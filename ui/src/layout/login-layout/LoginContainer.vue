<template>
  <div class="login-container">
    <header v-if="title || $slots.title" class="login-container__title">
      <slot name="title">
        <h1>{{ title }}</h1>
      </slot>
      <p v-if="subTitle" class="subtitle">{{ subTitle }}</p>
    </header>
    <div class="login-container__body">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps({
  title: String,
  subTitle: String,
})
</script>

<style lang="scss" scoped>
.login-container {
  width: 100%;
}
.login-container__title {
  margin-bottom: 28px;
  h1 {
    font-size: 22px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0 0 6px;
  }
  .subtitle {
    font-size: var(--font-size-base);
    color: var(--text-secondary);
    margin: 0;
  }
}
.login-container__body {
  width: 100%;
}
</style>
