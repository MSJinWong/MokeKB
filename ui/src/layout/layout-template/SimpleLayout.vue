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
      <main class="app-main">
        <AppMain />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Rail } from '@/layout/layout-rail'
import AppMain from '@/layout/app-main/index.vue'
import useStore from '@/stores'

const { user } = useStore()
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
  overflow: auto;
  /* No padding here — modules' internal LayoutContainer handles its own padding */
}
.is-expire .app-main {
  min-height: calc(100vh - 40px);
}
</style>
