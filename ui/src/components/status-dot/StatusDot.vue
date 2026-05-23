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
