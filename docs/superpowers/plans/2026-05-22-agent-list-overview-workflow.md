# 智能体列表 + 概览 + 工作流 三页重设计 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 spec `2026-05-22-agent-list-overview-workflow-design.md` 的 D2 + G1 + W1 三个核心方案,落地后三页面 30 秒辨认测试通过、后端零改动。

**Architecture:** 先做 PD 跨页共享原子(StatusDot/AgentAvatar/card-unified),再并行落 PA(列表分组瀑布)、PB(概览 Hero+tile+双 panel)、PC(工作流节点+网格+折线+抽屉)。所有任务只动 `ui/`,`apps/` git diff 必须为空。

**Tech Stack:** Vue 3 + Vite + TypeScript + Element Plus + SCSS + Lucide(`@iconify/vue` + `@iconify-json/lucide`)+ LogicFlow 2.x + ECharts(`vue-echarts`)。

**Verification approach:** 无单元测试基础设施,每个 Task 验收 = `npm run type-check`(必须退出 0)+ `npm run build`(可选,门级 task 必跑)+ dev server 路由走查 + 控制台 0 warnings/errors。

**Phase 依赖:** PD → (PA ‖ PB ‖ PC) → PE 走查。三页面之间互相不依赖,完成 PD 后可并行。

---

## 任务总览(18 个 Task)

| Phase | Task | 主题 |
|-------|------|------|
| **PD · 共享原子** | T1 | `StatusDot` 状态点组件 |
|  | T2 | `AgentAvatar` 单色字符头像组件 |
|  | T3 | 全局 `.card-unified` 样式类 |
| **PA · 智能体列表 D2** | T4 | application 路由切 MainLayout + Side IA |
|  | T5 | 新建 `ApplicationCard.vue` |
|  | T6 | 新建 `ApplicationGroupedList.vue` 分组瀑布 |
|  | T7 | 改写 `application/index.vue` 使用新组件 |
|  | T8 | i18n + 文案改"标签"用语 |
| **PB · 智能体概览 G1** | T9 | 新建 `HeroBar.vue` |
|  | T10 | 新建 `StatTile.vue` + 4 数据 tile 网格 |
|  | T11 | 新建 `TrendChart.vue` 单图 + 指标切换 |
|  | T12 | 新建 `AccessPanel.vue` 紧凑访问面板 |
|  | T13 | 改写 `application-overview/index.vue` 使用新组件 |
| **PC · 工作流 W1** | T14 | 画布 20×20 网格 SCSS |
|  | T15 | LogicFlow 边 `polyline` + 1.5px slate |
|  | T16 | 节点顶部 2px 色条 + 12×12 类型方块 icon |
|  | T17 | 节点配置 模态 → 右侧 420px 抽屉 |
| **PE · 联合走查** | T18 | 三页面 dev 走查 + 最终 commit |

---

## PD · 共享原子(3 Task)

### Task 1: `StatusDot` 状态点组件

**Files:**
- Create: `ui/src/components/status-dot/StatusDot.vue`
- Create: `ui/src/components/status-dot/index.ts`

- [ ] **Step 1: 创建组件目录与 index 出口**

写入 `ui/src/components/status-dot/index.ts`:

```typescript
import StatusDot from './StatusDot.vue'
export { StatusDot }
export default StatusDot
```

- [ ] **Step 2: 写入 `StatusDot.vue`**

```vue
<template>
  <span class="status-dot" :class="`status-dot--${status}`">
    <span class="status-dot__bullet" aria-hidden="true">●</span>
    <span class="status-dot__label">{{ label || statusText }}</span>
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

type StatusKey = 'published' | 'draft' | 'archived'

const props = defineProps<{
  status: StatusKey
  label?: string
}>()

const { t } = useI18n()

const statusText = computed(() => {
  switch (props.status) {
    case 'published': return t('common.status.published')
    case 'draft': return t('common.status.draft')
    case 'archived': return t('common.status.archived')
    default: return ''
  }
})
</script>

<style lang="scss" scoped>
.status-dot {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-size-xs);
  color: var(--text-secondary);
  line-height: 1;
}
.status-dot__bullet {
  font-size: 10px;
  line-height: 1;
}
.status-dot--published .status-dot__bullet { color: #10b981; }
.status-dot--draft .status-dot__bullet { color: #94a3b8; }
.status-dot--archived .status-dot__bullet { color: #cbd5e1; }
.status-dot--archived .status-dot__label { color: var(--text-tertiary); }
</style>
```

- [ ] **Step 3: 加 i18n key**

在 `ui/src/locales/lang/zh-CN/common.ts` 顶层节点(若已有 `status` 节点则补,否则新增)加:

```typescript
status: {
  published: '已发布',
  draft: '草稿',
  archived: '已归档',
},
```

`ui/src/locales/lang/en-US/common.ts` 加 `{ published: 'Published', draft: 'Draft', archived: 'Archived' }`,`zh-Hant` 加 `{ published: '已發布', draft: '草稿', archived: '已歸檔' }`。

- [ ] **Step 4: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 5: Commit**

```bash
git add ui/src/components/status-dot ui/src/locales
git commit -m "feat(ui): add StatusDot atom for unified status indicators"
```

---

### Task 2: `AgentAvatar` 单色字符头像组件

**Files:**
- Create: `ui/src/components/agent-avatar/AgentAvatar.vue`
- Create: `ui/src/components/agent-avatar/index.ts`

- [ ] **Step 1: 创建组件目录与出口**

写入 `ui/src/components/agent-avatar/index.ts`:

```typescript
import AgentAvatar from './AgentAvatar.vue'
export { AgentAvatar }
export default AgentAvatar
```

- [ ] **Step 2: 写入 `AgentAvatar.vue`**

```vue
<template>
  <span class="agent-avatar" :style="avatarStyle" :title="name">
    <span>{{ initial }}</span>
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    name: string
    size?: number
  }>(),
  { size: 28 }
)

const initial = computed(() => {
  const n = (props.name || '').trim()
  if (!n) return '?'
  return n.charAt(0).toUpperCase()
})

const avatarStyle = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
  fontSize: `${Math.round(props.size * 0.42)}px`,
}))
</script>

<style lang="scss" scoped>
.agent-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--brand-primary);
  color: #ffffff;
  font-weight: 600;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
  line-height: 1;
  user-select: none;
}
</style>
```

- [ ] **Step 3: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/components/agent-avatar
git commit -m "feat(ui): add AgentAvatar atom (single-color initial-letter square)"
```

---

### Task 3: 全局 `.card-unified` 样式类

**Files:**
- Modify: `ui/src/styles/component.scss`

- [ ] **Step 1: Read 当前 `component.scss` 头部**

```bash
head -10 ui/src/styles/component.scss
```

记录文件起始行,以便插入。

- [ ] **Step 2: 在 `component.scss` 末尾追加 `.card-unified`**

```scss
/* ===== 统一卡片(三页通用)===== */
.card-unified {
  background: var(--main-bg);
  border: 1px solid var(--border-base);
  border-radius: var(--radius-md);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  transition:
    border-color 0.15s,
    box-shadow 0.15s,
    transform 0.15s;

  &--hover:hover {
    border-color: rgba(15, 23, 42, 0.15);
    box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06);
    transform: translateY(-2px);
  }
}
```

- [ ] **Step 3: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/styles/component.scss
git commit -m "feat(ui): add .card-unified shared card style"
```

---

## PA · 智能体列表 D2(5 Task)

### Task 4: application 路由切 MainLayout + Side IA

**Files:**
- Modify: `ui/src/router/modules/application.ts`
- Modify: `ui/src/locales/lang/zh-CN/layout.ts`(同步 en-US / zh-Hant)

- [ ] **Step 1: 改写 `ui/src/router/modules/application.ts`**

```typescript
import { PermissionConst, RoleConst } from '@/utils/permission/data'

const applicationRouter = {
  path: '/application',
  name: 'application',
  meta: {
    title: 'layout.rail.agent',
    menu: true,
    permission: [
      RoleConst.USER.getWorkspaceRole,
      RoleConst.WORKSPACE_MANAGE.getWorkspaceRole,
      PermissionConst.APPLICATION_READ.getWorkspacePermissionWorkspaceManageRole,
      PermissionConst.APPLICATION_READ.getWorkspacePermission,
    ],
    icon: 'app-agent',
    iconActive: 'app-agent-active',
    group: 'workspace',
    order: 1,
  },
  redirect: '/application/list',
  component: () => import('@/layout/layout-template/MainLayout.vue'),
  children: [
    {
      path: '/application/list',
      name: 'application-list',
      meta: {
        title: 'layout.agent.menu.applicationList',
        active: '/application/list',
        activeMenu: '/application/list',
        parentPath: '/application',
        parentName: 'application',
        sameRoute: 'application',
      },
      component: () => import('@/views/application/index.vue'),
    },
  ],
}

export default applicationRouter
```

- [ ] **Step 2: 加 i18n key `layout.agent.menu.applicationList`**

在 `ui/src/locales/lang/zh-CN/layout.ts` 的 `layout` 节点(也就是文件 default export 的顶级)末尾,在 `workbench: { ... }` 块之后插入:

```typescript
agent: {
  menu: {
    applicationList: '应用列表',
  },
},
```

对应 en-US:`{ menu: { applicationList: 'Applications' } }`,zh-Hant:`{ menu: { applicationList: '應用列表' } }`。

- [ ] **Step 3: 检查 Rail 模块 `matchPaths` 仍能匹配新子路径**

确认 `ui/src/layout/layout-rail/modules.ts` 中:

```typescript
{
  key: 'agent',
  titleKey: 'layout.rail.agent',
  lucide: 'bot',
  path: '/application',
  matchPaths: ['/application', '/chat-user'],
},
```

`matchPaths` 用 `startsWith` 匹配,`/application/list` 仍命中。**无需改动**。

- [ ] **Step 4: 验证 + dev 走查**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

访问 `http://localhost:3000/admin/application`,预期:
- URL 自动重定向到 `/admin/application/list`
- 左侧 Rail "智能体" 亮起
- 200px Side 显示标题"智能体" + 菜单项"应用列表"
- Main 区域显示当前列表(暂未重做,可能仍是旧卡片网格)

- [ ] **Step 5: Commit**

```bash
git add ui/src/router/modules/application.ts ui/src/locales
git commit -m "refactor(ui): switch /application to MainLayout with Side menu"
```

---

### Task 5: 新建 `ApplicationCard.vue`

**Files:**
- Create: `ui/src/views/application/component/ApplicationCard.vue`

- [ ] **Step 1: 写入 `ApplicationCard.vue`**

```vue
<template>
  <router-link
    :to="`/application/${app.workspace_id || 'default'}/${appType}/${app.id}/overview`"
    class="app-card card-unified card-unified--hover"
  >
    <header class="app-card__head">
      <AgentAvatar :name="app.name" :size="32" />
      <div class="app-card__title">
        <h4 class="app-card__name">{{ app.name }}</h4>
        <span class="app-card__type">{{ typeLabel }}</span>
      </div>
    </header>
    <p class="app-card__desc" v-if="app.desc || app.description">
      {{ app.desc || app.description }}
    </p>
    <footer class="app-card__foot">
      <StatusDot :status="statusKey" />
      <span class="app-card__date">{{ formattedDate }}</span>
    </footer>
  </router-link>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import AgentAvatar from '@/components/agent-avatar/AgentAvatar.vue'
import StatusDot from '@/components/status-dot/StatusDot.vue'

interface ApplicationItem {
  id: string
  name: string
  desc?: string
  description?: string
  type?: string
  is_publish?: boolean
  update_time?: string
  workspace_id?: string
}

const props = defineProps<{ app: ApplicationItem }>()
const { t } = useI18n()

const appType = computed(() => (props.app.type || 'SIMPLE').toUpperCase())

const typeLabel = computed(() => {
  if (appType.value === 'WORK_FLOW') return t('views.application.advanced')
  return t('views.application.simple')
})

const statusKey = computed<'published' | 'draft'>(() =>
  props.app.is_publish ? 'published' : 'draft'
)

const formattedDate = computed(() => {
  const d = props.app.update_time
  if (!d) return ''
  return d.slice(0, 10)
})
</script>

<style lang="scss" scoped>
.app-card {
  display: flex;
  flex-direction: column;
  padding: 14px 16px;
  min-height: 120px;
  text-decoration: none;
  color: inherit;
}
.app-card__head {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px;
}
.app-card__title {
  display: flex;
  flex-direction: column;
  min-width: 0;
}
.app-card__name {
  font-size: var(--font-size-md);
  font-weight: 500;
  color: var(--text-primary);
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  line-height: 1.3;
}
.app-card__type {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  margin-top: 2px;
}
.app-card__desc {
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
  line-height: 1.5;
  margin: 0 0 10px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  flex: 1;
}
.app-card__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
}
</style>
```

- [ ] **Step 2: 加 i18n key**

`ui/src/locales/lang/zh-CN/views/application.ts` 的 default export 对象顶层加(或在已有 `simple`/`advanced` 上确认存在):

```typescript
simple: '简易',
advanced: '高级',
```

en-US:`{ simple: 'Simple', advanced: 'Advanced' }`,zh-Hant:`{ simple: '簡易', advanced: '高級' }`。

确认前若已存在(很可能),则 Step 2 跳过。

- [ ] **Step 3: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/application/component/ApplicationCard.vue ui/src/locales
git commit -m "feat(ui): add ApplicationCard component for redesigned agent list"
```

---

### Task 6: 新建 `ApplicationGroupedList.vue` 分组瀑布

**Files:**
- Create: `ui/src/views/application/component/ApplicationGroupedList.vue`

- [ ] **Step 1: 写入组件**

```vue
<template>
  <div class="grouped-list">
    <section v-for="group in groups" :key="group.key" class="grouped-list__group">
      <header class="grouped-list__head">
        <span
          class="grouped-list__color"
          :style="{ background: groupColor(group.key) }"
        />
        <h3 class="grouped-list__name">{{ group.label }}</h3>
        <span class="grouped-list__count">{{ group.items.length }}</span>
      </header>
      <div class="grouped-list__grid">
        <ApplicationCard
          v-for="item in group.items"
          :key="item.id"
          :app="item"
        />
        <button
          type="button"
          class="grouped-list__new card-unified"
          @click="$emit('create', group.key)"
        >
          <LucideIcon name="plus" :size="14" />
          {{ $t('views.application.newInGroup', { name: group.label }) }}
        </button>
      </div>
    </section>
    <div v-if="!groups.length" class="grouped-list__empty">
      <p>{{ $t('views.application.emptyList') }}</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import ApplicationCard from './ApplicationCard.vue'
import { LucideIcon } from '@/components/lucide-icon'

interface ApplicationItem {
  id: string
  name: string
  folder_id?: string | null
  is_publish?: boolean
  [k: string]: any
}
interface FolderItem {
  id: string
  name: string
}
interface GroupedView {
  key: string
  label: string
  items: ApplicationItem[]
}

const props = defineProps<{
  applications: ApplicationItem[]
  folders: FolderItem[]
  groupBy?: 'folder' | 'status' | 'none'
}>()

defineEmits<{ (e: 'create', folderId: string): void }>()

const palette = ['#10b981', '#3b82f6', '#8b5cf6', '#f59e0b', '#ef4444']

function hashIdx(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
  return h % palette.length
}

function groupColor(key: string): string {
  return palette[hashIdx(key)]
}

const groups = computed<GroupedView[]>(() => {
  const mode = props.groupBy || 'folder'
  if (mode === 'none') {
    return [{ key: 'all', label: '全部', items: props.applications }]
  }
  if (mode === 'status') {
    const buckets: Record<string, ApplicationItem[]> = {
      published: [],
      draft: [],
    }
    for (const a of props.applications) {
      ;(a.is_publish ? buckets.published : buckets.draft).push(a)
    }
    return [
      { key: 'published', label: '已发布', items: buckets.published },
      { key: 'draft', label: '草稿', items: buckets.draft },
    ].filter((g) => g.items.length > 0)
  }
  // mode === 'folder'
  const byFolder = new Map<string, ApplicationItem[]>()
  for (const a of props.applications) {
    const fid = a.folder_id || '__unsorted__'
    if (!byFolder.has(fid)) byFolder.set(fid, [])
    byFolder.get(fid)!.push(a)
  }
  const result: GroupedView[] = []
  for (const f of props.folders) {
    result.push({
      key: f.id,
      label: f.name,
      items: byFolder.get(f.id) || [],
    })
  }
  if (byFolder.has('__unsorted__')) {
    result.push({
      key: '__unsorted__',
      label: '未分类',
      items: byFolder.get('__unsorted__') || [],
    })
  }
  return result.filter((g) => g.items.length > 0)
})
</script>

<style lang="scss" scoped>
.grouped-list {
  display: flex;
  flex-direction: column;
  gap: 28px;
}
.grouped-list__head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
}
.grouped-list__color {
  width: 3px;
  height: 14px;
  border-radius: 2px;
  flex-shrink: 0;
}
.grouped-list__name {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}
.grouped-list__count {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
}
.grouped-list__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}
.grouped-list__new {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-height: 120px;
  border-style: dashed;
  background: transparent;
  color: var(--text-tertiary);
  font-size: var(--font-size-sm);
  cursor: pointer;
  &:hover {
    color: var(--text-primary);
    border-color: var(--text-tertiary);
  }
}
.grouped-list__empty {
  padding: 48px;
  text-align: center;
  color: var(--text-tertiary);
}
</style>
```

- [ ] **Step 2: 加 i18n key**

`ui/src/locales/lang/zh-CN/views/application.ts` 加:

```typescript
newInGroup: '在「{name}」下新建',
emptyList: '还没有智能体,去创建一个？',
```

en-US:`{ newInGroup: 'New in "{name}"', emptyList: 'No agents yet. Create one?' }`
zh-Hant:`{ newInGroup: '在「{name}」下新建', emptyList: '還沒有智能體，去創建一個？' }`

- [ ] **Step 3: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/application/component/ApplicationGroupedList.vue ui/src/locales
git commit -m "feat(ui): add ApplicationGroupedList for D2 waterfall layout"
```

---

### Task 7: 改写 `application/index.vue` 使用新组件

**Files:**
- Modify: `ui/src/views/application/index.vue`

- [ ] **Step 1: 先读现有文件结构**

```bash
wc -l ui/src/views/application/index.vue
head -30 ui/src/views/application/index.vue
```

理解现有 import / state / API 调用模式,以便保留数据接入逻辑。

- [ ] **Step 2: 重写 template + style,保留数据接入**

把整个 `<template>` 替换为:

```vue
<template>
  <div class="application-page">
    <header class="application-page__toolbar">
      <el-input
        v-model="searchKeyword"
        :placeholder="$t('views.application.searchPlaceholder')"
        class="application-page__search"
        clearable
        :prefix-icon="Search"
      />
      <el-select
        v-model="groupBy"
        size="default"
        class="application-page__groupby"
      >
        <el-option value="folder" :label="$t('views.application.groupBy.folder')" />
        <el-option value="status" :label="$t('views.application.groupBy.status')" />
        <el-option value="none" :label="$t('views.application.groupBy.none')" />
      </el-select>
      <el-button type="primary" @click="onCreate()">
        <LucideIcon name="plus" :size="14" />
        {{ $t('common.create') }}
      </el-button>
    </header>

    <ApplicationGroupedList
      :applications="filteredApplications"
      :folders="folders"
      :group-by="groupBy"
      @create="onCreate"
    />

    <!-- 旧创建对话框、模板对话框等保留(后续 task 改皮肤) -->
    <CreateApplicationDialog
      v-if="createDialogVisible"
      v-model:visible="createDialogVisible"
      :default-folder-id="targetFolderId"
      @created="loadAll"
    />
  </div>
</template>
```

`<script setup>` 部分核心保留 / 新增:

```typescript
import { ref, computed, onMounted } from 'vue'
import { Search } from '@element-plus/icons-vue'
import ApplicationGroupedList from './component/ApplicationGroupedList.vue'
import CreateApplicationDialog from './component/CreateApplicationDialog.vue'
import { LucideIcon } from '@/components/lucide-icon'
// 已有的 application API 与 folder API import 保留
// 假设原 file 中有 applicationApi / folderApi 引用 — 保留它们

const searchKeyword = ref('')
const groupBy = ref<'folder' | 'status' | 'none'>('folder')
const applications = ref<any[]>([])
const folders = ref<any[]>([])
const loading = ref(false)
const createDialogVisible = ref(false)
const targetFolderId = ref<string | null>(null)

const filteredApplications = computed(() => {
  const kw = searchKeyword.value.trim().toLowerCase()
  if (!kw) return applications.value
  return applications.value.filter((a: any) =>
    (a.name || '').toLowerCase().includes(kw) ||
    (a.desc || a.description || '').toLowerCase().includes(kw),
  )
})

async function loadAll() {
  loading.value = true
  try {
    // ← 这两个调用的精确签名以现有 file 里 import 的方法为准
    // 若原 file 用 applicationApi.getAllApplication / folderApi.getFolders,沿用
    const [apps, fs] = await Promise.all([
      applicationApi.getAllApplication?.(undefined),
      folderApi.getFolderList?.('APPLICATION') ?? Promise.resolve({ data: [] }),
    ])
    applications.value = (apps as any)?.data ?? []
    folders.value = (fs as any)?.data ?? []
  } catch (e) {
    console.warn('[application] load failed:', e)
  } finally {
    loading.value = false
  }
}

function onCreate(folderId?: string) {
  targetFolderId.value = folderId === '__unsorted__' ? null : folderId || null
  createDialogVisible.value = true
}

onMounted(loadAll)
```

> **重要**:`applicationApi` 与 `folderApi` 的具体 import 路径与方法名以现有 `index.vue` 里实际用的为准 — Step 1 grep 出来后照抄,不要发明新方法。

替换 `<style scoped>`:

```scss
.application-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 20px;
}
.application-page__toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
}
.application-page__search {
  max-width: 320px;
}
.application-page__groupby {
  width: 160px;
}
```

- [ ] **Step 3: i18n 补 toolbar 文案**

`ui/src/locales/lang/zh-CN/views/application.ts` 加:

```typescript
searchPlaceholder: '搜索智能体',
groupBy: {
  folder: '按标签分组',
  status: '按状态分组',
  none: '不分组',
},
```

en-US / zh-Hant 对应翻译。`ui/src/locales/lang/zh-CN/common.ts` 确认 `create: '创建'` 存在(若无则补)。

- [ ] **Step 4: 类型检查 + dev 走查**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

访问 `http://localhost:3000/admin/application/list`,预期:
- 顶部:搜索框 + "按标签分组" 下拉 + "创建" 按钮
- 主区:按 folder 自动分组显示,每组带颜色条 + 名称 + 数量
- 每组末尾有"+ 在「xxx」下新建"虚线卡
- 卡片头像是单色字符,不是紫机器人
- 控制台 0 errors

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/application/index.vue ui/src/locales
git commit -m "refactor(ui): rewrite application list as grouped waterfall (D2)"
```

---

### Task 8: i18n + 文案改"标签"用语

**Files:**
- Modify: `ui/src/locales/lang/{zh-CN,en-US,zh-Hant}/views/application.ts`
- Modify: `ui/src/components/folder-tree/index.vue`(仅 application 上下文文案,如有共享则不动)

- [ ] **Step 1: 扫描 application 相关"根目录""文件夹"文案**

```bash
grep -rn "根目录\|文件夹" ui/src/locales/lang/zh-CN/views/application.ts ui/src/views/application/ 2>/dev/null
```

- [ ] **Step 2: 应用文案在 application 模块的 i18n value 中改"标签"**

`ui/src/locales/lang/zh-CN/views/application.ts` 中(如已存在)把:
- `根目录` → `未分类`(若指列表里的默认组)
- `新建文件夹` → `新建标签`(若有这种 key)
- `重命名文件夹` → `重命名标签`

en-US:`Root` → `Unsorted`,`New folder` → `New label`,`Rename folder` → `Rename label`
zh-Hant 对应。

> ⚠️ 只动 application 模块的文案。knowledge / tool 等模块仍使用 folder-tree 组件,**不动它们的文案**(spec §3.1.3 明确)。

- [ ] **Step 3: 类型检查**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 4: dev 走查**

`/admin/application/list` 上能看到的 folder 相关 UI 文案应使用"标签 / 未分类"。

- [ ] **Step 5: Commit**

```bash
git add ui/src/locales
git commit -m "i18n(ui): rename folder concept to label in application module"
```

---

## PB · 智能体概览 G1(5 Task)

### Task 9: 新建 `HeroBar.vue`

**Files:**
- Create: `ui/src/views/application-overview/component/HeroBar.vue`

- [ ] **Step 1: 写入 `HeroBar.vue`**

```vue
<template>
  <header class="hero-bar">
    <AgentAvatar :name="detail?.name || '?'" :size="48" />
    <div class="hero-bar__title">
      <h1 class="hero-bar__name">{{ detail?.name || '-' }}</h1>
      <div class="hero-bar__meta">
        <StatusDot :status="detail?.is_publish ? 'published' : 'draft'" />
        <span class="hero-bar__sep">·</span>
        <span>{{ typeLabel }}</span>
        <span class="hero-bar__sep">·</span>
        <span>{{ detail?.user_name || '-' }}</span>
        <span class="hero-bar__sep">·</span>
        <span>{{ formattedDate }}</span>
      </div>
    </div>
    <div class="hero-bar__actions">
      <el-button @click="$emit('display-setting')">
        <LucideIcon name="settings-2" :size="14" />
        <span class="ml-4">{{ $t('views.applicationOverview.displaySetting') }}</span>
      </el-button>
      <el-button @click="$emit('embed')">
        <LucideIcon name="code-2" :size="14" />
        <span class="ml-4">{{ $t('views.applicationOverview.embed') }}</span>
      </el-button>
      <el-button @click="$emit('access-limit')">
        <LucideIcon name="lock" :size="14" />
        <span class="ml-4">{{ $t('views.applicationOverview.accessLimit') }}</span>
      </el-button>
      <el-button type="primary" @click="$emit('go-chat')">
        <LucideIcon name="message-circle" :size="14" />
        <span class="ml-4">{{ $t('views.applicationOverview.goChat') }}</span>
      </el-button>
    </div>
  </header>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import AgentAvatar from '@/components/agent-avatar/AgentAvatar.vue'
import StatusDot from '@/components/status-dot/StatusDot.vue'
import { LucideIcon } from '@/components/lucide-icon'

const props = defineProps<{ detail: any }>()

defineEmits<{
  (e: 'display-setting'): void
  (e: 'embed'): void
  (e: 'access-limit'): void
  (e: 'go-chat'): void
}>()

const { t } = useI18n()

const typeLabel = computed(() => {
  const t_ = (props.detail?.type || 'SIMPLE').toUpperCase()
  if (t_ === 'WORK_FLOW') return t('views.application.advanced')
  return t('views.application.simple')
})

const formattedDate = computed(() => (props.detail?.update_time || '').slice(0, 10))
</script>

<style lang="scss" scoped>
.hero-bar {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px 20px;
  border-bottom: 1px solid var(--border-base);
  background: var(--main-bg);
}
.hero-bar__title {
  flex: 1;
  min-width: 0;
}
.hero-bar__name {
  margin: 0;
  font-size: var(--font-size-xl);
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.3;
}
.hero-bar__meta {
  margin-top: 4px;
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
}
.hero-bar__sep {
  color: var(--text-tertiary);
}
.hero-bar__actions {
  display: flex;
  gap: 6px;
}
</style>
```

- [ ] **Step 2: 加 i18n key**

`ui/src/locales/lang/zh-CN/views/application-overview.ts` 顶层加(若不存在):

```typescript
displaySetting: '显示设置',
embed: '嵌入第三方',
accessLimit: '访问限制',
goChat: '去对话',
```

en-US:`{ displaySetting: 'Display', embed: 'Embed', accessLimit: 'Access', goChat: 'Open chat' }`
zh-Hant 对应。

部分 key 可能已存在(如 `goChat`)— grep 确认,已存在则跳过。

- [ ] **Step 3: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/application-overview/component/HeroBar.vue ui/src/locales
git commit -m "feat(ui): add HeroBar component for redesigned overview"
```

---

### Task 10: 新建 `StatTile.vue` + 4 数据 tile 网格

**Files:**
- Create: `ui/src/views/application-overview/component/StatTile.vue`
- Create: `ui/src/views/application-overview/component/StatGrid.vue`

- [ ] **Step 1: 写入 `StatTile.vue`**

```vue
<template>
  <article class="stat-tile">
    <div class="stat-tile__icon">
      <LucideIcon :name="icon" :size="18" />
    </div>
    <div class="stat-tile__body">
      <div class="stat-tile__num">{{ value }}</div>
      <div class="stat-tile__label">{{ label }}</div>
      <div v-if="delta" class="stat-tile__delta" :class="deltaClass">
        {{ delta }}
      </div>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { LucideIcon } from '@/components/lucide-icon'

const props = defineProps<{
  icon: string
  value: string | number
  label: string
  delta?: string
  trend?: 'up' | 'down' | 'flat'
}>()

const deltaClass = computed(() => {
  if (props.trend === 'up') return 'stat-tile__delta--up'
  if (props.trend === 'down') return 'stat-tile__delta--down'
  return 'stat-tile__delta--flat'
})
</script>

<style lang="scss" scoped>
.stat-tile {
  background: var(--side-bg);
  border: 1px solid var(--border-base);
  border-radius: var(--radius-md);
  padding: 14px 16px;
  display: flex;
  gap: 12px;
}
.stat-tile__icon {
  width: 32px;
  height: 32px;
  background: var(--main-bg);
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--brand-primary);
  flex-shrink: 0;
}
.stat-tile__num {
  font-size: 22px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.1;
}
.stat-tile__label {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-top: 4px;
}
.stat-tile__delta {
  font-size: var(--font-size-xs);
  margin-top: 4px;
}
.stat-tile__delta--up { color: #10b981; }
.stat-tile__delta--down { color: #ef4444; }
.stat-tile__delta--flat { color: var(--text-tertiary); }
</style>
```

- [ ] **Step 2: 写入 `StatGrid.vue`**

```vue
<template>
  <section class="stat-grid">
    <StatTile
      icon="users"
      :value="formatNumber(stats?.user_count)"
      :label="$t('views.applicationOverview.stats.users')"
      :delta="stats?.user_delta_label"
      :trend="stats?.user_trend"
    />
    <StatTile
      icon="message-circle"
      :value="formatNumber(stats?.qa_count)"
      :label="$t('views.applicationOverview.stats.questions')"
      :delta="stats?.qa_delta_label"
      :trend="stats?.qa_trend"
    />
    <StatTile
      icon="atom"
      :value="formatNumber(stats?.token_count)"
      :label="$t('views.applicationOverview.stats.tokens')"
      :delta="stats?.token_delta_label"
      :trend="stats?.token_trend"
    />
    <StatTile
      icon="smile"
      :value="formatPercent(stats?.satisfaction)"
      :label="$t('views.applicationOverview.stats.satisfaction')"
      :delta="stats?.satisfaction_delta_label"
      :trend="stats?.satisfaction_trend"
    />
  </section>
</template>

<script setup lang="ts">
import StatTile from './StatTile.vue'

defineProps<{ stats: any }>()

function formatNumber(n: number | undefined): string {
  if (n == null) return '0'
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`
  return String(n)
}

function formatPercent(n: number | undefined): string {
  if (n == null) return '—'
  return `${Math.round(n * 100)}%`
}
</script>

<style lang="scss" scoped>
.stat-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  padding: 16px 20px 0;
  @media (max-width: 1024px) {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
```

- [ ] **Step 3: 加 i18n key**

`ui/src/locales/lang/zh-CN/views/application-overview.ts` 加:

```typescript
stats: {
  users: '用户总数',
  questions: '提问次数',
  tokens: 'Tokens 总数',
  satisfaction: '用户满意度',
},
```

en-US:`{ users: 'Users', questions: 'Questions', tokens: 'Tokens', satisfaction: 'Satisfaction' }`
zh-Hant 对应。

- [ ] **Step 4: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/application-overview/component/StatTile.vue ui/src/views/application-overview/component/StatGrid.vue ui/src/locales
git commit -m "feat(ui): add StatTile + StatGrid for overview KPI row"
```

---

### Task 11: 新建 `TrendChart.vue` 单图 + 指标切换

**Files:**
- Create: `ui/src/views/application-overview/component/TrendChart.vue`

- [ ] **Step 1: 写入 `TrendChart.vue`**

```vue
<template>
  <article class="trend-chart card-unified">
    <header class="trend-chart__head">
      <h3 class="trend-chart__title">{{ $t('views.applicationOverview.trend.title') }}</h3>
      <div class="trend-chart__filters">
        <el-select v-model="range" size="small" class="trend-chart__range">
          <el-option value="7" :label="$t('views.applicationOverview.trend.last7')" />
          <el-option value="30" :label="$t('views.applicationOverview.trend.last30')" />
          <el-option value="90" :label="$t('views.applicationOverview.trend.last90')" />
        </el-select>
        <el-select v-model="metric" size="small" class="trend-chart__metric">
          <el-option value="users" :label="$t('views.applicationOverview.stats.users')" />
          <el-option value="questions" :label="$t('views.applicationOverview.stats.questions')" />
          <el-option value="tokens" :label="$t('views.applicationOverview.stats.tokens')" />
          <el-option value="satisfaction" :label="$t('views.applicationOverview.stats.satisfaction')" />
        </el-select>
      </div>
    </header>
    <div ref="chartRef" class="trend-chart__canvas" />
  </article>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import { GridComponent, TooltipComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([LineChart, GridComponent, TooltipComponent, CanvasRenderer])

const props = defineProps<{
  series: Array<{ date: string; value: number }>
}>()

const emit = defineEmits<{
  (e: 'change', payload: { range: string; metric: string }): void
}>()

const range = ref('7')
const metric = ref('questions')
const chartRef = ref<HTMLDivElement>()
let chart: echarts.ECharts | null = null

function renderChart() {
  if (!chartRef.value) return
  if (!chart) chart = echarts.init(chartRef.value)
  chart.setOption({
    grid: { left: 32, right: 16, top: 16, bottom: 24 },
    xAxis: {
      type: 'category',
      data: props.series.map((p) => p.date),
      axisLine: { lineStyle: { color: '#e5e7eb' } },
      axisLabel: { color: '#94a3b8', fontSize: 10 },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { lineStyle: { color: '#f1f5f9' } },
      axisLabel: { color: '#94a3b8', fontSize: 10 },
    },
    tooltip: { trigger: 'axis' },
    series: [
      {
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        data: props.series.map((p) => p.value),
        lineStyle: { color: '#0f172a', width: 1.5 },
        itemStyle: { color: '#0f172a' },
        areaStyle: { color: 'rgba(15, 23, 42, 0.04)' },
      },
    ],
  })
}

watch([range, metric], () => {
  emit('change', { range: range.value, metric: metric.value })
})

watch(() => props.series, () => renderChart(), { deep: true })

onMounted(async () => {
  await nextTick()
  renderChart()
  emit('change', { range: range.value, metric: metric.value })
})

onBeforeUnmount(() => {
  chart?.dispose()
  chart = null
})
</script>

<style lang="scss" scoped>
.trend-chart {
  padding: 14px 16px;
}
.trend-chart__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}
.trend-chart__title {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}
.trend-chart__filters {
  display: flex;
  gap: 8px;
}
.trend-chart__range,
.trend-chart__metric {
  width: 110px;
}
.trend-chart__canvas {
  height: 220px;
  width: 100%;
}
</style>
```

- [ ] **Step 2: 加 i18n key**

`ui/src/locales/lang/zh-CN/views/application-overview.ts` 加:

```typescript
trend: {
  title: '提问趋势',
  last7: '过去 7 天',
  last30: '过去 30 天',
  last90: '过去 90 天',
},
```

en-US / zh-Hant 同步。

- [ ] **Step 3: 确认 echarts 依赖**

```bash
grep '"echarts"' ui/package.json
```

确保 echarts 已是依赖。若无,跳过本任务并先 `cd ui && npm install --save echarts`(spec 范围内允许加这一个库,与 ECharts 既有使用一致)。

- [ ] **Step 4: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/application-overview/component/TrendChart.vue ui/src/locales
git commit -m "feat(ui): add TrendChart with metric switcher (replaces 4 charts)"
```

---

### Task 12: 新建 `AccessPanel.vue` 紧凑访问面板

**Files:**
- Create: `ui/src/views/application-overview/component/AccessPanel.vue`

- [ ] **Step 1: 写入 `AccessPanel.vue`**

```vue
<template>
  <article class="access-panel card-unified">
    <header class="access-panel__head">
      <h3 class="access-panel__title">{{ $t('views.applicationOverview.access.title') }}</h3>
    </header>
    <ul class="access-panel__list">
      <li class="access-panel__row">
        <span class="access-panel__label">{{ $t('views.applicationOverview.access.publicLink') }}</span>
        <el-switch v-model="modelToken" size="small" @change="$emit('toggle-active', modelToken)" />
        <span class="access-panel__hint">{{ modelToken ? $t('common.on') : $t('common.off') }}</span>
      </li>
      <li class="access-panel__row" v-if="modelToken">
        <span class="access-panel__label">{{ $t('views.applicationOverview.access.url') }}</span>
        <span class="access-panel__url">{{ chatUrl }}</span>
        <el-button text @click="$emit('copy', chatUrl)" :title="$t('common.copy')">
          <LucideIcon name="copy" :size="14" />
        </el-button>
      </li>
      <li class="access-panel__row">
        <span class="access-panel__label">{{ $t('views.applicationOverview.access.apiDoc') }}</span>
        <a :href="apiDocUrl" target="_blank" rel="noopener" class="access-panel__url access-panel__url--link">
          {{ apiDocUrl }}
        </a>
        <LucideIcon name="external-link" :size="14" />
      </li>
      <li class="access-panel__row">
        <span class="access-panel__label">{{ $t('views.applicationOverview.access.apiKey') }}</span>
        <el-button size="small" @click="$emit('manage-keys')">
          <LucideIcon name="key" :size="14" />
          <span class="ml-4">{{ $t('views.applicationOverview.access.manageKey') }}</span>
        </el-button>
      </li>
    </ul>
  </article>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { LucideIcon } from '@/components/lucide-icon'

const props = defineProps<{
  accessToken: { is_active?: boolean; access_token?: string }
  baseUrl: string
}>()

defineEmits<{
  (e: 'toggle-active', value: boolean): void
  (e: 'copy', value: string): void
  (e: 'manage-keys'): void
}>()

const modelToken = ref(!!props.accessToken?.is_active)
watch(() => props.accessToken?.is_active, (v) => { modelToken.value = !!v })

const chatUrl = computed(() => `${props.baseUrl}/chat/${props.accessToken?.access_token || ''}`)
const apiDocUrl = computed(() => `${props.baseUrl}/chat/api-doc/`)
</script>

<style lang="scss" scoped>
.access-panel {
  padding: 14px 16px;
}
.access-panel__head { margin-bottom: 8px; }
.access-panel__title {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}
.access-panel__list {
  list-style: none;
  padding: 0;
  margin: 0;
}
.access-panel__row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 0;
  border-top: 1px solid #f1f5f9;
  font-size: var(--font-size-sm);
}
.access-panel__label {
  color: var(--text-secondary);
  min-width: 80px;
  flex-shrink: 0;
}
.access-panel__url {
  font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
  font-size: var(--font-size-xs);
  background: var(--side-bg);
  padding: 3px 8px;
  border-radius: var(--radius-sm);
  color: var(--text-primary);
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  text-decoration: none;
}
.access-panel__url--link { color: var(--text-primary); }
.access-panel__hint {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
}
</style>
```

- [ ] **Step 2: 加 i18n key**

`ui/src/locales/lang/zh-CN/views/application-overview.ts` 加:

```typescript
access: {
  title: '访问与接入',
  publicLink: '公开访问',
  url: '链接',
  apiDoc: 'API 文档',
  apiKey: 'API Key',
  manageKey: '管理 Key',
},
```

en-US 与 zh-Hant 对应。`common.on / common.off / common.copy` 确认存在。

- [ ] **Step 3: 验证编译**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/application-overview/component/AccessPanel.vue ui/src/locales
git commit -m "feat(ui): add AccessPanel for compact access/API/key section"
```

---

### Task 13: 改写 `application-overview/index.vue` 使用新组件

**Files:**
- Modify: `ui/src/views/application-overview/index.vue`

- [ ] **Step 1: 备份现有数据接入代码片段**

```bash
grep -n "applicationOverviewApi\|getStatistics\|loadDetail\|onMounted" ui/src/views/application-overview/index.vue | head -10
```

记录现有 API 调用,以便保留。

- [ ] **Step 2: 重写 template**

把整个 `<template>` 替换为:

```vue
<template>
  <div class="overview-page" v-loading="loading">
    <HeroBar
      :detail="detail"
      @display-setting="displayDialogVisible = true"
      @embed="embedDialogVisible = true"
      @access-limit="limitDialogVisible = true"
      @go-chat="goChat"
    />

    <StatGrid :stats="stats" />

    <div class="overview-page__row">
      <TrendChart
        :series="trendSeries"
        @change="onTrendChange"
      />
      <AccessPanel
        :access-token="accessToken"
        :base-url="baseUrl"
        @toggle-active="onToggleActive"
        @copy="onCopy"
        @manage-keys="apiKeyDialogVisible = true"
      />
    </div>

    <!-- 保留现有 Dialog 组件,后续 task 改皮肤 -->
    <DisplaySettingDialog v-if="displayDialogVisible" v-model:visible="displayDialogVisible" :detail="detail" />
    <EmbedDialog v-if="embedDialogVisible" v-model:visible="embedDialogVisible" :detail="detail" />
    <LimitDialog v-if="limitDialogVisible" v-model:visible="limitDialogVisible" :detail="detail" />
    <APIKeyDialog v-if="apiKeyDialogVisible" v-model:visible="apiKeyDialogVisible" :detail="detail" />
  </div>
</template>
```

`<script setup>` 新结构(保留原数据接入):

```typescript
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import HeroBar from './component/HeroBar.vue'
import StatGrid from './component/StatGrid.vue'
import TrendChart from './component/TrendChart.vue'
import AccessPanel from './component/AccessPanel.vue'
import DisplaySettingDialog from './component/DisplaySettingDialog.vue'
import EmbedDialog from './component/EmbedDialog.vue'
import LimitDialog from './component/LimitDialog.vue'
import APIKeyDialog from './component/APIKeyDialog.vue'
// 原 file 的 applicationOverviewApi import 保留 — 沿用具体方法名

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const detail = ref<any>(null)
const stats = ref<any>(null)
const trendSeries = ref<Array<{ date: string; value: number }>>([])
const accessToken = ref<{ is_active?: boolean; access_token?: string }>({})
const baseUrl = ref(window.location.origin)

const displayDialogVisible = ref(false)
const embedDialogVisible = ref(false)
const limitDialogVisible = ref(false)
const apiKeyDialogVisible = ref(false)

async function loadDetail() {
  loading.value = true
  try {
    // 沿用原 file 的方法名;按 route.params.id 拉数据
    detail.value = (await applicationApi.getApplicationDetail(route.params.id)).data
    accessToken.value = (await applicationApi.getAccessToken(route.params.id)).data
    stats.value = (await applicationOverviewApi.getSummary(route.params.id)).data
  } catch (e) {
    console.warn('[overview] load failed:', e)
  } finally {
    loading.value = false
  }
}

async function onTrendChange(payload: { range: string; metric: string }) {
  try {
    const res = await applicationOverviewApi.getStatistics(
      route.params.id, payload.range, payload.metric,
    )
    trendSeries.value = (res.data || []).map((p: any) => ({
      date: p.date,
      value: p.value,
    }))
  } catch (e) {
    console.warn('[overview] trend load failed:', e)
  }
}

function onToggleActive(v: boolean) {
  applicationApi.toggleAccessToken(route.params.id, v).then(() => loadDetail())
}

function onCopy(text: string) {
  navigator.clipboard.writeText(text)
}

function goChat() {
  const url = `${baseUrl.value}/chat/${accessToken.value.access_token || ''}`
  window.open(url, '_blank')
}

onMounted(loadDetail)
```

> **重要**:`applicationApi.getApplicationDetail` / `getAccessToken` / `toggleAccessToken` 与 `applicationOverviewApi.getSummary` / `getStatistics` 的实际签名以现有 file 为准。Step 1 grep 出来后照抄。**不要发明新方法**;若现有方法返回结构不同,在 `loadDetail` 内适配,不动 API 层。

替换 `<style scoped>`:

```scss
.overview-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.overview-page__row {
  display: grid;
  grid-template-columns: 1.5fr 1fr;
  gap: 12px;
  padding: 0 20px 20px;
  @media (max-width: 1280px) {
    grid-template-columns: 1fr;
  }
}
```

- [ ] **Step 3: 删除 / 注释 旧的 StatisticsCharts 引用**

旧 `StatisticsCharts.vue` 的 4 chart 网格不再使用。在 `index.vue` 中:
- 删除 `import StatisticsCharts from './component/StatisticsCharts.vue'` 行(若有)
- 删除 template 中所有 `<StatisticsCharts ... />` 节点
- **不删** `StatisticsCharts.vue` 文件本体(其它视图可能仍引用)

```bash
grep -rln "StatisticsCharts" ui/src --exclude-dir=node_modules
```

确认其它处是否引用。如仅 overview 本页用到,可在 PE Task 18 末了删除文件。

- [ ] **Step 4: 类型检查 + dev 走查**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

访问任一应用详情页(如 `/admin/application/workspace/<id>/SIMPLE/overview`),预期:
- 顶部 Hero 横条(单色头像 + 名称 + 状态 + 4 按钮)
- 中间 4 个数据 tile(单色 Lucide outline icon)
- 下方左大右小:左 1 张趋势图带切换器,右紧凑访问面板
- 旧"基本信息" + 4 张并排折线图已消失
- 控制台 0 errors

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/application-overview/index.vue ui/src/locales
git commit -m "refactor(ui): rebuild overview as Hero+StatGrid+TrendChart+AccessPanel (G1)"
```

---

## PC · 工作流 W1(4 Task)

### Task 14: 画布 20×20 网格 SCSS

**Files:**
- Modify: `ui/src/styles/workflow.scss`

- [ ] **Step 1: Read 现有 workflow.scss 头部**

```bash
head -30 ui/src/styles/workflow.scss
```

- [ ] **Step 2: 在 workflow.scss 末尾追加画布网格 + 节点 token 重设**

```scss
/* ===== W1 · 工作流画布与节点重设 ===== */
.lf-canvas-overlay,
.lf-canvas {
  background-color: #ffffff;
  background-image:
    linear-gradient(#f1f5f9 1px, transparent 1px),
    linear-gradient(90deg, #f1f5f9 1px, transparent 1px);
  background-size: 20px 20px;
}

/* 节点容器顶部 2px 类型色条 */
.step-container {
  --node-type-color: #94a3b8;
  position: relative;
}
.step-container::before {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 2px;
  background: var(--node-type-color);
  border-top-left-radius: 6px;
  border-top-right-radius: 6px;
}
/* 类型映射(spec §6.4) */
.step-container[data-node-type="start"] { --node-type-color: #10b981; }
.step-container[data-node-type="reply"] { --node-type-color: #ef4444; }
.step-container[data-node-type="application"] { --node-type-color: #8b5cf6; }
.step-container[data-node-type="ai-chat"] { --node-type-color: #8b5cf6; }
.step-container[data-node-type="search-knowledge"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="condition"] { --node-type-color: #f59e0b; }
.step-container[data-node-type="question"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="form"] { --node-type-color: #f59e0b; }
.step-container[data-node-type="document-extract"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="rerank"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="speech-to-text"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="text-to-speech"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="image-understand"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="image-generate"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="variable-assign"] { --node-type-color: #f59e0b; }
.step-container[data-node-type="variable-aggregation"] { --node-type-color: #f59e0b; }
.step-container[data-node-type="variable-splitting"] { --node-type-color: #f59e0b; }
.step-container[data-node-type="loop"] { --node-type-color: #f59e0b; }
.step-container[data-node-type="loop-break"] { --node-type-color: #f59e0b; }
.step-container[data-node-type="loop-continue"] { --node-type-color: #f59e0b; }
.step-container[data-node-type="parameter-extraction"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="reranker"] { --node-type-color: #3b82f6; }
.step-container[data-node-type="tool"] { --node-type-color: #8b5cf6; }
.step-container[data-node-type="tool-base"] { --node-type-color: #8b5cf6; }
.step-container[data-node-type="tool-lib"] { --node-type-color: #8b5cf6; }
.step-container[data-node-type="tool-workflow-lib"] { --node-type-color: #8b5cf6; }
```

> 节点类型列表参考 `ui/src/workflow/icons/*-node-icon.vue` 文件名;若新增节点类型,在此处补充映射。

- [ ] **Step 3: 验证 + dev 走查**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

访问任意 workflow 路径(如 `/admin/application/workspace/.../workflow`),预期:
- 画布出现细网格(20×20,浅灰 #f1f5f9)
- 节点顶部出现 2px 色条(默认 slate,因 Task 16 还未注入 type 属性)

- [ ] **Step 4: Commit**

```bash
git add ui/src/styles/workflow.scss
git commit -m "feat(ui): add 20x20 canvas grid + node top color-bar SCSS (W1)"
```

---

### Task 15: LogicFlow 边 polyline + 1.5px slate stroke

**Files:**
- Modify: `ui/src/workflow/index.vue`(`setTheme` 配置)
- Modify: `ui/src/workflow/common/edge.ts`(边类型注册)

- [ ] **Step 1: 改 `ui/src/workflow/index.vue` 的 setTheme**

找到 `lf.value.setTheme({ ... })` 块(约第 82-87 行),改为:

```typescript
lf.value.setTheme({
  polyline: {
    stroke: '#0f172a',
    strokeWidth: 1.5,
  },
  bezier: {
    stroke: '#0f172a',
    strokeWidth: 1.5,
  },
})
```

> **保留 bezier**:loopEdge 等内部循环边可能仍用 bezier;统一改色避免回退。

- [ ] **Step 2: 改 `edge.ts` 默认边类型**

找 `class AppEdge extends ... { ... }` 与 `lf.setDefaultEdgeType('app-edge')`(约 `ui/src/workflow/index.vue` 末尾),`AppEdge` 在 `edge.ts` 中。

打开 `ui/src/workflow/common/edge.ts`,找到:

```typescript
class AppEdge extends PolylineEdge { ... }
// 或
class AppEdge extends BezierEdge { ... }
```

- 若继承自 `BezierEdge` → 改为 `PolylineEdge`(从 `@logicflow/core` 引入)
- 若已继承自 `PolylineEdge` → 不动

也更新 model:

```typescript
class AppEdgeModel extends PolylineEdgeModel { ... }
```

> **找到具体类名后照改**。`PolylineEdge` / `PolylineEdgeModel` 是 LogicFlow 2.x 标准 export。

- [ ] **Step 3: 检查 setTheme 是否影响 loopEdge**

读 `ui/src/workflow/common/loopEdge.ts` 头部 20 行,确认其继承基类。如继承 BezierEdge,因 Step 1 已把 bezier stroke 也改成 #0f172a,无需调整。

- [ ] **Step 4: 验证 + dev 走查**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

访问 workflow,预期:
- 连线为直角折线(非弯曲贝塞尔)
- 描边色 = 深石板 #0f172a,粗细 1.5px

如 dev 中节点位置错位,**rollback Step 2**(LogicFlow polyline 路径自动计算可能与 bezier 位置冲突),只保留 Step 1 颜色改动。

- [ ] **Step 5: Commit**

```bash
git add ui/src/workflow
git commit -m "refactor(ui): switch workflow edges to polyline + slate stroke (W1)"
```

---

### Task 16: 节点顶部 2px 色条 data-node-type 注入 + 12×12 类型方块 icon

**Files:**
- Modify: `ui/src/workflow/common/NodeContainer.vue`
- Modify: 多个 `ui/src/workflow/icons/*-node-icon.vue`(逐个或批量)

- [ ] **Step 1: 在 NodeContainer.vue 注入 data-node-type 属性**

找到 `<div class="step-container white-bg border-r-8 p-16" ...>` 节点,加 `:data-node-type="nodeModel.type"`:

```vue
<div
  class="step-container white-bg border-r-8 p-16"
  :data-node-type="nodeModel.type"
  :class="{ isSelected: props.nodeModel.isSelected, error: node_status !== 200 }"
  style="overflow: visible"
>
```

此举让 Task 14 的 SCSS 通过 `[data-node-type="..."]` 应用顶部色条。

- [ ] **Step 2: 节点 header icon 缩小到 12px 类型色实心方块**

`NodeContainer.vue` template 中找到 `<component :is="iconComponent(...)" :size="24" ...>`,改 size 24 → 16(若 component 本身渲染色块,缩小尺寸足以匹配 spec)。

如 :size 不被子 icon 组件接受为 prop,跳过 Step 2 并改在 SCSS 层用 `:deep()` 缩放:

```scss
/* 在 workflow.scss 末尾追加 */
.step-container .workflow-node-icon,
.step-container .el-avatar.workflow-node-icon {
  width: 16px !important;
  height: 16px !important;
  border-radius: 3px;
}
```

- [ ] **Step 3: 验证 + dev 走查**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

访问 workflow,预期:
- 每个节点顶部 2px 色条按节点类型(start=绿,ai-chat=紫,search-knowledge=蓝,condition=橙,reply=红)显示
- 节点 header icon 缩小到 16px 左右
- 控制台 0 errors

- [ ] **Step 4: Commit**

```bash
git add ui/src/workflow ui/src/styles/workflow.scss
git commit -m "feat(ui): inject node type into top-bar + shrink header icon (W1)"
```

---

### Task 17: 节点配置 模态 → 右侧 420px 抽屉

**Files:**
- Modify: 节点对应的配置 Dialog/Drawer 文件 — 需先调研

- [ ] **Step 1: 找到现有节点配置弹窗组件**

```bash
grep -rln "node-config\|NodeConfig\|节点配置" ui/src/workflow ui/src/views/application-workflow 2>/dev/null | head -10
```

大概率结果是某个 `NodeConfigDialog.vue` 或在 NodeContainer 内嵌的 `<el-dialog>`。记下文件路径。

- [ ] **Step 2: 改 Dialog 为 Drawer**

打开 Step 1 找到的文件,把:

```vue
<el-dialog v-model="visible" width="600px" ...>
  ...
</el-dialog>
```

替换为:

```vue
<el-drawer
  v-model="visible"
  :size="420"
  direction="rtl"
  :with-header="true"
  :modal="false"
  :title="nodeTitle"
>
  <template #default>
    <div class="node-config-body">
      <!-- 原 Dialog body 内容 -->
    </div>
  </template>
  <template #footer>
    <div class="node-config-footer">
      <el-button @click="$emit('cancel')">{{ $t('common.cancel') }}</el-button>
      <el-button type="primary" @click="$emit('save')">{{ $t('common.save') }}</el-button>
    </div>
  </template>
</el-drawer>
```

> 关键参数:`:size="420"` 抽屉宽度;`direction="rtl"` 从右侧出;`:modal="false"` 不遮罩画布。

- [ ] **Step 3: 检查 Drawer 内部内容样式**

旧 Dialog 内容用了固定 `width: 100%` 或 `el-row :gutter`,在 420px 抽屉下可能溢出。在抽屉内 wrap 加:

```scss
.node-config-body {
  padding: 16px 20px;
  overflow-y: auto;
}
.node-config-footer {
  padding: 12px 20px;
  border-top: 1px solid var(--border-base);
  text-align: right;
  & > .el-button + .el-button { margin-left: 8px; }
}
```

- [ ] **Step 4: 验证 + dev 走查**

```bash
cd ui && npm run type-check 2>&1 | tail -5
```

Expected: 退出码 0。

访问 workflow,双击任一节点或单击节点上配置图标,预期:
- 右侧滑出 420px 抽屉(非遮罩)
- 抽屉顶部 title 显示节点名
- 抽屉底部固定"取消 / 保存"按钮
- 同时仍可在画布上点其它节点(因 `:modal="false"`)

- [ ] **Step 5: Commit**

```bash
git add ui/src
git commit -m "refactor(ui): convert node config modal to right drawer (W1)"
```

---

## PE · 联合走查(1 Task)

### Task 18: 三页面 dev 走查 + 最终 commit

- [ ] **Step 1: 全门校验**

```bash
cd ui
npm run type-check 2>&1 | tail -10
npm run build 2>&1 | tail -10
```

Expected: 两者退出码 0。

- [ ] **Step 2: dev 路由走查**

```bash
cd ui && npm run dev
```

| 路由 | 预期 |
|------|------|
| `/admin/application/list` | Rail+Side(应用列表)+主区分组瀑布;每组带颜色条+计数+"+在 X 下新建"虚线卡;卡片单色字符头像;控制台 0 errors |
| `/admin/application/workspace/<id>/SIMPLE/overview` | Hero 横条 + 4 数据 tile(Lucide outline 单色 icon)+ 趋势图(可切指标)+ 紧凑访问面板 |
| `/admin/application/workspace/<id>/workflow` | 画布 20×20 浅网格;节点顶部 2px 类型色条;连线直角折线 #0f172a;双击节点 → 右 420px 抽屉(不遮画布) |

- [ ] **Step 3: 三语言抽检**

切换为 en-US / zh-Hant,重访三页面,确认新加文案(标签 / 分组 / Hero / stats / trend / access 等)均显示对应语言。

- [ ] **Step 4: 确认 apps/ 零改动**

```bash
git status apps/
```

Expected: 输出为空(`nothing to commit, working tree clean` 或无 `apps/` 行)。

- [ ] **Step 5: 30 秒辨认测试**

在浏览器开 `/admin/application/list`,自测:30 秒内能否反应出"这是 MaxKB"?

如能(说明仍有视觉残留),退到具体页面用 Chrome DevTools `inspect` 找出残留(常见:残留 #3370FF 蓝、紫机器人头像、`title-decoration-1` 装饰条等)→ 写 follow-up commit 修复。

- [ ] **Step 6: 最终汇总 commit(如有零散改动)**

```bash
git status
git add -A ui/
git commit -m "chore(ui): final PD/PA/PB/PC walkthrough and cleanup"
```

- [ ] **Step 7: 在 plan 文档底部记录完成情况**

更新本 plan 文档底部:

```markdown
## 完成记录

- **完成日期**:YYYY-MM-DD
- **分支**:`feat/frontend-redesign`
- **commit 链**:从 `<sha_t1>` 到 `<sha_t18>`,共 N 个 commit
- **自动门**:`npm run type-check` 退 0;`npm run build` 通过
- **手动验收**:三页面 dev 走查无错位;三语言抽检通过;`git diff apps/` 为空
- **范围调整 / 已知 gap**:(若有)
```

---

## 自审记录

**Spec coverage scan:**
- ✅ §3.1 列表 D2 → T4-T8 全覆盖
- ✅ §3.2 概览 G1 → T9-T13 全覆盖
- ✅ §3.3 工作流 W1 → T14-T17 全覆盖
- ✅ §4 跨页约定(StatusDot / AgentAvatar / card-unified)→ T1-T3 全覆盖
- ✅ §5 落地策略 + §8 完成定义 → T18 验收

**Placeholder scan:**
- T7/T13 中"以现有 file 里 import 的方法为准"是必要的:具体 API 方法名因项目状态不可枚举,但任务明确要求 grep 后照抄而非发明新方法,这是合理的"取决于代码现状"指令而非占位
- 无 "TBD" / "TODO" / 抽象描述未落地

**Type consistency:**
- `applications` / `folders` / `accessToken` 在 T6/T7/T13 中字段名一致
- `StatusDot` 接 `status: 'published' | 'draft' | 'archived'` 在 T1/T5/T9 三处用法一致
- `AgentAvatar` 接 `name: string; size?: number` 在 T2/T5/T9 三处用法一致
