<template>
  <section class="stat-grid">
    <StatTile
      icon="users"
      :value="formatNumber(stats?.user_count)"
      :label="$t('views.applicationOverview.stats.users')"
      :delta="stats?.user_delta_label"
      :trend="stats?.user_trend"
    />
    <StatTile
      icon="message-circle"
      :value="formatNumber(stats?.qa_count)"
      :label="$t('views.applicationOverview.stats.questions')"
      :delta="stats?.qa_delta_label"
      :trend="stats?.qa_trend"
    />
    <StatTile
      icon="atom"
      :value="formatNumber(stats?.token_count)"
      :label="$t('views.applicationOverview.stats.tokens')"
      :delta="stats?.token_delta_label"
      :trend="stats?.token_trend"
    />
    <StatTile
      icon="smile"
      :value="formatPercent(stats?.satisfaction)"
      :label="$t('views.applicationOverview.stats.satisfaction')"
      :delta="stats?.satisfaction_delta_label"
      :trend="stats?.satisfaction_trend"
    />
  </section>
</template>

<script setup lang="ts">
import StatTile from './StatTile.vue'

defineProps<{ stats: any }>()

function formatNumber(n: number | undefined): string {
  if (n == null) return '0'
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`
  return String(n)
}

function formatPercent(n: number | undefined): string {
  if (n == null) return '—'
  return `${Math.round(n * 100)}%`
}
</script>

<style lang="scss" scoped>
.stat-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  padding: 16px 20px 0;
  @media (max-width: 1024px) {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
