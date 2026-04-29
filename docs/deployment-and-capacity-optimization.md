# MokeKB 部署与容量优化方案

## 背景

当前项目是一个完整的 Agent Full 平台：包含图形化管理界面、RAG 知识库、应用编排、工作流、多模态模型、工具市场、MCP、触发器、Celery 异步任务、PostgreSQL/pgvector、Redis、本地模型与沙箱执行能力。

现有部署方式偏向 all-in-one：一个容器内同时包含 Web 后端、前端静态资源、PostgreSQL、Redis、向量模型、ffmpeg、Python 运行时、Celery 与沙箱环境。这种方式对快速体验友好，但对生产部署、镜像体积、依赖管理、服务扩容和故障隔离都不够友好。

本方案的目标不是砍掉 Agent Full，而是在保留核心产品能力的前提下，降低部署复杂度、减少默认依赖、改善代码模块边界，并为用户量和 RAG 知识库规模增长做好容量设计。

## 目标边界

### 保留能力

- 图形化管理界面，用于 RAG、应用和工作流调试。
- RAG 知识库、文档上传、网页同步、向量化、检索和命中测试。
- 工作流和 Agent 编排能力。
- 图片、语音、视频等多模态能力。
- 工具市场、内置工具、自定义工具、MCP。
- Celery 异步任务和任务状态管理。
- PostgreSQL + pgvector 作为默认向量存储。

### 可精简能力

- 邮件设置和邮件通知相关能力。
- 默认内置全部模型厂商 SDK。
- all-in-one 生产部署路径。
- 后端镜像内置前端构建环境和静态资源。
- 默认内置本地 embedding/reranker 模型。
- API 文档静态资源在生产环境默认启用。
- 主 Web 进程承担工具代码执行、沙箱、本地模型推理等重任务。

## 当前主要问题

### 1. 部署职责过多

当前 Dockerfile 和启动脚本将多个组件塞入同一运行镜像：

- PostgreSQL
- Redis
- Web/Gunicorn
- Celery
- local model
- 前端静态资源
- pgvector/age
- ffmpeg
- 本地向量模型和 tokenizer
- 沙箱依赖

这导致镜像大、升级复杂、服务不可独立扩容，并且数据库和应用生命周期绑定过紧。

### 2. 模型供应商耦合过重

`models_provider.constants.model_provider_constants` 当前 eager import 所有 provider。即使用户不使用某个模型厂商，只要其 SDK 缺失或版本冲突，应用启动就可能失败。

此外，大量厂商本质上可以通过 OpenAI-compatible 或 Anthropic-compatible API 接入，不一定需要独立 SDK 和独立 provider 代码。

### 3. local model 依赖默认进入镜像

即使 Web 进程通过 `TorchBlocker` 尝试阻止 torch 导入，本地模型相关依赖和模型文件仍然影响镜像体积：

- torch
- sentence-transformers
- langchain-huggingface
- transformers
- 本地 embedding/tokenizer 模型

### 4. 前后端部署耦合

后端路由同时承担 API、admin/chat 静态页、API 文档静态资源和前端 404 fallback。这样会让后端镜像构建必须绑定前端构建，也让后端扩容时携带不必要的静态资源。

### 5. RAG 容量上限有隐患

当前 embedding 表是单表，向量索引按知识库创建 HNSW 部分索引。小规模下有效，但知识库数量和 embedding 数量上来后会出现：

- 索引数量过多。
- 索引构建和维护成本高。
- 大量写入时索引更新压力大。
- embedding 单表膨胀。
- 检索查询和管理分页变慢。

### 6. 异步任务队列过粗

当前 Celery 队列主要是 `celery` 和 `model`。RAG 文档解析、embedding、索引构建、聊天、工作流、工具执行、多模态任务混在一起，用户量上来后容易互相影响。

## 优化方案

## 一、部署架构优化

### 1. 保留 all-in-one，但不作为生产推荐

all-in-one 适合试用和单机体验，应保留，但明确定位：

- 快速体验。
- 本地试用。
- 小团队演示。

生产环境推荐使用拆分部署。

### 2. 新增标准 docker compose 部署

建议拆成以下服务：

- `web`: Django/Gunicorn API。
- `worker-rag`: 文档解析、切分、embedding。
- `worker-workflow`: 工作流和 Agent 执行。
- `worker-tool`: 工具市场、自定义工具、MCP。
- `worker-multimodal`: 语音、图片、视频任务。
- `local-model`: 可选，本地 embedding/reranker 推理。
- `ui`: 可选，前端静态资源或 Nginx。
- `postgres`: PostgreSQL + pgvector。
- `redis`: broker/cache/lock。

### 3. 新增 app-only 镜像

`app-only` 镜像只包含：

- Python 运行时。
- 后端代码。
- 必要系统库。
- 核心 Python 依赖。
- Gunicorn/Celery。

不包含：

- PostgreSQL。
- Redis。
- Node 构建环境。
- 本地模型文件。
- ffmpeg，除非启用多媒体 worker。
- 前端 dist，除非选择单镜像部署。

### 4. 前端独立部署

图形界面仍然保留，但建议从后端镜像拆出：

- 前端单独构建 `ui` 镜像。
- Nginx 或对象存储/CDN 托管静态资源。
- API 通过环境变量配置后端地址。

收益：

- 后端镜像更小。
- Web API 扩容不重复携带静态文件。
- 前端和后端可以独立发布。

## 二、功能模块 Profile 化

建议引入统一部署 Profile：

```env
MAXKB_PROFILE=agent-full
MAXKB_ENABLE_UI=true
MAXKB_ENABLE_EMAIL=false
MAXKB_ENABLE_TRIGGER=true
MAXKB_ENABLE_TOOLS=true
MAXKB_ENABLE_MCP=true
MAXKB_ENABLE_MULTIMODAL=true
MAXKB_ENABLE_LOCAL_MODEL=false
MAXKB_ENABLE_API_DOCS=false
MAXKB_ENABLED_MODEL_TYPES=LLM,EMBEDDING,RERANKER,IMAGE,STT,TTS,TTI,TTV,ITV
MAXKB_ENABLED_PROVIDERS=model_openai_provider,model_anthropic_provider,model_siliconCloud_provider
```

这些开关应集中影响：

- `INSTALLED_APPS`
- URL 路由
- 前端菜单
- provider 注册
- 模型类型列表
- Celery 队列
- Docker compose profile

避免业务代码散落大量临时判断。

## 三、模型供应商优化

### 1. 保留协议面，而非保留所有品牌面

推荐默认保留：

- OpenAI
- Anthropic
- OpenAI-compatible
- 可选 local model
- 可选国内聚合平台

DeepSeek、Kimi、硅基流动、智谱、百炼、vLLM 等如果支持 OpenAI-compatible API，应优先通过 OpenAI-compatible provider 接入。

### 2. provider 懒加载

将 provider 注册从 eager import 改为白名单懒加载：

```python
PROVIDER_REGISTRY = {
    "model_openai_provider": "models_provider.impl.openai_model_provider.openai_model_provider.OpenAIModelProvider",
    "model_anthropic_provider": "models_provider.impl.anthropic_model_provider.anthropic_model_provider.AnthropicModelProvider",
    "model_siliconCloud_provider": "models_provider.impl.siliconCloud_model_provider.siliconCloud_model_provider.SiliconCloudModelProvider",
}
```

运行时只加载 `MAXKB_ENABLED_PROVIDERS` 中的 provider。

收益：

- 未启用 provider 的 SDK 不影响启动。
- 依赖可以按 extra 安装。
- 生产环境可控。

### 3. 模型类型过滤

根据 `MAXKB_ENABLED_MODEL_TYPES` 控制前后端可见模型类型。保留 Agent Full 时可以默认全开；轻量部署可只启用 `LLM,EMBEDDING,RERANKER`。

## 四、依赖拆分

建议将 `pyproject.toml` 拆分依赖组：

```toml
[project.optional-dependencies]
core = [
  "django",
  "djangorestframework",
  "psycopg",
  "django-redis",
  "celery",
  "langchain",
  "langchain-openai",
  "langchain-anthropic"
]

local-model = [
  "torch",
  "sentence-transformers",
  "langchain-huggingface",
  "transformers"
]

multimodal = [
  "pydub",
  "pysilk",
  "pymupdf",
  "pypdf"
]

providers-cn = [
  "dashscope",
  "qianfan",
  "zhipuai",
  "tencentcloud-sdk-python",
  "volcengine-python-sdk"
]

tools = [
  "pylint",
  "pymysql",
  "psycopg2-binary"
]
```

生产默认安装 `core + multimodal + tools`，本地模型和具体厂商 SDK 按需安装。

## 五、RAG 容量优化

### 1. embedding 表增加 workspace_id

当前 embedding 表只有 `knowledge_id`、`document_id`、`paragraph_id`。建议新增 `workspace_id`，便于：

- 多租户隔离。
- 分区。
- 查询过滤。
- 统计和清理。

### 2. embedding 表分区

中长期建议按以下方式之一分区：

- 按 `workspace_id` hash 分区。
- 按 `knowledge_id` hash 分区。
- 按 embedding model 分区。

推荐优先：`workspace_id hash`，因为它更贴近租户容量隔离。

### 3. 向量索引策略分层

当前每个知识库创建一个 HNSW 部分索引。建议改为动态策略：

- 小知识库：使用共享索引或顺序扫描 + filter。
- 中型知识库：按知识库创建 HNSW 部分索引。
- 大型知识库：单独分区和索引。
- 超大租户：独立数据库或独立向量存储。

需要增加阈值配置：

```env
MAXKB_HNSW_INDEX_MIN_ROWS=5000
MAXKB_HNSW_INDEX_MAX_PER_WORKSPACE=200
MAXKB_VECTOR_PARTITION_STRATEGY=workspace_hash
```

### 4. 索引异步构建

HNSW 索引构建不要在文档 embedding 完成后同步执行，应放入独立 `rag_index` 队列。

### 5. 检索 SQL 优化

当前检索 SQL 会在 embedding 表上过滤并计算相似度。建议：

- 所有检索必须带 `workspace_id` 和 `knowledge_id`。
- 避免跨 embedding model 检索。
- 为 `knowledge_id, document_id, is_active, source_type` 建复合索引。
- keywords/blend 检索增加 GIN 索引。
- 对高频知识库缓存 top query 或 query embedding。

### 6. 文档解析和向量化批量优化

当前 paragraph embedding 批次偏小。建议动态 batch：

- OpenAI-compatible embedding：16/32/64。
- 本地 embedding：按显存/CPU 配置。
- 失败时自动降 batch。

配置示例：

```env
MAXKB_EMBEDDING_BATCH_SIZE=32
MAXKB_EMBEDDING_BATCH_SIZE_LOCAL=64
MAXKB_EMBEDDING_RETRY=3
```

## 六、任务队列优化

### 1. 拆分 Celery 队列

建议拆分：

- `rag_parse`
- `rag_embedding`
- `rag_index`
- `chat`
- `workflow`
- `tool`
- `mcp`
- `multimodal`
- `maintenance`

这样可以避免知识库导入、视频处理、工具执行挤占聊天和工作流请求。

### 2. worker 独立扩容

推荐扩容策略：

- 用户聊天多：扩 `web` 和 `chat` worker。
- 知识库导入多：扩 `rag_parse` 和 `rag_embedding` worker。
- 工具调用多：扩 `tool` 和 `mcp` worker。
- 多模态多：扩 `multimodal` worker。
- 本地模型多：扩 `local-model` 服务。

### 3. 任务限流

建议引入租户级限流：

- 每个 workspace 同时导入文档数。
- 每个 workspace embedding 并发数。
- 每个 API key 聊天并发数。
- 每个工具/MCP 最大运行时间。

## 七、分页和查询优化

### 1. 用 keyset pagination 替代 offset pagination

当前部分分页和批处理使用 offset，数据量大时会越来越慢。建议对后台列表和批处理改为：

- `id > last_id`
- `create_time < last_create_time`
- 组合游标：`(create_time, id)`

### 2. 大表 count 优化

当前分页常用 `count(*)`。建议：

- 后台列表允许近似总数。
- 深分页不返回 total。
- 对管理端保留 total，对接口端使用 cursor。

### 3. ChatRecord 热冷分离

`application_chat_record` 会随用户量快速膨胀。建议：

- 按月分区。
- 只保留近期热数据。
- 执行详情 `details` 可压缩或外置。
- API 默认不返回完整执行详情。

## 八、文件存储优化

当前文件使用 PostgreSQL Large Object 保存。小规模可用，但生产容量增长后建议支持外部对象存储：

- S3
- MinIO
- 阿里云 OSS
- 腾讯 COS

数据库只保留元数据和对象 key。

收益：

- 降低 PostgreSQL 存储压力。
- 文件下载不占 DB 带宽。
- 便于归档和生命周期清理。

## 九、工具市场和沙箱优化

工具市场保留，但执行环境建议独立：

- Web 进程只负责编排和鉴权。
- Tool worker 负责执行。
- Sandbox 单独镜像。
- 工具依赖单独安装目录。
- 工具执行超时、内存、网络访问白名单可配置。

这样可以降低主服务风险，也便于扩容工具执行能力。

## 十、邮件设置精简

不需要邮件设置时：

- 关闭 `email_setting` 路由。
- 隐藏前端邮件设置菜单。
- 关闭找回密码邮件流程或改为管理员重置。
- 删除邮件模板在默认镜像中的打包。
- 权限常量中邮件相关权限可以保留但不展示。

建议使用配置开关：

```env
MAXKB_ENABLE_EMAIL=false
```

## 十一、推荐实施路线

### 阶段 1：低风险部署瘦身

- 新增 docker compose 标准部署。
- 新增 app-only 镜像。
- 前端拆成独立镜像或静态资源服务。
- 保留 all-in-one 作为体验版。
- 邮件设置通过配置关闭。
- API docs 生产默认关闭。

### 阶段 2：模块开关与 provider 懒加载

- 引入 `MAXKB_PROFILE`。
- provider 注册改为白名单懒加载。
- 模型类型按配置过滤。
- local model 改为独立 profile。
- 厂商 SDK 拆 optional dependencies。

### 阶段 3：任务队列拆分

- 拆 Celery 队列。
- 按队列启动不同 worker。
- embedding batch 可配置。
- 索引构建放入 `rag_index` 队列。
- 增加 workspace 级任务并发控制。

### 阶段 4：RAG 数据层扩容

- embedding 表增加 `workspace_id`。
- 增加复合索引。
- keywords/blend 检索加 GIN 索引。
- 改造 HNSW 索引策略。
- 引入分区表。

### 阶段 5：高容量治理

- ChatRecord 分区和归档。
- 文件外置对象存储。
- 工具执行独立 sandbox。
- 租户级限流。
- 指标监控和慢查询治理。

## 十二、优先级建议

最高优先级：

1. app-only 镜像和 compose 拆分。
2. provider 懒加载和白名单。
3. 关闭邮件设置。
4. 前端/后端镜像拆分。
5. Celery 队列拆分。

中优先级：

1. embedding batch 优化。
2. keyset pagination。
3. ChatRecord 查询优化。
4. API docs 生产关闭。
5. local model 独立 profile。

长期优先级：

1. embedding 表分区。
2. HNSW 动态索引策略。
3. 文件外置对象存储。
4. 工具 sandbox 独立化。
5. 租户级容量配额和限流。

## 结论

当前系统不应该简单裁剪成轻量后端，因为你仍然需要 Agent Full、图形化调试、多模态和工具市场。更合理的方向是：

- 产品能力保留。
- 部署形态拆分。
- provider 和依赖按需加载。
- 非核心管理能力用 profile 关闭。
- RAG、任务队列、文件和聊天记录按容量增长重新设计。

这样可以同时满足完整功能和更容易部署，也能为后续更多用户、更大知识库和更多工作流执行留出扩展空间。
