# 前端重设计 P5 实施计划 · 对话页 /chat + 移动端

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 spec 的 Phase 5。重做对话页 `/chat` 的桌面与移动端视觉；URL `/chat/:accessToken`、`/user-login/:accessToken` 与 postMessage 嵌入协议**严格保持不变**；这是本次重设计中曝光率最高、风险最高的一块。

**Architecture:** 项目已将 chat 拆为 `pc/` + `mobile/` + `embed/` 三套独立模板，由 `views/chat/index.vue` 根据 `query.mode` 与 `common.isMobile()` 动态加载。本 plan 在不动这个分发机制的前提下分别重写 pc 与 mobile 模板的视觉层。**前置依赖：必须先完成 P1+P2**（设计 Token 与 LucideIcon 就绪）。

**Tech Stack:** Vue 3 + Element Plus + SCSS + LucideIcon + 现有 chat 状态管理（`stores/modules/chatUser`、`bus/`）。

**Verification approach:** `type-check` + `build` + dev server 嵌入测试页验证。嵌入兼容性是硬要求：需准备一个本地 HTML 嵌入页验证 postMessage 与 URL 不变。

---

## 任务总览（9 个 Task）

1. 准备本地嵌入测试页（用于验证 postMessage 不破坏）
2. 重做 pc 对话页 · 顶部标题栏
3. 重做 pc 对话页 · 消息流（AI / 用户气泡）
4. 重做 pc 对话页 · 输入框
5. 重做 pc 对话页 · 历史会话抽屉（左侧）
6. 重做 mobile 对话页 · 整体响应式布局
7. 重做 mobile 对话页 · 触摸交互细节
8. 嵌入合约自测（postMessage / URL / iframe）
9. P5 联合走查 + 最终提交

---

### Task 1: 准备本地嵌入测试页

**Files:**
- Create: `ui/public/embed-test.html`（仅本地开发用，不发布）

- [ ] **Step 1: 找到 embed 脚本入口与 postMessage 协议**

```bash
git -C .. grep -ln 'postMessage\|window.addEventListener.*message' -- ui/src/views/chat
git -C .. grep -ln 'embed.*js\|chat.*embed\|window\.MaxKB\|window\.product' -- ui
```

记录：
- embed 脚本路径（如 `ui/chat.html` build 后位置 或 `chat.ts` 入口）
- postMessage 事件名（如 `setAccessToken`、`switchSession`）
- window 注入对象名（如 `window.ChatBot`、`window.kbembed`）

- [ ] **Step 2: 编写 embed-test.html**

写入 `ui/public/embed-test.html`：

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <title>Embed Test Page</title>
  <style>
    body { font-family: sans-serif; padding: 24px; }
    iframe { width: 420px; height: 640px; border: 1px solid #e5e7eb; border-radius: 6px; }
    .log { background: #f8fafc; padding: 12px; font-family: monospace; font-size: 12px; max-height: 200px; overflow: auto; }
  </style>
</head>
<body>
  <h1>对话嵌入兼容测试</h1>
  <p>本页用于验证 P5 改造前后 postMessage 协议、URL、iframe 加载行为完全一致。</p>
  <iframe id="chat" src="/chat/test-access-token?mode=pc"></iframe>
  <h3>postMessage 监听日志</h3>
  <div id="log" class="log"></div>
  <script>
    const log = document.getElementById('log')
    window.addEventListener('message', (e) => {
      const line = `${new Date().toISOString().slice(11, 19)}  ${JSON.stringify(e.data)}`
      log.innerHTML += line + '<br>'
      log.scrollTop = log.scrollHeight
    })
  </script>
</body>
</html>
```

- [ ] **Step 3: 启动 dev 并打开测试页（基线录像）**

```bash
cd ui
npm run dev
# 浏览器打开 http://localhost:5173/embed-test.html
```

把当前的 postMessage 日志截图保存到本地（不入 git）作为基线。任何后续改动如出现日志格式变化、缺失事件，回滚到此基线。

> 如 dev 起不来的 `test-access-token` 是无效 token，将 `iframe.src` 改为你 dev 环境中一个有效的 token，或临时塞一个测试应用的真实 token。

- [ ] **Step 4: Commit 测试页**

```bash
git add ui/public/embed-test.html
git commit -m "test(ui): add chat embed test page for postMessage parity check"
```

---

### Task 2: pc 对话页 · 顶部标题栏

**Files:**
- Modify: `ui/src/views/chat/pc/index.vue`（标题栏部分）
- Modify 或 Create: `ui/src/views/chat/pc/Header.vue`（如内联则抽出）

- [ ] **Step 1: 读取 pc/index.vue 当前结构**

```bash
git -C .. grep -n 'header\|app-bar\|chat-title' -- ui/src/views/chat/pc/index.vue
cat ui/src/views/chat/pc/index.vue | head -80
```

定位顶部标题渲染位置。

- [ ] **Step 2: 抽出 / 重写 Header 子组件**

如未抽出，新建 `ui/src/views/chat/pc/Header.vue`：

```vue
<template>
  <header class="chat-pc-header">
    <div class="chat-pc-header__left">
      <button class="icon-btn" @click="$emit('open-history')" :aria-label="$t('chat.history')">
        <LucideIcon name="menu" :size="18" />
      </button>
      <div class="agent">
        <div class="agent__avatar">
          <img v-if="avatar" :src="avatar" alt="" />
          <LucideIcon v-else name="bot" :size="16" />
        </div>
        <div class="agent__meta">
          <div class="agent__name">{{ name }}</div>
          <div class="agent__status">
            <span class="dot" />
            {{ $t('chat.online') }}
          </div>
        </div>
      </div>
    </div>
    <div class="chat-pc-header__right">
      <button class="icon-btn" @click="$emit('new-conversation')" :aria-label="$t('chat.newChat')">
        <LucideIcon name="square-pen" :size="16" />
      </button>
      <button class="icon-btn" @click="$emit('open-settings')" :aria-label="$t('chat.settings')">
        <LucideIcon name="more-horizontal" :size="16" />
      </button>
    </div>
  </header>
</template>

<script setup lang="ts">
import { LucideIcon } from '@/components/lucide-icon'

defineProps<{ name: string; avatar?: string }>()
defineEmits<{
  (e: 'open-history'): void
  (e: 'new-conversation'): void
  (e: 'open-settings'): void
}>()
</script>

<style lang="scss" scoped>
.chat-pc-header {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  background: var(--main-bg);
  border-bottom: 1px solid var(--border-base);
  flex-shrink: 0;
}
.chat-pc-header__left {
  display: flex;
  align-items: center;
  gap: 12px;
}
.agent {
  display: flex;
  align-items: center;
  gap: 10px;
}
.agent__avatar {
  width: 28px;
  height: 28px;
  border-radius: var(--radius-sm);
  background: var(--brand-primary);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}
.agent__name {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.2;
}
.agent__status {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  margin-top: 2px;
  .dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--status-success-text);
  }
}
.icon-btn {
  background: transparent;
  border: 0;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  cursor: pointer;
  &:hover {
    background: var(--side-bg);
    color: var(--text-primary);
  }
}
.chat-pc-header__right {
  display: flex;
  gap: 4px;
}
</style>
```

- [ ] **Step 3: 在 pc/index.vue 中引用 Header**

将原 `<header>` 或顶部 bar 替换为：

```vue
<Header
  :name="application?.name"
  :avatar="application?.icon"
  @open-history="historyDrawer = true"
  @new-conversation="createNewChat"
  @open-settings="settingsDialog = true"
/>
```

并 `import Header from './Header.vue'`。`createNewChat` 等方法**必须复用原本存在的方法**，不要重命名。

- [ ] **Step 4: i18n 补充**

`ui/src/locales/lang/zh-CN/views/ai-chat.ts` 或对应 i18n 文件中 `chat` 节点补：

```typescript
chat: {
  online: '在线',
  history: '历史会话',
  newChat: '新对话',
  settings: '设置',
  ...其它已有
},
```

en-US / zh-Hant 对应。

- [ ] **Step 5: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check && npm run dev
```

访问 dev 环境的有效 `/chat/:accessToken`，预期：顶部 56px 标题栏，左侧菜单+头像+智能体名+在线状态；右侧两个操作按钮。

- [ ] **Step 6: Commit**

```bash
git add ui/src/views/chat/pc ui/src/locales
git commit -m "refactor(ui): rebuild chat pc header with agent avatar + status"
```

---

### Task 3: pc 对话页 · 消息流（AI / 用户气泡）

**Files:**
- Modify: `ui/src/views/chat/component/`（消息渲染组件，通常名为 `MessageList`、`ChatMessage` 或类似）

- [ ] **Step 1: 定位消息渲染组件**

```bash
git -C .. grep -ln 'role.*user\|role.*ai\|class.*ai-message\|user-message' -- ui/src/views/chat
```

通常会在 `chat/component/` 下找到 `MessageItem.vue` 或类似。

- [ ] **Step 2: 重写 AI 消息样式**

定位 AI 消息 wrapper 的 `<style>`，将原有的渐变 / 圆角胶囊背景全部替换为：

```scss
.ai-message {
  display: flex;
  gap: 12px;
  padding: 16px 0;
  align-items: flex-start;

  &__avatar {
    width: 28px;
    height: 28px;
    border-radius: var(--radius-sm);
    background: var(--side-bg);
    color: var(--brand-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    overflow: hidden;
    img { width: 100%; height: 100%; object-fit: cover; }
  }
  &__body {
    flex: 1;
    min-width: 0;
    color: var(--text-primary);
    font-size: var(--font-size-md);
    line-height: 1.7;
  }
  &__meta {
    margin-top: 8px;
    font-size: var(--font-size-xs);
    color: var(--text-tertiary);
    display: flex;
    gap: 12px;
  }
}
```

- [ ] **Step 3: 重写 用户消息 样式**

```scss
.user-message {
  display: flex;
  justify-content: flex-end;
  padding: 8px 0;

  &__bubble {
    max-width: 75%;
    background: var(--brand-primary);
    color: #fff;
    padding: 10px 14px;
    border-radius: var(--radius-md);
    font-size: var(--font-size-md);
    line-height: 1.6;
    word-break: break-word;
  }
}
```

- [ ] **Step 4: 删除全局渐变变量引用**

```bash
git -C .. grep -n '\-\-dialog-bg-gradient-color\|linear-gradient' -- ui/src/views/chat
```

将所有 `linear-gradient(...)` 与渐变变量删除或替换为纯色 token。

- [ ] **Step 5: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check && npm run dev
```

发送一条对话，预期：AI 消息无底色 + 左侧头像 + 灰色 meta；用户消息深色填充 + 右对齐。

- [ ] **Step 6: Commit**

```bash
git add ui/src/views/chat
git commit -m "refactor(ui): rebuild chat message bubbles (flat + minimal)"
```

---

### Task 4: pc 对话页 · 输入框

**Files:**
- Modify: `ui/src/views/chat/component/`（输入框组件，通常 `ChatInput.vue` 或类似）

- [ ] **Step 1: 定位**

```bash
git -C .. grep -ln 'sendMessage\|chat-input\|textarea.*v-model.*message' -- ui/src/views/chat
```

- [ ] **Step 2: 重写输入框容器样式**

```scss
.chat-input {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  padding: 12px 16px;
  background: var(--main-bg);
  border-top: 1px solid var(--border-base);

  &__field {
    flex: 1;
    background: var(--main-bg);
    border: 1px solid var(--border-base);
    border-radius: var(--radius-md);
    padding: 10px 14px;
    min-height: 40px;
    max-height: 200px;
    font-size: var(--font-size-md);
    line-height: 1.5;
    color: var(--text-primary);
    resize: none;
    outline: none;

    &:focus {
      border-color: var(--brand-primary);
    }
  }
  &__send {
    width: 40px;
    height: 40px;
    border: 0;
    background: var(--brand-primary);
    color: #fff;
    border-radius: var(--radius-md);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    flex-shrink: 0;

    &:hover { background: var(--brand-primary-hover); }
    &:disabled { background: var(--text-tertiary); cursor: not-allowed; }
  }
}
```

- [ ] **Step 3: 将发送按钮文字改为 lucide arrow-up**

```vue
<button class="chat-input__send" @click="send" :disabled="!canSend">
  <LucideIcon name="arrow-up" :size="18" />
</button>
```

- [ ] **Step 4: 类型检查 + dev 走查**

输入区右下角发送按钮为方块圆角 + 箭头图标；输入框聚焦时边框为品牌色。

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/chat
git commit -m "refactor(ui): rebuild chat input box (compact + arrow icon)"
```

---

### Task 5: pc 对话页 · 历史会话抽屉（左侧）

**Files:**
- Modify: 历史会话相关组件（通常名 `HistoryDrawer.vue` 或 `SessionList.vue`）

- [ ] **Step 1: 定位**

```bash
git -C .. grep -ln 'el-drawer\|history.*drawer\|sessionList' -- ui/src/views/chat
```

- [ ] **Step 2: 将抽屉方向改为左侧**

找到 `<el-drawer>` 使用，将 `direction="rtl"` 改为 `direction="ltr"`；如未使用 el-drawer 而是自实现的滑出层，将 `right: 0; transform-origin: right` 改为 `left: 0; transform-origin: left`，并把 `translateX(100%)` 改为 `translateX(-100%)`。

- [ ] **Step 3: 重写抽屉内容样式**

抽屉宽度 320px；标题"历史会话"14px 加粗；列表项 36px 高、6px 圆角、悬停浅灰背景。

```scss
.history-drawer {
  &__title {
    font-size: var(--font-size-md);
    font-weight: 600;
    color: var(--text-primary);
    padding: 16px;
    border-bottom: 1px solid var(--border-base);
  }
  &__list {
    padding: 8px;
  }
  &__item {
    height: 36px;
    line-height: 36px;
    padding: 0 12px;
    border-radius: var(--radius-sm);
    font-size: var(--font-size-base);
    color: var(--text-secondary);
    cursor: pointer;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;

    &:hover { background: var(--side-bg); color: var(--text-primary); }
    &.is-active { background: var(--side-item-active-bg); color: var(--text-primary); font-weight: 500; }
  }
}
```

- [ ] **Step 4: 验证打开抽屉方向正确（从左侧滑入）**

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/chat
git commit -m "refactor(ui): move chat history to left drawer with new styles"
```

---

### Task 6: mobile 对话页 · 整体响应式布局

**Files:**
- Modify: `ui/src/views/chat/mobile/index.vue` 及其 `component/`

- [ ] **Step 1: 读取 mobile/index.vue 结构**

```bash
cat ui/src/views/chat/mobile/index.vue | head -80
ls ui/src/views/chat/mobile/component/
```

- [ ] **Step 2: 重做整体容器**

修改 mobile 顶层 `<style>` 或 wrapper：

```scss
.chat-mobile {
  display: flex;
  flex-direction: column;
  height: 100vh;
  height: 100dvh; /* iOS Safari URL bar 自适应 */
  background: var(--main-bg);
}
.chat-mobile__header {
  position: sticky;
  top: 0;
  z-index: 10;
  height: 52px;
  background: var(--main-bg);
  border-bottom: 1px solid var(--border-base);
  display: flex;
  align-items: center;
  padding: 0 12px;
  gap: 8px;
}
.chat-mobile__body {
  flex: 1;
  overflow-y: auto;
  padding: 12px 16px;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior: contain;
}
.chat-mobile__footer {
  position: sticky;
  bottom: 0;
  background: var(--main-bg);
  border-top: 1px solid var(--border-base);
  padding: 8px 12px;
  padding-bottom: max(8px, env(safe-area-inset-bottom));
}
```

- [ ] **Step 3: 复用 pc 的消息组件样式**

pc 重做的消息气泡 CSS 是按 `var(--font-size-md)` 等 token 写的，在 mobile 下自动 OK。如 mobile 组件原来是单独的 message 组件，确保它也读同款 token。

- [ ] **Step 4: 移动端字号 / padding 微调**

```scss
@media (max-width: 480px) {
  .ai-message {
    padding: 12px 0;
    &__body { font-size: var(--font-size-base); }
  }
  .user-message__bubble {
    max-width: 85%;
    font-size: var(--font-size-base);
  }
}
```

- [ ] **Step 5: dev 走查（用 Chrome DevTools 设备模拟）**

切到 iPhone 13 (390×844)，预期：标题吸顶、消息可滚动、输入框吸底、安全区不重叠。

- [ ] **Step 6: Commit**

```bash
git add ui/src/views/chat/mobile
git commit -m "refactor(ui): mobile chat layout (sticky header/footer + safe-area)"
```

---

### Task 7: mobile 对话页 · 触摸交互细节

**Files:**
- Modify: `ui/src/views/chat/mobile/index.vue` 及子组件

- [ ] **Step 1: 输入框聚焦时不顶起 viewport**

在 mobile textarea 上添加：

```html
<textarea
  v-model="input"
  enterkeyhint="send"
  autocomplete="off"
  autocorrect="off"
  autocapitalize="off"
  spellcheck="false"
  inputmode="text"
/>
```

并确保 mobile footer 用 `position: sticky` 而非 `fixed`（前者跟随键盘弹起；后者会被遮挡）。

- [ ] **Step 2: 历史抽屉用全屏从左滑入**

mobile 下抽屉的 width 改为 `min(85vw, 320px)`；遮罩点击关闭；ESC 键关闭。

- [ ] **Step 3: 长消息超出屏幕时支持双指放大图片 / 表格**

定位消息渲染中图片 / 表格元素，确保它们的 wrapper 是 `overflow-x: auto` 而非 `overflow: hidden`，让用户可横向滚动查看长内容。

- [ ] **Step 4: dev + 真机或模拟器走查**

iOS Safari 模拟器 / Android Chrome DevTools 模拟，发送消息、长按文本（无系统右键菜单干扰）、横向滑表格、键盘弹起后输入框不被遮挡。

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/chat/mobile
git commit -m "refactor(ui): polish mobile chat touch interactions"
```

---

### Task 8: 嵌入合约自测（postMessage / URL / iframe）

**Files:**
- 无文件修改，仅测试

- [ ] **Step 1: 与 Task 1 基线日志逐项比对**

启动 dev：

```bash
npm run dev
```

打开 `http://localhost:5173/embed-test.html`，触发对话；逐项检查右侧 postMessage 日志：

| 事件名 | P1 基线 | P5 实际 | 一致 |
|--------|---------|---------|------|
| （如 `kbembed:ready`） | ✓ | ?    | ?    |
| （如 `kbembed:message`） | ✓ | ?    | ?    |

如出现新增的事件、缺失的事件、或字段名变化（如 `accessToken` → `token`），**回退该 task 并查明原因**。这是硬约束。

- [ ] **Step 2: 切换 iframe URL 形态测试**

修改 `embed-test.html` 中 iframe `src`：
- `/chat/:token`（默认 pc）
- `/chat/:token?mode=pc`
- `/chat/:token?mode=mobile`
- `/chat/:token?mode=embed`

每种模式都重新发消息一次，确保仍能渲染。

- [ ] **Step 3: 测试 user-login 流**

iframe 加载 `/user-login/test-token`，验证登录流程未破坏。

- [ ] **Step 4: 记录测试结果**

新建 `docs/superpowers/notes/p5-embed-compat-2026-XX-XX.md`，记录测试结果与截图。如有问题，列出待修。

- [ ] **Step 5: Commit 测试记录**

```bash
git add docs/superpowers/notes
git commit -m "test(ui): record P5 embed compatibility verification"
```

---

### Task 9: P5 联合走查 + 最终提交

- [ ] **Step 1: 全门校验**

```bash
cd ui
npm run type-check
npm run build
```

Expected: 退出码 0。

- [ ] **Step 2: 关键路由走查**

```bash
npm run dev
```

| 路由 | 桌面预期 | 移动预期 (iPhone 13) |
|------|---------|---------------------|
| `/chat/:token` | 标题栏 + 历史按钮 + AI 平消息 + 输入框带箭头 | sticky 顶 + 满屏消息 + sticky 底 |
| `/chat/:token?mode=mobile` | 强制移动模板 | 同上 |
| `/chat/:token?mode=embed` | iframe 嵌入模板 | 同上 |
| `/embed-test.html` | iframe 渲染 + postMessage 日志可见 | — |

- [ ] **Step 3: 视觉抓图与 spec 6.3 节比对**

对照 spec 6.3 的设计描述与浏览器 mockup，逐项核对：
- AI 消息无气泡背景 ✓
- 用户消息深色填充 ✓
- 发送按钮单箭头 ✓
- 历史在左侧 ✓

- [ ] **Step 4: 最终汇总 commit**

```bash
git -C .. status
git -C .. add -A ui/
git -C .. commit -m "chore(ui): final P5 chat redesign walkthrough"
```

- [ ] **Step 5: 在 plan 文档底部勾选完成**

```markdown
## 完成记录

- 完成日期：YYYY-MM-DD
- 最终 commit：<sha>
- 嵌入合约验证：postMessage 事件名 / 字段对齐基线 ✓
- 桌面 + 移动 (iPhone 13 / Pixel 7) dev 走查通过
```

```bash
git -C .. add docs/superpowers/plans/2026-05-21-frontend-redesign-p5-chat.md
git -C .. commit -m "docs: mark P5 plan complete"
```
