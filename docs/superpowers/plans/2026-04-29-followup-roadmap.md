# MokeKB 后续优化路线图

> **For agentic workers:** 此文档不是一次性可落地计划，而是**长期 backlog**。每个工作项独立，可分别拉到自己的 plan 文档执行。
>
> 排序按"独立可执行 / ROI / 风险"组合考量，越靠前越建议先做。

**Goal:** 把 2026-04-29 主优化方案中"out of scope"的 5 项 + 代码 review 中标 P3 不做的 2 项，沉淀为可追踪的 backlog。

**Tech Stack:** Django 5.2 / PostgreSQL 17 / Celery / Docker / Vue 3

---

## 优先级一览

| # | 工作项 | 复杂度 | 风险 | 预估改动 |
|---|--------|-------|------|---------|
| F1 | 内部 sync 索引函数改私有命名 + UUID 校验 | 低 | 低 | 1 PR / 1 天 |
| F2 | 阿里百炼 / Docker AI provider embedding dimensions 也改自由输入 | 低 | 低 | 1 PR / 0.5 天 |
| F3 | ChatRecord 月分区 + 归档 | 中 | 中 | 1-2 PR / 1 周 |
| F4 | File 外置对象存储 (S3 / MinIO) | 中 | 中 | 1-2 PR / 1-2 周 |
| F5 | 工具沙箱独立容器 | 高 | 高 | 2-3 PR / 2-3 周 |
| F6 | 租户级配额与限流 | 高 | 中 | 2 PR / 2 周 |
| F7 | Trigger / 调度任务可观测性看板 | 中 | 低 | 1 PR / 1 周 |

---

## F1: 内部 sync 索引函数改私有 + UUID 校验

**背景：** Phase 6 把 `create_knowledge_index` / `drop_knowledge_index` 的对外调用全部改成异步 task。这两个函数现在只被 `apps/knowledge/task/index.py` 的 task wrapper 调用，但函数名仍然公开，未来开发可能误以为可以同步调用，破坏队列隔离。

同时这两个函数用 f-string 拼 SQL（k_id 来自 UUID 字段，但缺乏显式校验），属于 review 中 P3 的 SQLi 防御问题。

**Why:**
- 防止后续开发误用，恢复同步行为退化
- 显式 UUID 校验给出清晰的信任边界

**How to apply:**

1. `apps/knowledge/serializers/common.py`：把 `create_knowledge_index` → `_create_knowledge_index_sync`，`drop_knowledge_index` → `_drop_knowledge_index_sync`
2. 函数体首行加：

```python
import uuid as _uuid
_uuid.UUID(str(k_id))  # 仅做格式校验，失败抛 ValueError
```

3. 更新 `apps/knowledge/task/index.py` 的 import：

```python
from knowledge.serializers.common import (
    _create_knowledge_index_sync as create_knowledge_index,
    _drop_knowledge_index_sync as drop_knowledge_index,
)
```

或更直接：在 task 里就用新名字。

4. grep 确认没有遗漏的同步调用。

**Verification:**

```bash
grep -rn 'create_knowledge_index(\|drop_knowledge_index(' apps/ \
    | grep -v '_task\|_sync'
# 应该没有任何匹配
```

---

## F2: 国内 Provider embedding dimensions 也改自由输入

**背景：** Phase 3 Task 3.1 把 OpenAI provider 的 embedding `dimensions` 从固定下拉改成自由输入，以支持第三方 OpenAI 兼容端点的非标准维度。但同样的固定下拉模式还存在于：

- `apps/models_provider/impl/aliyun_bai_lian_model_provider/credential/embedding.py`
- `apps/models_provider/impl/docker_ai_model_provider/credential/embedding.py`

**Why:**
- 一致性：所有 OpenAI 兼容协议下的 provider 都应支持自定义维度
- 用户实际场景：通过百炼 / Docker AI 接 8192 / 4096 / 384 维 embedding 模型时被卡

**How to apply:**

1. 复用 `OpenAIEmbeddingModelParams` 在 `apps/models_provider/impl/openai_model_provider/credential/embedding.py:19-29` 的 `TextInputField` 写法
2. 把这两个 provider 的 `dimensions = forms.SingleSelect(...)` 改成同样的 `TextInputField` 块
3. 检查 `apps/models_provider/impl/aliyun_bai_lian_model_provider/model/embedding.py` 是否需要 dimensions sanitize（OpenAI provider Phase 3 加了 `optional_params` 清理，对应 commit 3c18bff1f）。如果阿里百炼 SDK 不接受空字符串或字符串维度，按同样方式 cast int / 剔除空值

**Verification:**

```bash
grep -rn 'class.*EmbeddingModelParams' apps/models_provider/impl/ \
    | xargs grep -l 'SingleSelect.*dimensions'
# 期望返回空（最理想）；如果还有别家就把它们也改了
```

---

## F3: ChatRecord 月分区 + 归档

**背景：** `application_chat_record` 表随用户量线性增长，热查询和历史数据混在一起。`details` JSON 字段可达数 KB，单表过千万行后 P99 查询延迟会显著恶化。`apps/common/job/clean_chat_job.py:48-95` 已有按 `clean_time` 软清理逻辑，但只是 DELETE，没有真正分离冷热。

**Why:**
- 历史对话数据是高写入低查询场景，适合按月切分
- 归档后的月分区可 detach + 转储到对象存储（与 F4 相关）
- 后台导出长时间窗口的报表时可以只扫相关分区

**How to apply:**

1. 创建 `application_chat_record_y2026m04` 这种命名约定的分区表
2. PostgreSQL 14+ 支持声明式分区：

```sql
CREATE TABLE application_chat_record_partitioned (
    LIKE application_chat_record INCLUDING ALL
) PARTITION BY RANGE (create_time);
```

3. 写迁移：
   - 创建分区父表
   - 把现有 `application_chat_record` 的数据按月 INSERT 到分区
   - 改名：原表 → `application_chat_record_legacy`，分区表 → `application_chat_record`
   - 加触发器：每月 1 号自动创建下月分区（用 pg_partman 或一个 celery 周期任务）

4. 旧月份分区按需 DETACH + 导出（pg_dump --table=...）后 DROP

5. 修改 `clean_chat_job` 或新增 `chat_archive_job`：从软删除改为 detach 整个分区 + 转储

**Risk:**
- 分区改造期间需短暂写入冻结（或在 PG 主从架构上做主备切换）
- 现有 ORM 查询需验证全部走 `create_time` 索引（PG 才能 partition pruning）

**Verification:**

```sql
EXPLAIN SELECT * FROM application_chat_record
WHERE create_time > '2026-04-01' AND chat_id = '...';
-- 期望 plan 仅扫描 _y2026m04 分区，不扫全表
```

---

## F4: File 外置对象存储

**背景：** `apps/knowledge/models/knowledge.py:329-433` 的 `File.save` 用 PostgreSQL Large Object（`lo_creat`/`lo_put`/`lo_get`/`lo_unlink`）存文件。优点是事务化，缺点是：
- DB 体积膨胀，备份恢复时间长
- 大文件下载占 DB 带宽
- 不易做生命周期管理 / CDN 加速

**Why:**
- 多数生产部署需要 TB 级文件存储，DB 不应承担这个职责
- 对象存储有原生的多区冗余、生命周期策略、CDN 集成

**How to apply:**

1. 新建 `apps/oss/storage_backend/` 目录，下放：
   - `base.py` - 抽象接口 `IStorageBackend`（`put`/`get`/`get_stream`/`delete`/`exists`）
   - `pg_lo_backend.py` - 兼容老逻辑的 PG Large Object 实现（默认）
   - `s3_backend.py` - S3 / MinIO / 阿里 OSS / 腾讯 COS（boto3 已在 providers-extras）
2. 加配置：
   - `MAXKB_FILE_STORAGE_BACKEND=pg_lo` (默认) / `s3`
   - `MAXKB_S3_ENDPOINT` / `MAXKB_S3_BUCKET` / `MAXKB_S3_REGION` / `MAXKB_S3_ACCESS_KEY` / `MAXKB_S3_SECRET_KEY`
3. `File` 模型加字段：
   - `storage_backend` (CharField, choices)
   - `external_key` (CharField, nullable - S3 object key)
   - `loid` 改 nullable（外部存储时为空）
4. 重写 `File.save` / `File.get_bytes` / `File.get_bytes_stream` 委托给 backend
5. 数据迁移工具：把现有 `loid` 文件灌进 S3，更新 `storage_backend='s3'` 和 `external_key`，最后 DROP loid

**Risk:**
- 迁移期间双写双读保证可用
- S3 故障的影响面从 DB 内事务保证扩大到外部依赖

**Verification:**

```bash
# 上传 100MB 测试文件，验证两种 backend 行为一致
python apps/manage.py shell <<'EOF'
from knowledge.models import File
import io
f = File(file_name='100mb.bin', source_type='SYSTEM', source_id='test')
f.save(bytea=b'X' * (100 * 1024 * 1024))
print('loid:', f.loid, 'external_key:', getattr(f, 'external_key', None))
content = f.get_bytes()
print('roundtrip ok:', len(content) == 100 * 1024 * 1024)
EOF
```

---

## F5: 工具沙箱独立容器

**背景：** 现在 `installer/sandbox.c` 通过 LD_PRELOAD 在 web/celery 进程内拦截危险 syscall。安全保证依赖 setuid sandbox 用户和 ld.so 的链接顺序，攻击面与主进程共享。Phase 4 拆出 app-only 镜像后，沙箱仍跑在 worker 容器里。

**Why:**
- LD_PRELOAD 不是真正的隔离 (容器仍可能被绕过)
- 沙箱代码占用主 worker 内存配额，挤压正常 RAG 任务
- 工具市场对自定义工具放开口子时，影响放大

**How to apply:**

1. 新建 `installer/Dockerfile.sandbox` - 独立 Python 镜像，仅装可信白名单包（requests / pymysql / psycopg2-binary）
2. 沙箱执行接口：现在 worker 内通过 fork+execve 跑用户代码，改成 RPC 给独立 `maxkb-sandbox` 服务
3. 通信协议：HTTP（加 token）或 gRPC，发送代码 + stdin，接收 stdout/stderr/return_code
4. `maxkb-sandbox` 服务：
   - 用 gVisor (`runsc`) 或 firecracker microVM 跑用户代码（强隔离）
   - 或保留 LD_PRELOAD + setuid 但加上 cgroup 限内存 / CPU
5. compose 加 `maxkb-sandbox` 服务，资源 `mem_limit: 512m, cpu_quota: 50000`

**Risk:**
- 高复杂度；需要重设计工具执行 API
- 网络 RPC 增加延迟（但工具执行本来就是秒级，可接受）

---

## F6: 租户级配额与限流

**背景：** 多租户场景下，单 workspace 的恶意 / 失误用法会拖累整个集群。Plan 原 §六.3 提到，但未实施。

**Why:**
- 大客户突然导入 1000 个文档会把 RAG 队列堆满，影响其他租户
- 没有控制时只能事后看监控发现问题

**How to apply:**

1. 在 Redis 实现滑动窗口计数：
   - Key: `ratelimit:{workspace_id}:{action}:{minute_bucket}`
   - `INCR` + `EXPIRE`
2. 配额维度：
   - 每个 workspace 同时进行的文档导入数（默认 10）
   - 每个 workspace embedding 调用频率（默认 100/min）
   - 每个 application api_key 聊天并发（默认 20）
   - 每个工具/MCP 调用最大运行时间（默认 300s）
3. 配额配置：在 `system_setting` 表加一个 `quota_setting` 类型，admin 可在管理后台改
4. 实施点：
   - 文档导入：`apps/knowledge/serializers/document.py` 各 `import_*` 方法在 enqueue 前查配额
   - Chat 并发：`apps/chat/serializers/chat.py` 入口加 RateLimit 装饰器
   - 工具：`apps/trigger/handler/impl/task/tool_task/base_tool_task.py` execute 前查配额
5. 触发限流时：返回 429 + 友好错误提示

**Verification:**

```python
# 并发跑 200 个 chat 请求，预期 100+ 被限流
import threading, requests
def hit():
    return requests.post('/chat/api/...', headers={'API-Key': '...'}, json={...})
results = [hit() for _ in range(200)]
print('429s:', sum(1 for r in results if r.status_code == 429))
```

---

## F7: 调度任务可观测性看板

**背景：** Phase 5 后所有定时任务都跑在 `maxkb-worker-maintenance` 容器里。出问题时定位靠看 docker logs。

**Why:**
- 哪些 trigger 在跑？最后一次成功 / 失败时间？运行时长？
- 哪些任务被 QueueOnce 锁住？

**How to apply:**

1. `apps/system_manage/views/` 加 `JobMonitor` view：
   - GET `/admin/api/system_manage/jobs` - apscheduler.get_jobs() + django_apscheduler 的执行历史
   - GET `/admin/api/system_manage/celery_tasks` - 用 celery inspect API 拿活动任务
2. 前端加菜单 "系统监控 → 调度任务"，列表 + 时间轴展示
3. 接 prometheus 客户端（可选）：暴露 `/metrics`，celery 指标 + DB 慢查询数 + Redis 连接池利用率

---

## 实施顺序建议

```
F1 (1d) ──┐
F2 (0.5d)─┼──► F3 (1w)──► F4 (1-2w)──► F5 (2-3w)
          │       │
          └──► F7 (1w)──► F6 (2w)
```

- F1 / F2 / F7 是低风险点缀，可由实习生 / 新人做，建立信心
- F3 / F4 是数据层重构，需要业务低峰期窗口
- F5 是高复杂度安全升级，建议有外部 review
- F6 依赖 F7（先看清楚再限流）

---

## 与主优化方案的关系

主优化方案 `2026-04-29-deployment-and-capacity-optimization.md` 已覆盖 35 个 commits（Phase 1-6）。这份 followup 是它的 **out of scope** + **review 标 P3** 的延续，不重复任何已完成的工作。

每完成一项 followup，可在该 plan 的 `## 实施顺序建议` 段下追加 commit hash 跟踪。
