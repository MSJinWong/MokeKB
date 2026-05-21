<template>
  <div class="login-layout">
    <aside class="login-layout__brand">
      <div class="brand-top">
        <img src="@/assets/logo/logo.svg" class="brand-logo" alt="logo" />
        <span class="brand-name">{{ productName }}</span>
      </div>
      <div class="brand-slogan">
        <h2>{{ $t('views.login.slogan.title') }}</h2>
        <p>{{ $t('views.login.slogan.subtitle') }}</p>
      </div>
      <div class="brand-deco" aria-hidden="true">
        <span class="circle c1" />
        <span class="circle c2" />
        <span class="circle c3" />
      </div>
    </aside>

    <section class="login-layout__form">
      <el-dropdown trigger="click" class="lang-switch" v-if="lang">
        <template #dropdown>
          <el-dropdown-menu class="w-180">
            <el-dropdown-item
              v-for="(l, i) in langList"
              :key="i"
              :value="l.value"
              @click="changeLang(l.value)"
              class="flex-between"
            >
              <span :class="l.value === user.getLanguage() ? 'primary' : ''">{{ l.label }}</span>
              <el-icon v-if="l.value === user.getLanguage()" class="primary"><Check /></el-icon>
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
        <el-button text>
          {{ currentLanguage }}<el-icon class="el-icon--right"><arrow-down /></el-icon>
        </el-button>
      </el-dropdown>

      <div class="form-wrap">
        <slot />
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import useStore from '@/stores'
import { useLocalStorage } from '@vueuse/core'
import { langList, localeConfigKey, getBrowserLang } from '@/locales/index'
import { PRODUCT_NAME as productName } from '@/utils/brand'

defineProps({
  lang: { type: Boolean, default: true },
})

const { user } = useStore()

const changeLang = (lang: string) => {
  useLocalStorage(localeConfigKey, getBrowserLang()).value = lang
  window.location.reload()
}

const currentLanguage = computed(() => {
  return langList.value?.filter((v: any) => v.value === user.getLanguage())?.[0]?.label
})
</script>

<style lang="scss" scoped>
.login-layout {
  height: 100vh;
  display: grid;
  grid-template-columns: 1fr 1fr;
  background: var(--main-bg);
}

.login-layout__brand {
  position: relative;
  background: var(--rail-bg);
  color: #fff;
  padding: 48px 56px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  overflow: hidden;
}
.brand-top {
  display: flex;
  align-items: center;
  gap: 12px;
  z-index: 1;
}
.brand-logo {
  width: 36px;
  height: 36px;
}
.brand-name {
  font-size: 18px;
  font-weight: 600;
  letter-spacing: 0.02em;
}
.brand-slogan {
  z-index: 1;
  h2 {
    font-size: 30px;
    font-weight: 600;
    margin: 0 0 12px;
    line-height: 1.3;
  }
  p {
    font-size: 14px;
    color: var(--rail-text);
    line-height: 1.6;
    max-width: 380px;
  }
}
.brand-deco {
  position: absolute;
  inset: 0;
  pointer-events: none;
  .circle {
    position: absolute;
    border: 1px solid var(--rail-hover-bg);
    border-radius: 50%;
  }
  .c1 {
    width: 240px;
    height: 240px;
    right: -80px;
    top: -80px;
  }
  .c2 {
    width: 180px;
    height: 180px;
    right: 40px;
    bottom: -60px;
  }
  .c3 {
    width: 100px;
    height: 100px;
    right: 200px;
    bottom: 60px;
  }
}

.login-layout__form {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}
.lang-switch {
  position: absolute;
  right: 20px;
  top: 20px;
}
.form-wrap {
  width: 100%;
  max-width: 400px;
}

@media (max-width: 900px) {
  .login-layout {
    grid-template-columns: 1fr;
  }
  .login-layout__brand {
    display: none;
  }
}
</style>
