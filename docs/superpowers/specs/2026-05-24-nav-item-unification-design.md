# 二级导航项视觉统一设计

- **日期**：2026-05-24
- **分支**：`feat/frontend-redesign`
- **范围**：`ui/` 前端三个二级导航组件（folder-tree / Side(SidebarItem) / common-list）的视觉统一 + folder-tree 与 SidebarItem 的 icon 系统迁移到 Lucide
- **不动**：`apps/` 后端、所有 API、嵌入合约
- **依赖**：前置 spec `2026-05-23-secondary-nav-unification-design.md`（左栏 220px / Side 自动隐 / 标题统一）已落地

---

## 1. 背景

上一个 spec 把"二级导航栏的容器宽度 + 标题"统一了，但**容器内部的"项"渲染各异**——3 个组件 + 1 套 token 系统全乱：

| 属性 | folder-tree | Side+SidebarItem | common-list |
|---|---|---|---|
| 项高 | ~40px | 声明 36px / 实际 38px | ~40px |
| Font-size | 13px (token) | 13px (token) | **14px 字面量** |
| 默认 font-weight | 400 | **500** | 400 |
| Hover 背景 | `rgba(primary,.1)` | Side 定义 `#eef2f6` 但 **SidebarItem 覆盖** 为 `rgba(primary,.1)` | `rgba(primary,.1)` |
| 激活背景 | `primary-light-9` | Side 定义 `#e2e8f0` 但 **被覆盖** 为 `primary-light-9` | `primary-light-9` |
| 激活文字色 | `primary` | Side 定义 `#0f172a` 但 **被覆盖** 为 `primary` | `primary` |
| 项间距 | 0 | 2px | 4px |
| Icon 系统 | `AppIcon`（MaxKB SVG 雪碧）| `AppIcon` + 1 处 EP Icon (`User`/`UserFilled`) | 无 |
| Icon 尺寸 | 20px | 20px | n/a |

**两个核心问题**：

1. **Side.vue 设计 token 失效**：`--side-item-hover-bg / --side-item-active-bg / --side-item-active-text` 在 Side.vue 里定义了 slate 调色板（`#eef2f6 / #e2e8f0 / #0f172a`），但 SidebarItem.vue 把它们用 `el-color-primary*` 完全覆盖了 —— **token 层从未生效**。
2. **图标 3 套并存**：folder-tree 全 AppIcon、Side 主要 AppIcon + 1 处 EP icon、model Provider.vue 已经迁到 Lucide。视觉上"文件夹"在不同页面显示 MaxKB 风黄填充 vs Lucide 细线。

本 spec 一次性统一：
- 抽 7 个 `--nav-item-*` token + 1 个 `%nav-item-base` SCSS placeholder
- 三组件 @extend placeholder 共享一致样式
- folder-tree 全部 AppIcon → LucideIcon
- SidebarItem.vue 删除手写覆盖 + 用 LucideIcon
- 4 个相关路由 `meta.icon` 改为 Lucide name + 放弃 `iconActive` 字段

---

## 2. 设计原则

| # | 原则 | 强化点 |
|---|---|---|
| 1 | **后端零改动** | 仅 `ui/` |
| 2 | **单一来源 token** | 7 个 `--nav-item-*` token 驱动 3 个组件 |
| 3 | **SCSS placeholder 复用** | `%nav-item-base` `@extend` 各组件；fallback 改 mixin 若 EP `:deep` 不生效 |
| 4 | **icon 统一 Lucide outline** | 16px 一刀切；放弃 `iconActive` filled 变体 |
| 5 | **保持向后兼容** | Side.vue 老 `--side-item-*` token 重映射到新 token，不破坏现有 SCSS |
| 6 | **保守边界** | 路由 meta.icon 仅改 Side 实际渲染的（user/auth/email/agent 4 处），不动 application-detail / document 子路由 |

---

## 3. Token + SCSS placeholder（PA Phase）

### 3.1 新增 7 个 `--nav-item-*` token

`ui/src/styles/variables.scss` 在 Side token 区域附近添加：

```scss
:root {
  /* ---- 二级导航项 token ---- */
  --nav-item-height: 36px;
  --nav-item-padding-x: 12px;
  --nav-item-radius: var(--radius-sm);           /* 4px */
  --nav-item-gap: 2px;                           /* 项间距 margin-bottom */
  --nav-item-font-size: var(--font-size-base);   /* 13px */
  --nav-item-font-weight: 400;
  --nav-item-color: var(--text-primary);

  --nav-item-hover-bg: rgba(15, 23, 42, 0.06);
  --nav-item-hover-color: var(--text-primary);

  --nav-item-active-bg: var(--el-color-primary-light-9);
  --nav-item-active-color: var(--el-color-primary);
  --nav-item-active-font-weight: 500;

  --nav-item-icon-size: 16px;
  --nav-item-icon-gap: 8px;
}
```

### 3.2 Side.vue 老 token 重映射（向后兼容）

`ui/src/styles/variables.scss` 找到现有的 `--side-item-*` 定义，改为重映射：

```scss
:root {
  --side-item-text: var(--nav-item-color);
  --side-item-hover-bg: var(--nav-item-hover-bg);
  --side-item-active-bg: var(--nav-item-active-bg);
  --side-item-active-text: var(--nav-item-active-color);
}
```

效果：Side.vue 现有 `var(--side-item-*)` 引用真正生效（之前被 SidebarItem 覆盖了）。

### 3.3 共享 `%nav-item-base` placeholder

`ui/src/styles/component.scss` 末尾追加：

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
```

### 3.4 Mixin fallback（若 `@extend` 在 EP `:deep` 下不生效）

实施 PB/PC/PD 任一阶段时若发现 `@extend %nav-item-base` 在 `:deep(.el-tree-node__content)` 或 `:deep(.el-menu-item)` 下不生效，**回退**为 SCSS mixin：

```scss
@mixin nav-item-base {
  /* 同 %nav-item-base 内容 */
}

/* 调用方 */
:deep(.el-tree-node__content) {
  @include nav-item-base;
}
```

二者择一，**不要混用**。

---

## 4. folder-tree icon + 样式接入（PB Phase）

### 4.1 8 处 AppIcon → LucideIcon

`ui/src/components/folder-tree/index.vue`：

| 行 | 旧 iconName | 新 LucideIcon name |
|---|---|---|
| 12 | `sortIconName`（动态） | 需查 binding 源；可能 `arrow-up-down` / `arrow-up` / `arrow-down` |
| 45 | `app-shared-active` | `share-2` |
| 84 | `app-folder` | `folder` |
| 97 | `app-more` | `more-horizontal` |
| 105 | `app-add-folder` | `folder-plus` |
| 112 | `app-edit` | `pencil` |
| 119 | `app-migrate` | `move` |
| 127 | `app-resource-authorization` | `shield-check` |
| 138 | `app-delete` | `trash-2` |

替换语法：`<AppIcon iconName="app-XXX" style="font-size: 20px"></AppIcon>` → `<LucideIcon name="YYY" :size="16" />`。统一 16px。

### 4.2 SCSS 接入

在 folder-tree 的 `<style scoped>` 加：

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

如 `@extend` 在 `:deep()` 下失效（Vue scoped SCSS 限制），改为 `@include nav-item-base`（见 §3.4 fallback）。

### 4.3 import LucideIcon

`<script setup>` 加：

```ts
import { LucideIcon } from '@/components/lucide-icon'
```

如果原本有 `import AppIcon from ...` 且全文 0 引用后，移除。

### 4.4 `sortIconName` 动态值映射

在 script 中查找 `sortIconName` 的 ref/computed 定义，把可能的 `'app-sort-XXX'` 系列值改为 Lucide name（如 `arrow-up-down` / `arrow-up` / `arrow-down`，按实际逻辑判断）。

---

## 5. SidebarItem 简化 + Side meta icon Lucide 化（PC Phase）

### 5.1 SidebarItem.vue 重写 style

`ui/src/layout/components/sidebar/SidebarItem.vue`：

- **删除**当前手写的 SCSS（`padding: 13px 12px 13px 8px !important` 和所有 hover/active 颜色覆盖）
- 在 `<style scoped>` 添加（或在父 Side.vue 加）：

```scss
:deep(.el-menu-item) {
  @extend %nav-item-base;
  /* el-menu-item 特殊处理：去 EP 默认 padding-left */
  padding-left: var(--nav-item-padding-x) !important;
}
:deep(.el-sub-menu .el-menu-item) {
  padding-left: 36px !important;  /* 二级缩进 = padding-x + indent */
}
```

- **icon 渲染**：`<AppIcon :iconName="menuIcon">` → `<LucideIcon :name="menuIcon" :size="16">`
- **删除 `iconActive` 处理逻辑**：menuIcon computed 仅返回 `meta.icon`，不再 swap 到 `meta.iconActive`

### 5.2 路由 meta.icon 改 Lucide name（4 处）

| 文件:行 | 旧 | 新 |
|---|---|---|
| `router/modules/system.ts:15-16` (user) | `icon: 'User', iconActive: 'UserFilled'` | `icon: 'users'`（删 iconActive） |
| `router/modules/system.ts:30-31` (authorization) | `icon: 'app-resource-authorization', iconActive: 'app-resource-authorization-active'` | `icon: 'shield-check'`（删 iconActive） |
| `router/modules/system.ts:114-115` (email) | `icon: 'app-setting', iconActive: 'app-setting-active'` | `icon: 'mail'`（删 iconActive） |
| `router/modules/application.ts:15-16` (agent) | `icon: 'app-agent', iconActive: 'app-agent-active'` | `icon: 'bot'`（删 iconActive） |

注意：`bot` 与 Rail `application` 模块在 `RAIL_MODULES` 里的 lucide 名一致，不冲突。

### 5.3 import 与 grep 验证

SidebarItem.vue 加 `import { LucideIcon } from '@/components/lucide-icon'`，去掉 `AppIcon` import（如果该文件还用到 AppIcon 其它地方则保留）。

grep 确认 system Side 范围内无 AppIcon / iconActive 残留：

```bash
grep -n "AppIcon\|iconActive" ui/src/layout/components/sidebar
grep -rn "iconActive" ui/src/router/modules/{system,application}.ts
```

期望：均 0 hit。

### 5.4 不动的 iconActive

`router/modules/application-detail.ts` / `document.ts` 等子路由的 `iconActive` 字段不在 Side 渲染路径中，**保留原状**（不在本 spec 范围）。

---

## 6. common-list 接入 nav-item（PD Phase）

`ui/src/components/common-list/index.vue` 的 `<style scoped>` 替换 `li` 样式：

```scss
li {
  @extend %nav-item-base;
}
```

删除手写的 `padding: 8px`、`font-size: 14px`、`margin-bottom: 4px`、独立的 hover/active 规则。

如 `@extend` 失败用 `@include nav-item-base`（§3.4 fallback）。

---

## 7. Provider.vue 不动（PE 顺带验证）

`views/model/component/Provider.vue` 已在 PG3 阶段把 AppIcon 替换为 LucideIcon。Provider 内部用 `<common-list>` 渲染 provider 列表，PD Phase 接入 nav-item 后视觉自动统一。

**只需验证**：Provider.vue 的 collapse 标题 icon 与 common-list 列表项视觉一致。

---

## 8. 落地策略

### 8.1 Phase 切分

| Phase | 内容 | 估时 |
|---|---|---|
| **PA · Token + placeholder** | variables.scss 加 7 个 nav-item token + 4 个 side-item token 重映射；component.scss 加 `%nav-item-base` placeholder | 0.25d |
| **PB · folder-tree icon + 样式** | 8 处 AppIcon → Lucide；`el-tree-node__content` @extend placeholder | 0.5d |
| **PC · SidebarItem + meta.icon** | SidebarItem.vue 删手写 SCSS + Lucide icon；4 个 route meta.icon 改 Lucide name；放弃 iconActive | 0.25d |
| **PD · common-list** | li @extend placeholder | 0.1d |
| **PE · 验证** | grep + type-check + build + dev server 走查 | 0.15d |

**单人总计约 1.25d**。

### 8.2 验收

1. `npm run type-check` 退出 0
2. `npm run build` 编译通过
3. dev server 走查：
   - **knowledge folder-tree**：folder 用 Lucide 细线 `folder`；下拉操作菜单 icons 全 Lucide outline；hover/active 视觉与 system Side 一致
   - **tool folder-tree**：同上
   - **system Side**：user (`users`) / authorization (`shield-check`) / email (`mail`) 3 项 icon 是 Lucide outline；项高 36px；激活态背景 primary-light-9
   - **model Provider**：常规列表项视觉与 folder-tree 一致
   - 浏览器控制台 0 warnings / 0 errors
4. 全局 grep：
   ```bash
   grep -rn "AppIcon" ui/src/components/folder-tree ui/src/layout/components/sidebar
   grep -rn "'User'\|'UserFilled'" ui/src/router
   grep -rn "iconActive" ui/src/router/modules/{system,application}.ts
   ```
   期望：均 0 hit
5. `apps/` git diff 为空

### 8.3 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| `@extend %nav-item-base` 在 `:deep()` 下不生效 | folder-tree / SidebarItem 项不接 placeholder | 实施时若 @extend 失败，回退为 `@include nav-item-base`（§3.4） |
| `sortIconName` 动态值映射难定 | 排序按钮显示错乱 | 实施时读 folder-tree script 找到该 ref 的 set 路径，根据现有 `'app-sort-XXX'` 值映射 |
| Side.vue 老 token 重映射后某处显示色微变 | UI 视觉细微变化 | 重映射保留语义；新值与原 SidebarItem 覆盖后实际渲染色基本一致（`primary-light-9` / `primary`）|
| route meta.icon 改 Lucide name 后其它消费者（breadcrumb? 弹窗?）显示错 | 非 Side 上下文图标错乱 | grep 所有 `meta.icon` / `meta.iconActive` 消费者；非 Side 路径保持 AppIcon 引用 |
| el-menu-item 缩进 padding-left 在 sub-menu 嵌套场景效果跟 EP 默认有差 | 子菜单不齐 | 已在 §5.1 加 `padding-left: 36px` 给 sub-menu；如有更深嵌套用 EP 默认 |
| Icon 从 20→16px 缩小后 folder-tree 主图标视觉权重不足 | folder 主图标"显得小" | 接受 16px 统一；实际使用中走查若问题大可单独调整 folder-tree 主图标为 18px |

### 8.4 不在范围

- workbench / Rail 顶级 icon（已是 Lucide via `RAIL_MODULES.lucide`）
- `router/modules/application-detail.ts` / `document.ts` / `knowledge.ts` / `tool.ts` / `model.ts` 的子路由 `meta.icon` —— 不在 Side 渲染路径
- AppIcon 组件本身的退休（保留，仍被其它视图大量引用）
- el-tree 内置缩进 `--el-tree-node-indent`（不动）
- 后端 / API
- `/chat`、`/user-login` 嵌入页

### 8.5 完成定义

1. 7 个 `--nav-item-*` token 单一驱动 3 组件
2. folder-tree 8 处 AppIcon 全部 Lucide outline 16px
3. SidebarItem.vue 删除手写覆盖；Side.vue 老 token 实际生效（通过重映射）
4. 4 个路由 meta.icon 是 Lucide name；`iconActive` 在 Side 渲染路径中放弃
5. 三组件视觉一致：36px / 13px / primary 激活色 / 4px radius / 2px margin
6. `apps/` git diff 为空
7. type-check / build 全清白
