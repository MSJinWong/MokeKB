<template>
  <div class="app-layout">
    <el-alert
      v-if="user.isExpire()"
      :title="$t('layout.isExpire')"
      type="warning"
      class="app-layout__expire"
      show-icon
      :closable="false"
    />
    <div class="app-layout__body" :class="{ 'is-expire': user.isExpire() }">
      <Rail />
      <Side v-if="!isShared" />
      <main class="app-main">
        <AppMain />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { Rail } from '@/layout/layout-rail'
import { Side } from '@/layout/layout-side'
import AppMain from '@/layout/app-main/index.vue'
import useStore from '@/stores'

const route = useRoute()
const { user } = useStore()

const {
  params: { folderId },
  query: { from },
} = route as any

const isShared = computed(() => {
  return (
    folderId === 'shared' ||
    from === 'systemShare' ||
    from === 'systemManage' ||
    route.path.includes('resource-management')
  )
})
</script>

<style lang="scss" scoped>
.app-layout {
  min-height: 100vh;
  background: var(--app-layout-bg-color);
}
.app-layout__expire {
  position: sticky;
  top: 0;
  z-index: 100;
  border-radius: 0;
}
.app-layout__body {
  display: flex;
  min-height: 100vh;
}
.app-main {
  flex: 1;
  min-width: 0;
  background: var(--main-bg);
  padding: var(--app-view-padding);
  overflow: auto;
}
.is-expire .app-main {
  min-height: calc(100vh - 40px);
}
</style>
