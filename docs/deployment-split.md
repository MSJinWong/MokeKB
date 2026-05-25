# MokeKB 拆分部署指南

本文档描述 MokeKB 的两种部署形态选择：

- **all-in-one**：单容器，包含 PostgreSQL + Redis + Web + Celery + 沙箱 + 前端 + 本地向量模型。适合快速体验、本地开发、小团队演示。
- **split**：多容器编排，PG/Redis/Web/Worker/UI 各自独立。适合生产部署，可独立扩缩容、独立升级。

---

## 形态对比

| 维度 | all-in-one | split |
|------|-----------|-------|
| 镜像数量 | 1 | 4（app / ui / pg / redis 镜像） |
| 单镜像体积 | 6-10 GB | app ≈ 1-2 GB，ui ≈ 200 MB |
| 调度器进程 | web 进程内 | maxkb-worker-maintenance 唯一一个 |
| 任务队列 | 单 `celery` 队列 | 5 个：rag_parse / rag_embedding / rag_index / maintenance / celery |
| 默认 provider | 全部 21 个 | 仅 OpenAI / Anthropic / SiliconFlow（白名单） |
| 升级方式 | 替换镜像 | 按服务滚动 |
| 数据库迁移 | 容器内自动 | maxkb-app 启动时自动 |

---

## 快速 Split 部署

### 1. 构建镜像

```bash
docker build -f installer/Dockerfile.app-only -t maxkb-app:latest .
docker build -f installer/Dockerfile.ui      -t maxkb-ui:latest .
```

### 2. 准备环境变量

```bash
cp installer/.env.split.example installer/.env.split
# 按实际修改 installer/.env.split：
#   POSTGRES_PASSWORD / REDIS_PASSWORD / MAXKB_DJANGO_SECRET_KEY
#   MAXKB_ENABLED_PROVIDERS（按需）
#   MAXKB_PUBLIC_PORT（默认 8080）
```

### 3. 启动

```bash
docker compose --env-file installer/.env.split -f installer/docker-compose.split.yml up -d
```

服务清单：
- `postgres`（pgvector/pgvector:pg17）
- `redis`（redis:7-alpine）
- `maxkb-app`（Web/Gunicorn，单实例运行 schema migrate）
- `maxkb-worker-rag`（消费 rag_parse + rag_embedding + rag_index 三队列）
- `maxkb-worker-default`（消费 celery 默认队列：聊天 / 工作流 / 工具 / MCP / 多模态等）
- `maxkb-worker-maintenance`（消费 maintenance 队列 + 全集群唯一 apscheduler 实例）
- `maxkb-ui`（nginx，提供 `/admin` 与 `/chat` 静态资源 + API 反代到 maxkb-app）

### 4. 访问

浏览器打开 `http://<host>:${MAXKB_PUBLIC_PORT:-8080}/admin/`。

---

## 环境变量参考

### 部署开关（在 split 模式中由 docker-compose.split.yml 默认设置）

| 变量 | 默认 | 含义 |
|------|------|------|
| `MAXKB_ENABLE_UI` | `true` | 是否在后端进程内挂载前端静态文件路由。split 模式应为 `false`（UI 由 nginx 容器提供） |
| `MAXKB_ENABLE_API_DOCS` | `false` | 是否暴露 `/admin/api-doc/` 与 `/chat/api-doc/`。打开后还需要 `MAXKB_DOC_PASSWORD` |
| `MAXKB_ENABLE_EMAIL` | `false` | 是否启用邮件功能（找回密码 / 系统邮件）。关闭时改为管理员重置 |
| `MAXKB_ENABLE_SCHEDULER` | `web` 进程内为 `true`，celery 进程内为 `false` | 是否启动 apscheduler。split 部署中只在 `maxkb-worker-maintenance` 启用 |

### Provider 白名单

| 变量 | 默认 | 含义 |
|------|------|------|
| `MAXKB_ENABLED_PROVIDERS` | `all` | 启用的 provider 名单。`all` = 全部启用；也可填逗号分隔子集精简部署 |

精简部署示例（覆盖文本/图片/音频/视频四类模态的 9 项最小集）：

```
model_openai_provider,model_anthropic_provider,model_siliconCloud_provider,
aliyun_bai_lian_model_provider,model_volcanic_engine_provider,
model_ollama_provider,model_vllm_provider,model_xinference_provider,model_docker_ai_provider
```

第三方 OpenAI 兼容端点（DeepSeek / Kimi / vLLM / 自部署 Ollama-OpenAI 等）通过 `model_openai_provider` 接入：在前端添加模型时填写自定义 `API URL`。

### Celery 队列拆分

| 变量 | 默认 | 含义 |
|------|------|------|
| `MAXKB_TASK_QUEUE_PREFIX_ENABLED` | unset | 设为 `1` 启用按任务名前缀路由到 5 个专项队列。**生产者侧（maxkb-app）和消费者侧（worker）都必须设置**，否则路由不生效 |

### RAG 与数据库

| 变量 | 默认 | 含义 |
|------|------|------|
| `MAXKB_HNSW_INDEX_MIN_ROWS` | `5000` | 知识库 embedding 行数低于此值时跳过 HNSW 索引构建（用复合 btree 索引兜底） |

### 沙箱（按需调整）

`MAXKB_SANDBOX_PYTHON_BANNED_HOSTS` 默认禁止访问回环 + Docker bridge + 常见 service 名。在 split 部署中，如沙箱内代码确实需要访问 `postgres` / `redis` service 名，再显式覆盖：

```yaml
# docker-compose.split.yml 中按需添加
maxkb-worker-default:
  environment:
    MAXKB_SANDBOX_PYTHON_BANNED_HOSTS: "127.0.0.0/8,localhost,169.254.0.0/16,::1/128"
```

---

## 多 worker 扩容策略

| 用户场景 | 扩容对象 |
|---------|---------|
| 知识库导入并发高 | 增加 `maxkb-worker-rag` 副本数 |
| 用户聊天/工作流并发高 | 增加 `maxkb-worker-default` 副本数 |
| 调度任务多 | **不要**多副本 `maxkb-worker-maintenance`——会重复执行 |

副本扩容示例：

```bash
docker compose -f installer/docker-compose.split.yml up -d --scale maxkb-worker-rag=3
```

---

## 数据库 migration

`maxkb-app` 启动时自动跑 `manage.py migrate`（main.py 入口）。worker 容器通过 `manage.py` 直接启动 worker，不跑 migrate（避免多容器并发竞争）。

升级流程：

```bash
# 1. 更新代码 / 镜像
docker pull maxkb-app:new-tag
docker pull maxkb-ui:new-tag

# 2. 滚动重启（maxkb-app 优先，里面自动跑 migrate）
docker compose -f installer/docker-compose.split.yml up -d --no-deps maxkb-app
docker compose -f installer/docker-compose.split.yml up -d --no-deps maxkb-worker-rag maxkb-worker-default maxkb-worker-maintenance maxkb-ui
```

涉及到 Phase 6 的数据库变更（embedding 增加 workspace_id 列、新增 4 个索引）：
- 新增列带 `db_default 'default'`，老二进制 INSERT 不带此列也能写
- 新增索引使用 `CREATE INDEX CONCURRENTLY`，不会锁写
- 大表（embedding 行数 1000 万+）的 GIN 索引建立可能数十分钟，期间表仍可读写

如果 migration 中途中断留下 INVALID 索引：

```sql
-- 检测
SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
-- 清理后重新跑 migration
DROP INDEX CONCURRENTLY <invalid_index_name>;
```

---

## 回滚

数据库 migration 0008-0010 全部为加字段加索引，**不删字段**。意味着：

- 新代码 + 旧 schema：会缺索引，性能退化但不出错
- 旧代码 + 新 schema：embedding 表多了 workspace_id 列（有 DB DEFAULT），老二进制 INSERT 不传该列时仍能写入；其它索引对老代码透明

回滚操作：

```bash
# 仅还原代码 / 镜像
docker compose -f installer/docker-compose.split.yml down
docker pull maxkb-app:old-tag
docker pull maxkb-ui:old-tag
docker compose -f installer/docker-compose.split.yml up -d
```

不需要 `migrate --reverse`。
