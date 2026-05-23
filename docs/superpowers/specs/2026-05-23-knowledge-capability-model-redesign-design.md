# 知识资产 / 能力扩展 / 模型 三模块重设计

- **日期**：2026-05-23
- **分支**：`feat/frontend-redesign`
- **范围**：`ui/` 前端三个 Rail 模块（knowledge / capability / model）下的页面与子组件
- **不动**：`apps/` 后端代码、所有 API、嵌入合约（`/chat/:accessToken` 与 `/user-login/:accessToken`）
- **依赖**：前置 spec 已落地的 atoms：`PageHeader` / `StatusDot` / `AgentAvatar` / `LucideIcon` / `.card-unified` / `.toolbar`

---

## 1. 背景

智能体 spec 和系统管理 spec 把"去 MaxKB 化"的 atom 体系（`PageHeader`+`.card-unified`+`StatusDot`+`LucideIcon`）落地之后，剩下三个 Rail 模块（知识资产 / 能力扩展 / 模型）的页面**仍有大面积 MaxKB 视觉指纹**：

- **重灾区 4 页全 MaxKB 风**：`/document`、`/problem`、`/hit-test`、`/trigger` 仍是 `<h2>` + 外层 `<el-card>` + `p-16-24` 根 padding + `AppIcon` 图标 + 状态用 raw `<el-icon>`
- **半新半旧 4 页**：`/knowledge`、`/tool`、`/model`、`/paragraph` 已经用 `LayoutContainer` 双栏壳，但还有少量残留（shared-folder 分支死代码、AppIcon、外层 el-card 嵌套）
- **模型子组件 9 处死分支**：`ModelCard.vue` / `CreateModelDialog.vue` 仍有 `'systemShare' | 'systemManage'` 条件分支，对应路由在系统管理 spec 的 PE6 已被删除，但组件代码没清
- **共享工作流画布 grid 偏离智能体 spec W1**：`ui/src/workflow/index.vue` 用 LogicFlow 原生 `grid: { size: 10, type: 'dot' }`，与 W1 §6.4 规定的 20px line CSS 网格不符。影响 application-workflow / knowledge-workflow / tool-workflow 三个 editor

3 模块下页面的**后端 API 100% 都活的**（除了 `tool/store.ts` 的 2 个 store template 方法），这次 redo 不像系统管理那样有"删孤儿页"环节——**主要是视觉对齐**。

本 spec 一次性把 3 模块对齐到"去 MaxKB 化"基准。

---

## 2. 设计原则

| # | 原则 | 强化点 |
|---|---|---|
| 1 | **后端零改动** | `apps/` git diff 为空 |
| 2 | **复用现有 atom**：PageHeader / StatusDot / .card-unified / .toolbar / LucideIcon | 不抽不必要的新组件 |
| 3 | **保留 `LayoutContainer` 双栏抽象** | 不破坏双栏页面（knowledge/tool/model/paragraph index） |
| 4 | **结构差异 > 颜色差异** | hit-test 嵌套 el-card 拆扁；trigger 状态从图标改 StatusDot |
| 5 | **死分支顺手清** | atom 升级时一并清掉 ModelCard 9 处 systemShare/systemManage 分支 |
| 6 | **范围保守** | knowledge / tool 子组件 dialogs 不在范围；dynamics-api facade 不重构 |

---

## 3. 共享原子（PA Phase）

### 3.1 直接复用（已有）

| 原子 | 路径 | 用途 |
|---|---|---|
| `<PageHeader>` | `ui/src/components/page-header/` | 4 重做页的统一头 |
| `<StatusDot>` | `ui/src/components/status-dot/` | 已有 5 keys：`published / draft / archived / enabled / disabled` |
| `<AgentAvatar>` | `ui/src/components/agent-avatar/` | （本 spec 未用到，列出仅作 reference） |
| `<LucideIcon>` | `ui/src/components/lucide-icon/` | 替代 AppIcon |
| `.card-unified` | `ui/src/styles/component.scss` | 外层卡 |
| `.toolbar` | `ui/src/styles/component.scss` | 批操作 + 搜索行 |

### 3.2 按需扩展 StatusDot 的候选 status key

实施 PB-PE / PG 阶段时如果需要，再扩展。候选：

| Key | 颜色 | 用途 |
|---|---|---|
| `indexing` | amber-500 `#f59e0b` | 文档索引中（document） |
| `error` | red-500 `#ef4444` | 错误状态（model / document） |
| `active` | emerald-500 `#10b981` | 触发器启用（trigger） |
| `paused` | slate-400 `#94a3b8` | 触发器暂停 / 模型暂停下载（trigger / model） |

不强求 PA Phase 完成扩展——遇到再扩；不需要就不扩。

### 3.3 `LayoutContainer` 处置

现状：knowledge/tool/model/paragraph index 用 `<LayoutContainer showCollapse>` 包"左 list 右 main"双栏。

**本 spec PF Phase 不引入 PageHeader 到这 4 个页面**：保留已有的 header slot 模式（FolderBreadcrumb / search row），只清残留。理由：LayoutContainer 已经有"主区头部"的位置，再叠一个 PageHeader 反而冗余。

未来如果有新的双栏管理页需要建，可以在 LayoutContainer 的 main 内顶部叠 `<PageHeader>` —— 这两者结构不冲突。但本 spec 不打开这扇门。

### 3.4 不抽新组件

| 不抽 | 原因 |
|---|---|
| `<DataTableShell>` | document/problem/trigger 表列差异大 |
| `<FormCard>` | 本 spec 没有纯表单页 |
| `<MetricTile>` | 不需要 |

### 3.5 PA Phase 改动

- 若无需扩展 StatusDot：**0 改动**（纯 review）
- 若需扩展：仅修改 `ui/src/components/status-dot/StatusDot.vue` 增加 status key + CSS rule + i18n 文本

---

## 4. 4 页重做（PB-PE Phase）

### 4.1 `/document` 重做（PB Phase）

**改 `ui/src/views/document/index.vue`**：

```
┌────────────────────────────────────────────────────────────┐
│ [< 返回]  文档管理                       [批量删除] [+ 上传]  │
│ 知识库 · {kb_name} · 共 {n} 个文档                          │
├────────────────────────────────────────────────────────────┤
│ [按文档名▾] [搜索...]              [状态筛选] [类型筛选]      │
├────────────────────────────────────────────────────────────┤
│ ☐ │ doc_name │ ● 已索引 │ 类型 │ 段落数 │ 创建时间 │ ⋯       │
└────────────────────────────────────────────────────────────┘
```

- 删除外层 `<div class="document p-16-24">` 根 div、`<h2 class="mb-16">`、外层 `<el-card style="--el-card-padding: 0">`
- 套 `<PageHeader showBack>`：title 用现有 i18n key、subtitle "{知识库名} · 共 {n}"
- actions slot 放批量删除 + 上传按钮
- 外层 `<div class="card-unified">` 包 toolbar + `<app-table>`
- 状态列：raw text/icon → `<StatusDot status="indexing|enabled|error">`
- 操作列 AppIcon 全部 → LucideIcon
- 保留：UploadDocument / ImportLarkDocument / ImportWorkflowDocument 等 dialog
- 保留：所有 `<el-table-column>` 字段不动
- API 调用零改动（`ui/src/api/knowledge/document.ts` 不动）

### 4.2 `/problem` 重做（PC Phase）

**改 `ui/src/views/problem/index.vue`**：

```
┌────────────────────────────────────────────────────────────┐
│ [< 返回]  问题管理                       [批量删除] [+ 创建]  │
│ 知识库 · {kb_name} · 共 {n} 个问题                          │
├────────────────────────────────────────────────────────────┤
│ [按问题搜索...]                                              │
├────────────────────────────────────────────────────────────┤
│ ☐ │ question_text │ 关联段落数 │ 创建时间 │ ⋯              │
└────────────────────────────────────────────────────────────┘
```

- 套 `<PageHeader showBack>` + `.card-unified` + `.toolbar`
- AppIcon → LucideIcon（`app-generate-question` → `sparkles`、`app-delete` → `trash-2`、`app-edit` → `pencil`）
- API 零改动

### 4.3 `/hit-test` 重做（PD Phase）

**改 `ui/src/views/hit-test/index.vue`**：

```
┌────────────────────────────────────────────────────────────┐
│ [< 返回]  命中测试                    [⚙ 检索参数]            │
│ 知识库 · {kb_name}                                          │
├────────────────────────────────────────────────────────────┤
│ ┌─ 查询输入 ────────────────────────────────────────────┐  │
│ │ [文本输入框]                                  [搜索]  │  │
│ └───────────────────────────────────────────────────────┘  │
│                                                            │
│ ┌─ 检索结果 ────────────────────────────────────────────┐  │
│ │ ▌段落 1（相似度 92%）                                 │  │
│ │   {paragraph content} ...                            │  │
│ │   👍 评分 / 👎                                       │  │
│ │ ─────────────────────────────────────────────────     │  │
│ │ ▌段落 2（相似度 88%）                                 │  │
│ │   ...                                                 │  │
│ └───────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

- 删除外层 `<div class="hit-test p-16-24">` 和 `<el-card class="hit-test__main">` 嵌套
- **拆掉嵌套 el-card**：原 outer `<el-card>` → 内 `<el-card shadow="never">` 检索结果 → 内嵌段落卡。改为单层 `.card-unified` 外层 + section 分组（h4/h5 + 上下间距分隔 + 横线 `border-bottom`），不再嵌 el-card
- 检索参数 popover 原来用 `<el-card shadow="never">` × 2（搜索模式 + 段落控制）；改为 popover 内直接 form items，不嵌 card
- AppIcon `app-like-color / app-oppose-color` → LucideIcon `thumbs-up / thumbs-down`
- 保留所有检索逻辑 / `el-scrollbar` / 评分逻辑
- API 零改动

### 4.4 `/trigger` 重做（PE Phase）

**改 `ui/src/views/trigger/index.vue`**：

```
┌────────────────────────────────────────────────────────────┐
│ 触发器管理                              [批量删除] [批量启用]│
│ 共 {n} 个触发器                                  [+ 创建]   │
├────────────────────────────────────────────────────────────┤
│ [按触发器名▾] [搜索...]                       [状态筛选]     │
├────────────────────────────────────────────────────────────┤
│ ☐ │ trigger_name │ ● 已启用 │ 类型 │ 关联资源 │ Cron │ ⋯   │
└────────────────────────────────────────────────────────────┘
```

- 删除外层 `<div class="trigger-manage p-16-24">` + `<h2 class="ml-24 mb-16">` + 外层 `<el-card>` + `main-calc-height`
- 套 `<PageHeader>`（**不需要 showBack** —— trigger 是 Rail 子菜单顶级页，不是详情页）
- actions slot 放 3 按钮
- 状态列：`<el-icon>` + AppIcon 二选一 → `<StatusDot status="active|paused">` （PA.2 扩展）
- 操作列 AppIcon → LucideIcon
- 保留：TriggerDrawer / ResourceTriggerDrawer / ExecutionDetailDrawer / TriggerTaskRecordDrawer
- API 零改动

---

## 5. 4 页轻量打磨（PF Phase）

**零结构性改动**——只清残留 + 替图标。这 4 页已经在用 `LayoutContainer`，不引入 `<PageHeader>`。

### 5.1 `/knowledge`（`ui/src/views/knowledge/index.vue`）

- 删除条件 `<h2>` 残留（shared-folder 分支：`v-if="folder.currentFolder?.id === 'share'"`）——shared 路由已在系统管理 PE6 删，这分支永远进不去
- 模板内 AppIcon 残留替换为 LucideIcon
- 单文件改动 ≤ 30 行

### 5.2 `/tool`（`ui/src/views/tool/index.vue`）

- 同 5.1：删 shared 分支的条件 `<h2>` 死代码
- AppIcon → LucideIcon
- 单文件改动 ≤ 30 行

### 5.3 `/model`（`ui/src/views/model/index.vue`）

- 基本已现代化
- 检查 `apiType === 'systemShare' / 'systemManage'` 条件分支并删除（PG 子组件清理时同步处理这里）
- `apiType` prop 传递给 ModelCard 的逻辑改为永远 `'workspace'`，或直接删除
- 期望改动 ≤ 20 行

### 5.4 `/paragraph`（`ui/src/views/paragraph/index.vue`）

```
当前：<div class="paragraph p-12-24"> > <el-card class="paragraph__main"> > <LayoutContainer> > ...
改后：<LayoutContainer class="paragraph"> > ...
```

- 删除外层 `<div class="paragraph p-12-24">` + 包裹的 `<el-card>`
- LayoutContainer 升为根；padding 移到 scoped style 或父级路由
- 残留 `<h3>` 如仅作 section 分组保留
- 单文件改动 ≤ 30 行

---

## 6. 模型子组件 atom 升级 + 死分支清（PG Phase）

### 6.1 范围

```
ui/src/views/model/component/Provider.vue
ui/src/views/model/component/ModelCard.vue
ui/src/views/model/component/CreateModelDialog.vue
ui/src/views/model/component/EditModel.vue
ui/src/views/model/component/SelectProviderDialog.vue
ui/src/views/model/component/ParamSettingDialog.vue
ui/src/views/model/component/AddParamDrawer.vue
```

### 6.2 共同改动模式

- **AppIcon → LucideIcon**：全部 `<AppIcon iconName="app-XXX">` 替换为 `<LucideIcon name="YYY">`。常见映射：
  - `app-more` → `more-horizontal`
  - `app-edit` → `pencil`
  - `app-delete` → `trash-2`
  - `app-add-outlined` → `plus`
  - `app-warning` → `alert-triangle`
  - `app-key` → `key`
  - `app-folder` → `folder`
  - `app-shared-active` → `share-2`
  - 找不到完美对应：fallback `circle-help` + 代码注释 todo
- **状态 → StatusDot**：`<el-icon><WarningFilled /></el-icon>` + ERROR/PAUSE_DOWNLOAD 文字 → `<StatusDot status="error">` / `<StatusDot status="paused">`
- **el-tag 滥用清理**：保留中性 informational（如"Shared" `<el-tag type="info">`）；真状态用 StatusDot

### 6.3 ModelCard.vue 死分支清理（顺手做）

| 行号 | 旧 | 改 |
|---|---|---|
| 行 87-88 | `v-if="isSystemShare"` 守卫的"Authorized Workspace" menu | 删 |
| 行 113, 148 | `v-if="apiType === 'workspace'"` 守卫的 2 处 drawer | 改无条件渲染 |
| 行 141-144 | `<AuthorizedWorkspace v-if="isSystemShare">` | 删 |
| 行 181 | prop 类型 `'systemShare' \| 'workspace' \| 'systemManage'` | 改 `'workspace'` 或删 apiType prop |
| 行 187 | `isSystemShare` computed | 删 |
| 行 244, 255, 278 | `loadSharedApi({ systemType: props.apiType })` | 改 `loadSharedApi({ systemType: 'workspace' })` 或直接走 workspace API |

**保守保留 `loadSharedApi` 调用层**，只把 systemType 写死 'workspace'——彻底重构 dynamics-api 不在范围。

### 6.4 CreateModelDialog.vue 死分支清理

| 行号 | 旧 | 改 |
|---|---|---|
| 行 251-257 | `apiType` computed | 删（永远 'workspace'） |
| 行 389 | 同 ModelCard.244 处理 | 同上 |

### 6.5 index.vue 顺带处理（与 PF.3 配合）

- 行 133-141：传给 ModelCard 的 `apiType` prop 删除
- `route.path.includes('shared') / 'resource-management')` 判断删除

### 6.6 EditModel / SelectProviderDialog / ParamSettingDialog / AddParamDrawer

- 只做 AppIcon → LucideIcon
- 不动其它结构 / props / 业务逻辑

### 6.7 范围外（明确划清）

- 不动 `ProviderApi` / `Model API` 调用
- 不动 `loadSharedApi` facade 本身
- 不重命名 props / 不改对外接口
- knowledge / tool 子组件不在 PG 范围（KnowledgeCard / ToolCard / 各 Drawer 等）

---

## 7. 死代码清（PH Phase）

### 7.1 `tool/store.ts` 2 个孤儿方法

`ui/src/api/tool/store.ts` 中后端不存在的方法：

- `getStoreKBList` → `/workspace/store/knowledge_template`（apps/tools/urls.py 和 apps/knowledge/urls.py 都无）
- `getStoreAppList` → `/workspace/store/application_template`（同上）

处理流程：

```bash
grep -rn "getStoreKBList\|getStoreAppList" ui/src
```

按 grep 结果：

- **如果有 UI 调用方**（如 ToolStoreDialog 之类有"知识库模板/应用模板"商店入口）→ **删除 UI 调用方 + 对应入口按钮/弹窗/路由**（**不补后端**）
- 如果调用方是已删页的孤儿 → 连同方法一并删
- 删完两个方法后从 store.ts 移除 export

### 7.2 顺带补的清理（PB-PG 实施过程中发现的）

- 死引用 grep 扫描（参照系统管理 PE7）：

```bash
grep -rn "isSystemShare\|isSystemManage" ui/src/views/model       # PG 之后 0 hit
grep -rn "AppIcon" ui/src/views/model                              # PG 之后 0 hit
grep -rn "AppIcon" ui/src/views/{document,problem,hit-test,trigger}  # PB-PE 之后 0 hit
```

发现遗漏即在 PH 收尾时一起清。

### 7.3 不在范围内

- `api/system-resource-management/*` 和 `api/system-shared/*` 文件的根本性删除（PE2 保留是因 dynamics-api 间接耦合）
- `views.shared.*` / `views.role.*` 等 i18n namespace（系统管理 PE5 验证仍有跨页组件用）
- 任何后端补齐工作

---

## 8. 工作流画布对齐 Spec W1（PI Phase）

### 8.1 偏离

智能体 spec W1 §6.4 规定 20px line 网格，但 `ui/src/workflow/index.vue` 使用 LogicFlow 原生 `grid: { size: 10, type: 'dot' }`（10px 点阵）。

### 8.2 影响

`ui/src/workflow/index.vue` 是 3 个 workflow editor 共享引擎，改一处=3 处统一：

- `views/application-workflow/`（智能体范围，本 spec 之外，**顺带修正**）
- `views/knowledge-workflow/`（本 spec 范围）
- `views/tool-workflow/`（本 spec 范围）

### 8.3 改动

`ui/src/workflow/index.vue`：

```js
// LogicFlow 配置改为禁用原生 grid
grid: false
```

加 CSS（在 workflow canvas 容器 div 上）：

```scss
.workflow-canvas {
  background-color: #ffffff;
  background-image:
    linear-gradient(#f1f5f9 1px, transparent 1px),
    linear-gradient(90deg, #f1f5f9 1px, transparent 1px);
  background-size: 20px 20px;
}
```

具体 CSS 类名按实际 wrapper 结构挂载。

### 8.4 已知限制

- LogicFlow 内置 SVG grid 是随 zoom 缩放的；CSS background 不随 zoom 缩放
- 接受这个限制（spec W1 已隐含）；如果 zoom 时网格视觉错位明显，留作"已知 issue"

---

## 9. 落地策略

### 9.1 Phase 切分

| Phase | 内容 | 估时 | 依赖 |
|---|---|---|---|
| **PA · 原子复用 + 按需扩展** | StatusDot 仅当 PB/PE 需要时扩展 | 0-0.25d | 无 |
| **PB · /document 重做** | PageHeader + .card-unified + .toolbar + Lucide + StatusDot | 0.5d | PA |
| **PC · /problem 重做** | 同 PB 模式 | 0.5d | PA |
| **PD · /hit-test 重做** | 拆嵌套 el-card + section 分组 + Lucide | 0.5d | PA |
| **PE · /trigger 重做** | PageHeader + StatusDot active/paused + Lucide | 0.5d | PA |
| **PF · 4 轻量打磨** | knowledge/tool/model index + paragraph：清残留 | 0.5d | 无 |
| **PG · 模型子组件 atom + 死分支清** | 7 组件 AppIcon→Lucide；ModelCard/CreateModelDialog 9 死分支删 | 0.5d | PA |
| **PH · tool/store.ts 死方法清** | 删 getStoreKBList/getStoreAppList + 调用方 | 0.25d | PG |
| **PI · workflow 画布 grid 对齐 W1** | `ui/src/workflow/index.vue` | 0.25d | 无 |

**单人总计约 3.5-4d**。PB/PC/PD/PE 文件 100% 不重叠 → subagent 并行可压缩到 1-1.5d。PF/PG/PI 之间也基本不冲突。PH 放 PG 之后避免 store.ts 与 model 子组件改动相互干扰。

### 9.2 验收

1. `npm run type-check` 退出码 0
2. `npm run build` 编译通过
3. dev server 走查：
   - **重做 4 页**：`/document` / `/problem` / `/hit-test` / `/trigger` 都展示 PageHeader + .card-unified；AppIcon 全替换；StatusDot 状态正常
   - **轻量 4 页**：`/knowledge` / `/tool` / `/model` / `/paragraph` 残留 h2 / el-card 嵌套 / 死分支去掉
   - **模型子组件**：ModelCard 没有 systemShare/systemManage 分支报错；所有 icon 是 Lucide
   - **工作流画布**：3 个 workflow URL（application-workflow / knowledge-workflow / tool-workflow）背景是 20px line（不是点阵）
   - 浏览器控制台 0 warnings / 0 errors
4. `git diff apps/` 为空
5. 死引用 grep 全 0 hit：

```bash
grep -rn "AppIcon" ui/src/views/{document,problem,hit-test,trigger,model}
grep -rn "isSystemShare\|isSystemManage\|systemShare\|systemManage" ui/src/views/model
grep -rn "getStoreKBList\|getStoreAppList" ui/src
```

### 9.3 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| StatusDot 扩展新 status key 影响已用 StatusDot 的页面 | 智能体 overview / user-manage 视觉变化 | 新增只追加 CSS rule + switch case，不改已有 5 key 行为 |
| AppIcon → LucideIcon 某些 app-XXX 找不到完美对应 | UI 显示错位或图标语义不准 | 实施时建立 mapping 表；找不到 fallback `circle-help` + 代码注释 todo |
| workflow grid 改动影响 application-workflow（不在本 spec 范围但共享引擎） | 智能体工作流编辑器视觉变化 | §8.2 已声明这是"顺手修"；走查智能体 workflow 确认无破坏 |
| /hit-test 嵌套 el-card 拆扁后 section 高度计算坏 | 检索结果区滚动异常 | PD 实施时验证 `el-scrollbar` 高度计算 |
| tool/store.ts 死方法的调用方可能是入口 button（如"应用模板商店"） | 删调用 = 删入口功能 | 实施时确认是否需要 UI 层面同步删按钮 / 弹窗 / 路由（与本 spec §7.1 一致：删调用，不补后端） |
| Model index 的 apiType prop 删除如果有其它消费者（非已审计的 ModelCard） | 类型报错 / 运行时 undefined | grep `apiType` 在 model 范围内的所有引用后再清 |

### 9.4 不在范围内

- knowledge / tool 模块的子组件（KnowledgeCard / ToolCard / 各 Drawer / Dialog）的 atom 升级 —— 子组件未来单独立项
- `api/system-resource-management/*` 和 `api/system-shared/*` 的根本性删除
- `dynamics-api / loadSharedApi facade` 重构
- 后端补齐死路由（store templates）
- 工作流节点本身的视觉重新设计（n8n 风端口等）
- 移动端适配（沿用整体 spec §3.3）

### 9.5 完成定义

1. 4 重做页 + 4 轻量页 + 模型 7 子组件 + 工作流画布 grid 全部按本 spec 完成
2. `apps/` git diff 为空
3. type-check / build 全清白
4. dev server 走过去无 console error
5. 30 秒辨认测试：4 重做页任一 30 秒不会反应出是 MaxKB
6. 死引用 grep 全 0 hit
