# Backend-only 部署指南（详细参考）

> **首次部署看这里**：[`deployment-quickstart.md`](./deployment-quickstart.md) — 用 `install-postgres.sh` 独立装 PG + 本栈管理 Redis（默认密码 123456），单机一键起。本文是详细参考，覆盖外部 PG/Redis、离线包、`.env` 字段、故障排查、CI 踩坑史。

适用：把 HoyanAI 后端容器化部署，**外部独立维护** PostgreSQL（带 pgvector）+ Redis + 前端 nginx 的场景。

> 前端独立部署（admin/chat 构建、nginx 配置、宝塔步骤、故障排查）：见 [`deployment-frontend.md`](./deployment-frontend.md)。

---

## 1. 部署模型

部署后会跑 **4 个容器，全部用同一个镜像** `ghcr.io/<owner>/hoyanai-app:<tag>`：

| 容器 | 角色 | 对外端口 |
|---|---|---|
| `hoyanai-app` | Django web（Gunicorn 在 8080） | `${MAXKB_BACKEND_PORT}` → 8080 |
| `hoyanai-worker-rag` | Celery worker：RAG parse / embedding / index | — |
| `hoyanai-worker-default` | Celery worker：默认 queue | — |
| `hoyanai-worker-maintenance` | Celery worker：维护 queue + apscheduler + celery-beat | — |

```
  浏览器/客户端
       │
       ▼
  独立前端 nginx
       │  反代：
       │    /admin/api/  → backend:8080/admin/api/
       │    /chat/api/   → backend:8080/chat/api/
       │    /ws/         → ws://backend:8080/ws/
       ▼
  宿主:${PORT}  →  容器 hoyanai-app:8080
                       │  ┌──── 外部 PostgreSQL（带 pgvector）
                       ├──┤
                       │  └──── 外部 Redis（with auth）
                       │
                       ▼ (Celery via Redis broker)
        hoyanai-worker-rag / default / maintenance
```

数据卷：`hoyanai-data:/opt/maxkb`（4 个容器共享，存日志、运行时缓存、Python sandbox packages）。

> 容器内路径仍为 `/opt/maxkb`(后端代码硬编码),不影响部署。

---

## 2. 前置条件

**服务器**：Ubuntu 22.04+ / Debian 12+，建议 4C/8G 起。

**宿主必装**：
- Docker engine 20.10+
- docker compose v2 plugin
- curl、netcat、openssl、iproute2（部署脚本会检测并提示 apt 安装）

**外部 PostgreSQL**：
- 14 或更高
- **必须装 pgvector 扩展**
- 数据库 + 专用用户已建好（详见下方 SQL）
- 用户对 schema `public` 有写权限
- `pg_hba.conf` 允许部署服务器 IP 连接
- `postgresql.conf` 中 `listen_addresses = '*'`（或显式列出部署 IP）

**外部 Redis**：
- 7.x，建议 7.2
- 设置了 `requirepass`
- 同机部署时 **`bind 0.0.0.0`** 或 `bind 127.0.0.1 172.17.0.1`（包含 docker bridge 网关）
- 防火墙放行 6379

**网络**：
- 部署服务器到 PG/Redis 网络畅通（脚本里 `nc -z` + `psql` 会验证）
- 公网端口至少 80/443（给独立前端 nginx 用）

### PG 一次性初始化 SQL

在 PG 服务器以 superuser 执行：

```sql
CREATE DATABASE hoyanai;
CREATE USER hoyanai WITH PASSWORD 'YourStrongPasswordHere';
GRANT ALL PRIVILEGES ON DATABASE hoyanai TO hoyanai;

\c hoyanai
CREATE EXTENSION IF NOT EXISTS vector;
GRANT ALL ON SCHEMA public TO hoyanai;
```

---

## 3. 部署：在线场景

适用：服务器能访问 ghcr.io。

```bash
# 1. 下载部署脚本
curl -fsSL https://raw.githubusercontent.com/MSJinWong/MokeKB/feat/frontend-redesign/installer/deploy-app-only.sh -o deploy.sh
chmod +x deploy.sh

# 2. 跑（交互式，全程问答）
./deploy.sh

# 3. 验证
docker compose -f ~/hoyanai/docker-compose.yml ps
curl http://localhost:8080/admin/api/profile
```

脚本会引导完成 6 步：
1. 环境检查（缺 curl/docker/nc 等会建议 apt 安装）
2. 镜像准备（pull 或离线 load）
3. 工作目录（默认 `~/hoyanai`）
4. 配置 .env（密码、连接信息、SECRET_KEY 自动生成）
5. 连通性检查（PG 端口 / Redis 端口 / pgvector 扩展）
6. 启动 + 等待健康检查通过

**国内服务器拉 ghcr.io 慢/失败**：考虑改用阿里云 ACR 同步镜像，或走下面的离线流程。

---

## 4. 部署：离线场景

适用：目标服务器无外网，但能从内网/U 盘接收文件。

### 阶段 A：联网机器准备 bundle

```bash
mkdir hoyanai-bundle && cd hoyanai-bundle

# 1. 从 GitHub Actions 下载离线镜像 tar.gz
#    https://github.com/MSJinWong/MokeKB/actions/workflows/build-and-push-app-only.yml
#    最近一次成功 run → 页面下方 Artifacts → hoyanai-app-<tag>-offline
#    解压后得到两个文件：
#      hoyanai-app-<tag>-linux-amd64.tar.gz
#      hoyanai-app-<tag>-linux-amd64.tar.gz.sha256
#    把这两个放进当前目录

# 2. 下载部署脚本 + compose 文件
curl -fsSL -O https://raw.githubusercontent.com/MSJinWong/MokeKB/feat/frontend-redesign/installer/docker-compose.app-only.yml
curl -fsSL -O https://raw.githubusercontent.com/MSJinWong/MokeKB/feat/frontend-redesign/installer/deploy-app-only.sh
mv docker-compose.app-only.yml docker-compose.yml   # 重命名以匹配脚本期望
chmod +x deploy-app-only.sh

cd ..
tar czf hoyanai-bundle.tar.gz hoyanai-bundle/
```

### 阶段 B：传到离线服务器

```bash
scp hoyanai-bundle.tar.gz user@offline-server:~/
# 或 U 盘 / 跳板机 / 内网共享
```

### 阶段 C：在离线服务器跑

```bash
# 验证 docker 已经装好
docker version && docker compose version

# 解包
tar xzf ~/hoyanai-bundle.tar.gz
cd ~/hoyanai-bundle

# 跑
./deploy-app-only.sh
```

交互到镜像那步选 **2 (离线)**：

```
  1) 在线 — 从 GHCR 拉取（默认）
  2) 离线 — 加载已下载的 tar.gz
选择 [1]: 2
tar.gz 文件路径: ./hoyanai-app-dev-linux-amd64.tar.gz
```

> 工作目录提示时输入 `.` 让脚本就用当前 bundle 目录，否则它默认会跳到 `~/hoyanai`，那边没有 docker-compose.yml 会重新去网上下载。

---

## 5. `.env` 字段速查

脚本会自动生成。手动改可参考：

| 变量 | 必填 | 默认 | 说明 |
|---|---|---|---|
| `COMPOSE_PROJECT_NAME` | — | `hoyanai` | 显式 pin，volumes 不会因 workdir 改名而漂移 |
| `MAXKB_IMAGE` | ✓ | — | 镜像 ref，如 `ghcr.io/msjinwong/hoyanai-app:v2.8.0` |
| `MAXKB_BACKEND_PORT` | ✓ | 8080 | 宿主映射端口 |
| `MAXKB_DB_HOST` | ✓ | — | PG IP/host — **同机部署不能用 127.0.0.1**（用 172.17.0.1） |
| `MAXKB_DB_PORT` | — | 5432 | |
| `MAXKB_DB_USER` / `MAXKB_DB_PASSWORD` / `MAXKB_DB_NAME` | ✓ | — | PG 凭据 |
| `MAXKB_DB_MAX_OVERFLOW` | — | 80 | DB 连接池溢出上限 |
| `MAXKB_REDIS_HOST` | ✓ | — | 同理不能 127.0.0.1 |
| `MAXKB_REDIS_PORT` / `MAXKB_REDIS_PASSWORD` / `MAXKB_REDIS_DB` | ✓ | 6379 / — / 0 | |
| `MAXKB_DJANGO_SECRET_KEY` | ✓ | — | `openssl rand -hex 32` 生成 |
| `MAXKB_ENABLED_PROVIDERS` | ✓ | `all` | 模型 provider 白名单。`all` = 启用全部；也可填逗号分隔子集精简部署 |
| `MAXKB_ENABLE_API_DOCS` / `MAXKB_ENABLE_EMAIL` | — | false | 可选开关 |

> **变量名保留 `MAXKB_*` 前缀**(后端代码按这个名字读),只是产品已重新品牌为 HoyanAI。
>
> **所有值用单引号包裹**（`KEY='value'`），避免 `#`、空格等触发 compose 的 .env 解析器吞行。脚本自动这么写。

---

## 6. 故障排查（按错误信息查）

### 6.1 CI 构建失败

| 错误 | 原因 | 修复 |
|---|---|---|
| `OSError: Readme file does not exist: README.md` | hatchling 要求 `pyproject.toml` 的 `readme` 文件存在 | Dockerfile COPY 包含 README.md；`.dockerignore` 加 `!README.md` |
| `CopyIgnoredFile: README.md ... excluded by .dockerignore` | `*.md` 黑名单也排除了 README | `.dockerignore` 加 `!README.md` |
| `failed to compute cache key: ... "/README.md": not found` | 同上 + 可能用了 stale GHA cache | 同上，并确保 workflow 用最新 commit 跑 |
| `ValueError: Unable to determine which files to ship inside the wheel` | `uv pip install ".[extras]"` 触发 hatchling build_wheel，找不到 `maxkb/` 目录 | 用 `-r pyproject.toml --extra <name>` 模式（只装依赖） |
| `ImportError: No config file found` (during `compilemessages`) | `MAXKB_CONFIG_TYPE` 未设为 `ENV`，Django 找不到 config.yml | Dockerfile stage-build 设 `ENV MAXKB_CONFIG_TYPE=ENV MAXKB_LOG_LEVEL=INFO` |

### 6.2 离线包 / 校验

| 错误 | 原因 | 修复 |
|---|---|---|
| `sha256sum: No such file or directory: offline/...` | 旧 workflow 的 sha256 文件记的是 `offline/<file>` 路径，但 artifact zip 解压后是平铺的 | 部署脚本现在用 hash 值直接对比，不依赖路径；workflow 也在 `offline/` 内执行 sha256sum |
| `文件不存在: <你输入的路径>` | 路径打错（脚本现在用 `read -e`，**支持 Tab 补全**） | 用相对路径 `./file.tar.gz` 或 Tab 补全 |
| 架构不匹配警告 | 镜像是 amd64，宿主是 arm64（或反之） | 当前 workflow 只产 amd64，arm 服务器需要本地重新 build |

### 6.3 .env / compose 解析

| 错误 | 原因 | 修复 |
|---|---|---|
| `error while interpolating x-app-env.MAXKB_X: required variable X is missing a value` | 值里有 `#`（最常见），compose 当成行内注释吞掉 | 给值加单引号：`MAXKB_DB_PASSWORD='Zaq12wsxcde#'`。新版脚本自动这么写 |
| 同上但密码确实写了 | 编辑器写出了 CRLF / BOM 等隐藏字符 | `cat -A .env` 看是否有 `^M$`；用 `dos2unix .env` 转 |
| compose 版本是 `5.0.2` 之类奇怪版本 | 非官方 docker compose 实现，.env 解析行为不一致 | 装官方 `docker-compose-plugin` |

### 6.4 启动失败 / 健康检查 timeout

**最关键的诊断命令**：

```bash
# 应用 stdout（main.py 包装层）
docker compose logs --tail=50 hoyanai-app

# Gunicorn 真实 stderr（这里才有 Python traceback）
docker exec $(docker compose ps -q hoyanai-app) tail -50 /opt/maxkb/logs/gunicorn.log
```

> 为什么要看两份日志？`main.py` 用 subprocess 启 Gunicorn 时把 `stderr` 重定向到 `/opt/maxkb/logs/gunicorn.log`，**`docker compose logs` 只看得到 "Start Gunicorn / gunicorn is stopped" 包装信息，看不到真错误**。新版脚本健康检查超时时会自动 dump 这两份。

常见 traceback：

| traceback | 原因 | 修复 |
|---|---|---|
| `redis.exceptions.TimeoutError: Timeout connecting to server` | `MAXKB_REDIS_HOST=127.0.0.1` 在容器里指容器自己 | 改成 docker bridge 网关（`172.17.0.1`）或宿主 LAN IP；宿主 redis.conf `bind 0.0.0.0` |
| `psycopg.OperationalError: could not connect to server` | PG 网络/防火墙问题 | `pg_hba.conf` 加 docker 网段；`listen_addresses` 改 `*`；防火墙放行 5432 |
| `psycopg.errors.InsufficientPrivilege: permission denied for schema public` | 应用 DB 用户权限不够，无法建表 | `GRANT ALL ON SCHEMA public TO hoyanai;` |
| `psycopg.errors.UndefinedObject: extension "vector" does not exist` | PG 没装 pgvector | 安装 pgvector 扩展，superuser 执行 `CREATE EXTENSION vector;` |
| `django.db.utils.ProgrammingError: relation "X" does not exist` | migration 没跑全 | `docker compose exec hoyanai-app python apps/manage.py migrate` 手动跑一次 |

### 6.5 4 个容器中只有 worker 起不来 / 一直 Created

`worker` 的 `depends_on: condition: service_healthy` 卡住——hoyanai-app 没变 healthy。看 6.4。

### 6.6 健康检查端点 401/403

如果未来 `/admin/api/profile` 改成需要认证，healthcheck 会因为 `curl -f` 而失败。当前版本是 unauthenticated OK 的。如出现，把 compose healthcheck 换成更基础的 endpoint，比如 `/`。

---

## 7. 升级

### 在线

```bash
cd ~/hoyanai
vim .env   # 改 MAXKB_IMAGE 指向新 tag
docker compose pull
docker compose up -d
```

### 离线

```bash
cd ~/hoyanai-bundle
# 把新版 tar.gz 放进来
docker load < hoyanai-app-v2.8.1-linux-amd64.tar.gz
cd ~/hoyanai
vim .env   # 改 MAXKB_IMAGE
docker compose up -d
```

升级期间 4 个容器会被 recreate，正在跑的 Celery 任务会被打断（任务消息留在 Redis，重启后由新容器继续消费）。

---

## 8. 卸载 / 重置

```bash
cd ~/hoyanai

# 停服务（保留数据卷）
docker compose down

# 完全清理（删除 hoyanai-data 卷 — log 和临时文件没了，但 PG/Redis 不动）
docker compose down -v

# 想连镜像也删
docker rmi $(docker images -q ghcr.io/msjinwong/hoyanai-app)
```

> PG 和 Redis 是外部服务，compose 不会动。需要清空时手动 `DROP DATABASE hoyanai` / `FLUSHDB`。

---

## 9. 运维参考

### 查看运行时关键路径

```bash
# 容器内日志
docker exec $(docker compose ps -q hoyanai-app) ls -la /opt/maxkb/logs/

# 宿主 volume 路径（root 可访问）
sudo ls $(docker volume inspect hoyanai_hoyanai-data --format '{{.Mountpoint}}')/logs/
```

### 手动调试

```bash
# 容器里跑 Django shell
docker compose exec hoyanai-app python apps/manage.py shell

# 手动跑 migration
docker compose exec hoyanai-app python apps/manage.py migrate

# 检查 Celery worker 是否在消费
docker compose exec hoyanai-app python apps/manage.py celery_inspect_active
```

### 调整资源

compose 没硬编码 CPU/内存限制。需要时在 `docker-compose.yml` 每个服务下加：

```yaml
deploy:
  resources:
    limits:
      memory: 2G
      cpus: '2.0'
```

---

## 附：踩过的坑（项目史记）

按踩到顺序：

1. **`README.md` 不在 build context** — pyproject.toml 引用了它，hatchling 校验失败
2. **`.dockerignore` 的 `*.md` 也排除了 README** — 加 `!README.md` 反排除
3. **`uv pip install .` 触发 hatchling build_wheel** — 项目没有 `maxkb/` 目录，改成 `-r pyproject.toml --extra X`
4. **`compilemessages` 找不到 config.yml** — stage-build 没设 `MAXKB_CONFIG_TYPE=ENV`，Django 默认走 yml 路径
5. **离线 tar 的 sha256 路径不对** — workflow 在 workspace 根目录运行 `sha256sum offline/X`，artifact 解压后是平铺的；改为在 `offline/` 内执行
6. **`.env` 里 `#` 触发行内注释** — `MAXKB_DB_PASSWORD=Zaq12wsxcde#` 被截断；用单引号包裹所有值
7. **`MAXKB_REDIS_HOST=127.0.0.1` 在容器里指向容器自己** — 宿主上的 Redis 应该用 `172.17.0.1`（docker bridge）或宿主 LAN IP
8. **Gunicorn 真实错误被吞** — `main.py` 把 stderr 重定向到容器内文件 `/opt/maxkb/logs/gunicorn.log`，`docker compose logs` 看不到 Python traceback

每一条都已通过 Dockerfile / workflow / 部署脚本的更新固化掉了。新部署不会再踩。
