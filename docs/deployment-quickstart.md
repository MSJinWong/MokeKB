# 服务器部署 Quickstart

适用：Ubuntu 22.04+ 单机部署 HoyanAI 后端，PG 独立管理、Redis 由本栈管理（默认密码 `123456`，端口绑 `127.0.0.1`）。前端独立部署（见 [`deployment-frontend.md`](./deployment-frontend.md)）。

> **本文档 = 当前推荐的部署路径。** 外部 PG / 外部 Redis / 离线包 / CI 踩坑史等场景见 [`deployment-app-only.md`](./deployment-app-only.md)。

---

## 1. 部署拓扑

```
┌──────────────────────────────────────────────────────────────┐
│ Server                                                       │
│                                                              │
│  ┌─ 独立容器 ─────────────────┐                              │
│  │ hoyanai-postgres           │ ← install-postgres.sh 管理   │
│  │   (pgvector/pgvector:pg17) │                              │
│  │   127.0.0.1:5432           │                              │
│  └────────────────────────────┘                              │
│             ▲                                                │
│             │ host.docker.internal:5432                      │
│             │                                                │
│  ┌─ docker compose 栈 ───────────────────────────────────┐   │
│  │  redis (alpine, 127.0.0.1:6379, password 123456)     │   │
│  │  hoyanai-app          (Django web :8080)             │   │
│  │  hoyanai-worker-rag                                  │   │
│  │  hoyanai-worker-default                              │   │
│  │  hoyanai-worker-maintenance                          │   │
│  └──────────────────────────────────────────────────────┘   │
│                       ▲                                      │
│                       │ :${MAXKB_BACKEND_PORT}               │
└───────────────────────┼──────────────────────────────────────┘
                        │
                  外网/独立前端 nginx
```

**5 个容器在 compose 栈里，1 个 PG 在栈外**——PG 独立的好处：升级/重跑后端栈时 PG 数据不动；PG 由自己的脚本管理备份。

数据持久化位置：

| 数据 | 宿主路径 |
|---|---|
| PG data | `/opt/hoyanai-pg/data/` |
| PG 备份 | `/opt/hoyanai-pg/backups/` |
| PG 密码凭据 | `/opt/hoyanai-pg/.password`（chmod 600） |
| Redis AOF | docker volume `hoyanai_hoyanai-redis-data` |
| 后端运行时（日志/sandbox/cache） | docker volume `hoyanai_hoyanai-data` |

---

## 2. 前置条件

**Server**：Ubuntu 22.04+ / Debian 12+，建议 4C/8G 起。

**必装**（脚本会检测并提示 apt 安装）：
- Docker engine 20.10+（支持 `host-gateway` extra_hosts）
- docker compose v2 plugin
- curl、netcat、openssl、iproute2

**网络**：能访问 `ghcr.io`（拉镜像）。国内服务器拉不动时改走离线流程，见 [`deployment-app-only.md`](./deployment-app-only.md) 第 4 节。

**镜像**：`ghcr.io/msjinwong/hoyanai-app:<tag>` 已经被 CI push 到 GHCR。如果是第一次部署且 CI 还没跑过，要么先触发 build-and-push workflow，要么走离线包。

---

## 3. 部署步骤

> 全程在 server 上以**普通用户**操作（不是 root）。当前用户需要在 `docker` 组里：
> ```bash
> groups | grep -q docker || (sudo usermod -aG docker $USER && newgrp docker)
> ```

### 3.1 安装 PostgreSQL（一次性）

```bash
# 1. 拉脚本
curl -fsSL https://raw.githubusercontent.com/MSJinWong/MokeKB/feat/frontend-redesign/installer/install-postgres.sh -o install-pg.sh
chmod +x install-pg.sh

# 2. 直接跑（密码交互输入，无需 vim）
./install-pg.sh
```

> 如需改默认目录/端口/用户名/库名等，编辑脚本顶部的常量后再跑。**密码不在顶部**，运行时交互设置。
>
> **默认 PG 绑 `0.0.0.0:5432`**：因为后端容器要通过 `host.docker.internal`（→ docker bridge 网关，如 172.17.0.1）连到 PG，而 127.0.0.1 不在网关接口上。脚本结尾会输出云厂商安全组阻断 5432 的提示——务必跟着做，否则 PG 可能暴露在公网。

脚本会依次跑 8 步：

1. **前置检查**：docker daemon 可用、openssl 可用（用于自动生成密码）
2. **PG 密码**：
   - 若 `/opt/hoyanai-pg/.password` 已存在 → 直接读取（重跑场景）
   - 否则交互：选 `1` 自动生成 24 字符强密码（推荐）/ 选 `2` 手动输入两次确认
   - 设置好之后写入 `/opt/hoyanai-pg/.password`（chmod 600）方便重跑读
3. **创建目录**：`/opt/hoyanai-pg/{data,backups}` 权限 0700
4. **备份**：若已有 `hoyanai-postgres` 容器在跑，先 `pg_dump` 到 `backups/hoyanai-YYYYMMDD-HHMMSS.sql.gz`，**备份失败则中止**防丢数据
5. **写 init.sql**：仅在 data dir 为空时跑一次，自动 `CREATE EXTENSION vector`
6. **启动容器**：`-p 127.0.0.1:5432:5432 -c max_connections=1000`
7. **等就绪**：`pg_isready` 轮询最长 60s，然后验证 vector 扩展已装
8. **清旧备份**：删除超过 `BACKUP_RETENTION_DAYS` 天的 `.sql.gz`

成功结尾会打印要填进后端 `.env` 的 5 个值。**密码记不住时**：
```bash
sudo cat /opt/hoyanai-pg/.password
```

### 3.2 部署后端栈

```bash
# 1. 拉部署脚本
curl -fsSL https://raw.githubusercontent.com/MSJinWong/MokeKB/feat/frontend-redesign/installer/deploy-app-only.sh -o deploy.sh
chmod +x deploy.sh

# 2. 跑（交互式 6 步）
./deploy.sh
```

交互回答指引：

| 提问 | 推荐输入 | 说明 |
|---|---|---|
| `选择镜像源 [1]` | `1` | 在线从 GHCR 拉 |
| `镜像 ref` | Enter | 用默认 `ghcr.io/msjinwong/hoyanai-app:dev`，生产改成具体版本 tag |
| `镜像 private? [N]` | n / y | private 时填 GitHub PAT (scope=read:packages) |
| `部署目录` | Enter | 默认 `~/hoyanai` |
| `PG host` | **Enter** | 用默认 `host.docker.internal`（compose extra_hosts 已配） |
| `PG port/user/db` | Enter | 用默认 5432/hoyanai/hoyanai |
| `PG password` | **3.1 设置的密码** | |
| `Redis 模式` | **`1`** | 由本栈管理 |
| `使用默认密码 123456？` | y | 端口已绑 127.0.0.1，弱口令仅本机可见，OK |
| `自动生成 Django SECRET_KEY` | y | `openssl rand -hex 32` 自动生成 |
| `MAXKB_ENABLED_PROVIDERS` | Enter | 默认 `all`（启用全部 provider） |
| `PG/Redis 预检` | — | PG 应该通过；Redis 是栈内，会跳过 nc 检查 |
| `现在 docker compose up -d？` | y | |

启动后等 `[✓] hoyanai-app 健康`，首次拉镜像 + worker 启动可能 2-3 分钟。

### 3.3 验证

```bash
cd ~/hoyanai
docker compose ps      # 5 个容器都得 Up / healthy

curl http://localhost:8080/admin/api/profile
# 返回 JSON（401 未登录也算正常，说明 web 已经在 serve）
```

前端 nginx（独立机器或同机）反代到 `http://<server-ip>:${MAXKB_BACKEND_PORT}`。前端部署见 [`deployment-frontend.md`](./deployment-frontend.md)。

---

## 4. 日常运维

所有命令在 `~/hoyanai` 目录下。

```bash
# 查看状态
docker compose ps

# 实时日志
docker compose logs -f hoyanai-app           # Web (Django + Gunicorn)
docker compose logs -f hoyanai-worker-rag    # RAG worker
docker compose logs -f redis                 # Redis

# Gunicorn 真实 stderr（Python traceback 在这里）
docker exec $(docker compose ps -q hoyanai-app) tail -100 /opt/maxkb/logs/gunicorn.log

# 重启 / 停止
docker compose restart
docker compose down                          # 不删 volume

# 升级镜像
vim .env                                     # 改 MAXKB_IMAGE 的 tag
docker compose pull
docker compose up -d
```

---

## 5. PG 备份与恢复

`install-postgres.sh` 已经在**重跑时**自动备份。你也可以手动备份：

```bash
# 手动备份（gzip 压缩）
docker exec hoyanai-postgres pg_dump -U hoyanai -d hoyanai \
  | gzip > /opt/hoyanai-pg/backups/manual-$(date +%F-%H%M).sql.gz

# 列出备份
ls -lh /opt/hoyanai-pg/backups/

# 恢复（⚠️ 会覆盖现有库 — 先停后端栈防止写入冲突）
cd ~/hoyanai && docker compose down
gunzip < /opt/hoyanai-pg/backups/hoyanai-YYYYMMDD-HHMMSS.sql.gz \
  | docker exec -i hoyanai-postgres psql -U hoyanai -d hoyanai
docker compose up -d
```

**定期备份建议**（cron，每天 3 点）：

```bash
crontab -e
# 加这行
0 3 * * * docker exec hoyanai-postgres pg_dump -U hoyanai -d hoyanai | gzip > /opt/hoyanai-pg/backups/cron-$(date +\%F).sql.gz && find /opt/hoyanai-pg/backups/ -name 'cron-*.sql.gz' -mtime +14 -delete
```

`install-postgres.sh` 顶部 `BACKUP_RETENTION_DAYS=7` 只清理脚本自己生成的 `hoyanai-*.sql.gz`，不会动 `manual-*` 或 `cron-*`——前缀分开就互不影响。

---

## 6. 常见问题

### 6.1 想改 PG 密码 / 忘了密码
密码保存在 `/opt/hoyanai-pg/.password`：
```bash
sudo cat /opt/hoyanai-pg/.password         # 查看
```
**改密码**（PG 用户已经存在的场景）：
```bash
# 1. 改 PG 里的密码
docker exec -it hoyanai-postgres psql -U hoyanai -d hoyanai \
  -c "ALTER USER hoyanai WITH PASSWORD '新密码';"
# 2. 同步更新凭据文件
echo -n '新密码' | sudo tee /opt/hoyanai-pg/.password >/dev/null
# 3. 同步 backend 栈 .env
vim ~/hoyanai/.env  # 改 MAXKB_DB_PASSWORD
docker compose -f ~/hoyanai/docker-compose.yml restart
```
**强制重新走交互设置**：删凭据文件 → `sudo rm /opt/hoyanai-pg/.password` → `./install-pg.sh`（脚本会重新问你密码，但 PG 里的旧密码不变；需要配合上面的 ALTER USER）。

### 6.2 `install-pg.sh` 报"密码不允许包含单引号"
脚本写 init.sql 时用单引号包值，密码含 `'` 会爆。选 `1` 自动生成的密码不会有这问题；手动输入时换别的特殊字符（`!@#$%^&*-_=+` 都 OK）。

### 6.3 部署脚本 preflight 报 `PG 端口不可达 host.docker.internal:5432`
**正常**：`host.docker.internal` 是 docker 容器内部 DNS 名，在 host 上不会解析。新版脚本会自动改用 docker bridge 网关 IP（如 172.17.0.1）做检测——如果还是失败，看下面 6.4。

旧版本（2026-05-26 之前 commit）的脚本直接 nc `host.docker.internal` 永远失败，可以 Ctrl-C 之后 `git pull` 拉新脚本，或当时选"仍然继续？y"绕过。

### 6.4 后端容器连不上 PG（`connection refused` / 健康检查 fail）
按这个顺序排查：
1. PG 容器在跑？`docker ps | grep hoyanai-postgres`
2. PG 接受连接？`docker exec hoyanai-postgres pg_isready -U hoyanai`
3. **PG 是否绑了 0.0.0.0**？`ss -tlnp | grep 5432`，要看到 `LISTEN 0 ... 0.0.0.0:5432`。如果是 `127.0.0.1:5432`，编辑 `install-pg.sh` 把 `PG_PORT_BIND="127.0.0.1:5432"` 改成 `"0.0.0.0:5432"` 重跑（会自动 pg_dump 备份）。
4. docker 版本 ≥ 20.10？`docker --version`（`host-gateway` 是这版引入）
5. 从容器侧直接测：
   ```bash
   docker run --rm --add-host=host.docker.internal:host-gateway \
     busybox sh -c "nc -z -v host.docker.internal 5432"
   # 期望: host.docker.internal (172.17.0.1:5432) open
   ```
6. 看应用真实报错：
   ```bash
   docker exec $(docker compose ps -q hoyanai-app) tail -100 /opt/maxkb/logs/gunicorn.log
   ```

### 6.5 担心 PG 绑 0.0.0.0 被公网扫到
检查方法：从**另一台机器**（不是部署 server）跑：
```bash
nc -z -w 3 <部署 server 公网 IP> 5432
```
应该 timeout / `connection refused`。如果**能连上**，说明云厂商安全组没拦——立刻去控制台禁止入站。

docker 自己的 iptables 规则一般会让 LAN 直连 docker0 网关比较难（NAT 阻断），但云厂商安全组是独立层，必须手动配。

### 6.6 后端起来了但 Redis 健康检查 fail
看 `docker compose logs redis`。最常见是 `.env` 里 `MAXKB_REDIS_PASSWORD` 被特殊字符截断——脚本写 .env 时已经用单引号包了，但如果你手改过 .env，检查是否仍有单引号：
```bash
grep MAXKB_REDIS_PASSWORD ~/hoyanai/.env
# 应该形如: MAXKB_REDIS_PASSWORD='123456'
```

### 6.7 升级后想清掉 Redis 缓存
```bash
docker compose down
docker volume rm hoyanai_hoyanai-redis-data
docker compose up -d
```
PG 在另一栈，不受影响。

### 6.8 想换强 Redis 密码并暴露到 LAN
1. 改 `~/hoyanai/.env` 的 `MAXKB_REDIS_PASSWORD`（注意单引号包裹）
2. 改 `~/hoyanai/docker-compose.yml` 里 redis 的 `ports`：`127.0.0.1:6379:6379` → `0.0.0.0:6379:6379`（或具体内网 IP）
3. `docker compose up -d`
4. 防火墙放行 6379

更多故障排查（CI/build/离线包/`#`-in-env/host-network 等历史踩坑）见 [`deployment-app-only.md`](./deployment-app-only.md) 第 6 节。

---

## 7. 卸载 / 重置

```bash
# 停后端栈（保留 PG 和 Redis 数据）
cd ~/hoyanai && docker compose down

# 删 Redis 缓存（PG 不动）
docker volume rm hoyanai_hoyanai-redis-data hoyanai_hoyanai-data

# 删 PG 容器（数据还在 /opt/hoyanai-pg/data/，重启 install-pg.sh 会恢复）
docker stop hoyanai-postgres && docker rm hoyanai-postgres

# 完全清空 PG 数据 + 凭据（⚠️ 不可逆，先备份！）
sudo rm -rf /opt/hoyanai-pg
```

---

## 8. 相关文件索引

| 文件 | 作用 |
|---|---|
| `installer/install-postgres.sh` | PG 独立安装/备份脚本，在 server 上单独跑 |
| `installer/deploy-app-only.sh` | 后端栈交互式部署脚本 |
| `installer/docker-compose.app-only.yml` | 5 个容器（redis + web + 3 workers）的 compose 定义 |
| `installer/.env.app-only.example` | .env 模板 |
| `docs/deployment-app-only.md` | 详细参考（外部服务、离线、CI 踩坑） |
| `docs/deployment-frontend.md` | 前端独立部署 |
