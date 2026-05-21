<template>
  <div class="error-page">
    <div class="error-page__icon">
      <LucideIcon name="shield-x" :size="80" />
    </div>
    <h1 class="error-page__title">{{ $t('common.error.noPermission.title') }}</h1>
    <p class="error-page__hint">{{ $t('common.error.noPermission.hint') }}</p>
    <el-button type="primary" @click="goHome">
      {{ $t('common.error.backHome') }}
    </el-button>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import LucideIcon from '@/components/lucide-icon/LucideIcon.vue'
const router = useRouter()
const goHome = () => router.push('/')
</script>

<style lang="scss" scoped>
.error-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: var(--main-bg);
  gap: 16px;
  color: var(--text-secondary);
}
.error-page__icon {
  color: var(--brand-primary);
  line-height: 1;
}
.error-page__title {
  font-size: var(--font-size-xl);
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}
.error-page__hint {
  font-size: var(--font-size-base);
  margin: 0 0 12px;
}
</style>
