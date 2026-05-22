# 平台管理重设计 · 拆分独立导航 + 删孤儿页 + 复用智能体原子

- **日期**：2026-05-22
- **分支**：`feat/frontend-redesign`
- **范围**：`ui/` 前端导航 IA + 4 个活页重做 + 12 孤儿页删除
- **不动**：`apps/` 后端代码、所有 API 路径、`/chat/:accessToken` 与 `/user-login/:accessToken` 嵌入合约、`workspace_id` 字段及其 model/路由/store 引用
- **依赖**：前置 spec `2026-05-21-frontend-redesign-design.md`（整体重设计） 与 `2026-05-22-agent-list-overview-workflow-design.md`（智能体三页）已落地的 atoms：`AgentAvatar`、`StatusDot`、`.card-unified`

---

## 1. 背景

整体重设计第二轮巡检发现"平台管理"模块存在 3 个独立但相关的问题：

1. **入口缺失**：Rail 的"平台"模块 `path: '/model'`，点击只跳到模型管理；`/system/*` 14 个子路由虽然存在，但**没有任何 UI 入口**让用户跳到它们（除非手输 URL）。原因：`830ba1d82 de-MaxKB pass` 重写 Rail 时把"模型"和"系统管理"合并到一个 platform 模块下，却只挂了模型路径。

2. **大量孤儿页面**：审计前端 API prefix 与 `apps/*/urls.py` 实际路由后发现，平台管理 18 个候选页面里有 **12 个完全没有后端实现**：角色管理、操作日志、对话用户/分组/认证、资源管理 × 4、共享资源 × 3、主题设置、平台登录认证。前端 API 调用全部 404。

3. **视觉与智能体页面不一致**：活的页面（用户管理 / 资源授权 / 邮箱设置）仍是 `<h2>` + 嵌套 `<el-card>` + `<el-breadcrumb>` 风，没有接入智能体已落地的 `AgentAvatar` / `StatusDot` / `.card-unified` 原子。

本 spec 一次性解决这三个问题：拆独立 Rail 项、删 12 孤儿、重做 4 个活页。

---

## 2. 设计原则

| # | 原则 | 强化点 |
|---|---|---|
| 1 | **后端零改动** | `workspace_id` 字段、`workspace/<id>/*` 路径、`apps/*/urls.py` 一律不动 |
| 2 | **只优化有后端的页** | UI 不维护对死接口的代码，但保留**字段语义**（`workspace_id` 留作 `'default'`） |
| 3 | **复用智能体原子** | 不抽不必要的新组件；优先用 `AgentAvatar` / `StatusDot` / `.card-unified` |
| 4 | **结构差异 > 颜色差异** | 用 PageHeader + tab 切资源类型这种结构层面变化，而不是简单换色 |
| 5 | **删的资产同时清** | 视图 / API client / i18n / store action 一并清，不留死代码 |
| 6 | **可控低风险** | 改动只在 UI 层，能用 grep 验证；最后一个 phase 才做毁灭性清理 |

---

## 3. 导航 IA 修复

### 3.1 Rail 改造（系统管理独立项）

`ui/src/layout/layout-rail/modules.ts` 加一项：

```ts
{
  key: 'system',
  titleKey: 'layout.rail.system',
  lucide: 'shield-cog',
  path: '/system/user',
  matchPaths: ['/system'],
}
```

"平台"项的 `matchPaths` 收回为 `['/model']`，**不再触碰 `/system`**。

最终 Rail 6 项：

```
工作台 / 智能体 / 知识库 / 能力 / 平台(→模型) / 系统管理(→用户)
```

### 3.2 Side 二级菜单（系统管理下 3 项）

```
系统管理
├── 用户管理      → /system/user
├── 资源授权      → /system/authorization/application（默认 tab）
└── 邮箱设置      → /system/email
```

资源授权目前有 4 条独立路由（application / knowledge / tool / model）复用同一个 `<index.vue>`。Side 只显示 1 项，**进页后用 tab 切资源类型**：
- URL 仍是 4 条独立路由（书签、权限、后退按钮语义不变）
- Tab 点击 = `router.push('/system/authorization/' + resource)`
- 当前 active tab 由 `route.meta.resource` 决定
- 权限不足的 tab 自动隐藏

### 3.3 工作空间字段保留不动（边界约束）

UI 上"工作空间管理"**页面**删除，但**字段和接口保留**：

| 保留 |
|---|
| `workspace_id = CharField(default="default")` 在 `apps/system_manage/models/*` 所有 model 字段不动 |
| 所有 `workspace/<workspace_id>/...` 后端路由路径不动 |
| `user.getWorkspaceId()` 返回 `'default'`，调用方继续传 |
| `/workspace/<id>/user_resource_permission/*` 后端路径（资源授权用）保留 |
| `/workspace/<id>/user_member`、`user_list` 后端路径（资源授权 EE workspace dropdown 用）保留 |
| 顶部 workspace dropdown 显示"默认工作空间"，去掉切换交互（保留显示） |

删除工作空间管理页就等于砍掉了所有改 `workspace_id` 的 UI 入口。

### 3.4 改动文件

```
ui/src/layout/layout-rail/modules.ts                  加 system 项；platform 收 matchPaths
ui/src/router/modules/system.ts                       去 hidden:true；切到 MainLayout；只留 3 个有效 children
ui/src/layout/layout-template/SystemMainLayout.vue    删（被 MainLayout 替代）
ui/src/locales/lang/zh-CN|en-US|zh-Hant/layout.ts     加 rail.system key
```

后端零改动。

---

## 4. 共享原子（精简版）

考虑到活页只剩 2 个重做 + 1 个轻量，抽 4 件套过头，改为**最小集**。

### 4.1 `<PageHeader>` Vue 组件 ✨ 新增

所有平台管理页统一头，取代当前 `<h2>` + `<el-breadcrumb>` + 嵌套 `<el-card>` 起头方式。

```
┌────────────────────────────────────────────────────┐
│ 用户管理                                  [次] [主] │   ← 56px 内容高
│ 平台用户 · 共 128 人                                │   ← 副信息 12px slate-500
└────────────────────────────────────────────────────┘
```

```ts
props: {
  title: string                  // 主标题 18px/600
  subtitle?: string              // 副信息行 12px/400 slate-500
  showBack?: boolean             // 是否带返回按钮（详情页用）
}
slots: {
  actions: 右侧按钮组（主操作 + 次操作，按整体 spec §4.4 分层）
  subtitle: 当默认 subtitle 不够（如要放 StatusDot + 计数组合）
}
```

放 `ui/src/components/page-header/PageHeader.vue`。

### 4.2 `<StatusDot>` 原子扩展 ✨ 修改已有

`ui/src/components/status-dot/StatusDot.vue` 现支持 `published / draft / archived` 三个 status key。扩展两个新 key：

```ts
type StatusKey = 'published' | 'draft' | 'archived' | 'enabled' | 'disabled'

// CSS:
.status-dot--enabled .status-dot__bullet { color: #10b981; }   // emerald-500
.status-dot--disabled .status-dot__bullet { color: #94a3b8; }  // slate-400
```

`statusText` 计算属性增加：
```ts
case 'enabled': return t('common.status.enabled')
case 'disabled': return t('common.status.disabled')
```

### 4.3 `.card-unified` SCSS class — 已存在 ✓

智能体 spec §4.2 已定义并落地。本 spec 所有活页的外层卡片包裹这个 class。

### 4.4 `.toolbar` SCSS 约定（不抽组件）

```scss
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-base);

  &__left, &__right { display: flex; gap: 8px; align-items: center; }
}
```

放在 `ui/src/styles/components.scss`（或 `card-unified` 同一文件）。

### 4.5 不抽的东西

- ~~`<DataTableCard>`~~：只有用户管理 1 处用，直接 `.card-unified` + `.toolbar` + `<app-table>` 内联
- ~~`<SplitPanelLayout>`~~：只有资源授权 1 处用，直接 `.card-unified` + 内部 flex
- ~~`<MetricTile>`~~：操作日志页删了，不再需要
- ~~`<FormCard>`~~：邮箱页 1 处用，轻量打磨不需要新壳

---

## 5. 活页重做

### 5.1 用户管理（/system/user）· 重做

```
┌──────────────────────────────────────────────────────────┐
│ 用户管理                          [批删] [批授角色] [+ 创建] │  PageHeader
│ 平台用户 · 共 128 人                                       │
├──────────────────────────────────────────────────────────┤
│ [按用户名▾] [搜索...]                                       │  .toolbar
├──────────────────────────────────────────────────────────┤
│ ☐ │ [M] M···│ jin │ ● 启用 │ jin@x.com │ ADMIN │ ⋯       │
│ ☐ │ [t] tom │ tom │ ● 停用 │ -        │ USER  │ ⋯       │
└──────────────────────────────────────────────────────────┘
```

改动：
- 套 `<PageHeader>`，actions slot 放 `批删` / `批授角色` / `+ 创建`
- 外层 `<el-card>` 改 `.card-unified`，内部 `.toolbar` + `<app-table>`
- 删除原有 `<h2>` + 外层 `<el-card>` 嵌套
- 昵称列前加 `<AgentAvatar :name="nick_name" :size="24">`
- `is_active` 列：`SuccessFilled` + `app-disabled` icon → `<StatusDot :status="row.is_active ? 'enabled' : 'disabled'">`
- 行操作 icons：`AppIcon app-edit/app-key/app-delete` → `<LucideIcon name="pencil/key/trash-2">`
- `el-divider` 竖线分隔切换 / 操作 icon → 改为按钮 8px gap
- `source` 列 if-else 链：抽本地 `formatSource(source)` 辅助函数，UI 上保持文字
- 现有 `UserDrawer / UserPwdDialog / SetUserRoleDialog` 交互全部不动

API 不动：`/user_manage*`（apps/users/urls.py）。

### 5.2 资源授权（/system/authorization/*）· 重做

```
┌──────────────────────────────────────────────────────────┐
│ 资源授权                                          [WS▾]    │  PageHeader (EE 显示 WS dropdown)
│ 为成员配置访问权限                                          │
├──────────────────────────────────────────────────────────┤
│ [ 应用 ][ 知识库 ][ 工具 ][ 模型 ]                          │  Tabs (router-push)
├──────────────┬───────────────────────────────────────────┤
│ 成员搜索...   │ 应用权限表                                  │
│              │ ┌─────────────────────────────────────┐    │
│ ● Jin (ADMIN)│ │ 应用名 │ 查看 │ 编辑 │ 删除 │ 管理   │    │
│ ○ Tom (USER) │ │ ... ...                            │    │
│ ○ Ada (USER) │ │                                    │    │
│              │ └─────────────────────────────────────┘    │
└──────────────┴───────────────────────────────────────────┘
```

改动：
- 套 `<PageHeader>`，actions slot 放（EE 才显示的）`<WorkspaceDropdown>`
- 删除原有面包屑（`<el-breadcrumb>`）
- 4 个 tab 切资源类型：每个 tab `@click` 触发 `router.push('/system/authorization/' + resource)`；active 由 `route.meta.resource` 决定
- 外层 `<el-card>` → `.card-unified`
- 左侧 `<common-list>` 成员列表交互保留
- 右侧 `<PermissionTable>` 完全不动
- WorkspaceDropdown 行为不动（EE 才出现，下拉切换）

API 不动：`/workspace/<id>/user_resource_permission/*`（apps/system_manage/urls.py）。

### 5.3 邮箱设置（/system/email）· 轻量打磨

```
┌──────────────────────────────────────────┐
│ 邮箱设置                       [保存]      │  PageHeader
│ 配置系统邮件服务                            │
├──────────────────────────────────────────┤
│ SMTP 服务器  [输入框]                       │
│ 端口         [输入框]                       │
│ 发件人邮箱   [输入框]                       │
│ ...                                       │
└──────────────────────────────────────────┘
```

改动：
- 套 `<PageHeader>`，actions slot 放 `保存` + `测试连接`
- 删除原 `<el-breadcrumb>` + 嵌套 `<el-card>` (layout-bg)
- 外层一层 `.card-unified` 即可
- 表单字段、`<el-form>` 校验规则、保存逻辑不动

API 不动：`/email_setting`（apps/system_manage/urls.py）。

### 5.4 模型管理（/model）· 不在本 spec 范围

之前已经做过精简（删 local_provider 等）。本 spec 只确保 IA 改造后 Rail "平台" → `/model` 跳转正常。

---

## 6. 删除清单

### 6.1 视图目录（整目录删）

```
ui/src/views/system/workspace/                  工作空间管理
ui/src/views/system/role/                       角色管理
ui/src/views/system/operate-log/                操作日志
ui/src/views/system-resource-management/        资源管理 × 4
ui/src/views/system-shared/                     共享资源 × 3
ui/src/views/system-chat-user/                  对话用户 / 分组 / 认证
ui/src/views/system-setting/theme/              主题设置（含 LoginPreview.vue）
ui/src/views/system-setting/authentication/     平台登录认证
```

**保留**（重做或轻量）：
```
ui/src/views/system/user-manage/                ✓ 重做
ui/src/views/system/resource-authorization/     ✓ 重做（加 Tab）
ui/src/views/system-setting/email/              ✓ 轻量
```

### 6.2 API client 文件（确认无引用后删）

```
ui/src/api/system/role.ts
ui/src/api/system/operate-log.ts
ui/src/api/system/chat-user.ts
ui/src/api/system/user-group.ts
ui/src/api/system/auth.ts
ui/src/api/system/api-key.ts
ui/src/api/system/platform-source.ts
ui/src/api/system-resource-management/           整目录
ui/src/api/system-shared/                        整目录
ui/src/api/system-settings/theme.ts
ui/src/api/system-settings/auth-setting.ts
ui/src/api/system-settings/platform-source.ts
```

**`ui/src/api/system/workspace.ts` 特殊处理**：
- 后端不存在的方法（`getSystemWorkspaceList` / `CreateOrUpdateWorkspace` / `deleteWorkspace` / `deleteWorkspaceCheck` 等）→ 删
- 顶部 workspace dropdown 仍调用的方法（如 `getWorkspaceListByUser`）→ 改为返回静态 `[{ id: 'default', name: '默认工作空间' }]`，不发请求
- 实施前必须 grep 每个方法的引用，逐个决定 删 / 改静态 / 保留

**`ui/src/api/system/license.ts` 同步处理**：
- 后端 `/license` 路由不存在（实际 license 校验走 `/valid/<type>/<count>`）
- 但 `ui/src/layout/layout-header/avatar/AboutDialog.vue` 仍在调用 `getLicense` 和 `putLicense` 显示/上传 EE 许可信息
- 处理策略：**先保留 license.ts 不删**，作为本 spec 后续单独清理项；当前 spec 接受 AboutDialog 这一处死接口（EE 才走到，CE 用户看不到）

### 6.3 路由清理

`ui/src/router/modules/system.ts`：删除以下子路由项

```
/system/workspace
/system/role
/system/resource-management/*  (4 个)
/system/shared/*                (3 个)
/system/chat/*                  (3 个)
/system/setting/theme
/system/authentication
/operate                        (顶层路由)
```

`systemRouter` 自身：
- 去 `hidden: true`
- 切到 `MainLayout`
- children 只留：`user` + `authorization`（含 4 个子路由）+ `email`
- 删 `SystemMainLayout.vue`（grep 确认无引用）

### 6.4 Store 与工具清理

```
ui/src/stores/modules/theme.ts          删 theme() action；setTheme 改为只接静态默认；或彻底删 store（实施时根据 LogoFull/top-about 引用情况判断）
ui/src/stores/modules/user.ts:146-154    删 EE/PE 分支调用 theme.theme() 的逻辑，一律走 defaultPlatformSetting
ui/src/utils/theme.ts                    defaultPlatformSetting 常量保留（logo / 外链开关源）
```

`getWorkspaceId()` 当前的实现位于 `stores/modules/user.ts`（不是独立的 workspace store）。验证后保留返回 `'default'` 的语义。

### 6.5 i18n 清理

三份 locale 文件（zh-CN / en-US / zh-Hant）分别处理：

```
保留:  views.userManage.*  views.system.email.*  views.system.resourceAuthorization.*
删除:  views.workspace.*  views.role.*  views.operateLog.*
       views.system.resource_management.*  views.shared.*  views.chatUser.*
       views.system.authentication.*  theme.*
新增:  layout.rail.system (zh-CN: "系统管理"  en-US: "System"  zh-Hant: "系統管理")
```

删除前 grep 每个 i18n key 的引用确认无残留。

### 6.6 检查清单（落地前必跑）

```bash
# 1. 死引用检查
grep -rn 'theme\.themeInfo' ui/src        # 所有 ?. 链确认 OK；fallback 走 defaultPlatformSetting
grep -rn 'role\.ts\|operate-log\.ts' ui/src # 确认无遗留 import
grep -rn 'SystemMainLayout' ui/src         # 确认无引用后再删
grep -rn '\$t(.views\.workspace' ui/src   # i18n key 引用清理

# 2. 编译
npm run type-check
npm run build

# 3. 后端 diff
git diff apps/                             # 必须为空
```

---

## 7. 落地策略

### 7.1 Phase 切分

| Phase | 内容 | 估时 |
|---|---|---|
| **PA · IA + 原子** | Rail 加 system 项；Side 默认行为；`<PageHeader>` 新建；`<StatusDot>` 扩展 enabled/disabled；i18n 加 `layout.rail.system`；删 `SystemMainLayout` | 0.5d |
| **PB · 用户管理重做** | PageHeader + .card-unified + AgentAvatar + StatusDot + LucideIcon | 0.5d |
| **PC · 资源授权重做** | PageHeader + Tabs 切 4 资源类型；WorkspaceDropdown 挪 actions；保留 PermissionTable | 0.5d |
| **PD · 邮箱设置轻量** | PageHeader + .card-unified；删 breadcrumb + 嵌套 card | 0.25d |
| **PE · 删除清理** | 删 12 孤儿页 + 对应 API client + i18n key + theme store 简化；workspace.ts 逐方法处理 | 1d |

**单人总计约 2.75d**。PB / PC / PD 解耦，多人可并行压缩到 1.5d。

PE 放最后是为了：先让活页改完并跑通，再做毁灭性清理 —— 出问题容易回滚。

### 7.2 验收

1. `npm run type-check` 退出码 0
2. `npm run build` 编译通过
3. dev server 走查：
   - 登录后 Rail 显示 6 项（含**新的"系统管理"**）
   - 点 Rail "系统管理" → 默认跳 `/system/user`
   - Side 显示 3 项：用户管理 / 资源授权 / 邮箱设置
   - **用户管理**：增删改查、批操作、状态切换、AgentAvatar、StatusDot、Lucide icons 都正常
   - **资源授权**：4 个 tab 切换 URL 跟着变化、PermissionTable 正常；EE 状态下 WorkspaceDropdown 在 PageHeader actions 显示
   - **邮箱设置**：PageHeader + 表单 + 保存 + 测试连接
   - 点 Rail "平台" → 跳 `/model`，模型管理页正常
   - 输入已删页面 URL（如 `/system/role`）→ 404 / noPermission
4. 浏览器控制台 0 warnings / 0 errors
5. `git diff apps/` 为空（后端零改动）
6. 工作空间字段验证：`grep -rn "workspace_id" apps/` 数量与 main 分支一致

### 7.3 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 删 `theme.theme()` 调用导致 logo / slogan 拿不到 | login / forgot-password / top-about 显示异常 | 一律走 `defaultPlatformSetting` 常量 fallback；走查登录页 |
| 删 `api/system/workspace.ts` 时漏判，断顶部 workspace dropdown | 顶部 dropdown 报错 | 逐方法 grep 引用；保留 `getWorkspaceListByUser` 改为静态 return |
| Tab 切换 in 资源授权破坏现有书签 / 浏览器后退 | 用户书签失效 | 每个 tab 是真实 router-link 不是纯前端 state；URL / 权限 / 书签都不变 |
| 删 i18n key 时被其它地方引用 | 红色 i18n missing 警告 | grep 所有引用后再删；保守起见先注释、下一轮清 |
| Rail 加项后 5 项变 6 项，1024-1280px 区间 Rail 挤 | 移动端断点 Rail 撑高 | 整体 spec §3.3 已声明 < 1024px 不支持；1280 以上不挤 |
| `SystemMainLayout.vue` 删后某处仍 import | 启动报错 | grep `SystemMainLayout` 确认无引用 |

---

## 8. 不在范围内

- **后端补齐**任何被删页面的功能（角色 / 操作日志 / 对话用户 / 共享资源等）—— 如果未来要做，单独立项
- **多工作空间** UI 重新引入（EE 才用，且当前后端不支持完整 CRUD）
- **管理后台移动端适配**（沿用整体 spec §3.3 总则，< 1024px 不支持）
- **i18n key 翻译质量** 优化（除 `layout.rail.system` 新增）
- **模型管理页**结构重做（之前已精简，本 spec 不动）

---

## 9. 完成定义

本 spec 实施完毕的标志：

1. Rail 显示 6 项，"系统管理"独立可见可点
2. 4 个活页（用户管理 / 资源授权 / 邮箱设置 / 模型管理）打开正常，按新原子风格渲染
3. 12 个被删的 URL 直接访问返回 noPermissionD 或 404
4. `apps/` git diff 为空
5. 浏览器控制台 / `npm run type-check` / `npm run build` 全部清白
6. `workspace_id` 字段在 `apps/` 全部保留；前端 `user.getWorkspaceId()` 返回 `'default'`
7. 30 秒辨认测试通过（系统管理任一页 30 秒内不会反应出是 MaxKB）
