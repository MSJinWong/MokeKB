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

    <section class="workbench__quick">
      <header class="workbench__section-head">
        <h2>{{ $t('layout.workbench.quick.title') }}</h2>
      </header>
      <div class="workbench__quick-grid">
        <router-link
          v-for="q in quickActions"
          :key="q.key"
          :to="q.to"
          class="quick-card"
        >
          <div class="quick-card__icon">
            <LucideIcon :name="q.icon" :size="18" />
          </div>
          <div class="quick-card__body">
            <div class="quick-card__title">{{ q.title }}</div>
            <div class="quick-card__desc">{{ q.desc }}</div>
          </div>
        </router-link>
      </div>
    </section>

    <section class="workbench__recent">
      <header class="workbench__section-head">
        <h2>{{ $t('layout.workbench.recent.title') }}</h2>
        <router-link to="/application" class="see-more">
          {{ $t('common.viewAll') }}
          <LucideIcon name="chevron-right" :size="14" />
        </router-link>
      </header>
      <div v-if="agents.length" class="workbench__recent-grid">
        <RecentAgentCard v-for="a in agents" :key="a.id" :agent="a" />
      </div>
      <div v-else class="workbench__recent-empty">
        <p>{{ $t('layout.workbench.recent.empty') }}</p>
        <router-link to="/application" class="empty-cta">
          <LucideIcon name="plus" :size="14" />
          {{ $t('layout.workbench.recent.cta') }}
        </router-link>
      </div>
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
  if (h < 6) return t('layout.workbench.greeting.lateNight')
  if (h < 12) return t('layout.workbench.greeting.morning')
  if (h < 18) return t('layout.workbench.greeting.afternoon')
  return t('layout.workbench.greeting.evening')
})

const today = computed(() => {
  const d = new Date()
  const weekday = ['日', '一', '二', '三', '四', '五', '六'][d.getDay()]
  return `${d.toISOString().slice(0, 10)} · 周${weekday}`
})

const quickActions = computed(() => [
  {
    key: 'agent',
    icon: 'bot',
    to: '/application',
    title: t('layout.workbench.quick.newAgent.title'),
    desc: t('layout.workbench.quick.newAgent.desc'),
  },
  {
    key: 'library',
    icon: 'book-open-text',
    to: '/knowledge',
    title: t('layout.workbench.quick.uploadLibrary.title'),
    desc: t('layout.workbench.quick.uploadLibrary.desc'),
  },
  {
    key: 'model',
    icon: 'cpu',
    to: '/model',
    title: t('layout.workbench.quick.connectModel.title'),
    desc: t('layout.workbench.quick.connectModel.desc'),
  },
  {
    key: 'platform',
    icon: 'settings-2',
    to: '/system/setting/theme',
    title: t('layout.workbench.quick.platformSetting.title'),
    desc: t('layout.workbench.quick.platformSetting.desc'),
  },
])

const statCards = computed(() => [
  { key: 'agents', icon: 'bot', value: stats.value.agentCount, label: t('layout.workbench.stats.agents') },
  { key: 'conversations', icon: 'message-circle', value: stats.value.conversationCount, label: t('layout.workbench.stats.conversations') },
  { key: 'libraries', icon: 'book-open-text', value: stats.value.libraryCount, label: t('layout.workbench.stats.libraries') },
  { key: 'tools', icon: 'puzzle', value: stats.value.toolCount, label: t('layout.workbench.stats.tools') },
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
.workbench__section-head {
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
.workbench__quick-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  @media (max-width: 1024px) {
    grid-template-columns: repeat(2, 1fr);
  }
}
.quick-card {
  display: flex;
  align-items: center;
  gap: 12px;
  background: var(--main-bg);
  border: 1px solid var(--border-base);
  border-radius: var(--radius-md);
  padding: 14px 16px;
  text-decoration: none;
  transition:
    border-color 0.15s,
    box-shadow 0.15s,
    transform 0.15s;
  &:hover {
    border-color: var(--brand-primary-soft);
    box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06);
    transform: translateY(-2px);
  }
}
.quick-card__icon {
  width: 36px;
  height: 36px;
  background: var(--side-bg);
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-primary);
  flex-shrink: 0;
}
.quick-card__title {
  font-size: var(--font-size-md);
  font-weight: 500;
  color: var(--text-primary);
  line-height: 1.2;
}
.quick-card__desc {
  font-size: var(--font-size-xs);
  color: var(--text-tertiary);
  margin-top: 4px;
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
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  color: var(--text-tertiary);
  font-size: var(--font-size-base);
  padding: 32px 24px;
  text-align: center;
  background: var(--side-bg);
  border: 1px dashed var(--border-base);
  border-radius: var(--radius-md);
  p {
    margin: 0;
  }
}
.empty-cta {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 6px 14px;
  font-size: var(--font-size-sm);
  color: #ffffff;
  background: var(--brand-primary);
  border-radius: var(--radius-sm);
  text-decoration: none;
  &:hover {
    background: var(--brand-primary-hover);
  }
}
</style>
