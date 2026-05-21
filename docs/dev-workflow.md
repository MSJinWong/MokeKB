# 开发工作流：WSL 运行 + Windows 编辑器 + GitHub Desktop 版本管理

适用于 Windows 用户，在 **WSL2 中跑 MokeKB 服务**、用 **Windows 端 IDE 编辑代码**、用 **GitHub Desktop 管理 git** 的混合工作流。环境初装请先看 [`dev-wsl.md`](./dev-wsl.md)，本文聚焦在装完之后**日常怎么干活**。

---

## 0. 关键原则

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│  代码物理位置:  ~/projects/MokeKB  (WSL ext4)              │
│                 ↑ 唯一来源                                  │
│                 │                                          │
│       ┌─────────┼─────────┬──────────┬──────────┐         │
│       │         │         │          │          │         │
│   VSCode    GitHub      WSL       Windows    任意 Win      │
│   + WSL     Desktop    Terminal   浏览器     工具          │
│   扩展      (Windows)  (Linux)              \\wsl$\...     │
│                                                            │
│   (编辑)    (commit/    (跑服务、 (访问页面) (查看文件)    │
│             push/pull) 命令行 git)                         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**核心约定**：

- 代码**只在 WSL 里有一份**（`~/projects/MokeKB`）。不要在 Windows D 盘维护第二份。
- Windows IDE / GHD 通过 `\\wsl$\Ubuntu\home\<user>\projects\MokeKB` UNC 路径访问 WSL 文件，对它们来说就是网络盘。
- 跑服务（backend / worker / 前端 npm dev）**全部在 WSL 终端**，不在 Windows。
- 浏览器在 Windows 上，访问 `http://localhost:<port>` —— WSL2 自动把端口转发到 Windows，零配置。

---

## 1. 一次性设置

只在装完环境后做一次。后续日常开发跳到 §2。

### 1.1 让 WSL 副本指向真实远程

如果你最初是 `git clone /mnt/d/GitRepo/MokeKB ~/projects/MokeKB` 这样从 Windows 副本克隆过来的，WSL 副本的 `origin` 会指向那条本地路径，不是 GitHub / Gitee。改过来：

```bash
cd ~/projects/MokeKB

# 看现在指向哪
git remote -v
# 如果显示 /mnt/d/GitRepo/MokeKB，继续；如果已经是 git@github.com:... 跳过本节

# 从 Windows 副本拿真实远程 URL
REAL_REMOTE=$(git -C /mnt/d/GitRepo/MokeKB config --get remote.origin.url)
echo "Real remote: $REAL_REMOTE"

# 改 origin 并绑定 upstream
git remote set-url origin "$REAL_REMOTE"
git fetch origin
git branch --set-upstream-to=origin/release-2.9-simplify release-2.9-simplify

# 验证
git remote -v
# 期望：origin <真实 URL> (fetch/push)
```

### 1.2 配置 git 行尾符与身份

GHD 是 Windows 应用，默认行为可能跟 WSL 不一致。在仓库内强制统一：

```bash
cd ~/projects/MokeKB

# 不让 Windows 工具自动转 CRLF
git config --local core.autocrlf false
git config --local core.eol lf

# 强制使用同一身份（避免 Windows ~/.gitconfig 和 WSL ~/.gitconfig 不一致）
git config --local user.name "Your Name"
git config --local user.email "your@email"

# 验证
git config --local --list | grep -E '(autocrlf|eol|user\.)'
```

> `--local` 只影响本仓库，不污染你的全局配置。

### 1.3 装 VSCode + WSL 扩展（推荐编辑器）

Windows 上装 [VSCode](https://code.visualstudio.com/)，然后装 WSL 扩展：

```bash
# 在 WSL 里执行（如果 VSCode 已在 PATH 里，可省略）
code --install-extension ms-vscode-remote.remote-wsl
```

或 GUI 里搜 `Remote - WSL` (Microsoft 官方) 安装。

之后**用 WSL 终端打开项目**：

```bash
cd ~/projects/MokeKB
code .
```

会启动 Windows VSCode，但：
- 文件树左下角显示 `WSL: Ubuntu`
- 集成终端默认是 WSL bash
- Python 解释器自动选 `~/.venv/bin/python`（提示选时确认一次）
- Git 操作、调试、LSP 全部跑在 WSL 里

### 1.4 把 WSL 仓库加到 GitHub Desktop

打开 GitHub Desktop：

1. **File → Add local repository**
2. 路径填：
   ```
   \\wsl$\Ubuntu\home\<your-wsl-user>\projects\MokeKB
   ```
   例如：`\\wsl$\Ubuntu\home\mrwan\projects\MokeKB`

3. GHD 识别 `.git` 后加入仓库列表

> **首次添加可能卡几秒**：GHD 要扫描整个仓库索引。耐心等。

### 1.5 验证 GHD 能正常拉/推

在 GHD 里：
- 顶栏应显示当前分支 `release-2.9-simplify`
- 右上角 "Fetch origin" 按一下，没报错就 OK
- History 选项卡能看到所有 commit

如果 GHD 报"找不到 git" 或类似错，多半是它内置 git 不认 UNC 路径上的某些权限位。一般升级到最新版 GHD 即可解决。

### 1.6（可选）归档或删除 Windows 副本

确认 WSL 副本所有改动都推到远程后：

```powershell
# Windows PowerShell
cd D:\GitRepo\MokeKB
git status              # 无未推送的 commit 才能删
git log origin/release-2.9-simplify..HEAD --oneline   # 应该 0 行

# 二选一：
# A) 改名归档（保险）
Move-Item D:\GitRepo\MokeKB D:\GitRepo\MokeKB.legacy

# B) 直接删
Remove-Item -Recurse -Force D:\GitRepo\MokeKB
```

---

## 2. 日常开发流程

### 2.1 早上开工

```bash
# WSL 终端
cd ~/projects/MokeKB
```

或 Windows Terminal 直接配一个 WSL profile 默认 cd 到这。

**拉最新代码**：在 GHD 顶栏点 "Fetch origin" → 如果有新 commit，按钮变 "Pull origin" → 点击。

或命令行：

```bash
git pull
```

**打开 VSCode**：

```bash
code .
```

**起服务**（3 个集成终端标签页）：

| 标签 | 命令 | 用途 |
|---|---|---|
| 1 | `source .venv/bin/activate && set -a; source .env.dev; set +a && python main.py dev web` | 后端 Web |
| 2 | `source .venv/bin/activate && set -a; source .env.dev; set +a && python main.py dev celery` | Celery worker |
| 3 | `cd ui && npm run dev` | 前端 admin（可选） |

> 一行太长？可以把 `source ...activate && set -a; source .env.dev; set +a` 加到 `.venv/bin/activate` 末尾，以后只需 `source .venv/bin/activate`。

**浏览器访问**：
- 后端 API：http://localhost:8080/admin/api/profile
- API 文档：http://localhost:8080/admin/api-doc/
- 前端：http://localhost:3000/admin/（如果跑了 npm dev）

### 2.2 写代码

- 在 **VSCode（WSL 模式）** 里改文件
- 后端代码保存 → Django autoreload 自动重启
- 前端代码保存 → vite HMR 立即生效
- Celery worker 改代码后**需要手动重启**（Ctrl+C → 重跑）

### 2.3 提交代码（GitHub Desktop）

切到 GHD 窗口：

1. **Changes 选项卡** 列出所有 modified / added / deleted 文件
2. 左侧勾选要提交的文件（默认全勾，可单独取消）
3. 右下角 **Summary** 填 commit 标题（短，≤72 字）
4. **Description**（可选）填详细说明
5. 点 **Commit to release-2.9-simplify**（按钮文字含当前分支名）

> 命名风格参考最近的 commit history，本项目大致用 `fix:` / `feat:` / `docs:` / `perf:` / `chore:` 前缀。

### 2.4 推送（GitHub Desktop）

Commit 之后顶栏会变 "Push origin"，点一下完事。

> 也可以在 WSL 命令行 `git push`，效果一样。GHD 走的是 Windows 凭据，WSL 命令行走的是 Linux 凭据 —— **任选一个，但同一个 PR 内别混用**，避免 SSH key / HTTPS token 来回切换出问题。

### 2.5 拉别人的更新

GHD：**Fetch origin** → 如果远程领先，按钮变 **Pull origin** → 点击。

WSL 命令行：

```bash
git pull
```

两种方式更新的是同一个工作区。

### 2.6 切分支 / 新分支

GHD：顶栏 **Current Branch** → **New Branch**（从 main 起新分支）或切到已有分支。

WSL 命令行：

```bash
git switch -c feat/my-new-feature   # 从当前分支起新分支
git switch main                      # 切到 main
```

---

## 3. 常见问题

### 3.1 GHD 显示一堆 `node_modules/` 或 `.venv/` 文件 modified

`.gitignore` 漏了。验证：

```bash
cd ~/projects/MokeKB
grep -E '^(node_modules|\.venv|__pycache__)' .gitignore
```

如果没有就加上，并清空已被追踪的：

```bash
echo -e "\n.venv/\nnode_modules/\n__pycache__/\n*.pyc" >> .gitignore
git rm -r --cached .venv node_modules 2>/dev/null
git add .gitignore
git commit -m "chore: ignore venv / node_modules / pycache"
```

### 3.2 GHD 提交后 WSL `git log` 看不到？反之亦然？

不可能。两者操作的是**同一个 `.git` 目录**。如果真的看不到，多半是：
- GHD 装载的不是 `\\wsl$\Ubuntu\home\<user>\projects\MokeKB`，而是另一个路径副本
- 或者你 WSL 不小心 cd 到了 `/mnt/d/GitRepo/MokeKB`（旧的 Windows 副本）

`pwd` 确认下当前目录，`git remote -v` 确认是否同一份。

### 3.3 提交时报 `fatal: detected dubious ownership in repository`

git 出于安全检查，跨 Windows/WSL 文件系统操作有时会触发。一次性放行：

```bash
git config --global --add safe.directory '/mnt/d/GitRepo/MokeKB'
git config --global --add safe.directory '//wsl.localhost/Ubuntu/home/<your-user>/projects/MokeKB'
```

### 3.4 VSCode 终端打开后不是 WSL bash，而是 PowerShell

左下角应该显示 `WSL: Ubuntu`。如果显示 `Win32` 之类，说明你**没用 WSL 扩展打开项目**。退出后，从 WSL 终端再次 `cd ~/projects/MokeKB && code .` 启动。

### 3.5 行尾符冲突：明明没改文件但 GHD 显示全文件 modified

是 §1.2 的设置没生效。重新跑一遍仓库级配置，然后：

```bash
git add --renormalize .
git status   # 应该没有 modified 了
```

如果有，commit 一下，标题写 `chore: normalize line endings`。

### 3.6 `git push` 报 SSH key 找不到

GHD 用 Windows `%USERPROFILE%\.ssh\`，WSL git 用 `~/.ssh/`。两边都要有 key，或者**复用同一份 key**：

```bash
# 把 Windows 的 SSH key 复制到 WSL（一次性）
mkdir -p ~/.ssh
cp /mnt/c/Users/<your-windows-user>/.ssh/id_ed25519 ~/.ssh/
cp /mnt/c/Users/<your-windows-user>/.ssh/id_ed25519.pub ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# 测试
ssh -T git@github.com
```

或者反过来，GHD 改用 HTTPS + token，省得管 SSH。

---

## 4. 推荐的 IDE 替代

| IDE | WSL 支持方式 |
|---|---|
| **VSCode**（推荐） | 装 `Remote - WSL` 扩展；`code .` 从 WSL 终端启动 |
| **Cursor** / **Trae** | 同 VSCode，装 WSL 扩展 |
| **PyCharm Pro / WebStorm** | Settings → Project Interpreter → Add → WSL |
| Notepad++ / Sublime / 任意 | 文件菜单 → 打开 → 输入 `\\wsl$\Ubuntu\home\<user>\projects\MokeKB` |

社区版 PyCharm **不支持** WSL 解释器，需要 Pro。

---

## 5. 总结：一图流

```
开机
  ↓
Windows Terminal → wsl -d Ubuntu → cd ~/projects/MokeKB
  ↓                                            ↓
GHD 点 Fetch/Pull origin                    code .  ──→  Windows VSCode (WSL 模式)
                                                          ↓
                                                  集成终端 × 3:
                                                  • python main.py dev web
                                                  • python main.py dev celery
                                                  • cd ui && npm run dev
                                                          ↓
                                                  浏览器 (Windows): localhost:8080 / 3000

写代码
  ↓
保存 → 自动 reload
  ↓
切 GHD → Commit → Push origin
  ↓
完事
```

---

## 6. 相关文档

- 环境初装：[`dev-wsl.md`](./dev-wsl.md)
- Docker 部署：[`deployment-docker.md`](./deployment-docker.md)
- 拆分部署：[`split-deployment.md`](./split-deployment.md)
