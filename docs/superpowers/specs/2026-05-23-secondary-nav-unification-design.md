# 二级导航栏统一设计

- **日期**：2026-05-23
- **分支**：`feat/frontend-redesign`
- **范围**：`ui/` 前端「二级导航 / 左栏」体系的宽度 + 风格 + 显隐策略统一
- **不动**：`apps/` 后端代码、所有 API、嵌入合约
- **依赖**：前置 spec `2026-05-22-platform-management-redesign-design.md` 和 `2026-05-23-knowledge-capability-model-redesign-design.md` 已落地

---

## 1. 背景

`MainLayout` 三段式 `Rail (64px) + Side (200px) + Main` 是前端整体重设计的骨架。但在三个 Rail 模块（knowledge / capability / platform-model）下，**Side 内容近乎空白**（subMenuList 只有 0-1 项），而 Main 区内的 `LayoutContainer` 又渲染了一个 240px+ 的 `#left` 列表（folder 树 / provider 列表）—— 用户实际看到的是 **Rail + 空 Side + 内 #left + 真 Main 内容** 的"三层左栏"结构，浪费视觉 chrome 同时各栏宽度不一致：

| 位置 | 宽度 | 可拖拽 |
|---|---|---|
| Side.vue | 200px 固定 | ❌ |
| LayoutContainer 默认 | 240px | 仅 prop 给 |
| knowledge/index | 240-400px | ✅ |
| tool/index | 240-400px | ✅ |
| model/index | 240px 固定 | ❌ |
| paragraph/index | 240px 固定 | ❌ |
| ToolStoreDialog | **204px 写死** | ❌ |
| Application 系列对话框 | 240px 固定 | ❌ |

**风格也各异**：
- knowledge / tool / model 头部用 `<h4 class="p-12-16 pb-0 mt-12">`
- paragraph **没有标题**
- Application 对话框**没有标题** + 无 showCollapse

**隐藏 bug**：全局 `.mul-operation` 浮条 `margin-left: var(--sidebar-width)` (= 200px)，但 LayoutContainer 左栏 240px+，**底部批量操作栏在所有使用 LayoutContainer 的页面 misaligned 40px+**。

本 spec 一次性统一：宽度 / 显隐策略 / 内部样式。

---

## 2. 设计原则

| # | 原则 | 强化点 |
|---|---|---|
| 1 | **后端零改动** | 仅 `ui/` |
| 2 | **单一宽度 token** | 所有二级导航 / 左栏统一 220px |
| 3 | **Side 自动隐藏** | subMenuList < 2 项时不渲染（消除"空 Side"浪费） |
| 4 | **取消 resizable** | 一致性 > 可定制；folder 长名靠截断+tooltip 解决 |
| 5 | **顺手修 misalign bug** | `.mul-operation` 自动跟新宽度 |
| 6 | **保守边界** | Application 弹窗内布局不强求统一（不同上下文） |

---

## 3. Design Token 改造

### 3.1 改 `variables.scss`

`ui/src/styles/variables.scss`：

```scss
/* line 21 */
--side-width: 220px;       /* was 200px */
/* line 105 */
--sidebar-width: var(--side-width);   /* 别名保留，自动跟新值 */
```

### 3.2 影响面（已 grep 验证，全部预期）

6 处使用，全部"左栏宽度"相关，**无意外副作用**：

| 文件 | 行 | 用途 | 改后效果 |
|---|---|---|---|
| `layout/layout-side/Side.vue` | 54 | Side 容器 width | 220px ✓ 目标 |
| `components/layout-container/index.vue` | 101 | LayoutContainer fallback width | 220px |
| `styles/component.scss` | 408 | `.mul-operation margin-left` | 220px (修 misalign bug) |
| `styles/component.scss` | 411 | `.mul-operation width: calc(100% - ...)` | 跟 220px (修 bug) |
| `styles/variables.scss` | 21, 105 | token 定义 + 别名 | 220px |
| `views/document/index.vue` | 1560 | `.document .mul-operation` width override | 220px (PB1 fix 阶段加的，自动跟) |

无其它隐藏副作用（grep 已确认无 hardcoded 200px / 240px 假设）。

---

## 4. LayoutContainer 改造

### 4.1 默认 props 变更

`ui/src/components/layout-container/index.vue`：

```ts
const props = defineProps({
  showCollapse: Boolean,
  resizable: { type: Boolean, default: false },   // 显式声明默认 false
  minLeftWidth: { type: Number, default: 220 },   // was 240
  maxLeftWidth: { type: Number, default: 220 },   // was 400 — 默认等同 min
  showLeft: { type: Boolean, default: true },
})
```

### 4.2 inline style 改 token

把 `<div :style="{ width: isCollapse ? 0 : ${leftWidth}px }">` 的逻辑改为：

```ts
const widthStyle = computed(() => {
  if (isCollapse.value) return '0'
  if (props.resizable) return `${leftWidth.value}px`
  return 'var(--side-width)'    // 默认走 token
})
```

```html
<div :style="{ width: widthStyle }">
```

效果：
- 不传 `resizable` → 220px（跟 token）
- 传 `resizable` → 用 JS ref 控制（但 `minLeftWidth`/`maxLeftWidth` 都改 220 后，拖拽实际只在 220 内动 = 等于不可拖；如想真拖，调用方需明确传 `:maxLeftWidth="360"`）

### 4.3 拆所有 `resizable` 用法

| 文件 | 现状 | 改后 |
|---|---|---|
| `views/knowledge/index.vue` | `<LayoutContainer showCollapse resizable class="knowledge-manage">` | **删 `resizable`** → `<LayoutContainer showCollapse class="knowledge-manage">` |
| `views/tool/index.vue` | `<LayoutContainer showCollapse resizable class="tool-manage">` | **删 `resizable`** |
| `views/model/index.vue` | `<LayoutContainer showCollapse class="model-manage">` | 不动（已无 resizable）|
| `views/paragraph/index.vue` | `<LayoutContainer showCollapse>` | 不动 |
| `views/tool/tool-store/ToolStoreDialog.vue` | `<LayoutContainer v-loading="loading" :minLeftWidth="204">` | **删 `:minLeftWidth`** prop → 走默认 220 |
| `views/tool-workflow/template-store/TemplateStoreDialog.vue` | 注释掉了 LayoutContainer | 不动 |
| `views/application/component/*.vue` 三个 dialogs | `<LayoutContainer class="application-manage">` | **不动**（§7.1 边界）|

---

## 5. Side.vue 自动隐藏

### 5.1 修改

`ui/src/layout/layout-side/Side.vue`：

```vue
<template>
  <aside class="app-side" v-if="visible" :aria-label="$t('layout.side.aria')">
    <!-- 原内容不动 -->
  </aside>
</template>

<script setup lang="ts">
// 在 subMenuList 之后追加：
const visible = computed(() => subMenuList.value.length >= 2)
</script>
```

逻辑：subMenuList 少于 2 项时不渲染整个 aside。MainLayout 的 flex 容器自动收回 Side 占用的 220px，Main 顶到 Rail 边。

### 5.2 影响（按当前路由 + 系统管理 + 3 模块 redesign 之后状态）

| Rail 模块 | subMenuList 项数 | Side 可见性 |
|---|---|---|
| workbench | 0 | ❌ 自动隐 |
| agent | 1（应用列表）| ❌ 自动隐 |
| knowledge | 1（知识资产）| ❌ 自动隐 |
| capability | 1-2（工具 + 触发器？需 grep 验证） | 视实际而定 |
| platform (model) | 1（模型）| ❌ 自动隐 |
| system | 3（用户/资源授权/邮箱）| ✅ 可见 |

capability 模块的实际 subMenuList 行为在实施时用 `getChildRouteListByPathAndName` 验证 — 如果它真的只有 1 项也会自动隐。

### 5.3 不破坏 hideMenu 过滤

系统管理 spec 的 4 个 authorization 子路由用 `meta.hideMenu: true` 在 `subMenuList` 中已被过滤。本次 `visible` 计算基于过滤后的 length，与现有 hideMenu 机制叠加正确。

### 5.4 边界：active route meta.parentName 不存在时

某些 fallback 路由 (404 / no-permission) 的 meta 可能不带 `parentName` / `parentPath`，`subMenuList` 返回 0 项。`visible` 也是 `false`，与"显示空 Side"相比是更好的行为。

---

## 6. 内部样式统一

### 6.1 新增共享 SCSS class

`ui/src/styles/component.scss` 末尾追加：

```scss
/* ===== 二级导航 / 左栏面板标题 ===== */
.side-panel__title {
  font-size: var(--font-size-md);     /* 14px */
  font-weight: 600;
  color: var(--text-primary);
  padding: 16px 14px 12px;
  margin: 0;
}
```

数值与 Side.vue 的 `.app-side__title` 完全一致（统一 chrome）。

### 6.2 4 个目标页面接入

| 页面 | 旧标题 | 新标题 |
|---|---|---|
| `views/knowledge/index.vue` | `<h4 class="p-12-16 pb-0 mt-12">{{ $t('views.knowledge.title') }}</h4>` | `<h4 class="side-panel__title">{{ $t('views.knowledge.title') }}</h4>` |
| `views/tool/index.vue` | `<h4 class="p-12-16 pb-0 mt-12">{{ $t('views.tool.title') }}</h4>` | `<h4 class="side-panel__title">{{ $t('views.tool.title') }}</h4>` |
| `views/model/index.vue` | `<h4 class="p-12-16 pb-0 mt-12">{{ $t('views.model.provider') }}</h4>` | `<h4 class="side-panel__title">{{ $t('views.model.provider') }}</h4>` |
| `views/paragraph/index.vue` | **无** | 加 `<h4 class="side-panel__title">{{ $t('views.paragraph.title') }}</h4>` 在 `#left` slot 顶部（需新 i18n key）|

### 6.3 paragraph 新增 i18n key

`ui/src/locales/lang/{zh-CN,en-US,zh-Hant}/views/paragraph.ts` 加：

- zh-CN: `title: '段落'`
- en-US: `title: 'Paragraphs'`
- zh-Hant: `title: '段落'`

如果 `views.paragraph.title` 已存在（grep 验证）则不动。

### 6.4 Side.vue 标题已经一致

Side.vue 的 `.app-side__title` 现有样式：

```scss
font-size: var(--font-size-md);
font-weight: 600;
color: var(--text-primary);
padding: 16px 14px 12px;
```

与 `.side-panel__title` 完全相同。**不动 Side.vue 标题样式**，保持当前行为。

---

## 7. 落地策略

### 7.1 Phase 切分

| Phase | 内容 | 估时 |
|---|---|---|
| **PA · Token + LayoutContainer 默认** | `variables.scss` 改 220、`LayoutContainer` 默认 prop 改、inline style 改 token | 0.25d |
| **PB · 删 resizable + ToolStoreDialog minLeftWidth** | 3 处页面调用方修改 | 0.25d |
| **PC · Side 自动隐藏** | `Side.vue` 加 `visible` 计算 | 0.25d |
| **PD · 内部样式统一** | 新增 `.side-panel__title` SCSS class；4 页面接入 + paragraph 加标题 + 新 i18n key | 0.25d |
| **PE · 验证** | grep + type-check + build + dev server 走查所有 5 个 Rail 模块 | 0.25d |

**单人总计约 1-1.25d**。

### 7.2 验收

1. `npm run type-check` 退出 0
2. `npm run build` 编译通过
3. dev server 走查 5 个 Rail 模块：
   - **workbench**：左侧只有 Rail（无 Side，无 LayoutContainer #left）
   - **agent**：同上 — Side 自动隐
   - **knowledge**：Rail + LayoutContainer #left 220px（无 Side）；标题用 `.side-panel__title`
   - **capability**：根据实际 subMenuList 数量；若 1 项则 Side 隐
   - **platform-model**：Rail + LayoutContainer #left 220px；不可拖
   - **system**：Rail + Side 220px（可见，因有 3 项）
4. 走查 4 个 LayoutContainer 页：
   - knowledge / tool / model index — 左栏 220px，不可拖，标题统一
   - paragraph index — 左栏 220px，**新增标题**
5. 走查批量操作 misalign 修复：
   - `/document/...` 选中文档 → 底部批量操作浮条 `left` 对齐到 220px 不再 misaligned
6. `grep -rn "p-12-16 pb-0 mt-12" ui/src/views/{knowledge,tool,model}/index.vue` → 0 hits
7. `grep -rn "200px\|240px" ui/src/styles/variables.scss` → 仅一个 `200px → 220px` 替换；无残留 200/240 在 sidebar 上下文中
8. `apps/` git diff 为空

### 7.3 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 改 token 影响其它意外引用 | 隐式视觉跳动 | §3.2 已 grep 验证 6 处，全部预期；无意外副作用 |
| `.mul-operation` 修复后对齐变化使现有用户感到"动了" | 用户体验细微变化 | 这是 bug 修复 — 之前的 misalign 才是不一致；接受这一次"对齐归位" |
| Side 自动隐 在某些 Rail 模块产生意外（如 capability 只有 1 项实际希望有 Side）| Side 突然消失 | 若 capability 模块实际希望保留 Side，可手动在该模块加占位项或调整 visible 计算阈值 |
| Application 三个 dialog 内部仍 240px，与主页面 220px 不一致 | 弹窗内左栏比主页面"宽 20px" | §7.4 明确不在范围；可读性可接受 |
| paragraph i18n key 已存在但语义不匹配 | 标题文本怪 | 实施时 grep 检查 — 如已存在但语义不合，用 `views.paragraph.sidebarTitle` 之类新 key |

### 7.4 不在范围内

- **3 个 Application 系列对话框**（ApplicationDialog / AddKnowledgeDialog / ToolDialog）的 LayoutContainer 内布局：弹窗内部双栏，不同上下文，保留 240px
- **TemplateStoreDialog**（注释掉的）：不动
- **后端 / API**：零改动
- **响应式**：1024px 以下不支持沿用整体 spec 总则
- **Side 标题 + Rail 标题等其它 chrome**：已经一致，不动

### 7.5 完成定义

1. `--side-width: 220px` 单一 token 驱动全局
2. 5 个 Rail 模块 Side 行为合理（system 显，余下视实际隐）
3. 4 个 LayoutContainer 页面左栏 220px、不可拖、标题统一
4. `.mul-operation` 浮条与左栏对齐（不再 misaligned）
5. `apps/` git diff 为空
6. type-check / build 全清白
7. dev server 走过去无 console error
