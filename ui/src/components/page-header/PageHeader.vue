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
  font-size: var(--font-size-xl);
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.4;
  margin: 0;
}
.page-header__subtitle {
  font-size: var(--font-size-sm);
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
