# 前端重设计 P6+P7 实施计划 · 工作流编辑器 + 收尾

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 spec 的 Phase 6（LogicFlow 工作流编辑器换皮）与 Phase 7（错误页、长尾视图、最终走查）。本 plan 完成后，整个 spec 的 7 个 phase 全部落地。

**Architecture:** P6 用 CSS 变量 + `:deep()` 选择器覆盖 LogicFlow 默认外观，**不替换引擎**；节点 `<template>` 通过自定义视图组件挂载。P7 是清单式查漏补缺，包括错误页、settings 子页、404/500、字符串扫描清零、视觉走查。**前置依赖：必须先完成 P1+P2**。

**Tech Stack:** Vue 3 + Element Plus + LogicFlow 1.2.27 + SCSS + LucideIcon。

**Verification approach:** P6 用 dev server 打开三个 workflow 编辑器（application / knowledge / tool）目测；P7 用 `git grep -i maxkb` 清零 + 全路由清单走查。

---

## 任务总览（10 个 Task）

**P6 · 工作流编辑器**
1. 创建节点皮肤公共样式文件
2. 应用工作流（application-workflow）节点换皮
3. 知识库工作流（knowledge-workflow）节点换皮
4. 工具工作流（tool-workflow）节点换皮
5. LogicFlow 画布：网格底纹 + 连线样式
6. LogicFlow 工具栏 + 节点配置抽屉

**P7 · 收尾**
7. 错误页 404 / 500 / NoPermission 重做
8. settings 子页与长尾视图视觉补漏
9. 全仓字符串与素材最终扫描
10. P6+P7 全 plan 完工最终走查

---

## P6 · 工作流编辑器

### Task 1: 创建节点皮肤公共样式

**Files:**
- Create: `ui/src/styles/workflow.scss`
- Modify: `ui/src/styles/index.scss`（引入）

- [ ] **Step 1: 创建工作流公共样式**

写入 `ui/src/styles/workflow.scss`：

```scss
/**
 * LogicFlow 工作流统一皮肤。
 * 通过 CSS 变量 + 子选择器覆盖 LogicFlow 默认 DOM。
 *
 * 节点类型色（顶部 2px 色条）：
 *   - 触发 / 开始：绿
 *   - 数据 / 检索：蓝
 *   - AI / LLM：紫
 *   - 逻辑 / 分支：橙
 *   - 输出 / 终止：红
 */

:root {
  --wf-canvas-bg: var(--main-bg);
  --wf-grid-color: #f1f5f9;
  --wf-grid-size: 20px;

  --wf-node-bg: var(--main-bg);
  --wf-node-border: var(--border-base);
  --wf-node-text: var(--text-primary);
  --wf-node-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  --wf-node-hover-shadow: 0 4px 12px rgba(15, 23, 42, 0.08);
  --wf-node-radius: var(--radius-md);

  --wf-line-color: var(--text-primary);
  --wf-line-width: 1.5px;

  --wf-type-trigger: #10b981;
  --wf-type-data: #3b82f6;
  --wf-type-ai: #8b5cf6;
  --wf-type-logic: #f59e0b;
  --wf-type-output: #ef4444;
}

.wf-node {
  background: var(--wf-node-bg);
  border: 1px solid var(--wf-node-border);
  border-radius: var(--wf-node-radius);
  color: var(--wf-node-text);
  box-shadow: var(--wf-node-shadow);
  min-width: 140px;
  padding: 0;
  overflow: hidden;
  font-size: var(--font-size-base);
  transition:
    box-shadow 0.15s,
    border-color 0.15s;

  &:hover {
    box-shadow: var(--wf-node-hover-shadow);
  }
  &.is-selected {
    border-color: var(--brand-primary);
    box-shadow: 0 0 0 2px var(--brand-primary-soft);
  }

  &__type-bar {
    height: 2px;
    width: 100%;
  }
  &__inner {
    padding: 10px 12px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  &__icon {
    width: 16px;
    height: 16px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  &__title {
    font-weight: 500;
    color: var(--text-primary);
  }

  &[data-type='trigger'] .wf-node__type-bar { background: var(--wf-type-trigger); }
  &[data-type='data']    .wf-node__type-bar { background: var(--wf-type-data); }
  &[data-type='ai']      .wf-node__type-bar { background: var(--wf-type-ai); }
  &[data-type='logic']   .wf-node__type-bar { background: var(--wf-type-logic); }
  &[data-type='output']  .wf-node__type-bar { background: var(--wf-type-output); }
}

/* LogicFlow 画布与连线覆盖 */
.lf-canvas-overlay,
.lf-container {
  background-color: var(--wf-canvas-bg);
  background-image:
    linear-gradient(var(--wf-grid-color) 1px, transparent 1px),
    linear-gradient(90deg, var(--wf-grid-color) 1px, transparent 1px);
  background-size: var(--wf-grid-size) var(--wf-grid-size);
}

.lf-canvas-overlay path,
.lf-edge path {
  stroke: var(--wf-line-color);
  stroke-width: var(--wf-line-width);
  fill: none;
}
.lf-edge.is-selected path {
  stroke: var(--brand-primary);
}
```

- [ ] **Step 2: 引入到 index.scss**

修改 `ui/src/styles/index.scss`，新增一行：

```scss
@use './workflow.scss';
```

- [ ] **Step 3: 类型检查 + 编译**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/styles/workflow.scss ui/src/styles/index.scss
git commit -m "style(ui): add unified workflow skin (LogicFlow override)"
```

---

### Task 2: application-workflow 节点换皮

**Files:**
- Modify: `ui/src/views/application-workflow/component/`（节点视图组件）
- Modify: `ui/src/views/application-workflow/index.vue`

- [ ] **Step 1: 定位节点模板**

```bash
git -C .. grep -ln 'register\|h-vue\|HtmlNode\|VueNode' -- ui/src/views/application-workflow ui/src/workflow
ls ui/src/views/application-workflow/component/
ls ui/src/workflow 2>/dev/null
```

LogicFlow 节点通常通过 `register({ type, view, model })` 注册；查找 view 组件位置。

- [ ] **Step 2: 改写节点 view 渲染模板**

对每个节点 view 组件（如 `StartNode.vue`、`LLMNode.vue`、`SearchNode.vue` 等），将其根 `<div>` 改为：

```vue
<template>
  <div class="wf-node" :data-type="typeGroup" :class="{ 'is-selected': selected }">
    <span class="wf-node__type-bar" />
    <div class="wf-node__inner">
      <span class="wf-node__icon" :style="{ color: iconColor }">
        <LucideIcon :name="lucideName" :size="14" />
      </span>
      <span class="wf-node__title">{{ title }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { LucideIcon } from '@/components/lucide-icon'

const props = defineProps<{
  title: string
  selected?: boolean
  typeGroup: 'trigger' | 'data' | 'ai' | 'logic' | 'output'
  lucideName: string
}>()

const iconColor = computed(() => {
  const map = {
    trigger: 'var(--wf-type-trigger)',
    data: 'var(--wf-type-data)',
    ai: 'var(--wf-type-ai)',
    logic: 'var(--wf-type-logic)',
    output: 'var(--wf-type-output)',
  }
  return map[props.typeGroup]
})
</script>
```

> 实际操作：原节点组件已有大量 prop 与逻辑；**只改 `<template>` 与新增 `<style>` 中 wf- 类名**，不动 LogicFlow 注册逻辑。

- [ ] **Step 3: 节点类型映射表**

建立映射（按你项目实际节点类型补全）：

| 节点 type | typeGroup | lucideName |
|-----------|-----------|------------|
| `start` | trigger | `play` |
| `search` / `dataset` | data | `database` |
| `ai-chat` / `llm` | ai | `sparkles` |
| `condition` / `branch` | logic | `git-branch` |
| `reply` / `end` | output | `send` |
| `function` | data | `function-square` |
| `image` / `ocr` | data | `image` |

如有未列出的节点，按其语义就近归入五类。

- [ ] **Step 4: 删除节点旧 inline 样式**

清理节点 view 组件 `<style>` 中的：
- `linear-gradient(...)` 渐变背景
- `border-radius: 10px` 大圆角（继承自 wf-node 的 `var(--radius-md)` = 6px）
- 各色硬编码 hex

- [ ] **Step 5: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check && npm run dev
```

打开任一应用 → 高级编排页（`/application/<from>/<id>/workflow`），目测：
- 节点白底方角 + 顶部 2px 类型色条 ✓
- Lucide icon 显示 ✓
- 节点 hover 阴影变化 ✓

- [ ] **Step 6: Commit**

```bash
git add ui/src/views/application-workflow
git commit -m "refactor(ui): apply workflow skin to application workflow nodes"
```

---

### Task 3: knowledge-workflow 节点换皮

**Files:**
- Modify: `ui/src/views/knowledge-workflow/component/`

- [ ] **Step 1: 同 Task 2 流程**

```bash
ls ui/src/views/knowledge-workflow/component/
git -C .. grep -ln 'register\|view:' -- ui/src/views/knowledge-workflow
```

按 Task 2 的节点改写策略，对每个 view 组件改 `<template>` + 类型映射。

- [ ] **Step 2: 类型检查 + dev 走查**

进入任一资料库 → 索引流程编辑器，确认节点皮肤已应用。

- [ ] **Step 3: Commit**

```bash
git add ui/src/views/knowledge-workflow
git commit -m "refactor(ui): apply workflow skin to knowledge workflow nodes"
```

---

### Task 4: tool-workflow 节点换皮

**Files:**
- Modify: `ui/src/views/tool-workflow/component/`

- [ ] **Step 1: 同 Task 2 / 3 流程**

```bash
ls ui/src/views/tool-workflow/component/
```

- [ ] **Step 2: 类型检查 + dev 走查**

进入工具 → 函数编辑器，确认节点皮肤已应用。

- [ ] **Step 3: Commit**

```bash
git add ui/src/views/tool-workflow
git commit -m "refactor(ui): apply workflow skin to tool workflow nodes"
```

---

### Task 5: LogicFlow 画布 · 网格底纹 + 连线

**Files:**
- 通常无文件修改（Task 1 已通过 SCSS 全局覆盖了 `.lf-canvas-overlay` 与 `.lf-edge`）
- 仅校验

- [ ] **Step 1: 校验底纹与连线已生效**

打开 application-workflow 编辑器，预期：
- 画布底纹是 20×20 浅灰网格（不是圆点）
- 连线深色 1.5px

如未生效（LogicFlow 内部用 inline style 强覆盖），用 `:deep()` 在工作流页面级 `<style>` 加权重：

```scss
:deep(.lf-canvas-overlay) {
  background-image:
    linear-gradient(var(--wf-grid-color) 1px, transparent 1px),
    linear-gradient(90deg, var(--wf-grid-color) 1px, transparent 1px) !important;
}
```

- [ ] **Step 2: 检查 LogicFlow 版本相关 API**

```bash
npm ls @logicflow/core
```

记录版本（`1.2.27`），如未来升级 LogicFlow 需要回到本 task 检查选择器是否变更。

- [ ] **Step 3: Commit（如有补丁）**

```bash
git add ui/src/views/application-workflow ui/src/views/knowledge-workflow ui/src/views/tool-workflow
git commit -m "fix(ui): force workflow grid override via :deep() if needed"
```

如无修改则 skip commit。

---

### Task 6: LogicFlow 工具栏 + 节点配置抽屉

**Files:**
- Modify: 工作流页面顶部工具栏渲染处
- Modify: 节点配置弹窗 / 抽屉组件

- [ ] **Step 1: 工具栏改浮动吸顶居中**

定位工具栏（通常名 `Toolbar.vue` 或在 index.vue 内联）。修改其 wrapper 样式：

```scss
.wf-toolbar {
  position: absolute;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 10;
  background: var(--main-bg);
  border: 1px solid var(--border-base);
  border-radius: var(--radius-md);
  padding: 4px;
  display: flex;
  gap: 2px;
  box-shadow: var(--wf-node-shadow);

  button, .tool-item {
    width: 32px;
    height: 32px;
    border-radius: var(--radius-sm);
    background: transparent;
    border: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-secondary);
    cursor: pointer;

    &:hover { background: var(--side-bg); color: var(--text-primary); }
    &.is-active { background: var(--side-item-active-bg); color: var(--brand-primary); }
  }
}
```

- [ ] **Step 2: 节点配置面板从对话框改为右侧抽屉**

如当前用 `<el-dialog>` 显示节点配置，改为 `<el-drawer direction="rtl" size="420px">`：

```vue
<el-drawer
  v-model="configVisible"
  :title="currentNode?.title"
  direction="rtl"
  size="420px"
  :with-header="true"
>
  <component :is="currentConfigForm" v-bind="currentNode" />
</el-drawer>
```

如有多个节点类型对应不同表单组件，逻辑保留，仅外壳从 dialog 换为 drawer。

- [ ] **Step 3: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check && npm run dev
```

打开工作流编辑器，预期：
- 工具栏浮在画布顶部居中
- 点击节点后右侧抽屉弹出，宽 420px

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/application-workflow ui/src/views/knowledge-workflow ui/src/views/tool-workflow
git commit -m "refactor(ui): floating toolbar + right drawer for workflow config"
```

---

## P7 · 收尾

### Task 7: 错误页 404 / 500 / NoPermission

**Files:**
- Modify: `ui/src/views/error/404.vue`、`500.vue`（如存在）
- Modify: `ui/src/views/error/NoPermission.vue`
- 可能 Modify: `ui/src/assets/404.png`、`500.png`

- [ ] **Step 1: 读取现有错误页**

```bash
ls ui/src/views/error/
cat ui/src/views/error/NoPermission.vue 2>/dev/null | head -50
```

- [ ] **Step 2: 重写为极简单页**

每个错误页统一为以下模板（按错误码替换数字与文案）：

```vue
<template>
  <div class="error-page">
    <div class="error-page__code">404</div>
    <h1 class="error-page__title">{{ $t('error.notFound.title') }}</h1>
    <p class="error-page__hint">{{ $t('error.notFound.hint') }}</p>
    <el-button type="primary" @click="goHome">
      {{ $t('error.backHome') }}
    </el-button>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
const router = useRouter()
const goHome = () => router.push('/')
</script>

<style lang="scss" scoped>
.error-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: var(--main-bg);
  gap: 16px;
  color: var(--text-secondary);
}
.error-page__code {
  font-size: 96px;
  font-weight: 700;
  color: var(--brand-primary);
  letter-spacing: -0.04em;
  line-height: 1;
}
.error-page__title {
  font-size: var(--font-size-xl);
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}
.error-page__hint {
  font-size: var(--font-size-base);
  margin: 0 0 12px;
}
</style>
```

- [ ] **Step 3: 删除老 png（如新设计不用）**

```bash
git -C .. rm ui/src/assets/404.png ui/src/assets/500.png 2>/dev/null
```

如仍被某处 import 报错，回退此删除并改用 import + 灰度处理。

- [ ] **Step 4: i18n 文案**

`ui/src/locales/lang/zh-CN/...` 中补：

```typescript
error: {
  notFound: { title: '页面走丢了', hint: '你访问的页面不存在或已被移除。' },
  serverError: { title: '服务异常', hint: '请稍后重试。' },
  noPermission: { title: '无权访问', hint: '你的角色暂无该页面的权限。' },
  backHome: '返回首页',
},
```

en-US / zh-Hant 对应。

- [ ] **Step 5: dev 走查**

```bash
npm run dev
```

访问 `/no-permission`、不存在的路径 `/asdfgh` 验证 404，预期：极简灰色页 + 大号品牌色错误码 + 单按钮"返回首页"。

- [ ] **Step 6: Commit**

```bash
git add ui/src/views/error ui/src/locales ui/src/assets
git commit -m "refactor(ui): rebuild error pages (404/500/no-permission)"
```

---

### Task 8: settings 子页与长尾视图视觉补漏

**Files:**
- Walk through: `ui/src/views/system*/`、`ui/src/views/model/`、其它未触及视图

- [ ] **Step 1: 列出未走查的视图**

```bash
ls ui/src/views/
```

P1+P5 已覆盖：`login`、`workbench`、`application`、`application-workflow`、`knowledge-workflow`、`tool-workflow`、`chat`。

剩余视图：`application-overview`、`chat-log`、`chat-user`、`demo`、`document`、`hit-test`、`knowledge`、`model`、`paragraph`、`problem`、`system`、`system-chat-user`、`system-resource-management`、`system-setting`、`system-shared`、`tool`、`trigger`。

- [ ] **Step 2: 逐视图走查**

```bash
npm run dev
```

依次访问下列路由（按 `RAIL_MODULES` 与 sidebar 排序），每个路由查 3 个关键点：

| 视图 | 检查点 |
|------|--------|
| `/knowledge` | 卡片圆角 / 边框颜色 / 顶部按钮位置 |
| `/document` (任一资料库内) | 文档列表 row 高度 / 操作按钮 |
| `/paragraph` (任一文档内) | 段落卡片样式 / 分块视觉 |
| `/hit-test` | 测试输入框 + 结果列表样式 |
| `/problem` | 问题列表样式 |
| `/tool` | 工具列表卡片样式 |
| `/trigger` | 触发列表样式 |
| `/model` | 模型卡片样式 |
| `/system` 所有子页 | 表单 / Tab / 卡片 |
| `/chat-log` | 对话历史表格 |
| `/application-overview` | 应用概览仪表盘 |
| `/demo` | 如未删除，确认无 MaxKB 残留 |

- [ ] **Step 3: 局部修复**

每发现一处视觉违和（如硬编码 `border-radius: 16px`、渐变背景、MaxKB 风格色块），就近 patch 改用 Token 变量。**保持改动小而精**，不重写功能。

- [ ] **Step 4: 类型检查 + 构建**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

- [ ] **Step 5: Commit（如有修改）**

```bash
git add ui/src/views
git commit -m "refactor(ui): polish long-tail views to match new design tokens"
```

---

### Task 9: 全仓字符串与素材最终扫描

**Files:**
- 全仓扫描

- [ ] **Step 1: 字符串清零**

```bash
git -C .. grep -i 'maxkb' -- ui 2>/dev/null
```

Expected: **零输出**。如有残留，逐处替换为 `PRODUCT_NAME` / `productName`。

```bash
git -C .. grep -i 'maxkb' -- . ':!LICENSE' ':!*.md' ':!docs/' ':!.git/' 2>/dev/null
```

Expected: 仅 `LICENSE`（法律义务）保留。

- [ ] **Step 2: 素材扫描**

```bash
ls ui/src/assets/logo/
ls ui/public/
```

确认：
- `MaxKB-logo.svg` / `MaxKB-logo-currentColor.svg` 已删（P1 Task 7）
- `InsightHub.gif`、`tipIMG.jpg` 已删（P1 Task 7）
- `favicon.ico` 是占位或用户提供的新图标

- [ ] **Step 3: 第三方平台 logo 保留**

```bash
ls ui/src/assets/logo/ | grep -i 'dingtalk\|lark\|slack\|wechat'
```

Expected: 保留（接入对方平台的合规标识，不能换）。

- [ ] **Step 4: Commit（如有残留补 patch）**

```bash
git -C .. status
# 若有改动
git -C .. add -A ui/
git -C .. commit -m "chore(ui): final string and asset cleanup"
```

---

### Task 10: P6+P7 全 plan 完工最终走查

- [ ] **Step 1: 全门校验**

```bash
cd ui
npm run type-check
npm run build
```

Expected: 退出码 0。`dist/` 大小变化记录到 commit message（与 P1+P2 后对比，预期减少：移除大量旧 svg）。

- [ ] **Step 2: 30 秒辨认测试**

让一个熟悉 MaxKB 的同事（或自检视角换位思考）首次访问 dev 站点 30 秒，问：能立刻反应出"这是 MaxKB"吗？

- 若不能 → 验收准则 #1 通过
- 若能 → 询问其判断依据，回到对应 plan 补漏（最常见漏点：i18n 残留文案、保留的小图标、URL 末尾的 `/application` 等）

- [ ] **Step 3: 三屏宽抓图**

```bash
npm run dev
```

用 Chrome DevTools 切换 viewport：1280 / 1440 / 1920 各抓 `/workbench` / `/application` / `/chat/<token>` 三页，保存到本地（不入 git）。

- [ ] **Step 4: 三语言抽检**

切 en-US / zh-Hant，重访 `/workbench`、`/application`、`/login`，确认无中文残留、菜单标签翻译正确。

- [ ] **Step 5: 最终 commit**

```bash
git -C .. status
git -C .. add -A
git -C .. commit -m "chore(ui): complete frontend redesign (P1-P7)"
```

- [ ] **Step 6: 在所有 plan 文档底部标记完成**

依次：

```bash
# P1+P2
git -C .. add docs/superpowers/plans/2026-05-21-frontend-redesign-p1-p2.md
# P3+P4
git -C .. add docs/superpowers/plans/2026-05-21-frontend-redesign-p3-p4.md
# P5
git -C .. add docs/superpowers/plans/2026-05-21-frontend-redesign-p5-chat.md
# P6+P7
git -C .. add docs/superpowers/plans/2026-05-21-frontend-redesign-p6-p7.md
git -C .. commit -m "docs: mark all redesign plans complete"
```

- [ ] **Step 7: PR 准备**

```bash
git -C .. log --oneline release-2.9-simplify ^main | head -40
```

预期看到 P1-P7 全部 commit 列表。整理 PR 描述模板：

```markdown
## Summary
- 完成前端整体重设计，去 MaxKB 视觉与交互指纹
- 后端零改动；嵌入合约 (`/chat/:token`、postMessage) 保持兼容
- 见 `docs/superpowers/specs/2026-05-21-frontend-redesign-design.md`

## Test plan
- [ ] `npm run type-check` / `npm run build` 通过
- [ ] 桌面路由全量走查（`/workbench` / `/application` / `/knowledge` / `/tool` / `/model` / `/system` / `/login`）
- [ ] `/chat/:token` 桌面 + 移动端 + iframe 嵌入测试通过
- [ ] `embed-test.html` postMessage 与基线一致
- [ ] `git grep -i maxkb` 仅剩 LICENSE
- [ ] 30 秒辨认测试通过（陌生人无法立刻识别为 MaxKB 衍生）
```

---

## 完成记录（all phases）

- 完成日期：YYYY-MM-DD
- 最终 commit：<sha>
- 验收准则全部通过：✓
- 后端代码 git diff（`apps/`）：空
- 字符串清零（除 LICENSE）：✓
