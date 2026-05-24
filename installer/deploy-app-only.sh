#!/usr/bin/env bash
# Interactive deployment script for MokeKB backend-only.
# Assumes: Ubuntu host. External PostgreSQL (with pgvector) and Redis on
# separate machines. Frontend deployed elsewhere.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MSJinWong/MokeKB/feat/frontend-redesign/installer/deploy-app-only.sh -o deploy.sh
#   chmod +x deploy.sh
#   ./deploy.sh
#
# Env overrides:
#   MOKEKB_BRANCH=main ./deploy.sh        # download compose from a different ref
#   MOKEKB_DIR=/srv/mokekb ./deploy.sh    # default working dir

set -euo pipefail

# === Config ===
REPO="${MOKEKB_REPO:-MSJinWong/MokeKB}"
BRANCH="${MOKEKB_BRANCH:-feat/frontend-redesign}"
DEFAULT_IMAGE="ghcr.io/msjinwong/mokekb-app:dev"
DEFAULT_DIR="${MOKEKB_DIR:-$HOME/mokekb}"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/installer"
COMPOSE_URL="${RAW_BASE}/docker-compose.app-only.yml"

# === Colors (auto-disable when not a TTY) ===
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

info()  { echo "${C_BLUE}[*]${C_RESET} $*" >&2; }
ok()    { echo "${C_GREEN}[✓]${C_RESET} $*" >&2; }
warn()  { echo "${C_YELLOW}[!]${C_RESET} $*" >&2; }
err()   { echo "${C_RED}[✗]${C_RESET} $*" >&2; }

# === Prompt helpers (prompts go to stderr; value comes back via stdout) ===
ask() {
  local prompt="$1" default="${2:-}" var
  if [ -n "$default" ]; then
    read -rp "$prompt [$default]: " var
    var="${var:-$default}"
  else
    read -rp "$prompt: " var
  fi
  printf '%s' "$var"
}

ask_required() {
  local prompt="$1" var
  while true; do
    var=$(ask "$prompt")
    if [ -n "$var" ]; then
      printf '%s' "$var"; return
    fi
    warn "不能为空"
  done
}

ask_secret() {
  local prompt="$1" var
  read -rsp "$prompt: " var
  echo >&2
  printf '%s' "$var"
}

ask_secret_required() {
  local prompt="$1" var
  while true; do
    var=$(ask_secret "$prompt")
    if [ -n "$var" ]; then
      printf '%s' "$var"; return
    fi
    warn "不能为空"
  done
}

ask_yes_no() {
  local prompt="$1" default="${2:-y}" var
  while true; do
    if [ "$default" = "y" ]; then
      read -rp "$prompt [Y/n]: " var; var="${var:-y}"
    else
      read -rp "$prompt [y/N]: " var; var="${var:-n}"
    fi
    case "$var" in
      [yY]|[yY][eE][sS]) return 0 ;;
      [nN]|[nN][oO])     return 1 ;;
      *) warn "请输入 y 或 n" ;;
    esac
  done
}

# Read a value from a .env-style file WITHOUT shell-evaluating it.
# Value is taken literally from the `KEY=...` line. Returns empty if key absent.
# This intentionally bypasses `source` to avoid command-injection / quoting bugs
# when the file contains special chars (e.g. passwords with $, ", spaces).
parse_env_value() {
  local key="$1" file="$2" line k
  [ -f "$file" ] || return 0
  while IFS= read -r line; do
    case "$line" in
      \#*|'') continue ;;
    esac
    k="${line%%=*}"
    if [ "$k" = "$key" ]; then
      printf '%s' "${line#*=}"
      return 0
    fi
  done < "$file"
}

# Compare image arch with host. Warns and prompts on mismatch.
# Critical for offline tar (workflow only produces linux/amd64) loaded onto
# ARM hosts — without QEMU the container fails with `exec format error`.
check_image_arch() {
  local image="$1" img_arch host_arch host_norm
  img_arch=$(docker image inspect "$image" -f '{{.Architecture}}' 2>/dev/null || echo unknown)
  host_arch=$(uname -m)
  case "$host_arch" in
    x86_64|amd64)  host_norm=amd64 ;;
    aarch64|arm64) host_norm=arm64 ;;
    *) host_norm="$host_arch" ;;
  esac
  if [ "$img_arch" = "unknown" ]; then
    warn "无法读取镜像架构"
    return 0
  fi
  if [ "$img_arch" != "$host_norm" ]; then
    err "镜像架构 ($img_arch) 与主机 ($host_arch -> $host_norm) 不一致"
    err "运行将依赖 QEMU 模拟（性能很差），或直接 'exec format error'"
    ask_yes_no "仍要继续？" n || exit 1
  else
    ok "架构匹配: $img_arch"
  fi
}

# Warn if image tag is mutable (dev/latest/edge/nightly) — bad for reproducibility.
warn_mutable_tag() {
  local image="$1" tag="${1##*:}"
  case "$tag" in
    dev|latest|edge|nightly)
      warn "镜像使用 mutable tag ':$tag'"
      warn "生产环境建议改用版本号 tag（如 :v2.8.0）以保证可复现 / 回滚 / 审计" ;;
  esac
}

# === 1. environment check ===
step_check_env() {
  info "Step 1/6: 检查环境"

  if [ -f /etc/os-release ] && ! grep -qi "ubuntu" /etc/os-release; then
    warn "未检测到 Ubuntu，脚本可能仍可工作但只在 Ubuntu 测试过。"
  fi

  local missing=()
  command -v curl    >/dev/null 2>&1 || missing+=("curl")
  command -v docker  >/dev/null 2>&1 || missing+=("docker.io")
  docker compose version >/dev/null 2>&1 || missing+=("docker-compose-plugin")
  command -v nc      >/dev/null 2>&1 || missing+=("netcat-openbsd")
  command -v openssl >/dev/null 2>&1 || missing+=("openssl")

  if [ ${#missing[@]} -gt 0 ]; then
    warn "缺少: ${missing[*]}"
    if ask_yes_no "是否用 apt 安装？（需要 sudo）" y; then
      sudo apt-get update
      sudo apt-get install -y "${missing[@]}"
    else
      err "请先安装这些依赖"; exit 1
    fi
  fi

  if ! docker info >/dev/null 2>&1; then
    if ! groups | grep -qw docker && [ "$(id -u)" -ne 0 ]; then
      warn "当前用户不在 docker 组。运行下面命令后重新登录："
      warn "  sudo usermod -aG docker \$USER && newgrp docker"
    fi
    err "docker daemon 不可用"; exit 1
  fi

  ok "docker $(docker --version | awk '{print $3}' | tr -d ',')"
  ok "docker compose $(docker compose version --short 2>/dev/null || echo unknown)"
}

# === 2. image source ===
step_get_image() {
  info "Step 2/6: 镜像准备"
  echo "  1) 在线 — 从 GHCR 拉取（默认）" >&2
  echo "  2) 离线 — 加载已下载的 tar.gz" >&2
  local choice
  choice=$(ask "选择" "1")

  case "$choice" in
    1)
      IMAGE=$(ask "镜像 ref" "$DEFAULT_IMAGE")
      if ask_yes_no "镜像是 private？需要先登录 ghcr.io？" n; then
        local user pat
        user=$(ask "GitHub 用户名" "MSJinWong")
        pat=$(ask_secret "GitHub PAT (scope=read:packages)")
        echo "$pat" | docker login ghcr.io -u "$user" --password-stdin
      fi
      info "docker pull $IMAGE"
      docker pull "$IMAGE"
      ;;
    2)
      local tar
      tar=$(ask_required "tar.gz 文件路径（如 ./mokekb-app-dev-linux-amd64.tar.gz）")
      [ -f "$tar" ] || { err "文件不存在: $tar"; exit 1; }
      if [ -f "${tar}.sha256" ]; then
        info "校验 sha256"
        ( cd "$(dirname "$tar")" && sha256sum -c "$(basename "${tar}.sha256")" ) \
          || { err "sha256 校验失败"; exit 1; }
      else
        warn "未找到 ${tar}.sha256，跳过校验"
      fi
      local load_out
      load_out=$(docker load < "$tar")
      IMAGE=$(printf '%s\n' "$load_out" | sed -n 's/^Loaded image: //p' | head -1)
      [ -n "$IMAGE" ] || { err "无法识别加载的镜像名"; exit 1; }
      ok "加载完成: $IMAGE"
      ;;
    *)
      err "无效选择"; exit 1 ;;
  esac

  check_image_arch "$IMAGE"
  warn_mutable_tag "$IMAGE"
}

# === 3. workdir + compose ===
step_workdir() {
  info "Step 3/6: 工作目录"
  WORKDIR=$(ask "部署目录" "$DEFAULT_DIR")
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  if [ -f docker-compose.yml ]; then
    if ask_yes_no "docker-compose.yml 已存在，重新下载？" n; then
      mv docker-compose.yml "docker-compose.yml.bak.$(date +%s)"
      curl -fsSL -o docker-compose.yml "$COMPOSE_URL"
      ok "已重新下载 docker-compose.yml"
    fi
  else
    curl -fsSL -o docker-compose.yml "$COMPOSE_URL"
    ok "下载 docker-compose.yml"
  fi
}

# === 4. configure .env ===
step_configure() {
  info "Step 4/6: 配置 .env"

  if [ -f .env ] && ! ask_yes_no ".env 已存在，重新配置？（会备份原文件）" n; then
    ok "保留现有 .env"
    PG_HOST=$(parse_env_value MAXKB_DB_HOST .env)
    PG_PORT=$(parse_env_value MAXKB_DB_PORT .env)
    PG_USER=$(parse_env_value MAXKB_DB_USER .env)
    PG_PASS=$(parse_env_value MAXKB_DB_PASSWORD .env)
    PG_DB=$(parse_env_value MAXKB_DB_NAME .env)
    REDIS_HOST=$(parse_env_value MAXKB_REDIS_HOST .env)
    REDIS_PORT=$(parse_env_value MAXKB_REDIS_PORT .env)
    REDIS_PASS=$(parse_env_value MAXKB_REDIS_PASSWORD .env)
    BACKEND_PORT=$(parse_env_value MAXKB_BACKEND_PORT .env)

    # Compare .env's MAXKB_IMAGE with what was just pulled/loaded.
    # Without this, an offline upgrade silently deploys the OLD image
    # because docker compose reads .env, not the IMAGE variable.
    local env_image
    env_image=$(parse_env_value MAXKB_IMAGE .env)
    if [ -n "$env_image" ] && [ "$env_image" != "$IMAGE" ]; then
      warn ".env 中 MAXKB_IMAGE=$env_image"
      warn "刚刚准备的镜像  IMAGE=$IMAGE"
      if ask_yes_no "更新 .env 的 MAXKB_IMAGE 为新镜像？" y; then
        local tmpf
        tmpf=$(mktemp)
        sed "s|^MAXKB_IMAGE=.*|MAXKB_IMAGE=$IMAGE|" .env > "$tmpf"
        mv "$tmpf" .env
        chmod 600 .env
        ok "已更新 .env 中的 MAXKB_IMAGE"
      else
        info "保持 .env 原值；后续部署将使用 $env_image"
        IMAGE="$env_image"
      fi
    fi
    return
  fi
  [ -f .env ] && cp .env ".env.bak.$(date +%s)"

  echo >&2
  echo "${C_BOLD}PostgreSQL（必须支持 pgvector 扩展）${C_RESET}" >&2
  PG_HOST=$(ask_required "PG host (IP / hostname)")
  PG_PORT=$(ask "PG port" "5432")
  PG_USER=$(ask "PG user" "maxkb")
  PG_PASS=$(ask_secret_required "PG password")
  PG_DB=$(ask   "PG database" "maxkb")

  echo >&2
  echo "${C_BOLD}Redis${C_RESET}" >&2
  REDIS_HOST=$(ask_required "Redis host")
  REDIS_PORT=$(ask "Redis port" "6379")
  REDIS_PASS=$(ask_secret_required "Redis password")
  REDIS_DB=$(ask   "Redis DB" "0")

  echo >&2
  BACKEND_PORT=$(ask "Backend 监听端口" "8080")

  echo >&2
  if ask_yes_no "自动生成 Django SECRET_KEY？" y; then
    DJANGO_SECRET=$(openssl rand -hex 32)
  else
    DJANGO_SECRET=$(ask_secret_required "Django SECRET_KEY")
  fi

  echo >&2
  echo "${C_BOLD}模型 Provider 白名单（all = 全部 20 个）${C_RESET}" >&2
  PROVIDERS=$(ask "MAXKB_ENABLED_PROVIDERS" \
    "model_openai_provider,model_anthropic_provider,model_siliconCloud_provider,aliyun_bai_lian_model_provider,model_volcanic_engine_provider,model_ollama_provider,model_vllm_provider,model_xinference_provider,model_docker_ai_provider")

  cat > .env <<EOF
# Generated by deploy-app-only.sh on $(date -u +'%Y-%m-%dT%H:%M:%SZ')
# Pin compose project name so volumes/networks survive workdir relocation.
COMPOSE_PROJECT_NAME=mokekb

MAXKB_IMAGE=${IMAGE}
MAXKB_BACKEND_PORT=${BACKEND_PORT}

MAXKB_DB_HOST=${PG_HOST}
MAXKB_DB_PORT=${PG_PORT}
MAXKB_DB_USER=${PG_USER}
MAXKB_DB_PASSWORD=${PG_PASS}
MAXKB_DB_NAME=${PG_DB}
MAXKB_DB_MAX_OVERFLOW=80

MAXKB_REDIS_HOST=${REDIS_HOST}
MAXKB_REDIS_PORT=${REDIS_PORT}
MAXKB_REDIS_PASSWORD=${REDIS_PASS}
MAXKB_REDIS_DB=${REDIS_DB}

MAXKB_DJANGO_SECRET_KEY=${DJANGO_SECRET}

MAXKB_ENABLED_PROVIDERS=${PROVIDERS}

MAXKB_ENABLE_API_DOCS=false
MAXKB_ENABLE_EMAIL=false
EOF
  chmod 600 .env
  ok ".env 已写入 (chmod 600)"
}

# === 5. preflight ===
step_preflight() {
  info "Step 5/6: 连通性检查"

  if nc -z -w 5 "$PG_HOST" "$PG_PORT" 2>/dev/null; then
    ok "PG 端口可达 $PG_HOST:$PG_PORT"
  else
    err "PG 端口不可达 $PG_HOST:$PG_PORT — 检查防火墙 / listen_addresses / pg_hba.conf"
    ask_yes_no "仍然继续？" n || exit 1
  fi

  if nc -z -w 5 "$REDIS_HOST" "$REDIS_PORT" 2>/dev/null; then
    ok "Redis 端口可达 $REDIS_HOST:$REDIS_PORT"
  else
    err "Redis 端口不可达 $REDIS_HOST:$REDIS_PORT"
    ask_yes_no "仍然继续？" n || exit 1
  fi

  # Optional: deeper PG check if psql available
  if command -v psql >/dev/null 2>&1; then
    if PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" \
         -tAc 'SELECT 1' >/dev/null 2>&1; then
      ok "PG 用户认证 OK，数据库 $PG_DB 可访问"

      local has_vector
      has_vector=$(PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" \
                   -tAc "SELECT 1 FROM pg_extension WHERE extname='vector'" 2>/dev/null || true)
      if [ "$has_vector" = "1" ]; then
        ok "pgvector 扩展已启用"
      else
        warn "pgvector 扩展未启用。首次启动 maxkb 会尝试自动 CREATE EXTENSION"
        warn "如果失败，需要在 PG 上以 superuser 执行："
        warn "  psql -d $PG_DB -c 'CREATE EXTENSION IF NOT EXISTS vector;'"
      fi
    else
      warn "PG 用户/密码/库名 可能有误（psql 连不上）"
      warn "如果 PG 未建库/用户，请在 PG 服务器执行下列 SQL（superuser）："
      cat >&2 <<SQL
  CREATE DATABASE $PG_DB;
  CREATE USER $PG_USER WITH PASSWORD '<填密码>';
  GRANT ALL PRIVILEGES ON DATABASE $PG_DB TO $PG_USER;
  \\c $PG_DB
  CREATE EXTENSION IF NOT EXISTS vector;
  GRANT ALL ON SCHEMA public TO $PG_USER;
SQL
      ask_yes_no "仍然继续？" n || exit 1
    fi
  else
    info "未安装 psql，跳过深度 PG 检查（apt install postgresql-client 可获取）"
  fi
}

# === 6. launch ===
step_launch() {
  info "Step 6/6: 启动"

  if ! ask_yes_no "现在执行 docker compose up -d？" y; then
    info "已写好配置但未启动。手动启动：cd $WORKDIR && docker compose up -d"
    return
  fi

  docker compose up -d

  info "等待 maxkb-app 健康检查（最长 3 分钟）"
  local i cid status
  cid=$(docker compose ps -q maxkb-app)
  for i in $(seq 1 36); do
    status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null || echo "none")
    case "$status" in
      healthy)   ok "maxkb-app 健康"; break ;;
      unhealthy) err "maxkb-app unhealthy"; docker compose logs --tail=50 maxkb-app; return 1 ;;
    esac
    sleep 5
    printf '.' >&2
  done
  echo >&2

  if [ "$status" != "healthy" ]; then
    warn "等待超时。看日志：docker compose logs -f maxkb-app"
  fi

  echo >&2
  ok "${C_BOLD}部署完成${C_RESET}"
  cat >&2 <<EOF

  管理后台：     http://<服务器 IP>:${BACKEND_PORT}/admin/
  API 健康检查： curl http://localhost:${BACKEND_PORT}/admin/api/profile

  常用命令（在 $WORKDIR 目录下）：
    docker compose ps                          # 容器状态
    docker compose logs -f maxkb-app           # web 日志
    docker compose logs -f maxkb-worker-rag    # RAG worker 日志
    docker compose restart                     # 重启
    docker compose down                        # 停止
    docker compose pull && docker compose up -d  # 升级到新 tag（先改 .env 里 MAXKB_IMAGE）

EOF
}

# === Main ===
main() {
  echo "${C_BOLD}MokeKB Backend-only 交互式部署${C_RESET}" >&2
  echo "目标：Ubuntu host + 外部 PG（pgvector） + 外部 Redis + 独立前端" >&2
  echo >&2

  step_check_env;  echo >&2
  step_get_image;  echo >&2
  step_workdir;    echo >&2
  step_configure;  echo >&2
  step_preflight;  echo >&2
  step_launch
}

main "$@"
