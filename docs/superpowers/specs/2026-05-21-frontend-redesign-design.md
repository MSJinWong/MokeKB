# 前端整体重设计 · 去 MaxKB 指纹化

- **日期**：2026-05-21
- **范围**：`ui/` 前端布局与样式重做
- **不动**：`apps/` 后端代码、所有 API、`/chat/:accessToken` 与 `/user-login/:accessToken` 的 URL 与 postMessage 协议

---

## 1. 目标

让对 MaxKB 熟悉的普通用户首次访问时**完全无法识别**这是 MaxKB；让 MaxKB 行家用户在不到 30 秒的扫视里也**不会立刻反应过来**。功能、API、后端、嵌入合约一律不动。

定位：**企业内部平台 / 公司内网**风格的智能体与知识平台。

---

## 2. 设计原则

| # | 原则 | 用途 |
|---|------|------|
| 1 | **结构差异 > 颜色差异** | 骨架与导航换了之后，肌肉记忆失效，光改颜色行家一眼看穿 |
| 2 | **后端零改动** | 路由 `path`、API、字段名保留；只动 UI 显示名、组件样式、品牌素材 |
| 3 | **设计 Token 优先** | 能改 `variables.scss` 解决的不动组件；保留 MaxKB 上游升级的可能 |
| 4 | **嵌入面优先稳定** | `/chat`、`/user-login` 视觉可大改，但 URL、postMessage、JS API 不变 |
| 5 | **能删的素材就删** | `MaxKB-logo.svg` 等所有写死素材与字符串枚举清理 |

### 范围边界

- **在范围内**：管理后台桌面端（最低设计宽度 1280px）+ `/chat` 与 `/user-login` 的移动端响应（375px 起）
- **不在范围内**：管理后台移动端适配、暗色模式切换、LogicFlow 引擎重写、i18n 翻译质量优化（仅改产品名与术语条目）

---

## 3. 整体架构

### 3.1 骨架 B · 图标 Rail + 子菜单

```
┌──────┬────────┬──────────────────────────┐
│ Rail │  Side  │       Main               │
│ 64px │ 200px  │       (flex 1)           │
│      │        │                          │
│ ⊞    │ 概览    │  当前模块的子页面          │
│ ◐    │ ...    │                          │
│ ▤    │        │                          │
│ ◉    │        │                          │
│ ⚙    │        │                          │
└──────┴────────┴──────────────────────────┘
```

- **左 64px Rail（深色）**：顶级 5 个模块图标，激活时左侧 2px 品牌色竖条 + 文字白色
- **紧贴 200px Side（浅灰）**：当前模块的二级菜单，激活项浅色背景
- **Main（白底）**：内容区，左 20px padding
- **无顶部 bar** —— MaxKB 标志性蓝紫渐变 Header 直接删除

### 3.2 调性 ① · 深 Rail + 亮内容

- Rail 深色：`#0f172a`（深石板）
- Side 浅灰：`#f8fafc`
- Main 白：`#ffffff`
- 强调色：用户提供的品牌色（仅用于激活态、主按钮、链接、Rail 激活竖条）
- **不使用任何渐变**

### 3.3 响应式

| 断点 | 行为 |
|------|------|
| ≥ 1280px | Rail + Side + Main 三段全展开 |
| 1024–1280px | Side 默认折叠为图标，hover/点击展开浮层 |
| < 1024px（管理后台） | **不支持**，提示请用桌面 |
| `/chat` 与 `/user-login` < 768px | Rail 隐藏，顶部 56px 标题吸顶 + 输入框吸底 + 消息流满屏 + 历史从左侧抽屉 |

---

## 4. 设计 Token

### 4.1 完整 Token（覆盖 `ui/src/styles/variables.scss`）

```scss
:root {
  /* ---- 品牌（由用户提供，留接入位） ---- */
  --brand-primary: #__USER_PROVIDED__;
  --brand-primary-hover: #__USER_PROVIDED__;
  --brand-primary-active: #__USER_PROVIDED__;
  --brand-primary-soft: #__USER_PROVIDED_10%__;

  /* ---- Rail（深） ---- */
  --rail-width: 64px;
  --rail-bg: #0f172a;
  --rail-text: #94a3b8;
  --rail-text-active: #ffffff;
  --rail-hover-bg: #1e293b;
  --rail-active-bar: var(--brand-primary);

  /* ---- Side（浅灰） ---- */
  --side-width: 200px;
  --side-bg: #f8fafc;
  --side-border: #e2e8f0;
  --side-item-text: #475569;
  --side-item-hover-bg: #eef2f6;
  --side-item-active-bg: #e2e8f0;
  --side-item-active-text: #0f172a;

  /* ---- Main ---- */
  --main-bg: #ffffff;
  --text-primary: #0f172a;
  --text-secondary: #64748b;
  --text-tertiary: #94a3b8;
  --border-base: #e5e7eb;
  --border-strong: #cbd5e1;

  /* ---- 形状 ---- */
  --radius-sm: 4px;     /* 旧 6 */
  --radius-md: 6px;     /* 旧 8 */
  --radius-lg: 10px;    /* 旧 16 ←指纹消除最大 */

  /* ---- 密度 ---- */
  --view-padding: 20px;        /* 旧 24 */
  --card-min-height: 140px;    /* 旧 166 */
  --card-min-width: 260px;     /* 旧 220 */

  /* ---- 状态色（Tag/Badge，去 MaxKB 高饱和） ---- */
  --status-success-bg: #ecfdf5;
  --status-success-text: #047857;
  --status-warning-bg: #fffbeb;
  --status-warning-text: #b45309;
  --status-danger-bg: #fef2f2;
  --status-danger-text: #b91c1c;
  --status-info-bg: #eff6ff;
  --status-info-text: #1d4ed8;

  /* ---- 移除（旧变量删除） ---- */
  /* ❌ --app-header-bg-color（蓝紫渐变） */
  /* ❌ --app-logo-color（蓝紫渐变） */
  /* ❌ --app-avatar-gradient-color（紫蓝渐变） */
  /* ❌ --tag-default-bg/color 等高饱和 tag */
}
```

### 4.2 字体阶梯（比 MaxKB 紧一档）

```scss
--font-size-xs:   11px;
--font-size-sm:   12px;
--font-size-base: 13px;   /* MaxKB 多为 14 */
--font-size-md:   14px;
--font-size-lg:   16px;
--font-size-xl:   18px;
```

字体栈不变：`-apple-system, "PingFang SC", "Microsoft YaHei", sans-serif`。

### 4.3 Element Plus 主题覆盖

仅在 `element-plus.scss` 修改 CSS 变量，不替换组件库：

```scss
:root {
  --el-color-primary: var(--brand-primary);
  --el-color-primary-light-3: var(--brand-primary-hover);
  --el-border-radius-base: var(--radius-md);
  --el-border-radius-small: var(--radius-sm);
  --el-border-radius-round: var(--radius-lg);
  --el-text-color-primary: var(--text-primary);
  --el-text-color-regular: var(--text-secondary);
  --el-bg-color-page: var(--main-bg);
}
```

### 4.4 Icon 系统

- 替换为 **Lucide**（`@iconify-json/lucide` + `@iconify/vue`），描边 1.5px，统一 24px 默认尺寸
- `ui/src/assets/` 下处理策略：
  - **替换重画**：`logo/MaxKB-logo*.svg`、`logo/logo*.svg/.png`、`workflow-demo.png`、`hit-test-empty.png`
  - **保留**：`404.png`、`500.png`、第三方平台 logo（`logo_dingtalk.svg`、`logo_lark.svg` 等，是接入对方平台的合规标识，不能换）
  - **重画为新品牌风**：`icon_import.svg`、`upload-icon.svg`、`user-icon.svg`、`sort.svg` 等通用图标统一改 Lucide 风格

---

## 5. 导航 IA 重排

URL `path` 不变，只换菜单显示名 + 顶级分组 + 子项排序 + icon。

### 5.1 Rail 顶级 5 模块

| 序 | 新名 | Lucide Icon | 旧 MaxKB | 对应 URL |
|---|------|-------------|----------|---------|
| 1 | 工作台 | `layout-dashboard` | （新建落地页） | `/workbench`（新增） |
| 2 | 智能体 | `bot` | 智能应用 | `/application` |
| 3 | 知识资产 | `book-open-text` | 知识库 + 问题 + 段落 | `/knowledge` |
| 4 | 能力扩展 | `puzzle` | 工具 + 函数 + 触发器 | `/tool` |
| 5 | 平台管理 | `settings-2` | 模型 + 系统 | `/system` |

`routes.ts` 中根 `/` redirect 从 `/application` 改为 `/workbench`。

### 5.2 Side 二级菜单

```
工作台
  ├─ 概览                ← /workbench（新建）
  └─ 全部对话            ← chat-log 列表入口
智能体
  ├─ 应用列表            ← /application
  └─ 用户行为            ← chat-user（用户交互/管理）
知识资产
  ├─ 资料库              ← /knowledge
  ├─ 文档                ← /document
  ├─ 问题集              ← MaxKB "问题库"
  └─ 检索调优            ← MaxKB "命中测试"
能力扩展
  ├─ 工具                ← /tool
  └─ 自动化触发          ← /trigger
平台管理
  ├─ 模型接入            ← /model
  ├─ 成员与角色          ← /system 用户管理子页
  ├─ 资源授权            ← /system 资源共享子页
  └─ 平台设置            ← /system 设置子页
```

**说明**：
- "高级编排"（即应用 workflow 编辑器）通过点击应用卡进入应用详情，再切换 Tab 进入；它是 `/application/:from/:id/workflow` 形态的深链，不放侧栏顶级
- "函数"也是从工具详情进入（`/tool/:id/:folderId/workflow`），同理不放顶级
- "公开链接 / 嵌入"是应用详情页的发布 Tab，不放顶级

### 5.3 术语重命名（全站文案 + i18n）

| MaxKB 术语 | 新术语 |
|------------|--------|
| 智能应用 | 智能体 |
| 知识库 | 资料库 |
| 命中测试 | 检索调优 |
| 问题库 | 问题集 |
| 函数库 | 函数 |
| 触发器 | 自动化触发 |
| 系统设置 | 平台设置 |
| 资源管理 | 资源授权 |
| 应用工作流 | 高级编排 |

只改 i18n value，不动 key；不动组件 prop。

---

## 6. 四个高曝光页面 · 深度重做

### 6.1 登录页

**MaxKB 现状**：蓝紫渐变全屏背景 + 居中圆角白卡片 + 渐变 Logo

**新设计**：
- 左 50% 暗色（`#0f172a`）品牌叙事栏：产品名 + slogan + 几何圆形装饰（`border-radius: 50%`、`border: 1px solid #1e293b` 的低对比圆）
- 右 50% 纯白表单栏：标题"登录账号" + 用户名 + 密码 + 主按钮（品牌色填充）
- ResetPassword、ForgotPassword 同款布局，仅替换右侧表单

文件：`ui/src/views/login/index.vue` 重写；`ResetPassword.vue`、`ForgotPassword.vue` 套同一布局组件。

### 6.2 工作台首页（新增）

`/workbench` 新建路由与页面 `ui/src/views/workbench/index.vue`。

三段式结构：
1. **欢迎条**：`早上好，{用户名}` + 当前日期
2. **统计卡组**：4 个浅色统计卡（智能体数、本月对话数、资料库数、工具数），每卡 `1fr` 等宽，数字 18px 加粗、标签 9px 大写
3. **我的智能体**：3 列卡片栅格（260×140，圆角 10px，白底 1px 边），每卡：左上 20px 实心方块 icon + 名称 + 描述 + "最近 24h · N 次对话"

应用列表 `/application` 沿用同款卡片规格。

### 6.3 对话页 `/chat`

**URL 与 postMessage 协议保持不变。**

视觉重做：
- **标题栏 56px**：左 22px 智能体头像方块 + 名称 + "· 在线"状态文字 + 右侧 `搜索 / 重置 / 更多` 图标按钮（Lucide）
- **AI 消息**：透明无底，仅 18px 头像 + 文本 + 灰色元信息行（`· 0.4s · 引用 3 篇文档`）
- **用户消息**：品牌色（深石板 `#0f172a`）填充 + 白字 + 6px 圆角，靠右
- **输入框**：底部吸附 1px 边框白底，最小 36px 高度多行 textarea，右侧发送按钮改为单向上箭头图标
- **历史会话**：从左侧抽屉拉入（MaxKB 是右上下拉，方向反转）
- **移动端**（< 768px）：
  - 标题吸顶 + 输入框吸底（`position: sticky`）
  - 消息流满屏，AI 消息无头像缩进只有左边距
  - 历史抽屉占满屏，关闭手势从右滑出

文件：`ui/src/views/chat/` 整目录视觉层重写。

### 6.4 工作流编辑器

LogicFlow 引擎不动，仅替换节点视觉与画布外观。

**节点**：
- 白底（`#ffffff`）方角（`radius: 6px`）+ 1px `#e2e8f0` 边
- 顶部 2px 类型色条：
  - 触发/开始：`#10b981` 绿
  - 数据/检索：`#3b82f6` 蓝
  - AI/LLM：`#8b5cf6` 紫
  - 逻辑/分支：`#f59e0b` 橙
  - 输出/终止：`#ef4444` 红
- 节点内：12×12 类型色实心方块 icon + 名称（13px）
- 阴影：`0 1px 2px rgba(0,0,0,.04)`

**画布**：
- 底纹从圆点 → 20×20 细网格（`#f1f5f9` 1px 线）
- 连线从带箭头贝塞尔 → 直角折线，描边 1.5px `#0f172a`
- 工具栏从右上固定 → 浮动吸顶居中（`position: absolute; top: 12px; left: 50%; transform: translateX(-50%)`）
- 节点配置面板从模态弹窗 → 右侧抽屉（420px 宽）

文件：`ui/src/views/application-workflow/`、`knowledge-workflow/`、`tool-workflow/` 共享节点皮肤组件；通过 `:deep()` 覆盖 LogicFlow 内部 CSS。

---

## 7. 落地策略与文件改动地图

### 7.1 改动地图（按层）

```
ui/src/styles/                  Token 层（重写）
  variables.scss                完全重写：删除所有渐变变量，注入新 Rail/Side/Main token
  element-plus.scss             覆写 --el-color-primary、--el-border-radius-* 等
  index.scss / app.scss         调整字号阶梯、密度
  component.scss                全局组件类清理

ui/src/layout/                  骨架层（重写）
  layout-template/MainLayout.vue        Rail + Side + Main 三段
  layout-template/SystemMainLayout.vue  同上（系统设置区复用）
  layout-template/SimpleLayout.vue      登录/全屏页保留但去渐变
  layout-rail/  (新建目录)              顶级 Rail 组件 + 模块数据源
  layout-side/  (新建目录)              二级 Side 组件
  layout-header/                        旧目录大部分作废，保留 avatar 子组件

ui/src/router/                  路由（最小改动）
  routes.ts                     "/" redirect 改到 /workbench
  modules/workbench.ts (新建)   /workbench 路由
  modules/*.ts meta.title       同步新名

ui/src/views/                   页面层
  workbench/ (新建)             工作台首页
  login/index.vue               重写为左暗右白
  login/ResetPassword.vue       套同款布局
  login/ForgotPassword.vue      套同款布局
  chat/ (整目录)                视觉重写 + 移动端响应；URL/postMessage 不动
  application/                  卡片网格重做
  application-overview/         数据卡块重做
  application-workflow/         LogicFlow 节点皮肤替换
  knowledge-workflow/           同上
  tool-workflow/                同上
  其它 views                    依赖新 token 自动跟随，按需局部修

ui/src/locales/                 文案层
  zh-CN/*.json                  全量术语 value 重命名
  en/*.json                     同步

ui/src/assets/                  素材层
  logo/                         替换为用户提供 Logo（含 favicon）
  *.svg/*.png                   清理 MaxKB 印记
ui/public/                      favicon.ico、InsightHub.gif、tipIMG.jpg 替换或删除

ui/admin.html / ui/chat.html    title / meta description

ui/src/{utils,api,stores,components,workflow,...}/  字符串扫描："MaxKB" → 产品名
                                                    （已 grep 出 20 个文件）

** 新增依赖 **
@iconify/vue
@iconify-json/lucide
```

### 7.2 Phase 切分（共 7 期）

| Phase | 内容 | 估时 | 阻塞 |
|-------|------|------|------|
| **P1 · 基础设施** | 重写 token + EP 主题 + Lucide 接入 + 品牌素材替换 + 字符串清理 | 2 天 | ✓ 必须先做 |
| **P2 · 骨架与导航** | Rail+Side+Main 布局 + 菜单 IA + i18n 改名 | 3 天 | ✓ P3-P7 都依赖 |
| **P3 · 登录页** | 左暗右白重写 + ResetPassword/Forgot 同步 | 1 天 | — |
| **P4 · 工作台 + 列表** | 新工作台路由与页面 + 应用列表卡片重做 | 2 天 | — |
| **P5 · /chat + 移动端** | 对话视觉重写 + 移动端响应 + 嵌入兼容自测 | 2.5 天 | — |
| **P6 · 工作流编辑器** | LogicFlow 节点皮肤 + 画布网格 + 工具条 | 1.5 天 | — |
| **P7 · 收尾** | 错误页/设置页等长尾视觉补漏 + 全站走查 + 截图比对 | 1 天 | — |

**总计约 13 天**（单人，含联调；并行可压到 7-8 天）。**P1 + P2 一次性合并**，再启动 P3–P7（可并行）。

---

## 8. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| LogicFlow 内部 CSS 选择器变更（升级时） | 工作流外观回退 | 节点皮肤用 CSS 变量 + `:deep()` 局部覆盖；记录依赖的内部 class |
| MaxKB 上游升级合并冲突 | 维护成本上升 | Token 集中在 `variables.scss`；新组件放 layout-rail/layout-side 等新文件，少改动原 layout-header/ |
| Element Plus 大版本升级断 token | 主题失效 | 覆写依赖的 EP CSS 变量名记录在 element-plus.scss 顶部注释 |
| `/chat` 嵌入破坏 | 客户业务中断 | P5 必须用真实 `<script src="../embed.js">` 嵌入到第三方测试页验证 postMessage |
| "MaxKB" 字符串遗漏 | 指纹残留 | 全仓 `grep -i maxkb` 纳入 PR check，仅允许 `LICENSE` 与上游 README 残留 |
| 品牌素材未及时提供 | P1 阻塞 | P1 用占位 logo + 占位主色（如 `#0f172a`），交付时刷一遍即可 |

---

## 9. 验收准则

1. **30 秒辨认测试**：让一个熟悉 MaxKB 的人首次访问，30 秒内不能立刻反应出"这是 MaxKB"（硬性目标）
2. **后端零改动**：`apps/` 目录 git diff 为空
3. **字符串清理**：全仓 `grep -i maxkb` 仅剩 `LICENSE` 与上游 README（保留法律义务）
4. **嵌入合约保持**：`/chat/:accessToken`、`/user-login/:accessToken` URL 与 postMessage 协议不变；提供第三方页面嵌入 demo 验证通过
5. **桌面无错位**：1280px / 1440px / 1920px 三档管理后台截图比对无错位
6. **移动端 `/chat` 适配**：iPhone 13 (390×844) 与 Pixel 7 (412×915) 实机/模拟器截图通过
7. **i18n 全量改名**：所有出现 MaxKB 术语的 i18n value 已替换；无 hardcoded 文案

---

## 10. 待用户提供的素材

| # | 素材 | 用途 |
|---|------|------|
| 1 | 产品名（中/英） | 全站文案、admin.html title、Rail Logo 文字 |
| 2 | Logo SVG（带文字 / 纯图标 / currentColor 三套） | Rail 顶部、登录页、favicon |
| 3 | 品牌主色 hex（含 hover/active/soft 4 档） | `--brand-primary*` token |
| 4 | favicon.ico（32×32） | `ui/public/favicon.ico` |
| 5 | （可选）slogan 中英文 | 登录页左栏 |

P1 阶段可用占位（深石板 `#0f172a` + 文字 Logo），交付前用户素材到位即可一次性刷入。
