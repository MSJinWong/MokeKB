<template>
  <router-link
    :to="to"
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
import type { RouteLocationRaw } from 'vue-router'
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

const props = defineProps<{
  app: ApplicationItem
  to: RouteLocationRaw
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
