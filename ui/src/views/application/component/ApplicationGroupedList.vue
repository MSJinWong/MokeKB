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
          :to="buildTo(item)"
          @action="(kind, app) => $emit('action', kind, app)"
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
import type { RouteLocationRaw } from 'vue-router'

interface ApplicationItem {
  id: string
  name: string
  folder_id?: string | null
  is_publish?: boolean
  type?: string
  [k: string]: any
}
interface FolderItem {
  id: string
  name: string
  children?: FolderItem[]
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
  buildTo: (item: ApplicationItem) => RouteLocationRaw
}>()

type CardAction = 'setting' | 'auth' | 'trigger' | 'move' | 'copy' | 'export' | 'delete'

defineEmits<{
  (e: 'create', folderId: string): void
  (e: 'action', kind: CardAction, app: ApplicationItem): void
}>()

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
  // folder 接口返回的是嵌套树，根节点下挂用户新建的标签，需要递归扁平化
  // 否则子标签永远不会成为分组，带这些标签的智能体在画面上消失。
  const flat = flattenFolders(props.folders)
  const result: GroupedView[] = flat.map((f) => ({
    key: f.id,
    label: f.name,
    items: byFolder.get(f.id) || [],
  }))
  if (byFolder.has('__unsorted__')) {
    result.push({
      key: '__unsorted__',
      label: '未分类',
      items: byFolder.get('__unsorted__') || [],
    })
  }
  return result.filter((g) => g.items.length > 0)
})

function flattenFolders(folders: FolderItem[]): FolderItem[] {
  const out: FolderItem[] = []
  for (const f of folders) {
    out.push(f)
    if (f.children?.length) out.push(...flattenFolders(f.children))
  }
  return out
}
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
