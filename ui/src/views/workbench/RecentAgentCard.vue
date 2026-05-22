<template>
  <router-link
    :to="`/application/${agent.id}/setting`"
    class="agent-card"
  >
    <div class="agent-card__row">
      <div class="agent-card__icon" :style="iconStyle">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <mask id="agent-eyes" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
            <rect width="24" height="24" fill="#fff" />
            <circle cx="9.25" cy="11" r="1.15" fill="#000" />
            <circle cx="14.75" cy="11" r="1.15" fill="#000" />
          </mask>
          <g fill="currentColor" mask="url(#agent-eyes)">
            <circle cx="12" cy="2.5" r="0.9" />
            <rect x="11.5" y="3.2" width="1" height="1.8" rx="0.3" />
            <rect x="4" y="5" width="16" height="12" rx="3" />
            <path d="M2 22 Q12 15 22 22 H2 Z" />
          </g>
        </svg>
      </div>
      <div class="agent-card__name">{{ agent.name }}</div>
    </div>
    <p v-if="agent.description" class="agent-card__desc">{{ agent.description }}</p>
    <div class="agent-card__meta">
      {{ $t('layout.workbench.recent.conversation24h', { n: agent.conversation24h }) }}
    </div>
  </router-link>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { RecentAgent } from '@/api/workbench'

const props = defineProps<{ agent: RecentAgent }>()

const iconStyle = computed(() => ({
  background: props.agent.icon ? 'transparent' : 'var(--brand-primary)',
}))
</script>

<style lang="scss" scoped>
.agent-card {
  display: block;
  background: var(--main-bg);
  border: 1px solid var(--border-base);
  border-radius: var(--radius-lg);
  padding: 16px;
  text-decoration: none;
  transition: box-shadow 0.15s, border-color 0.15s, transform 0.15s;
  min-height: 140px;

  &:hover {
    border-color: var(--brand-primary-soft);
    box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06);
    transform: translateY(-2px);
  }
}
.agent-card__row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}
.agent-card__icon {
  width: 28px;
  height: 28px;
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  flex-shrink: 0;
}
.agent-card__name {
  font-size: var(--font-size-md);
  font-weight: 500;
  color: var(--text-primary);
}
.agent-card__desc {
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
  line-height: 1.5;
  margin: 0 0 12px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.agent-card__meta {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
}
</style>
