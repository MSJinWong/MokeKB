# MokeKB 在 WSL 中的本地开发指南

适用于 Windows 用户在 **WSL2 + Ubuntu 24.04** 上跑 MokeKB 的开发模式（不通过 Docker，直接跑后端 / Worker / 前端）。Linux 用户也可参考，跳过 WSL 部分。

---

## 0. 总览

```
WSL2 (Ubuntu 24.04)
├── PostgreSQL 17 + pgvector  (端口 5432)
├── Redis 7                   (端口 6379)
├── Python 3.11 venv          → MokeKB 后端 Web (端口 8080)
├── Python 3.11 venv          → MokeKB Celery worker
└── Node 24                   → Vue UI dev server (端口 3000 admin / 3001 chat)
```

---

## 1. 启动 WSL2

如果 Ubuntu 实例已存在但停止：

```powershell
# 在 Windows PowerShell
wsl --list --verbose
wsl -d Ubuntu
```

如果还没装：

```powershell
wsl --install -d Ubuntu-24.04
```

进入 WSL 后续命令都在 Ubuntu shell 里跑。

> 💡 性能建议：把项目 clone 到 `~/projects/` 而不是 `/mnt/d/`。WSL 跨 9P 文件系统访问 Windows 盘速度极慢（npm install 会慢 10x）。

---

## 2. 安装系统依赖

```bash
sudo apt update
sudo apt install -y \
    build-essential gcc g++ make \
    libffi-dev libexpat1-dev libpq-dev \
    git curl wget vim \
    python3.11 python3.11-venv python3.11-dev \
    redis-server \
    ffmpeg \
    gettext
```

### 2.1 PostgreSQL 17 + pgvector

Ubuntu 24.04 默认源只有 PG 16。装 17 用 PostgreSQL 官方源：

```bash
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
    --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
    https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list'
sudo apt update
sudo apt install -y postgresql-17 postgresql-17-pgvector
```

启动并初始化用户 / 数据库：

```bash
sudo systemctl start postgresql
# WSL 没有 systemd 时用：sudo service postgresql start
sudo -u postgres psql <<'EOF'
CREATE USER maxkb WITH PASSWORD 'maxkb_dev';
CREATE DATABASE maxkb OWNER maxkb;
\c maxkb
CREATE EXTENSION IF NOT EXISTS vector;
EOF
```

> WSL2 默认无 systemd。开启方法：编辑 `/etc/wsl.conf`，加：
> ```ini
> [boot]
> systemd=true
> ```
> 然后 `wsl --shutdown` 后重进。

### 2.2 Redis

```bash
sudo systemctl start redis-server
# 或 sudo service redis-server start

# 设密码
sudo sed -i 's/^# requirepass .*/requirepass maxkb_redis_dev/' /etc/redis/redis.conf
sudo systemctl restart redis-server

# 验证
redis-cli -a maxkb_redis_dev ping  # PONG
```

### 2.3 Node 24

```bash
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs
node --version  # v24.x
```

### 2.4 uv（Python 包管理器，比 pip 快 10x）

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# 重开 shell 或 source ~/.bashrc
uv --version
```

---

## 3. 克隆代码与 Python 环境

```bash
mkdir -p ~/projects && cd ~/projects
# 你已经有 D:\GitRepo\MokeKB；可以软链或重新 clone
git clone <你的远程 url> MokeKB && cd MokeKB
git checkout release-2.9-simplify

# 创建 venv
python3.11 -m venv .venv
source .venv/bin/activate

# 装依赖（含所有 extras 用于完整开发体验）
uv pip install -e ".[local-model,multimodal,providers-cn,providers-extras,tools]"

# 编译沙箱 .so（工具执行需要，不编译会报 "missing sandbox.so"）
mkdir -p sandbox/lib
gcc -shared -fPIC -o sandbox/lib/sandbox.so installer/sandbox.c -ldl
```

> 如果你**不需要**本地模型（用 OpenAI 官方 API 完全够），可以省略 `local-model` extra：
> ```bash
> uv pip install -e ".[multimodal,providers-cn,providers-extras,tools]"
> ```
> 这能省 ~3 GB（torch + sentence-transformers）。

---

## 4. 配置文件

MokeKB 通过 `MAXKB_*` 前缀的环境变量读配置，或读取 `/opt/maxkb/conf/config.yml`。开发时用环境变量最方便。

创建 `~/projects/MokeKB/.env.dev`：

```env
# === 数据库 ===
MAXKB_CONFIG_TYPE=ENV
MAXKB_DB_NAME=maxkb
MAXKB_DB_HOST=127.0.0.1
MAXKB_DB_PORT=5432
MAXKB_DB_USER=maxkb
MAXKB_DB_PASSWORD=maxkb_dev

# === Redis ===
MAXKB_REDIS_HOST=127.0.0.1
MAXKB_REDIS_PORT=6379
MAXKB_REDIS_PASSWORD=maxkb_redis_dev
MAXKB_REDIS_DB=0

# === Django ===
MAXKB_SECRET_KEY=dev-only-not-for-prod-change-me
MAXKB_LOG_LEVEL=DEBUG

# === Phase 1-6 开关（开发时全开，方便调试） ===
MAXKB_ENABLE_API_DOCS=true
MAXKB_DOC_PASSWORD=maxkb
MAXKB_ENABLE_EMAIL=false
MAXKB_ENABLE_UI=true
MAXKB_ENABLE_SCHEDULER=true

# === Provider 白名单（开发时建议 all 方便切换测试） ===
MAXKB_ENABLED_PROVIDERS=all

# === Sandbox ===
MAXKB_SANDBOX=0   # 开发关掉，工具直接跑 host python，省得每次编译沙箱
MAXKB_SANDBOX_HOME=/home/$USER/projects/MokeKB/sandbox
MAXKB_SANDBOX_PYTHON_PACKAGE_PATHS=/home/$USER/projects/MokeKB/.venv/lib/python3.11/site-packages
MAXKB_SANDBOX_PYTHON_BANNED_HOSTS=127.0.0.0/8,localhost

# === Celery 队列（开发时不开拆分，单队列简单） ===
# MAXKB_TASK_QUEUE_PREFIX_ENABLED=1
```

加载到当前 shell：

```bash
set -a; source .env.dev; set +a
```

> 把 `set -a; source .env.dev; set +a` 加到你的 venv activate 脚本里：
> ```bash
> echo 'set -a; source ~/projects/MokeKB/.env.dev; set +a' >> .venv/bin/activate
> ```

---

## 5. 数据库初始化

```bash
cd ~/projects/MokeKB
source .venv/bin/activate

# 跑迁移（apps 在 sys.path 里靠 main.py，开发用 manage.py 也可以）
python apps/manage.py migrate

# 验证 Phase 6 的列与索引都在
psql "host=127.0.0.1 user=maxkb dbname=maxkb password=maxkb_dev" <<'EOF'
\d embedding
SELECT indexname FROM pg_indexes WHERE tablename='embedding' ORDER BY indexname;
SELECT count(*) FROM embedding WHERE workspace_id IS NULL OR workspace_id='';
EOF
```

期望输出：
- `\d embedding` 看到 `workspace_id` 列，`default 'default'::character varying`
- 索引列表包含：`embedding_kid_active_stype_idx`、`embedding_search_vector_gin`、`embedding_document_id_idx`、`embedding_paragraph_id_idx`
- null count 为 0

---

## 6. 启动开发模式

需要 **3 个终端**（或 tmux split）。每个都要先 `source .venv/bin/activate` + 加载 .env.dev。

### 终端 A: Web 后端

```bash
python main.py dev web
# 监听 0.0.0.0:8080
```

`main.py dev` 会自动跑 `collect_static` + `migrate` + `runserver`。代码改动会热重载。

### 终端 B: Celery worker

```bash
python main.py dev celery
```

如果想测试 Phase 5 的多队列模式：

```bash
export MAXKB_TASK_QUEUE_PREFIX_ENABLED=1
python apps/manage.py start celery_rag_parse celery_rag_embedding celery_rag_index celery_celery celery_maintenance
```

### 终端 C: 前端 dev server

```bash
cd ui
npm install
npm run dev   # admin 在 http://localhost:3000/admin/
# 或：
npm run chat  # chat 在 http://localhost:3001/chat/
```

vite proxy 已经把 `/admin/api/*` 和 `/chat/api/*` 转发到 `127.0.0.1:8080`，前端开发不用关心 CORS。

---

## 7. 冒烟流程

浏览器打开 `http://localhost:3000/admin/`，默认账号：
- 用户名 `admin`
- 密码 `MaxKB@123..` （首次登录强制改密）

依次走：

1. **新建知识库** → 选 OpenAI 兼容 embedding model（填 api_base + api_key + 自定义 model name + dimensions）
2. **上传文档**（任意 .txt 或 .md）→ 等待 worker 状态变绿
3. **命中测试** → 输入查询，应返回相关段落
4. **新建应用** → 绑定知识库 → 发起对话

---

## 8. 测试 Phase 1-6 的开关

### 8.1 邮件 disabled 路径

```bash
export MAXKB_ENABLE_EMAIL=false
# 重启 Web
curl -X POST http://localhost:8080/admin/api/user/send_email \
  -H 'Content-Type: application/json' \
  -d '{"email":"a@b.c","type":"reset_password"}'
# 期望：HTTP 200 + body 含 "code":1004 + "Email feature is disabled"
```

### 8.2 管理员重置他人密码

```bash
# 先取 admin token
TOKEN=$(curl -s -X POST http://localhost:8080/admin/api/user/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"MaxKB@123.."}' \
  | python -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")

# 用 admin 重置普通用户密码
curl -X POST http://localhost:8080/admin/api/user/admin_reset_password \
  -H "AUTHORIZATION: $TOKEN" -H 'Content-Type: application/json' \
  -d '{"target_user_id":"<用户uuid>","new_password":"NewPwd@2026"}'
```

### 8.3 Provider 白名单

```bash
# 全量
export MAXKB_ENABLED_PROVIDERS=all
# 重启，应在前端模型 → 添加模型 → 选择厂商时看到 21 个

# 精简
export MAXKB_ENABLED_PROVIDERS=model_openai_provider,model_anthropic_provider
# 重启，前端只列 OpenAI + Anthropic
```

### 8.4 HNSW 阈值

```bash
# 设小阈值方便测试（默认 5000）
export MAXKB_HNSW_INDEX_MIN_ROWS=10
# 重启 worker；上传文档 → 段落 ≥10 时建索引
psql "..." -c "SELECT indexname FROM pg_indexes WHERE indexname LIKE 'embedding_hnsw_idx_%';"
```

### 8.5 队列拆分

```bash
export MAXKB_TASK_QUEUE_PREFIX_ENABLED=1
python apps/manage.py start celery_rag_parse celery_rag_embedding celery_rag_index celery_maintenance celery_celery
# 上传文档，观察日志中 task 名字 + 队列名

# 用 celery inspect 验证
celery -A ops inspect active_queues
```

---

## 9. 常见问题

### `ImportError: libpq.so.5: cannot open shared object`

```bash
sudo apt install -y libpq5
```

### Sandbox 报错 `Permission denied to create subprocess`

开发模式建议关沙箱：

```bash
export MAXKB_SANDBOX=0
```

### 前端 npm install 慢

```bash
npm config set registry https://registry.npmmirror.com
npm install --prefer-offline
```

### WSL2 systemd 不工作

`/etc/wsl.conf` 加：

```ini
[boot]
systemd=true
```

然后 PowerShell `wsl --shutdown`，重进。

### Migration 失败 `relation "embedding_hnsw_idx_..." already exists`

Phase 6 fix 已加 `IF NOT EXISTS`。如果你停在更早版本：

```sql
DROP INDEX IF EXISTS embedding_hnsw_idx_<uuid>;
```

---

## 10. 下一步

- 跑通本文档后，对照 `docs/deployment-docker.md` 验证 docker 部署
