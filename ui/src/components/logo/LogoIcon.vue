<template>
  <img class="logo-icon" src="@/assets/logo/logo2.svg" :height="height" :width="width" />
</template>
<script setup lang="ts">
defineOptions({ name: 'LogoIcon' })

defineProps({
  height: {
    type: String,
    default: '36px',
  },
  width: {
    type: String,
    default: undefined,
  },
})
</script>
<style lang="scss" scoped>
.logo-icon {
  display: block;
  flex-shrink: 0;
}

.custom-logo-color {
  path {
    fill: var(--el-color-primary);
  }
}
</style>
