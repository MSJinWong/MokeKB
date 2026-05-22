<template>
  <div class="resource-authorization">
    <PageHeader
      :title="$t('views.system.resourceAuthorization.title')"
      :subtitle="activeData.label"
    >
      <template #actions>
        <WorkspaceDropdown
          v-if="hasPermission(EditionConst.IS_EE, 'OR')"
          :data="workspaceList"
          :currentWorkspace="currentWorkspace"
          @changeWorkspace="changeWorkspace"
        />
      </template>
    </PageHeader>

    <el-tabs
      v-model="currentResource"
      class="resource-authorization__tabs"
      @tab-click="onTabClick"
    >
      <el-tab-pane
        v-for="t in resourceTabs"
        :key="t.key"
        :label="t.label"
        :name="t.key"
      />
    </el-tabs>

    <div class="card-unified resource-authorization__card">
      <div class="flex">
        <div class="resource-authorization__left border-r">
          <div class="p-24 pb-0">
            <h4 class="mb-12">{{ $t('views.system.resourceAuthorization.member') }}</h4>
            <el-input
              v-model="filterText"
              :placeholder="$t('common.search')"
              prefix-icon="Search"
              clearable
            />
          </div>
          <div class="list-height-left">
            <el-scrollbar>
              <div class="p-8-16">
                <common-list
                  :data="filterMember"
                  v-loading="loading"
                  @click="clickMemberHandle"
                  :default-active="currentUser"
                >
                  <template #default="{ row }">
                    <div class="flex-between">
                      <div class="flex">
                        <span class="mr-8 ellipsis-1" :title="row.nick_name">{{
                          i18n_name(row.nick_name)
                        }}</span>
                        <el-text
                          class="color-input-placeholder ellipsis-1"
                          :title="row.roles.join('，')"
                          v-if="hasPermission([EditionConst.IS_EE, EditionConst.IS_PE], 'OR')"
                        >({{
                          row.roles.map((item: any) => i18n_name(item))?.join('，')
                        }})</el-text>
                      </div>
                    </div>
                  </template>
                </common-list>
              </div>
            </el-scrollbar>
          </div>
        </div>
        <PermissionTable
          :data="treeData"
          :type="activeData.type"
          ref="PermissionTableRef"
          :getData="getPermissionList"
          @submitPermissions="submitPermissions"
        />
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { onMounted, ref, reactive, watch, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PageHeader } from '@/components/page-header'
import PermissionTable from '@/views/system/resource-authorization/component/PermissionTable.vue'
import { MsgSuccess, MsgConfirm } from '@/utils/message'
import { SourceTypeEnum } from '@/enums/common'
import { t } from '@/locales'
import AuthorizationApi from '@/api/system/resource-authorization'
import { EditionConst } from '@/utils/permission/data'
import { hasPermission } from '@/utils/permission/index'
import type { WorkspaceItem } from '@/api/type/workspace'
import { loadPermissionApi } from '@/utils/dynamics-api/permission-api.ts'

import useStore from '@/stores'
import { i18n_name } from '@/utils/common'

const route = useRoute()
const router = useRouter()

interface ResourceTab { key: string; label: string }
const resourceTabs = computed<ResourceTab[]>(() => [
  { key: 'APPLICATION', label: t('views.application.title') },
  { key: 'KNOWLEDGE', label: t('views.knowledge.title') },
  { key: 'TOOL', label: t('views.tool.title') },
  { key: 'MODEL', label: t('views.model.title') },
])

const currentResource = ref<string>((route.meta.resource as string) || 'APPLICATION')

watch(() => route.meta.resource, (v) => {
  if (typeof v === 'string') currentResource.value = v
})

const routeMap: Record<string, string> = {
  APPLICATION: '/system/authorization/application',
  KNOWLEDGE: '/system/authorization/knowledge',
  TOOL: '/system/authorization/tool',
  MODEL: '/system/authorization/model',
}

function onTabClick(tab: any) {
  const path = routeMap[tab.props.name]
  if (path && path !== route.path) router.push(path)
}

const { user } = useStore()
const loading = ref(false)
const rLoading = ref(false)
const memberList = ref<any[]>([]) // 全部成员
const filterMember = ref<any[]>([]) // 搜索过滤后列表
const currentUser = ref<string>('')
const currentType = ref<string>('')
const filterText = ref('')
const permissionData = ref<any[]>([])

const settingTags = reactive([
  {
    label: t('views.knowledge.title'),
    type: SourceTypeEnum.KNOWLEDGE,
  },
  {
    label: t('views.application.title'),
    type: SourceTypeEnum.APPLICATION,
  },
  {
    label: t('views.tool.title'),
    type: SourceTypeEnum.TOOL,
  },
  {
    label: t('views.model.title'),
    type: SourceTypeEnum.MODEL,
  },
])
// 当前激活的数据类型（应用/知识库/模型/工具）
const activeData = computed(() => {
  const lastIndex = route.path.lastIndexOf('/')
  const currentPathType = route.path.substring(lastIndex + 1).toUpperCase()
  return settingTags.filter((item) => {
    return item.type === currentPathType
  })[0]
})

watch(filterText, (val: any) => {
  if (val) {
    filterMember.value = memberList.value.filter((v: any) =>
      v.nick_name.toLowerCase().includes(val.toLowerCase()),
    )
  } else {
    filterMember.value = memberList.value
  }
})

function submitPermissions(obj: any) {
  const workspaceId = currentWorkspaceId.value || user.getWorkspaceId() || 'default'
  AuthorizationApi.putResourceAuthorization(
    workspaceId,
    currentUser.value,
    (route.meta?.resource as string) || 'APPLICATION',
    obj,
    rLoading,
  ).then(() => {
    MsgSuccess(t('common.submitSuccess'))
    getPermissionList()
  })
}

const PermissionTableRef = ref()

const getPermissionList = () => {
  const workspaceId = currentWorkspaceId.value || user.getWorkspaceId() || 'default'
  const params: any = {}
  AuthorizationApi.getResourceAuthorization(
    workspaceId,
    currentUser.value,
    (route.meta?.resource as string) || 'APPLICATION',
    params,
    rLoading,
  ).then((res) => {
    const resourceType = (route.meta?.resource as string) || 'APPLICATION'

    if (resourceType === 'MODEL') {
      permissionData.value = res.data || []
    } else {
      permissionData.value =
        res.data.map((item: any) => {
          if (!item.folder_id && item.permission === 'NOT_AUTH') {
            return { ...item, permission: 'VIEW' }
          }
          return item
        }) || []
    }
  })
}

const toTree = (nodeList: any, pField: any) => {
  if (!nodeList || nodeList.length === 0) return []

  const list = JSON.parse(JSON.stringify(nodeList))

  if (!pField) {
    pField = 'parentId'
  }
  const nodeMap = Object.fromEntries(list.map((item: any) => [item.id, item]))

  for (let index = 0; index < nodeList.length; index++) {
    const element = list[index]
    if (!element.children) {
      element.children = []
    }
    if (element[pField]) {
      const pNode = nodeMap[element[pField]]
      if (pNode) {
        if (!pNode.children) {
          pNode.children = []
        }
        pNode.children.push(element)
      }
    }
  }
  return list.filter((item: any) => !item[pField])
}

const treeData = computed(() => {
  const resourceType = (route.meta?.resource as string) || 'APPLICATION'
  if (resourceType === 'MODEL') {
    return permissionData.value
  }
  return toTree(permissionData.value, 'folder_id')
})

function clickMemberHandle(item: any) {
  currentUser.value = item.id
  currentType.value = item.type
  getPermissionList()
}

function getMember(id?: string) {
  const workspaceId = currentWorkspaceId.value || user.getWorkspaceId() || 'default'
  AuthorizationApi.getUserMember(workspaceId, loading).then((res) => {
    memberList.value = res.data
    filterMember.value = res.data
    if (memberList.value.length > 0) {
      const member = (id && memberList.value.find((p: any) => p.user_id === id)) || null
      currentUser.value = member ? member.id : memberList.value?.[0]?.id
      currentType.value = member ? member.type : memberList.value?.[0]?.type
      getPermissionList()
    } else {
      permissionData.value = []
    }
  })
}

const workspaceList = ref<WorkspaceItem[]>([])
const currentWorkspaceId = ref<string | undefined>('')
const currentWorkspace = computed(() => {
  return workspaceList.value.find((w) => w.id == currentWorkspaceId.value)
})
async function getWorkspaceList() {
  const res = await loadPermissionApi('workspace').getSystemWorkspaceList(loading)
  workspaceList.value = res.data
  currentWorkspaceId.value = (user.getWorkspaceId() as string) || 'default'
}

function changeWorkspace(item: WorkspaceItem) {
  currentWorkspaceId.value = item.id
  getMember()
}

onMounted(() => {
  if (user.isEE()) {
    getWorkspaceList()
  }
  getMember()
})
</script>

<style lang="scss" scoped>
.resource-authorization {
  padding: 0 24px 24px;
}
.resource-authorization__tabs {
  margin-bottom: 12px;
}
.resource-authorization__card {
  overflow: hidden;
  height: calc(100vh - 200px);
}
.resource-authorization__left {
  width: 280px;
  flex-shrink: 0;
}
.list-height-left {
  height: calc(100% - 100px);
}
</style>
