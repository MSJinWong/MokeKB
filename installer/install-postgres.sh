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
#   vim install-pg.sh        # edit PG_PASSWORD below — REQUIRED
#   ./install-pg.sh
#
# Re-running this script: detects an existing container, runs pg_dump to
# PG_BACKUP_DIR, then restarts in place. Data volume survives.

set -euo pipefail

# ============================================================
# Configuration — edit these before running
# ============================================================
PG_IMAGE="pgvector/pgvector:pg17"
PG_CONTAINER="hoyanai-postgres"
PG_DATA_DIR="/opt/hoyanai-pg/data"
PG_BACKUP_DIR="/opt/hoyanai-pg/backups"
PG_PORT_BIND="127.0.0.1:5432"            # host:container; "127.0.0.1:5432" = local only
PG_DB="hoyanai"
PG_USER="hoyanai"
PG_PASSWORD="CHANGE_ME_BEFORE_RUN"       # ← MUST change before first run
PG_MAX_CONNECTIONS=1000
BACKUP_RETENTION_DAYS=7
# ============================================================

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

# ============================================================
# 1. Guards
# ============================================================
step_guards() {
  info "Step 1/7: 前置检查"

  if [ "$PG_PASSWORD" = "CHANGE_ME_BEFORE_RUN" ] || [ -z "$PG_PASSWORD" ]; then
    err "请先编辑脚本顶部的 PG_PASSWORD（当前是占位值 CHANGE_ME_BEFORE_RUN）"
    err "建议用 'openssl rand -base64 24' 生成强密码"
    exit 1
  fi

  # 单引号会破坏后面写 init.sql / docker exec 等场景，提前拒绝
  case "$PG_PASSWORD" in
    *\'*)
      err "PG_PASSWORD 不允许包含单引号，请换一个字符"
      exit 1 ;;
  esac

  if ! command -v docker >/dev/null 2>&1; then
    err "未找到 docker"; exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    err "docker daemon 不可用（当前用户可能不在 docker 组：sudo usermod -aG docker \$USER && newgrp docker）"
    exit 1
  fi

  ok "docker $(docker --version | awk '{print $3}' | tr -d ',')"
}

# ============================================================
# 2. Prepare directories
# ============================================================
step_dirs() {
  info "Step 2/7: 准备目录"

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
# 3. Backup if old container is running
# ============================================================
step_backup() {
  info "Step 3/7: 检测旧容器并备份"

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
# 4. Write init.sql for first-run extension setup
# ============================================================
step_init_sql() {
  info "Step 4/7: 准备 init.sql"

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
# 5. (Re)start container
# ============================================================
step_start() {
  info "Step 5/7: 启动容器"

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
# 6. Wait + verify
# ============================================================
step_wait() {
  info "Step 6/7: 等待 PG 就绪"

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
# 7. Cleanup old backups + print connection info
# ============================================================
step_finish() {
  info "Step 7/7: 清理 & 输出接入信息"

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
    MAXKB_DB_PASSWORD='<本脚本顶部的 PG_PASSWORD>'
    MAXKB_DB_NAME='${PG_DB}'

  ${C_BOLD}常用命令：${C_RESET}
    docker logs $PG_CONTAINER                            # 查看日志
    docker exec -it $PG_CONTAINER psql -U $PG_USER -d $PG_DB
    docker restart $PG_CONTAINER                         # 重启
    手动备份: docker exec $PG_CONTAINER pg_dump -U $PG_USER -d $PG_DB | gzip > backup.sql.gz

EOF
}

main() {
  echo "${C_BOLD}HoyanAI PostgreSQL (pgvector) 安装${C_RESET}" >&2
  echo >&2
  step_guards
  step_dirs
  step_backup
  step_init_sql
  step_start
  step_wait
  step_finish
}

main "$@"
