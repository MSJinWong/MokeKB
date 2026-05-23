import { Result } from '@/request/Result'
import type { Ref } from 'vue'
import type { WorkspaceItem } from '@/api/type/workspace'

/**
 * 获取工作空间列表（静态存根：后端工作空间端点已移除，保留 default workspace 语义）
 */
const getSystemWorkspaceList: (loading?: Ref<boolean>) => Promise<Result<WorkspaceItem[]>> = (
  _loading?,
) => {
  return Promise.resolve(Result.success([{ id: 'default', name: 'Default' }]) as Result<WorkspaceItem[]>)
}

export default {
  getSystemWorkspaceList,
}
