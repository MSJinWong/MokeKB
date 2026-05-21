/**
 * 工作台聚合 API。
 * 复用已有的 application / knowledge / tool 列表 API，不新增后端端点。
 *
 * 现有方法签名（已确认）：
 *   getAllApplication(param?, loading?) → Result<any[]>          — application/application.ts
 *   getKnowledgeList(param?, loading?)  → Result<any>            — knowledge/knowledge.ts
 *   getToolList(data?, loading?)        → Result<{tools, folders}> — tool/tool.ts
 */

export interface WorkbenchStats {
  agentCount: number
  conversationCount: number
  libraryCount: number
  toolCount: number
}

export interface RecentAgent {
  id: string
  name: string
  description?: string
  conversation24h: number
  icon?: string
}

export async function loadWorkbenchStats(): Promise<WorkbenchStats> {
  // TODO（占位实现）：调用项目内现有 API 聚合统计。
  // 当用户提供具体 API 调用细节或当我们到 P4.T7 启用时再填充。
  // 现在返回 0 占位，确保类型契约就绪。
  return {
    agentCount: 0,
    conversationCount: 0,
    libraryCount: 0,
    toolCount: 0,
  }
}

export async function loadRecentAgents(): Promise<RecentAgent[]> {
  // TODO（占位实现）：同上
  return []
}
