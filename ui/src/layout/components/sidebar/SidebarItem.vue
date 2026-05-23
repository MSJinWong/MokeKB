<template>
  <div v-if="(!menu.meta || !menu.meta.hidden) && showMenu()" class="sidebar-item">
    <el-sub-menu
      v-if="menu?.children && menu?.children.length > 0"
      :index="menu.path"
      popper-class="sidebar-container-popper"
    >
      <template #title>
        <LucideIcon
          v-if="menu.meta && menu.meta.icon"
          :name="menuIcon"
          :size="16"
          class="sidebar-icon"
        />
        <span>{{ $t(menu.meta?.title as string) }}</span>
      </template>
      <sidebar-item
        v-hasPermission="child.meta?.permission"
        v-for="(child, index) in menu?.children"
        :key="index"
        :menu="child"
        :activeMenu="activeMenu"
      >
      </sidebar-item>
    </el-sub-menu>
    <el-menu-item
      v-else
      ref="subMenu"
      :index="menu.path"
      popper-class="sidebar-popper"
      @click="clickHandle(menu)"
    >
      <template #title>
        <LucideIcon
          v-if="menu.meta && menu.meta.icon"
          :name="menuIcon"
          :size="16"
          class="sidebar-icon"
        />
        <span v-if="menu.meta && menu.meta.title">{{ $t(menu.meta?.title as string) }}</span>
      </template>
    </el-menu-item>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter, useRoute, type RouteRecordRaw } from 'vue-router'
import { LucideIcon } from '@/components/lucide-icon'
import { isWorkFlow } from '@/utils/application'

const props = defineProps<{
  menu: RouteRecordRaw
  activeMenu: any
}>()

const router = useRouter()
const route = useRoute()
const {
  params: { id, type, from, folderId },
} = route as any

function showMenu() {
  if (isWorkFlow(type)) {
    return props.menu.name !== 'AppHitTest'
  } else {
    return true
  }
}

function clickHandle(item?: any) {
  if (isWorkFlow(type) && item?.name === 'AppSetting') {
    router.push({ path: `/application/${from}/${id}/workflow` })
  } else if (type === '4' && item?.name === 'knowledgeWorkflowSetting') {
    router.push({ path: `/knowledge/${id}/${folderId}/workflow` })
  }
}

const menuIcon = computed(() => {
  return (props.menu?.meta?.icon as string) ?? ''
})
</script>

<style scoped lang="scss">
@use '@/styles/nav-item' as nav;

.sidebar-item {
  .sidebar-icon {
    flex-shrink: 0;
  }
  :deep(.el-menu-item) {
    @include nav.nav-item-base;
  }
  :deep(.el-sub-menu__title) {
    @include nav.nav-item-base;
  }
  .el-sub-menu .el-menu-item {
    padding-left: 36px !important;
  }
}
</style>
