<template>
  <div class="user-manage">
    <PageHeader
      :title="$t('views.userManage.title')"
      :subtitle="`${$t('views.userManage.title')} · ${paginationConfig.total}`"
    >
      <template #actions>
        <el-button
          v-if="user.isPE() || user.isEE()"
          :disabled="multipleSelection.length === 0"
          @click="setUserRoles"
          v-hasPermission="[RoleConst.ADMIN, PermissionConst.USER_EDIT]"
        >
          {{ $t('views.userManage.settingRole') }}
        </el-button>
        <el-button
          :disabled="multipleSelection.length === 0"
          @click="handleBatchDelete"
          v-hasPermission="[RoleConst.ADMIN, PermissionConst.USER_DELETE]"
        >
          {{ $t('common.delete') }}
        </el-button>
        <el-button
          type="primary"
          @click="createUser"
          v-hasPermission="[RoleConst.ADMIN, PermissionConst.USER_CREATE]"
        >
          {{ $t('views.userManage.createUser') }}
        </el-button>
      </template>
    </PageHeader>

    <div class="card-unified user-manage__card">
      <div class="toolbar">
        <div class="toolbar__left"></div>
        <div class="toolbar__right complex-search">
          <el-select
            class="complex-search__left"
            v-model="search_type"
            style="width: 120px"
            @change="search_type_change"
          >
            <el-option :label="$t('views.login.loginForm.username.label')" value="username" />
            <el-option :label="$t('views.userManage.userForm.nick_name.label')" value="nick_name" />
            <el-option :label="$t('views.login.loginForm.email.label')" value="email" />
            <el-option :label="$t('common.status.label')" value="is_active" />
            <el-option
              v-if="user.isEE() || user.isPE()"
              :label="$t('views.userManage.source.label')"
              value="source"
            />
          </el-select>
          <el-input
            v-if="search_type === 'username'"
            v-model="search_form.username"
            @change="getList"
            style="width: 220px"
            clearable
            :placeholder="$t('common.inputPlaceholder')"
          />
          <el-input
            v-else-if="search_type === 'nick_name'"
            v-model="search_form.nick_name"
            @change="getList"
            style="width: 220px"
            clearable
            :placeholder="$t('common.inputPlaceholder')"
          />
          <el-input
            v-else-if="search_type === 'email'"
            v-model="search_form.email"
            @change="getList"
            style="width: 220px"
            clearable
            :placeholder="$t('common.inputPlaceholder')"
          />
          <el-select
            v-else-if="search_type === 'is_active'"
            v-model="search_form.is_active"
            @change="getList"
            clearable
            style="width: 220px"
          >
            <el-option :label="$t('common.status.enabled')" :value="true" />
            <el-option :label="$t('common.status.disabled')" :value="false" />
          </el-select>
          <el-select
            v-else-if="search_type === 'source'"
            v-model="search_form.source"
            @change="getList"
            style="width: 220px"
            clearable
            :placeholder="$t('common.inputPlaceholder')"
          >
            <el-option :label="$t('views.userManage.source.local')" value="LOCAL" />
            <el-option label="CAS" value="CAS" />
            <el-option label="LDAP" value="LDAP" />
            <el-option label="OIDC" value="OIDC" />
            <el-option label="OAuth2" value="OAuth2" />
            <el-option :label="$t('views.userManage.source.wecom')" value="wecom" />
            <el-option :label="$t('views.userManage.source.lark')" value="lark" />
            <el-option :label="$t('views.userManage.source.dingtalk')" value="dingtalk" />
          </el-select>
        </div>
      </div>

      <app-table
        :data="userTableData"
        :pagination-config="paginationConfig"
        @sizeChange="handleSizeChange"
        @changePage="getList"
        v-loading="loading"
        @selection-change="handleSelectionChange"
        :maxTableHeight="280"
      >
        <el-table-column type="selection" width="55" />
        <el-table-column
          prop="nick_name"
          :label="$t('views.userManage.userForm.nick_name.label')"
          min-width="200"
          show-overflow-tooltip
        >
          <template #default="{ row }">
            <div class="flex align-center">
              <AgentAvatar :name="row.nick_name" :size="24" class="mr-8" />
              <span>{{ row.nick_name }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column
          prop="username"
          min-width="180"
          show-overflow-tooltip
          :label="$t('views.login.loginForm.username.label')"
        />
        <el-table-column width="120" prop="is_active" :label="$t('common.status.label')">
          <template #default="{ row }">
            <StatusDot :status="row.is_active ? 'enabled' : 'disabled'" />
          </template>
        </el-table-column>
        <el-table-column
          prop="email"
          :label="$t('views.login.loginForm.email.label')"
          show-overflow-tooltip
          min-width="200"
        >
          <template #default="{ row }">
            {{ row.email || '-' }}
          </template>
        </el-table-column>
        <el-table-column
          prop="phone"
          width="120"
          :label="$t('views.userManage.userForm.phone.label')"
        >
          <template #default="{ row }">
            {{ row.phone || '-' }}
          </template>
        </el-table-column>
        <el-table-column
          prop="role_name"
          :label="$t('views.role.member.role')"
          width="220"
          v-if="user.isEE() || user.isPE()"
        >
          <template #default="{ row }">
            <el-popover :width="500" :persistent="false">
              <template #reference>
                <TagGroup class="cursor" :tags="row.role_name" tooltipDisabled />
              </template>
              <template #default>
                <el-table
                  :data="row.role_workspace"
                  :max-height="300"
                  :tooltip-options="{ popperClass: 'max-w-350' }"
                >
                  <el-table-column
                    prop="role"
                    :label="$t('views.role.member.role')"
                    width="200"
                    show-overflow-tooltip
                  />
                  <el-table-column
                    prop="workspace"
                    :label="$t('views.workspace.title')"
                    show-overflow-tooltip
                  />
                </el-table>
              </template>
            </el-popover>
          </template>
        </el-table-column>
        <el-table-column prop="source" width="120" :label="$t('views.userManage.source.label')">
          <template #default="{ row }">
            {{ formatSource(row.source) }}
          </template>
        </el-table-column>
        <el-table-column :label="$t('common.createTime')" width="180">
          <template #default="{ row }">
            {{ datetimeFormat(row.create_time) }}
          </template>
        </el-table-column>
        <el-table-column :label="$t('common.operation')" width="160" align="left" fixed="right">
          <template #default="{ row }">
            <span @click.stop>
              <el-switch
                :disabled="row.role === 'ADMIN' || row.id === user.userInfo?.id"
                size="small"
                v-model="row.is_active"
                :before-change="() => changeState(row)"
                v-if="hasPermission([RoleConst.ADMIN, PermissionConst.USER_EDIT], 'OR')"
              />
            </span>
            <el-tooltip
              effect="dark"
              :content="$t('common.edit')"
              placement="top"
              v-if="hasPermission([RoleConst.ADMIN, PermissionConst.USER_EDIT], 'OR')"
            >
              <el-button
                type="primary"
                text
                @click.stop="editUser(row)"
                :title="$t('common.edit')"
              >
                <LucideIcon name="pencil" :size="16" />
              </el-button>
            </el-tooltip>
            <el-tooltip
              effect="dark"
              :content="$t('views.userManage.setting.updatePwd')"
              placement="top"
              v-if="hasPermission([RoleConst.ADMIN, PermissionConst.USER_EDIT], 'OR')"
            >
              <el-button
                type="primary"
                text
                @click.stop="editPwdUser(row)"
                :title="$t('views.userManage.setting.updatePwd')"
              >
                <LucideIcon name="key" :size="16" />
              </el-button>
            </el-tooltip>
            <el-tooltip
              effect="dark"
              :content="$t('common.delete')"
              placement="top"
              v-if="hasPermission([RoleConst.ADMIN, PermissionConst.USER_DELETE], 'OR')"
            >
              <el-button
                :disabled="row.role === 'ADMIN' || row.id === user.userInfo?.id"
                type="primary"
                text
                @click.stop="deleteUserManage(row)"
                :title="$t('common.delete')"
              >
                <LucideIcon name="trash-2" :size="16" />
              </el-button>
            </el-tooltip>
          </template>
        </el-table-column>
      </app-table>
    </div>

    <UserDrawer :title="title" ref="UserDrawerRef" @refresh="refresh" />
    <UserPwdDialog ref="UserPwdDialogRef" @refresh="refresh" />
    <SetUserRoleDialog ref="setUserRoleRef" @refresh="refresh" />
  </div>
</template>

<script lang="ts" setup>
import { onMounted, ref, reactive } from 'vue'
import UserDrawer from './component/UserDrawer.vue'
import UserPwdDialog from './component/UserPwdDialog.vue'
import SetUserRoleDialog from './component/SetUserRoleDialog.vue'
import userManageApi from '@/api/system/user-manage'
import { datetimeFormat } from '@/utils/time'
import { MsgSuccess, MsgConfirm } from '@/utils/message'
import { t } from '@/locales'
import useStore from '@/stores'
import { PermissionConst, RoleConst } from '@/utils/permission/data'
import { hasPermission } from '@/utils/permission/index'
import { i18n_name } from '@/utils/common'
import { PageHeader } from '@/components/page-header'
import { AgentAvatar } from '@/components/agent-avatar'
import { StatusDot } from '@/components/status-dot'
import { LucideIcon } from '@/components/lucide-icon'

const { user, common } = useStore()
const search_type = ref('username')
const search_form = ref<{
  username: string
  nick_name?: string
  email?: string
  is_active?: boolean | null
  source?: string | null
}>({
  username: '',
  nick_name: '',
  email: '',
  is_active: null,
  source: '',
})

const UserDrawerRef = ref()
const UserPwdDialogRef = ref()
const loading = ref(false)

const paginationConfig = reactive({
  current_page: 1,
  page_size: 20,
  total: 0,
})
const userTableData = ref<any[]>([])

const search_type_change = () => {
  search_form.value = { username: '', nick_name: '', email: '', is_active: null }
}

function handleSizeChange() {
  paginationConfig.current_page = 1
  getList()
}

function getList() {
  const params: any = {}
  const searchValue = search_form.value[search_type.value as keyof typeof search_form.value]
  if (searchValue !== undefined && searchValue !== null && searchValue !== '') {
    params[search_type.value] = searchValue
  }
  return userManageApi.getUserManage(paginationConfig, params, loading).then((res) => {
    userTableData.value = res.data.records.map((item: any) => ({
      ...item,
      nick_name: i18n_name(item.nick_name),
      role_workspace: Object.entries(item.role_workspace ?? {}).map(([role, workspaces]) => ({
        role: i18n_name(role),
        workspace:
          (workspaces as string[])?.[0] === 'None'
            ? '-'
            : (workspaces as string[])?.map((ws) => i18n_name(ws)).join(', '),
      })),
    }))
    paginationConfig.total = res.data.total
  })
}

async function changeState(row: any) {
  const obj = {
    is_active: !row.is_active,
  }
  const str = obj.is_active ? t('common.status.enableSuccess') : t('common.status.disableSuccess')
  await userManageApi
    .putUserManage(row.id, obj, loading)
    .then((res) => {
      getList()
      MsgSuccess(str)
      return true
    })
    .catch(() => {
      return false
    })
}

const title = ref('')

function editUser(row: any) {
  title.value = t('views.userManage.editUser')
  UserDrawerRef.value.open(row)
}

function createUser() {
  title.value = t('views.userManage.createUser')
  UserDrawerRef.value.open()
}

function deleteUserManage(row: any) {
  MsgConfirm(
    `${t('views.userManage.delete.confirmTitle')}${row.nick_name} ?`,
    t('views.userManage.delete.confirmMessage'),
    {
      confirmButtonText: t('common.confirm'),
      confirmButtonClass: 'danger',
    },
  )
    .then(() => {
      loading.value = true
      userManageApi.delUserManage(row.id, loading).then(() => {
        MsgSuccess(t('common.deleteSuccess'))
        getList()
      })
    })
    .catch(() => {})
}

function editPwdUser(row: any) {
  UserPwdDialogRef.value.open(row)
}

function refresh() {
  getList()
}

const multipleSelection = ref<any[]>([])

function handleSelectionChange(val: any[]) {
  multipleSelection.value = val
}

function handleBatchDelete() {
  MsgConfirm(t('views.chatUser.batchDeleteUser', { count: multipleSelection.value.length }), '', {
    confirmButtonText: t('common.confirm'),
    confirmButtonClass: 'danger',
  })
    .then(() => {
      userManageApi
        .batchDelete(
          multipleSelection.value.map((item) => item.id),
          loading,
        )
        .then(async () => {
          MsgSuccess(t('common.deleteSuccess'))
          await getList()
        })
    })
    .catch(() => {})
}

const setUserRoleRef = ref<InstanceType<typeof SetUserRoleDialog>>()

function setUserRoles() {
  setUserRoleRef.value?.open(multipleSelection.value.map((item) => item.id))
}

function formatSource(source: string): string {
  switch (source) {
    case 'LOCAL': return t('views.userManage.source.local')
    case 'wecom': return t('views.userManage.source.wecom')
    case 'lark': return t('views.userManage.source.lark')
    case 'dingtalk': return t('views.userManage.source.dingtalk')
    case 'OAUTH2':
    case 'OAuth2': return 'OAuth2'
    default: return source
  }
}

onMounted(() => {
  getList()
})
</script>

<style lang="scss" scoped>
.user-manage {
  padding: 0 24px 24px;
}
.user-manage__card {
  overflow: hidden;
}
</style>
