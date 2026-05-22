<template>
  <span class="agent-avatar" :style="avatarStyle" :title="name">
    <span>{{ initial }}</span>
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    name: string
    size?: number
  }>(),
  { size: 28 }
)

const initial = computed(() => {
  const n = (props.name || '').trim()
  if (!n) return '?'
  return n.charAt(0).toUpperCase()
})

const avatarStyle = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
  fontSize: `${Math.round(props.size * 0.42)}px`,
}))
</script>

<style lang="scss" scoped>
.agent-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--brand-primary);
  color: #ffffff;
  font-weight: 600;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
  line-height: 1;
  user-select: none;
}
</style>
