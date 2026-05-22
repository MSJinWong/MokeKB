# 平台管理重设计实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"系统管理"拆为独立 Rail 项 + 重做 3 个活页（用户管理、资源授权、邮箱设置）+ 删除 12 个孤儿页及其 API/i18n/store 引用，全程保留 `workspace_id` 字段语义和后端零改动。

**Architecture:** 复用智能体重设计已落地的 atoms（`AgentAvatar` / `StatusDot` / `.card-unified`），新增 `<PageHeader>` Vue 组件、扩展 `<StatusDot>` 两个新 status key、新增 `.toolbar` SCSS 约定。Phase 顺序：先建 atoms → 重做活页 → 最后做毁灭性清理。

**Tech Stack:** Vue 3 + Element Plus + Pinia + vue-router + iconify (lucide) + SCSS + vue-i18n.

**Source spec:** `docs/superpowers/specs/2026-05-22-platform-management-redesign-design.md`

---

## Phase PA · IA + 原子（基础设施）

### Task PA1: 加 `system` Rail 模块 + i18n key

**Files:**
- Modify: `ui/src/layout/layout-rail/modules.ts`
- Modify: `ui/src/locales/lang/zh-CN/layout.ts`
- Modify: `ui/src/locales/lang/en-US/layout.ts`
- Modify: `ui/src/locales/lang/zh-Hant/layout.ts`

- [ ] **Step 1: 修改 modules.ts — platform 收 matchPaths + 加 system 项**

打开 `ui/src/layout/layout-rail/modules.ts`，替换 `RAIL_MODULES` 数组的最后一项 + 增加一项：

```ts
  {
    key: 'platform',
    titleKey: 'layout.rail.platform',
    lucide: 'settings-2',
    path: '/model',
    matchPaths: ['/model'],
  },
  {
    key: 'system',
    titleKey: 'layout.rail.system',
    lucide: 'shield-cog',
    path: '/system/user',
    matchPaths: ['/system'],
  },
]
```

把原来的 `matchPaths: ['/model', '/system']` 收回为 `['/model']`。

- [ ] **Step 2: 修改 zh-CN/layout.ts — 改 platform 值 + 加 system key**

打开 `ui/src/locales/lang/zh-CN/layout.ts`，在 `rail:` 对象里：

```ts
  rail: {
    aria: '主导航',
    workbench: '工作台',
    agent: '智能体',
    knowledge: '知识资产',
    capability: '能力扩展',
    platform: '模型',
    system: '系统管理',
  },
```

`platform` 从 `'平台管理'` 改为 `'模型'`（因为现在 Rail 平台只跳 /model），新增 `system: '系统管理'`。

- [ ] **Step 3: 修改 en-US/layout.ts**

打开 `ui/src/locales/lang/en-US/layout.ts`，在 `rail:` 对象里把 `platform` 改成 `'Models'`，新增 `system: 'System'`：

```ts
  rail: {
    aria: 'Main navigation',
    workbench: 'Workbench',
    agent: 'Agents',
    knowledge: 'Knowledge',
    capability: 'Capabilities',
    platform: 'Models',
    system: 'System',
  },
```

如果原来键的英文译文不完全相同，按文件中实际的英文翻译风格保留其它键，只改 `platform` + 加 `system`。

- [ ] **Step 4: 修改 zh-Hant/layout.ts**

打开 `ui/src/locales/lang/zh-Hant/layout.ts`，在 `rail:` 对象里把 `platform` 改成 `'模型'`，新增 `system: '系統管理'`。

- [ ] **Step 5: type-check + dev server 验证**

```bash
cd ui && npm run type-check
```

期望：退出码 0。

```bash
npm run dev
```

打开 `http://localhost:<port>`，Rail 应当显示 **6 项**：工作台 / 智能体 / 知识资产 / 能力扩展 / **模型** / **系统管理**。点"系统管理"图标 → 跳到 `/system/user`。

- [ ] **Step 6: Commit**

```bash
git add ui/src/layout/layout-rail/modules.ts ui/src/locales/lang
git commit -m "feat(ui): add System rail module + rename Platform→Models i18n"
```

---

### Task PA2: 新建 `<PageHeader>` 组件

**Files:**
- Create: `ui/src/components/page-header/PageHeader.vue`
- Create: `ui/src/components/page-header/index.ts`

- [ ] **Step 1: 写 PageHeader.vue**

新建文件 `ui/src/components/page-header/PageHeader.vue`：

```vue
<template>
  <header class="page-header">
    <div class="page-header__main">
      <el-button
        v-if="showBack"
        link
        class="page-header__back"
        @click="$emit('back')"
        :aria-label="$t('common.back')"
      >
        <LucideIcon name="arrow-left" :size="18" />
      </el-button>
      <div class="page-header__text">
        <h2 class="page-header__title">{{ title }}</h2>
        <div v-if="$slots.subtitle || subtitle" class="page-header__subtitle">
          <slot name="subtitle">{{ subtitle }}</slot>
        </div>
      </div>
    </div>
    <div v-if="$slots.actions" class="page-header__actions">
      <slot name="actions" />
    </div>
  </header>
</template>

<script setup lang="ts">
import { LucideIcon } from '@/components/lucide-icon'

withDefaults(
  defineProps<{
    title: string
    subtitle?: string
    showBack?: boolean
  }>(),
  { showBack: false }
)

defineEmits<{ (e: 'back'): void }>()
</script>

<style lang="scss" scoped>
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 0 12px;
  margin-bottom: 16px;
  min-height: 56px;
}
.page-header__main {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  flex: 1;
}
.page-header__back {
  flex-shrink: 0;
  padding: 4px;
}
.page-header__text { min-width: 0; }
.page-header__title {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.4;
  margin: 0;
}
.page-header__subtitle {
  font-size: 12px;
  font-weight: 400;
  color: var(--text-secondary);
  margin-top: 2px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.page-header__actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
</style>
```

- [ ] **Step 2: 写 index.ts re-export**

新建文件 `ui/src/components/page-header/index.ts`：

```ts
import PageHeader from './PageHeader.vue'
export { PageHeader }
export default PageHeader
```

- [ ] **Step 3: type-check 验证**

```bash
cd ui && npm run type-check
```

期望：退出码 0。

- [ ] **Step 4: Commit**

```bash
git add ui/src/components/page-header
git commit -m "feat(ui): add PageHeader atom for management pages"
```

---

### Task PA3: 扩展 `<StatusDot>` 支持 enabled/disabled

**Files:**
- Modify: `ui/src/components/status-dot/StatusDot.vue`

- [ ] **Step 1: 编辑 StatusDot.vue 扩展 type + CSS**

打开 `ui/src/components/status-dot/StatusDot.vue`，替换其中 type 声明 + statusText 计算 + CSS：

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

type StatusKey = 'published' | 'draft' | 'archived' | 'enabled' | 'disabled'

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
    case 'enabled': return t('common.status.enabled')
    case 'disabled': return t('common.status.disabled')
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
.status-dot--enabled .status-dot__bullet { color: #10b981; }
.status-dot--disabled .status-dot__bullet { color: #94a3b8; }
</style>
```

- [ ] **Step 2: type-check 验证**

```bash
cd ui && npm run type-check
```

期望：退出码 0。

- [ ] **Step 3: Commit**

```bash
git add ui/src/components/status-dot/StatusDot.vue
git commit -m "feat(ui): extend StatusDot with enabled/disabled keys"
```

---

### Task PA4: 加 `.toolbar` SCSS 约定

**Files:**
- Modify: `ui/src/styles/component.scss`

- [ ] **Step 1: 在 component.scss 末尾追加 .toolbar 规则**

打开 `ui/src/styles/component.scss`，在 `.card-unified { ... }` 块之后追加：

```scss
/* ===== 工具栏(批量操作 + 搜索/筛选)===== */
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-base);

  &__left,
  &__right {
    display: flex;
    align-items: center;
    gap: 8px;
  }
}
```

- [ ] **Step 2: 验证 SCSS 编译**

```bash
cd ui && npm run build
```

期望：编译通过，无 SCSS 错误。

- [ ] **Step 3: Commit**

```bash
git add ui/src/styles/component.scss
git commit -m "feat(ui): add .toolbar SCSS convention for mgmt pages"
```

---

### Task PA5: `/system` 切到 MainLayout + 去 hidden

**Files:**
- Modify: `ui/src/router/modules/system.ts`

- [ ] **Step 1: 修改 systemRouter 顶层定义**

打开 `ui/src/router/modules/system.ts`，把开头的 systemRouter 顶层定义改为：

```ts
const systemRouter = {
  path: '/system',
  name: 'system',
  meta: { title: 'views.system.title' },
  component: () => import('@/layout/layout-template/MainLayout.vue'),
  children: [
    // ... 保留所有现有 children 不动（本任务只改外壳，clean-up 留到 PE6）
```

去掉 `hidden: true`，把 component 从 `SystemMainLayout.vue` 改成 `MainLayout.vue`。

- [ ] **Step 2: type-check 验证**

```bash
cd ui && npm run type-check
```

期望：退出码 0。

- [ ] **Step 3: dev server 验证**

```bash
cd ui && npm run dev
```

浏览器打开 `http://localhost:<port>/system/user`：
- 左侧应显示 Rail（6 项，"系统管理"高亮）
- 中间显示 Side（按 system 路由的 children 展开 — 此时还有所有未删的子菜单，**正常**，下一 Phase 才删）
- 右侧显示用户管理页（旧样式 OK，PB 才重做）

- [ ] **Step 4: 删除 SystemMainLayout.vue 之前先 grep 引用**

```bash
grep -rn "SystemMainLayout" ui/src
```

期望：除 system.ts 之外，不应有其它文件 import 它（system.ts 在 Step 1 已改为 MainLayout）。

- [ ] **Step 5: 删除 SystemMainLayout.vue**

```bash
rm ui/src/layout/layout-template/SystemMainLayout.vue
```

- [ ] **Step 6: type-check + build 双验证**

```bash
cd ui && npm run type-check && npm run build
```

期望：均通过。

- [ ] **Step 7: Commit**

```bash
git add -A ui/src/router/modules/system.ts ui/src/layout/layout-template
git commit -m "refactor(ui): /system uses MainLayout; drop SystemMainLayout"
```

---

## Phase PB · 用户管理重做

### Task PB1: 重写用户管理页

**Files:**
- Modify: `ui/src/views/system/user-manage/index.vue`

- [ ] **Step 1: 看一下当前 user-manage 的 import 块**

```bash
grep -n "^import\|^from" ui/src/views/system/user-manage/index.vue | head -20
```

记下当前的 import 风格。

- [ ] **Step 2: 替换 template + 调整 script imports**

打开 `ui/src/views/system/user-manage/index.vue`，替换整个 `<template>` 部分：

```vue
<template>
  <div class="user-manage">
    <PageHeader
      :title="$t('views.userManage.title')"
      :subtitle="`${$t('views.userManage.title')} · ${$t('common.total', { n: paginationConfig.total })}`"
    >
      <template #actions>
        <el-button
          v-if="user.isPE() || user.isEE()"
          :disabled="multipleSelection.length === 0"
          @click="setUserRoles"
          v-hasPermission="[RoleConst.ADMIN, PermissionConst.USER_EDIT]"
        >
          {{ $t('views.userManage.settingRole') }}
        </el-button>
        <el-button
          :disabled="multipleSelection.length === 0"
          @click="handleBatchDelete"
          v-hasPermission="[RoleConst.ADMIN, PermissionConst.USER_DELETE]"
        >
          {{ $t('common.delete') }}
        </el-button>
        <el-button
          type="primary"
          @click="createUser"
          v-hasPermission="[RoleConst.ADMIN, PermissionConst.USER_CREATE]"
        >
          {{ $t('views.userManage.createUser') }}
        </el-button>
      </template>
    </PageHeader>

    <div class="card-unified user-manage__card">
      <div class="toolbar">
        <div class="toolbar__left"></div>
        <div class="toolbar__right complex-search">
          <el-select
            class="complex-search__left"
            v-model="search_type"
            style="width: 120px"
            @change="search_type_change"
          >
            <el-option :label="$t('views.login.loginForm.username.label')" value="username" />
            <el-option :label="$t('views.userManage.userForm.nick_name.label')" value="nick_name" />
            <el-option :label="$t('views.login.loginForm.email.label')" value="email" />
            <el-option :label="$t('common.status.label')" value="is_active" />
            <el-option
              v-if="user.isEE() || user.isPE()"
              :label="$t('views.userManage.source.label')"
              value="source"
            />
          </el-select>
          <el-input
            v-if="search_type === 'username'"
            v-model="search_form.username"
            @change="getList"
            style="width: 220px"
            clearable
            :placeholder="$t('common.inputPlaceholder')"
          />
          <el-input
            v-else-if="search_type === 'nick_name'"
            v-model="search_form.nick_name"
            @change="getList"
            style="width: 220px"
            clearable
            :placeholder="$t('common.inputPlaceholder')"
          />
          <el-input
            v-else-if="search_type === 'email'"
            v-model="search_form.email"
            @change="getList"
            style="width: 220px"
            clearable
            :placeholder="$t('common.inputPlaceholder')"
          />
          <el-select
            v-else-if="search_type === 'is_active'"
            v-model="search_form.is_active"
            @change="getList"
            clearable
            style="width: 220px"
          >
            <el-option :label="$t('common.status.enabled')" :value="true" />
            <el-option :label="$t('common.status.disabled')" :value="false" />
          </el-select>
          <el-select
            v-else-if="search_type === 'source'"
            v-model="search_form.source"
            @change="getList"
            style="width: 220px"
            clearable
            :placeholder="$t('common.inputPlaceholder')"
          >
            <el-option :label="$t('views.userManage.source.local')" value="LOCAL" />
            <el-option label="CAS" value="CAS" />
            <el-option label="LDAP" value="LDAP" />
            <el-option label="OIDC" value="OIDC" />
            <el-option label="OAuth2" value="OAuth2" />
            <el-option :label="$t('views.userManage.source.wecom')" value="wecom" />
            <el-option :label="$t('views.userManage.source.lark')" value="lark" />
            <el-option :label="$t('views.userManage.source.dingtalk')" value="dingtalk" />
          </el-select>
        </div>
      </div>

      <app-table
        :data="userTableData"
        :pagination-config="paginationConfig"
        @sizeChange="handleSizeChange"
        @changePage="getList"
        v-loading="loading"
        @selection-change="handleSelectionChange"
        :maxTableHeight="280"
      >
        <el-table-column type="selection" width="55" />
        <el-table-column
          prop="nick_name"
          :label="$t('views.userManage.userForm.nick_name.label')"
          min-width="200"
          show-overflow-tooltip
        >
          <template #default="{ row }">
            <div class="flex align-center">
              <AgentAvatar :name="row.nick_name" :size="24" class="mr-8" />
              <span>{{ row.nick_name }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column
          prop="username"
          min-width="180"
          show-overflow-tooltip
          :label="$t('views.login.loginForm.username.label')"
        />
        <el-table-column width="120" prop="is_active" :label="$t('common.status.label')">
          <template #default="{ row }">
            <StatusDot :status="row.is_active ? 'enabled' : 'disabled'" />
          </template>
        </el-table-column>
        <el-table-column
          prop="email"
          :label="$t('views.login.loginForm.email.label')"
          show-overflow-tooltip
          min-width="200"
        >
          <template #default="{ row }">
            {{ row.email || '-' }}
          </template>
        </el-table-column>
        <el-table-column
          prop="phone"
          width="120"
          :label="$t('views.userManage.userForm.phone.label')"
        >
          <template #default="{ row }">
            {{ row.phone || '-' }}
          </template>
        </el-table-column>
        <el-table-column
          prop="role_name"
          :label="$t('views.role.member.role')"
          width="220"
          v-if="user.isEE() || user.isPE()"
        >
          <template #default="{ row }">
            <el-popover :width="500" :persistent="false">
              <template #reference>
                <TagGroup class="cursor" :tags="row.role_name" tooltipDisabled />
              </template>
              <template #default>
                <el-table
                  :data="row.role_workspace"
                  :max-height="300"
                  :tooltip-options="{ popperClass: 'max-w-350' }"
                >
                  <el-table-column
                    prop="role"
                    :label="$t('views.role.member.role')"
                    width="200"
                    show-overflow-tooltip
                  />
                  <el-table-column
                    prop="workspace"
                    :label="$t('views.workspace.title')"
                    show-overflow-tooltip
                  />
                </el-table>
              </template>
            </el-popover>
          </template>
        </el-table-column>
        <el-table-column prop="source" width="120" :label="$t('views.userManage.source.label')">
          <template #default="{ row }">
            {{ formatSource(row.source) }}
          </template>
        </el-table-column>
        <el-table-column :label="$t('common.createTime')" width="180">
          <template #default="{ row }">
            {{ datetimeFormat(row.create_time) }}
          </template>
        </el-table-column>
        <el-table-column :label="$t('common.operation')" width="160" align="left" fixed="right">
          <template #default="{ row }">
            <span @click.stop>
              <el-switch
                :disabled="row.role === 'ADMIN' || row.id === user.userInfo?.id"
                size="small"
                v-model="row.is_active"
                :before-change="() => changeState(row)"
                v-if="hasPermission([RoleConst.ADMIN, PermissionConst.USER_EDIT], 'OR')"
              />
            </span>
            <el-tooltip
              effect="dark"
              :content="$t('common.edit')"
              placement="top"
              v-if="hasPermission([RoleConst.ADMIN, PermissionConst.USER_EDIT], 'OR')"
            >
              <el-button
                type="primary"
                text
                @click.stop="editUser(row)"
                :title="$t('common.edit')"
              >
                <LucideIcon name="pencil" :size="16" />
              </el-button>
            </el-tooltip>
            <el-tooltip
              effect="dark"
              :content="$t('views.userManage.setting.updatePwd')"
              placement="top"
              v-if="hasPermission([RoleConst.ADMIN, PermissionConst.USER_EDIT], 'OR')"
            >
              <el-button
                type="primary"
                text
                @click.stop="editPwdUser(row)"
                :title="$t('views.userManage.setting.updatePwd')"
              >
                <LucideIcon name="key" :size="16" />
              </el-button>
            </el-tooltip>
            <el-tooltip
              effect="dark"
              :content="$t('common.delete')"
              placement="top"
              v-if="hasPermission([RoleConst.ADMIN, PermissionConst.USER_DELETE], 'OR')"
            >
              <el-button
                :disabled="row.role === 'ADMIN' || row.id === user.userInfo?.id"
                type="primary"
                text
                @click.stop="deleteUserManage(row)"
                :title="$t('common.delete')"
              >
                <LucideIcon name="trash-2" :size="16" />
              </el-button>
            </el-tooltip>
          </template>
        </el-table-column>
      </app-table>
    </div>

    <UserDrawer :title="title" ref="UserDrawerRef" @refresh="refresh" />
    <UserPwdDialog ref="UserPwdDialogRef" @refresh="refresh" />
    <SetUserRoleDialog ref="setUserRoleRef" @refresh="refresh" />
  </div>
</template>
```

- [ ] **Step 3: 调整 script imports（加 PageHeader / AgentAvatar / StatusDot / LucideIcon）**

打开 `ui/src/views/system/user-manage/index.vue` 的 `<script lang="ts" setup>` 块顶部 import 区，**加入**以下 import（其它 import 保留）：

```ts
import { PageHeader } from '@/components/page-header'
import { AgentAvatar } from '@/components/agent-avatar'
import { StatusDot } from '@/components/status-dot'
import { LucideIcon } from '@/components/lucide-icon'
```

把现有这些 import **删除**（不再用）：

```ts
// 删除： import { SuccessFilled } from '@element-plus/icons-vue'  （如果有）
// 删除： 任何对 AppIcon 的局部 import（AppIcon 是全局注册的可不删 import，但模板里已不用）
```

- [ ] **Step 4: 加 formatSource 辅助函数到 script 末尾**

在 `<script setup>` 中 onMounted 调用之前，添加：

```ts
function formatSource(source: string): string {
  switch (source) {
    case 'LOCAL': return t('views.userManage.source.local')
    case 'wecom': return t('views.userManage.source.wecom')
    case 'lark': return t('views.userManage.source.lark')
    case 'dingtalk': return t('views.userManage.source.dingtalk')
    case 'OAUTH2':
    case 'OAuth2': return 'OAuth2'
    default: return source
  }
}
```

- [ ] **Step 5: 加 user-manage 局部样式**

替换 `<style lang="scss" scoped>` 块（原来是空的）：

```vue
<style lang="scss" scoped>
.user-manage {
  padding: 0 24px 24px;
}
.user-manage__card {
  overflow: hidden;
}
</style>
```

- [ ] **Step 6: 确认 common.total i18n key 存在**

```bash
grep -rn "total:" ui/src/locales/lang/zh-CN/common.ts
```

如果不存在 `common.total`（带 `{n}` 占位），先添加：

`ui/src/locales/lang/zh-CN/common.ts`（在 common 对象内）：
```ts
total: '共 {n} 人',
```

`en-US/common.ts`：
```ts
total: 'Total {n}',
```

`zh-Hant/common.ts`：
```ts
total: '共 {n} 人',
```

或者 — 如果你想避免新 key — 把 PageHeader 的 subtitle 改成简单字符串，例如：
```ts
:subtitle="`${$t('views.userManage.title')} · ${paginationConfig.total}`"
```

实施者选择其一。

- [ ] **Step 7: type-check + build 验证**

```bash
cd ui && npm run type-check && npm run build
```

期望：均通过。

- [ ] **Step 8: dev server 走查**

```bash
cd ui && npm run dev
```

打开 `/system/user`：
- 顶部 PageHeader（标题 + 总数 + 右侧 3 按钮）
- toolbar 行（搜索类型 + 搜索框）
- 表格行显示 AgentAvatar + StatusDot + LucideIcon 三种新原子
- 切换启用/停用 switch 工作
- 点编辑/改密/删除按钮触发对应 dialog

- [ ] **Step 9: Commit**

```bash
git add ui/src/views/system/user-manage ui/src/locales/lang
git commit -m "refactor(ui): rebuild user-manage with PageHeader+atoms"
```

---

## Phase PC · 资源授权重做

### Task PC1: 重写资源授权页（PageHeader + 4 Tab 切资源类型）

**Files:**
- Modify: `ui/src/views/system/resource-authorization/index.vue`
- Modify: `ui/src/views/system/resource-authorization/constant.ts`（仅在需要新增 resourceType meta 时；先读）

- [ ] **Step 1: 读 constant.ts 了解 resource type 列表**

```bash
cat ui/src/views/system/resource-authorization/constant.ts
```

记下 4 个 resource 的 key（`APPLICATION` / `KNOWLEDGE` / `TOOL` / `MODEL`）和对应 label。

- [ ] **Step 2: 替换 template — PageHeader + Tabs + 现有左右分栏**

打开 `ui/src/views/system/resource-authorization/index.vue`，替换 `<template>`：

```vue
<template>
  <div class="resource-authorization">
    <PageHeader
      :title="$t('views.system.resourceAuthorization.title')"
      :subtitle="activeData.label"
    >
      <template #actions>
        <WorkspaceDropdown
          v-if="hasPermission(EditionConst.IS_EE, 'OR')"
          :data="workspaceList"
          :currentWorkspace="currentWorkspace"
          @changeWorkspace="changeWorkspace"
        />
      </template>
    </PageHeader>

    <el-tabs
      v-model="currentResource"
      class="resource-authorization__tabs"
      @tab-click="onTabClick"
    >
      <el-tab-pane
        v-for="t in resourceTabs"
        :key="t.key"
        :label="t.label"
        :name="t.key"
      />
    </el-tabs>

    <div class="card-unified resource-authorization__card">
      <div class="flex">
        <div class="resource-authorization__left border-r">
          <div class="p-24 pb-0">
            <h4 class="mb-12">{{ $t('views.system.resourceAuthorization.member') }}</h4>
            <el-input
              v-model="filterText"
              :placeholder="$t('common.search')"
              prefix-icon="Search"
              clearable
            />
          </div>
          <div class="list-height-left">
            <el-scrollbar>
              <div class="p-8-16">
                <common-list
                  :data="filterMember"
                  v-loading="loading"
                  @click="clickMemberHandle"
                  :default-active="currentUser"
                >
                  <template #default="{ row }">
                    <div class="flex-between">
                      <div class="flex">
                        <span class="mr-8 ellipsis-1" :title="row.nick_name">{{
                          i18n_name(row.nick_name)
                        }}</span>
                        <el-text
                          class="color-input-placeholder ellipsis-1"
                          :title="row.roles.join('，')"
                          v-if="hasPermission([EditionConst.IS_EE, EditionConst.IS_PE], 'OR')"
                        >({{
                          row.roles.map((item: any) => i18n_name(item))?.join('，')
                        }})</el-text>
                      </div>
                    </div>
                  </template>
                </common-list>
              </div>
            </el-scrollbar>
          </div>
        </div>
        <PermissionTable
          :data="treeData"
          :type="activeData.type"
          ref="PermissionTableRef"
          :getData="getPermissionList"
          @submitPermissions="submitPermissions"
        />
      </div>
    </div>
  </div>
</template>
```

- [ ] **Step 3: 替换 script — 加 PageHeader/LucideIcon import + tabs 逻辑**

打开同文件的 `<script lang="ts" setup>` 块，在 import 区**加入**：

```ts
import { ref, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PageHeader } from '@/components/page-header'
```

确保已有的其它 import（`PermissionTable`、`WorkspaceDropdown`、`AuthorizationApi`、`MsgSuccess` 等）保留。

在 `script setup` 内、`route` 定义之后增加：

```ts
const router = useRouter()

interface ResourceTab { key: string; label: string }
const resourceTabs = computed<ResourceTab[]>(() => [
  { key: 'APPLICATION', label: t('views.application.title') },
  { key: 'KNOWLEDGE', label: t('views.knowledge.title') },
  { key: 'TOOL', label: t('views.tool.title') },
  { key: 'MODEL', label: t('views.model.title') },
])

const currentResource = ref<string>((route.meta.resource as string) || 'APPLICATION')

watch(() => route.meta.resource, (v) => {
  if (typeof v === 'string') currentResource.value = v
})

const routeMap: Record<string, string> = {
  APPLICATION: '/system/authorization/application',
  KNOWLEDGE: '/system/authorization/knowledge',
  TOOL: '/system/authorization/tool',
  MODEL: '/system/authorization/model',
}

function onTabClick(tab: any) {
  const path = routeMap[tab.props.name]
  if (path && path !== route.path) router.push(path)
}
```

- [ ] **Step 4: 删除原 template 顶部的 el-breadcrumb 部分（已由 PageHeader 替代）**

在 Step 2 替换 template 时已完成。确认新 template 里**没有** `<el-breadcrumb>` 残留。

- [ ] **Step 5: 替换 style（去原 el-card 边距相关）**

打开 `<style lang="scss" scoped>` 块，替换为：

```scss
<style lang="scss" scoped>
.resource-authorization {
  padding: 0 24px 24px;
}
.resource-authorization__tabs {
  margin-bottom: 12px;
}
.resource-authorization__card {
  overflow: hidden;
  height: calc(100vh - 200px);
}
.resource-authorization__left {
  width: 280px;
  flex-shrink: 0;
}
.list-height-left {
  height: calc(100% - 100px);
}
</style>
```

- [ ] **Step 6: type-check + build 验证**

```bash
cd ui && npm run type-check && npm run build
```

期望：均通过。

- [ ] **Step 7: dev server 走查**

```bash
cd ui && npm run dev
```

打开 `/system/authorization/application`：
- 顶部 PageHeader（含 actions slot 显示 EE-only WorkspaceDropdown）
- Tabs 显示 4 个资源类型，当前 application 高亮
- 点 "知识库" tab → URL 跳到 `/system/authorization/knowledge`，PermissionTable 重新加载
- 浏览器后退按钮 → 回到 `/system/authorization/application`
- 左侧成员列表 + 搜索 + 选择 + 右侧 PermissionTable 提交都工作

- [ ] **Step 8: Commit**

```bash
git add ui/src/views/system/resource-authorization
git commit -m "refactor(ui): rebuild resource-authorization with PageHeader+tabs"
```

---

## Phase PD · 邮箱设置轻量打磨

### Task PD1: 重做邮箱设置页

**Files:**
- Modify: `ui/src/views/system-setting/email/index.vue`

- [ ] **Step 1: 读当前 email/index.vue 全文**

```bash
cat ui/src/views/system-setting/email/index.vue | head -80
```

记下 template 上层结构 + 哪个按钮触发 save / test。

- [ ] **Step 2: 复制原 form 代码到剪贴板**

```bash
sed -n '/<el-form/,/<\/el-form>/p' ui/src/views/system-setting/email/index.vue
```

把输出（完整的 `<el-form ... > ... </el-form>` 块）记下，下一步原封不动粘贴。

如果文件里有多个 form / 嵌套，按外层 form 算。

- [ ] **Step 3: 重写 template — 套 PageHeader + .card-unified + 原 form**

打开 `ui/src/views/system-setting/email/index.vue`，把整个 `<template>` 替换为：

```vue
<template>
  <div class="email-setting" v-loading="loading">
    <PageHeader
      :title="$t('views.system.email.title')"
      :subtitle="$t('views.system.email.subtitle')"
    >
      <template #actions>
        <el-button @click="testConnection">
          {{ $t('views.system.email.testConnection') }}
        </el-button>
        <el-button type="primary" @click="save">
          {{ $t('common.save') }}
        </el-button>
      </template>
    </PageHeader>

    <div class="card-unified email-setting__card p-24">
      <!-- 把 Step 2 复制的 <el-form ...> ... </el-form> 块粘贴到这里 -->
    </div>
  </div>
</template>
```

**操作要点**：
- Step 2 复制的 form 块原封不动粘贴到注释位置（替换掉注释）
- 表单内部的 `<el-form-item>`、`v-model`、`rules`、字段名一律保留
- 如果原 form 内有保存 / 测试连接按钮，把它们**移除**（已挪到 PageHeader actions slot）
- 删除原 template 中的 `<el-breadcrumb>` 和外层 / 嵌套的 `<el-card>` 壳
- 原 `save` / `testConnection` 函数在 `<script>` 中不动；template 里改为 PageHeader actions 中调用

- [ ] **Step 4: 加 PageHeader import**

在 `<script setup>` 顶部加：

```ts
import { PageHeader } from '@/components/page-header'
```

- [ ] **Step 5: 替换 style block**

```vue
<style lang="scss" scoped>
.email-setting {
  padding: 0 24px 24px;
}
.email-setting__card {
  max-width: 800px;
}
</style>
```

- [ ] **Step 6: 检查 i18n key 存在**

```bash
grep -n "email.subtitle\|email.testConnection" ui/src/locales/lang/zh-CN/views/system.ts 2>/dev/null
```

如不存在，先在 `views.system.email` 对象下加：
- zh-CN: `subtitle: '配置系统邮件服务'`, `testConnection: '测试连接'`
- en-US: `subtitle: 'Configure system mail service'`, `testConnection: 'Test connection'`
- zh-Hant: `subtitle: '配置系統郵件服務'`, `testConnection: '測試連接'`

- [ ] **Step 7: type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

期望：均通过。

- [ ] **Step 8: dev server 走查**

打开 `/system/email`：
- PageHeader（标题 / 副信息 / 测试连接 + 保存按钮）
- 表单字段不变
- 点保存能 trigger 既有 save 逻辑
- 点测试连接能 trigger 既有 test 逻辑

- [ ] **Step 9: Commit**

```bash
git add ui/src/views/system-setting/email ui/src/locales/lang
git commit -m "refactor(ui): polish email-setting with PageHeader+card-unified"
```

---

## Phase PE · 删除清理（毁灭性 — 最后做）

### Task PE1: 删除 8 个孤儿视图目录

**Files:**
- Delete: `ui/src/views/system/workspace/`
- Delete: `ui/src/views/system/role/`
- Delete: `ui/src/views/system/operate-log/`
- Delete: `ui/src/views/system-resource-management/`
- Delete: `ui/src/views/system-shared/`
- Delete: `ui/src/views/system-chat-user/`
- Delete: `ui/src/views/system-setting/theme/`
- Delete: `ui/src/views/system-setting/authentication/`

- [ ] **Step 1: 在删除前 grep 确认这些目录的 import 引用**

```bash
grep -rn "views/system/workspace\|views/system/role\|views/system/operate-log\|views/system-resource-management\|views/system-shared\|views/system-chat-user\|views/system-setting/theme\|views/system-setting/authentication" ui/src
```

预期：唯一引用方应当只是 `ui/src/router/modules/system.ts`（在 PE6 一并清）。

- [ ] **Step 2: 删除 8 个目录**

```bash
rm -rf ui/src/views/system/workspace
rm -rf ui/src/views/system/role
rm -rf ui/src/views/system/operate-log
rm -rf ui/src/views/system-resource-management
rm -rf ui/src/views/system-shared
rm -rf ui/src/views/system-chat-user
rm -rf ui/src/views/system-setting/theme
rm -rf ui/src/views/system-setting/authentication
```

- [ ] **Step 3: 验证 build 期望失败（因为 router 还引用了被删的 view）**

```bash
cd ui && npm run build
```

预期：**编译会失败**，提示找不到刚删的 view 文件。这是正常的，下一 task (PE6) 会清 router 引用。

不 commit。继续做 PE2-PE5，再做 PE6 之后才能 build 通过。

---

### Task PE2: 删除孤儿 API client 文件

**Files:**
- Delete: `ui/src/api/system/role.ts`
- Delete: `ui/src/api/system/operate-log.ts`
- Delete: `ui/src/api/system/chat-user.ts`
- Delete: `ui/src/api/system/user-group.ts`
- Delete: `ui/src/api/system/auth.ts`
- Delete: `ui/src/api/system/api-key.ts`
- Delete: `ui/src/api/system/platform-source.ts`
- Delete: `ui/src/api/system-resource-management/`（整目录）
- Delete: `ui/src/api/system-shared/`（整目录）
- Delete: `ui/src/api/system-settings/theme.ts`
- Delete: `ui/src/api/system-settings/auth-setting.ts`
- Delete: `ui/src/api/system-settings/platform-source.ts`

- [ ] **Step 1: 删除前 grep 各文件的 import 引用**

```bash
for f in role operate-log chat-user user-group auth api-key platform-source; do
  echo "=== api/system/$f ===";
  grep -rn "api/system/$f" ui/src --include="*.ts" --include="*.vue";
done
for f in theme auth-setting platform-source; do
  echo "=== api/system-settings/$f ===";
  grep -rn "api/system-settings/$f" ui/src --include="*.ts" --include="*.vue";
done
echo "=== api/system-resource-management ===";
grep -rn "api/system-resource-management" ui/src --include="*.ts" --include="*.vue";
echo "=== api/system-shared ===";
grep -rn "api/system-shared" ui/src --include="*.ts" --include="*.vue";
```

如果输出里出现**除了被删 view 之外**的其它 import 来源（比如 `dynamics-api/`），暂停 → 报告人工分析。否则继续。

- [ ] **Step 2: 删除 14 个 API client**

```bash
rm ui/src/api/system/role.ts
rm ui/src/api/system/operate-log.ts
rm ui/src/api/system/chat-user.ts
rm ui/src/api/system/user-group.ts
rm ui/src/api/system/auth.ts
rm ui/src/api/system/api-key.ts
rm ui/src/api/system/platform-source.ts
rm -rf ui/src/api/system-resource-management
rm -rf ui/src/api/system-shared
rm ui/src/api/system-settings/theme.ts
rm ui/src/api/system-settings/auth-setting.ts
rm ui/src/api/system-settings/platform-source.ts
```

- [ ] **Step 3: 检查 dynamics-api 是否引用了被删的 API**

```bash
grep -rn "role.ts\|operate-log.ts\|chat-user.ts\|user-group.ts\|api-key.ts\|theme.ts\|auth-setting" ui/src/utils/dynamics-api
```

如有引用，记录下来；这些会在 PE5/PE6 阶段统一清。本步不 commit。

---

### Task PE3: 清理 theme store + user.ts theme 调用

**Files:**
- Modify: `ui/src/stores/modules/theme.ts`
- Modify: `ui/src/stores/modules/user.ts`

- [ ] **Step 1: 简化 theme.ts**

打开 `ui/src/stores/modules/theme.ts`，把整个 store 替换为：

```ts
import { defineStore } from 'pinia'
import { cloneDeep } from 'lodash'
import { defaultPlatformSetting } from '@/utils/theme'

export interface themeStateTypes {
  themeInfo: any
}

const useThemeStore = defineStore('theme', {
  state: (): themeStateTypes => ({
    themeInfo: { ...defaultPlatformSetting },
  }),
  actions: {
    isDefaultTheme() {
      return true
    },
    setTheme(data?: any) {
      this.themeInfo = data ? cloneDeep(data) : { ...defaultPlatformSetting }
    },
  },
})

export default useThemeStore
```

去掉对 `@/api/system-settings/theme` 的 import 和 `theme()` action。

- [ ] **Step 2: 改 user.ts 去掉 EE/PE 分支拉 themeInfo 的逻辑**

打开 `ui/src/stores/modules/user.ts` 第 146-154 行附近，替换为：

```ts
            this.license_is_valid = ok.data.license_is_valid
            this.edition = ok.data.edition
            this.version = ok.data.version
            this.rsaKey = ok.data.rsa
            const theme = useThemeStore()
            theme.setTheme()
            resolve(ok)
```

去掉 `if (this.isEE() || this.isPE()) { await theme.theme() } else { ... }` 的分支判断 — 一律走默认。

- [ ] **Step 3: 验证 LogoFull / top-about / login 页仍能从 defaultPlatformSetting 拿到值**

```bash
grep -n "themeInfo?.loginLogo\|themeInfo?.theme\|themeInfo?.slogan\|themeInfo?.showUserManual" ui/src
```

预期：所有引用都是 `?.` defensive；defaultPlatformSetting 缺这些字段（如 `loginLogo` 默认是空）时走 fallback 路径。

不 commit。

---

### Task PE4: workspace.ts API client 逐方法处理

**Files:**
- Modify: `ui/src/api/system/workspace.ts`

- [ ] **Step 1: grep 每个方法的引用**

```bash
for fn in getWorkspaceListByUser getWorkspaceList getSystemWorkspaceList CreateOrUpdateWorkspace deleteWorkspaceCheck deleteWorkspace; do
  echo "=== $fn ==="
  grep -rn "$fn" ui/src --include="*.ts" --include="*.vue"
done
```

- [ ] **Step 2: 重写 workspace.ts 保留有引用的方法，其它删**

打开 `ui/src/api/system/workspace.ts`。根据 Step 1 的引用结果决定：

- 如果 `getWorkspaceListByUser` 在 layout-header / WorkspaceDropdown / 其它仍存活的地方被调用 → **保留但改为返回静态默认**：

```ts
const getWorkspaceListByUser: (loading?: Ref<boolean>) => Promise<Result<WorkspaceItem[]>> = (loading) => {
  // /workspace/by_user 后端不存在；返回静态默认工作空间避免 404
  return Promise.resolve(new Result(true, '', [{ id: 'default', name: 'layout.about.default_workspace' } as WorkspaceItem]))
}
```

(注意：`Result` 构造函数签名要按项目现有用法核实)

- 其它后端不存在的方法（`getSystemWorkspaceList` / `CreateOrUpdateWorkspace` / `deleteWorkspaceCheck` / `deleteWorkspace`）→ **删函数 + export 移除**

最终 `workspace.ts` 只剩被外部还在用的 1-2 个方法（具体哪几个由 Step 1 引用清单决定）。

- [ ] **Step 3: type-check 确认**

```bash
cd ui && npm run type-check
```

如有 type 错误，找到调用方更新（应该不会有，因为我们只删了无引用的方法）。

不 commit。

---

### Task PE5: 删除孤儿 i18n keys

**Files:**
- Modify: `ui/src/locales/lang/zh-CN/views/*.ts`
- Modify: `ui/src/locales/lang/en-US/views/*.ts`
- Modify: `ui/src/locales/lang/zh-Hant/views/*.ts`
- Possibly Delete: 整个文件如果完全是孤儿 namespace

- [ ] **Step 1: 列出 views 子目录**

```bash
ls ui/src/locales/lang/zh-CN/views
```

- [ ] **Step 2: 验证哪些 namespace 完全孤儿**

对每个 namespace（workspace / role / operate-log / chat-user / shared / resource-management / 主题相关 / authentication）：

```bash
for ns in workspace role operateLog chatUser shared resourceManagement; do
  echo "=== \$t('views.$ns ==="
  grep -rn "\\\$t('views\.$ns\." ui/src --include="*.vue" --include="*.ts" | head -3
done
```

预期：所有 `views.workspace.*` / `views.role.*` 等的引用都是 0（在 PE1 删 view 之后）。例外：`views.system.email.*` 和 `views.userManage.*` 和 `views.system.resourceAuthorization.*` 仍有引用 — 这些**保留**。

- [ ] **Step 3: 删除孤儿 view i18n 文件**

```bash
rm ui/src/locales/lang/zh-CN/views/workspace.ts 2>/dev/null
rm ui/src/locales/lang/zh-CN/views/role.ts 2>/dev/null
rm ui/src/locales/lang/zh-CN/views/operateLog.ts 2>/dev/null
rm ui/src/locales/lang/zh-CN/views/chatUser.ts 2>/dev/null
rm ui/src/locales/lang/zh-CN/views/shared.ts 2>/dev/null
rm ui/src/locales/lang/zh-CN/views/resourceManagement.ts 2>/dev/null
# 同样对 en-US / zh-Hant 处理
```

注意：实际文件名要 `ls` 结果为准。

- [ ] **Step 4: 清 `views/*.ts` 主入口 / index 里的引用**

```bash
cat ui/src/locales/lang/zh-CN/views/index.ts
```

按上一步删的文件相应去掉 `import` 和 export。

- [ ] **Step 5: 清 `theme.ts` 整顶层 i18n 文件**

```bash
ls ui/src/locales/lang/zh-CN/theme.ts 2>/dev/null && rm ui/src/locales/lang/zh-CN/theme.ts
ls ui/src/locales/lang/en-US/theme.ts 2>/dev/null && rm ui/src/locales/lang/en-US/theme.ts
ls ui/src/locales/lang/zh-Hant/theme.ts 2>/dev/null && rm ui/src/locales/lang/zh-Hant/theme.ts
```

然后清 `ui/src/locales/lang/<locale>/index.ts` 里 import 行。

- [ ] **Step 6: 清 `views.system.authentication` 和 `views.system.resource_management` 子 namespace**

如果 `views.system` 是单个文件（如 `system.ts`），打开它删掉 `authentication` 和 `resource_management` 子对象。**保留** `email` 和 `resourceAuthorization` 子对象。

- [ ] **Step 7: 验证 type-check 不报 i18n 缺 key**

```bash
cd ui && npm run type-check
```

如有 missing key 报错，找到具体引用，可能：
- 还有 view 文件没删干净（PE1 漏）
- 或者某 key 实际还被某存活页面引用（应保留）

按情况调整。不 commit。

---

### Task PE6: 清理 router 移除孤儿子路由

**Files:**
- Modify: `ui/src/router/modules/system.ts`

- [ ] **Step 1: 重写 system.ts 只留 3 个有效 children**

打开 `ui/src/router/modules/system.ts`，整个 `systemRouter` 替换为：

```ts
import { PermissionConst, EditionConst, RoleConst } from '@/utils/permission/data'
import { ComplexPermission } from '@/utils/permission/type'

const systemRouter = {
  path: '/system',
  name: 'system',
  meta: { title: 'views.system.title' },
  component: () => import('@/layout/layout-template/MainLayout.vue'),
  redirect: '/system/user',
  children: [
    {
      path: '/system/user',
      name: 'user',
      meta: {
        icon: 'User',
        iconActive: 'UserFilled',
        title: 'views.userManage.title',
        activeMenu: '/system',
        parentPath: '/system',
        parentName: 'system',
        sameRoute: 'user',
        permission: [RoleConst.ADMIN, PermissionConst.USER_READ],
      },
      component: () => import('@/views/system/user-manage/index.vue'),
    },
    {
      path: '/system/authorization',
      name: 'authorization',
      meta: {
        icon: 'app-resource-authorization',
        iconActive: 'app-resource-authorization-active',
        title: 'views.system.resourceAuthorization.title',
        activeMenu: '/system',
        parentPath: '/system',
        parentName: 'system',
        sameRoute: 'authorization',
        permission: [
          new ComplexPermission(
            [RoleConst.ADMIN, RoleConst.WORKSPACE_MANAGE],
            [
              PermissionConst.APPLICATION_WORKSPACE_USER_RESOURCE_PERMISSION_READ,
              PermissionConst.APPLICATION_WORKSPACE_USER_RESOURCE_PERMISSION_READ
                .getWorkspacePermissionWorkspaceManageRole,
            ],
            [],
            'OR',
          ),
        ],
      },
      redirect: '/system/authorization/application',
      children: [
        {
          path: '/system/authorization/application',
          name: 'authorizationApplication',
          meta: {
            title: 'views.application.title',
            activeMenu: '/system',
            parentPath: '/system',
            parentName: 'system',
            resource: 'APPLICATION',
            sameRoute: 'authorization',
            hideMenu: true,
          },
          component: () => import('@/views/system/resource-authorization/index.vue'),
        },
        {
          path: '/system/authorization/knowledge',
          name: 'authorizationKnowledge',
          meta: {
            title: 'views.knowledge.title',
            activeMenu: '/system',
            parentPath: '/system',
            parentName: 'system',
            resource: 'KNOWLEDGE',
            sameRoute: 'authorization',
            hideMenu: true,
          },
          component: () => import('@/views/system/resource-authorization/index.vue'),
        },
        {
          path: '/system/authorization/tool',
          name: 'authorizationTool',
          meta: {
            title: 'views.tool.title',
            activeMenu: '/system',
            parentPath: '/system',
            parentName: 'system',
            resource: 'TOOL',
            sameRoute: 'authorization',
            hideMenu: true,
          },
          component: () => import('@/views/system/resource-authorization/index.vue'),
        },
        {
          path: '/system/authorization/model',
          name: 'authorizationModel',
          meta: {
            title: 'views.model.title',
            activeMenu: '/system',
            parentPath: '/system',
            parentName: 'system',
            resource: 'MODEL',
            sameRoute: 'authorization',
            hideMenu: true,
          },
          component: () => import('@/views/system/resource-authorization/index.vue'),
        },
      ],
    },
    {
      path: '/system/email',
      name: 'email',
      meta: {
        icon: 'app-setting',
        iconActive: 'app-setting-active',
        title: 'views.system.email.title',
        activeMenu: '/system',
        parentPath: '/system',
        parentName: 'system',
        sameRoute: 'email',
        permission: [
          new ComplexPermission([RoleConst.ADMIN], [PermissionConst.EMAIL_SETTING_READ], [], 'OR'),
        ],
      },
      component: () => import('@/views/system-setting/email/index.vue'),
    },
  ],
}

export default systemRouter
```

变更要点：
- 去 `hidden: true`、`component` 改为 MainLayout、加 `redirect: '/system/user'`
- 只保留 `user` / `authorization`（含 4 个子路由 + `hideMenu: true` 让 Side 只显示 1 项"资源授权"）/ `email`
- 删除：`workspace` / `role` / `resource-management` / `shared` / `chat` / `setting/theme` / `authentication`
- Side 菜单解析时识别 `hideMenu: true` —— 如果项目里现有 Side 不支持这个 meta，**Step 2** 处理

- [ ] **Step 2: 让 Side 识别 hideMenu meta（如未实现）**

```bash
grep -rn "hideMenu" ui/src/router ui/src/layout
```

如有现成实现：跳过 Step 2。否则在 `ui/src/router/common.ts`（`getChildRouteListByPathAndName` 函数）中过滤 `hideMenu === true` 的项：

打开 `ui/src/router/common.ts`，找 `getChildRouteListByPathAndName` 返回 list 之前过滤一道：

```ts
// 在 return 之前
return list.filter((r: any) => !r.meta?.hideMenu)
```

具体行号根据实际文件结构调整。

- [ ] **Step 3: 删除 /operate 顶层路由**

```bash
grep -rn "name: 'operate'\|path: '/operate'" ui/src/router
```

如果在 `systemRouter` 之外（独立顶层 route），打开对应文件删除。

- [ ] **Step 4: type-check + build 全验证（这次必须通过）**

```bash
cd ui && npm run type-check && npm run build
```

期望：全部通过。

如果还有 type 错误（如 dynamics-api 引用了被删的 API），针对性修复。

- [ ] **Step 5: dev server 走查全链路**

```bash
cd ui && npm run dev
```

按以下顺序点击：
1. 登录后默认进首页（工作台）
2. 点 Rail "系统管理" → 跳 `/system/user`
3. Side 显示 3 项：用户管理 / 资源授权 / 邮箱设置
4. 用户管理：PageHeader + 表格 + 增删改查 OK
5. 点资源授权 → 跳 `/system/authorization/application`
6. 切换 4 个 tab，URL 跟着变；PermissionTable 加载新数据
7. 点邮箱设置 → 显示 PageHeader + 表单
8. 浏览器 URL 直接输入 `/system/role` → 404 或 noPermission
9. 浏览器 URL 直接输入 `/operate` → 404
10. 控制台 0 错误 0 警告

- [ ] **Step 6: 后端 diff 验证**

```bash
git diff apps/
```

预期：完全为空。

- [ ] **Step 7: workspace_id 字段健康检查**

```bash
git diff main -- apps/ | grep -c "workspace_id"
```

预期：0（未触碰任何 workspace_id 字段）。

```bash
grep -rn "getWorkspaceId" ui/src
```

预期：调用方仍能拿到 `'default'`。

- [ ] **Step 8: 一并 Commit PE1-PE6**

```bash
git add -A
git commit -m "refactor(ui): remove 12 orphan platform-mgmt pages + APIs + i18n"
```

---

### Task PE7: 最终验收

**Files:** (验证类，不动文件)

- [ ] **Step 1: 全量 grep 死引用扫描**

```bash
echo "=== 1. theme 死调用 ==="
grep -rn "ThemeApi\|theme.theme()" ui/src

echo "=== 2. SystemMainLayout 残留 ==="
grep -rn "SystemMainLayout" ui/src

echo "=== 3. 被删 view 路径残留 ==="
grep -rn "views/system/workspace\|views/system/role\|views/system/operate-log" ui/src
grep -rn "views/system-resource-management\|views/system-shared\|views/system-chat-user" ui/src
grep -rn "views/system-setting/theme\|views/system-setting/authentication" ui/src

echo "=== 4. 被删 API 路径残留 ==="
grep -rn "api/system/role'\|api/system/operate-log'\|api/system/chat-user'" ui/src
grep -rn "api/system-settings/theme'\|api/system-settings/auth-setting'" ui/src
```

期望：以上各项均**无输出**（或仅有注释行）。

- [ ] **Step 2: type-check + build 最终验证**

```bash
cd ui && npm run type-check && npm run build
```

期望：全部 0 退出码。

- [ ] **Step 3: 后端零改动确认**

```bash
git diff main -- apps/
```

期望：完全为空。

- [ ] **Step 4: dev server 综合走查（按 spec §7.2 验收清单）**

按 spec `2026-05-22-platform-management-redesign-design.md` §7.2 走 6 项验收。

- [ ] **Step 5: 30 秒辨认测试**

让一个不熟悉项目的人盯 `/system/user` 30 秒 — 应该不会立刻反应出是 MaxKB。

- [ ] **Step 6: 最终 Commit（如有微调）**

```bash
git add -A
git commit -m "chore(ui): finalize platform-mgmt redesign (verification pass)"
```

---

## 完成定义

本计划全部 task 完成后，spec `2026-05-22-platform-management-redesign-design.md` §9 的 7 条完成定义全部满足。

