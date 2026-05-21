<template>
  <Icon :icon="`lucide:${name}`" :width="size" :height="size" />
</template>

<script setup lang="ts">
import { Icon } from '@iconify/vue'

withDefaults(
  defineProps<{
    name: string
    size?: number | string
  }>(),
  {
    size: 18,
  },
)
</script>
