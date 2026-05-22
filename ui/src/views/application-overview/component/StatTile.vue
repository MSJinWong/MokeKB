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
