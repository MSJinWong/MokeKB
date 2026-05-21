<template>
  <div class="app-layout">
    <div class="app-layout__body">
      <Rail />
      <Side />
      <main class="app-main">
        <AppMain />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Rail } from '@/layout/layout-rail'
import { Side } from '@/layout/layout-side'
import AppMain from '@/layout/app-main/index.vue'
</script>

<style lang="scss" scoped>
.app-layout {
  min-height: 100vh;
  background: var(--app-layout-bg-color);
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
</style>
