# 知识资产 / 能力扩展 / 模型 三模块重设计 · 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 knowledge / capability / model 3 个 Rail 模块下的 4 个重灾区页面（document/problem/hit-test/trigger）重做、4 个长尾页面（knowledge/tool/model/paragraph index）轻量打磨、模型 7 个子组件 atom 升级 + 死分支清、tool/store.ts 死 API 方法清理、workflow 画布 grid 对齐 Spec W1。后端零改动。

**Architecture:** 复用已落地的原子（`PageHeader`/`StatusDot`/`LucideIcon`/`.card-unified`/`.toolbar`），按需扩展 `StatusDot` 增加 `active/paused/error/indexing` 4 个新 status key。4 重做页用 `<PageHeader>` + `.card-unified` + `.toolbar` 模式取代 `<h2>` + 嵌套 `<el-card>` + `p-16-24`；4 轻量页保留 `LayoutContainer` 双栏结构、只清残留；模型子组件批量 AppIcon→LucideIcon、状态用 StatusDot；ModelCard / CreateModelDialog / index.vue 的 `'systemShare'|'systemManage'` 9 处死分支删除。

**Tech Stack:** Vue 3 + Element Plus + Pinia + vue-router + iconify/lucide + SCSS + vue-i18n. LogicFlow (for workflow).

**Source spec:** `docs/superpowers/specs/2026-05-23-knowledge-capability-model-redesign-design.md`

**Pre-impl state (HEAD when plan written):** `77a7adcfe` 系统管理 redesign 完成；3 模块审计未动；spec 提交在工作树。

---

## 共享映射表 · AppIcon → LucideIcon

本表被 PB1 / PC1 / PD1 / PE1 / PG1 / PG2 / PG3 共用。替换语法：

```vue
<AppIcon iconName="app-XXX"></AppIcon>   →   <LucideIcon name="YYY" :size="16" />
```

保留外层 `class` / `title` 属性。

| 旧 iconName | 新 LucideIcon name |
|---|---|
| `app-more` | `more-horizontal` |
| `app-edit` | `pencil` |
| `app-delete` | `trash-2` |
| `app-execution-record` | `history` |
| `app-cancel` | `x` |
| `app-vectorization` | `zap` |
| `app-generate-question` | `sparkles` |
| `app-sync` | `refresh-cw` |
| `app-migrate` | `move` |
| `app-export` | `download` |
| `app-lock` | `lock` |
| `app-key` | `key` |
| `app-setting` | `settings` |
| `app-folder` | `folder` |
| `app-resource-authorization` | `shield-check` |
| `app-resource-mapping` | `link` |
| `app-warning` | `alert-triangle` |
| `app-shared-active` | `share-2` |
| `app-all-menu-active` | `grid-2x2` |
| `app-add-outlined` | `plus` |
| `app-batch-delete` | `trash` |
| `app-template-center` | `library` |
| `app-disabled` | `circle-slash` |
| `app-like-color` | `thumbs-up` |
| `app-oppose-color` | `thumbs-down` |
| 找不到对应 | `circle-help` （加注释 `// TODO: pick proper lucide name`） |

---

## Phase PA · 原子扩展（按需）

### Task PA1: StatusDot 扩展 4 个新 status key

**Files:**
- Modify: `ui/src/components/status-dot/StatusDot.vue`
- Modify: `ui/src/locales/lang/zh-CN/common.ts`
- Modify: `ui/src/locales/lang/en-US/common.ts`
- Modify: `ui/src/locales/lang/zh-Hant/common.ts`

- [ ] **Step 1: 替换 StatusDot.vue 整文件**

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

type StatusKey =
  | 'published' | 'draft' | 'archived'
  | 'enabled' | 'disabled'
  | 'active' | 'paused'
  | 'indexing' | 'error'

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
    case 'active': return t('common.status.active')
    case 'paused': return t('common.status.paused')
    case 'indexing': return t('common.status.indexing')
    case 'error': return t('common.status.error')
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
.status-dot--active .status-dot__bullet { color: #10b981; }
.status-dot--paused .status-dot__bullet { color: #94a3b8; }
.status-dot--indexing .status-dot__bullet { color: #f59e0b; }
.status-dot--error .status-dot__bullet { color: #ef4444; }
</style>
```

- [ ] **Step 2: 加 i18n keys 到 zh-CN/common.ts**

打开 `ui/src/locales/lang/zh-CN/common.ts`，在 `status:` 对象内的已有 keys（`enabled / disabled / published / draft / archived` 等）旁追加：

```ts
    active: '已启用',
    paused: '已暂停',
    indexing: '索引中',
    error: '错误',
```

- [ ] **Step 3: 加 i18n keys 到 en-US/common.ts**

同样位置加：

```ts
    active: 'Active',
    paused: 'Paused',
    indexing: 'Indexing',
    error: 'Error',
```

- [ ] **Step 4: 加 i18n keys 到 zh-Hant/common.ts**

```ts
    active: '已啟用',
    paused: '已暫停',
    indexing: '索引中',
    error: '錯誤',
```

- [ ] **Step 5: type-check**

```bash
cd ui && npm run type-check
```

期望：退出 0。

- [ ] **Step 6: Commit**

```bash
git add ui/src/components/status-dot/StatusDot.vue ui/src/locales/lang
git commit -m "feat(ui): extend StatusDot with active/paused/indexing/error keys"
```

---

## Phase PB · /document 重做

### Task PB1: 重写 document/index.vue 外层壳（保留表格 + 业务逻辑）

**Files:**
- Modify: `ui/src/views/document/index.vue` (lines 1-161 outer wrapper + status column + operation column + style block)

**注意：此文件 1563 行，只动外层 + 状态列 + 操作列。表格列其它 prop / 顶级 dialogs / script 业务函数全部保留不动。**

- [ ] **Step 1: 加 PageHeader / LucideIcon imports**

在 `<script setup>` 顶部（其它 imports 之间）添加：

```ts
import { PageHeader } from '@/components/page-header'
import { LucideIcon } from '@/components/lucide-icon'
import { StatusDot } from '@/components/status-dot'
```

- [ ] **Step 2: 替换 template 行 1-161**（外层壳 + 顶部 toolbar）

打开 `ui/src/views/document/index.vue`，替换 line 1-161（包括根 `<div>` 起头到 `</div>` 收紧 toolbar 区，**不**包括 `<app-table>` 开始）为：

```vue
<template>
  <div class="document">
    <PageHeader
      :title="$t('common.fileUpload.document')"
      :subtitle="`${knowledgeDetail?.name || ''} · ${$t('views.document.total', { n: paginationConfig.total })}`"
      :showBack="true"
      @back="$router.back()"
    >
      <template #actions>
        <template v-if="!isShared">
          <el-button
            v-if="knowledgeDetail?.type === 0 && permissionPrecise.doc_create(id)"
            type="primary"
            @click="
              router.push({
                path: `/knowledge/document/upload/${folderId}/${type}`,
                query: { id: id },
              })
            "
          >
            {{ $t('views.document.uploadDocument') }}
          </el-button>
          <el-button
            v-if="knowledgeDetail?.type === 1 && permissionPrecise.doc_create(id)"
            type="primary"
            @click="importDoc"
          >
            {{ $t('views.document.importDocument') }}
          </el-button>
          <el-button
            v-if="knowledgeDetail?.type === 2 && permissionPrecise.doc_create(id)"
            type="primary"
            @click="
              router.push({
                path: `/knowledge/import/lark/${folderId}`,
                query: { id: id, folder_token: knowledgeDetail?.meta.folder_token },
              })
            "
          >
            {{ $t('views.document.importDocument') }}
          </el-button>
          <el-button
            v-if="knowledgeDetail?.type === 4 && permissionPrecise.doc_create(id)"
            type="primary"
            @click="toImportWorkflow"
          >
            {{ $t('views.document.importDocument') }}
          </el-button>
          <el-button
            @click="batchRefresh"
            :disabled="multipleSelection.length === 0"
            v-if="permissionPrecise.doc_vector(id)"
          >
            {{ $t('views.knowledge.setting.vectorization') }}
          </el-button>
          <el-button
            @click="openGenerateDialog()"
            :disabled="multipleSelection.length === 0"
            v-if="permissionPrecise.doc_generate(id)"
          >
            {{ $t('views.document.generateQuestion.title') }}
          </el-button>
          <el-button
            @click="openBatchEditDocument"
            :disabled="multipleSelection.length === 0"
            v-if="permissionPrecise.doc_edit(id)"
          >
            {{ $t('common.setting') }}
          </el-button>

          <el-dropdown v-if="MoreFilledPermission0(id)">
            <el-button>
              <LucideIcon name="more-horizontal" :size="16" />
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item
                  @click="openknowledgeDialog()"
                  :disabled="multipleSelection.length === 0"
                  v-if="permissionPrecise.doc_migrate(id)"
                >
                  {{ $t('views.document.setting.migration') }}
                </el-dropdown-item>
                <el-dropdown-item
                  @click="openAddTagDialog()"
                  :disabled="multipleSelection.length === 0"
                  v-if="permissionPrecise.doc_tag(id)"
                >
                  {{ $t('views.document.tag.addTag') }}
                </el-dropdown-item>
                <el-dropdown-item
                  divided
                  @click="syncMulDocument"
                  :disabled="multipleSelection.length === 0"
                  v-if="knowledgeDetail?.type === 1 && permissionPrecise.doc_sync(id)"
                >
                  {{ $t('views.document.syncDocument') }}
                </el-dropdown-item>
                <el-dropdown-item
                  divided
                  @click="syncLarkMulDocument"
                  :disabled="multipleSelection.length === 0"
                  v-if="knowledgeDetail?.type === 2 && permissionPrecise.doc_sync(id)"
                >
                  {{ $t('views.document.syncDocument') }}
                </el-dropdown-item>
                <el-dropdown-item
                  @click="exportMulDocument"
                  :disabled="multipleSelection.length === 0"
                  v-if="permissionPrecise.doc_export(id)"
                >
                  {{ $t('views.document.setting.export') }} Excel
                </el-dropdown-item>
                <el-dropdown-item
                  @click="exportMulDocumentZip"
                  :disabled="multipleSelection.length === 0"
                  v-if="permissionPrecise.doc_export(id)"
                >
                  {{ $t('views.document.setting.export') }} Zip
                </el-dropdown-item>
                <el-dropdown-item
                  divided
                  @click="deleteMulDocument"
                  :disabled="multipleSelection.length === 0"
                  v-if="permissionPrecise.doc_delete(id)"
                >
                  {{ $t('common.delete') }}
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </template>
      </template>
    </PageHeader>

    <div class="card-unified document__card">
      <div class="toolbar">
        <div class="toolbar__left">
          <el-tooltip
            effect="dark"
            :content="$t('common.ExecutionRecord.title')"
            placement="top"
            v-if="knowledgeDetail?.type === 4 && permissionPrecise.doc_create(id)"
          >
            <el-button @click="openListAction">
              <LucideIcon name="history" :size="16" />
            </el-button>
          </el-tooltip>
          <el-button @click="openTagDrawer" v-if="permissionPrecise.tag_read(id)">
            {{ $t('views.document.tag.label') }}
          </el-button>
        </div>
        <div class="toolbar__right complex-search">
          <el-select
            class="complex-search__left"
            v-model="search_type"
            style="width: 120px"
            @change="search_type_change"
          >
            <el-option :label="$t('common.name')" value="name" />
          </el-select>
          <el-input
            v-if="search_type === 'name'"
            v-model="search_form.name"
            @change="refresh"
            :placeholder="$t('common.searchBar.placeholder')"
            style="width: 220px"
            clearable
          />
        </div>
      </div>

      <app-table
        ref="multipleTableRef"
        class="document-table"
```

**注意保持 `<app-table>` 后面所有内容（columns, dialogs）完全不变。** 这一步只替换从根 `<div>` 到 `<app-table>` 打开标签之前的部分。如果原文件的 `<app-table>` 在 line 162 开始，这一步操作就是删除 line 1-161，把上面的代码插入到 line 1 之前。

- [ ] **Step 3: 找到旧的 status 列改用 StatusDot**

Grep 找现有 status 列定义：

```bash
grep -n 'prop="status"' ui/src/views/document/index.vue
```

预期：找到 1 处定义类似 `<el-table-column prop="status" :label="$t('views.document.fileStatus.label')">`。

读 status 列那一段（约 20-50 行内），找到旧的 template 渲染逻辑（用了 `StatusValue` 组件 — 这是 `views/document/component/Status.vue`，**保留 StatusValue 不动**，它已经是封装的状态显示）。**这一步什么都不改**，因为 StatusValue 是自定义组件。如果原代码确实使用 raw `<el-icon>` + condition 的方式，再考虑替换为 `<StatusDot>`。

- [ ] **Step 4: 操作列 AppIcon → LucideIcon**

Grep 操作列内的 AppIcon：

```bash
grep -n 'AppIcon iconName' ui/src/views/document/index.vue
```

按出现顺序逐条替换。映射规则：

| 旧 iconName | 新 LucideIcon name |
|---|---|
| `app-more` | `more-horizontal` |
| `app-edit` | `pencil` |
| `app-delete` | `trash-2` |
| `app-execution-record` | `history` |
| `app-cancel` | `x` |
| `app-vectorization` | `zap` |
| `app-generate-question` | `sparkles` |
| `app-sync` | `refresh-cw` |
| `app-migrate` | `move` |
| `app-export` | `download` |
| `app-lock` | `lock` |
| `app-key` | `key` |
| `app-setting` | `settings` |
| `app-folder` | `folder` |
| `app-resource-authorization` | `shield-check` |
| `app-resource-mapping` | `link` |
| `app-warning` | `alert-triangle` |
| `app-shared-active` | `share-2` |
| `app-all-menu-active` | `grid-2x2` |
| `app-add-outlined` | `plus` |
| `app-batch-delete` | `trash` |
| `app-template-center` | `library` |
| 找不到对应 | `circle-help` （加注释 `// TODO: pick proper lucide name`） |

替换语法：`<AppIcon iconName="app-XXX"></AppIcon>` → `<LucideIcon name="YYY" :size="16" />`

替换时保留外层 `class`/`title` 属性。

- [ ] **Step 5: 替换 style block**

替换 line 1551-1563 的 `<style scoped>` 块为：

```vue
<style lang="scss" scoped>
.document {
  padding: 0 24px 24px;
}
.document__card {
  overflow: hidden;
  .mul-operation {
    right: 24px;
    width: calc(100% - var(--sidebar-width) - 48px);
  }
}
.document-table {
  :deep(.el-table__row) {
    cursor: pointer;
  }
}
</style>
```

- [ ] **Step 6: 加 i18n key `views.document.total`**

grep 检查：

```bash
grep -n "views.document.total\|^    total:" ui/src/locales/lang/zh-CN/views/document.ts
```

如果 key 不存在，在 `ui/src/locales/lang/{zh-CN,en-US,zh-Hant}/views/document.ts` 的 `document:` 对象内加：

- zh-CN: `total: '共 {n} 个文档',`
- en-US: `total: 'Total {n} documents',`
- zh-Hant: `total: '共 {n} 個文檔',`

如果 key 已存在但用了不同的 placeholder（如 `{0}` 或不带 placeholder），改成 `{n}` 形式以匹配 `$t('views.document.total', { n: ... })` 调用。

- [ ] **Step 7: type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

期望：均退出 0。如果 type-check 报错关于 `AppIcon` 未使用 / `LucideIcon` 找不到，按错误信息修复。

- [ ] **Step 8: 验证 AppIcon 已清**

```bash
grep -n "AppIcon" ui/src/views/document/index.vue
```

期望：0 hit（如有，对照 Step 4 表继续替换；如某 AppIcon 在子组件 ref 名字里出现，那是 false positive 不算）。

- [ ] **Step 9: Commit**

```bash
git add ui/src/views/document/index.vue ui/src/locales/lang
git commit -m "refactor(ui): rebuild /document with PageHeader + .card-unified"
```

---

## Phase PC · /problem 重做

### Task PC1: 重写 problem/index.vue

**Files:**
- Modify: `ui/src/views/problem/index.vue`

文件 428 行，template 156 行。可以提供完整 template 替换。

- [ ] **Step 1: 加 imports**

在 `<script setup>` imports 区追加：

```ts
import { PageHeader } from '@/components/page-header'
import { LucideIcon } from '@/components/lucide-icon'
```

- [ ] **Step 2: 替换整个 template（line 1-156）**

```vue
<template>
  <div class="problem">
    <PageHeader
      :title="$t('views.problem.title')"
      :subtitle="`${knowledgeDetail?.name || ''} · ${$t('views.problem.total', { n: paginationConfig.total })}`"
      :showBack="true"
      @back="$router.back()"
    >
      <template #actions>
        <el-button
          type="primary"
          @click="createProblem"
          v-if="permissionPrecise.problem_create(id)"
        >
          {{ $t('views.problem.createProblem') }}
        </el-button>
        <el-button
          @click="relateProblem()"
          :disabled="multipleSelection.length === 0"
          v-if="permissionPrecise.problem_relate(id)"
        >
          {{ $t('views.problem.relateParagraph.title') }}
        </el-button>
        <el-button
          @click="deleteMulDocument"
          :disabled="multipleSelection.length === 0"
          v-if="permissionPrecise.problem_delete(id)"
        >
          {{ $t('views.problem.setting.batchDelete') }}
        </el-button>
      </template>
    </PageHeader>

    <div class="card-unified problem__card">
      <div class="toolbar">
        <div class="toolbar__left"></div>
        <div class="toolbar__right">
          <el-input
            v-model="filterText"
            :placeholder="$t('common.searchBar.placeholder')"
            prefix-icon="Search"
            class="w-240"
            @change="getList"
            clearable
          />
        </div>
      </div>

      <app-table
        ref="multipleTableRef"
        :data="problemData"
        :pagination-config="paginationConfig"
        :quick-create="permissionPrecise.problem_create(id)"
        :quickCreateName="$t('views.problem.quickCreateName')"
        :quickCreatePlaceholder="$t('views.problem.quickCreateProblem')"
        :quickCreateMaxlength="256"
        @sizeChange="handleSizeChange"
        @changePage="getList"
        @cell-mouse-enter="cellMouseEnter"
        @cell-mouse-leave="cellMouseLeave"
        @creatQuick="creatQuickHandle"
        @row-click="rowClickHandle"
        @selection-change="handleSelectionChange"
        :row-class-name="setRowClass"
        v-loading="loading"
        :row-key="(row: any) => row.id"
      >
        <el-table-column type="selection" width="55" :reserve-selection="true" />
        <el-table-column prop="content" :label="$t('views.problem.title')" min-width="280">
          <template #default="{ row }">
            <ReadWrite
              @change="editName($event, row.id)"
              :data="row.content"
              :showEditIcon="permissionPrecise.problem_edit(id) && row.id === currentMouseId"
              :maxlength="256"
            />
          </template>
        </el-table-column>
        <el-table-column
          prop="paragraph_count"
          :label="$t('views.problem.table.paragraph_count')"
          align="right"
          min-width="100"
        >
          <template #default="{ row }">
            <el-link
              type="primary"
              @click.stop="rowClickHandle(row)"
              v-if="row.paragraph_count"
            >
              {{ row.paragraph_count }}
            </el-link>
            <span v-else>{{ row.paragraph_count }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="create_time" :label="$t('common.createTime')" width="170">
          <template #default="{ row }">
            {{ datetimeFormat(row.create_time) }}
          </template>
        </el-table-column>
        <el-table-column
          prop="update_time"
          :label="$t('views.problem.table.updateTime')"
          width="170"
        >
          <template #default="{ row }">
            {{ datetimeFormat(row.update_time) }}
          </template>
        </el-table-column>
        <el-table-column :label="$t('common.operation')" align="left" fixed="right">
          <template #default="{ row }">
            <div>
              <el-tooltip
                effect="dark"
                :content="$t('views.problem.relateParagraph.title')"
                placement="top"
              >
                <el-button
                  type="primary"
                  text
                  @click.stop="relateProblem(row)"
                  v-if="permissionPrecise.problem_relate(id)"
                >
                  <LucideIcon name="sparkles" :size="16" />
                </el-button>
              </el-tooltip>
              <el-tooltip effect="dark" :content="$t('common.delete')" placement="top">
                <el-button
                  type="primary"
                  text
                  @click.stop="deleteProblem(row)"
                  v-if="permissionPrecise.problem_delete(id)"
                >
                  <LucideIcon name="trash-2" :size="16" />
                </el-button>
              </el-tooltip>
            </div>
          </template>
        </el-table-column>
      </app-table>
    </div>

    <CreateProblemDialog ref="CreateProblemDialogRef" @refresh="refresh" />
    <DetailProblemDrawer
      :next="nextChatRecord"
      :pre="preChatRecord"
      ref="DetailProblemRef"
      v-model:currentId="currentClickId"
      v-model:currentContent="currentContent"
      :pre_disable="pre_disable"
      :next_disable="next_disable"
      @refresh="refreshRelate"
    />
    <RelateProblemDialog ref="RelateProblemDialogRef" @refresh="refreshRelate" />
  </div>
</template>
```

**注意 `knowledgeDetail` 是否在 script 已声明** — 如果 problem 页 script 中没有 `knowledgeDetail` 变量，subtitle 应改为不含 knowledgeDetail 的形式（仅 `$t('views.problem.total', { n: paginationConfig.total })`）。先 grep 确认：

```bash
grep -n "knowledgeDetail" ui/src/views/problem/index.vue
```

如果无定义，简化 subtitle 为：

```ts
:subtitle="$t('views.problem.total', { n: paginationConfig.total })"
```

- [ ] **Step 3: 替换 style block**

```vue
<style lang="scss" scoped>
.problem {
  padding: 0 24px 24px;
}
.problem__card {
  overflow: hidden;
}
</style>
```

- [ ] **Step 4: i18n key `views.problem.total`**

Grep 确认是否存在：

```bash
grep -n "^    total" ui/src/locales/lang/zh-CN/views/problem.ts
```

如不存在，在 3 locale 文件加：

- zh-CN: `total: '共 {n} 个问题',`
- en-US: `total: 'Total {n} questions',`
- zh-Hant: `total: '共 {n} 個問題',`

- [ ] **Step 5: type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

- [ ] **Step 6: 验证 AppIcon 已清**

```bash
grep -n "AppIcon" ui/src/views/problem/index.vue
```

期望：0 hit。

- [ ] **Step 7: Commit**

```bash
git add ui/src/views/problem/index.vue ui/src/locales/lang
git commit -m "refactor(ui): rebuild /problem with PageHeader + .card-unified"
```

---

## Phase PD · /hit-test 重做

### Task PD1: 重写 hit-test/index.vue（拆嵌套 el-card + AppIcon 替换）

**Files:**
- Modify: `ui/src/views/hit-test/index.vue`

文件 442 行，template 236 行。**这一页结构改造最大**：拆嵌套 el-card + 检索参数 popover 内嵌 card 扁平化。

- [ ] **Step 1: 加 imports**

在 `<script setup>` imports 区追加：

```ts
import { PageHeader } from '@/components/page-header'
import { LucideIcon } from '@/components/lucide-icon'
```

- [ ] **Step 2: 读完整 template 块**

```bash
sed -n '1,236p' ui/src/views/hit-test/index.vue
```

记下完整的 popover 内部内容（line 105-122 之间，spec §4.3 提到的 2 个 `<el-card shadow="never">`），以及检索结果区结构。

- [ ] **Step 3: 替换整个 template**

```vue
<template>
  <div class="hit-test">
    <PageHeader
      :title="$t('views.application.hitTest.title')"
      :subtitle="$t('views.application.hitTest.text')"
      :showBack="true"
      @back="$router.back()"
    >
      <template #actions>
        <el-popover
          :visible="popoverVisible"
          placement="bottom-end"
          :width="500"
          trigger="click"
          :persistent="false"
        >
          <template #reference>
            <el-button
              @click="settingChange('open')"
              v-if="!route.path.includes('share/')"
            >
              <LucideIcon name="settings" :size="16" class="mr-4" />
              {{ $t('common.paramSetting') }}
            </el-button>
          </template>

          <!-- ⚠️ 在 Step 4 把原 popover 内容粘贴在这里 -->

          <div class="text-right">
            <el-button @click="popoverVisible = false">{{ $t('common.cancel') }}</el-button>
            <el-button type="primary" @click="settingChange('close')">
              {{ $t('common.confirm') }}
            </el-button>
          </div>
        </el-popover>
      </template>
    </PageHeader>

    <div class="card-unified hit-test__card" v-loading="loading">
      <div class="hit-test__question" :style="{ visibility: questionTitle ? 'visible' : 'hidden' }">
        <el-avatar>
          <img src="@/assets/user-icon.svg" style="width: 54%" alt="" />
        </el-avatar>
        <h4 class="text break-all ellipsis-1 ml-12" :title="questionTitle">
          {{ questionTitle }}
        </h4>
      </div>

      <el-scrollbar>
        <div :style="{ height: user.isExpire() ? 'calc(100vh - 380px)' : 'calc(100vh - 340px)' }">
          <el-empty
            v-if="first"
            :image="emptyImg"
            :description="$t('views.application.hitTest.emptyMessage1')"
            style="padding-top: 160px"
            :image-size="125"
          />
          <el-empty
            v-else-if="paragraphDetail.length == 0"
            :description="$t('views.application.hitTest.emptyMessage2')"
            style="padding-top: 160px"
            :image-size="125"
          />
          <el-row v-else>
            <el-col
              :xs="24"
              :sm="12"
              :md="12"
              :lg="8"
              :xl="6"
              v-for="(item, index) in paragraphDetail"
              :key="index"
              class="p-8"
            >
              <CardBox
                shadow="hover"
                :title="item.title || '-'"
                :description="item.content"
                class="document-card cursor"
                :class="item.is_active ? '' : 'disabled'"
                @click="editParagraph(item)"
              >
                <template #icon>
                  <el-avatar class="avatar-light" :size="22">{{ index + 1 + '' }}</el-avatar>
                </template>
                <template #tag>
                  <div class="primary">{{ item.similarity?.toFixed(3) }}</div>
                </template>
                <template #footer>
                  <div class="footer-content flex-between">
                    <el-text>
                      <el-icon><Document /></el-icon>
                      {{ item?.document_name }}
                    </el-text>
                    <div v-if="item.trample_num || item.star_num">
                      <span v-if="item.star_num">
                        <LucideIcon name="thumbs-up" :size="14" />
                        {{ item.star_num }}
                      </span>
                      <span v-if="item.trample_num" class="ml-4">
                        <LucideIcon name="thumbs-down" :size="14" />
                        {{ item.trample_num }}
                      </span>
                    </div>
                  </div>
                </template>
              </CardBox>
            </el-col>
          </el-row>
        </div>
      </el-scrollbar>
    </div>

    <ParagraphDialog
      ref="ParagraphDialogRef"
      :title="title"
      @refresh="refresh"
      :apiType="apiType"
    />

    <div class="hit-test__operate">
      <div class="operate-textarea flex" v-if="!route.path.includes('share/')">
        <el-input
          v-model="textareaValue"
          @keydown.enter="sendChatHandle($event)"
          type="textarea"
          :autosize="{ minRows: 1, maxRows: 4 }"
          :placeholder="$t('views.application.hitTest.placeholder')"
        />
        <div class="operate">
          <el-button
            text
            class="sent-button"
            :disabled="isDisabledChart || loading"
            @click="sendChatHandle"
          >
            <LucideIcon name="send" :size="20" />
          </el-button>
        </div>
      </div>
    </div>
  </div>
</template>
```

**注意**：上面 `<el-input v-model="textareaValue" ...>` 的 v-model 名字（`textareaValue`）可能与原文件不一致 — 看 line 124 附近实际变量名（原文件用 `<el-input ... @keydown.enter="sendChatHandle($event)" />`，v-model 在原 template 中可能缩略未列出）。grep 确认：

```bash
grep -n "v-model" ui/src/views/hit-test/index.vue | head -10
```

如果实际是其它名字（如 `inputValue` / `query` 等），用实际名字。

- [ ] **Step 4: 把原 popover 内容粘贴到注释位置**

回到原文件 line 105-115 之间，**复制原 popover 的内容**（除了 `<el-card shadow="never">` 包裹层 — 那是要扁平化的）。原内容大致是 2 个 `<el-card shadow="never">`（一个搜索模式、一个段落控制设置），各自里面是 `<el-form>` items。

把它们的 `<el-form>` 内容**直接放到** Step 3 的注释位置，外层不要 `<el-card shadow="never">`，改为用 `<h5>`分组：

```vue
<h5 class="hit-test__section">{{ $t('views.application.hitTest.searchMode') }}</h5>
<!-- 原第一个 el-card 里的 form items -->

<h5 class="hit-test__section">{{ $t('views.application.hitTest.paragraphControl') }}</h5>
<!-- 原第二个 el-card 里的 form items -->
```

具体 i18n key 名字按原文件实际的 label 选择（如果原 card 标题是 `$t('views.application.hitTest.searchMode')` 就保留这个 key）。

- [ ] **Step 5: 替换 style block**

```vue
<style lang="scss" scoped>
.hit-test {
  padding: 0 24px 24px;
}
.hit-test__card {
  padding: 16px;
  margin-bottom: 16px;
}
.hit-test__question {
  display: flex;
  align-items: center;
  margin-bottom: 16px;
  .text {
    padding: 6px 0;
    height: 34px;
    box-sizing: border-box;
  }
}
.hit-test__section {
  font-size: 13px;
  font-weight: 600;
  margin: 16px 0 8px;
  color: var(--text-primary);
  &:first-of-type {
    margin-top: 0;
  }
}
.hit-test__operate {
  .operate-textarea {
    box-shadow: 0px 6px 24px 0px rgba(var(--el-text-color-primary-rgb), 0.08);
    background-color: #ffffff;
    border-radius: 8px;
    border: 1px solid #ffffff;
    box-sizing: border-box;

    &:has(.el-textarea__inner:focus) {
      border: 1px solid var(--el-color-primary);
    }

    :deep(.el-textarea__inner) {
      border-radius: 8px !important;
      box-shadow: none;
      resize: none;
      padding: 12px 16px;
    }
    .operate {
      padding: 6px 10px;
      .sent-button {
        max-height: none;
      }
      :deep(.el-loading-spinner) {
        margin-top: -15px;
        .circular {
          width: 31px;
          height: 31px;
        }
      }
    }
  }
}
.document-card {
  height: 210px;
  border: 1px solid var(--app-layout-bg-color);
  &:hover {
    background: #ffffff;
    border: 1px solid var(--el-border-color);
  }
  &.disabled {
    background: var(--app-layout-bg-color);
    border: 1px solid var(--app-layout-bg-color);
    :deep(.description) {
      color: var(--app-border-color-dark);
    }
    :deep(.title) {
      color: var(--app-border-color-dark);
    }
  }
  :deep(.description) {
    -webkit-line-clamp: 5 !important;
    height: 110px;
  }
}
</style>
```

- [ ] **Step 6: type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

如果检索参数 popover 中引用的 i18n key（`searchMode` / `paragraphControl`）不存在，build 不会失败但 dev server 会显示 missing key warning。Grep 确认：

```bash
grep -n "searchMode\|paragraphControl" ui/src/locales/lang/zh-CN/views/application.ts
```

如缺，按需补加（如果原 `<el-card>` 用 `slot="header"` 显示文字，复用那个 key 名）。

- [ ] **Step 7: 验证 AppIcon 已清**

```bash
grep -n "AppIcon" ui/src/views/hit-test/index.vue
```

期望：0 hit。

- [ ] **Step 8: Commit**

```bash
git add ui/src/views/hit-test/index.vue ui/src/locales/lang
git commit -m "refactor(ui): rebuild /hit-test with PageHeader + flatten nested cards"
```

---

## Phase PE · /trigger 重做

### Task PE1: 重写 trigger/index.vue 外层壳 + 状态列

**Files:**
- Modify: `ui/src/views/trigger/index.vue`

文件 541 行，template 322 行。只动外层 + 状态列，表格列其它 + dialogs 保留不动。

- [ ] **Step 1: 加 imports**

```ts
import { PageHeader } from '@/components/page-header'
import { LucideIcon } from '@/components/lucide-icon'
import { StatusDot } from '@/components/status-dot'
```

- [ ] **Step 2: 替换外层 template（line 1-44）**

替换 line 1 至 toolbar 区结束（约 line 44 — 不含 `<app-table>`）为：

```vue
<template>
  <div class="trigger-manage">
    <PageHeader
      :title="$t('views.trigger.title')"
      :subtitle="$t('views.trigger.total', { n: paginationConfig.total })"
    >
      <template #actions>
        <el-button
          v-if="triggerPermissionMap.create()"
          type="primary"
          @click="openCreateTriggerDrawer"
        >
          {{ $t('common.create') }}
        </el-button>
        <el-button
          v-if="triggerPermissionMap.edit()"
          @click="batchChangeState(true)"
          :disabled="multipleSelection.length === 0"
        >
          {{ $t('common.status.enable') }}
        </el-button>
        <el-button
          v-if="triggerPermissionMap.edit()"
          @click="batchChangeState(false)"
          :disabled="multipleSelection.length === 0"
        >
          {{ $t('common.status.disable') }}
        </el-button>
        <el-button
          v-if="triggerPermissionMap.delete()"
          @click="batchDelete"
          :disabled="multipleSelection.length === 0"
        >
          {{ $t('common.delete') }}
        </el-button>
      </template>
    </PageHeader>

    <div class="card-unified trigger-manage__card">
      <div class="toolbar">
        <div class="toolbar__left"></div>
        <div class="toolbar__right complex-search">
```

**保留** `complex-search` 内的搜索逻辑（line 34-43 的 el-select / el-input chain）原封不动，紧接在上面 `<div class="toolbar__right complex-search">` 之后，到 `</div>` 关闭。然后再来：

```vue
        </div>
      </div>

      <app-table
```

**保留** 原 `<app-table>` 起点（line 45-322 之前的所有 columns + 操作列），不动。

最后在原 `</el-card>` + `</div>` + dialogs 那块（约 line 50-53）改为：

```vue
      </app-table>
    </div>

    <TriggerDrawer @refresh="getList()" ref="triggerDrawerRef"></TriggerDrawer>
    <TriggerTaskRecordDrawer ref="triggerTaskRecordDrawerRef"></TriggerTaskRecordDrawer>
  </div>
</template>
```

- [ ] **Step 3: 找到 is_active 状态列改用 StatusDot**

Grep：

```bash
grep -n 'prop="is_active"' ui/src/views/trigger/index.vue
```

读那一段（约 10-20 行），找到现在的渲染方式（用了 `<el-icon><SuccessFilled /></el-icon>` + AppIcon `app-disabled` 二选一）。替换为：

```vue
<el-table-column prop="is_active" :label="$t('common.status.label')" width="120">
  <template #default="{ row }">
    <StatusDot :status="row.is_active ? 'active' : 'paused'" />
  </template>
</el-table-column>
```

保留原 width 设置（如果不同则按原值）。

- [ ] **Step 4: 操作列 AppIcon → LucideIcon**

grep + 用 Step PB1 的 mapping 表替换。

```bash
grep -n "AppIcon iconName" ui/src/views/trigger/index.vue
```

- [ ] **Step 5: 替换 style block（原本是空的）**

```vue
<style lang="scss" scoped>
.trigger-manage {
  padding: 0 24px 24px;
}
.trigger-manage__card {
  overflow: hidden;
}
</style>
```

- [ ] **Step 6: i18n key `views.trigger.total`**

```bash
grep -n "^    total" ui/src/locales/lang/zh-CN/views/trigger.ts
```

如不存在加：

- zh-CN: `total: '共 {n} 个触发器',`
- en-US: `total: 'Total {n} triggers',`
- zh-Hant: `total: '共 {n} 個觸發器',`

如果文件结构是 `views.trigger.title` 形式而不是单独的 `trigger.ts` 文件，找到 trigger namespace 加进去。

- [ ] **Step 7: type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

- [ ] **Step 8: 验证 AppIcon 已清**

```bash
grep -n "AppIcon" ui/src/views/trigger/index.vue
```

期望：0 hit。

- [ ] **Step 9: Commit**

```bash
git add ui/src/views/trigger/index.vue ui/src/locales/lang
git commit -m "refactor(ui): rebuild /trigger with PageHeader + StatusDot active/paused"
```

---

## Phase PF · 4 轻量打磨

### Task PF1: knowledge/index.vue 清残留

**Files:**
- Modify: `ui/src/views/knowledge/index.vue`

- [ ] **Step 1: 删除 line 19 的 share-folder h2 分支**

打开文件，找到：

```vue
<h2 v-if="folder.currentFolder?.id === 'share'">
  {{ $t('views.shared.shared_knowledge') }}
</h2>
<FolderBreadcrumb :folderList="folderList" @click="folderClickHandle" v-else />
```

替换为只保留 FolderBreadcrumb（shared 分支死，路由已删）：

```vue
<FolderBreadcrumb :folderList="folderList" @click="folderClickHandle" />
```

- [ ] **Step 2: 删除死 Vue imports**

打开 `<script setup>` 顶部的 Vue import：

```ts
import { onMounted, ref, reactive, shallowRef, nextTick, computed } from 'vue'
```

替换为：

```ts
import { onMounted, ref, computed } from 'vue'
```

（去掉未使用的 `reactive`, `shallowRef`, `nextTick`）

- [ ] **Step 3: type-check**

```bash
cd ui && npm run type-check
```

期望：退出 0。如报错说某个被删的 import 实际仍在使用，恢复对应 import。

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/knowledge/index.vue
git commit -m "chore(ui): clean knowledge/index.vue dead share branch + imports"
```

---

### Task PF2: tool/index.vue 清残留

**Files:**
- Modify: `ui/src/views/tool/index.vue`

- [ ] **Step 1: 删除 line 20 的 share-folder h2 分支**

```vue
<h2 v-if="folder.currentFolder?.id === 'share'">
  {{ $t('views.shared.shared_tool') }}
</h2>
<FolderBreadcrumb :folderList="folderList" @click="folderClickHandle" v-else />
```

替换为：

```vue
<FolderBreadcrumb :folderList="folderList" @click="folderClickHandle" />
```

- [ ] **Step 2: 删除死 Vue imports**

```ts
import { onMounted, ref, reactive, computed } from 'vue'
```

替换为：

```ts
import { onMounted, ref, computed } from 'vue'
```

- [ ] **Step 3: type-check**

```bash
cd ui && npm run type-check
```

- [ ] **Step 4: Commit**

```bash
git add ui/src/views/tool/index.vue
git commit -m "chore(ui): clean tool/index.vue dead share branch + imports"
```

---

### Task PF3: model/index.vue 清 apiType 死分支

**Files:**
- Modify: `ui/src/views/model/index.vue`

- [ ] **Step 1: 删除 apiType computed（line 133-141）**

读取文件后找到这个块：

```ts
const apiType = computed(() => {
  if (route.path.includes('shared')) {
    return 'systemShare'
  } else if (route.path.includes('resource-management')) {
    return 'systemManage'
  } else {
    return 'workspace'
  }
})
```

完全删除（包括前后空行）。

- [ ] **Step 2: 删除 `<ModelCard>` 传递的 apiType / isSystemShare props**

打开 line 85-94 附近的 ModelCard 使用：

```vue
<ModelCard
  @change="list_model"
  :updateModelById="updateModelById"
  :model="model"
  :provider_list="provider_list"
  :isShared="isShared"
  :isSystemShare="isSystemShare"
  :apiType="apiType"
>
</ModelCard>
```

删除 `:isSystemShare="isSystemShare"` 和 `:apiType="apiType"` 两行：

```vue
<ModelCard
  @change="list_model"
  :updateModelById="updateModelById"
  :model="model"
  :provider_list="provider_list"
  :isShared="isShared"
>
</ModelCard>
```

- [ ] **Step 3: 删除 isSystemShare computed（如有）**

```bash
grep -n "isSystemShare" ui/src/views/model/index.vue
```

如果在 script 中有 `const isSystemShare = computed(...)`，整段删除。

- [ ] **Step 4: type-check**

```bash
cd ui && npm run type-check
```

期望：退出 0。注意：此时 ModelCard 的 prop 还接收 isSystemShare/apiType（PG1 还没改），但因为我们不再传，是允许的（Vue 不强制传 optional prop）。如果 ModelCard 在 props 里把 apiType 定为 required，会报错；那就把 PF3 推迟到 PG1 之后做。

实际：PG1 会同步修 ModelCard 让它不再依赖 apiType。所以 PF3 和 PG1 必须按顺序做。

**实施 order: PF3 在 PG1 之后做**。`addBlockedBy` 关系在 task 编排里建立。

或者先做 PG1 改 ModelCard 让 apiType / isSystemShare 改为 optional，再做 PF3 删 index.vue 的传递。

- [ ] **Step 5: Commit**

```bash
git add ui/src/views/model/index.vue
git commit -m "chore(ui): drop dead apiType branches in model/index.vue"
```

---

### Task PF4: paragraph/index.vue 外层壳重组

**Files:**
- Modify: `ui/src/views/paragraph/index.vue`

**这一页是 PF 中最大的改动** — 涉及把 LayoutContainer 从内嵌 el-card 升为根。

- [ ] **Step 1: 读 line 28 附近的 el-card 起点**

```bash
sed -n '25,60p' ui/src/views/paragraph/index.vue
```

看清楚 el-card 内部的 v-loading 绑定（`(paginationConfig.current_page === 1 && loading) || changeStateloading`）。

- [ ] **Step 2: 重构 outer wrapper**

打开 `ui/src/views/paragraph/index.vue`，把 line 2 到 line 27（外层 `<div class="paragraph p-12-24">` + `<div class="flex align-center">` + `<back-button>` + `<h3>` + 顶层 description text + `<div class="header-button">` + 那些 button + 起头的 `<el-card>`）改为：

```vue
<template>
  <div class="paragraph" v-loading="(paginationConfig.current_page === 1 && loading) || changeStateloading">
    <PageHeader
      :title="documentDetail?.name || ''"
      :showBack="true"
      @back="$router.back()"
    >
      <template #subtitle>
        <el-text type="info" v-if="documentDetail?.type === '1'">
          {{ $t('views.document.form.source_url.label') }}：
          <el-link :href="documentDetail?.meta?.source_url" target="_blank">
            <span class="break-all">{{ documentDetail?.meta?.source_url }}</span>
          </el-link>
        </el-text>
      </template>
      <template #actions v-if="!shareDisabled && permissionPrecise.doc_edit(id)">
        <el-button @click="batchSelectedHandle(true)" v-if="isBatch === false">
          {{ $t('views.paragraph.setting.batchSelected') }}
        </el-button>
        <el-button @click="batchSelectedHandle(false)" v-if="isBatch === true">
          {{ $t('views.paragraph.setting.cancelSelected') }}
        </el-button>
        <el-button @click="addParagraph" type="primary" :disabled="loading" v-if="isBatch === false">
          {{ $t('views.paragraph.addParagraph') }}
        </el-button>
      </template>
    </PageHeader>

    <div class="card-unified paragraph__card">
```

接下来：保留 原 line 28 `<el-card>` 内部 `<LayoutContainer>` 之后的所有内容（中间表单 / 列表 / 详情 / 弹窗），文件最后把原 line `</el-card>` `</div>` 改为：

```vue
    </div>
  </div>
</template>
```

- [ ] **Step 3: 加 PageHeader import**

```ts
import { PageHeader } from '@/components/page-header'
```

- [ ] **Step 4: 替换 style block**

打开 `<style scoped>`，替换为：

```vue
<style lang="scss" scoped>
.paragraph {
  position: relative;
  padding: 0 24px 24px;
}
.paragraph__card {
  position: relative;
  padding: 0;
  overflow: hidden;
  box-sizing: border-box;

  .mul-operation {
    position: absolute;
  }
}
.paragraph-sidebar {
  width: 100%;
  height: calc(100vh - 215px);
  box-sizing: border-box;
}
.paragraph-detail {
  height: calc(100vh - 215px);
  max-width: 1000px;
  margin: 16px auto;

  .el-checkbox-group {
    font-size: inherit;
    line-height: inherit;
  }
}
.paragraph-card {
  .is-selected {
    border: 1px solid var(--el-color-primary);
  }
  &.handle {
    .handle-img {
      visibility: hidden;
    }
    &:hover {
      .handle-img {
        visibility: visible;
      }
    }
  }
}
</style>
```

去掉了原本 `.header-button { position: absolute; ... }` 这块（因为按钮组移到 PageHeader actions slot 了）。

- [ ] **Step 5: type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

期望：均退出 0。

- [ ] **Step 6: Commit**

```bash
git add ui/src/views/paragraph/index.vue
git commit -m "refactor(ui): paragraph/index.vue uses PageHeader; drop el-card wrap"
```

---

## Phase PG · 模型子组件 atom 升级 + 死分支清

### Task PG1: ModelCard.vue AppIcon 替换 + 死分支清 + 状态用 StatusDot

**Files:**
- Modify: `ui/src/views/model/component/ModelCard.vue`

- [ ] **Step 1: 加 imports**

在 `<script setup>` imports 区追加：

```ts
import { LucideIcon } from '@/components/lucide-icon'
import { StatusDot } from '@/components/status-dot'
```

如果文件已有 `import { WarningFilled } from '@element-plus/icons-vue'`，删除。

- [ ] **Step 2: 替换 7 处 AppIcon**

按下面逐行替换（行号是当前文件状态）。**找到每行，把 `<AppIcon iconName="X">...</AppIcon>` 改为 `<LucideIcon name="Y" :size="16" />`**：

| 行 | 旧 iconName | 新 LucideIcon name |
|---|---|---|
| 74 | `app-more` | `more-horizontal` |
| 83 | `app-edit` | `pencil` |
| 90 | `app-lock` | `lock` |
| 108 | `app-setting` | `settings` |
| 115 | `app-resource-authorization` | `shield-check` |
| 123 | `app-resource-mapping` | `link` |
| 133 | `app-delete` | `trash-2` |

- [ ] **Step 3: 状态显示改 StatusDot（行 11-24 区域）**

找到 line 11-15 附近：

```vue
<el-tooltip ...>
  <template #content>
    <span>{{ errMessage }}</span>
  </template>
  <el-icon><WarningFilled /></el-icon>
</el-tooltip>
```

替换为：

```vue
<el-tooltip ...>
  <template #content>
    <span>{{ errMessage }}</span>
  </template>
  <StatusDot status="error" />
</el-tooltip>
```

找到 line 16-24（`PAUSE_DOWNLOAD` 状态）：

```vue
<el-tooltip ...>
  <template #content>
    <span>{{ ... base_model + downloadError ... }}</span>
  </template>
  <el-icon><WarningFilled /></el-icon>
</el-tooltip>
```

替换为：

```vue
<el-tooltip ...>
  <template #content>
    <span>{{ ... base_model + downloadError ... }}</span>
  </template>
  <StatusDot status="paused" />
</el-tooltip>
```

- [ ] **Step 4: 删除 isSystemShare-related 死分支**

找到 line 87-88（"Authorized Workspace" dropdown item）：

```vue
<el-dropdown-item v-if="isSystemShare" @click="...">
  ...
</el-dropdown-item>
```

整个块删除。

找到 line 113（`v-if="apiType === 'workspace' && permissionPrecise.auth(model.id)"`）：

把 `apiType === 'workspace' && ` 删掉，保留 `permissionPrecise.auth(model.id)`：

```vue
<el-dropdown-item v-if="permissionPrecise.auth(model.id)" @click="...">
  ...
</el-dropdown-item>
```

找到 line 141-144（`<AuthorizedWorkspace v-if="isSystemShare">`）：

整个块删除。

找到 line 148（`v-if="apiType === 'workspace'"` 包裹 `<ResourceAuthorizationDrawer>`）：

去掉 `v-if`，让 ResourceAuthorizationDrawer 无条件渲染：

```vue
<ResourceAuthorizationDrawer ref="resourceAuthRef" :resource_type="..." :resource="..." />
```

- [ ] **Step 5: 改 prop 类型 + 删 isSystemShare computed**

找到 line 181 的 prop 定义：

```ts
apiType: 'systemShare' | 'workspace' | 'systemManage'
```

如果是必填 prop，把它整个删除（PF3 已经不传了）。如果是 optional：

```ts
apiType?: 'workspace'
```

或直接删 prop。

找到 line 186-188 的 `isSystemShare` computed：

```ts
const isSystemShare = computed(() => {
  return props.apiType === 'systemShare'
})
```

整个块删除。

找到 line 37 的 `<el-tag v-if="isShared || isSystemShare">`：

去掉 `|| isSystemShare`，保留 `isShared`：

```vue
<el-tag v-if="isShared" ... />
```

找到 line 192 的 `permissionMap['model'][props.apiType]`：

直接改为 `permissionMap['model']['workspace']`。

- [ ] **Step 6: 改 loadSharedApi 调用**

找到 line 244, 255, 278：

```ts
loadSharedApi({ type: 'model', systemType: props.apiType }).XXX(...)
```

替换为：

```ts
loadSharedApi({ type: 'model', systemType: 'workspace' }).XXX(...)
```

- [ ] **Step 7: 移除 AuthorizedWorkspace import（如不再用）**

```bash
grep -n "AuthorizedWorkspace" ui/src/views/model/component/ModelCard.vue
```

如果 grep 0 hit 除了 import 那一行，删除 import 那行。

- [ ] **Step 8: 验证**

```bash
grep -n "AppIcon\|isSystemShare\|isSystemManage\|systemShare\|systemManage" ui/src/views/model/component/ModelCard.vue
```

期望：0 hit。

```bash
cd ui && npm run type-check
```

期望：退出 0。

- [ ] **Step 9: Commit**

```bash
git add ui/src/views/model/component/ModelCard.vue
git commit -m "refactor(ui): ModelCard atom upgrade + drop dead systemShare branches"
```

---

### Task PG2: CreateModelDialog.vue AppIcon + apiType cleanup

**Files:**
- Modify: `ui/src/views/model/component/CreateModelDialog.vue`

- [ ] **Step 1: 加 imports**

```ts
import { LucideIcon } from '@/components/lucide-icon'
```

- [ ] **Step 2: 替换 6 处 AppIcon**

| 行 | 旧 iconName | 新 LucideIcon name |
|---|---|---|
| 48 | `app-warning` | `alert-triangle` |
| 75 | `app-warning` | `alert-triangle` |
| 126 | `app-warning` | `alert-triangle` |
| 156 | `app-add-outlined` | `plus` |
| 208 | `app-edit` | `pencil` |
| 213 | `app-delete` | `trash-2` |

- [ ] **Step 3: 替换 apiType computed（line 251-259）**

```ts
const apiType = computed(() => {
  if (route.path.includes('shared')) {
    return 'systemShare'
  } else if (route.path.includes('resource-management')) {
    return 'systemManage'
  } else {
    return 'workspace'
  }
})
```

替换为：

```ts
const apiType = 'workspace'
```

或彻底删除 computed，把 line 389 的 `apiType.value` 改为字面量 `'workspace'`。

- [ ] **Step 4: 改 loadSharedApi 调用**

找到 line 389：

```ts
loadSharedApi({ type: 'model', systemType: apiType.value }).createModel(...)
```

替换为：

```ts
loadSharedApi({ type: 'model', systemType: 'workspace' }).createModel(...)
```

如果 Step 3 已彻底删 apiType computed，apiType.value 引用就不存在了 — 同样改写。

- [ ] **Step 5: 验证**

```bash
grep -n "AppIcon\|apiType\|systemShare\|systemManage" ui/src/views/model/component/CreateModelDialog.vue
```

期望：0 hit。

```bash
cd ui && npm run type-check
```

- [ ] **Step 6: Commit**

```bash
git add ui/src/views/model/component/CreateModelDialog.vue
git commit -m "refactor(ui): CreateModelDialog AppIcon→Lucide + drop apiType branches"
```

---

### Task PG3: Provider.vue + 4 个对话框 AppIcon-only 替换

**Files:**
- Modify: `ui/src/views/model/component/Provider.vue`
- Modify: `ui/src/views/model/component/EditModel.vue`
- Modify: `ui/src/views/model/component/SelectProviderDialog.vue`
- Modify: `ui/src/views/model/component/ParamSettingDialog.vue`
- Modify: `ui/src/views/model/component/AddParamDrawer.vue`

每个文件加 `import { LucideIcon } from '@/components/lucide-icon'`，然后逐个 grep + 替换 AppIcon。

- [ ] **Step 1: Provider.vue**

```ts
import { LucideIcon } from '@/components/lucide-icon'
```

替换：

| 行 | 旧 iconName | 新 |
|---|---|---|
| 11-15 | `app-shared-active` | `share-2` |
| 24-28 | `app-all-menu-active`（值是 `:iconName="..."` 绑定的字符串）| 改为 `<LucideIcon name="grid-2x2" :size="20" />` |
| 40 | `app-folder` | `folder` |
| 74 | `app-folder` | `folder` |

注意 line 24-28 是 `:iconName="'app-all-menu-active'"` 这种绑定形式，需要整个改成 Lucide 渲染。

- [ ] **Step 2: EditModel.vue**

```bash
grep -n "AppIcon" ui/src/views/model/component/EditModel.vue
```

按映射表（见 PB1 Step 4）替换所有 AppIcon。

- [ ] **Step 3: SelectProviderDialog.vue**

```bash
grep -n "AppIcon" ui/src/views/model/component/SelectProviderDialog.vue
```

同上替换。

- [ ] **Step 4: ParamSettingDialog.vue**

```bash
grep -n "AppIcon" ui/src/views/model/component/ParamSettingDialog.vue
```

同上替换。

- [ ] **Step 5: AddParamDrawer.vue**

```bash
grep -n "AppIcon" ui/src/views/model/component/AddParamDrawer.vue
```

同上替换。

- [ ] **Step 6: 验证整个 model/component 全清**

```bash
grep -rn "AppIcon" ui/src/views/model
```

期望：0 hit。

```bash
cd ui && npm run type-check
```

- [ ] **Step 7: Commit**

```bash
git add ui/src/views/model/component
git commit -m "refactor(ui): model sub-components AppIcon→Lucide"
```

---

## Phase PH · tool/store.ts 死方法清

### Task PH1: 删 getStoreKBList / getStoreAppList + 2 个 caller

**Files:**
- Modify: `ui/src/api/tool/store.ts`
- Modify: `ui/src/views/knowledge/template-store/TemplateStoreDialog.vue`
- Modify: `ui/src/views/application/template-store/TemplateStoreDialog.vue`
- Possibly Delete: 整个 `template-store/` 目录（如果 Dialog 是唯一文件）

- [ ] **Step 1: 先确认 caller 文件结构**

```bash
ls ui/src/views/knowledge/template-store
ls ui/src/views/application/template-store
```

如果目录里除了 `TemplateStoreDialog.vue` 没别的文件 → 整目录可删。如果有其它文件 → 只动 Dialog。

- [ ] **Step 2: 确认 TemplateStoreDialog 在哪些地方被引用**

```bash
grep -rn "TemplateStoreDialog\|template-store" ui/src --include="*.ts" --include="*.vue"
```

记下每个 caller。

- [ ] **Step 3: 处理选项**

**选项 A（推荐）**：删除 Dialog + 入口按钮。

- 删除 `ui/src/views/knowledge/template-store/TemplateStoreDialog.vue`
- 删除 `ui/src/views/application/template-store/TemplateStoreDialog.vue`
- 删除目录（如 Step 1 确认目录除 Dialog 无其它文件）：
  ```bash
  rm -rf ui/src/views/knowledge/template-store
  rm -rf ui/src/views/application/template-store
  ```
- 对每个引用 Dialog 的 caller 文件：删除 import 行 + 删除 `<TemplateStoreDialog>` 的标签使用 + 删除打开 Dialog 的按钮（搜 "templateStore" / "openTemplate" 等关键词找入口按钮）

**选项 B（保守）**：保留 Dialog 文件但内部改成"功能暂未上线"提示。

实施时选 **A**：用户已确认"删除调用"。

- [ ] **Step 4: 删除 store.ts 中的 2 个方法**

打开 `ui/src/api/tool/store.ts`：

- 删除 `getStoreKBList` const 定义（约 5-10 行）
- 删除 `getStoreAppList` const 定义
- 删除 `export default { ... }` 中的这 2 个 key

verify：

```bash
grep -n "getStoreKBList\|getStoreAppList" ui/src/api/tool/store.ts
```

期望：0 hit。

- [ ] **Step 5: 全局 grep 验证无遗留**

```bash
grep -rn "getStoreKBList\|getStoreAppList" ui/src
grep -rn "TemplateStoreDialog" ui/src
```

期望：均 0 hit（或仅注释行）。

- [ ] **Step 6: type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

期望：均退出 0。如有错，说明某 caller 的 import / 标签 / 按钮还没清干净。

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore(ui): remove dead getStoreKBList/getStoreAppList + callers"
```

---

## Phase PI · 工作流画布 grid 对齐 Spec W1

### Task PI1: 修改 LogicFlow grid 配置 + 加 CSS 网格

**Files:**
- Modify: `ui/src/workflow/index.vue` (grid config 行 67-73)
- Modify: `ui/src/styles/workflow.scss` (lf-canvas-overlay 选择器附近)

- [ ] **Step 1: 修改 workflow/index.vue grid 配置**

打开 `ui/src/workflow/index.vue`，找到 line 67-73 的 LogicFlow 配置：

```ts
grid: {
  size: 10,
  type: 'dot',
  config: {
    color: '#DEE0E3',
    thickness: 1,
  },
},
```

替换为：

```ts
grid: false,
```

- [ ] **Step 2: 改 LogicFlow background 颜色**

找到 line 64-66：

```ts
background: {
  backgroundColor: '#f5f6f7',
},
```

替换为：

```ts
background: {
  backgroundColor: '#ffffff',
},
```

（spec §6.4 要求白底；可选保留原色，根据视觉判断。）

- [ ] **Step 3: 加 CSS 20px 线网到 workflow.scss**

打开 `ui/src/styles/workflow.scss`，找到 `.lf-canvas-overlay, .lf-container` 块（line 88-95 附近）：

```scss
.lf-canvas-overlay,
.lf-container {
  // 原有 rules
}
```

在这个块内追加：

```scss
.lf-canvas-overlay,
.lf-container {
  background-color: #ffffff;
  background-image:
    linear-gradient(#f1f5f9 1px, transparent 1px),
    linear-gradient(90deg, #f1f5f9 1px, transparent 1px);
  background-size: 20px 20px;
}
```

保留原有 rules，只追加这 4 行。

- [ ] **Step 4: type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

期望：均退出 0。

- [ ] **Step 5: dev server 视觉验证**

```bash
cd ui && npm run dev
```

打开任一 workflow editor URL（如 `/application/{id}/workflow`），确认背景是 20px 线网而不是 10px 点。LogicFlow 拖动 / zoom / 节点等不动。

完事 Ctrl+C 停 dev server。

- [ ] **Step 6: Commit**

```bash
git add ui/src/workflow/index.vue ui/src/styles/workflow.scss
git commit -m "fix(ui): workflow canvas uses 20px line grid (spec W1)"
```

---

## Final Verification（PE7 风格收尾）

### Task FINAL: 全局死引用扫描 + 完整 dev-server 走查

**Files:** (no edits)

- [ ] **Step 1: 全量 grep 死引用**

```bash
echo "=== AppIcon in 5 重做+模型 views ==="
grep -rn "AppIcon" ui/src/views/document ui/src/views/problem ui/src/views/hit-test ui/src/views/trigger ui/src/views/model

echo "=== isSystemShare / systemShare / systemManage 残留 ==="
grep -rn "isSystemShare\|isSystemManage\|systemShare\|systemManage" ui/src/views/model

echo "=== 死 store 方法残留 ==="
grep -rn "getStoreKBList\|getStoreAppList\|TemplateStoreDialog" ui/src

echo "=== template-store 目录残留 ==="
ls ui/src/views/knowledge/template-store 2>&1
ls ui/src/views/application/template-store 2>&1
```

期望：前 3 项 0 hit；后 2 项 "No such file or directory"。

- [ ] **Step 2: 最终 type-check + build**

```bash
cd ui && npm run type-check && npm run build
```

- [ ] **Step 3: 后端零改动确认**

```bash
git diff main -- apps/ | wc -l
```

期望：0。

- [ ] **Step 4: dev server 综合走查**

```bash
cd ui && npm run dev
```

依次打开（每页验证 PageHeader + .card-unified + Lucide icon + StatusDot 正常）：

1. `/document/...`（重做 document）
2. `/problem/...`（重做 problem）
3. `/hit-test/...`（重做 hit-test）
4. `/trigger`（重做 trigger）
5. `/knowledge`（轻量打磨）
6. `/tool`（轻量打磨）
7. `/model`（轻量打磨）
8. `/paragraph/...`（轻量打磨 — 这页改最多）
9. 任一 workflow editor URL（grid 20px 线网）

每页确认浏览器 console 0 error 0 warning。

- [ ] **Step 5: 完成定义（无需 commit）**

按 spec §9.5 检查：

1. 4 重做页 + 4 轻量页 + 模型 7 子组件 + 工作流 grid 全部完成 ✓
2. `apps/` git diff 为空 ✓
3. type-check / build 全清白 ✓
4. dev server 走过去无 console error ✓
5. 30 秒辨认测试通过 ✓
6. 死引用 grep 全 0 hit ✓

---

## 完成定义

本计划全部 task 完成后，spec `2026-05-23-knowledge-capability-model-redesign-design.md` §9.5 的 6 条完成定义全部满足。

## 依赖关系

PA1 → 所有 task 之前
PG1 → PF3（必须先改 ModelCard 让 apiType 可选，再删 index.vue 的传递）
PG3 → PG2 → PG1（按需，但都可独立运行）
PI1、PH1、PF1、PF2 完全独立
PB1、PC1、PD1、PE1 完全独立（可并行）

## subagent driven 推荐执行顺序

PA1 → PB1 + PC1 + PD1 + PE1 并发 → PF1 + PF2 + PI1 + PH1 并发 → PG1 → PG2 → PG3 → PF3 → PF4 → FINAL
