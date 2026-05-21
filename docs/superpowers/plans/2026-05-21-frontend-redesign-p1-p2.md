# 前端重设计 P1+P2 实施计划 · 基础设施 + 骨架与导航

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 spec `docs/superpowers/specs/2026-05-21-frontend-redesign-design.md` 的 Phase 1（基础设施）与 Phase 2（骨架与导航）—— 替换设计 Token、Element Plus 主题、Icon 系统、品牌素材；将顶部水平 + 侧栏布局重做为「左侧深色 Rail + 浅色二级 Side + 白色 Main」三段结构；导航 IA 重排为 5 个顶级模块，新增 `/workbench` 工作台路由。

**Architecture:** 改动集中在 `ui/src/styles/`（Token 层）、`ui/src/layout/`（骨架层）、`ui/src/router/modules/`（导航 meta）、`ui/src/locales/`（文案层）。后端代码与 API 不动。LogicFlow、Element Plus 仅通过 CSS 变量层覆写，不替换组件库。

**Tech Stack:** Vue 3 + Vite 6 + TypeScript + Element Plus 2.13 + SCSS + vue-i18n 11 + @iconify/vue（新引入）+ @iconify-json/lucide（新引入）。

**Verification approach:** 本仓库 UI 无单元测试与 e2e 测试基础设施。本计划用以下手段替代 TDD：
- `npm run type-check` 做类型门
- `npm run build` 做编译门
- `npm run dev` + 浏览器手动访问关键路由（/login、/、/application、/knowledge、/model、/system）做视觉门
- `git grep -i maxkb` 做指纹清理门

每个 task 完成后必须执行至少一项门并附预期输出。

---

## 任务总览（17 个 Task，按依赖顺序）

**P1 · 基础设施**
1. 添加 Lucide / Iconify 依赖
2. 重写设计 Token（`variables.scss`）
3. 覆写 Element Plus 主题（`element-plus.scss`）
4. 调整字号与密度（`app.scss`、`index.scss`、`component.scss`）
5. 清理 "MaxKB" 字符串：TS/JS/Vue 中的 hardcoded 文案
6. 更新 HTML 标题与 meta（`admin.html`、`chat.html`）
7. 替换品牌素材占位（logo、favicon）

**P2 · 骨架与导航**
8. 创建 LucideIcon 包装组件
9. 定义 Rail 模块数据与 Lucide 映射
10. 创建 Rail 组件（`layout-rail/`）
11. 创建 Side 组件（`layout-side/`）
12. 重构 `MainLayout.vue` 为三段结构
13. 重构 `SystemMainLayout.vue` 同款结构
14. 调整 `SimpleLayout.vue`（去渐变）
15. 创建 `/workbench` 占位路由 + 改根 redirect
16. i18n 文案术语重命名（zh-CN / en-US / zh-Hant）
17. P1+P2 联合走查 + 最终提交

---

## P1 · 基础设施

### Task 1: 添加 Lucide / Iconify 依赖

**Files:**
- Modify: `ui/package.json`

- [ ] **Step 1: 安装依赖**

```bash
cd ui
npm install @iconify/vue@^4.1.2 @iconify-json/lucide@^1.0.0 --save
```

- [ ] **Step 2: 验证 package.json 已写入**

Run: `git -C .. diff -- ui/package.json | grep iconify`
Expected 输出两行：`+    "@iconify/vue": "^4.1.2",` 与 `+    "@iconify-json/lucide": "^1.0.0",`（版本号最终以 npm 实际写入为准）。

- [ ] **Step 3: 验证 vite 可解析**

```bash
cd ui
npm run type-check
```

Expected: 退出码 0；无 `Cannot find module '@iconify/vue'` 报错。

- [ ] **Step 4: Commit**

```bash
git add ui/package.json ui/package-lock.json
git commit -m "chore(ui): add @iconify/vue + lucide icon set for redesign"
```

---

### Task 2: 重写设计 Token（`variables.scss`）

**Files:**
- Modify: `ui/src/styles/variables.scss`（完全重写）

- [ ] **Step 1: 备份当前 variables.scss 内容到 git 暂存（可选回看）**

```bash
git -C .. show HEAD:ui/src/styles/variables.scss > /tmp/variables.scss.bak
```

- [ ] **Step 2: 覆盖写入新内容**

写入 `ui/src/styles/variables.scss`：

```scss
:root {
  /* ===== 品牌 Token（占位，待用户提供素材时替换） ===== */
  --brand-primary: #0f172a;
  --brand-primary-hover: #1e293b;
  --brand-primary-active: #334155;
  --brand-primary-soft: rgba(15, 23, 42, 0.08);

  /* ===== 兼容老变量（避免一次性 break 现存视图） ===== */
  --el-color-primary: var(--brand-primary);
  --app-base-px: 8px;

  /* ===== Layout · Rail（深） ===== */
  --rail-width: 64px;
  --rail-bg: #0f172a;
  --rail-text: #94a3b8;
  --rail-text-active: #ffffff;
  --rail-hover-bg: #1e293b;
  --rail-active-bar: var(--brand-primary);

  /* ===== Layout · Side（浅灰） ===== */
  --side-width: 200px;
  --side-bg: #f8fafc;
  --side-border: #e2e8f0;
  --side-item-text: #475569;
  --side-item-hover-bg: #eef2f6;
  --side-item-active-bg: #e2e8f0;
  --side-item-active-text: #0f172a;

  /* ===== Layout · Main ===== */
  --main-bg: #ffffff;
  --app-layout-bg-color: #f5f6f7;
  --app-view-bg-color: #ffffff;
  --app-view-padding: 20px; /* 旧 24px */
  --app-main-height: calc(100vh - var(--app-view-padding) * 2);

  /* ===== 文字 ===== */
  --text-primary: #0f172a;
  --text-secondary: #64748b;
  --text-tertiary: #94a3b8;
  --app-text-color-secondary: var(--text-secondary);
  --app-text-color-disable: var(--text-tertiary);
  --app-input-color-placeholder: var(--text-tertiary);

  /* ===== 边框 ===== */
  --border-base: #e5e7eb;
  --border-strong: #cbd5e1;
  --app-border-color-dark: var(--border-strong);

  /* ===== 形状（比 MaxKB 紧一档、方一档） ===== */
  --radius-sm: 4px;
  --radius-md: 6px;
  --radius-lg: 10px;
  --app-border-radius-small: var(--radius-sm);
  --app-border-radius-base: var(--radius-md);
  --app-border-radius-large: var(--radius-lg);

  /* ===== 字号阶梯 ===== */
  --font-size-xs: 11px;
  --font-size-sm: 12px;
  --font-size-base: 13px;
  --font-size-md: 14px;
  --font-size-lg: 16px;
  --font-size-xl: 18px;

  /* ===== Card 密度 ===== */
  --card-width: 260px;        /* 旧 330 */
  --card-min-height: 140px;   /* 旧 166 */
  --card-min-width: 260px;    /* 旧 220 */

  /* ===== 状态色（去 MaxKB 高饱和） ===== */
  --status-success-bg: #ecfdf5;
  --status-success-text: #047857;
  --status-warning-bg: #fffbeb;
  --status-warning-text: #b45309;
  --status-danger-bg: #fef2f2;
  --status-danger-text: #b91c1c;
  --status-info-bg: #eff6ff;
  --status-info-text: #1d4ed8;

  --tag-default-bg: var(--status-info-bg);
  --tag-default-color: var(--status-info-text);
  --tag-success-bg: var(--status-success-bg);
  --tag-success-color: var(--status-success-text);
  --tag-warning-bg: var(--status-warning-bg);
  --tag-warning-color: var(--status-warning-text);
  --tag-danger-bg: var(--status-danger-bg);

  /* ===== 资源授权侧栏宽（保留） ===== */
  --setting-left-width: 280px;
  --md-bk-hover-color: var(--el-border-color-hover);

  /* ===== Header 兼容变量（保留但置空，避免引用方报错） ===== */
  --app-header-height: 0px;
  --app-header-padding: 0;

  /* ❌ 删除：--app-header-bg-color（蓝紫渐变） */
  /* ❌ 删除：--app-logo-color（蓝紫渐变） */
  /* ❌ 删除：--app-avatar-gradient-color（紫蓝渐变） */

  /* ===== AI chat 背景（去渐变） ===== */
  --dialog-bg-gradient-color: #f8fafc;
}
```

- [ ] **Step 3: 验证 SCSS 编译**

```bash
cd ui
npm run build 2>&1 | tail -30
```

Expected: 构建成功；可能有部分视图引用了已删除的渐变变量，看是否有 `--app-header-bg-color` 相关警告。如有，记录到 task 12-14 中处理。

- [ ] **Step 4: 启动 dev server，访问 /login 与 /application，目测确认全站无渐变残留**

```bash
cd ui
npm run dev
```

打开 `http://localhost:5173/login`，预期：现状仍是 MaxKB 布局，但 header 区域不再有渐变背景（变成纯色或空白，因 `--app-header-bg-color` 被删除）。这是预期中的"过渡态"，下一个 task 起会逐步收拾。

- [ ] **Step 5: Commit**

```bash
git add ui/src/styles/variables.scss
git commit -m "style(ui): rewrite design tokens for redesign (remove gradients)"
```

---

### Task 3: 覆写 Element Plus 主题（`element-plus.scss`）

**Files:**
- Modify: `ui/src/styles/element-plus.scss`

- [ ] **Step 1: 读取当前内容**

```bash
cat ui/src/styles/element-plus.scss
```

记录其结构，下面在文件顶部追加 / 覆盖关键变量。

- [ ] **Step 2: 在文件顶部插入 EP CSS 变量覆盖块**

修改 `ui/src/styles/element-plus.scss`，在已有 `@use 'element-plus/...';` 等导入之后、其余规则之前插入：

```scss
:root {
  /* ===== Element Plus 主题覆盖（仅 CSS 变量层） ===== */
  --el-color-primary: var(--brand-primary);
  --el-color-primary-light-3: var(--brand-primary-hover);
  --el-color-primary-light-5: var(--brand-primary-active);
  --el-color-primary-light-7: var(--brand-primary-soft);
  --el-color-primary-light-9: var(--brand-primary-soft);

  --el-border-radius-base: var(--radius-md);
  --el-border-radius-small: var(--radius-sm);
  --el-border-radius-round: var(--radius-lg);

  --el-text-color-primary: var(--text-primary);
  --el-text-color-regular: var(--text-secondary);
  --el-text-color-secondary: var(--text-secondary);
  --el-text-color-placeholder: var(--text-tertiary);
  --el-text-color-disabled: var(--text-tertiary);

  --el-border-color: var(--border-base);
  --el-border-color-light: var(--border-base);
  --el-border-color-lighter: var(--border-base);

  --el-bg-color-page: var(--app-layout-bg-color);
  --el-bg-color: var(--main-bg);

  --el-font-size-base: var(--font-size-base);
  --el-font-size-small: var(--font-size-sm);
  --el-font-size-large: var(--font-size-md);
}
```

如文件已有 `:root {}` 块，将上述变量合并进去，避免重复 `:root {`。

- [ ] **Step 3: 验证类型与编译**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0；构建成功。

- [ ] **Step 4: dev server 目测 EP 组件圆角已变小**

```bash
cd ui
npm run dev
```

访问 `/login`，预期：登录按钮圆角从 8px → 6px；输入框圆角同步变化。

- [ ] **Step 5: Commit**

```bash
git add ui/src/styles/element-plus.scss
git commit -m "style(ui): override Element Plus theme via CSS variables"
```

---

### Task 4: 调整字号与密度（`app.scss`、`index.scss`、`component.scss`）

**Files:**
- Modify: `ui/src/styles/app.scss`
- Modify: `ui/src/styles/index.scss`
- Modify: `ui/src/styles/component.scss`

- [ ] **Step 1: 读取 3 个文件当前内容，识别影响字号/间距/圆角的规则**

```bash
cat ui/src/styles/app.scss
cat ui/src/styles/index.scss
cat ui/src/styles/component.scss
```

记录所有 `font-size:` `padding:` `border-radius:` 硬编码值。

- [ ] **Step 2: 替换硬编码字号为 CSS 变量**

对每个 `font-size: 14px` 改为 `font-size: var(--font-size-md)`；`font-size: 13px` → `var(--font-size-base)`；`font-size: 12px` → `var(--font-size-sm)`。其它字号同理映射。

如有 `padding: 24px` 用于视图容器，改为 `padding: var(--app-view-padding)`。

如有 `border-radius: 16px` 改为 `var(--radius-lg)`；`8px` → `var(--radius-md)`；`6px` → `var(--radius-sm)`。

- [ ] **Step 3: 验证编译**

```bash
cd ui
npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

- [ ] **Step 4: dev server 目测密度**

访问 `/application`，预期：卡片间距与字号略紧一档。

- [ ] **Step 5: Commit**

```bash
git add ui/src/styles/app.scss ui/src/styles/index.scss ui/src/styles/component.scss
git commit -m "style(ui): switch hardcoded sizes to design token vars"
```

---

### Task 5: 清理 "MaxKB" 字符串（TS/JS/Vue hardcoded 文案）

**Files:**
- Modify: 全仓 grep `MaxKB`（非 `LICENSE`、非 `README*`、非 `docs/`）的所有 TS/Vue 文件
- Modify: `ui/src/utils/common.ts`（产品名常量）
- Modify: `ui/src/stores/modules/user.ts`、`ui/src/main.ts`、`ui/src/chat.ts` 等已知文件

- [ ] **Step 1: 先创建产品名常量集中位**

新建文件 `ui/src/utils/brand.ts`：

```typescript
/**
 * 品牌常量集中位 —— 后续替换产品名时只动这里。
 * 用户提供品牌素材后填入实际值。
 */
export const PRODUCT_NAME = '产品名'
export const PRODUCT_NAME_EN = 'ProductName'
export const PRODUCT_SLOGAN = '企业知识与智能体平台'
export const PRODUCT_SLOGAN_EN = 'Enterprise knowledge & agent platform'
```

- [ ] **Step 2: 全仓 grep 找出所有硬编码 "MaxKB"**

```bash
git -C .. grep -ln 'MaxKB' -- ui/src
```

Expected 输出约 20 个文件（与设计文档中提到的范围一致）。

- [ ] **Step 3: 逐文件替换**

对每个文件，将硬编码的 `'MaxKB'` 字面量改为 `PRODUCT_NAME`，并在文件顶部 import：

```typescript
import { PRODUCT_NAME } from '@/utils/brand'
```

如果是 Vue 模板中的 `MaxKB` 字面文字，改为 `{{ productName }}`，在 `<script setup>` 中：

```typescript
import { PRODUCT_NAME as productName } from '@/utils/brand'
```

注意：**不要碰** `apps/`（后端）、`LICENSE`、`README*.md`、`docs/`。

- [ ] **Step 4: 验证清理结果**

```bash
git -C .. grep -ln -i 'maxkb' -- ui/src ui/admin.html ui/chat.html ui/public 2>/dev/null
```

Expected: 输出仅剩 `ui/src/assets/logo/MaxKB-logo.svg` 与 `MaxKB-logo-currentColor.svg`（文件名，下一个 task 替换）。

- [ ] **Step 5: 类型检查 + 构建**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

- [ ] **Step 6: Commit**

```bash
git add ui/src
git commit -m "refactor(ui): centralize product brand name in utils/brand.ts"
```

---

### Task 6: 更新 HTML 标题与 meta

**Files:**
- Modify: `ui/admin.html`
- Modify: `ui/chat.html`

- [ ] **Step 1: 读取当前**

```bash
cat ui/admin.html ui/chat.html
```

记录 `<title>` 与 `<meta name="description">`。

- [ ] **Step 2: 替换 title 与 description**

`ui/admin.html`：将 `<title>MaxKB</title>`（或当前内容）改为：

```html
<title>%VITE_APP_TITLE%</title>
```

如 vite.config.ts 有 `vite-plugin-html` 注入变量则保留，否则直接写产品名占位：

```html
<title>产品名 · 管理控制台</title>
```

`ui/chat.html` 同理：

```html
<title>产品名 · 智能助手</title>
```

如有 `<meta name="description" content="MaxKB...">` 同步改为产品描述。

- [ ] **Step 3: 验证**

```bash
cd ui
npm run build
grep -i 'maxkb' dist/*.html
```

Expected: 无输出（构建产物中无 MaxKB 文字）。

- [ ] **Step 4: Commit**

```bash
git add ui/admin.html ui/chat.html
git commit -m "refactor(ui): rebrand HTML titles and meta"
```

---

### Task 7: 替换品牌素材占位

**Files:**
- Modify: `ui/public/favicon.ico`（占位为通用图标）
- Modify: `ui/src/assets/logo/logo.svg`（占位）
- Modify: `ui/src/assets/logo/logo-currentColor.svg`（占位）
- Delete: `ui/src/assets/logo/MaxKB-logo.svg`
- Delete: `ui/src/assets/logo/MaxKB-logo-currentColor.svg`
- Modify: `ui/public/InsightHub.gif`（如未被引用则删除）
- Modify: `ui/public/tipIMG.jpg`（如未被引用则删除）

- [ ] **Step 1: 确认 MaxKB-logo.svg 引用**

```bash
git -C .. grep -l 'MaxKB-logo' -- ui/src
```

Expected: 输出 0 个或少量引用文件。

- [ ] **Step 2: 替换 logo 占位 svg**

写入 `ui/src/assets/logo/logo.svg`（占位深色方块 + 字母 M）：

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect width="64" height="64" rx="10" fill="#0f172a"/>
  <text x="32" y="42" font-family="system-ui" font-size="28" font-weight="700" text-anchor="middle" fill="#ffffff">M</text>
</svg>
```

写入 `ui/src/assets/logo/logo-currentColor.svg`（同形状但用 currentColor）：

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect width="64" height="64" rx="10" fill="currentColor"/>
  <text x="32" y="42" font-family="system-ui" font-size="28" font-weight="700" text-anchor="middle" fill="#ffffff">M</text>
</svg>
```

- [ ] **Step 3: 删除 MaxKB 相关 svg**

```bash
git -C .. rm ui/src/assets/logo/MaxKB-logo.svg ui/src/assets/logo/MaxKB-logo-currentColor.svg
```

- [ ] **Step 4: 检查 favicon 与公共图片引用**

```bash
git -C .. grep -l 'InsightHub\|tipIMG\|favicon' -- ui/src ui/admin.html ui/chat.html
```

如未引用则：

```bash
git -C .. rm ui/public/InsightHub.gif ui/public/tipIMG.jpg
```

`ui/public/favicon.ico` 暂保留（用户提供后再换）；可生成占位：

```bash
# 留下一行注释提示
echo "Placeholder — replace with brand favicon before release" > ui/public/.favicon-todo
```

- [ ] **Step 5: 编译验证**

```bash
cd ui
npm run build 2>&1 | tail -10
```

Expected: 退出码 0；如有 `import '~/assets/logo/MaxKB-logo.svg'` 报错说明 Step 1 漏改，回去修。

- [ ] **Step 6: Commit**

```bash
git add ui/src/assets/logo ui/public
git commit -m "assets(ui): replace MaxKB branding assets with placeholders"
```

---

## P2 · 骨架与导航

### Task 8: 创建 LucideIcon 包装组件

**Files:**
- Create: `ui/src/components/lucide-icon/LucideIcon.vue`
- Create: `ui/src/components/lucide-icon/index.ts`

- [ ] **Step 1: 创建 LucideIcon.vue**

写入 `ui/src/components/lucide-icon/LucideIcon.vue`：

```vue
<template>
  <Icon :icon="`lucide:${name}`" :width="size" :height="size" />
</template>

<script setup lang="ts">
import { Icon } from '@iconify/vue'

withDefaults(
  defineProps<{
    name: string
    size?: number | string
  }>(),
  {
    size: 18,
  },
)
</script>
```

- [ ] **Step 2: 创建 index.ts 导出**

写入 `ui/src/components/lucide-icon/index.ts`：

```typescript
export { default as LucideIcon } from './LucideIcon.vue'
```

- [ ] **Step 3: 类型检查**

```bash
cd ui
npm run type-check
```

Expected: 退出码 0。

- [ ] **Step 4: dev server 烟雾测试 —— 临时插入一个图标到 /login**

在 `ui/src/views/login/index.vue` 文件顶部任意可见位置临时插入 `<LucideIcon name="check" :size="24" />`，访问 `/login`，预期：能看到一个对勾图标。验证后还原。

- [ ] **Step 5: Commit**

```bash
git add ui/src/components/lucide-icon
git commit -m "feat(ui): add LucideIcon wrapper component"
```

---

### Task 9: 定义 Rail 模块数据与 Lucide 映射

（先做数据，再做组件 —— Task 10/11 依赖此 task）

**Files:**
- Create: `ui/src/layout/layout-rail/modules.ts`

- [ ] **Step 1: 创建模块数据**

写入 `ui/src/layout/layout-rail/modules.ts`：

```typescript
/**
 * Rail 顶级模块定义。
 * - title: i18n key（指向 ui/src/locales/lang/<locale>/layout.ts 的 rail.<key>）
 * - lucide: lucide 图标名
 * - path: 顶级路径，点击 Rail 时跳转的根 path
 * - matchPaths: 主路径前缀集合，用于判断当前 active 模块
 */
export interface RailModule {
  key: string
  titleKey: string
  lucide: string
  path: string
  matchPaths: string[]
}

export const RAIL_MODULES: RailModule[] = [
  {
    key: 'workbench',
    titleKey: 'rail.workbench',
    lucide: 'layout-dashboard',
    path: '/workbench',
    matchPaths: ['/workbench'],
  },
  {
    key: 'agent',
    titleKey: 'rail.agent',
    lucide: 'bot',
    path: '/application',
    matchPaths: ['/application', '/chat-user'],
  },
  {
    key: 'knowledge',
    titleKey: 'rail.knowledge',
    lucide: 'book-open-text',
    path: '/knowledge',
    matchPaths: ['/knowledge', '/document', '/paragraph', '/hit-test', '/problem'],
  },
  {
    key: 'capability',
    titleKey: 'rail.capability',
    lucide: 'puzzle',
    path: '/tool',
    matchPaths: ['/tool', '/trigger'],
  },
  {
    key: 'platform',
    titleKey: 'rail.platform',
    lucide: 'settings-2',
    path: '/model',
    matchPaths: ['/model', '/system'],
  },
]

export function findActiveModuleKey(currentPath: string): string {
  for (const m of RAIL_MODULES) {
    if (m.matchPaths.some((p) => currentPath.startsWith(p))) return m.key
  }
  return RAIL_MODULES[0].key
}
```

- [ ] **Step 2: 类型检查**

```bash
cd ui
npm run type-check
```

Expected: 退出码 0。

- [ ] **Step 3: Commit**

```bash
git add ui/src/layout/layout-rail/modules.ts
git commit -m "feat(ui): define Rail module data with Lucide icon mapping"
```

---

### Task 10: 创建 Rail 组件

**Files:**
- Create: `ui/src/layout/layout-rail/Rail.vue`
- Create: `ui/src/layout/layout-rail/index.ts`

- [ ] **Step 1: 创建 Rail.vue**

写入 `ui/src/layout/layout-rail/Rail.vue`：

```vue
<template>
  <nav class="app-rail" :aria-label="$t('rail.aria')">
    <router-link to="/workbench" class="app-rail__brand" aria-label="home">
      <img src="@/assets/logo/logo-currentColor.svg" alt="" />
    </router-link>
    <ul class="app-rail__items">
      <li v-for="m in RAIL_MODULES" :key="m.key">
        <router-link
          :to="m.path"
          class="app-rail__item"
          :class="{ 'is-active': activeKey === m.key }"
          v-hasPermission="undefined"
        >
          <LucideIcon :name="m.lucide" :size="20" />
          <span class="app-rail__label">{{ $t(m.titleKey) }}</span>
        </router-link>
      </li>
    </ul>
  </nav>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { RAIL_MODULES, findActiveModuleKey } from './modules'
import { LucideIcon } from '@/components/lucide-icon'

const route = useRoute()
const activeKey = computed(() => findActiveModuleKey(route.path))
</script>

<style lang="scss" scoped>
.app-rail {
  width: var(--rail-width);
  background: var(--rail-bg);
  color: var(--rail-text);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 0;
  flex-shrink: 0;
  height: 100vh;
  position: sticky;
  top: 0;
}
.app-rail__brand {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 16px;
  color: var(--rail-text-active);
}
.app-rail__brand img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.app-rail__items {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
  width: 100%;
}
.app-rail__item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 10px 6px;
  font-size: 10px;
  color: var(--rail-text);
  text-decoration: none;
  border-left: 2px solid transparent;
  transition:
    color 0.15s,
    background 0.15s,
    border-color 0.15s;
}
.app-rail__item:hover {
  background: var(--rail-hover-bg);
  color: var(--rail-text-active);
}
.app-rail__item.is-active {
  background: var(--rail-hover-bg);
  color: var(--rail-text-active);
  border-left-color: var(--rail-active-bar);
}
.app-rail__label {
  font-size: 10px;
  line-height: 1.2;
  text-align: center;
}
</style>
```

- [ ] **Step 2: 创建 index.ts**

写入 `ui/src/layout/layout-rail/index.ts`：

```typescript
export { default as Rail } from './Rail.vue'
export * from './modules'
```

- [ ] **Step 3: 类型检查**

```bash
cd ui
npm run type-check
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/layout/layout-rail
git commit -m "feat(ui): add Rail component for top-level module navigation"
```

---

### Task 11: 创建 Side 组件

**Files:**
- Create: `ui/src/layout/layout-side/Side.vue`
- Create: `ui/src/layout/layout-side/index.ts`

- [ ] **Step 1: 创建 Side.vue**

写入 `ui/src/layout/layout-side/Side.vue`：

```vue
<template>
  <aside class="app-side" :aria-label="$t('side.aria')">
    <div class="app-side__title">{{ moduleTitle }}</div>
    <el-scrollbar>
      <el-menu
        :default-active="activeMenu"
        router
        class="app-side__menu"
        background-color="transparent"
      >
        <SidebarItem
          v-hasPermission="menu.meta?.permission"
          v-for="(menu, index) in subMenuList"
          :key="index"
          :menu="menu"
          :activeMenu="activeMenu"
        />
      </el-menu>
    </el-scrollbar>
  </aside>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { getChildRouteListByPathAndName } from '@/router/index'
import { RAIL_MODULES, findActiveModuleKey } from '@/layout/layout-rail/modules'
import SidebarItem from '@/layout/components/sidebar/SidebarItem.vue'

const route = useRoute()
const { t } = useI18n()

const subMenuList = computed(() => {
  const { meta } = route
  return getChildRouteListByPathAndName(meta.parentPath as string, meta.parentName as string)
})

const activeMenu = computed(() => {
  const { path, meta } = route
  return (meta.active as string) || path
})

const moduleTitle = computed(() => {
  const key = findActiveModuleKey(route.path)
  const m = RAIL_MODULES.find((x) => x.key === key)
  return m ? t(m.titleKey) : ''
})
</script>

<style lang="scss" scoped>
.app-side {
  width: var(--side-width);
  background: var(--side-bg);
  border-right: 1px solid var(--side-border);
  flex-shrink: 0;
  height: 100vh;
  display: flex;
  flex-direction: column;
  position: sticky;
  top: 0;
}
.app-side__title {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-primary);
  padding: 16px 14px 12px;
}
.app-side__menu {
  border: none;
  background: transparent;
  padding: 0 8px;

  :deep(.el-menu-item) {
    height: 36px;
    line-height: 36px;
    color: var(--side-item-text);
    border-radius: var(--radius-sm);
    margin-bottom: 2px;
    font-size: var(--font-size-base);
  }
  :deep(.el-menu-item:hover) {
    background: var(--side-item-hover-bg);
    color: var(--side-item-active-text);
  }
  :deep(.el-menu-item.is-active) {
    background: var(--side-item-active-bg);
    color: var(--side-item-active-text);
    font-weight: 500;
  }
}
</style>
```

- [ ] **Step 2: 创建 index.ts**

写入 `ui/src/layout/layout-side/index.ts`：

```typescript
export { default as Side } from './Side.vue'
```

- [ ] **Step 3: 类型检查**

```bash
cd ui
npm run type-check
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/layout/layout-side
git commit -m "feat(ui): add Side component for module sub-navigation"
```

---

### Task 12: 重构 `MainLayout.vue` 为三段结构

**Files:**
- Modify: `ui/src/layout/layout-template/MainLayout.vue`
- Modify: `ui/src/layout/layout-template/index.scss`（如使用 layout-container 也需调整）

- [ ] **Step 1: 重写 MainLayout.vue**

完整替换为：

```vue
<template>
  <div class="app-layout">
    <el-alert
      v-if="user.isExpire()"
      :title="$t('layout.isExpire')"
      type="warning"
      class="app-layout__expire"
      show-icon
      :closable="false"
    />
    <div class="app-layout__body" :class="{ 'is-expire': user.isExpire() }">
      <Rail />
      <Side v-if="!isShared" />
      <main class="app-main">
        <AppMain />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { Rail } from '@/layout/layout-rail'
import { Side } from '@/layout/layout-side'
import AppMain from '@/layout/app-main/index.vue'
import useStore from '@/stores'

const route = useRoute()
const { user } = useStore()

const {
  params: { folderId },
  query: { from },
} = route as any

const isShared = computed(() => {
  return (
    folderId === 'shared' ||
    from === 'systemShare' ||
    from === 'systemManage' ||
    route.path.includes('resource-management')
  )
})
</script>

<style lang="scss" scoped>
.app-layout {
  min-height: 100vh;
  background: var(--app-layout-bg-color);
}
.app-layout__expire {
  position: sticky;
  top: 0;
  z-index: 100;
  border-radius: 0;
}
.app-layout__body {
  display: flex;
  min-height: 100vh;
}
.app-main {
  flex: 1;
  min-width: 0;
  background: var(--main-bg);
  padding: var(--app-view-padding);
  overflow: auto;
}
.is-expire .app-main {
  min-height: calc(100vh - 40px);
}
</style>
```

- [ ] **Step 2: 删除 layout-header 旧 import（已不再用）**

不需主动删 `UserHeader.vue` `SystemHeader.vue` 文件本身（保留磁盘文件以防其它地方 import），仅在 MainLayout 中不再使用。

- [ ] **Step 3: 类型检查 + 构建**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

- [ ] **Step 4: dev server 走查**

```bash
cd ui
npm run dev
```

登录后访问 `/application`，预期：左侧出现 64px 深色 Rail（5 个图标）+ 200px 浅色 Side（"智能体"子菜单）+ 白色 Main。顶部 bar 消失。

- [ ] **Step 5: Commit**

```bash
git add ui/src/layout/layout-template/MainLayout.vue
git commit -m "refactor(ui): restructure MainLayout to Rail + Side + Main"
```

---

### Task 13: 重构 `SystemMainLayout.vue`

**Files:**
- Modify: `ui/src/layout/layout-template/SystemMainLayout.vue`

- [ ] **Step 1: 读取当前**

```bash
cat ui/src/layout/layout-template/SystemMainLayout.vue
```

- [ ] **Step 2: 重写为同款三段结构**

```vue
<template>
  <div class="app-layout">
    <div class="app-layout__body">
      <Rail />
      <Side />
      <main class="app-main">
        <AppMain />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Rail } from '@/layout/layout-rail'
import { Side } from '@/layout/layout-side'
import AppMain from '@/layout/app-main/index.vue'
</script>

<style lang="scss" scoped>
.app-layout {
  min-height: 100vh;
  background: var(--app-layout-bg-color);
}
.app-layout__body {
  display: flex;
  min-height: 100vh;
}
.app-main {
  flex: 1;
  min-width: 0;
  background: var(--main-bg);
  padding: var(--app-view-padding);
  overflow: auto;
}
</style>
```

- [ ] **Step 3: 类型检查 + 构建**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

- [ ] **Step 4: 访问 `/system`，目测三段结构生效**

预期：与管理后台主页面同样的 Rail + Side + Main 三段。

- [ ] **Step 5: Commit**

```bash
git add ui/src/layout/layout-template/SystemMainLayout.vue
git commit -m "refactor(ui): restructure SystemMainLayout to Rail + Side + Main"
```

---

### Task 14: 调整 `SimpleLayout.vue`（去渐变）

**Files:**
- Modify: `ui/src/layout/layout-template/SimpleLayout.vue`

- [ ] **Step 1: 读取**

```bash
cat ui/src/layout/layout-template/SimpleLayout.vue
```

- [ ] **Step 2: 去渐变**

将文件中所有 `linear-gradient(...)` 与对 `--app-header-bg-color` `--app-logo-color` 的引用替换为纯色 var 或删除对应规则。如：

```scss
// 旧（删除）
// background: var(--app-header-bg-color);
// 新
background: var(--main-bg);
```

如组件渲染了 header，使整体退化为单一白底全屏容器：

```vue
<template>
  <div class="simple-layout">
    <router-view />
  </div>
</template>

<style scoped lang="scss">
.simple-layout {
  min-height: 100vh;
  background: var(--main-bg);
}
</style>
```

（具体保留多少现有逻辑取决于 SimpleLayout 当前是否被 children 路由使用 —— 不要删 `<router-view>` 或其它必要插槽）。

- [ ] **Step 3: 类型检查 + 构建**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

- [ ] **Step 4: 访问 `/login`，目测无渐变 header**

- [ ] **Step 5: Commit**

```bash
git add ui/src/layout/layout-template/SimpleLayout.vue
git commit -m "refactor(ui): remove gradients from SimpleLayout"
```

---

### Task 15: 创建 `/workbench` 占位路由 + 改根 redirect

**Files:**
- Create: `ui/src/router/modules/workbench.ts`
- Create: `ui/src/views/workbench/index.vue`（占位，仅放标题与说明）
- Modify: `ui/src/router/routes.ts`

- [ ] **Step 1: 创建占位视图**

写入 `ui/src/views/workbench/index.vue`：

```vue
<template>
  <div class="workbench-placeholder">
    <h1>{{ $t('rail.workbench') }}</h1>
    <p>{{ $t('workbench.placeholder') }}</p>
  </div>
</template>

<style lang="scss" scoped>
.workbench-placeholder {
  padding: 24px;
  color: var(--text-secondary);
  h1 {
    color: var(--text-primary);
    font-size: var(--font-size-xl);
    margin-bottom: 12px;
  }
}
</style>
```

- [ ] **Step 2: 创建路由模块**

写入 `ui/src/router/modules/workbench.ts`：

```typescript
import { RoleConst } from '@/utils/permission/data'

const workbenchRouter = {
  path: '/workbench',
  name: 'workbench',
  meta: {
    title: 'rail.workbench',
    menu: true,
    permission: [
      RoleConst.USER.getWorkspaceRole,
      RoleConst.WORKSPACE_MANAGE.getWorkspaceRole,
    ],
    icon: 'workbench',
    group: 'workspace',
    order: 0,
  },
  redirect: '/workbench',
  component: () => import('@/layout/layout-template/SimpleLayout.vue'),
  children: [
    {
      path: '/workbench',
      name: 'workbench-index',
      meta: { title: 'rail.workbench', activeMenu: '/workbench' },
      component: () => import('@/views/workbench/index.vue'),
      hidden: true,
    },
  ],
}

export default workbenchRouter
```

- [ ] **Step 3: 修改根 redirect**

修改 `ui/src/router/routes.ts` 第 9-12 行附近的 home redirect：

```typescript
{
  path: '/',
  name: 'home',
  redirect: '/workbench',  // 旧值 /application
  children: [
    ...rolesRoutes,
    // ...
  ],
}
```

- [ ] **Step 4: 类型检查 + 构建 + dev 走查**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
npm run dev
```

访问根路径，预期：自动重定向到 `/workbench` 并显示占位页。

- [ ] **Step 5: Commit**

```bash
git add ui/src/router/routes.ts ui/src/router/modules/workbench.ts ui/src/views/workbench
git commit -m "feat(ui): add /workbench placeholder route and redirect root to it"
```

---

### Task 16: i18n 文案术语重命名（zh-CN / en-US / zh-Hant）

**Files:**
- Modify: `ui/src/locales/lang/zh-CN/layout.ts`、`zh-CN/views/index.ts` 及子文件
- Modify: `ui/src/locales/lang/en-US/layout.ts`、对应视图文件
- Modify: `ui/src/locales/lang/zh-Hant/layout.ts`、对应视图文件

- [ ] **Step 1: 在 layout.ts 中添加 rail 与 side 节点**

`ui/src/locales/lang/zh-CN/layout.ts` 文件 export default 内补充：

```typescript
rail: {
  aria: '主导航',
  workbench: '工作台',
  agent: '智能体',
  knowledge: '知识资产',
  capability: '能力扩展',
  platform: '平台管理',
},
side: {
  aria: '子菜单',
},
workbench: {
  placeholder: '工作台首页将在下一阶段实现。',
},
```

`ui/src/locales/lang/en-US/layout.ts` 同位置：

```typescript
rail: {
  aria: 'Primary navigation',
  workbench: 'Workbench',
  agent: 'Agents',
  knowledge: 'Knowledge',
  capability: 'Capabilities',
  platform: 'Platform',
},
side: {
  aria: 'Submenu',
},
workbench: {
  placeholder: 'Workbench home will be implemented in next phase.',
},
```

`ui/src/locales/lang/zh-Hant/layout.ts` 同位置：

```typescript
rail: {
  aria: '主導航',
  workbench: '工作臺',
  agent: '智能體',
  knowledge: '知識資產',
  capability: '能力擴展',
  platform: '平臺管理',
},
side: {
  aria: '子選單',
},
workbench: {
  placeholder: '工作臺首頁將在下一階段實現。',
},
```

- [ ] **Step 2: 重命名旧术语条目**

按 spec 第 5.3 节的术语清单，在各 locale 的 views/ 子目录文件里找 `value`（不是 key），按下列对应替换：

| 旧 value（zh-CN） | 新 value |
|------------------|---------|
| 智能应用 | 智能体 |
| 知识库 | 资料库 |
| 命中测试 | 检索调优 |
| 问题库 | 问题集 |
| 函数库 | 函数 |
| 触发器 | 自动化触发 |
| 系统设置 | 平台设置 |
| 资源管理 | 资源授权 |
| 应用工作流 | 高级编排 |

en-US 对应：

| 旧 value（en-US） | 新 value |
|------------------|---------|
| Application(s) | Agent(s) |
| Knowledge Base | Library |
| Hit Test | Retrieval Tuning |
| Problem(s) | FAQ Set |
| Function Library | Functions |
| Trigger(s) | Automation |
| System | Platform |
| Resource Management | Resource Access |
| Application Workflow | Advanced Orchestration |

zh-Hant 按 zh-CN 等值繁体替换。

具体操作 —— 对每个旧术语逐一定位文件：

```bash
# 中文术语扫描
for term in '智能应用' '知识库' '命中测试' '问题库' '函数库' '触发器' '系统设置' '资源管理' '应用工作流'; do
  echo "=== $term ==="
  git -C .. grep -ln -F "$term" -- ui/src/locales/lang/zh-CN ui/src/locales/lang/zh-Hant
done

# 英文术语扫描
for term in 'Application' 'Knowledge Base' 'Hit Test' 'Problem' 'Function Library' 'Trigger' 'Resource Management' 'Application Workflow'; do
  echo "=== $term ==="
  git -C .. grep -ln -F "$term" -- ui/src/locales/lang/en-US
done
```

逐文件改 value，**不动 key**。每个 value 仅在该 key 真正表示对应概念时替换；像 `'触发条件'` 这种相关但不同的词不动。

- [ ] **Step 3: 验证**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

```bash
git -C .. grep -c '智能应用' -- ui/src/locales/lang/zh-CN
```

Expected: 0（或仅剩注释中的旧术语）。

- [ ] **Step 4: dev server 走查**

切换语言为 zh-CN / en-US / zh-Hant 各一次，验证 Rail tooltip 和 Side 标题都显示新术语。

- [ ] **Step 5: Commit**

```bash
git add ui/src/locales
git commit -m "i18n(ui): rename product terms for de-fingerprinting"
```

---

### Task 17: P1+P2 联合走查 + 最终提交

**Files:**
- 全仓走查 / 视觉比对

- [ ] **Step 1: 全仓 MaxKB 字符串扫描**

```bash
git -C .. grep -i 'maxkb' -- ui 2>/dev/null
```

Expected: 零输出。**若仍有，回到 Task 5 / Task 6 补漏。**

```bash
git -C .. grep -i 'maxkb' -- . ':!LICENSE' ':!*.md' ':!docs/' 2>/dev/null
```

Expected: 仅剩 `LICENSE`（法律义务）。

- [ ] **Step 2: 类型门 + 编译门**

```bash
cd ui
npm run type-check
npm run build
```

Expected: 两者皆退出码 0。

- [ ] **Step 3: dev server 五路由走查**

```bash
npm run dev
```

依次访问，每个路由都要确认 Rail + Side + Main 渲染正常、无颜色错乱、无控制台 error：

| 路由 | 预期 |
|------|------|
| `/login` | 仍是 MaxKB 原版登录（不在本 plan 范围）但无渐变背景 |
| `/workbench` | 占位标题"工作台" + 说明文字 |
| `/application` | Rail 高亮"智能体"+ Side 显示应用相关菜单 + 应用列表 |
| `/knowledge` | Rail 高亮"知识资产" + Side 显示资料库菜单 |
| `/tool` | Rail 高亮"能力扩展" + Side 显示工具菜单 |
| `/model` | Rail 高亮"平台管理" + Side 显示模型菜单 |
| `/system/...` | Rail 高亮"平台管理" + Side 显示系统设置菜单 |

- [ ] **Step 4: 视觉抓图比对**

打开 `/application`，按 F12 → 设备工具栏 → 截图。与 spec 文档 6.2 节描述比对：
- Rail 64px 宽 + 深色背景 ✓
- Side 200px 宽 + 浅灰背景 ✓
- 无顶部水平 bar ✓

- [ ] **Step 5: 最终汇总 commit（如有零散改动未提交）**

```bash
git -C .. status
```

如有 untracked 或 modified：

```bash
git -C .. add -A ui/
git -C .. commit -m "chore(ui): final P1+P2 cleanup and walkthrough"
```

- [ ] **Step 6: 在 plan 文档底部勾选完成**

更新本 plan 文档（即本文件）底部加一行：

```markdown
## 完成记录

- 完成日期：YYYY-MM-DD
- 最终 commit：<sha>
- 验收：5 路由 + 3 语言全部通过 dev server 目测
- 已知遗留：Login 页（P3）/ 应用列表卡片样式（P4）/ 对话页（P5）/ 工作流（P6）尚未重做
```

```bash
git -C .. add docs/superpowers/plans/2026-05-21-frontend-redesign-p1-p2.md
git -C .. commit -m "docs: mark P1+P2 plan complete"
```

---

## 后续计划

P1+P2 完成后，按需起 plan 完成剩余 phase：

- `docs/superpowers/plans/2026-05-21-frontend-redesign-p3-p4.md`（P3 登录 + P4 工作台/列表）
- `docs/superpowers/plans/2026-05-21-frontend-redesign-p5-chat.md`（P5 对话页 + 移动端）
- `docs/superpowers/plans/2026-05-21-frontend-redesign-p6-p7.md`（P6 工作流 + P7 收尾）

每个 plan 独立可并行（合 P1+P2 后）。

---

## 完成记录

- **完成日期**：2026-05-22
- **分支**：`feat/frontend-redesign`
- **commit 链**：`1b365e107`（T1）… `ce4f6c993`（T17 最终清理）共 17 个 commit
- **自动门验收**：
  - `npm run type-check` 退出码 0
  - `npm run build` 编译通过（仅有预存在的 chunk-size 警告，与本改造无关）
  - `git grep -i 'maxkb' -- ui` 剩余仅 `variables.scss` 注释（设计意图说明，刻意保留）；`window.MaxKB` API 合约保留（spec 第 2 节明确要求）；`MaxKB-locale` localStorage key 保留（向后兼容）
- **本次范围与 plan 偏差**：
  - T5 清理 MaxKB 字符串：调研后发现项目内**无 hardcoded 用户可见 MaxKB 文案**（"MaxKB" 关键字几乎全为 `window.MaxKB.*` API 合约或 `MaxKB-locale` 存储 key，均不可改）。任务范围缩减为仅创建 `ui/src/utils/brand.ts` 占位常量模块，供后续 P3 登录页等使用。
  - T6 HTML 标题：HTML 文件已用 `%VITE_APP_TITLE%` 模板，真正源在 `ui/env/.env` 与 `ui/env/.env.chat`，改 env 即可。
  - T7 资产清理：`InsightHub.gif`、`tipIMG.jpg`、第三方平台 logo（钉钉/飞书/Slack/微信）保留 —— 前两者有真实引用、后者是接入合规标识。
  - T12 commit 内 ride-along 了 `.env.dev` 删除与 `.gitignore` 安全规则添加（用户/linter 在此前会话外的 intentional 改动），不是本任务引入但混入了同一 commit；技术状态正常无回归。
  - T14 SimpleLayout：经路由架构核查，SimpleLayout 是模块首页 wrapper（pages 内部已有自己的 folder-tree 子导航），不挂全局 Side，仅挂 Rail + Main，避免 3 列纳格。
  - T17 最终扫描发现 5 处 `https://maxkb.cn/pricing.html` 外链 + 1 处 `icon_robot.svg` 标题残留，已 patch（一并清掉）。

- **遗留事项（移交给 P3-P7）**：
  - 登录页仍是 MaxKB 居中卡片样式 → P3 重做
  - `/workbench` 是占位（仅标题+一行说明） → P4 填实
  - 应用列表卡片样式仍是旧风 → P4 重做
  - `/chat` 对话页与移动端 → P5
  - 工作流编辑器节点皮肤 → P6
  - 错误页、长尾视图视觉补漏 → P7

- **手动验收（请用户在合并前完成）**：
  - 启动 `npm run dev`
  - 登录后依次访问 `/`（应跳转到 `/workbench`） → `/application` → `/knowledge` → `/tool` → `/model` → `/system`
  - 每个路由确认：左侧 64px 暗色 Rail（5 个图标）出现 + Side（如有）紧贴 + 顶部水平 bar 完全消失
  - 切换 zh-CN / en-US / zh-Hant 三种语言，确认菜单标签随之变化为新术语
