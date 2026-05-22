<template>
  <div class="application-page" v-loading="loading">
    <header class="application-page__toolbar">
      <el-input
        v-model="searchKeyword"
        :placeholder="$t('views.application.searchPlaceholder')"
        class="application-page__search"
        clearable
        :prefix-icon="Search"
      />
      <el-select
        v-model="groupBy"
        size="default"
        class="application-page__groupby"
      >
        <el-option value="folder" :label="$t('views.application.groupBy.folder')" />
        <el-option value="status" :label="$t('views.application.groupBy.status')" />
        <el-option value="none" :label="$t('views.application.groupBy.none')" />
      </el-select>
      <el-dropdown trigger="click" @command="onCreateCommand">
        <el-button type="primary">
          <LucideIcon name="plus" :size="14" />
          <span class="ml-4">{{ $t('common.create') }}</span>
          <el-icon class="ml-4"><ArrowDown /></el-icon>
        </el-button>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item command="simple">
              <LucideIcon name="bot" :size="14" />
              <span class="ml-8">{{ $t('views.application.simple') }}</span>
            </el-dropdown-item>
            <el-dropdown-item command="advanced">
              <LucideIcon name="git-branch" :size="14" />
              <span class="ml-8">{{ $t('views.application.advanced') }}</span>
            </el-dropdown-item>
            <el-dropdown-item command="template" divided>
              <LucideIcon name="library" :size="14" />
              <span class="ml-8">{{ $t('workflow.setting.templateCenter') }}</span>
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </header>

    <ApplicationGroupedList
      :applications="filteredApplications"
      :folders="folders"
      :group-by="groupBy"
      :build-to="buildToForItem"
      @create="onCreate"
      @action="onAction"
    />

    <CreateApplicationDialog ref="CreateApplicationDialogRef" @refresh="loadAll" />
    <TemplateStoreDialog ref="TemplateStoreDialogRef" @refresh="loadAll" />
    <MoveToDialog
      ref="MoveToDialogRef"
      :source="SourceTypeEnum.APPLICATION"
      @refresh="loadAll"
    />
    <CopyApplicationDialog ref="CopyApplicationDialogRef" @refresh="loadAll" />
    <ResourceAuthorizationDrawer
      ref="ResourceAuthorizationDrawerRef"
      :type="SourceTypeEnum.APPLICATION"
    />
    <ResourceTriggerDrawer
      ref="ResourceTriggerDrawerRef"
      :source="SourceTypeEnum.APPLICATION"
    />
  </div>
</template>

<script lang="ts" setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search, ArrowDown } from '@element-plus/icons-vue'
import ApplicationGroupedList from './component/ApplicationGroupedList.vue'
import CreateApplicationDialog from './component/CreateApplicationDialog.vue'
import CopyApplicationDialog from './component/CopyApplicationDialog.vue'
import TemplateStoreDialog from './template-store/TemplateStoreDialog.vue'
import MoveToDialog from '@/components/folder-tree/MoveToDialog.vue'
import ResourceAuthorizationDrawer from '@/components/resource-authorization-drawer/index.vue'
import ResourceTriggerDrawer from '@/views/trigger/ResourceTriggerDrawer.vue'
import { LucideIcon } from '@/components/lucide-icon'
import ApplicationApi from '@/api/application/application'
import { SourceTypeEnum } from '@/enums/common'
import { hasPermission } from '@/utils/permission'
import { ComplexPermission } from '@/utils/permission/type'
import { EditionConst, PermissionConst, RoleConst } from '@/utils/permission/data'
import { MsgSuccess, MsgConfirm, MsgError } from '@/utils/message'
import { isWorkFlow } from '@/utils/application'
import { t } from '@/locales'
import useStore from '@/stores'

const router = useRouter()

const { folder } = useStore()

const searchKeyword = ref('')
const groupBy = ref<'folder' | 'status' | 'none'>('folder')
const applications = ref<any[]>([])
const folders = ref<any[]>([])
const loading = ref(false)

const CreateApplicationDialogRef = ref()
const TemplateStoreDialogRef = ref()
const MoveToDialogRef = ref()
const CopyApplicationDialogRef = ref()
const ResourceAuthorizationDrawerRef = ref()
const ResourceTriggerDrawerRef = ref<InstanceType<typeof ResourceTriggerDrawer>>()

const filteredApplications = computed(() => {
  const kw = searchKeyword.value.trim().toLowerCase()
  if (!kw) return applications.value
  return applications.value.filter((a: any) =>
    (a.name || '').toLowerCase().includes(kw) ||
    (a.desc || a.description || '').toLowerCase().includes(kw),
  )
})

// 保留 get_route 权限路由逻辑(从旧版 index.vue 完整迁移)
function get_route(item: any): string {
  if (
    hasPermission(
      [
        new ComplexPermission(
          [RoleConst.USER],
          [PermissionConst.APPLICATION.getApplicationWorkspaceResourcePermission(item.id)],
          [],
          'AND',
        ),
        RoleConst.WORKSPACE_MANAGE.getWorkspaceRole,
        PermissionConst.APPLICATION_OVERVIEW_READ.getWorkspacePermissionWorkspaceManageRole,
        PermissionConst.APPLICATION_OVERVIEW_READ.getApplicationWorkspaceResourcePermission(
          item.id,
        ),
      ],
      'OR',
    )
  ) {
    return `/application/workspace/${item.id}/${item.type}/overview`
  } else if (
    hasPermission(
      [
        new ComplexPermission(
          [RoleConst.USER],
          [PermissionConst.APPLICATION.getApplicationWorkspaceResourcePermission(item.id)],
          [],
          'AND',
        ),
        RoleConst.WORKSPACE_MANAGE.getWorkspaceRole,
        PermissionConst.APPLICATION_EDIT.getWorkspacePermissionWorkspaceManageRole,
        PermissionConst.APPLICATION_EDIT.getApplicationWorkspaceResourcePermission(item.id),
      ],
      'OR',
    )
  ) {
    if (item.type == 'WORK_FLOW') {
      return `/application/workspace/${item.id}/workflow`
    } else {
      return `/application/workspace/${item.id}/${item.type}/setting`
    }
  } else if (
    hasPermission(
      [
        new ComplexPermission(
          [RoleConst.USER],
          [PermissionConst.APPLICATION.getApplicationWorkspaceResourcePermission(item.id)],
          [EditionConst.IS_EE, EditionConst.IS_PE],
          'AND',
        ),
        new ComplexPermission(
          [RoleConst.WORKSPACE_MANAGE.getWorkspaceRole],
          [PermissionConst.APPLICATION_ACCESS_READ.getWorkspacePermissionWorkspaceManageRole],
          [EditionConst.IS_EE, EditionConst.IS_PE],
          'OR',
        ),
        new ComplexPermission(
          [],
          [
            PermissionConst.APPLICATION_ACCESS_READ.getApplicationWorkspaceResourcePermission(
              item.id,
            ),
          ],
          [EditionConst.IS_EE, EditionConst.IS_PE],
          'OR',
        ),
      ],
      'OR',
    )
  ) {
    return `/application/workspace/${item.id}/${item.type}/access`
  } else if (
    hasPermission(
      [
        new ComplexPermission(
          [RoleConst.USER],
          [PermissionConst.APPLICATION.getApplicationWorkspaceResourcePermission(item.id)],
          [EditionConst.IS_EE, EditionConst.IS_PE],
          'AND',
        ),
        new ComplexPermission(
          [RoleConst.WORKSPACE_MANAGE.getWorkspaceRole],
          [PermissionConst.APPLICATION_CHAT_USER_READ.getWorkspacePermissionWorkspaceManageRole],
          [EditionConst.IS_EE, EditionConst.IS_PE],
          'OR',
        ),
        new ComplexPermission(
          [],
          [
            PermissionConst.APPLICATION_CHAT_USER_READ.getApplicationWorkspaceResourcePermission(
              item.id,
            ),
          ],
          [EditionConst.IS_EE, EditionConst.IS_PE],
          'OR',
        ),
      ],
      'OR',
    )
  ) {
    return `/application/workspace/${item.id}/${item.type}/chat-user`
  } else if (
    hasPermission(
      [
        new ComplexPermission(
          [RoleConst.USER],
          [PermissionConst.APPLICATION.getApplicationWorkspaceResourcePermission(item.id)],
          [],
          'AND',
        ),
        PermissionConst.APPLICATION_CHAT_LOG_READ.getWorkspacePermissionWorkspaceManageRole,
        PermissionConst.APPLICATION_CHAT_LOG_READ.getApplicationWorkspaceResourcePermission(
          item.id,
        ),
      ],
      'OR',
    )
  ) {
    return `/application//workspace${item.id}/${item.type}/chat-log`
  } else return `/application/`
}

function buildToForItem(item: any) {
  return get_route(item)
}

async function loadFolders() {
  try {
    const res: any = await folder.asyncGetFolder(
      SourceTypeEnum.APPLICATION,
      {},
      'workspace',
      loading,
    )
    folders.value = res?.data ?? []
  } catch (e) {
    console.warn('[application] folder load failed:', e)
    folders.value = []
  }
}

async function loadApplications() {
  try {
    const res: any = await ApplicationApi.getAllApplication(undefined, loading)
    applications.value = res?.data ?? []
  } catch (e) {
    console.warn('[application] application load failed:', e)
    applications.value = []
  }
}

async function loadAll() {
  await Promise.all([loadFolders(), loadApplications()])
}

function onCreate(folderId?: string) {
  const targetFolder = folderId && folderId !== '__unsorted__' ? folderId : 'default'
  CreateApplicationDialogRef.value?.open(targetFolder, 'SIMPLE')
}

function onCreateCommand(cmd: 'simple' | 'advanced' | 'template') {
  const targetFolder = folder.currentFolder?.id || 'default'
  if (cmd === 'template') {
    TemplateStoreDialogRef.value?.open(targetFolder)
    return
  }
  CreateApplicationDialogRef.value?.open(
    targetFolder,
    cmd === 'advanced' ? 'WORK_FLOW' : 'SIMPLE',
  )
}

function onMove(app: any) {
  MoveToDialogRef.value?.open({ id: app.id, folder_id: app.folder_id })
}

function settingApplication(app: any) {
  if (isWorkFlow(app.type)) {
    router.push({ path: `/application/workspace/${app.id}/workflow` })
  } else {
    router.push({ path: `/application/workspace/${app.id}/${app.type}/setting` })
  }
}

function copyApplication(app: any) {
  ApplicationApi.getApplicationDetail(app.id, loading).then((res: any) => {
    if (res?.data) {
      CopyApplicationDialogRef.value?.open(
        { ...res.data, model_id: res.data.model },
        app.folder_id || 'default',
      )
    }
  })
}

function exportApplication(app: any) {
  ApplicationApi.exportApplication(app.id, app.name, loading).catch((e: any) => {
    if (e?.response && e.response.status !== 403) {
      e.response.data.text().then((res: string) => {
        try {
          MsgError(`${t('views.application.tip.ExportError')}:${JSON.parse(res).message}`)
        } catch {
          MsgError(t('views.application.tip.ExportError'))
        }
      })
    }
  })
}

function deleteApplication(app: any) {
  MsgConfirm(
    `${t('views.application.delete.confirmTitle')}${app.name} ?`,
    app.resource_count > 0
      ? t('views.application.delete.resourceCountMessage', { count: app.resource_count })
      : '',
    {
      confirmButtonText: t('common.confirm'),
      cancelButtonText: t('common.cancel'),
      confirmButtonClass: 'danger',
    },
  )
    .then(() => {
      ApplicationApi.delApplication(app.id, loading).then(() => {
        MsgSuccess(t('common.deleteSuccess'))
        loadAll()
      })
    })
    .catch(() => {})
}

function onAction(kind: string, app: any) {
  switch (kind) {
    case 'setting':
      settingApplication(app)
      break
    case 'auth':
      ResourceAuthorizationDrawerRef.value?.open(app.id)
      break
    case 'trigger':
      ResourceTriggerDrawerRef.value?.open(app)
      break
    case 'move':
      onMove(app)
      break
    case 'copy':
      copyApplication(app)
      break
    case 'export':
      exportApplication(app)
      break
    case 'delete':
      deleteApplication(app)
      break
  }
}

onMounted(loadAll)
</script>

<style lang="scss" scoped>
.application-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 20px;
}
.application-page__toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
}
.application-page__search {
  max-width: 320px;
}
.application-page__groupby {
  width: 160px;
}
</style>
