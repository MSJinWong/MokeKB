<template>
  <article class="trend-chart card-unified">
    <header class="trend-chart__head">
      <h3 class="trend-chart__title">{{ $t('views.applicationOverview.trend.title') }}</h3>
      <div class="trend-chart__filters">
        <el-select v-model="range" size="small" class="trend-chart__range">
          <el-option value="7" :label="$t('views.applicationOverview.trend.last7')" />
          <el-option value="30" :label="$t('views.applicationOverview.trend.last30')" />
          <el-option value="90" :label="$t('views.applicationOverview.trend.last90')" />
        </el-select>
        <el-select v-model="metric" size="small" class="trend-chart__metric">
          <el-option value="users" :label="$t('views.applicationOverview.stats.users')" />
          <el-option value="questions" :label="$t('views.applicationOverview.stats.questions')" />
          <el-option value="tokens" :label="$t('views.applicationOverview.stats.tokens')" />
          <el-option value="satisfaction" :label="$t('views.applicationOverview.stats.satisfaction')" />
        </el-select>
      </div>
    </header>
    <div ref="chartRef" class="trend-chart__canvas" />
  </article>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import { GridComponent, TooltipComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([LineChart, GridComponent, TooltipComponent, CanvasRenderer])

const props = defineProps<{
  series: Array<{ date: string; value: number }>
}>()

const emit = defineEmits<{
  (e: 'change', payload: { range: string; metric: string }): void
}>()

const range = ref('7')
const metric = ref('questions')
const chartRef = ref<HTMLDivElement>()
let chart: echarts.ECharts | null = null

function renderChart() {
  if (!chartRef.value) return
  if (!chart) chart = echarts.init(chartRef.value)
  chart.setOption({
    grid: { left: 32, right: 16, top: 16, bottom: 24 },
    xAxis: {
      type: 'category',
      data: props.series.map((p) => p.date),
      axisLine: { lineStyle: { color: '#e5e7eb' } },
      axisLabel: { color: '#94a3b8', fontSize: 10 },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { lineStyle: { color: '#f1f5f9' } },
      axisLabel: { color: '#94a3b8', fontSize: 10 },
    },
    tooltip: { trigger: 'axis' },
    series: [
      {
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        data: props.series.map((p) => p.value),
        lineStyle: { color: '#0f172a', width: 1.5 },
        itemStyle: { color: '#0f172a' },
        areaStyle: { color: 'rgba(15, 23, 42, 0.04)' },
      },
    ],
  })
}

watch([range, metric], () => {
  emit('change', { range: range.value, metric: metric.value })
})

watch(() => props.series, () => renderChart(), { deep: true })

onMounted(async () => {
  await nextTick()
  renderChart()
  emit('change', { range: range.value, metric: metric.value })
})

onBeforeUnmount(() => {
  chart?.dispose()
  chart = null
})
</script>

<style lang="scss" scoped>
.trend-chart {
  padding: 14px 16px;
}
.trend-chart__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}
.trend-chart__title {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}
.trend-chart__filters {
  display: flex;
  gap: 8px;
}
.trend-chart__range,
.trend-chart__metric {
  width: 110px;
}
.trend-chart__canvas {
  height: 220px;
  width: 100%;
}
</style>
