<template>
  <div class="workbench-placeholder">
    <h1>{{ $t('rail.workbench') }}</h1>
    <p>{{ $t('workbench.placeholder') }}</p>
  </div>
</template>

<style lang="scss" scoped>
.workbench-placeholder {
  padding: 24px;
  color: var(--text-secondary);
  h1 {
    color: var(--text-primary);
    font-size: var(--font-size-xl);
    margin-bottom: 12px;
  }
}
</style>
