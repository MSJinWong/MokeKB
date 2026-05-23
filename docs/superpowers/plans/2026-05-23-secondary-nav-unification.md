# 二级导航栏统一实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把所有二级导航 / 左栏（Side.vue + LayoutContainer #left）统一到 220px、自动隐藏 Side 当 subMenuList<2、取消 resizable、标题样式统一、顺手修 `.mul-operation` misalign bug。

**Architecture:** 单一 CSS token `--side-width: 220px` 驱动 Side.vue + LayoutContainer 默认 + `.mul-operation` 浮条 — 改一处全局自动跟。Side.vue 加 `visible` 计算让空 Side 不渲染。LayoutContainer 默认 `min=max=220`，删除调用方 resizable 用法。新加 `.side-panel__title` SCSS class，4 个 LayoutContainer 主页面用同一标题样式。

**Tech Stack:** Vue 3 + Element Plus + Pinia + vue-router + SCSS + vue-i18n.

**Source spec:** `docs/superpowers/specs/2026-05-23-secondary-nav-unification-design.md`

---

## Task PA1: Token + LayoutContainer 默认改造

**Files:**
- Modify: `ui/src/styles/variables.scss`
- Modify: `ui/src/components/layout-container/index.vue`

- [ ] **Step 1: 改 variables.scss line 21**

打开 `ui/src/styles/variables.scss`，找到 line 21：

```scss
--side-width: 200px;
```

改为：

```scss
--side-width: 220px;
```

`--sidebar-width` 在 line 105 是 `var(--side-width)` 别名，自动跟值，不动。

- [ ] **Step 2: 改 LayoutContainer 默认 props**

打开 `ui/src/components/layout-container/index.vue`，找到 line 41-56 的 defineProps：

```ts
const props = defineProps({
  showCollapse: Boolean,
  resizable: Boolean,
  minLeftWidth: {
    type: Number,
    default: 240,
  },
  maxLeftWidth: {
    type: Number,
    default: 400,
  },
  showLeft: {
    type: Boolean,
    default: true,
  },
})
```

替换为：

```ts
const props = defineProps({
  showCollapse: Boolean,
  resizable: { type: Boolean, default: false },
  minLeftWidth: {
    type: Number,
    default: 220,
  },
  maxLeftWidth: {
    type: Number,
    default: 220,
  },
  showLeft: {
    type: Boolean,
    default: true,
  },
})
```

- [ ] **Step 3: 改 LayoutContainer inline style 走 token（非 resizable 时）**

打开 `ui/src/components/layout-container/index.vue`，找到 template 的 line 5：

```vue
:style="{ width: isCollapse ? 0 : `${leftWidth}px` }"
```

在 `<script setup>` 中 `isResizing` 之后（约 line 60 之后）添加一个 computed：

```ts
import { computed, onUnmounted, ref } from 'vue'
// ... existing code ...

const widthStyle = computed(() => {
  if (isCollapse.value) return '0'
  if (props.resizable) return `${leftWidth.value}px`
  return 'var(--side-width)'
})
```

把 import 行从 `import { onUnmounted, ref } from 'vue'` 改为 `import { computed, onUnmounted, ref } from 'vue'`。

然后修改 template line 5：

```vue
:style="{ width: widthStyle }"
```

效果：
- 不传 `resizable` → CSS 变量驱动，与 token 同步
- 传 `resizable` → 走 JS ref（用户拖动可生效；但因为 PA1 默认 min=max=220，需要调用方显式给 maxLeftWidth 才能拖）

- [ ] **Step 4: 验证**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check"
```

期望：exit 0。

- [ ] **Step 5: Commit**

```bash
git add ui/src/styles/variables.scss ui/src/components/layout-container/index.vue
git commit -m "feat(ui): unify left panel token to 220px; LayoutContainer default min=max=220"
```

---

## Task PB1: 删除 resizable + ToolStoreDialog minLeftWidth

**Files:**
- Modify: `ui/src/views/knowledge/index.vue`
- Modify: `ui/src/views/tool/index.vue`
- Modify: `ui/src/views/tool/tool-store/ToolStoreDialog.vue`

- [ ] **Step 1: 删 knowledge/index.vue 的 resizable**

打开 `ui/src/views/knowledge/index.vue`，找到第 2 行附近：

```vue
<LayoutContainer showCollapse resizable class="knowledge-manage">
```

改为：

```vue
<LayoutContainer showCollapse class="knowledge-manage">
```

(删除 `resizable` attribute)

- [ ] **Step 2: 删 tool/index.vue 的 resizable**

打开 `ui/src/views/tool/index.vue`，找到第 2 行附近：

```vue
<LayoutContainer showCollapse resizable class="tool-manage">
```

改为：

```vue
<LayoutContainer showCollapse class="tool-manage">
```

- [ ] **Step 3: 删 ToolStoreDialog 的 :minLeftWidth 显式 prop**

打开 `ui/src/views/tool/tool-store/ToolStoreDialog.vue`，找到 line 31 附近：

```vue
<LayoutContainer v-loading="loading" :minLeftWidth="204">
```

改为：

```vue
<LayoutContainer v-loading="loading">
```

(删除 `:minLeftWidth="204"` 显式覆盖；走 PA1 改的默认 220)

- [ ] **Step 4: 验证 3 文件改动正确**

```bash
grep -n "resizable\|minLeftWidth" ui/src/views/knowledge/index.vue ui/src/views/tool/index.vue ui/src/views/tool/tool-store/ToolStoreDialog.vue
```

期望：
- knowledge/index.vue 中无 `resizable` hit
- tool/index.vue 中无 `resizable` hit
- ToolStoreDialog.vue 中无 `minLeftWidth` hit

- [ ] **Step 5: type-check**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check"
```

期望：exit 0。

- [ ] **Step 6: Commit**

```bash
git add ui/src/views/knowledge/index.vue ui/src/views/tool/index.vue ui/src/views/tool/tool-store/ToolStoreDialog.vue
git commit -m "chore(ui): drop resizable + ToolStoreDialog minLeftWidth override"
```

---

## Task PC1: Side.vue 自动隐藏

**Files:**
- Modify: `ui/src/layout/layout-side/Side.vue`

- [ ] **Step 1: 加 visible 计算 + v-if 在 aside 标签**

打开 `ui/src/layout/layout-side/Side.vue`。

第 1 步：在 `<aside>` 标签上加 `v-if="visible"`。把 line 2：

```vue
<aside class="app-side" :aria-label="$t('layout.side.aria')">
```

改为：

```vue
<aside class="app-side" v-if="visible" :aria-label="$t('layout.side.aria')">
```

第 2 步：在 `<script setup>` 中、`activeMenu` computed 之前（约 line 38 之后），添加：

```ts
const visible = computed(() => subMenuList.value.length >= 2)
```

完整的 script setup 末尾应该是 4 个 computed：`subMenuList`、`visible`、`activeMenu`、`moduleTitle`。

- [ ] **Step 2: type-check**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check"
```

期望：exit 0。

- [ ] **Step 3: Commit**

```bash
git add ui/src/layout/layout-side/Side.vue
git commit -m "feat(ui): hide Side.vue when subMenuList has fewer than 2 items"
```

---

## Task PD1: 内部样式统一 — `.side-panel__title` + 4 页面接入

**Files:**
- Modify: `ui/src/styles/component.scss`
- Modify: `ui/src/views/knowledge/index.vue`
- Modify: `ui/src/views/tool/index.vue`
- Modify: `ui/src/views/model/index.vue`
- Modify: `ui/src/views/paragraph/index.vue`
- Modify: `ui/src/locales/lang/zh-CN/views/paragraph.ts`
- Modify: `ui/src/locales/lang/en-US/views/paragraph.ts`
- Modify: `ui/src/locales/lang/zh-Hant/views/paragraph.ts`

- [ ] **Step 1: 加 `.side-panel__title` SCSS class**

打开 `ui/src/styles/component.scss`，在文件末尾追加：

```scss
/* ===== 二级导航 / 左栏面板标题 ===== */
.side-panel__title {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-primary);
  padding: 16px 14px 12px;
  margin: 0;
}
```

- [ ] **Step 2: 改 knowledge/index.vue 标题 class**

打开 `ui/src/views/knowledge/index.vue`，找到 `#left` slot 中的标题：

```vue
<h4 class="p-12-16 pb-0 mt-12">{{ $t('views.knowledge.title') }}</h4>
```

改为：

```vue
<h4 class="side-panel__title">{{ $t('views.knowledge.title') }}</h4>
```

- [ ] **Step 3: 改 tool/index.vue 标题 class**

打开 `ui/src/views/tool/index.vue`：

```vue
<h4 class="p-12-16 pb-0 mt-12">{{ $t('views.tool.title') }}</h4>
```

改为：

```vue
<h4 class="side-panel__title">{{ $t('views.tool.title') }}</h4>
```

- [ ] **Step 4: 改 model/index.vue 标题 class**

打开 `ui/src/views/model/index.vue`：

```vue
<h4 class="p-12-16 pb-0 mt-12">{{ $t('views.model.provider') }}</h4>
```

改为：

```vue
<h4 class="side-panel__title">{{ $t('views.model.provider') }}</h4>
```

- [ ] **Step 5: 在 paragraph/index.vue `#left` slot 顶部加标题**

打开 `ui/src/views/paragraph/index.vue`。找到 `<template #left>`，在其内部第一行（紧跟 `<template #left>` 之后）插入：

```vue
<h4 class="side-panel__title">{{ $t('views.paragraph.title') }}</h4>
```

注意：paragraph 当前的 `#left` 内容是 `<div class="paragraph-sidebar p-16">` 包裹的 `<el-scrollbar>` + `<el-anchor>`。加在 `<div class="paragraph-sidebar...">` 之前（即 slot 第一行）。

- [ ] **Step 6: 检查 i18n key `views.paragraph.title` 是否存在**

```bash
grep -n "  title:" ui/src/locales/lang/zh-CN/views/paragraph.ts
```

读 paragraph.ts 文件确认 namespace 结构。

**如果 `views.paragraph.title` 不存在**：在 3 个 locale 文件的 paragraph 对象内加：

- zh-CN `paragraph.ts`: `title: '段落',`
- en-US `paragraph.ts`: `title: 'Paragraphs',`
- zh-Hant `paragraph.ts`: `title: '段落',`

**如果已存在**：不动 i18n 文件。

- [ ] **Step 7: 验证**

```bash
grep -rn "p-12-16 pb-0 mt-12" ui/src/views/{knowledge,tool,model}/index.vue
```

期望：0 hit。

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check"
```

期望：exit 0。

- [ ] **Step 8: Commit**

```bash
git add ui/src/styles/component.scss ui/src/views/knowledge/index.vue ui/src/views/tool/index.vue ui/src/views/model/index.vue ui/src/views/paragraph/index.vue ui/src/locales/lang
git commit -m "feat(ui): unify .side-panel__title across knowledge/tool/model/paragraph"
```

---

## Task FINAL: 综合验证

**Files:** (验证类，不动文件)

- [ ] **Step 1: 全局 grep 验证**

```bash
echo "=== 1. p-12-16 残留 ==="
grep -rn "p-12-16 pb-0 mt-12" ui/src/views

echo "=== 2. resizable 残留（仅 LayoutContainer 应是 default=false 不显式给）==="
grep -rn "<LayoutContainer .*resizable" ui/src

echo "=== 3. minLeftWidth 显式覆盖 ==="
grep -rn ":minLeftWidth=" ui/src

echo "=== 4. 200px / 240px 硬编码（在 sidebar 上下文中）==="
grep -rn "200px\|240px" ui/src/styles ui/src/layout ui/src/components/layout-container

echo "=== 5. --side-width 用法 ==="
grep -rn "var(--side-width)\|var(--sidebar-width)" ui/src
```

期望：
- 1: 0 hit
- 2: 0 hit
- 3: 0 hit（Application 3 dialogs 不在范围，但本身不传 minLeftWidth，应也是 0）
- 4: 0 hit in sidebar contexts (variables.scss 应是 `--side-width: 220px`)
- 5: 6 处使用，全部"左栏宽度"相关

- [ ] **Step 2: type-check + build**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check 2>&1 | tail -3"
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run build 2>&1 | tail -5"
```

期望：两者都退出 0；build 仅 chunk-size warnings。

- [ ] **Step 3: 后端零改动确认**

```bash
git diff main -- apps/ 2>&1 | wc -l
```

期望：0（或 main 不存在的 fatal — 也接受）。

- [ ] **Step 4: dev server 走查（可选 — 留给用户做最终视觉确认）**

如果实施者想走查：

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run dev"
```

按 spec §7.2 验收清单走 5 Rail 模块 + 4 LayoutContainer 页 + .mul-operation 浮条 — 文档已经在 spec 里，这步不必复述。

如果 dev server 走查发现问题，记下来；否则跳过。

- [ ] **Step 5: 完成报告**

总结：
1. 哪些 Phase 完成
2. capability 模块 subMenuList 实际项数（grep 验证后报告）
3. paragraph i18n key 处理（已存在 / 新加）
4. 任何 dev server 走查的发现
5. 后端 diff 状态

不 commit 该报告 — 仅作为该 task 的状态描述。

---

## 完成定义

本 plan 全部 task 完成后，spec `2026-05-23-secondary-nav-unification-design.md` §7.5 的 7 条完成定义全部满足：

1. `--side-width: 220px` 单一 token 驱动全局 ✓
2. 5 个 Rail 模块 Side 行为合理 ✓
3. 4 个 LayoutContainer 页面左栏 220px、不可拖、标题统一 ✓
4. `.mul-operation` 浮条与左栏对齐 ✓
5. `apps/` git diff 为空 ✓
6. type-check / build 全清白 ✓
7. dev server 走过去无 console error ✓

## 依赖关系

PA1 → 所有
PB1 / PC1 / PD1 完全独立（文件不重叠）
FINAL 在最后

## subagent-driven 推荐执行顺序

PA1 → PB1 → PC1 → PD1 → FINAL

（PA1 后顺序无关；只是规避同时改文件造成的认知混乱）
