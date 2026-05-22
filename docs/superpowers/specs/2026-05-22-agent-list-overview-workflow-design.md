# 智能体列表 + 概览 + 工作流 · 三页重设计

- **日期**:2026-05-22
- **分支**:`feat/frontend-redesign`
- **范围**:`ui/` 前端:智能体列表页 / 智能体详情概览页 / 应用工作流编辑器
- **不动**:`apps/` 后端代码、所有 API、嵌入合约 (`/chat/:accessToken` 与 `/user-login/:accessToken` URL + postMessage)
- **依赖**:前置 spec `2026-05-21-frontend-redesign-design.md`(整体重设计)已落地的 P1+P2(Token + 骨架)+ P3+P4(登录+工作台+列表雏形)+ P6+P7(LogicFlow 节点皮肤)

---

## 1. 背景

整体重设计第一轮交付后,巡检发现三个核心页面仍残留 MaxKB 风格或未实现 spec 约定:

1. **智能体列表页**:左侧 folder 树面板信息密度低(常态只有一个"根目录"),卡片头像沿用 MaxKB 紫机器人,工具栏分布无逻辑分组
2. **智能体概览页**:两张大卡(基本信息 + 监控统计)垂直堆叠,4 个 MaxKB 风彩色圆形统计 icon,4 张并排折线图占据大量空间但信息密度低
3. **工作流编辑器**:Spec §6.4 约定(节点顶部 2px 色条 / 画布 20×20 网格 / 直角折线 / 右抽屉配置)未实现,仍是 24px 色块头像 + 贝塞尔曲线 + 白底无网格 + 模态弹窗

本 spec 整合三页的重组方案,选定执行强度,统一视觉约定。

---

## 2. 设计原则(沿用 + 强化)

| # | 原则 | 本 spec 强化点 |
|---|------|------|
| 1 | **后端零改动** | 列表页"标签"概念在 UI 层映射到后端 folder,不新增 tag 表 |
| 2 | **结构差异 > 颜色差异** | 概览页彻底改信息布局(Hero + tile + 双 panel),不仅是改色 |
| 3 | **去 MaxKB 视觉指纹** | 头像/icon 全部换 Lucide outline 单色;彻底删彩色圆形统计 icon |
| 4 | **信息密度提升** | 4 张折线图 → 1 张主图 + 切换器;左侧 folder 树 → 顶部分组瀑布 |
| 5 | **可控低风险** | 工作流选择"严格按 spec",改动只在 CSS/LogicFlow theme/抽屉层,业务逻辑零改 |

---

## 3. 三页面详细设计

### 3.1 智能体列表 · D2 标签分组瀑布

**目标**:用按"标签"自动分组的瀑布列表取代左侧 folder 树,信息密度高、无嵌套深度负担,一屏看完全部分类。**前端层把 folder API 重新包装为"标签",后端零改动**。

#### 3.1.1 布局

```
┌──────┬────────┬──────────────────────────────────────────────┐
│ Rail │  Side  │  Main                                        │
│ 64px │ 200px  │  ┌─────────────────────────────────────────┐ │
│      │ 应用… │  │ 🔍 搜索智能体     ⫶ 按标签分组    + 创建 │ │
│      │ 用户… │  ├─────────────────────────────────────────┤ │
│      │        │  │ ▌研发(5)                                │ │
│      │        │  │ [卡][卡][+在「研发」新建]              │ │
│      │        │  │                                          │ │
│      │        │  │ ▌客服(4)                                │ │
│      │        │  │ [卡][卡][卡][卡]                        │ │
│      │        │  │                                          │ │
│      │        │  │ ▌未分类(1)                              │ │
│      │        │  └─────────────────────────────────────────┘ │
└──────┴────────┴──────────────────────────────────────────────┘
```

#### 3.1.2 关键变更

- **路由布局**:`/application` 从 `SimpleLayout` 切到 `MainLayout`(与其它模块一致)
- **Side 二级菜单**:`应用列表(/application)` 单项;spec §5.2 的"用户行为(/chat-user)"项需要新建全局 chat-user 列表路由,**不在本 spec 范围**,留 v2
- **顶部 toolbar**:`🔍 搜索 input(flex 1)` | `⫶ 按 X 分组 下拉(默认: 按标签分组)` | `+ 创建`(主操作,深石板)
- **分组瀑布**:
  - 每组标题:`▌color-bar  folder.name  <count>`(color-bar 用 folder 名 hash 映射到 emerald/amber/violet/cyan/red 5 色循环)
  - 每组卡片网格:`grid-template-columns: repeat(auto-fill, minmax(260px, 1fr))`
  - 每组末尾:虚线"+ 在「{folderName}」新建"卡(点击 = 当前 folder 上下文创建)
- **分组下拉选项**:`不分组(平铺) / 按标签分组(default) / 按状态分组 / 按创建人分组`
- **卡片**:见 §4 跨页统一约定
- **空态**:无任何智能体时,显示居中"快速开始"图示 + "+ 创建第一个智能体"按钮

#### 3.1.3 现有 folder UI 处理

- 旧 `ui/src/components/folder-tree/` 组件保留(其它模块如知识库仍会用到),仅 application 模块的 `index.vue` 改用新版"分组瀑布"组件
- 旧"折叠箭头 < / 搜索 / 排序"工具组移除(分组瀑布天然解决了"找到一个分类"的需求)
- 旧"根目录"等 folder 用语在 UI 全部改称"标签 / 分类",`folder_id` 等 URL / API 参数字段仍使用 folder 命名(不动)

#### 3.1.4 API 调用映射

| UI 动作 | 后端调用 |
|---------|---------|
| 加载分组 | `GET /folders` 拿 folder 列表 + `GET /applications` 拿全部 application |
| 标签管理(改名/删) | `PATCH /folders/:id` / `DELETE /folders/:id` |
| 在分组下创建 | `POST /applications` 带 `folder_id` 参数(已有字段) |
| 拖卡片到其它组 | `PATCH /applications/:id` 改 `folder_id`(已有字段) |
| 切换"按状态分组" | 前端纯客户端用 `application.status` 分组,不调接口 |

---

### 3.2 智能体概览 · G1 单页紧凑

**目标**:把"基本信息 + 监控统计"两张大卡重组成 Hero + tile + 双 panel 单屏布局,4 张图压成 1 张主图,信息密度提升 3x,Lucide outline 单色 icon 取代 MaxKB 彩色圆形 icon。

#### 3.2.1 布局

```
┌────────────────────────────────────────────────────────────────────────┐
│ [M] 学生知识点自测智能体                                                │
│     ● 已发布 · 高级 · 系统管理员 · 2026-05-22                          │
│                            [⚙显示设置][⤤嵌入][🔒访问限制][→去对话]   │
├────────────────────────────────────────────────────────────────────────┤
│ ┌──────────┬──────────┬──────────┬──────────┐                          │
│ │ 👥 用户   │ 💬 提问  │ ⚛ Token │ ☺ 满意度 │                          │
│ │ 128       │ 1.2k     │ 340k     │ 94%     │                          │
│ │ ↑+12 本周│ ↑+85 本周│ —持平   │ ↑+3pt   │                          │
│ └──────────┴──────────┴──────────┴──────────┘                          │
│                                                                          │
│ ┌──────────────────────────┐  ┌──────────────────────────┐             │
│ │ 提问趋势 [过去7天▾] [指标▾]│  │ 访问与接入                 │             │
│ │ ╱─────╲╱──╲╱──             │  │ 公开访问  [●●○] 开启       │             │
│ │                            │  │ 链接 https://… 📋         │             │
│ │                            │  │ API 文档 /chat/api-doc/ ↗ │             │
│ │                            │  │ API Key  [🔑 管理]        │             │
│ └──────────────────────────┘  └──────────────────────────┘             │
└────────────────────────────────────────────────────────────────────────┘
```

#### 3.2.2 关键变更

**Hero 横条**(56px 内容高度):
- 左:48px 头像方块(单色字符,如 `M` `t`,**取代 MaxKB 紫机器人 fallback**)
- 中:智能体名称(18px/600) + 副信息行(状态点+类型+创建人+日期, 12px slate-500)
- 右:4 个 outline button:`⚙ 显示设置 / ⤤ 嵌入第三方 / 🔒 访问限制` + 1 个 primary button `→ 去对话`

**4 数据 tile 行**:
- 4 等宽 tile,`grid-template-columns: repeat(4, 1fr); gap: 12px;`
- 每 tile 内容:
  - 28×28 浅灰底圆角方块,内含 Lucide outline icon(用户/消息/原子/笑脸),色 = `--brand-primary` 深石板
  - 数字:22px/600,深石板
  - 标签:10px uppercase letter-spacing 0.05em,slate-400
  - delta:`↑ +12 本周`(emerald-500)/ `↓ -5` (red-500) / `— 持平`(slate-400)
- **彻底删除**当前的彩色圆形 icon(orange/blue/purple/red 圆斑)

**双 panel**(下方,`grid-template-columns: 1fr 1fr; gap: 12px`):

左 panel "提问趋势":
- 顶部 `h4 提问趋势(13px/600)` + 右侧两个 select:`[过去7天▾] [指标:用户总数/提问次数/Tokens/满意度▾]`
- 主体:1 张折线图(用 ECharts,沿用现有图表组件,改色为 `--brand-primary` 与 `--text-tertiary`)
- **取代**当前 2x2 共 4 张并排小图

右 panel "访问与接入":
- 列表风格,每行:`label(70px slate-500) | value(monospace 灰底)| 操作 icon`
- 4 行:`公开访问 | toggle | 状态文字`、`链接 | URL | 📋 复制`、`API 文档 | URL | ↗ 跳转`、`API Key | (空) | 🔑 管理 Key 按钮`

#### 3.2.3 删除项

- 当前"基本信息"卡片的 `| 基本信息` antd 风竖线 heading
- 当前 4 张并排折线图(只保留 1 张主图)
- 当前彩色圆形统计 icon(`.avatar-blue/orange/purple/red`)在 overview 页的使用

#### 3.2.4 数据流

- Hero 数据:走现有 `applicationApi.getDetail(id)`
- 4 tile 数据:走现有 `applicationOverviewApi` 聚合接口
- 趋势图:走现有 `getStatistics(id, range, metric)`
- 访问开关 / API Key / Embed:走现有接口

**零新增 API**。

---

### 3.3 工作流编辑器 · W1 严格按 spec §6.4

**目标**:把 spec §6.4 的视觉约定真正落地,改动只在 CSS / LogicFlow theme / 抽屉组件层,业务逻辑零改。

#### 3.3.1 节点视觉

```
旧:
┌──────────────────┐
│ [orange ●] 开始   │   ← 24px 圆角方块头像(MaxKB 风彩色)
│ 触发器             │
└──────────────────┘

新:
┌══════════════════┐   ← 2px 顶部色条 (类型色)
│ ■ 开始             │   ← 12×12 类型色实心方块 + 名称 13px
│ 触发器             │
└──────────────────┘
```

- **节点容器**:`background: #fff; border: 1px solid #e5e7eb; border-radius: 6px; box-shadow: 0 1px 2px rgba(15,23,42,0.04);`
- **顶部 2px 色条**:`height: 2px; background: var(--node-type-color)`
- **类型 → 色**(spec §6.4):
  - `trigger/start` → emerald-500 `#10b981`
  - `data/retrieval` → blue-500 `#3b82f6`
  - `ai/llm` → violet-500 `#8b5cf6`
  - `logic/branch` → amber-500 `#f59e0b`
  - `output/end` → red-500 `#ef4444`
- **节点内 header**:`12×12 类型色实心方块 + 名称(13px/500 深石板)`
- **节点内 sub**:类型说明,11px slate-400

#### 3.3.2 画布

- 底色:`#ffffff`
- 网格:`background-image: linear-gradient(#f1f5f9 1px, transparent 1px), linear-gradient(90deg, #f1f5f9 1px, transparent 1px); background-size: 20px 20px;`
- **取代**当前白底无网格

#### 3.3.3 连线

- LogicFlow 配置:`edgeType: 'polyline'`(直角折线),取代默认 `bezier`
- 样式:`stroke: #0f172a; stroke-width: 1.5; fill: none;`
- 箭头:保留(15° 三角形),色同 stroke
- **取代**当前 `bezier` 默认浅灰描边

#### 3.3.4 配置面板

- 触发:双击节点 / 单击节点上 ⚙ icon
- 位置:右侧抽屉,420px 宽,从右滑入(transition 200ms)
- 结构:
  ```
  ┌────────────────────┐
  │ 节点名 · 配置    ✕ │  ← header 16px/600 + close icon
  ├────────────────────┤
  │ (滚动区)            │
  │ 字段 1              │
  │ 字段 2              │
  │ ...                  │
  ├────────────────────┤
  │       [取消] [保存] │  ← footer 固定,16px/24px padding
  └────────────────────┘
  ```
- **取代**当前模态弹窗(遮挡画布,无法同时看上下游节点)
- 抽屉不遮罩画布(无 overlay),允许直接在画布上操作其它节点

#### 3.3.5 工具栏

- 现状已基本对齐 spec(浮动吸顶居中),**不改动**

#### 3.3.6 改动范围

```
ui/src/views/application-workflow/        节点配置抽屉重写
ui/src/views/knowledge-workflow/           同上
ui/src/views/tool-workflow/                同上
ui/src/workflow/common/NodeContainer.vue   顶部色条 + 12×12 icon
ui/src/workflow/icons/*-node-icon.vue      改用 12×12 类型色方块
ui/src/workflow/common/edge.ts             LogicFlow polyline 配置 + stroke 色
ui/src/workflow/common/CustomLine.vue      直角折线渲染
ui/src/styles/workflow.scss                网格 + 节点样式
```

业务逻辑(节点的 props、运行时校验、保存接口)**零改动**。

---

## 4. 跨页面统一约定

### 4.1 Icon 系统

| 用途 | 选型 |
|------|------|
| 一般 UI(导航/按钮/列表)| Lucide outline 1.5px,16/20px,色 `var(--text-primary)` 或 `var(--brand-primary)` |
| 智能体头像 | 单色字符方块(`M`/`t`/`客`):28×28 圆角 4px,bg `var(--brand-primary)`,字 18px/600 白色;字符 = 名称首字 |
| 工作流节点 icon | 12×12 实心方块,色 = 类型色(emerald/blue/violet/amber/red 五选一) |
| 统计 tile icon | Lucide outline,20px,色 `var(--text-primary)`,衬于 28×28 浅灰底圆角方块 |

**禁用**:MaxKB 紫机器人 fallback、彩色圆形 mark、渐变 logo、动画 GIF emoji。

### 4.2 卡片

```scss
.card-unified {
  background: var(--main-bg);
  border: 1px solid var(--border-base);
  border-radius: 6px;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition: border-color .15s, box-shadow .15s, transform .15s;

  &:hover {
    border-color: rgba(15, 23, 42, 0.15);
    box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06);
    transform: translateY(-2px);
  }
}
```

### 4.3 状态指示

| 状态 | 表达 |
|------|------|
| 已发布 | `● 已发布`,点 emerald-500,文字 slate-500,11px |
| 草稿 | `● 草稿`,点 slate-400,文字 slate-500,11px |
| 已归档 | `● 已归档`,点 slate-300,文字 slate-400,11px |

**禁用**:`el-tag` 风彩色背景标签(`.tag.success/.warning/.danger`)在状态指示场景。状态保持中性,业务标签(如"简易/高级")才用 tag 样式。

### 4.4 按钮分组

| 角色 | 样式 |
|------|------|
| 主操作(每页 ≤ 1) | `--brand-primary` 实色 + 白字 |
| 次操作 | outline border (`--border-base`) + 深石板字 + 白底 |
| 三级链接操作 | 纯文字,无 border 无 bg,hover 改深石板 |

---

## 5. 落地策略

### 5.1 Phase 切分

| Phase | 内容 | 估时 |
|-------|------|------|
| **PA · 列表页 D2** | application/index 重写为分组瀑布;切 MainLayout;Side IA 接入 | 1.5 天 |
| **PB · 概览页 G1** | application-overview 重写 Hero + tile + 双 panel;删多余图表 | 1 天 |
| **PC · 工作流 W1** | 节点样式 + LogicFlow polyline + 网格 + 抽屉配置 | 1.5 天 |
| **PD · 跨页约定** | 卡片/icon/状态/按钮统一抽出共享样式 | 0.5 天 |

**总计约 4.5 天**(单人)。可三人并行(PA/PB/PC 解耦),压缩到 1.5-2 天。

### 5.2 验收

1. `npm run type-check` 退出码 0
2. `npm run build` 编译通过
3. dev server 走查 3 页面:
   - `/application`:分组瀑布渲染、点 chip-less 分组依然能在分组下创建、空 folder 显示空状态
   - `/application/.../SIMPLE/overview`:Hero 4 按钮可点、4 tile 数字正确、趋势图切换 work、访问 toggle work
   - `/application/.../workflow`:节点顶部色条按类型显示、画布网格可见、连线直角折线、双击节点弹右抽屉、抽屉底部保存 work
4. 控制台 0 warnings / 0 errors
5. `git diff apps/` 为空(后端零改动)

---

## 6. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| `application/index.vue` 改大动静量,影响共享组件 | 卡片/搜索/批量选择回退 | 抽出新组件 `ApplicationGroupedList.vue`,旧 `index.vue` 内容保留为引用 |
| LogicFlow `polyline` 配置改造可能影响节点位置 | 现有 workflow 打开错位 | 用 LogicFlow 自带 router 模式,不动节点 x/y 坐标 |
| 概览页 1 张图替代 4 张,用户找不到旧指标 | 体验回退 | 主图右侧 select 包含原 4 指标全部,默认提问 |
| 抽屉宽度 420px 在 1280px 屏占比 33%,小屏挤 | 节点信息看不全 | 节点保留主信息;详细字段一律抽屉内 |

---

## 7. 不在范围内

- 列表页拖拽排序卡片(后续可单独议)
- 全局"用户行为"列表路由(spec §5.2 提到的智能体模块 Side 第二项 `/chat-user`,需新建路由 + 列表视图,留 v2)
- 工作流节点的 **n8n 风左侧 type bar + 显式端口**(W2 方案,留 v2)
- 工作流"调试 / 模拟运行"面板重设计(与本 spec 无关)
- 移动端适配(管理后台 < 1280px 不支持,沿 spec 总则)

---

## 8. 完成定义

本 spec 实施完毕的标志:
1. 三页面截图 + 设计 mockup 一一比对无错位
2. 30 秒辨认测试通过(任何熟悉 MaxKB 的人,三页面任一,30 秒内不会反应出是 MaxKB)
3. `apps/` git diff 为空
4. CI 通过
