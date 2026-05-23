import {PermissionConst, EditionConst, RoleConst} from '@/utils/permission/data'
import {hasPermission} from '@/utils/permission/index'
import roleWorkspaceApi from '@/api/workspace/role'
import systemWorkspaceApi from '@/api/system/workspace'
import workspaceApi from '@/api/workspace/workspace'
import workspaceChatUserApi from '@/api/workspace/chat-user'
import workspaceUserGroupApi from '@/api/workspace/user-group'
import useStore from "@/stores";

// 系统管理员 API
const systemApiMap = {
  workspace: systemWorkspaceApi,
} as any

// 企业版工作空间管理员 API
const workspaceApiMap = {
  role: roleWorkspaceApi,
  workspace: workspaceApi,
  chatUser: workspaceChatUserApi,
  userGroup: workspaceUserGroupApi,
} as any

/** 动态导入 API 模块的函数
 *  loadPermissionApi('workspace')
 */
const {user} = useStore()
const systemPermissionMap = {
  workspace: [PermissionConst.WORKSPACE_READ, RoleConst.ADMIN],
}
const workspacePermissionMap = {
  workspace: [PermissionConst.WORKSPACE_WORKSPACE_READ, RoleConst.WORKSPACE_MANAGE.getWorkspaceRole],
  role: [PermissionConst.WORKSPACE_ROLE_READ, RoleConst.WORKSPACE_MANAGE.getWorkspaceRole],
  chatUser: [PermissionConst.WORKSPACE_CHAT_USER_READ, RoleConst.WORKSPACE_MANAGE.getWorkspaceRole],
  userGroup: [PermissionConst.WORKSPACE_USER_GROUP_READ, RoleConst.WORKSPACE_MANAGE.getWorkspaceRole],
}

export function loadPermissionApi(type: string) {
  if (hasPermission([EditionConst.IS_EE, EditionConst.IS_PE], 'OR')) {
    user.getHasPermissionWorkspaceManage()
    if (hasPermission(systemPermissionMap[type as keyof typeof systemPermissionMap], 'OR')) {
      // 加载系统管理员 API
      return systemApiMap[type]
    } else if (
      hasPermission(workspacePermissionMap[type as keyof typeof workspacePermissionMap], 'OR')
    ) {
      // 加载企业版工作空间管理员 API
      return workspaceApiMap[type]
    }
  }
}
