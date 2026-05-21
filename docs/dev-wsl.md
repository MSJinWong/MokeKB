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

> ⚠️ **Ubuntu 24.04 默认源没有 `python3.11`**（默认是 3.12）。必须先加 deadsnakes PPA：
>
> ```bash
> sudo apt install -y software-properties-common
> sudo add-apt-repository -y ppa:deadsnakes/ppa
> sudo apt update
> ```

```bash
sudo apt update
sudo apt install -y \
    build-essential gcc g++ make \
    libffi-dev libexpat1-dev libpq-dev libpq5 \
    git curl wget vim \
    python3.11 python3.11-venv python3.11-dev \
    redis-server \
    ffmpeg \
    gettext \
    postgresql-client-16
```

> `postgresql-client-16` 提供 `psql` 命令，用于验证远程 / 本地 PG 连通性。能连到 PG 17 服务端，不要求版本完全一致。

### 2.1 PostgreSQL 17 + pgvector（可选：使用远程 PG 时跳过本节）

> **使用远程 / 云 PG**（如 RDS、阿里云 PG、自建集群）的同学跳过本节。仅需用 §2 已装的 `psql` 客户端验证：
>
> ```bash
> # 替换成真实凭据
> PGPASSWORD=<pwd> psql -h <host> -p <port> -U <user> -d <db> -c "SELECT version();"
> PGPASSWORD=<pwd> psql -h <host> -p <port> -U <user> -d <db> -c "SELECT extname, extversion FROM pg_extension WHERE extname='vector';"
> ```
>
> 期望：第一条返回 PG 版本号；第二条至少返回一行 `vector`（如果没有，需要 DBA 给库开启 `CREATE EXTENSION vector;`，pgvector ≥ 0.7 推荐）。

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

# 装依赖（注意：release-2.9-simplify 已移除 local-model extra）
uv pip install -e ".[multimodal,providers-cn,providers-extras,tools]"

# 编译沙箱 .so（仅当 MAXKB_SANDBOX=1 时需要；dev 设 MAXKB_SANDBOX=0 可跳过）
mkdir -p sandbox/lib
gcc -shared -fPIC -o sandbox/lib/sandbox.so installer/sandbox.c -ldl
```

> **最小安装**（只跑核心 API，不接任何第三方厂商 SDK）：
> ```bash
> uv pip install -e .
> ```
> 这能省 ~1 GB（dashscope / qianfan / langchain-aws 等）。

### 3.1 系统目录权限（必做）

后端在以下路径写入文件，路径在代码里**硬编码**：
- `/opt/maxkb/logs` — Django 日志（见 `apps/maxkb/const.py:12` `LOG_DIR`）
- `/opt/maxkb-app/tmp` — jieba 缓存等临时文件（见 `main.py:98` `TMPDIR`）

预先建好并改 owner：

```bash
sudo mkdir -p /opt/maxkb/logs /opt/maxkb-app/tmp
sudo chown -R $USER:$USER /opt/maxkb /opt/maxkb-app
```

漏做的后果：`python main.py dev web` 启动时报 `PermissionError: [Errno 13] Permission denied: '/opt/maxkb'`。

---

## 4. 配置文件

MokeKB 通过 `MAXKB_*` 前缀的环境变量读配置，或读取 `/opt/maxkb/conf/config.yml`。开发时用环境变量最方便。

> ⚠️ **`MAXKB_CONFIG_TYPE=ENV` 是必填项**。`apps/maxkb/conf.py:258-262` 默认走 yml 文件分支；只有当此变量**恰好**等于字符串 `ENV` 时才走环境变量分支。漏掉就会报：
> ```
> ImportError: Error: No config file found.
> ```

> 💡 **粘贴 heredoc 注意**：部分终端（Windows Terminal + WSL 在某些复制路径下）会给粘贴的多行内容**每行加 2 个前导空格**，导致 `EOF` 不被识别为结束符、且 `grep '^MAXKB_'` 匹配不到行。若粘贴后 `grep -c '^MAXKB_' .env.dev` 返回 0，一条命令修：
> ```bash
> sed -i -e 's/^ *//' -e '/^EOF$/d' .env.dev
> ```
> 或全程改用 `nano .env.dev` 编辑，避免这个问题。

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

# 加载 .env.dev 到当前 shell（每个新终端都要做）
set -a; source .env.dev; set +a

# 验证关键变量到位（应看到 5 行；特别是 MAXKB_CONFIG_TYPE=ENV）
env | grep -E '^MAXKB_(CONFIG_TYPE|DB_HOST|REDIS_HOST|SECRET_KEY|SANDBOX)='

# 跑迁移：推荐 main.py upgrade_db（自带带退避的重试）
python main.py upgrade_db
# 也可用 python apps/manage.py migrate；功能等价，但没有重试逻辑

# 验证 Phase 6 的列与索引都在（本地或远程 PG 都行，按你的 .env.dev 改）
PGPASSWORD=$MAXKB_DB_PASSWORD psql -h $MAXKB_DB_HOST -p $MAXKB_DB_PORT -U $MAXKB_DB_USER -d $MAXKB_DB_NAME <<'EOF'
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

启动成功后浏览器验证（WSL2 默认把端口转发到 Windows，直接 localhost 即可）：

| URL | 说明 |
|---|---|
| http://localhost:8080/admin/api/profile | API 探针；未登录返回 401 或匿名 profile |
| http://localhost:8080/admin/api-doc/ | 管理端 Swagger UI（需 `MAXKB_ENABLE_API_DOCS=true` + `MAXKB_DOC_PASSWORD` 非空，见 `apps/common/init/init_doc.py:46`） |
| http://localhost:8080/chat/api-doc/ | 对话端 Swagger UI |
| http://localhost:8080/admin/api-doc/schema/ | 原始 OpenAPI JSON |

> `MAXKB_DOC_PASSWORD` 的作用是**让 doc 路由本身被注册**（非空即可），不是 Basic Auth 密码。

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

### `E: Unable to locate package python3.11`（Ubuntu 24.04）

24.04 默认源没有 3.11，先加 deadsnakes PPA（已在 §2 写明）：

```bash
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev
```

### `ModuleNotFoundError: No module named 'jinja2'`

`apps/common/init/init_template.py` import 了 `jinja2`，但旧版本 `pyproject.toml` 漏声明。当前已在 `pyproject.toml` 加上 `jinja2==3.1.5`；如你的 venv 是在修复前建的，重装一次依赖即可：

```bash
uv pip install -e ".[multimodal,providers-cn,providers-extras,tools]"
# 或临时打补丁：
uv pip install jinja2
```

### `PermissionError: [Errno 13] Permission denied: '/opt/maxkb'`

`apps/maxkb/const.py:12` 把 `LOG_DIR` 写死成 `/opt/maxkb/logs`。建好目录 + 改 owner（见 §3.1）：

```bash
sudo mkdir -p /opt/maxkb/logs /opt/maxkb-app/tmp
sudo chown -R $USER:$USER /opt/maxkb /opt/maxkb-app
```

### `ImportError: Error: No config file found.`

`MAXKB_CONFIG_TYPE=ENV` 没设。`apps/maxkb/conf.py:258-262` 默认走 yml 分支，必须显式设此变量为 `ENV` 才会读环境变量。

### `grep -c '^MAXKB_' .env.dev` 返回 0（变量没生效）

终端粘贴 heredoc 时给每行加了 2 个前导空格，导致 `EOF` 不识别为结束符且 `^MAXKB_` 匹配不到。一条命令修：

```bash
sed -i -e 's/^ *//' -e '/^EOF$/d' .env.dev
```

之后用 `nano .env.dev` 编辑可彻底避免。

### Migration 警告：`Your models in app(s): 'system_manage', 'tools' have changes that are not yet reflected`

`release-2.9-simplify` 分支上 model 改动尚未生成 migration。**不阻塞启动**，但运行时如撞到 `column does not exist`，再生成迁移：

```bash
python apps/manage.py makemigrations system_manage tools
# 先看 diff 再 apply：
python apps/manage.py migrate
```

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
