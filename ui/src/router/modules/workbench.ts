import { RoleConst } from '@/utils/permission/data'

const workbenchRouter = {
  path: '/workbench',
  name: 'workbench',
  meta: {
    title: 'layout.rail.workbench',
    menu: true,
    permission: [
      RoleConst.USER.getWorkspaceRole,
      RoleConst.WORKSPACE_MANAGE.getWorkspaceRole,
    ],
    icon: 'workbench',
    group: 'workspace',
    order: 0,
  },
  redirect: '/workbench/overview',
  component: () => import('@/layout/layout-template/MainLayout.vue'),
  children: [
    {
      path: 'overview',
      name: 'workbench-overview',
      meta: {
        title: 'layout.workbench.menu.overview',
        active: '/workbench/overview',
        parentPath: '/workbench',
        parentName: 'workbench',
      },
      component: () => import('@/views/workbench/index.vue'),
    },
  ],
}

export default workbenchRouter
