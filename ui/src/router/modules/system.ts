import { PermissionConst, EditionConst, RoleConst } from '@/utils/permission/data'
import { ComplexPermission } from '@/utils/permission/type'

const systemRouter = {
  path: '/system',
  name: 'system',
  meta: { title: 'views.system.title' },
  component: () => import('@/layout/layout-template/MainLayout.vue'),
  redirect: '/system/user',
  children: [
    {
      path: '/system/user',
      name: 'user',
      meta: {
        icon: 'users',
        title: 'views.userManage.title',
        activeMenu: '/system',
        parentPath: '/system',
        parentName: 'system',
        sameRoute: 'user',
        permission: [RoleConst.ADMIN, PermissionConst.USER_READ],
      },
      component: () => import('@/views/system/user-manage/index.vue'),
    },
    {
      path: '/system/authorization',
      name: 'authorization',
      meta: {
        icon: 'shield-check',
        title: 'views.system.resourceAuthorization.title',
        activeMenu: '/system',
        parentPath: '/system',
        parentName: 'system',
        sameRoute: 'authorization',
        permission: [
          new ComplexPermission(
            [RoleConst.ADMIN, RoleConst.WORKSPACE_MANAGE],
            [
              PermissionConst.APPLICATION_WORKSPACE_USER_RESOURCE_PERMISSION_READ,
              PermissionConst.APPLICATION_WORKSPACE_USER_RESOURCE_PERMISSION_READ
                .getWorkspacePermissionWorkspaceManageRole,
            ],
            [],
            'OR',
          ),
        ],
      },
      redirect: '/system/authorization/application',
      children: [
        {
          path: '/system/authorization/application',
          name: 'authorizationApplication',
          meta: {
            title: 'views.application.title',
            activeMenu: '/system',
            parentPath: '/system',
            parentName: 'system',
            resource: 'APPLICATION',
            sameRoute: 'authorization',
            hideMenu: true,
          },
          component: () => import('@/views/system/resource-authorization/index.vue'),
        },
        {
          path: '/system/authorization/knowledge',
          name: 'authorizationKnowledge',
          meta: {
            title: 'views.knowledge.title',
            activeMenu: '/system',
            parentPath: '/system',
            parentName: 'system',
            resource: 'KNOWLEDGE',
            sameRoute: 'authorization',
            hideMenu: true,
          },
          component: () => import('@/views/system/resource-authorization/index.vue'),
        },
        {
          path: '/system/authorization/tool',
          name: 'authorizationTool',
          meta: {
            title: 'views.tool.title',
            activeMenu: '/system',
            parentPath: '/system',
            parentName: 'system',
            resource: 'TOOL',
            sameRoute: 'authorization',
            hideMenu: true,
          },
          component: () => import('@/views/system/resource-authorization/index.vue'),
        },
        {
          path: '/system/authorization/model',
          name: 'authorizationModel',
          meta: {
            title: 'views.model.title',
            activeMenu: '/system',
            parentPath: '/system',
            parentName: 'system',
            resource: 'MODEL',
            sameRoute: 'authorization',
            hideMenu: true,
          },
          component: () => import('@/views/system/resource-authorization/index.vue'),
        },
      ],
    },
    {
      path: '/system/email',
      name: 'email',
      meta: {
        icon: 'mail',
        title: 'views.system.email.title',
        activeMenu: '/system',
        parentPath: '/system',
        parentName: 'system',
        sameRoute: 'email',
        permission: [
          new ComplexPermission([RoleConst.ADMIN], [PermissionConst.EMAIL_SETTING_READ], [], 'OR'),
        ],
      },
      component: () => import('@/views/system-setting/email/index.vue'),
    },
  ],
}

export default systemRouter
