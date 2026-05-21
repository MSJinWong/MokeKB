import { RoleConst } from '@/utils/permission/data'

const workbenchRouter = {
  path: '/workbench',
  name: 'workbench',
  meta: {
    title: 'rail.workbench',
    menu: true,
    permission: [
      RoleConst.USER.getWorkspaceRole,
      RoleConst.WORKSPACE_MANAGE.getWorkspaceRole,
    ],
    icon: 'workbench',
    group: 'workspace',
    order: 0,
  },
  redirect: '/workbench',
  component: () => import('@/layout/layout-template/SimpleLayout.vue'),
  children: [
    {
      path: '/workbench',
      name: 'workbench-index',
      meta: { title: 'rail.workbench', activeMenu: '/workbench' },
      component: () => import('@/views/workbench/index.vue'),
      hidden: true,
    },
  ],
}

export default workbenchRouter
