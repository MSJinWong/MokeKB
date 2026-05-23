import { PermissionConst, RoleConst } from '@/utils/permission/data'

const applicationRouter = {
  path: '/application',
  name: 'application',
  meta: {
    title: 'layout.rail.agent',
    menu: true,
    permission: [
      RoleConst.USER.getWorkspaceRole,
      RoleConst.WORKSPACE_MANAGE.getWorkspaceRole,
      PermissionConst.APPLICATION_READ.getWorkspacePermissionWorkspaceManageRole,
      PermissionConst.APPLICATION_READ.getWorkspacePermission,
    ],
    icon: 'bot',
    group: 'workspace',
    order: 1,
  },
  redirect: '/application/list',
  component: () => import('@/layout/layout-template/MainLayout.vue'),
  children: [
    {
      path: '/application/list',
      name: 'application-list',
      meta: {
        title: 'layout.agent.menu.applicationList',
        active: '/application/list',
        activeMenu: '/application/list',
        parentPath: '/application',
        parentName: 'application',
        sameRoute: 'application',
      },
      component: () => import('@/views/application/index.vue'),
    },
  ],
}

export default applicationRouter
