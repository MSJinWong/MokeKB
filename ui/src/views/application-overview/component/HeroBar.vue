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
