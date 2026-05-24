# 前端独立部署指南（nginx / 宝塔）

适用：后端已经按 [`deployment-app-only.md`](./deployment-app-only.md) 部署在某台机器上（或 [`deployment-split.md`](./deployment-split.md) 模式但**不**用自带的 `maxkb-ui` 容器），前端 admin + chat 单独构建后由独立 nginx 提供。

宝塔（BT Panel）场景是 1 类，但本文档的 nginx 模板对**任何 nginx 部署**（裸机 / docker / k8s ingress）都通用。

---

## 1. 架构

```
                  浏览器
                    │
                    ▼
   ┌──────────────────────────────────┐
   │  独立 nginx（本机或前置 LB）        │
   │                                  │
   │  /                → 301 /admin/  │
   │  /admin/          → 静态 SPA      │
   │  /chat/           → 静态 SPA      │
   │  /admin/api/      → 反代 → 后端    │
   │  /chat/api/       → 反代 → 后端    │
   │  /admin/oss/...   → 反代 → 后端    │
   │  /chat/oss/...    → 反代 → 后端    │
   └──────────────────────────────────┘
                    │
                    ▼
          maxkb-app:8080（或你映射的宿主端口）
```

**为什么两份产物**：admin 和 chat 是**两套独立的 Vite 构建**——不同入口 html、不同 `VITE_BASE_PATH`、不同 dev 端口。同源走 nginx 反代，没有 CORS 问题。

---

## 2. 构建产物

```bash
cd ui

# 一次性装依赖
npm ci

# 分别构建（也可以并发：npx concurrently "npm run build" "npm run build-chat"）
npm run build         # → ui/dist/admin/
npm run build-chat    # → ui/dist/chat/
```

| 模式 | 命令 | 入口 | base | 产物目录 |
|---|---|---|---|---|
| admin | `npm run build` | `admin.html` | `/admin/` | `ui/dist/admin/` |
| chat | `npm run build-chat` | `chat.html` | `/chat/` | `ui/dist/chat/` |

Vite 配置在 `ui/vite.config.ts:103`：用 `dist${VITE_BASE_PATH}` 作 outDir，再用自定义 `renameHtmlPlugin` 把入口 html 改名成 `index.html`，所以两次构建产物互不覆盖。

打包上传：

```bash
cd ui
tar czf mokekb-ui.tar.gz -C dist admin chat
scp mokekb-ui.tar.gz user@server:/tmp/
```

---

## 3. 服务器目录约定

本文档假设站点根目录是 `/project/mokekb/front/`（宝塔自定义路径示例；标准 nginx 用 `/var/www/mokekb/` 同理）。最终结构：

```
/project/mokekb/front/
├── admin/
│   ├── index.html
│   ├── favicon.ico
│   └── assets/
│       ├── index-XXXXXXXX.js
│       ├── index-XXXXXXXX.css
│       └── ...
└── chat/
    ├── index.html
    └── assets/
        └── ...
```

URL 路径段（`/admin/`、`/chat/`）和目录段一一对应，这是为什么 nginx 配置用 `root` 而不是 `alias`——避免 alias 在嵌套 regex location 里的坑（见 [§ 7.2](#72-改用-alias-导致静态资源-404)）。

解压：

```bash
sudo mkdir -p /project/mokekb/front
sudo tar xzf /tmp/mokekb-ui.tar.gz -C /project/mokekb/front
sudo chown -R www:www /project/mokekb/front    # 宝塔默认 nginx 跑在 www 用户
ls /project/mokekb/front                       # 应该看到 admin/  chat/
```

---

## 4. 标准 nginx 配置模板

把下面这段填进你的 `server { }`。需要替换的占位符（共 3 处）：

| 占位符 | 含义 | 示例 |
|---|---|---|
| `your.domain.com` | 站点域名 | `moke.feilan.net` |
| `/project/mokekb/front` | 静态文件根目录 | `/var/www/mokekb` |
| `127.0.0.1:8080` | 后端地址:端口 | `127.0.0.1:8888` / `10.0.0.5:8080` / `backend.internal:8080` |

```nginx
server {
    listen 80;
    server_name your.domain.com;
    root /project/mokekb/front;
    index index.html;

    # 上传大文件（知识库批量导入）需要
    client_max_body_size 100m;

    # === 后端 API 反代 ===
    location /admin/api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;        # SSE 流式必须关
    }

    location /chat/api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
    }

    # === OSS 下载（头像 / 知识库附件等） ===
    location ~ ^/(admin|chat)/oss/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_read_timeout 300s;
    }

    # === admin SPA ===
    # ^~ 是关键：前缀匹配命中后不再尝试 regex location，
    # 防止下方任何 `location ~* \.js$` 之类的通用规则"偷走"静态资源请求。
    location ^~ /admin/ {
        try_files $uri $uri/ /admin/index.html;

        # 命中此 location 时 root 自动继承 server 的 /project/mokekb/front
        # 实际路径：/project/mokekb/front/admin/...
        location ~* \.(?:js|css|woff2?|ttf|svg|png|jpg|jpeg|gif|ico)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # === chat SPA ===
    location ^~ /chat/ {
        try_files $uri $uri/ /chat/index.html;

        location ~* \.(?:js|css|woff2?|ttf|svg|png|jpg|jpeg|gif|ico)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # === 根路径 → admin ===
    location = / {
        return 301 /admin/;
    }
}
```

---

## 5. 宝塔（BT Panel）特定步骤

### 5.1 建站

1. **网站 → 添加站点**
2. 域名：`moke.feilan.net`（或临时用 IP）
3. 根目录：`/project/mokekb/front`（**父目录**，不是 `/admin`）
4. PHP 版本：**纯静态**
5. 不要建数据库、不要 FTP

建好后**先别测访问**——根目录下没有 `index.html`，`/` 必然回 404 或 301 到 `/admin/`，正常。

### 5.2 改配置

**站点设置 → 配置文件**。宝塔默认生成的 server 块里有几段会跟前端冲突，要**删掉**或**替换**：

**必删**（会拦截 admin/chat 的静态资源请求）：

```nginx
# 删掉这两段——它们是 regex location，会抢在 /admin/ /chat/ 之前匹配，
# 然后按 server 顶部 root 找文件，但是路径不对（找不到 /admin/admin/assets/...）
location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)$ { expires 30d; ... }
location ~ .*\.(js|css)?$                  { expires 12h; ... }
```

**必加**：[§ 4](#4-标准-nginx-配置模板) 里 `location /admin/api/` 一直到 `location = /` 这一整段。

**可保留**：宝塔自带的「敏感文件 / 敏感目录黑名单」（`\.user.ini` `\.git/` 等）——这些 regex 跟前端路径没冲突，留着加固即可。但只有在 `/admin/` `/chat/` 都加了 `^~` 时才安全，否则黑名单 regex 也可能拦截不该拦的静态资源。

### 5.3 SSL

**站点设置 → SSL → Let's Encrypt → 申请 → 强制 HTTPS**。

后端 API 用 HTTPS 是强烈建议——浏览器对 HTTPS 站点访问 HTTP API 会触发 mixed-content 拦截，登录后所有请求都会挂。

证书申请期间的 `/.well-known/` 路径宝塔会自动注入 include，前面的配置不用改。

### 5.4 端口避坑：**8888 跟宝塔面板冲突**

宝塔面板**默认监听 8888**。如果后端容器也用 8888（`MAXKB_BACKEND_PORT=8888`）：

- 要么宝塔已经把面板挪到别的端口（比如 28888）了——OK，不冲突
- 要么宝塔还在 8888——你的后端起不来，或者反代会回宝塔登录页 HTML 而不是 JSON

**验证**：

```bash
ss -tlnp | grep ':8888'
curl -sf http://127.0.0.1:8888/admin/api/profile
# 期望：JSON 应答（401 也行）
# 错误：HTML（宝塔登录页）→ 端口被宝塔占了
```

建议后端就用默认 8080，跟 [`deployment-app-only.md`](./deployment-app-only.md) 保持一致。

---

## 6. 后端必须的配套设置

后端 `.env`（即 `deploy-app-only.sh` 生成的那个）里：

```env
MAXKB_ENABLE_UI=false
```

否则后端进程也会挂前端静态路由，浪费内存、还可能跟 nginx 缓存配置打架。

**注意**：app-only / split 部署模式的 compose 文件已经默认设了这个，手动改 `.env` 一般不需要动。但如果是从 all-in-one 迁过来的旧部署，要确认下。

---

## 7. 故障排查

### 7.1 `/admin/` 200 但 `/admin/assets/*.js` 404

**最常见的坑**。原因：宝塔默认配置里有这样的 regex location：

```nginx
location ~ .*\.(js|css)?$ { expires 12h; ... }
```

它是 regex，优先级 > `location /admin/` 的 prefix（**没加 `^~` 时**）。请求 `/admin/assets/foo.js` 命中这个通用规则，按 server 根目录 `/project/mokekb/front` 找 `/project/mokekb/front/admin/assets/foo.js`——文件在那也能找到，但因为 location 块里没有任何 `try_files`，可能因为别的指令缺失返回 403/404。

**修复**：

1. 给 `/admin/` `/chat/` 加 `^~` 前缀（[§ 4](#4-标准-nginx-配置模板) 模板已经加了）
2. 删掉宝塔自带的 `.*\.(gif|...)$` 和 `.*\.(js|css)?$` 两段通用 expires 规则

两件都做最稳。

### 7.2 改用 alias 导致静态资源 404

如果你把 `/admin/` 配置改成 alias：

```nginx
location ^~ /admin/ {
    alias /project/mokekb/front/admin/;
    location ~* \.js$ {
        alias /project/mokekb/front/admin/;    # ← 坑
        try_files $uri =404;
    }
}
```

请求 `/admin/assets/foo.js` 走到 inner regex location，alias 在 regex location 里**没有 capture 就行为未定义**，nginx 实际找的路径可能是 `/project/mokekb/front/admin/admin/assets/foo.js`（多了一层 `admin/`）→ 404。

确认方法：

```bash
tail -f /www/wwwlogs/<域名>.error.log
# 再请求一次出问题的 .js
# 错误日志里会看到 open() "/project/mokekb/front/admin/admin/assets/...js" failed
```

**修复**：用 [§ 4](#4-标准-nginx-配置模板) 模板里的 `root` 写法。`root` 在嵌套 location 里**自动继承**，URL 路径段和目录段一一对应时它最简单。

nginx 官方文档[明确说](https://nginx.org/en/docs/http/ngx_http_core_module.html#alias)：
> When location matches the last part of the directive's value, it is **better to use the root directive instead**.
> When alias is used inside a location defined with a regular expression then such regular expression **should contain captures** and alias should refer to these captures.

### 7.3 刷新页面（深层路由）404

比如 `/admin/application/abc123` 这种 SPA 内部路由，直接刷新出 404：

**原因**：`location /admin/` 块缺 `try_files ... /admin/index.html` fallback。

**修复**：模板里已经有 `try_files $uri $uri/ /admin/index.html;`，确认这一行在你的配置里。

> **注意 fallback 路径必须是 `/admin/index.html` 不是 `/index.html`**。因为 SPA base 是 `/admin/`，HTML 里所有资源链接都带 `/admin/` 前缀，回 `/index.html` 浏览器解析 base 时会错。

### 7.4 聊天 token 一次性憋出来，不是流式吐字

**原因**：proxy buffering 没关。nginx 默认会缓冲后端响应，攒满或后端结束才一次性发给客户端。SSE 流式必须关。

**修复**：`location /admin/api/` 和 `/chat/api/` 都要有 `proxy_buffering off;`（模板里已加）。

### 7.5 WebSocket 握手失败（工作流调试 / 实时语音）

**原因**：缺 `Upgrade` / `Connection` 头。

**修复**：模板里 `/admin/api/` `/chat/api/` 已经加了：
```nginx
proxy_set_header Upgrade    $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_http_version 1.1;
```

> 更规范的写法是用 `map $http_upgrade $connection_upgrade { default upgrade; '' close; }` 然后 `Connection $connection_upgrade;`——非 WebSocket 请求就不会带 `Connection: upgrade` 了。当前写法虽不规范但实际无害。

### 7.6 登录后 API 请求带不上 token / 401

**原因 A**：前端走 HTTPS、API 走 HTTP（mixed-content 被浏览器拦）。**修复**：站点强制 HTTPS。

**原因 B**：API 不同域（比如前端 `https://kb.x.com`、API 直连 `http://10.0.0.5:8080`），cookie 跨域。**修复**：本文档架构 API 走同源反代（`/admin/api/...`），不应有此问题；如果你绕过 nginx 直连了，改回走反代。

### 7.7 上传文件 413 Request Entity Too Large

宝塔默认 `client_max_body_size 50m`。知识库批量上传可能超过。

**修复**：模板里已经有 `client_max_body_size 100m;`，按需调大。**注意**：这个指令在 server 块或 location 块都行，但**必须在 nginx config 里**，不能只在宝塔面板的"上传大小限制"里改（那个只控 PHP，对反代无效）。

### 7.8 改配置后浏览器还是看旧版本

`index.html` 本身没有 hash，浏览器可能缓存。

**临时**：用户 Ctrl+Shift+R 强刷。

**根治**：给 `index.html` 加 no-cache 头。如果模板里 `location ^~ /admin/` 没有再叠加 `expires` 或 `Cache-Control` 到非 assets 路径，nginx 默认会带 `Last-Modified` + 弱 ETag，浏览器会带 `If-Modified-Since` 回来，nginx 返回 304——这种行为对 SPA 通常足够。如果还是有问题：

```nginx
location ^~ /admin/ {
    try_files $uri $uri/ /admin/index.html;

    # 仅给 index.html 显式 no-cache
    location = /admin/index.html {
        expires -1;
        add_header Cache-Control "no-cache, must-revalidate";
    }

    location ~* \.(?:js|css|woff2?|ttf|svg|png|jpg|jpeg|gif|ico)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## 8. 升级流程

```bash
# 本地
cd ui
git pull
npm ci                # 如果 package-lock 有变
npm run build && npm run build-chat
tar czf mokekb-ui.tar.gz -C dist admin chat

# 上传
scp mokekb-ui.tar.gz user@server:/tmp/

# 服务器上：原地解压覆盖（前端零停机，nginx 实时生效）
sudo tar xzf /tmp/mokekb-ui.tar.gz -C /project/mokekb/front
sudo chown -R www:www /project/mokekb/front/admin /project/mokekb/front/chat
```

**不需要重启 nginx**——静态文件实时生效。assets 全部带 hash，浏览器自动失效；index.html 走 ETag 304 协商缓存。

如果想更稳（避免请求中途同时拿到新旧版本的文件）：

```bash
# 解压到临时目录，再原子 mv
sudo tar xzf /tmp/mokekb-ui.tar.gz -C /project/mokekb/front-new
sudo mv /project/mokekb/front{,-old} && sudo mv /project/mokekb/front{-new,}
# 验证后清理：sudo rm -rf /project/mokekb/front-old
```

---

## 9. 验证清单

改完配置后**按顺序**走完这 6 条，任何一条不过先别上线：

```bash
DOMAIN=moke.feilan.net
BACKEND=127.0.0.1:8080

# 1. 后端可达 + 应答的是后端不是宝塔/别的
curl -sf http://$BACKEND/admin/api/profile | head -c 200
# 期望：JSON 含 "code": 200 或 401，不是 HTML

# 2. nginx 语法 OK
sudo nginx -t

# 3. admin 主页
curl -I http://$DOMAIN/admin/
# 期望：HTTP/1.1 200 OK，Content-Type: text/html

# 4. admin 静态资源（任挑一个 hash 文件名）
curl -I http://$DOMAIN/admin/favicon.ico
# 期望：HTTP/1.1 200 OK，Cache-Control: public, immutable

# 5. SPA 深层路由 fallback
curl -I http://$DOMAIN/admin/application/whatever-route
# 期望：HTTP/1.1 200 OK（fallback 到 index.html，不是 404）

# 6. API 走通
curl http://$DOMAIN/admin/api/profile | head -c 200
# 期望：跟第 1 步同样的 JSON
```

chat 同样 4 条（把 admin 换 chat）。

浏览器打开 `https://$DOMAIN/`，应该自动跳到 `/admin/`，DevTools Network 面板里所有请求 2xx/3xx，没有 4xx/5xx。
