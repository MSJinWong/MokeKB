<template>
  <aside class="app-side" v-if="visible" :aria-label="$t('layout.side.aria')">
    <div class="app-side__title">{{ moduleTitle }}</div>
    <el-scrollbar>
      <el-menu
        :default-active="activeMenu"
        router
        class="app-side__menu"
        background-color="transparent"
      >
        <SidebarItem
          v-hasPermission="menu.meta?.permission"
          v-for="(menu, index) in subMenuList"
          :key="index"
          :menu="menu"
          :activeMenu="activeMenu"
        />
      </el-menu>
    </el-scrollbar>
  </aside>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { getChildRouteListByPathAndName } from '@/router/index'
import { RAIL_MODULES, findActiveModuleKey } from '@/layout/layout-rail/modules'
import SidebarItem from '@/layout/components/sidebar/SidebarItem.vue'

const route = useRoute()
const { t } = useI18n()

const subMenuList = computed(() => {
  const { meta } = route
  const list = getChildRouteListByPathAndName(meta.parentPath as string, meta.parentName as string)
  return list.filter((r: any) => !r.meta?.hideMenu)
})

const visible = computed(() => subMenuList.value.length >= 2)

const activeMenu = computed(() => {
  const { path, meta } = route
  return (meta.active as string) || path
})

const moduleTitle = computed(() => {
  const key = findActiveModuleKey(route.path)
  const m = RAIL_MODULES.find((x) => x.key === key)
  return m ? t(m.titleKey) : ''
})
</script>

<style lang="scss" scoped>
.app-side {
  width: var(--side-width);
  background: var(--side-bg);
  border-right: 1px solid var(--side-border);
  flex-shrink: 0;
  height: 100vh;
  display: flex;
  flex-direction: column;
  position: sticky;
  top: 0;
}
.app-side__title {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-primary);
  padding: 16px 14px 12px;
}
.app-side__menu {
  border: none;
  background: transparent;
  padding: 0 8px;

  :deep(.el-menu-item) {
    height: 36px;
    line-height: 36px;
    color: var(--side-item-text);
    border-radius: var(--radius-sm);
    margin-bottom: 2px;
    font-size: var(--font-size-base);
  }
  :deep(.el-menu-item:hover) {
    background: var(--side-item-hover-bg);
    color: var(--side-item-active-text);
  }
  :deep(.el-menu-item.is-active) {
    background: var(--side-item-active-bg);
    color: var(--side-item-active-text);
    font-weight: 500;
  }
}
</style>
