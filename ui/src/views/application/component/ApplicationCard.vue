<template>
  <div class="app-card-wrap">
    <router-link :to="to" class="app-card card-unified card-unified--hover">
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
    <el-dropdown
      class="app-card__menu"
      trigger="click"
      @command="onMenuCommand"
      @click.stop.prevent
    >
      <el-button text class="app-card__menu-btn" @click.stop.prevent>
        <LucideIcon name="more-horizontal" :size="14" />
      </el-button>
      <template #dropdown>
        <el-dropdown-menu>
          <el-dropdown-item command="setting">
            <LucideIcon name="settings-2" :size="14" />
            <span class="ml-8">{{ $t('common.setting') }}</span>
          </el-dropdown-item>
          <el-dropdown-item command="auth">
            <LucideIcon name="users" :size="14" />
            <span class="ml-8">{{ $t('views.system.resourceAuthorization.title') }}</span>
          </el-dropdown-item>
          <el-dropdown-item command="trigger">
            <LucideIcon name="bell" :size="14" />
            <span class="ml-8">{{ $t('views.trigger.title') }}</span>
          </el-dropdown-item>
          <el-dropdown-item command="move">
            <LucideIcon name="folder-tree" :size="14" />
            <span class="ml-8">{{ $t('common.moveTo') }}</span>
          </el-dropdown-item>
          <el-dropdown-item command="copy">
            <LucideIcon name="copy" :size="14" />
            <span class="ml-8">{{ $t('common.copy') }}</span>
          </el-dropdown-item>
          <el-dropdown-item command="export" divided>
            <LucideIcon name="download" :size="14" />
            <span class="ml-8">{{ $t('common.export') }}</span>
          </el-dropdown-item>
          <el-dropdown-item command="delete">
            <LucideIcon name="trash-2" :size="14" />
            <span class="ml-8 app-card__danger">{{ $t('common.delete') }}</span>
          </el-dropdown-item>
        </el-dropdown-menu>
      </template>
    </el-dropdown>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { RouteLocationRaw } from 'vue-router'
import AgentAvatar from '@/components/agent-avatar/AgentAvatar.vue'
import StatusDot from '@/components/status-dot/StatusDot.vue'
import { LucideIcon } from '@/components/lucide-icon'

interface ApplicationItem {
  id: string
  name: string
  desc?: string
  description?: string
  type?: string
  is_publish?: boolean
  update_time?: string
  workspace_id?: string
  folder_id?: string | null
}

const props = defineProps<{
  app: ApplicationItem
  to: RouteLocationRaw
}>()

type CardAction = 'setting' | 'auth' | 'trigger' | 'move' | 'copy' | 'export' | 'delete'

const emit = defineEmits<{
  (e: 'action', kind: CardAction, app: ApplicationItem): void
}>()

const { t } = useI18n()

const typeLabel = computed(() => {
  const appType = (props.app.type || 'SIMPLE').toUpperCase()
  if (appType === 'WORK_FLOW') return t('views.application.advanced')
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

const ACTIONS: CardAction[] = ['setting', 'auth', 'trigger', 'move', 'copy', 'export', 'delete']
function onMenuCommand(cmd: string) {
  if ((ACTIONS as string[]).includes(cmd)) {
    emit('action', cmd as CardAction, props.app)
  }
}
</script>

<style lang="scss" scoped>
.app-card-wrap {
  position: relative;
}
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
.app-card__menu {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 1;
  opacity: 0;
  transition: opacity 0.15s;
}
.app-card-wrap:hover .app-card__menu,
.app-card__menu:focus-within {
  opacity: 1;
}
.app-card__menu-btn {
  padding: 2px 4px !important;
  color: var(--text-tertiary);
  &:hover {
    color: var(--text-primary);
  }
}
.app-card__danger {
  color: var(--el-color-danger);
}
</style>
