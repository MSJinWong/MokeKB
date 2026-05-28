/**
 * 工作台聚合 API。
 * 复用已有的 application / knowledge / tool 列表 API，不新增后端端点。
 */
import applicationApi from '@/api/application/application'
import knowledgeApi from '@/api/knowledge/knowledge'
import toolApi from '@/api/tool/tool'

export interface WorkbenchStats {
  agentCount: number
  libraryCount: number
  toolCount: number
}

export interface RecentAgent {
  id: string
  name: string
  description?: string
  icon?: string
}

function safeArray<T>(value: any, picker?: (v: any) => any): T[] {
  const raw = picker ? picker(value) : value
  return Array.isArray(raw) ? (raw as T[]) : []
}

export async function loadWorkbenchStats(): Promise<WorkbenchStats> {
  const [appsRes, libsRes, toolsRes] = await Promise.allSettled([
    applicationApi.getAllApplication(),
    knowledgeApi.getKnowledgeList(),
    toolApi.getToolList(),
  ])

  const apps =
    appsRes.status === 'fulfilled' ? safeArray<any>(appsRes.value, (r) => r?.data) : []
  const libs =
    libsRes.status === 'fulfilled' ? safeArray<any>(libsRes.value, (r) => r?.data) : []
  const tools =
    toolsRes.status === 'fulfilled'
      ? safeArray<any>(toolsRes.value, (r) => r?.data?.tools)
      : []

  return {
    agentCount: apps.filter((a) => a?.resource_type !== 'folder').length,
    libraryCount: libs.filter((k) => k?.resource_type !== 'folder').length,
    toolCount: tools.filter((t) => t?.resource_type !== 'folder').length,
  }
}

export async function loadRecentAgents(): Promise<RecentAgent[]> {
  try {
    const res = await applicationApi.getAllApplication()
    const list = safeArray<any>(res, (r) => r?.data)
    return list
      .filter((item) => item?.resource_type !== 'folder')
      .slice(0, 6)
      .map((item) => ({
        id: item.id,
        name: item.name,
        description: item.desc || item.description,
        icon: item.icon,
      }))
  } catch {
    return []
  }
}
