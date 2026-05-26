#!/usr/bin/env bash
# Standalone PostgreSQL (pgvector) installer for HoyanAI.
#
# Runs INDEPENDENTLY of docker-compose.app-only.yml. PG lives in its own
# container, binds to 127.0.0.1:5432, and the backend stack reaches it via
# host.docker.internal (configured in docker-compose.app-only.yml).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MSJinWong/MokeKB/feat/frontend-redesign/installer/install-postgres.sh -o install-pg.sh
#   chmod +x install-pg.sh
#   ./install-pg.sh           # 首次跑会交互式让你设置密码（自动生成或手输）
#
# Re-runs: 自动读取 PG_CREDENTIALS_FILE 里保存的密码做 pg_dump 备份，
# 然后用同一个密码重启容器。数据卷保留。

set -euo pipefail

# ============================================================
# Configuration — edit these to customize (密码不在这里，运行时交互输入)
# ============================================================
PG_IMAGE="pgvector/pgvector:pg17"
PG_CONTAINER="hoyanai-postgres"
PG_DATA_DIR="/opt/hoyanai-pg/data"
PG_BACKUP_DIR="/opt/hoyanai-pg/backups"
PG_CREDENTIALS_FILE="/opt/hoyanai-pg/.password"   # chmod 0600，记住交互输入的密码
# 必须绑 0.0.0.0：docker 容器走 host.docker.internal 解析到 docker bridge gw（如 172.17.0.1），
# 而 127.0.0.1 不在 bridge gw 上。 绑 0.0.0.0 后容器才能连过来。
# 防护手段：(1) 云厂商安全组拒绝 5432 入站；(2) 物理防火墙规则；(3) docker 默认 iptables
# 隔离让 LAN 直连 docker0 网关比较难。如果你的部署环境特殊，改成 "172.17.0.1:5432" 也行。
PG_PORT_BIND="0.0.0.0:5432"
PG_DB="hoyanai"
PG_USER="hoyanai"
PG_MAX_CONNECTIONS=1000
BACKUP_RETENTION_DAYS=7
# ============================================================

# 填充自 step_password
PG_PASSWORD=""

# Colors (auto-disable when not a TTY)
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

# ===== prompt helpers (mirror deploy-app-only.sh style) =====
ask() {
  local prompt="$1" default="${2:-}" var
  if [ -n "$default" ]; then
    read -erp "$prompt [$default]: " var
    var="${var:-$default}"
  else
    read -erp "$prompt: " var
  fi
  printf '%s' "$var"
}

ask_secret() {
  local prompt="$1" var
  read -rsp "$prompt: " var
  echo >&2
  printf '%s' "$var"
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

# 单引号会破坏后面写 init.sql / psql 等场景，提前拒绝
validate_password() {
  case "$1" in
    *\'*) err "密码不允许包含单引号（'），请换一个字符"; return 1 ;;
  esac
  [ -n "$1" ] || { err "密码不能为空"; return 1; }
  return 0
}

# ============================================================
# 1. Guards (docker available)
# ============================================================
step_guards() {
  info "Step 1/8: 前置检查"

  if ! command -v docker >/dev/null 2>&1; then
    err "未找到 docker"; exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    err "docker daemon 不可用（当前用户可能不在 docker 组：sudo usermod -aG docker \$USER && newgrp docker）"
    exit 1
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    warn "未找到 openssl，自动生成密码不可用（手动输入仍然 OK）"
  fi

  ok "docker $(docker --version | awk '{print $3}' | tr -d ',')"
}

# ============================================================
# 2. Password — load from credentials file or prompt
# ============================================================
step_password() {
  info "Step 2/8: PG 密码"

  if [ -f "$PG_CREDENTIALS_FILE" ]; then
    PG_PASSWORD=$(cat "$PG_CREDENTIALS_FILE")
    if ! validate_password "$PG_PASSWORD"; then
      err "凭据文件 $PG_CREDENTIALS_FILE 内容非法。删除后重跑设置新密码。"
      exit 1
    fi
    ok "从凭据文件读取已有密码: $PG_CREDENTIALS_FILE"
    return 0
  fi

  echo >&2
  echo "${C_BOLD}首次部署，设置 PG 密码${C_RESET}" >&2
  echo "  1) 自动生成强随机密码（推荐）" >&2
  echo "  2) 手动输入密码" >&2
  local choice
  choice=$(ask "选择" "1")

  case "$choice" in
    2)
      while true; do
        PG_PASSWORD=$(ask_secret "请输入 PG 密码")
        local confirm
        confirm=$(ask_secret "再次输入确认")
        if [ "$PG_PASSWORD" != "$confirm" ]; then
          warn "两次输入不一致，重试"
          continue
        fi
        validate_password "$PG_PASSWORD" || continue
        break
      done
      ;;
    *)
      if ! command -v openssl >/dev/null 2>&1; then
        err "需要 openssl 来自动生成密码，请装 openssl 或选 2 手动输入"
        exit 1
      fi
      # 去掉 /+= 等特殊字符避免 URL / shell 转义场景出问题
      PG_PASSWORD=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)
      echo >&2
      ok "已生成密码: ${C_BOLD}${PG_PASSWORD}${C_RESET}"
      warn "请立即抄写下来 — 后端部署时要填到 .env 的 MAXKB_DB_PASSWORD"
      warn "也会保存到 $PG_CREDENTIALS_FILE（chmod 600）"
      if ! ask_yes_no "继续？" y; then
        info "已取消"; exit 0
      fi
      ;;
  esac

  # 保存凭据文件
  local cred_dir
  cred_dir=$(dirname "$PG_CREDENTIALS_FILE")
  mkdir -p "$cred_dir"
  chmod 0700 "$cred_dir" 2>/dev/null || true
  # printf 比 echo 更靠谱（不在末尾加 newline 也 OK，cat 读出来一样）
  printf '%s' "$PG_PASSWORD" > "$PG_CREDENTIALS_FILE"
  chmod 0600 "$PG_CREDENTIALS_FILE"
  ok "密码已保存: $PG_CREDENTIALS_FILE (chmod 600)"
}

# ============================================================
# 3. Prepare directories
# ============================================================
step_dirs() {
  info "Step 3/8: 准备目录"

  # PG 要求 data dir 是 0700，否则启动报错
  if [ ! -d "$PG_DATA_DIR" ]; then
    mkdir -p "$PG_DATA_DIR"
    chmod 0700 "$PG_DATA_DIR"
    ok "新建 $PG_DATA_DIR (0700)"
  else
    ok "data dir 已存在: $PG_DATA_DIR"
  fi

  mkdir -p "$PG_BACKUP_DIR"
  chmod 0700 "$PG_BACKUP_DIR"
}

# ============================================================
# 4. Backup if old container is running
# ============================================================
step_backup() {
  info "Step 4/8: 检测旧容器并备份"

  local cid
  cid=$(docker ps -q -f name="^${PG_CONTAINER}$" 2>/dev/null || true)

  if [ -z "$cid" ]; then
    # Container 可能已经 stop 但还在（exited 状态）
    if docker ps -aq -f name="^${PG_CONTAINER}$" >/dev/null 2>&1; then
      local existed
      existed=$(docker ps -aq -f name="^${PG_CONTAINER}$" 2>/dev/null || true)
      if [ -n "$existed" ]; then
        warn "找到已停止的容器 $PG_CONTAINER（无法 pg_dump，将直接删除重建）"
      fi
    else
      info "首次部署，无需备份"
    fi
    return 0
  fi

  local ts
  ts=$(date +%Y%m%d-%H%M%S)
  local bak="$PG_BACKUP_DIR/${PG_DB}-${ts}.sql.gz"

  info "正在 pg_dump 到 $bak"
  # 用 PGPASSWORD env 避免命令行密码泄漏；-Fp 纯 SQL 便于人工恢复，配合 gzip
  if docker exec -e PGPASSWORD="$PG_PASSWORD" "$PG_CONTAINER" \
       pg_dump -U "$PG_USER" -d "$PG_DB" --no-owner --no-acl 2>/dev/null | gzip > "$bak"; then
    if [ -s "$bak" ]; then
      ok "备份完成: $bak ($(du -h "$bak" | cut -f1))"
    else
      err "备份文件为空，可能 pg_dump 失败（密码/用户/库名变更过？）"
      err "如果你确认旧数据可以丢，删除空备份后重跑：rm -f $bak && ./install-pg.sh"
      rm -f "$bak"
      exit 1
    fi
  else
    err "pg_dump 失败。中止以防丢数据。"
    err "如果旧容器已损坏无法备份，先用 docker cp 拷贝 $PG_DATA_DIR 然后手动清理重跑。"
    rm -f "$bak"
    exit 1
  fi
}

# ============================================================
# 5. Write init.sql for first-run extension setup
# ============================================================
step_init_sql() {
  info "Step 5/8: 准备 init.sql"

  # 注意：/docker-entrypoint-initdb.d 只在 data dir 为空时执行。
  # 已有数据的场景下 init.sql 不会再跑——这是 PG 镜像的设计，不是 bug。
  local init_dir="$PG_DATA_DIR/../init"
  mkdir -p "$init_dir"
  chmod 0755 "$init_dir"

  cat > "$init_dir/init.sql" <<EOF
-- HoyanAI PostgreSQL init script.
-- Runs ONCE on first container start (when data dir is empty).
-- POSTGRES_DB has already created the database '$PG_DB' as owner '$PG_USER'.
\\c $PG_DB;
CREATE EXTENSION IF NOT EXISTS vector;
EOF
  ok "init.sql 写入: $init_dir/init.sql"

  # 保存路径供 step_start 用
  INIT_SQL_PATH="$init_dir/init.sql"
}

# ============================================================
# 6. (Re)start container
# ============================================================
step_start() {
  info "Step 6/8: 启动容器"

  # 停旧
  docker stop "$PG_CONTAINER" 2>/dev/null || true
  docker rm   "$PG_CONTAINER" 2>/dev/null || true

  docker run -d \
    --name "$PG_CONTAINER" \
    --restart unless-stopped \
    -p "${PG_PORT_BIND}:5432" \
    -v "$PG_DATA_DIR:/var/lib/postgresql/data" \
    -v "$INIT_SQL_PATH:/docker-entrypoint-initdb.d/init.sql:ro" \
    -e POSTGRES_DB="$PG_DB" \
    -e POSTGRES_USER="$PG_USER" \
    -e POSTGRES_PASSWORD="$PG_PASSWORD" \
    "$PG_IMAGE" \
    -c max_connections="$PG_MAX_CONNECTIONS" \
    >/dev/null

  ok "容器已启动: $PG_CONTAINER"
}

# ============================================================
# 7. Wait + verify
# ============================================================
step_wait() {
  info "Step 7/8: 等待 PG 就绪"

  local i
  for i in $(seq 1 30); do
    if docker exec "$PG_CONTAINER" pg_isready -U "$PG_USER" -d "$PG_DB" >/dev/null 2>&1; then
      ok "PG 已就绪（等待 ${i}*2s）"
      break
    fi
    sleep 2
    printf '.' >&2
  done
  echo >&2

  if ! docker exec "$PG_CONTAINER" pg_isready -U "$PG_USER" -d "$PG_DB" >/dev/null 2>&1; then
    err "等待 60s 后 PG 仍未就绪"
    err "查看日志: docker logs $PG_CONTAINER"
    exit 1
  fi

  # 验证 vector 扩展（首次部署）
  local has_vector
  has_vector=$(docker exec -e PGPASSWORD="$PG_PASSWORD" "$PG_CONTAINER" \
                 psql -U "$PG_USER" -d "$PG_DB" -tAc \
                 "SELECT 1 FROM pg_extension WHERE extname='vector'" 2>/dev/null || true)
  if [ "$has_vector" = "1" ]; then
    ok "pgvector 扩展已启用"
  else
    warn "pgvector 扩展未启用（init.sql 只在 data dir 为空时跑）"
    warn "如果是首次部署却没装上，说明 init.sql 执行失败，看 docker logs $PG_CONTAINER"
    warn "如果是已有库升级，手动跑：docker exec -it $PG_CONTAINER psql -U $PG_USER -d $PG_DB -c 'CREATE EXTENSION vector;'"
  fi
}

# ============================================================
# 8. Cleanup old backups + print connection info
# ============================================================
step_finish() {
  info "Step 8/8: 清理 & 输出接入信息"

  # 清理过期备份
  if [ -d "$PG_BACKUP_DIR" ]; then
    local deleted
    deleted=$(find "$PG_BACKUP_DIR" -maxdepth 1 -name "${PG_DB}-*.sql.gz" -mtime +"$BACKUP_RETENTION_DAYS" -print -delete 2>/dev/null | wc -l)
    if [ "$deleted" -gt 0 ]; then
      ok "清理 $deleted 个超过 ${BACKUP_RETENTION_DAYS} 天的旧备份"
    fi
  fi

  # 提取端口（PG_PORT_BIND 形如 "127.0.0.1:5432" 或裸 "5432"）
  local host_port="${PG_PORT_BIND##*:}"
  local bind_addr="${PG_PORT_BIND%:*}"
  [ "$bind_addr" = "$PG_PORT_BIND" ] && bind_addr="0.0.0.0"

  echo >&2
  ok "${C_BOLD}PostgreSQL 安装完成${C_RESET}"
  cat >&2 <<EOF

  容器:       $PG_CONTAINER
  绑定:       ${bind_addr}:${host_port}
  数据目录:   $PG_DATA_DIR
  备份目录:   $PG_BACKUP_DIR (保留 ${BACKUP_RETENTION_DAYS} 天)

  ${C_BOLD}把这些值填进 deploy-app-only.sh 写出的 .env：${C_RESET}
    MAXKB_DB_HOST='host.docker.internal'
    MAXKB_DB_PORT='${host_port}'
    MAXKB_DB_USER='${PG_USER}'
    MAXKB_DB_PASSWORD='<见 ${PG_CREDENTIALS_FILE}：cat 一下即可>'
    MAXKB_DB_NAME='${PG_DB}'

  ${C_BOLD}常用命令：${C_RESET}
    docker logs $PG_CONTAINER                            # 查看日志
    docker exec -it $PG_CONTAINER psql -U $PG_USER -d $PG_DB
    docker restart $PG_CONTAINER                         # 重启
    手动备份: docker exec $PG_CONTAINER pg_dump -U $PG_USER -d $PG_DB | gzip > backup.sql.gz

EOF

  # 安全提示：0.0.0.0 绑定可能被公网/LAN 扫到。
  if [ "$bind_addr" = "0.0.0.0" ]; then
    warn "${C_BOLD}安全提示${C_RESET}：PG 当前绑 0.0.0.0:${host_port}（docker 容器走 host.docker.internal 才能连）"
    warn "  - 云服务器：在云厂商安全组拒绝 ${host_port}/tcp 入站（关键！）"
    warn "  - 本地机器：默认 docker iptables 会让 LAN 较难直连 docker0 网关，但仍建议主机防火墙也限制"
    warn "  - 验证不在公网暴露：在另一台机器 'nc -z -w 3 <你的服务器公网 IP> ${host_port}' 应该 timeout"
  fi
}

main() {
  echo "${C_BOLD}HoyanAI PostgreSQL (pgvector) 安装${C_RESET}" >&2
  echo >&2
  step_guards
  step_password
  step_dirs
  step_backup
  step_init_sql
  step_start
  step_wait
  step_finish
}

main "$@"
