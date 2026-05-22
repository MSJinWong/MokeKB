<template>
  <div class="overview-page" v-loading="loading">
    <HeroBar
      :detail="detail"
      @display-setting="openDisplaySettingDialog"
      @embed="openEmbedDialog"
      @access-limit="openLimitDialog"
      @go-chat="goChat"
    />

    <StatGrid :stats="stats" />

    <div class="overview-page__row">
      <TrendChart :series="trendSeries" @change="onTrendChange" />
      <AccessPanel
        :access-token="accessToken"
        :base-url="origin"
        @toggle-active="onToggleActive"
        @copy="onCopy"
        @manage-keys="openAPIKeyDialog"
      />
    </div>

    <EmbedDialog
      ref="EmbedDialogRef"
      :data="detail"
      :api-input-params="mapToUrlParams(apiInputParams)"
    />
    <APIKeyDialog ref="APIKeyDialogRef" />
    <!-- 社区版/企业版 访问限制 -->
    <component :is="currentLimitDialog" ref="LimitDialogRef" @refresh="refresh" />
    <!-- 社区版/企业版 显示设置 -->
    <component
      :is="currentDisplaySettingDialog"
      ref="DisplaySettingDialogRef"
      @refresh="refresh"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, shallowRef, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import HeroBar from './component/HeroBar.vue'
import StatGrid from './component/StatGrid.vue'
import TrendChart from './component/TrendChart.vue'
import AccessPanel from './component/AccessPanel.vue'
import EmbedDialog from './component/EmbedDialog.vue'
import APIKeyDialog from './component/APIKeyDialog.vue'
import LimitDialog from './component/LimitDialog.vue'
import DisplaySettingDialog from './component/DisplaySettingDialog.vue'
import XPackLimitDrawer from './xpack-component/XPackLimitDrawer.vue'
import XPackDisplaySettingDialog from './xpack-component/XPackDisplaySettingDialog.vue'
import { nowDate, beforeDay } from '@/utils/time'
import { MsgSuccess } from '@/utils/message'
import { copyClick } from '@/utils/clipboard'
import { mapToUrlParams } from '@/utils/application'
import { t } from '@/locales'
import { EditionConst } from '@/utils/permission/data'
import { hasPermission } from '@/utils/permission/index'
import { loadSharedApi } from '@/utils/dynamics-api/shared-api'

const route = useRoute()
const {
  params: { id },
} = route as any

const apiType = computed(() => {
  if (route.path.includes('resource-management')) {
    return 'systemManage'
  } else {
    return 'workspace'
  }
})

const loading = ref(false)
const detail = ref<any>(null)
const accessToken = ref<any>({})
const apiInputParams = ref<any[]>([])

const origin = window.location.origin + `${window.MaxKB.chatPrefix}`

// Stats + trend (derived from statistics API)
const rawStats = ref<any[]>([])
const stats = ref<any>(null)
const trendSeries = ref<Array<{ date: string; value: number }>>([])
const currentMetric = ref<string>('questions')
const currentRange = ref<number | string>(7)

const METRIC_TO_FIELD: Record<string, string> = {
  users: 'customer_num',
  questions: 'chat_record_count',
  tokens: 'tokens_num',
  satisfaction: 'star_num',
}

function sum(arr: number[]): number {
  return arr.reduce((acc, v) => acc + (Number(v) || 0), 0)
}

function buildStats(data: any[]) {
  const userArr = data.map((d: any) => Number(d.customer_num) || 0)
  const qaArr = data.map((d: any) => Number(d.chat_record_count) || 0)
  const tokenArr = data.map((d: any) => Number(d.tokens_num) || 0)
  const starArr = data.map((d: any) => Number(d.star_num) || 0)
  const trampleArr = data.map((d: any) => Number(d.trample_num) || 0)
  const starTotal = sum(starArr)
  const trampleTotal = sum(trampleArr)
  const denom = starTotal + trampleTotal
  stats.value = {
    user_count: sum(userArr),
    qa_count: sum(qaArr),
    token_count: sum(tokenArr),
    satisfaction: denom > 0 ? starTotal / denom : null,
  }
}

function buildTrend(data: any[], metric: string) {
  const field = METRIC_TO_FIELD[metric] || 'chat_record_count'
  trendSeries.value = (data || []).map((d: any) => ({
    date: (d.day || '').slice(5), // MM-DD for axis brevity
    value: Number(d[field]) || 0,
  }))
}

async function fetchStatistics(range: number | string, metric: string) {
  const days = Number(range) || 7
  const payload = {
    start_time: beforeDay(days),
    end_time: nowDate,
  }
  const res: any = await loadSharedApi({ type: 'application', systemType: apiType.value })
    .getStatistics(id, payload)
  rawStats.value = res.data || []
  buildStats(rawStats.value)
  buildTrend(rawStats.value, metric)
}

async function onTrendChange(payload: { range: string; metric: string }) {
  currentRange.value = payload.range
  currentMetric.value = payload.metric
  try {
    await fetchStatistics(payload.range, payload.metric)
  } catch (e) {
    console.warn('[overview] trend load failed:', e)
  }
}

function refresh() {
  getAccessToken()
}

function getAccessToken() {
  loadSharedApi({ type: 'application', systemType: apiType.value })
    .getAccessToken(id, loading)
    .then((res: any) => {
      accessToken.value = res?.data
    })
}

function getDetail() {
  loadSharedApi({ type: 'application', systemType: apiType.value })
    .getApplicationDetail(id, loading)
    .then((res: any) => {
      detail.value = res.data
      detail.value.work_flow?.nodes
        ?.filter((v: any) => v.id === 'base-node')
        .map((v: any) => {
          apiInputParams.value = v.properties.api_input_field_list
            ? v.properties.api_input_field_list.map((v: any) => ({
                name: v.variable,
                value: v.default_value,
              }))
            : v.properties.input_field_list
              ? v.properties.input_field_list
                  .filter((v: any) => v.assignment_method === 'api_input')
                  .map((v: any) => ({ name: v.variable, value: v.default_value }))
              : []
        })
    })
}

async function updateAccessToken(obj: any, msg: string) {
  return loadSharedApi({ type: 'application', systemType: apiType.value })
    .putAccessToken(id as string, obj, loading)
    .then((res: any) => {
      accessToken.value = res?.data
      MsgSuccess(msg)
    })
}

function onToggleActive(val: boolean) {
  const msg = val
    ? t('common.status.enableSuccess')
    : t('common.status.disableSuccess')
  updateAccessToken({ is_active: val }, msg)
}

function onCopy(text: string) {
  copyClick(text)
}

function goChat() {
  if (!accessToken.value?.is_active || !accessToken.value?.access_token) return
  const urlParams = mapToUrlParams(apiInputParams.value)
    ? '?' + mapToUrlParams(apiInputParams.value)
    : ''
  const shareUrl = `${origin}/` + accessToken.value.access_token + urlParams
  window.open(shareUrl, '_blank')
}

// Dialog refs
const APIKeyDialogRef = ref<any>(null)
const EmbedDialogRef = ref<any>(null)
const DisplaySettingDialogRef = ref<any>(null)
const LimitDialogRef = ref<any>(null)
const currentDisplaySettingDialog = shallowRef<any>(null)
const currentLimitDialog = shallowRef<any>(null)

function openAPIKeyDialog() {
  APIKeyDialogRef.value?.open()
}

function openEmbedDialog() {
  if (!accessToken.value?.is_active) return
  EmbedDialogRef.value?.open(accessToken.value?.access_token)
}

function openDisplaySettingDialog() {
  if (hasPermission([EditionConst.IS_EE, EditionConst.IS_PE], 'OR')) {
    currentDisplaySettingDialog.value = XPackDisplaySettingDialog
  } else {
    currentDisplaySettingDialog.value = DisplaySettingDialog
  }
  nextTick(() => {
    if (currentDisplaySettingDialog.value === XPackDisplaySettingDialog) {
      loadSharedApi({ type: 'application', systemType: apiType.value })
        .getApplicationSetting(id)
        .then((ok: any) => {
          DisplaySettingDialogRef.value?.open(ok.data, detail.value)
        })
    } else {
      DisplaySettingDialogRef.value?.open(accessToken.value, detail.value)
    }
  })
}

function openLimitDialog() {
  if (hasPermission([EditionConst.IS_EE, EditionConst.IS_PE], 'OR')) {
    currentLimitDialog.value = XPackLimitDrawer
  } else {
    currentLimitDialog.value = LimitDialog
  }
  nextTick(() => {
    LimitDialogRef.value?.open(accessToken.value)
  })
}

onMounted(() => {
  getDetail()
  getAccessToken()
  // TrendChart emits 'change' on mount with default range/metric, which triggers
  // fetchStatistics via onTrendChange — no need to call it again here.
})
</script>

<style lang="scss" scoped>
.overview-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
  height: 100%;
  overflow: auto;
}
.overview-page__row {
  display: grid;
  grid-template-columns: 1.5fr 1fr;
  gap: 12px;
  padding: 0 20px 20px;
  @media (max-width: 1280px) {
    grid-template-columns: 1fr;
  }
}
</style>
