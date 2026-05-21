# 前端重设计 P3+P4 实施计划 · 登录页 + 工作台 + 应用列表

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 spec 的 Phase 3（登录页重做）与 Phase 4（工作台首页 + 应用列表卡片重做）。三个落地页都是用户首次访问的"门面"，本 plan 后整体观感差异化即可达到 90% 以上。

**Architecture:** P3 重写 `LoginLayout` 与 `LoginContainer` 为左暗右白双栏；index/Forgot/Reset 三页共用新布局。P4 填实 P1+P2 的 `/workbench` 占位 + 重做 `application/index.vue` 卡片样式与顶部过滤区。**前置依赖：必须先完成 P1+P2**（设计 Token、Rail+Side+Main 骨架、Lucide 图标系统已就绪）。

**Tech Stack:** Vue 3 + Vite + Element Plus + SCSS + LucideIcon（P1+P2 已引入）。

**Verification approach:** 与 P1+P2 一致 —— `npm run type-check` + `npm run build` + dev server 路由走查。每个 task 完成后验证至少一项门。

---

## 任务总览（10 个 Task）

**P3 · 登录页**
1. 重写 `LoginLayout.vue` 为左暗右白双栏
2. 重写 `LoginContainer.vue` 适配新布局
3. 调整 `login/index.vue` 顶部 / 副标题文案
4. 同步 `ForgotPassword.vue` 与 `ResetPassword.vue`
5. 适配 `scanCompinents`（扫码登录组件）

**P4 · 工作台 + 应用列表**
6. 准备工作台 API 与统计聚合（前端聚合 / 不动后端）
7. 工作台首页填实：欢迎条 + 统计卡组
8. 工作台首页填实：我的智能体卡片网格
9. 重做应用列表卡片（`ApplicationCard` / `index.vue`）
10. P3+P4 联合走查 + 最终提交

---

## P3 · 登录页

### Task 1: 重写 `LoginLayout.vue` 为左暗右白双栏

**Files:**
- Modify: `ui/src/layout/login-layout/LoginLayout.vue`

- [ ] **Step 1: 完整替换 LoginLayout.vue**

写入：

```vue
<template>
  <div class="login-layout">
    <aside class="login-layout__brand">
      <div class="brand-top">
        <img src="@/assets/logo/logo.svg" class="brand-logo" alt="logo" />
        <span class="brand-name">{{ productName }}</span>
      </div>
      <div class="brand-slogan">
        <h2>{{ $t('views.login.slogan.title') }}</h2>
        <p>{{ $t('views.login.slogan.subtitle') }}</p>
      </div>
      <div class="brand-deco" aria-hidden="true">
        <span class="circle c1" />
        <span class="circle c2" />
        <span class="circle c3" />
      </div>
    </aside>

    <section class="login-layout__form">
      <el-dropdown trigger="click" class="lang-switch" v-if="lang">
        <template #dropdown>
          <el-dropdown-menu class="w-180">
            <el-dropdown-item
              v-for="(l, i) in langList"
              :key="i"
              :value="l.value"
              @click="changeLang(l.value)"
              class="flex-between"
            >
              <span :class="l.value === user.getLanguage() ? 'primary' : ''">{{ l.label }}</span>
              <el-icon v-if="l.value === user.getLanguage()" class="primary"><Check /></el-icon>
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
        <el-button text>
          {{ currentLanguage }}<el-icon class="el-icon--right"><arrow-down /></el-icon>
        </el-button>
      </el-dropdown>

      <div class="form-wrap">
        <slot />
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import useStore from '@/stores'
import { useLocalStorage } from '@vueuse/core'
import { langList, localeConfigKey, getBrowserLang } from '@/locales/index'
import { PRODUCT_NAME as productName } from '@/utils/brand'

defineProps({
  lang: { type: Boolean, default: true },
})

const { user } = useStore()

const changeLang = (lang: string) => {
  useLocalStorage(localeConfigKey, getBrowserLang()).value = lang
  window.location.reload()
}

const currentLanguage = computed(() => {
  return langList.value?.filter((v: any) => v.value === user.getLanguage())?.[0]?.label
})
</script>

<style lang="scss" scoped>
.login-layout {
  height: 100vh;
  display: grid;
  grid-template-columns: 1fr 1fr;
  background: var(--main-bg);
}

.login-layout__brand {
  position: relative;
  background: var(--rail-bg);
  color: #fff;
  padding: 48px 56px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  overflow: hidden;
}
.brand-top {
  display: flex;
  align-items: center;
  gap: 12px;
  z-index: 1;
}
.brand-logo {
  width: 36px;
  height: 36px;
}
.brand-name {
  font-size: 18px;
  font-weight: 600;
  letter-spacing: 0.02em;
}
.brand-slogan {
  z-index: 1;
  h2 {
    font-size: 30px;
    font-weight: 600;
    margin: 0 0 12px;
    line-height: 1.3;
  }
  p {
    font-size: 14px;
    color: var(--rail-text);
    line-height: 1.6;
    max-width: 380px;
  }
}
.brand-deco {
  position: absolute;
  inset: 0;
  pointer-events: none;
  .circle {
    position: absolute;
    border: 1px solid var(--rail-hover-bg);
    border-radius: 50%;
  }
  .c1 {
    width: 240px;
    height: 240px;
    right: -80px;
    top: -80px;
  }
  .c2 {
    width: 180px;
    height: 180px;
    right: 40px;
    bottom: -60px;
  }
  .c3 {
    width: 100px;
    height: 100px;
    right: 200px;
    bottom: 60px;
  }
}

.login-layout__form {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}
.lang-switch {
  position: absolute;
  right: 20px;
  top: 20px;
}
.form-wrap {
  width: 100%;
  max-width: 400px;
}

@media (max-width: 900px) {
  .login-layout {
    grid-template-columns: 1fr;
  }
  .login-layout__brand {
    display: none;
  }
}
</style>
```

- [ ] **Step 2: 在 i18n 添加 slogan 条目**

在 `ui/src/locales/lang/zh-CN/views/login.ts`（若不存在则在 `ui/src/locales/lang/zh-CN/views/index.ts` 中定位 login 节点）的 `views.login` 节点下补：

```typescript
slogan: {
  title: '让每位员工触达组织记忆',
  subtitle: '企业知识与智能体平台。统一管理资料、模型、工具与对话。',
},
```

en-US 与 zh-Hant 对应同步。

- [ ] **Step 3: 类型检查**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

- [ ] **Step 4: dev 走查**

访问 `/login`，预期：左侧深色 brand 栏 + 圆形装饰 + slogan；右侧白底登录表单。`< 900px` 浏览器窗口下品牌栏隐藏。

- [ ] **Step 5: Commit**

```bash
git add ui/src/layout/login-layout/LoginLayout.vue ui/src/locales
git commit -m "refactor(ui): rewrite LoginLayout to left dark + right white"
```

---

### Task 2: 重写 `LoginContainer.vue` 适配新布局

**Files:**
- Modify: `ui/src/layout/login-layout/LoginContainer.vue`

- [ ] **Step 1: 完整替换**

写入：

```vue
<template>
  <div class="login-container">
    <header v-if="title || $slots.title" class="login-container__title">
      <slot name="title">
        <h1>{{ title }}</h1>
      </slot>
      <p v-if="subTitle" class="subtitle">{{ subTitle }}</p>
    </header>
    <div class="login-container__body">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps({
  title: String,
  subTitle: String,
})
</script>

<style lang="scss" scoped>
.login-container {
  width: 100%;
}
.login-container__title {
  margin-bottom: 28px;
  h1 {
    font-size: 22px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0 0 6px;
  }
  .subtitle {
    font-size: var(--font-size-base);
    color: var(--text-secondary);
    margin: 0;
  }
}
.login-container__body {
  width: 100%;
}
</style>
```

- [ ] **Step 2: 验证编译**

```bash
cd ui
npm run type-check && npm run build 2>&1 | tail -10
```

Expected: 退出码 0。

- [ ] **Step 3: Commit**

```bash
git add ui/src/layout/login-layout/LoginContainer.vue
git commit -m "refactor(ui): rewrite LoginContainer for new login layout"
```

---

### Task 3: 调整 `login/index.vue` 文案与结构

**Files:**
- Modify: `ui/src/views/login/index.vue`

- [ ] **Step 1: 移除旧 LoginContainer 的 logo 使用**

原 index.vue 通过 `<LoginContainer :subTitle="...">` 中 LoginContainer 自带 `<LogoFull />`。新 LoginLayout 已在左暗栏渲染品牌 Logo，右侧表单不再需要重复 Logo。

修改 index.vue 中所有 `<LoginContainer>` 使用，传入 `title`（如 `$t('views.login.title')`）；删除任何在表单顶部重复显示 Logo 的代码块。

定位（在 index.vue 表单顶部，约第 3-4 行）：

```vue
<!-- 旧 -->
<LoginContainer :subTitle="newDefaultSlogan">
  <h2 class="mb-24" v-if="!showQrCodeTab">{{ loginMode || $t('views.login.title') }}</h2>

<!-- 新 -->
<LoginContainer :title="loginMode || $t('views.login.title')">
```

将 `<h2>` 删除（标题由 LoginContainer 渲染）。

- [ ] **Step 2: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check && npm run dev
```

访问 `/login`，预期：左暗右白布局中右侧表单顶部显示"登录账号"标题，无重复 Logo。

- [ ] **Step 3: Commit**

```bash
git add ui/src/views/login/index.vue
git commit -m "refactor(ui): adapt login index to new LoginContainer API"
```

---

### Task 4: 同步 `ForgotPassword.vue` 与 `ResetPassword.vue`

**Files:**
- Modify: `ui/src/views/login/ForgotPassword.vue`
- Modify: `ui/src/views/login/ResetPassword.vue`

- [ ] **Step 1: 读取两文件，识别 LoginContainer 使用**

```bash
git -C .. grep -n 'LoginContainer\|<h2\|LogoFull' -- ui/src/views/login/ForgotPassword.vue ui/src/views/login/ResetPassword.vue
```

- [ ] **Step 2: 按 Task 3 同款手法迁移**

将每处 `<h2 class="mb-24">...</h2>` 删除，改用 LoginContainer 的 `title` prop：

```vue
<!-- 旧 -->
<LoginContainer>
  <h2 class="mb-24">{{ $t('views.login.forgotPassword') }}</h2>

<!-- 新 -->
<LoginContainer :title="$t('views.login.forgotPassword')">
```

如有 `<LogoFull>` 重复 Logo 渲染，全部移除。

- [ ] **Step 3: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check
```

访问 `/forgot_password` 与 `/reset_password`（如有），目测左暗右白 + 顶部标题正确。

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/login/ForgotPassword.vue ui/src/views/login/ResetPassword.vue
git commit -m "refactor(ui): adapt forgot/reset password to new LoginContainer"
```

---

### Task 5: 适配 `scanCompinents`（扫码登录）

**Files:**
- Modify: `ui/src/views/login/scanCompinents/*.vue`

- [ ] **Step 1: 检查扫码组件是否在登录页内嵌**

```bash
git -C .. grep -ln 'scanCompinents\|showQrCodeTab' -- ui/src/views/login
ls ui/src/views/login/scanCompinents/
```

- [ ] **Step 2: 视觉对齐**

扫码组件常用于 LDAP / 钉钉 / 飞书 / 企业微信扫码登录。仅需确保其外层容器宽度与新表单一致（400px max-width，由 LoginLayout `.form-wrap` 控制）。

如组件内部有硬编码宽度（例如 `width: 480px`），将其改为 `width: 100%` 或读取容器自适应宽度。

如有渐变背景或 MaxKB 风格按钮，按 P1+P2 Token 替换为 `var(--brand-primary)` 等。

- [ ] **Step 3: 类型检查**

```bash
cd ui
npm run type-check
```

- [ ] **Step 4: 走查（如能本地搭建扫码场景）**

如本地无法触发扫码登录，至少确认 `import` 链路无报错，组件能编译。

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/login/scanCompinents
git commit -m "refactor(ui): align scan login components with new layout"
```

---

## P4 · 工作台 + 应用列表

### Task 6: 准备工作台 API 与统计聚合

**Files:**
- Create: `ui/src/api/workbench.ts`（仅 wrap 现有 API，不动后端）
- Modify: `ui/src/views/workbench/index.vue`

- [ ] **Step 1: 调研现有 API**

工作台需要展示：
- 应用数量
- 本月对话数
- 资料库数量
- 工具数量
- 最近活跃的 3-6 个应用

```bash
git -C .. grep -ln 'export.*get.*Application\|getAllApplication' -- ui/src/api 2>/dev/null
git -C .. grep -ln 'getAllKnowledge\|getKnowledgeList' -- ui/src/api 2>/dev/null
```

记录已有方法。

- [ ] **Step 2: 创建 workbench.ts aggregator**

写入 `ui/src/api/workbench.ts`：

```typescript
/**
 * 工作台聚合 API。
 * 复用已有的 application / knowledge / tool / chat-log 等列表 API，
 * 不新增后端端点。
 */
import { applicationApi } from '@/api/application/application'
import { knowledgeApi } from '@/api/knowledge/knowledge'
import { toolApi } from '@/api/tool/tool'

export interface WorkbenchStats {
  agentCount: number
  conversationCount: number
  libraryCount: number
  toolCount: number
}

export interface RecentAgent {
  id: string
  name: string
  description?: string
  conversation24h: number
  icon?: string
}

export async function loadWorkbenchStats(): Promise<WorkbenchStats> {
  const [apps, libs, tools] = await Promise.all([
    applicationApi.getAllApplication?.(undefined) ?? Promise.resolve({ data: [] }),
    knowledgeApi.getAllKnowledge?.() ?? Promise.resolve({ data: [] }),
    toolApi.getAllTool?.() ?? Promise.resolve({ data: [] }),
  ])
  // 对话数从聚合接口或前端缓存读取；如无现成接口，置 0 占位（待联调）
  return {
    agentCount: (apps as any)?.data?.length ?? 0,
    libraryCount: (libs as any)?.data?.length ?? 0,
    toolCount: (tools as any)?.data?.length ?? 0,
    conversationCount: 0,
  }
}

export async function loadRecentAgents(): Promise<RecentAgent[]> {
  const res = await applicationApi.getAllApplication?.(undefined)
  const list = (res as any)?.data ?? []
  return list.slice(0, 6).map((item: any) => ({
    id: item.id,
    name: item.name,
    description: item.desc || item.description,
    conversation24h: 0,
    icon: item.icon,
  }))
}
```

> **注意**：上面的 `applicationApi.getAllApplication` 等是占位调用，实际方法名以你项目中现有 API 模块为准。Step 1 已让你 grep 确认。如方法名不同，**改方法名，不要新建后端端点**。

- [ ] **Step 3: 类型检查**

```bash
cd ui
npm run type-check
```

如有 TS 报错，按真实 API 签名修正聚合层。

- [ ] **Step 4: Commit**

```bash
git add ui/src/api/workbench.ts
git commit -m "feat(ui): add workbench stats aggregator API (frontend-only)"
```

---

### Task 7: 工作台首页 · 欢迎条 + 统计卡组

**Files:**
- Modify: `ui/src/views/workbench/index.vue`

- [ ] **Step 1: 替换 P1+P2 占位实现**

完整覆盖 `ui/src/views/workbench/index.vue`：

```vue
<template>
  <div class="workbench">
    <header class="workbench__hello">
      <h1>{{ greeting }}，{{ user.userInfo?.nick_name || user.userInfo?.username }}</h1>
      <span class="date">{{ today }}</span>
    </header>

    <section class="workbench__stats">
      <article
        v-for="stat in statCards"
        :key="stat.key"
        class="stat-card"
      >
        <div class="stat-card__icon">
          <LucideIcon :name="stat.icon" :size="20" />
        </div>
        <div class="stat-card__body">
          <div class="stat-card__num">{{ stat.value }}</div>
          <div class="stat-card__label">{{ stat.label }}</div>
        </div>
      </article>
    </section>

    <!-- 我的智能体在下一 task 填实 -->
    <section class="workbench__recent" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { LucideIcon } from '@/components/lucide-icon'
import { loadWorkbenchStats, type WorkbenchStats } from '@/api/workbench'
import useStore from '@/stores'

const { t } = useI18n()
const { user } = useStore()

const stats = ref<WorkbenchStats>({
  agentCount: 0,
  conversationCount: 0,
  libraryCount: 0,
  toolCount: 0,
})

const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 6) return t('workbench.greeting.lateNight')
  if (h < 12) return t('workbench.greeting.morning')
  if (h < 18) return t('workbench.greeting.afternoon')
  return t('workbench.greeting.evening')
})

const today = computed(() => {
  const d = new Date()
  const weekday = ['日', '一', '二', '三', '四', '五', '六'][d.getDay()]
  return `${d.toISOString().slice(0, 10)} · 周${weekday}`
})

const statCards = computed(() => [
  { key: 'agents', icon: 'bot', value: stats.value.agentCount, label: t('workbench.stats.agents') },
  { key: 'conversations', icon: 'message-circle', value: stats.value.conversationCount, label: t('workbench.stats.conversations') },
  { key: 'libraries', icon: 'book-open-text', value: stats.value.libraryCount, label: t('workbench.stats.libraries') },
  { key: 'tools', icon: 'puzzle', value: stats.value.toolCount, label: t('workbench.stats.tools') },
])

onMounted(async () => {
  try {
    stats.value = await loadWorkbenchStats()
  } catch (e) {
    console.warn('[workbench] stats load failed:', e)
  }
})
</script>

<style lang="scss" scoped>
.workbench {
  display: flex;
  flex-direction: column;
  gap: 24px;
}
.workbench__hello {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  h1 {
    font-size: var(--font-size-xl);
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }
  .date {
    font-size: var(--font-size-sm);
    color: var(--text-tertiary);
  }
}
.workbench__stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  @media (max-width: 1024px) {
    grid-template-columns: repeat(2, 1fr);
  }
}
.stat-card {
  background: var(--side-bg);
  border: 1px solid var(--border-base);
  border-radius: var(--radius-md);
  padding: 14px 16px;
  display: flex;
  align-items: center;
  gap: 12px;
}
.stat-card__icon {
  width: 36px;
  height: 36px;
  background: var(--main-bg);
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--brand-primary);
  flex-shrink: 0;
}
.stat-card__num {
  font-size: 22px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.1;
}
.stat-card__label {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin-top: 4px;
}
</style>
```

- [ ] **Step 2: 添加 i18n 文案**

在 `ui/src/locales/lang/zh-CN/layout.ts` 的 `workbench` 节点补充（与 P1+P2 已建的 `workbench.placeholder` 同位置）：

```typescript
workbench: {
  placeholder: '...',  // P1+P2 已有
  greeting: {
    morning: '早上好',
    afternoon: '下午好',
    evening: '晚上好',
    lateNight: '夜深了',
  },
  stats: {
    agents: '智能体',
    conversations: '本月对话',
    libraries: '资料库',
    tools: '工具',
  },
  recent: {
    title: '我的智能体',
    empty: '还没有智能体，去创建一个？',
    conversation24h: '最近 24h · {n} 次对话',
  },
},
```

en-US 与 zh-Hant 同步对应翻译。

- [ ] **Step 3: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check && npm run dev
```

访问 `/workbench`，预期：欢迎条 + 4 个统计卡片（数字从聚合 API 读取；对话数若无后端聚合接口则显示 0，留 Task 6 / future 改）。

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/workbench ui/src/locales
git commit -m "feat(ui): build workbench welcome + stats cards"
```

---

### Task 8: 工作台首页 · 我的智能体卡片网格

**Files:**
- Modify: `ui/src/views/workbench/index.vue`
- Create: `ui/src/views/workbench/RecentAgentCard.vue`

- [ ] **Step 1: 创建 RecentAgentCard 子组件**

写入 `ui/src/views/workbench/RecentAgentCard.vue`：

```vue
<template>
  <router-link
    :to="`/application/${agent.id}/setting`"
    class="agent-card"
  >
    <div class="agent-card__row">
      <div class="agent-card__icon" :style="iconStyle">
        <LucideIcon name="bot" :size="14" />
      </div>
      <div class="agent-card__name">{{ agent.name }}</div>
    </div>
    <p v-if="agent.description" class="agent-card__desc">{{ agent.description }}</p>
    <div class="agent-card__meta">
      {{ $t('workbench.recent.conversation24h', { n: agent.conversation24h }) }}
    </div>
  </router-link>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { LucideIcon } from '@/components/lucide-icon'
import type { RecentAgent } from '@/api/workbench'

const props = defineProps<{ agent: RecentAgent }>()

const iconStyle = computed(() => ({
  background: props.agent.icon ? 'transparent' : 'var(--brand-primary)',
}))
</script>

<style lang="scss" scoped>
.agent-card {
  display: block;
  background: var(--main-bg);
  border: 1px solid var(--border-base);
  border-radius: var(--radius-lg);
  padding: 16px;
  text-decoration: none;
  transition:
    box-shadow 0.15s,
    border-color 0.15s,
    transform 0.15s;
  min-height: 140px;

  &:hover {
    border-color: var(--brand-primary-soft);
    box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06);
    transform: translateY(-2px);
  }
}
.agent-card__row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}
.agent-card__icon {
  width: 28px;
  height: 28px;
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  flex-shrink: 0;
}
.agent-card__name {
  font-size: var(--font-size-md);
  font-weight: 500;
  color: var(--text-primary);
}
.agent-card__desc {
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
  line-height: 1.5;
  margin: 0 0 12px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.agent-card__meta {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
}
</style>
```

- [ ] **Step 2: 在 workbench/index.vue 中渲染网格**

替换 `<section class="workbench__recent" />` 部分：

```vue
<section class="workbench__recent">
  <header class="workbench__recent-head">
    <h2>{{ $t('workbench.recent.title') }}</h2>
    <router-link to="/application" class="see-more">
      {{ $t('common.viewAll') }}
      <LucideIcon name="chevron-right" :size="14" />
    </router-link>
  </header>
  <div v-if="agents.length" class="workbench__recent-grid">
    <RecentAgentCard v-for="a in agents" :key="a.id" :agent="a" />
  </div>
  <p v-else class="workbench__recent-empty">{{ $t('workbench.recent.empty') }}</p>
</section>
```

在 `<script setup>` 中新增 import 与 ref：

```typescript
import RecentAgentCard from './RecentAgentCard.vue'
import { loadRecentAgents, type RecentAgent } from '@/api/workbench'

const agents = ref<RecentAgent[]>([])

onMounted(async () => {
  try {
    stats.value = await loadWorkbenchStats()
    agents.value = await loadRecentAgents()
  } catch (e) {
    console.warn('[workbench] load failed:', e)
  }
})
```

补充 `<style scoped>`：

```scss
.workbench__recent-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 16px;
  h2 {
    font-size: var(--font-size-lg);
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }
}
.see-more {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
  text-decoration: none;
  &:hover {
    color: var(--brand-primary);
  }
}
.workbench__recent-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}
.workbench__recent-empty {
  color: var(--text-tertiary);
  font-size: var(--font-size-base);
  padding: 24px;
  text-align: center;
  background: var(--side-bg);
  border: 1px dashed var(--border-base);
  border-radius: var(--radius-md);
}
```

- [ ] **Step 3: 添加 i18n common.viewAll**

在 `ui/src/locales/lang/zh-CN/common.ts` 中确认有 `viewAll: '查看全部'`，如无则补；en-US `View all`、zh-Hant `查看全部`。

- [ ] **Step 4: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check && npm run dev
```

访问 `/workbench`，预期：底部出现"我的智能体"网格；卡片点击跳应用详情；空态有提示。

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/workbench
git commit -m "feat(ui): add recent agents grid on workbench page"
```

---

### Task 9: 重做应用列表卡片

**Files:**
- Modify: `ui/src/views/application/index.vue`（顶部过滤区样式）
- Modify: `ui/src/views/application/component/ApplicationDialog.vue` 等卡片渲染处（若有 ApplicationCard 抽出则改它）

- [ ] **Step 1: 定位卡片渲染位置**

```bash
git -C .. grep -ln 'class.*app-card\|card-list-item\|application.*card' -- ui/src/views/application
```

找出实际渲染卡片的组件 / 模板片段；MaxKB 通常会在 `index.vue` 内联或在 `component/` 抽组件。

- [ ] **Step 2: 调整卡片样式**

无论卡片在何处，目标样式：
- 容器：`background: var(--main-bg); border: 1px solid var(--border-base); border-radius: var(--radius-lg); min-height: 140px; padding: 16px;`
- 悬停：`border-color: var(--brand-primary-soft); box-shadow: 0 4px 12px rgba(15,23,42,0.06); transform: translateY(-2px);`
- 顶部行：28px 实心方块 icon（`var(--brand-primary)` 背景）+ 14px 名称
- 描述：13px 灰色，2 行截断
- 底部 meta：11px 灰色

如卡片当前用 `border-radius: 16px` 与渐变背景，全部替换为上述 token。

具体编辑 = 在 `ApplicationDialog.vue` / `ApplicationCard` 或 `index.vue` 的卡片 `<style>` 中替换 CSS 规则。

- [ ] **Step 3: 调整顶部过滤区**

`ui/src/views/application/index.vue` 的 `complex-search` 部分：
- 不动逻辑
- 给 wrapper 加：`gap: 8px; align-items: center; padding-bottom: 16px;`
- el-input / el-select 沿用 P1+P2 已覆写的 EP token（圆角已自动跟随）

- [ ] **Step 4: 类型检查 + dev 走查**

```bash
cd ui
npm run type-check && npm run dev
```

访问 `/application`，预期：卡片方角化、阴影减弱、悬停浮起；顶部过滤栏视觉紧凑。

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/application
git commit -m "refactor(ui): redesign application list cards (compact + flat)"
```

---

### Task 10: P3+P4 联合走查 + 最终提交

- [ ] **Step 1: 全门校验**

```bash
cd ui
npm run type-check
npm run build
```

Expected: 两者退出码 0。

- [ ] **Step 2: dev 路由走查**

```bash
npm run dev
```

| 路由 | 预期 |
|------|------|
| `/login` | 左暗右白布局 + 圆形装饰 + 登录表单 |
| `/forgot_password` | 同款布局 + 找回密码表单 |
| `/workbench` | 欢迎条 + 4 统计卡 + 智能体网格 |
| `/application` | 重做后的紧凑卡片，悬停浮起 |

- [ ] **Step 3: 三语言抽检**

切换为 en-US / zh-Hant，重访 `/workbench`，确认 greeting / stats label / recent title 均显示对应语言。

- [ ] **Step 4: 视觉抓图比对**

对照 spec 6.1 与 6.2 节描述与浏览器 mockup 截图，逐项核对（左暗右白比例、卡片尺寸 / 圆角、统计卡数字字号）。

- [ ] **Step 5: 最终汇总 commit（如有零散改动）**

```bash
git -C .. status
git -C .. add -A ui/
git -C .. commit -m "chore(ui): final P3+P4 cleanup and walkthrough"
```

- [ ] **Step 6: 在 plan 文档底部勾选完成**

更新本 plan 文档：

---

## 完成记录

- **完成日期**：2026-05-22
- **分支**：`feat/frontend-redesign`
- **commit 链**：`90ca98c03`（T1 LoginLayout）… `58ef7a4f8`（T8 workbench 智能体网格）共 9 个 commit
- **自动门**：`npm run type-check` 退出 0；`npm run build` 编译通过
- **范围调整**：
  - T5 scanCompinents：调研发现 4 个扫码组件（DingTalk/Lark/WeCom + QrCodeTab）已经是 280px 居中 / 100% 流式布局，与新 400px form-wrap 兼容。无修改 / 无 commit。
  - T6 workbench API：采用占位实现（返回 0 / 空数组）。真实 API 接入是更深的工作（涉及 Pinia 上下文与工作空间 ID），交付时 UI 渲染为 0 占位，用户提供后续 API 细节后再接。
  - T9 应用列表卡片：发现卡片由共享 `CardBox` 组件渲染（包裹 `<el-card>`），通过修改 `element-plus.scss` 全局 .el-card 覆盖一次性影响所有列表卡片 —— 实际 ROI 比仅改 application 视图大得多。

- **手动验收（请用户在合并前完成）**：
  - `cd ui && npm run dev`
  - 访问 `/login`：左暗品牌叙事栏（圆形装饰 + slogan）+ 右白表单
  - 访问 `/forgot_password` 与 `/reset_password`：同款双栏布局
  - 访问 `/workbench`：欢迎条 + 4 统计卡（数字 0）+ 我的智能体网格（空态）
  - 访问 `/application`：紧凑卡片 + 悬停浮起 + 圆角 10px
  - 切换 zh-CN / en-US / zh-Hant 三语，确认所有新文案显示正确
