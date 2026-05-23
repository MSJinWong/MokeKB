<template>
  <div class="common-list">
    <ul v-if="data.length > 0">
      <template v-for="(item, index) in data" :key="index">
        <li
          @click.stop="clickHandle(item, index)"
          :class="current === item[props.valueKey] ? 'active color-primary-1' : ''"
          class="cursor"
          @mouseenter.stop="mouseenter(item)"
          @mouseleave.stop="mouseleave()"
        >
          <slot :row="item" :index="index"> </slot>
        </li>
      </template>
    </ul>
    <slot name="empty" v-else>
      <el-empty :description="$t('common.noData')" />
    </slot>
  </div>
</template>
<script setup lang="ts">
import { ref, watch } from 'vue'

defineOptions({ name: 'CommonList' })

const props = withDefaults(
  defineProps<{
    data: Array<any>
    defaultActive?: string
    valueKey?: string // 唯一标识的键名
  }>(),
  {
    data: () => [],
    defaultActive: '',
    valueKey: 'id',
  },
)

const current = ref<number | string>(0)

watch(
  () => props.defaultActive,
  (val) => {
    current.value = val
  },
  { immediate: true },
)

const emit = defineEmits(['click', 'mouseenter', 'mouseleave'])

function mouseenter(row: any) {
  emit('mouseenter', row)
}
function mouseleave() {
  emit('mouseleave')
}

function clickHandle(row: any, index: number) {
  current.value = row[props.valueKey]
  emit('click', row)
}

function clearCurrent() {
  current.value = 0
}
defineExpose({
  clearCurrent,
})
</script>
<style lang="scss" scoped>
@use '@/styles/nav-item' as nav;

.common-list {
  ul {
    margin: 0;
    padding: 0;
    list-style: none;
  }
  li {
    @include nav.nav-item-base;
  }
}
</style>
