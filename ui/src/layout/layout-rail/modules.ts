/**
 * Rail 顶级模块定义。
 * - title: i18n key（指向 ui/src/locales/lang/<locale>/layout.ts 的 rail.<key>）
 * - lucide: lucide 图标名
 * - path: 顶级路径，点击 Rail 时跳转的根 path
 * - matchPaths: 主路径前缀集合，用于判断当前 active 模块
 */
export interface RailModule {
  key: string
  titleKey: string
  lucide: string
  path: string
  matchPaths: string[]
}

export const RAIL_MODULES: RailModule[] = [
  {
    key: 'workbench',
    titleKey: 'rail.workbench',
    lucide: 'layout-dashboard',
    path: '/workbench',
    matchPaths: ['/workbench'],
  },
  {
    key: 'agent',
    titleKey: 'rail.agent',
    lucide: 'bot',
    path: '/application',
    matchPaths: ['/application', '/chat-user'],
  },
  {
    key: 'knowledge',
    titleKey: 'rail.knowledge',
    lucide: 'book-open-text',
    path: '/knowledge',
    matchPaths: ['/knowledge', '/document', '/paragraph', '/hit-test', '/problem'],
  },
  {
    key: 'capability',
    titleKey: 'rail.capability',
    lucide: 'puzzle',
    path: '/tool',
    matchPaths: ['/tool', '/trigger'],
  },
  {
    key: 'platform',
    titleKey: 'rail.platform',
    lucide: 'settings-2',
    path: '/model',
    matchPaths: ['/model', '/system'],
  },
]

export function findActiveModuleKey(currentPath: string): string {
  for (const m of RAIL_MODULES) {
    if (m.matchPaths.some((p) => currentPath.startsWith(p))) return m.key
  }
  return RAIL_MODULES[0].key
}
