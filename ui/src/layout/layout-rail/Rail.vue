<template>
  <nav class="app-rail" :aria-label="$t('rail.aria')">
    <router-link to="/workbench" class="app-rail__brand" aria-label="home">
      <img src="@/assets/logo/logo-currentColor.svg" alt="" />
    </router-link>
    <ul class="app-rail__items">
      <li v-for="m in RAIL_MODULES" :key="m.key">
        <router-link
          :to="m.path"
          class="app-rail__item"
          :class="{ 'is-active': activeKey === m.key }"
          v-hasPermission="undefined"
        >
          <LucideIcon :name="m.lucide" :size="20" />
          <span class="app-rail__label">{{ $t(m.titleKey) }}</span>
        </router-link>
      </li>
    </ul>
  </nav>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { RAIL_MODULES, findActiveModuleKey } from './modules'
import { LucideIcon } from '@/components/lucide-icon'

const route = useRoute()
const activeKey = computed(() => findActiveModuleKey(route.path))
</script>

<style lang="scss" scoped>
.app-rail {
  width: var(--rail-width);
  background: var(--rail-bg);
  color: var(--rail-text);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 0;
  flex-shrink: 0;
  height: 100vh;
  position: sticky;
  top: 0;
}
.app-rail__brand {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 16px;
  color: var(--rail-text-active);
}
.app-rail__brand img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.app-rail__items {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
  width: 100%;
}
.app-rail__item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 10px 6px;
  font-size: 10px;
  color: var(--rail-text);
  text-decoration: none;
  border-left: 2px solid transparent;
  transition:
    color 0.15s,
    background 0.15s,
    border-color 0.15s;
}
.app-rail__item:hover {
  background: var(--rail-hover-bg);
  color: var(--rail-text-active);
}
.app-rail__item.is-active {
  background: var(--rail-hover-bg);
  color: var(--rail-text-active);
  border-left-color: var(--rail-active-bar);
}
.app-rail__label {
  font-size: 10px;
  line-height: 1.2;
  text-align: center;
}
</style>
