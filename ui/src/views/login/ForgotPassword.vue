<template>
  <login-layout v-if="!loading" v-loading="loading">
    <LoginContainer
      :subTitle="theme.themeInfo?.slogan ? theme.themeInfo?.slogan : $t('theme.defaultSlogan')"
    >
      <h2 class="mb-24">{{ $t('views.login.forgotPassword') }}</h2>
      <p class="mb-24 forgot-tip">
        {{ $t('views.login.forgotPasswordContactAdmin') }}
      </p>
      <el-button size="large" type="primary" class="w-full" @click="router.push('/login')">
        {{ $t('views.login.buttons.backLogin') }}
      </el-button>
    </LoginContainer>
  </login-layout>
</template>
<script setup lang="ts">
import {onBeforeMount, ref} from 'vue'
import LoginContainer from '@/layout/login-layout/LoginContainer.vue'
import LoginLayout from '@/layout/login-layout/LoginLayout.vue'
import {useRouter} from 'vue-router'
import useStore from '@/stores'

const router = useRouter()
const {theme, user} = useStore()

const loading = ref<boolean>(false)

onBeforeMount(() => {
  loading.value = true
  user.asyncGetProfile().then(() => {
    loading.value = false
  })
})
</script>
<style lang="scss" scoped>
.forgot-tip {
  color: var(--el-text-color-regular);
  line-height: 1.6;
}
</style>
