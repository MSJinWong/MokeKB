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
