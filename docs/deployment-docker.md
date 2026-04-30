# MokeKB Docker 部署指南

涵盖两种部署形态：**all-in-one**（单容器，快速体验）和 **split**（多容器，生产推荐）。

> 本文档与 `docs/deployment-split.md` 互补——后者是 split 模式的环境变量与运维参考；本文档着重在 **如何选择 / 如何起 / 如何升级 / 如何回滚**。

---

## 目录

1. [选哪种？](#选哪种)
2. [前置准备](#前置准备)
3. [all-in-one 部署](#all-in-one-部署)
4. [Split 部署](#split-部署)
5. [日常运维](#日常运维)
6. [升级与回滚](#升级与回滚)
7. [备份恢复](#备份恢复)
8. [扩容](#扩容)
9. [故障排查](#故障排查)

---

## 选哪种？

| 你的场景 | 推荐 |
|----------|-----|
| 个人体验 / Demo / 团队几十人内部使用 | all-in-one |
| 生产环境 / 多租户 / 知识库 > 100 万条 embedding | split |
| 不想管 PostgreSQL / Redis 自己运维 | split + 接云上托管 PG / Redis |
| 需要独立扩容 worker | split |
| 单机资源 < 8GB RAM | all-in-one (并禁用 local-model) |

切换不是单向的：从 all-in-one → split 只需 dump 数据库 / restore 到外部 PG，再换 compose 即可。

---

## 前置准备

### 服务器规格

| 部署形态 | 推荐 CPU | 推荐 RAM | 推荐磁盘 |
|---------|---------|---------|---------|
| all-in-one (含 local-model) | 4 核 | 16 GB | 50 GB SSD |
| all-in-one (无 local-model) | 2 核 | 8 GB | 30 GB SSD |
| split (4 服务在一台) | 4 核 | 16 GB | 100 GB SSD |
| split (生产，多机) | 单机 4 核 8 GB × N | 同左 | DB 单独 200 GB+ |

### Docker / Compose 版本

```bash
docker --version          # >= 24.0
docker compose version    # >= v2.20
```

如果是 Docker Desktop（Windows / Mac），确保给容器至少 8GB RAM。

---

## all-in-one 部署

最简方式：单容器跑全部组件。容器内自带 PostgreSQL 17 + pgvector + Redis + Web + Worker + 沙箱 + 前端。

### 1. 拉镜像（或自己 build）

```bash
docker pull ghcr.io/1panel-dev/maxkb:latest
# 或 build 你这个分支
docker build -f installer/Dockerfile -t maxkb-local:dev .
```

### 2. 启动

```bash
docker run -d \
  --name maxkb \
  --restart unless-stopped \
  -p 8080:8080 \
  -v maxkb-data:/opt/maxkb \
  -e MAXKB_ENABLE_API_DOCS=false \
  -e MAXKB_ENABLE_EMAIL=false \
  -e MAXKB_ENABLED_PROVIDERS=model_openai_provider,model_anthropic_provider,model_siliconCloud_provider \
  ghcr.io/1panel-dev/maxkb:latest
```

> 数据目录默认 `maxkb-data` 命名卷。如要直接挂宿主机目录：`-v /host/path:/opt/maxkb`。
>
> 启用 API doc 时还需要 `-e MAXKB_DOC_PASSWORD=maxkb`（值不重要，但必须非空，且需匹配特定 MD5——目前是字面量 `'maxkb'`）。

### 3. 验证启动

```bash
docker logs --tail 50 maxkb
# 期望看到:
#   PostgreSQL started.
#   Redis started.
#   MaxKB started.

curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/admin/
# 期望: 200
```

### 4. 首次登录

浏览器打开 `http://<host>:8080/admin/`，默认账号：

- 用户名: `admin`
- 密码: `MaxKB@123..`（首次登录强制改密）

---

## Split 部署

生产推荐。组件拆成 7 个容器：postgres / redis / maxkb-app / maxkb-worker-rag / maxkb-worker-default / maxkb-worker-maintenance / maxkb-ui。

### 1. Build 自定义镜像

> 如果不需要自己改代码，可以跳过这一步直接用预构建镜像（如有）。

```bash
cd ~/projects/MokeKB
git checkout release-2.9-simplify

docker build -f installer/Dockerfile.app-only -t maxkb-app:latest .
docker build -f installer/Dockerfile.ui      -t maxkb-ui:latest .
```

镜像大小预期：
- `maxkb-app`：~1.5 GB（无 PG / Redis / UI / 本地模型）
- `maxkb-ui`：~150 MB（nginx + 前端 dist）

### 2. 准备环境变量

```bash
cp installer/.env.split.example installer/.env.split
vim installer/.env.split
```

**必须修改的项**：

```env
POSTGRES_PASSWORD=<生成强密码>
REDIS_PASSWORD=<生成强密码>
MAXKB_DJANGO_SECRET_KEY=<至少 50 字节随机串>
MAXKB_PUBLIC_PORT=8080            # 公网暴露端口
MAXKB_ENABLED_PROVIDERS=model_openai_provider,model_anthropic_provider,model_siliconCloud_provider
```

生成 SECRET_KEY 的快捷方式：

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

### 3. 启动

```bash
docker compose --env-file installer/.env.split \
               -f installer/docker-compose.split.yml \
               up -d
```

### 4. 等待健康

```bash
docker compose --env-file installer/.env.split \
               -f installer/docker-compose.split.yml \
               ps
```

期望全部 7 个服务 `running` 且 `healthy`：

```
NAME                              STATUS
maxkb-app-...                     Up 2 minutes (healthy)
maxkb-worker-rag-...              Up 1 minute
maxkb-worker-default-...          Up 1 minute
maxkb-worker-maintenance-...      Up 1 minute
maxkb-ui-...                      Up 1 minute
postgres-...                      Up 2 minutes (healthy)
redis-...                         Up 2 minutes (healthy)
```

### 5. 访问

浏览器：`http://<host>:8080/admin/`

---

## 日常运维

### 查看日志

```bash
# 所有服务
docker compose -f installer/docker-compose.split.yml logs -f

# 特定服务（最近 100 行）
docker compose -f installer/docker-compose.split.yml logs -f --tail 100 maxkb-app
docker compose -f installer/docker-compose.split.yml logs -f --tail 100 maxkb-worker-rag
```

### 进容器排查

```bash
docker compose -f installer/docker-compose.split.yml exec maxkb-app bash
# 在容器里：
python /opt/maxkb-app/apps/manage.py shell
```

### 验证队列路由生效

```bash
docker compose -f installer/docker-compose.split.yml exec maxkb-worker-rag \
    celery -A ops inspect active_queues
```

期望看到 `rag_parse / rag_embedding / rag_index` 三个队列。

### 验证调度器只在一个进程

```bash
for svc in maxkb-app maxkb-worker-rag maxkb-worker-default maxkb-worker-maintenance; do
    echo "=== $svc ==="
    docker compose -f installer/docker-compose.split.yml exec $svc \
        printenv MAXKB_ENABLE_SCHEDULER
done
```

期望：仅 `maxkb-worker-maintenance` 输出 `true`，其它 `false`。

---

## 升级与回滚

### 升级（split 模式）

1. **拉新镜像**

```bash
docker pull maxkb-app:<new-tag>
docker pull maxkb-ui:<new-tag>
```

如果是自己 build：先 `git pull && docker build ...`。

2. **滚动重启 maxkb-app**（它会自动跑 `manage.py migrate`）

```bash
docker compose -f installer/docker-compose.split.yml \
    up -d --no-deps maxkb-app
docker compose -f installer/docker-compose.split.yml \
    logs -f --tail 100 maxkb-app
# 等到 "MaxKB started." 再继续下一步
```

3. **重启所有 worker 与 ui**

```bash
docker compose -f installer/docker-compose.split.yml \
    up -d --no-deps \
    maxkb-worker-rag maxkb-worker-default maxkb-worker-maintenance maxkb-ui
```

worker 不跑 migrate，所以重启快（秒级）。

### 升级（all-in-one）

```bash
docker pull ghcr.io/1panel-dev/maxkb:<new-tag>
docker stop maxkb && docker rm maxkb
docker run -d --name maxkb [...原参数...] ghcr.io/1panel-dev/maxkb:<new-tag>
```

数据保留在命名卷 `maxkb-data` 里，不会丢。

### 回滚

由于 Phase 6 的所有 migration 都是 **加列加索引**，**没有删字段**，所以回滚有两条路径：

**A. 回滚代码 + 镜像，schema 保持新版**（推荐，零数据迁移）

```bash
# split
docker pull maxkb-app:<old-tag>
docker compose -f installer/docker-compose.split.yml \
    up -d --no-deps maxkb-app maxkb-worker-rag maxkb-worker-default maxkb-worker-maintenance maxkb-ui

# all-in-one
docker pull ghcr.io/1panel-dev/maxkb:<old-tag>
docker stop maxkb && docker rm maxkb
docker run -d --name maxkb [...] ghcr.io/1panel-dev/maxkb:<old-tag>
```

旧二进制看到新 schema：
- `embedding.workspace_id` 列：旧二进制 INSERT 不带此列时，PG 用 `db_default 'default'` 兜底——**不会失败**
- 4 个新索引：旧二进制完全无感知
- `file_sha256_hash_idx` 普通索引：旧二进制透明使用

**B. 完全回滚（极少需要）**：包括 schema rollback。需要 `python manage.py migrate knowledge 0007`，会执行 reverse_sql，但通常没必要。

### 危险操作清单

| 不要做 | 原因 |
|-------|-----|
| `docker compose down -v` | `-v` 删卷，丢所有数据 |
| `docker volume rm maxkb-data` | 同上 |
| 在 split 模式给 `maxkb-worker-maintenance` 加副本 | 会重复执行调度任务 |
| 在多个容器里都设 `MAXKB_ENABLE_SCHEDULER=true` | 同上 |
| `python manage.py migrate --fake` | 跳过 migration 但留下 schema 与代码不一致 |

---

## 备份恢复

### Split 模式：备份外部 Postgres

```bash
docker compose -f installer/docker-compose.split.yml exec -T postgres \
    pg_dump -U maxkb -Fc -d maxkb > maxkb-$(date +%Y%m%d).dump
```

恢复：

```bash
docker compose -f installer/docker-compose.split.yml exec -T postgres \
    pg_restore -U maxkb -d maxkb --clean --if-exists < maxkb-20260429.dump
```

> 注意：embedding 表如果很大，pg_dump 时间也长。生产建议用 PG 的 logical replication / 物理复制 + 定时快照。

### Split 模式：备份 maxkb-data 卷（含日志、临时文件、PIP_TARGET 沙箱包）

```bash
docker run --rm -v maxkb-data:/data -v $(pwd):/backup alpine \
    tar czf /backup/maxkb-data-$(date +%Y%m%d).tar.gz -C /data .
```

### All-in-one：备份整个数据卷

```bash
docker run --rm -v maxkb-data:/data -v $(pwd):/backup alpine \
    tar czf /backup/maxkb-allinone-$(date +%Y%m%d).tar.gz -C /data .
```

里面包含 PG 数据 + Redis dump + 应用日志。

---

## 扩容

### Split 模式：单 worker 扩多副本

知识库导入并发高时：

```bash
docker compose --env-file installer/.env.split \
               -f installer/docker-compose.split.yml \
               up -d --scale maxkb-worker-rag=3
```

聊天 / 工具调用并发高时：

```bash
docker compose --env-file installer/.env.split \
               -f installer/docker-compose.split.yml \
               up -d --scale maxkb-worker-default=3
```

> ⚠️ **不要 scale `maxkb-worker-maintenance`** —— 会重复执行调度任务。
>
> Web 也可以 scale（`--scale maxkb-app=2`），但需要前面挂负载均衡（nginx upstream / 云 LB），且只让一个实例跑 migration。当前 compose 没做这个，所以 web 默认 1 副本即可。

### Split 模式：单 worker 改并发数

每个 worker 容器内 celery 用 `-c` 控制并发线程数。当前默认 `worker_concurrency=5`（在 `apps/ops/celery/__init__.py:19`），如要调整：

```bash
docker compose -f installer/docker-compose.split.yml \
    exec maxkb-worker-rag \
    celery -A ops control rate_limit ...
```

或在 compose 中给 worker 加 env：

```yaml
maxkb-worker-rag:
  environment:
    CELERY_WORKER_CONCURRENCY: 10
```

### 接管外部 Postgres / Redis

把 split compose 中 `postgres` 和 `redis` 服务删除，把 `maxkb-app` / 三个 worker 的对应 env 改为外部地址：

```yaml
maxkb-app:
  environment:
    MAXKB_DB_HOST: my-rds.cn-east-1.amazonaws.com
    MAXKB_DB_PORT: 5432
    MAXKB_DB_USER: maxkb
    MAXKB_DB_PASSWORD: ...
    MAXKB_REDIS_HOST: my-redis.cn-east-1.cache.amazonaws.com
    MAXKB_REDIS_PORT: 6379
    MAXKB_REDIS_PASSWORD: ...
```

外部 PostgreSQL **必须**：
- 版本 >= 13（PG 14+ 推荐用于声明式分区）
- 启用 pgvector 扩展（`CREATE EXTENSION vector;`）
- 允许 maxkb 用户 `CREATE INDEX CONCURRENTLY`（即非只读账号）

---

## 故障排查

### 启动慢 / `maxkb-app unhealthy`

```bash
docker compose -f installer/docker-compose.split.yml logs maxkb-app | tail -100
```

常见原因：
- migration 慢（embedding 表很大时回填 workspace_id 慢；见 followup F3 / F4 优化）
- DB 连接失败：检查 `MAXKB_DB_*` 与 postgres healthcheck

### worker 不消费

```bash
docker compose -f installer/docker-compose.split.yml exec maxkb-worker-rag \
    celery -A ops inspect active_queues
```

如果没看到 rag_* 队列，检查 `MAXKB_TASK_QUEUE_PREFIX_ENABLED=1` 是否同时设在 maxkb-app **与** worker（生产侧 + 消费侧都要）。

### Worker / web 日志中出现 `Provider xxx is not enabled`

`MAXKB_ENABLED_PROVIDERS` 收紧后，DB 里残留的 model 行引用了被禁用的 provider。两种解决：

1. 把对应 provider 加回白名单
2. 在管理界面删除引用该 provider 的模型记录

### nginx 502 Bad Gateway

```bash
docker compose -f installer/docker-compose.split.yml logs maxkb-ui
```

通常是 maxkb-app 还没 healthy。等待 `start_period: 60s` 后会自动恢复。如果持续 502：检查 maxkb-app 是否能从 `maxkb-ui` 容器内 ping 通：

```bash
docker compose -f installer/docker-compose.split.yml exec maxkb-ui \
    wget -O- http://maxkb-app:8080/admin/api/profile
```

### 清理 INVALID 索引

如果 `CREATE INDEX CONCURRENTLY` 中途中断（例如 OOM）：

```sql
-- 在 postgres 容器里
SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
-- 复制名字后
DROP INDEX CONCURRENTLY <index_name>;
-- 重新跑 migration
```

### embedding 数据膨胀，DB 体积爆涨

参考 `docs/superpowers/plans/2026-04-29-followup-roadmap.md` F4：把 File 外置到对象存储是首要选项。

---

## 端口映射

| 服务 | 容器内 | 外暴露 | 用途 |
|------|-------|-------|------|
| maxkb-ui (split) | 80 | `MAXKB_PUBLIC_PORT` (默认 8080) | 浏览器访问 |
| maxkb-app (split) | 8080 | 内部 only | UI 反代到此 |
| postgres (split) | 5432 | 内部 only | 仅 maxkb-app/worker 访问 |
| redis (split) | 6379 | 内部 only | 仅 maxkb-app/worker 访问 |
| all-in-one | 8080 | 8080 | 浏览器访问 |

> 生产环境**不要**在外网暴露 postgres / redis 端口。

---

## 进一步阅读

- 各环境变量详解：`docs/deployment-split.md`
- 主优化方案 commit 索引：`docs/superpowers/plans/2026-04-29-deployment-and-capacity-optimization.md`
- 后续 backlog：`docs/superpowers/plans/2026-04-29-followup-roadmap.md`
- 本地开发：`docs/dev-wsl.md`
