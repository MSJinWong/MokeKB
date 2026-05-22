<template>
  <header class="chat-pc-header">
    <div class="chat-pc-header__left">
      <div class="agent">
        <div class="agent__avatar">
          <img v-if="isAppIcon(avatar)" :src="avatar" alt="" />
          <svg v-else width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <mask id="agent-eyes-header" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
              <rect width="24" height="24" fill="#fff" />
              <circle cx="9.25" cy="11" r="1.15" fill="#000" />
              <circle cx="14.75" cy="11" r="1.15" fill="#000" />
            </mask>
            <g fill="currentColor" mask="url(#agent-eyes-header)">
              <circle cx="12" cy="2.5" r="0.9" />
              <rect x="11.5" y="3.2" width="1" height="1.8" rx="0.3" />
              <rect x="4" y="5" width="16" height="12" rx="3" />
              <path d="M2 22 Q12 15 22 22 H2 Z" />
            </g>
          </svg>
        </div>
        <div class="agent__meta">
          <div class="agent__name">{{ name }}</div>
          <div class="agent__status">
            <span class="dot" />
            {{ $t('chat.online') }}
          </div>
        </div>
      </div>
    </div>
    <div class="chat-pc-header__right">
      <button
        v-if="showNewChat"
        class="icon-btn"
        @click="$emit('new-conversation')"
        :aria-label="$t('chat.newChat')"
      >
        <LucideIcon name="square-pen" :size="16" />
      </button>
      <button
        v-if="showSettings"
        class="icon-btn"
        @click="$emit('open-settings')"
        :aria-label="$t('chat.settings')"
      >
        <LucideIcon name="more-horizontal" :size="16" />
      </button>
    </div>
  </header>
</template>

<script setup lang="ts">
import { LucideIcon } from '@/components/lucide-icon'
import { isAppIcon } from '@/utils/common'

withDefaults(
  defineProps<{
    name?: string
    avatar?: string
    showNewChat?: boolean
    showSettings?: boolean
  }>(),
  {
    name: '',
    showNewChat: true,
    showSettings: true,
  },
)

defineEmits<{
  (e: 'new-conversation'): void
  (e: 'open-settings'): void
}>()
</script>

<style lang="scss" scoped>
.chat-pc-header {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  background: var(--main-bg, #ffffff);
  border-bottom: 1px solid var(--border-base, #e5e7eb);
  flex-shrink: 0;
}

.chat-pc-header__left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.agent {
  display: flex;
  align-items: center;
  gap: 10px;
}

.agent__avatar {
  width: 28px;
  height: 28px;
  border-radius: var(--radius-sm, 6px);
  background: var(--el-color-primary, #0f172a);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
}

.agent__name {
  font-size: 14px;
  font-weight: 600;
  color: var(--el-text-color-primary);
  line-height: 1.2;
}

.agent__status {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
  margin-top: 2px;

  .dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #34d399;
  }
}

.icon-btn {
  background: transparent;
  border: 0;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-sm, 6px);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--el-text-color-secondary);
  cursor: pointer;

  &:hover {
    background: var(--el-fill-color-light);
    color: var(--el-text-color-primary);
  }
}

.chat-pc-header__right {
  display: flex;
  gap: 4px;
}
</style>
