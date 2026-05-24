<template>
  <el-card shadow="hover" class="card-box" :class="{ 'is-disabled': disabled }">
    <div class="card-header">
      <slot name="header">
        <div class="title flex align-center">
          <div class="mr-12 flex align-center" v-if="showIcon">
            <slot name="icon">
              <el-avatar shape="square" :size="32" class="avatar-blue">
                <img src="@/assets/knowledge/icon_document.svg" style="width: 58%" alt="" />
              </el-avatar>
            </slot>
          </div>
          <div style="width: 90%" class="mt-4">
            <slot name="title">
              <span class="ellipsis-1" :title="title" style="width: 80%">
                {{ title }}
              </span>
            </slot>
            <slot name="subTitle"> </slot>
          </div>

          <div class="status-tag">
            <!-- hoverShow 保留为 slot 参数语义：consumer 可在 :hover 时显示某图标。CSS 由 consumer 配 .card-box:hover .xxx 实现 -->
            <slot name="tag" :hoverShow="false"> <!-- 放标签 --> </slot>
          </div>
        </div>
      </slot>
    </div>
    <div class="description break-all mt-12">
      <slot>
        <div class="content color-secondary">
          {{ description }}
        </div>
      </slot>
    </div>

    <div class="card-footer flex-between" v-if="$slots.footer || $slots.mouseEnter">
      <div style="flex: 1">
        <slot name="footer"></slot>
      </div>
      <div class="card-mouse-enter">
        <slot name="mouseEnter" v-if="$slots.mouseEnter" />
      </div>
    </div>
  </el-card>
</template>
<script setup lang="ts">
import { t } from '@/locales'
defineOptions({ name: 'CardBox' })
withDefaults(
  defineProps<{
    /**
     * 标题
     */
    title?: string
    /**
     * 描述
     */
    description?: string
    /**
     * 是否展示icon
     */
    showIcon?: boolean
    disabled?: boolean
  }>(),
  { title: t('common.title'), description: '', showIcon: true, border: true, disabled: false },
)
</script>
<style lang="scss" scoped>
.card-box {
  font-size: 14px;
  position: relative;
  min-height: var(--card-min-height);
  min-width: var(--card-min-width);
  line-height: 20px !important;
  .card-header {
    margin-top: -5px;
  }
  .description {
    line-height: 22px;
    font-weight: 400;
    min-height: 70px;
    .content {
      display: -webkit-box;
      height: var(--app-card-box-description-height, 40px);
      -webkit-box-orient: vertical;
      -webkit-line-clamp: 2;
      overflow: hidden;
    }
  }

  .card-footer {
    position: absolute;
    bottom: 8px;
    left: 0;
    min-height: 30px;
    font-weight: 400;
    padding: 0 16px;
    width: 100%;
    box-sizing: border-box;
  }
  .status-tag {
    position: absolute;
    right: 16px;
    top: 14px;
  }
  // hover 显示 mouseEnter slot 内容（dropdown 等"更多操作"按钮）
  // 用纯 CSS 实现，避免 JS mouseenter/mouseleave 与 v-if mount/unmount 之间的 hit-test 反馈循环
  .card-mouse-enter {
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.15s ease;
  }
  &:hover .card-mouse-enter,
  .card-mouse-enter:focus-within {
    opacity: 1;
    pointer-events: auto;
  }
  &.is-disabled .card-mouse-enter {
    opacity: 0 !important;
    pointer-events: none !important;
  }
}
</style>
