# 二级导航项视觉统一实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 7 个 `--nav-item-*` token + 1 个 `%nav-item-base` SCSS placeholder 驱动 3 个二级导航组件（folder-tree / Side(SidebarItem) / common-list）的项级样式统一；folder-tree 8 处 AppIcon → Lucide；SidebarItem 删手写覆盖 + 改 LucideIcon；4 个路由 meta.icon 改 Lucide name 并放弃 iconActive。

**Architecture:** 集中 token + SCSS placeholder + Vue 组件接入。Side.vue 老 `--side-item-*` token 重映射到新 nav-item token（向后兼容，且让 Side.vue 现有引用真正生效）。@extend placeholder 在 `:deep()` 下若失败，备选 mixin `@include nav-item-base`。

**Tech Stack:** Vue 3 + Element Plus + SCSS + vue-i18n + iconify/lucide.

**Source spec:** `docs/superpowers/specs/2026-05-24-nav-item-unification-design.md`

**Pre-impl HEAD:** `da64e7b54` (spec 提交后)

---

## Task PA1: Token + SCSS placeholder

**Files:**
- Modify: `ui/src/styles/variables.scss`
- Modify: `ui/src/styles/component.scss`

- [ ] **Step 1: 在 variables.scss 加 7 个 nav-item token**

打开 `ui/src/styles/variables.scss`。在 line 28 之后（Side token 之后、Main token 之前）插入：

```scss

  /* ===== 二级导航项 token ===== */
  --nav-item-height: 36px;
  --nav-item-padding-x: 12px;
  --nav-item-radius: var(--radius-sm);
  --nav-item-gap: 2px;
  --nav-item-font-size: var(--font-size-base);
  --nav-item-font-weight: 400;
  --nav-item-color: var(--text-primary);

  --nav-item-hover-bg: rgba(15, 23, 42, 0.06);
  --nav-item-hover-color: var(--text-primary);

  --nav-item-active-bg: var(--el-color-primary-light-9);
  --nav-item-active-color: var(--el-color-primary);
  --nav-item-active-font-weight: 500;

  --nav-item-icon-size: 16px;
  --nav-item-icon-gap: 8px;
```

- [ ] **Step 2: 替换 Side.vue 老 token (lines 24-27) 为重映射**

仍在 variables.scss，找到 lines 24-27：

```scss
  --side-item-text: #475569;
  --side-item-hover-bg: #eef2f6;
  --side-item-active-bg: #e2e8f0;
  --side-item-active-text: #0f172a;
```

替换为（保持顺序，但值改为 var 引用）：

```scss
  --side-item-text: var(--nav-item-color);
  --side-item-hover-bg: var(--nav-item-hover-bg);
  --side-item-active-bg: var(--nav-item-active-bg);
  --side-item-active-text: var(--nav-item-active-color);
```

- [ ] **Step 3: 在 component.scss 末尾追加 `%nav-item-base` placeholder**

打开 `ui/src/styles/component.scss`，在文件末尾追加：

```scss

/* ===== 二级导航项 公共样式 ===== */
%nav-item-base {
  height: var(--nav-item-height);
  line-height: var(--nav-item-height);
  padding: 0 var(--nav-item-padding-x);
  font-size: var(--nav-item-font-size);
  font-weight: var(--nav-item-font-weight);
  color: var(--nav-item-color);
  border-radius: var(--nav-item-radius);
  margin-bottom: var(--nav-item-gap);
  display: flex;
  align-items: center;
  gap: var(--nav-item-icon-gap);
  cursor: pointer;
  transition: background-color 0.15s, color 0.15s;
  box-sizing: border-box;

  &:hover {
    background: var(--nav-item-hover-bg);
    color: var(--nav-item-hover-color);
  }

  &.is-active,
  &.active {
    background: var(--nav-item-active-bg);
    color: var(--nav-item-active-color);
    font-weight: var(--nav-item-active-font-weight);
  }
}

/* Mixin fallback — 在 :deep() 下若 @extend 失效，调用方改用 @include nav-item-base */
@mixin nav-item-base {
  height: var(--nav-item-height);
  line-height: var(--nav-item-height);
  padding: 0 var(--nav-item-padding-x);
  font-size: var(--nav-item-font-size);
  font-weight: var(--nav-item-font-weight);
  color: var(--nav-item-color);
  border-radius: var(--nav-item-radius);
  margin-bottom: var(--nav-item-gap);
  display: flex;
  align-items: center;
  gap: var(--nav-item-icon-gap);
  cursor: pointer;
  transition: background-color 0.15s, color 0.15s;
  box-sizing: border-box;

  &:hover {
    background: var(--nav-item-hover-bg);
    color: var(--nav-item-hover-color);
  }

  &.is-active,
  &.active {
    background: var(--nav-item-active-bg);
    color: var(--nav-item-active-color);
    font-weight: var(--nav-item-active-font-weight);
  }
}
```

- [ ] **Step 4: type-check + build**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check && npm run build 2>&1 | tail -5"
```

期望：均退出 0；build 仅 chunk-size warning。

- [ ] **Step 5: Commit**

```bash
git add ui/src/styles/variables.scss ui/src/styles/component.scss
git commit -m "feat(ui): introduce --nav-item-* tokens + nav-item-base placeholder"
```

---

## Task PB1: folder-tree icon + style 接入

**Files:**
- Modify: `ui/src/components/folder-tree/index.vue`

- [ ] **Step 1: 加 LucideIcon import**

打开 `ui/src/components/folder-tree/index.vue`。在 `<script setup>` import 区（约 line 161-180）找到合适位置加：

```ts
import { LucideIcon } from '@/components/lucide-icon'
```

放在其它 `@/components/*` import 行附近。

- [ ] **Step 2: 替换 8 处 AppIcon → LucideIcon**

按顺序逐处替换。每处用 Edit 工具精确替换（保留外层 class / title）：

**a) Line 12** — 排序按钮 icon（动态 binding）：

```vue
<AppIcon :iconName="sortIconName"></AppIcon>
```

改为：

```vue
<LucideIcon :name="sortIconName" :size="16" />
```

**b) Line 44-48** — 分享节点 icon：

```vue
<AppIcon
  iconName="app-shared-active"
  style="font-size: 18px"
  class="color-primary"
></AppIcon>
```

改为：

```vue
<LucideIcon
  name="share-2"
  :size="16"
  class="color-primary"
/>
```

**c) Line 84** — folder 主图标：

```vue
<AppIcon iconName="app-folder" style="font-size: 20px"></AppIcon>
```

改为：

```vue
<LucideIcon name="folder" :size="16" />
```

**d) Line 97** — more 按钮：

```vue
<AppIcon iconName="app-more"></AppIcon>
```

改为：

```vue
<LucideIcon name="more-horizontal" :size="16" />
```

**e) Line 105** — 添加子文件夹：

```vue
<AppIcon iconName="app-add-folder" class="color-secondary"></AppIcon>
```

改为：

```vue
<LucideIcon name="folder-plus" :size="16" class="color-secondary" />
```

**f) Line 112** — 编辑：

```vue
<AppIcon iconName="app-edit" class="color-secondary"></AppIcon>
```

改为：

```vue
<LucideIcon name="pencil" :size="16" class="color-secondary" />
```

**g) Line 119** — 移动：

```vue
<AppIcon iconName="app-migrate" class="color-secondary"></AppIcon>
```

改为：

```vue
<LucideIcon name="move" :size="16" class="color-secondary" />
```

**h) Line 126-129** — 资源授权：

```vue
<AppIcon
  iconName="app-resource-authorization"
  class="color-secondary"
></AppIcon>
```

改为：

```vue
<LucideIcon name="shield-check" :size="16" class="color-secondary" />
```

**i) Line 138** — 删除：

```vue
<AppIcon iconName="app-delete" class="color-secondary"></AppIcon>
```

改为：

```vue
<LucideIcon name="trash-2" :size="16" class="color-secondary" />
```

- [ ] **Step 3: 修改 sortIconName computed 返回 Lucide name**

找到 `sortIconName` computed（line 304-313）：

```ts
const sortIconName = computed(() => {
  const sort = currentSort.value
  if (sort.endsWith('asc')) {
    return 'app-folder-asc'
  }
  if (sort.endsWith('desc')) {
    return 'app-folder-desc'
  }
  return 'app-folder-custom'
})
```

替换为：

```ts
const sortIconName = computed(() => {
  const sort = currentSort.value
  if (sort.endsWith('asc')) {
    return 'arrow-up-narrow-wide'
  }
  if (sort.endsWith('desc')) {
    return 'arrow-down-wide-narrow'
  }
  return 'arrow-up-down'
})
```

- [ ] **Step 4: 接入 `%nav-item-base` 到 el-tree-node 项**

在文件的 `<style lang="scss" scoped>` 块内追加（如果文件没有 style 块，先创建一个）：

```scss
:deep(.el-tree-node__content) {
  @extend %nav-item-base;
}
:deep(.el-tree-node.is-current > .el-tree-node__content) {
  background: var(--nav-item-active-bg);
  color: var(--nav-item-active-color);
  font-weight: var(--nav-item-active-font-weight);
}
```

- [ ] **Step 5: 验证 + 若 @extend 失败 fallback**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check && npm run build 2>&1 | tail -10"
```

如果 type-check / build 报错说 `@extend %nav-item-base` 不能跨 scope（Vue scoped + SCSS placeholder + `:deep()` 偶尔有问题），把 `@extend %nav-item-base;` 替换为 `@include nav-item-base;`。

期望：build 通过。

- [ ] **Step 6: 验证 AppIcon 已清**

```bash
grep -n "AppIcon" ui/src/components/folder-tree/index.vue
```

期望：0 hit。

- [ ] **Step 7: Commit**

```bash
git add ui/src/components/folder-tree/index.vue
git commit -m "refactor(ui): folder-tree icons to Lucide + nav-item style"
```

---

## Task PC1: SidebarItem 简化 + 4 个路由 meta.icon

**Files:**
- Modify: `ui/src/layout/components/sidebar/SidebarItem.vue`
- Modify: `ui/src/router/modules/system.ts`
- Modify: `ui/src/router/modules/application.ts`

- [ ] **Step 1: 重写 SidebarItem.vue**

打开 `ui/src/layout/components/sidebar/SidebarItem.vue`，替换整个文件：

```vue
<template>
  <div v-if="(!menu.meta || !menu.meta.hidden) && showMenu()" class="sidebar-item">
    <el-sub-menu
      v-if="menu?.children && menu?.children.length > 0"
      :index="menu.path"
      popper-class="sidebar-container-popper"
    >
      <template #title>
        <LucideIcon
          v-if="menu.meta && menu.meta.icon"
          :name="menuIcon"
          :size="16"
          class="sidebar-icon"
        />
        <span>{{ $t(menu.meta?.title as string) }}</span>
      </template>
      <sidebar-item
        v-hasPermission="child.meta?.permission"
        v-for="(child, index) in menu?.children"
        :key="index"
        :menu="child"
        :activeMenu="activeMenu"
      >
      </sidebar-item>
    </el-sub-menu>
    <el-menu-item
      v-else
      ref="subMenu"
      :index="menu.path"
      popper-class="sidebar-popper"
      @click="clickHandle(menu)"
    >
      <template #title>
        <LucideIcon
          v-if="menu.meta && menu.meta.icon"
          :name="menuIcon"
          :size="16"
          class="sidebar-icon"
        />
        <span v-if="menu.meta && menu.meta.title">{{ $t(menu.meta?.title as string) }}</span>
      </template>
    </el-menu-item>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter, useRoute, type RouteRecordRaw } from 'vue-router'
import { LucideIcon } from '@/components/lucide-icon'
import { isWorkFlow } from '@/utils/application'

const props = defineProps<{
  menu: RouteRecordRaw
  activeMenu: any
}>()

const router = useRouter()
const route = useRoute()
const {
  params: { id, type, from, folderId },
} = route as any

function showMenu() {
  if (isWorkFlow(type)) {
    return props.menu.name !== 'AppHitTest'
  } else {
    return true
  }
}

function clickHandle(item?: any) {
  if (isWorkFlow(type) && item?.name === 'AppSetting') {
    router.push({ path: `/application/${from}/${id}/workflow` })
  } else if (type === '4' && item?.name === 'knowledgeWorkflowSetting') {
    router.push({ path: `/knowledge/${id}/${folderId}/workflow` })
  }
}

const menuIcon = computed(() => {
  return props.menu?.meta?.icon as string | undefined
})
</script>

<style scoped lang="scss">
.sidebar-item {
  .sidebar-icon {
    flex-shrink: 0;
  }
  :deep(.el-menu-item) {
    @extend %nav-item-base;
  }
  :deep(.el-sub-menu__title) {
    @extend %nav-item-base;
  }
  .el-sub-menu .el-menu-item {
    padding-left: 36px !important;
  }
}
</style>
```

关键变更：
- import `LucideIcon`
- 模板里 `<AppIcon :iconName>` → `<LucideIcon :name :size="16">`
- `menuIcon` computed 简化为只读 `meta.icon`（去掉 iconActive 路径）
- `<style>` 完全重写：删手写 padding/font-weight/colors；用 `@extend %nav-item-base`

如果 `@extend %nav-item-base` 在 `:deep()` 下不生效（build 报错），把两处 `@extend` 改为 `@include nav-item-base`。

- [ ] **Step 2: 改 system.ts 3 处路由 meta.icon**

打开 `ui/src/router/modules/system.ts`。

**a) Line 15-16** — `/system/user` 路由的 meta：

```ts
        icon: 'User',
        iconActive: 'UserFilled',
```

替换为：

```ts
        icon: 'users',
```

(2 行变 1 行，删除 iconActive)

**b) Line 30-31** — `/system/authorization` 路由的 meta（找到 `authorization` name 的项）：

```ts
        icon: 'app-resource-authorization',
        iconActive: 'app-resource-authorization-active',
```

替换为：

```ts
        icon: 'shield-check',
```

**c) Line 114-115** — `/system/email` 路由的 meta：

```ts
        icon: 'app-setting',
        iconActive: 'app-setting-active',
```

替换为：

```ts
        icon: 'mail',
```

- [ ] **Step 3: 改 application.ts 1 处路由 meta.icon**

打开 `ui/src/router/modules/application.ts`。Line 15-16：

```ts
    icon: 'app-agent',
    iconActive: 'app-agent-active',
```

替换为：

```ts
    icon: 'bot',
```

- [ ] **Step 4: 验证**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check && npm run build 2>&1 | tail -5"
```

期望：均退出 0。

```bash
grep -n "AppIcon\|iconActive" ui/src/layout/components/sidebar/SidebarItem.vue
grep -n "iconActive" ui/src/router/modules/system.ts ui/src/router/modules/application.ts
```

期望：均 0 hit。

- [ ] **Step 5: Commit**

```bash
git add ui/src/layout/components/sidebar/SidebarItem.vue ui/src/router/modules/system.ts ui/src/router/modules/application.ts
git commit -m "refactor(ui): SidebarItem uses Lucide + nav-item-base; route meta.icon → Lucide names"
```

---

## Task PD1: common-list 接入

**Files:**
- Modify: `ui/src/components/common-list/index.vue`

- [ ] **Step 1: 替换 `<style scoped>` 块**

打开 `ui/src/components/common-list/index.vue`。找到 `<style lang="scss" scoped>` 块（lines 70-101）：

```scss
<style lang="scss" scoped>
/* 通用 ui li样式 */
.common-list {
  li {
    padding: 8px;
    font-weight: 400;
    font-size: 14px;
    margin-bottom: 4px;
    min-height: 24px;
    line-height: 24px;
    &.active {
      background: var(--el-color-primary-light-9);
      border-radius: var(--app-border-radius-small);
      color: var(--el-color-primary);
      font-weight: 500;
      &:hover {
        background: var(--el-color-primary-light-9);
      }
    }
    &:hover {
      border-radius: var(--app-border-radius-small);
      background: rgba(var(--el-text-color-primary-rgb), 0.1);
    }
    &.is-active {
      &:hover {
        color: var(--el-color-primary);
        background: var(--el-color-primary-light-9);
      }
    }
  }
}
</style>
```

替换为：

```scss
<style lang="scss" scoped>
.common-list {
  ul {
    margin: 0;
    padding: 0;
    list-style: none;
  }
  li {
    @extend %nav-item-base;
  }
}
</style>
```

(简化为只 `@extend`；ul reset 是因为去掉之前 li 自身的 margin/padding 后，ul 默认样式可能让间距奇怪)

如果 `@extend %nav-item-base` 在 scoped 编译报错，改为 `@include nav-item-base`。

- [ ] **Step 2: 验证**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check && npm run build 2>&1 | tail -5"
```

期望：均退出 0。

- [ ] **Step 3: Commit**

```bash
git add ui/src/components/common-list/index.vue
git commit -m "refactor(ui): common-list li uses nav-item-base"
```

---

## Task FINAL: 综合验证

**Files:** (验证类，不动文件)

- [ ] **Step 1: 全局 grep 死引用扫描**

```bash
echo "=== AppIcon in folder-tree + SidebarItem ==="
grep -rn "AppIcon" ui/src/components/folder-tree ui/src/layout/components/sidebar

echo "=== 老 EP Icon name in route meta ==="
grep -rn "'User'\|'UserFilled'" ui/src/router

echo "=== iconActive in Side routes ==="
grep -n "iconActive" ui/src/router/modules/system.ts ui/src/router/modules/application.ts

echo "=== nav-item-base usage ==="
grep -rn "%nav-item-base\|@extend %nav-item-base\|@include nav-item-base" ui/src
```

期望：
- 前 3 项：0 hit
- 第 4 项：folder-tree / SidebarItem / common-list 各 1+ hit（接入了）

- [ ] **Step 2: type-check + build via WSL**

```bash
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run type-check 2>&1 | tail -3"
wsl bash -c "cd /home/mrwan/projects/MokeKB/ui && npm run build 2>&1 | tail -5"
```

期望：两者均 exit 0；build 仅 chunk-size warning。

- [ ] **Step 3: Token + placeholder 落地确认**

```bash
grep -n "nav-item" ui/src/styles/variables.scss
grep -n "nav-item-base" ui/src/styles/component.scss
```

期望：
- variables.scss：~14 行 `--nav-item-*` token + 4 行 `--side-item-*` 重映射
- component.scss：`%nav-item-base` placeholder + `@mixin nav-item-base` 两块

- [ ] **Step 4: 后端零改动**

```bash
git diff main -- apps/ 2>&1 | head -5
```

期望：empty 或 "main not found"（branch 隔离 OK）。

- [ ] **Step 5: 最近 4 commits 确认**

```bash
git log --oneline -8
```

期望按顺序看到：
- PA1: `feat(ui): introduce --nav-item-* tokens + nav-item-base placeholder`
- PB1: `refactor(ui): folder-tree icons to Lucide + nav-item style`
- PC1: `refactor(ui): SidebarItem uses Lucide + nav-item-base; route meta.icon → Lucide names`
- PD1: `refactor(ui): common-list li uses nav-item-base`

- [ ] **Step 6: 报告**

汇总：
- 4 个 Phase 完成情况
- @extend / @include 各处实际用了哪个（fallback 是否触发）
- AppIcon 残留 grep 结果
- Build / type-check 结果

不 commit 报告。

---

## 完成定义

本计划全部 task 完成后，spec `2026-05-24-nav-item-unification-design.md` §8.5 的 7 条全部满足：

1. 7 个 `--nav-item-*` token 单一驱动 3 组件 ✓
2. folder-tree 8 处 AppIcon 全部 Lucide outline 16px ✓
3. SidebarItem 删除手写覆盖；Side.vue 老 token 实际生效 ✓
4. 4 个路由 meta.icon 是 Lucide name；iconActive 在 Side 渲染路径中放弃 ✓
5. 三组件视觉一致（36px / 13px / primary 激活色 / 4px radius / 2px gap）✓
6. `apps/` git diff 为空 ✓
7. type-check / build 全清白 ✓

## 依赖关系

PA1 → 所有
PB1 / PC1 / PD1 完全独立（文件不重叠）
FINAL 在最后

## subagent-driven 推荐执行顺序

PA1 → PB1 → PC1 → PD1 → FINAL
