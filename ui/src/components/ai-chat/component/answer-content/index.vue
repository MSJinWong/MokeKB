<template>
  <div class="ai-answer item-content lighter">
    <div v-for="(answer_text, index) in answer_text_list" :key="index" class="ai-answer__row">
      <!-- AI avatar -->
      <div class="ai-answer__avatar" v-if="showAvatar">
        <img v-if="application.avatar" :src="application.avatar" height="28px" width="28px" />
        <LogoIcon v-else height="28px" width="28px" />
      </div>
      <!-- AI message body (flat, no card bubble) -->
      <div
        class="ai-answer__body"
        @mouseup="openControl"
        :style="{
          'padding-right': showUserAvatar ? 'var(--padding-left)' : '0',
        }"
      >
        <MdRenderer
          v-if="
            (chatRecord.write_ed === undefined || chatRecord.write_ed === true) &&
            answer_text.length == 0 &&
            answer_text
              .map((item) => item.content)
              .join('')
              .trim().length == 0
          "
          :source="$t('chat.tip.answerMessage')"
        ></MdRenderer>
        <template v-else-if="answer_text.length > 0">
          <MdRenderer
            v-for="(answer, index) in answer_text"
            :key="index"
            :chat_record_id="answer.chat_record_id"
            :child_node="answer.child_node"
            :runtime_node_id="answer.runtime_node_id"
            :reasoning_content="answer.reasoning_content"
            :disabled="loading || type == 'log'"
            :source="answer.content"
            :send-message="chatMessage"
          ></MdRenderer>
        </template>
        <p v-else-if="chatRecord.is_stop" style="margin: 0.5rem 0">
          {{ $t('chat.tip.stopAnswer') }}
        </p>
        <p v-else style="margin: 0.5rem 0">
          {{ $t('chat.tip.answerLoading') }} <span class="dotting"></span>
        </p>
        <!-- 知识来源 -->
        <KnowledgeSourceComponent
          :data="chatRecord"
          :application="application"
          :type="type"
          :appType="application.type"
          :executionIsRightPanel="props.executionIsRightPanel"
          @open-execution-detail="emit('openExecutionDetail')"
          @openParagraph="emit('openParagraph')"
          @openParagraphDocument="(val: string) => emit('openParagraphDocument', val)"
          v-if="showSource(chatRecord) && index === chatRecord.answer_text_list.length - 1"
        />
      </div>
    </div>

    <!-- Operation buttons row -->
    <div
      class="ai-answer__operations"
      :style="{
        'padding-left': showAvatar ? 'var(--padding-left)' : '0',
        'padding-right': showUserAvatar ? 'var(--padding-left)' : '0',
      }"
      v-if="!selection"
    >
      <OperationButton
        :type="type"
        :application="application"
        :chatRecord="chatRecord"
        @update:chatRecord="(event: any) => emit('update:chatRecord', event)"
        :loading="loading"
        :start-chat="startChat"
        :stop-chat="stopChat"
        :regenerationChart="regenerationChart"
      ></OperationButton>
    </div>
  </div>
</template>
<script setup lang="ts">
import { computed, onMounted } from 'vue'
import KnowledgeSourceComponent from '@/components/ai-chat/component/knowledge-source-component/index.vue'
import MdRenderer from '@/components/markdown/MdRenderer.vue'
import OperationButton from '@/components/ai-chat/component/operation-button/index.vue'
import { type chatType } from '@/api/type/application'
import bus from '@/bus'

const props = defineProps<{
  chatRecord: chatType
  application: any
  loading: boolean
  sendMessage: (question: string, other_params_data?: any, chat?: chatType) => Promise<boolean>
  chatManagement: any
  type: 'log' | 'ai-chat' | 'debug-ai-chat' | 'share'
  executionIsRightPanel?: boolean
  selection?: boolean
}>()

const emit = defineEmits([
  'update:chatRecord',
  'openExecutionDetail',
  'openParagraph',
  'openParagraphDocument',
])

const showAvatar = computed(() => {
  return props.application.show_avatar == undefined ? true : props.application.show_avatar
})
const showUserAvatar = computed(() => {
  return props.application.show_user_avatar == undefined ? true : props.application.show_user_avatar
})
const chatMessage = (question: string, type: 'old' | 'new', other_params_data?: any) => {
  if (type === 'old') {
    add_answer_text_list(props.chatRecord.answer_text_list)
    props.sendMessage(question, other_params_data, props.chatRecord).then(() => {
      props.chatManagement.open(props.chatRecord.id)
      props.chatManagement.write(props.chatRecord.id)
    })
  } else {
    props.sendMessage(question, other_params_data)
  }
}
const add_answer_text_list = (answer_text_list: Array<any>) => {
  answer_text_list.push([])
}

const openControl = (event: any) => {
  if (props.type !== 'log') {
    bus.emit('open-control', event)
  }
}

const answer_text_list = computed(() => {
  return props.chatRecord.answer_text_list.map((item) => {
    if (typeof item == 'string') {
      return [
        {
          content: item,
          chat_record_id: undefined,
          child_node: undefined,
          runtime_node_id: undefined,
          reasoning_content: undefined,
        },
      ]
    } else if (item instanceof Array) {
      return item
    } else {
      return [item]
    }
  })
})

function showSource(row: any) {
  if (props.type === 'log') {
    return true
  } else if (row.write_ed && 500 !== row.status) {
    return true
  }
  return false
}

const regenerationChart = (chat: chatType) => {
  const container = props.chatRecord?.upload_meta
    ? props.chatRecord.upload_meta
    : props.chatRecord.execution_details?.find((detail) => detail.type === 'start-node')

  props.sendMessage(chat.problem_text, {
    re_chat: true,
    image_list: container?.image_list || [],
    document_list: container?.document_list || [],
    audio_list: container?.audio_list || [],
    video_list: container?.video_list || [],
    other_list: container?.other_list || [],
  })
}
const stopChat = (chat: chatType) => {
  props.chatManagement.stop(chat.id)
}
const startChat = (chat: chatType) => {
  props.chatManagement.write(chat.id)
}

onMounted(() => {
  bus.on('chat:stop', () => {
    stopChat(props.chatRecord)
  })
})
</script>
<style lang="scss" scoped>
// AI answer – flat layout (no card bubble)
.ai-answer {
  padding: 16px 0 4px;

  &__row {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    margin-bottom: 4px;
  }

  &__avatar {
    flex-shrink: 0;
    width: 28px;
    height: 28px;
    border-radius: var(--radius-sm);
    background: var(--app-layout-bg-color, #f5f5f5);
    color: var(--brand-primary);
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

  &__body {
    flex: 1;
    min-width: 0;
    color: var(--app-text-color);
    font-size: var(--font-size-md);
    line-height: 1.7;
  }

  &__operations {
    // indent to align with body when avatar is shown
  }
}
</style>
