<template>
  <div class="workbench">
    <header class="workbench__hello">
      <h1>{{ greeting }}，{{ userName }}</h1>
      <span class="date">{{ today }}</span>
    </header>

    <section class="workbench__stats">
      <article
        v-for="stat in statCards"
        :key="stat.key"
        class="stat-card"
      >
        <div class="stat-card__icon">
          <LucideIcon :name="stat.icon" :size="20" />
        </div>
        <div class="stat-card__body">
          <div class="stat-card__num">{{ stat.value }}</div>
          <div class="stat-card__label">{{ stat.label }}</div>
        </div>
      </article>
    </section>

    <section class="workbench__recent">
      <header class="workbench__recent-head">
        <h2>{{ $t('workbench.recent.title') }}</h2>
        <router-link to="/application" class="see-more">
          {{ $t('common.viewAll') }}
          <LucideIcon name="chevron-right" :size="14" />
        </router-link>
      </header>
      <div v-if="agents.length" class="workbench__recent-grid">
        <RecentAgentCard v-for="a in agents" :key="a.id" :agent="a" />
      </div>
      <p v-else class="workbench__recent-empty">{{ $t('workbench.recent.empty') }}</p>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { LucideIcon } from '@/components/lucide-icon'
import RecentAgentCard from './RecentAgentCard.vue'
import { loadWorkbenchStats, loadRecentAgents, type WorkbenchStats, type RecentAgent } from '@/api/workbench'
import useStore from '@/stores'

const { t } = useI18n()
const { user } = useStore()

const stats = ref<WorkbenchStats>({
  agentCount: 0,
  conversationCount: 0,
  libraryCount: 0,
  toolCount: 0,
})

const agents = ref<RecentAgent[]>([])

const userName = computed(() => {
  const info = user.userInfo
  return info?.nick_name || info?.username || ''
})

const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 6) return t('workbench.greeting.lateNight')
  if (h < 12) return t('workbench.greeting.morning')
  if (h < 18) return t('workbench.greeting.afternoon')
  return t('workbench.greeting.evening')
})

const today = computed(() => {
  const d = new Date()
  const weekday = ['日', '一', '二', '三', '四', '五', '六'][d.getDay()]
  return `${d.toISOString().slice(0, 10)} · 周${weekday}`
})

const statCards = computed(() => [
  { key: 'agents', icon: 'bot', value: stats.value.agentCount, label: t('workbench.stats.agents') },
  { key: 'conversations', icon: 'message-circle', value: stats.value.conversationCount, label: t('workbench.stats.conversations') },
  { key: 'libraries', icon: 'book-open-text', value: stats.value.libraryCount, label: t('workbench.stats.libraries') },
  { key: 'tools', icon: 'puzzle', value: stats.value.toolCount, label: t('workbench.stats.tools') },
])

onMounted(async () => {
  try {
    stats.value = await loadWorkbenchStats()
    agents.value = await loadRecentAgents()
  } catch (e) {
    console.warn('[workbench] load failed:', e)
  }
})
</script>

<style lang="scss" scoped>
.workbench {
  display: flex;
  flex-direction: column;
  gap: 24px;
  padding: 24px;
}
.workbench__hello {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  h1 {
    font-size: var(--font-size-xl);
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }
  .date {
    font-size: var(--font-size-sm);
    color: var(--text-tertiary);
  }
}
.workbench__stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  @media (max-width: 1024px) {
    grid-template-columns: repeat(2, 1fr);
  }
}
.stat-card {
  background: var(--side-bg);
  border: 1px solid var(--border-base);
  border-radius: var(--radius-md);
  padding: 14px 16px;
  display: flex;
  align-items: center;
  gap: 12px;
}
.stat-card__icon {
  width: 36px;
  height: 36px;
  background: var(--main-bg);
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--brand-primary);
  flex-shrink: 0;
}
.stat-card__num {
  font-size: 22px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.1;
}
.stat-card__label {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin-top: 4px;
}
.workbench__recent-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 16px;
  h2 {
    font-size: var(--font-size-lg);
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }
}
.see-more {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
  text-decoration: none;
  &:hover {
    color: var(--brand-primary);
  }
}
.workbench__recent-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}
.workbench__recent-empty {
  color: var(--text-tertiary);
  font-size: var(--font-size-base);
  padding: 24px;
  text-align: center;
  background: var(--side-bg);
  border: 1px dashed var(--border-base);
  border-radius: var(--radius-md);
}
</style>
