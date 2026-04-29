# MokeKB 部署与容量优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留 Agent Full 能力的前提下，把 MokeKB 从 all-in-one 镜像演进为可独立扩容的多服务部署，按需加载 provider，按容量优化向量库与主库。

**Architecture:**
- 渐进式：保留 all-in-one 作为体验版兜底，所有改动加开关、默认走旧路径，最后再切默认值。
- 分阶段：6 个 Phase，每个 Phase 独立可发布、独立可回滚。任何一个 Phase 跑完都能继续提供服务。
- 最大化使用环境变量驱动；不引入新的配置文件格式。

**Tech Stack:** Django 5.2 / Celery 5.5 / PostgreSQL 17 + pgvector / Redis / langchain-openai / Vue 3 / Vite / Docker / Gunicorn

**Out of scope（后续单独规划）：**
- ChatRecord 月分区与归档
- File 外置对象存储 (S3/MinIO)
- 工具沙箱独立容器
- 租户级配额/限流

---

## 实施顺序与依赖

```
Phase 0  Baseline      ──► Phase 1 Slim-Down  ──► Phase 2 Email Rework
                                                       │
                                                       ▼
Phase 3 Provider Lazy-Load ──► Phase 4 Image Split ──► Phase 5 Queue Split ──► Phase 6 RAG/DB
```

每个 Phase 末尾都有"冒烟回归"任务，确保 all-in-one 仍可启动、关键流程可用。

---

## Phase 0 — 基线快照

确认起点状态并冻结预期行为。

### Task 0.1: 记录基线启动与冒烟流程

**Files:**
- Create: `docs/superpowers/plans/baseline.md`

- [ ] **Step 1: 启动 all-in-one 容器并记录关键信息**

```bash
docker run -d --name maxkb-baseline -p 18080:8080 \
  -v ${PWD}/.baseline-data:/var/lib/postgresql/data \
  ghcr.io/1panel-dev/maxkb:v2.0.0
sleep 60
docker exec maxkb-baseline ps -ef | tee /tmp/baseline-processes.txt
docker exec maxkb-baseline cat /opt/py3/lib/python3.11/site-packages/django/__init__.py | head -5
docker exec maxkb-baseline du -sh /opt/maxkb-app/model 2>/dev/null
docker images ghcr.io/1panel-dev/maxkb:v2.0.0 --format '{{.Size}}'
```

Expected: 5 个进程（postgres, redis-server, gunicorn web, gunicorn local_model, celery worker），镜像大小 6–10 GB，model 目录 1–3 GB。

- [ ] **Step 2: 跑冒烟流程并截图保存**

通过浏览器访问 `http://127.0.0.1:18080/admin/`，登录默认账号 `admin/MaxKB@123..`，依次完成：
1. 新建一个知识库（"baseline-kb"），上传一段纯文本
2. 等向量化完成
3. 在"命中测试"输入查询，确认能返回段落
4. 新建应用，绑定知识库，发起一次对话

- [ ] **Step 3: 写入 baseline.md**

把进程清单、镜像大小、model 目录大小、冒烟通过截图（或 5 行说明）写入 `docs/superpowers/plans/baseline.md`。后续每个 Phase 末尾的冒烟回归都对照这个文件。

- [ ] **Step 4: 提交**

```bash
git add docs/superpowers/plans/baseline.md
git commit -m "docs: capture deployment baseline before optimization"
```

---

## Phase 1 — 低风险瘦身

去掉死代码、关掉裸奔的 API doc、把硬编码的禁用列表改成可配置。每一项都不改业务逻辑。

### Task 1.1: 删除未使用的 PostgreSQL AGE 扩展

**Files:**
- Modify: `installer/Dockerfile-base:18-19`

- [ ] **Step 1: 确认代码中无任何 AGE/cypher 引用**

```bash
grep -rE 'CREATE EXTENSION.*age|ag_catalog|cypher\(' apps/ installer/ | grep -v '\.po:' || echo "no references"
```

Expected output: `no references`

- [ ] **Step 2: 修改 Dockerfile-base**

打开 `installer/Dockerfile-base`，定位 12-19 行的 `DEPENDENCIES` 块，删除 `postgresql-17-age` 一行：

```dockerfile
ARG DEPENDENCIES="                    \
        curl                          \
        ca-certificates               \
        vim                           \
        wait-for-it                   \
        redis-server                  \
        postgresql-17-pgvector"
```

- [ ] **Step 3: 重建 base 镜像并验证扩展数量**

```bash
docker build -f installer/Dockerfile-base -t maxkb-base:test .
docker run --rm maxkb-base:test sh -c 'dpkg -l | grep -E "postgresql-17-(pgvector|age)"'
```

Expected: 只列出 `postgresql-17-pgvector`，不再列出 `postgresql-17-age`。

- [ ] **Step 4: 提交**

```bash
git add installer/Dockerfile-base
git commit -m "build: remove unused PostgreSQL AGE extension from base image"
```

### Task 1.2: 关闭 chat API doc 的密码绕过

**Files:**
- Modify: `apps/common/init/init_doc.py:67-74`

- [ ] **Step 1: 阅读现状**

打开 `apps/common/init/init_doc.py`，确认 71-73 行：

```python
(init_chat_doc, {'valid': lambda: CONFIG.get('DOC_PASSWORD') is not None and encrypt(
    CONFIG.get('DOC_PASSWORD')) == 'd4fc097197b4b90a122b92cbd5bbe867' or True, ...
```

末尾 `or True` 让 chat doc 永远暴露。

- [ ] **Step 2: 删除 `or True` 让 chat doc 走和 admin doc 一样的密码校验**

```python
init_list = [(init_app_doc, {'valid': lambda: CONFIG.get('DOC_PASSWORD') is not None and encrypt(
    CONFIG.get('DOC_PASSWORD')) == 'd4fc097197b4b90a122b92cbd5bbe867',
                             'get_call': get_call,
                             'get_params': lambda application_urlpatterns, patterns: (application_urlpatterns,)}),
             (init_chat_doc, {'valid': lambda: CONFIG.get('DOC_PASSWORD') is not None and encrypt(
                 CONFIG.get('DOC_PASSWORD')) == 'd4fc097197b4b90a122b92cbd5bbe867',
                              'get_call': get_call,
                              'get_params': lambda application_urlpatterns, patterns: (
                                  application_urlpatterns, patterns)})]
```

- [ ] **Step 3: 验证未设置 DOC_PASSWORD 时 chat doc schema 路由不存在**

```bash
python apps/manage.py shell <<'EOF'
from maxkb import urls
print([str(p.pattern) for p in urls.urlpatterns if 'chat_schema' in (p.name or '')])
EOF
```

Expected output: `[]`（空列表）

- [ ] **Step 4: 提交**

```bash
git add apps/common/init/init_doc.py
git commit -m "fix(security): require DOC_PASSWORD for chat API doc schema endpoint"
```

### Task 1.3: 增加 MAXKB_ENABLE_API_DOCS 总开关

**Files:**
- Modify: `apps/maxkb/urls/web.py:54-79`
- Modify: `apps/maxkb/conf.py`（新增 getter）

- [ ] **Step 1: 确认 ConfigManager 写法**

```bash
grep -n 'def get_admin_path\|def get_chat_path\|def get_debug' apps/maxkb/conf.py
```

记下其中一个 getter 的实现，照抄风格。

- [ ] **Step 2: 在 conf.py 中新增 getter（紧跟 get_debug 后）**

打开 `apps/maxkb/conf.py`，按现有 getter 风格新增：

```python
def get_enable_api_docs(self):
    val = self.get('ENABLE_API_DOCS')
    if val is None:
        return False  # 生产默认关闭
    return str(val).lower() in ('1', 'true', 'yes', 'on')
```

- [ ] **Step 3: 在 urls/web.py 中用开关包裹 doc 静态路由与 init_doc 调用**

定位 `apps/maxkb/urls/web.py:51`（`init_doc(...)` 行）和 78-79 行（`if not settings.DEBUG: pro()`），改为：

```python
if CONFIG.get_enable_api_docs():
    init_doc(urlpatterns, chat_urlpatterns)


def pro():
    if CONFIG.get_enable_api_docs():
        urlpatterns.append(
            re_path(rf'^{CONFIG.get_admin_path()[1:]}/api-doc/(?P<path>.*)$', static.serve,
                    {'document_root': os.path.join(settings.STATIC_ROOT, "drf_spectacular_sidecar")}, name='doc'),
        )
        urlpatterns.append(
            re_path(rf'^{CONFIG.get_chat_path()[1:]}/api-doc/(?P<path>.*)$', static.serve,
                    {'document_root': os.path.join(settings.STATIC_ROOT, "drf_spectacular_sidecar")}, name='doc_chat'),
        )
    # 暴露ui静态资源
    urlpatterns.append(
        re_path(rf"^{CONFIG.get_admin_path()[1:]}/(?P<path>.*)$", static.serve,
                {'document_root': os.path.join(settings.STATIC_ROOT, "admin")},
                name='admin'),
    )
    urlpatterns.append(
        re_path(rf'^{CONFIG.get_chat_path()[1:]}/(?P<path>.*)$', static.serve,
                {'document_root': os.path.join(settings.STATIC_ROOT, "chat")},
                name='chat'),
    )
```

- [ ] **Step 4: 验证默认关闭**

```bash
python apps/manage.py shell <<'EOF'
from maxkb import urls
names = [p.name for p in urls.urlpatterns if p.name]
print('doc' in names, 'doc_chat' in names, 'schema' in names, 'chat_schema' in names)
EOF
```

Expected: `False False False False`

- [ ] **Step 5: 验证打开后路由出现**

```bash
MAXKB_ENABLE_API_DOCS=true MAXKB_DOC_PASSWORD='maxkb' python apps/manage.py shell <<'EOF'
from maxkb import urls
names = [p.name for p in urls.urlpatterns if p.name]
print('doc' in names, 'schema' in names)
EOF
```

Expected: `True True`

- [ ] **Step 6: 提交**

```bash
git add apps/maxkb/urls/web.py apps/maxkb/conf.py
git commit -m "feat: gate API docs behind MAXKB_ENABLE_API_DOCS, default off"
```

### Task 1.4: 移除 celery_model 死代码

**Files:**
- Modify: `apps/common/management/commands/services/command.py:16-49`
- Modify: `apps/ops/celery/__init__.py:24-27`

- [ ] **Step 1: 确认 celery_model 没有 service class 注册**

```bash
grep -n 'celery_model' apps/common/management/commands/services/
```

应该只在 `command.py:16` 和 `command.py:36` 出现，没有 service class。

- [ ] **Step 2: 删除 command.py 中的 celery_model 引用**

打开 `apps/common/management/commands/services/command.py`，把 16 行 `celery_model = 'celery_model', 'celery_model'` 删掉，把 36 行 `return [cls.celery_default, cls.celery_model]` 改为 `return [cls.celery_default]`。

- [ ] **Step 3: 删除 ops/celery/__init__.py 中无对应 worker 的 model queue**

打开 `apps/ops/celery/__init__.py:24-27`，把 `task_queues` 配置改为：

```python
configs["task_queues"] = [
    Queue("celery", Exchange("celery"), routing_key="celery"),
]
```

- [ ] **Step 4: 验证启动 celery 仍然 OK**

```bash
SERVER_NAME=celery python apps/manage.py celery celery_default --help 2>&1 | head -5
```

Expected: 帮助文本输出，没有 `KeyError: celery_model`。

- [ ] **Step 5: 提交**

```bash
git add apps/common/management/commands/services/command.py apps/ops/celery/__init__.py
git commit -m "chore: remove dead celery_model queue and service entry"
```

### Task 1.5: 沙箱禁用列表保持保守默认（仅文档化覆盖路径）

**Files:**
- 不修改 Dockerfile-base 默认值
- Append: `docs/deployment-split.md`（Phase 6 Task 6.8 中产出，本任务先放规划占位）

- [ ] **Step 1: 复核现状**

`installer/Dockerfile-base:48-51` 默认禁 `127.0.0.0/8,localhost,host.docker.internal,172.17.0.0/16,maxkb,pgsql,redis,172.31.250.192/26,0.0.0.0/32,::/0`。这是**安全保守值**，沙箱不能随意访问内网。

- [ ] **Step 2: 不动默认值**

split 部署若需要沙箱访问 PG/Redis service 名，**不应放松全局默认**，而由 split compose 显式覆盖：

```yaml
# 留作 Phase 4 Task 4.4 docker-compose.split.yml 的注释示例
# environment:
#   # 仅当沙箱内代码确实需要访问 postgres/redis 时再放开，否则保持默认
#   MAXKB_SANDBOX_PYTHON_BANNED_HOSTS: "127.0.0.0/8,localhost,169.254.0.0/16,::1/128"
```

- [ ] **Step 3: 跳过提交（本任务无代码改动）**

记录到计划里即可。Phase 6 Task 6.8 产出 `docs/deployment-split.md` 时把上面注释作为可选项写进去。

### Task 1.6: 给 apscheduler 启动加 MAXKB_ENABLE_SCHEDULER 开关

**Files:**
- Modify: `apps/common/job/scheduler.py`
- Modify: `apps/maxkb/conf.py`

- [ ] **Step 1: 在 conf.py 新增 getter**

打开 `apps/maxkb/conf.py`，在 `get_enable_api_docs` 之后追加：

```python
def get_enable_scheduler(self):
    val = self.get('ENABLE_SCHEDULER')
    if val is None:
        # 兼容老行为：默认 web 进程开启，celery worker 不开
        import os
        return os.environ.get('SERVER_NAME', 'web') == 'web'
    return str(val).lower() in ('1', 'true', 'yes', 'on')
```

- [ ] **Step 2: 改造 scheduler.py 让 start() 可被关闭**

替换 `apps/common/job/scheduler.py` 全文：

```python
from apscheduler.schedulers.background import BackgroundScheduler
from django_apscheduler.jobstores import DjangoJobStore

from maxkb.const import CONFIG

scheduler = BackgroundScheduler()
scheduler.add_jobstore(DjangoJobStore(), "default")

if CONFIG.get_enable_scheduler():
    try:
        scheduler.start()
    except Exception as e:
        from common.utils.logger import maxkb_logger

        maxkb_logger.error(f"Failed to start scheduler: {e}")
```

- [ ] **Step 3: 验证 worker 进程默认不启动 scheduler**

```bash
SERVER_NAME=celery python -c "from common.job.scheduler import scheduler; print('running:', scheduler.running)"
```

Expected: `running: False`

```bash
SERVER_NAME=web python -c "from common.job.scheduler import scheduler; print('running:', scheduler.running)"
```

Expected: `running: True`

- [ ] **Step 4: 提交**

```bash
git add apps/common/job/scheduler.py apps/maxkb/conf.py
git commit -m "feat: gate apscheduler start behind MAXKB_ENABLE_SCHEDULER (default web only)"
```

### Task 1.7: 给 File.sha256_hash 加普通索引（不加 unique）

**Files:**
- Create: `apps/knowledge/migrations/0008_file_sha256_index.py`

**说明：** 业务语义上同 sha256 可有多行（不同 source_type/source_id 共享 loid），所以**不能**加 unique。这里只为 `File.save()` 的 `filter(sha256_hash=...).first()` 查询提速。

- [ ] **Step 1: 创建 migration 文件**

写入 `apps/knowledge/migrations/0008_file_sha256_index.py`：

```python
from django.db import migrations


class Migration(migrations.Migration):

    atomic = False  # CREATE INDEX CONCURRENTLY 不能在事务中

    dependencies = [
        ('knowledge', '0007_remove_knowledgeworkflowversion_workflow_and_more'),
    ]

    operations = [
        migrations.RunSQL(
            sql=[
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS file_sha256_hash_idx
                   ON file (sha256_hash)
                   WHERE sha256_hash <> ''""",
            ],
            reverse_sql=[
                "DROP INDEX IF EXISTS file_sha256_hash_idx",
            ],
        ),
    ]
```

- [ ] **Step 2: 跑 migration 并验证**

```bash
python apps/manage.py migrate knowledge
python apps/manage.py shell <<'EOF'
from django.db import connection
with connection.cursor() as c:
    c.execute("SELECT indexname FROM pg_indexes WHERE tablename='file' AND indexname='file_sha256_hash_idx'")
    print(c.fetchall())
EOF
```

Expected: 输出包含 `file_sha256_hash_idx`。

- [ ] **Step 3: 验证 File.save 仍然按 sha256 复用 loid**

```bash
python apps/manage.py shell <<'EOF'
from knowledge.models import File
import io
# 模拟两次同内容上传，应得到相同 loid
f1 = File(file_name='t.txt', source_type='SYSTEM', source_id='a')
f1.save(bytea=b'hello world test content for sha dedup')
f2 = File(file_name='t.txt', source_type='SYSTEM', source_id='b')
f2.save(bytea=b'hello world test content for sha dedup')
print('loid match:', f1.loid == f2.loid, 'distinct id:', f1.id != f2.id)
EOF
```

Expected: `loid match: True distinct id: True`（业务语义保留：两行 File 共享 loid）。

- [ ] **Step 4: 提交**

```bash
git add apps/knowledge/migrations/0008_file_sha256_index.py
git commit -m "perf(db): add concurrent index on File.sha256_hash to speed up dedup lookup"
```

### Task 1.8: Phase 1 冒烟回归

**Files:**
- Modify: `docs/superpowers/plans/baseline.md`

- [ ] **Step 1: 重建 all-in-one 镜像**

```bash
docker build -f installer/Dockerfile -t maxkb-local:phase1 .
docker rm -f maxkb-phase1 2>/dev/null
docker run -d --name maxkb-phase1 -p 18081:8080 maxkb-local:phase1
sleep 60
docker logs --tail 50 maxkb-phase1
```

Expected: 看到 `MaxKB started.` 字样，无 ERROR。

- [ ] **Step 2: 验证默认关 API doc**

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18081/admin/api-doc/
```

Expected: `404`

- [ ] **Step 3: 重跑 Phase 0 的冒烟流程**

走 baseline.md 记录的 4 步（建库、上传、命中、对话），全部通过。

- [ ] **Step 4: 在 baseline.md 末尾追加 phase1 记录**

记录镜像大小（应略小，因 age 扩展剔除）+ 进程清单（应不变）。

- [ ] **Step 5: 提交**

```bash
git add docs/superpowers/plans/baseline.md
git commit -m "docs: phase 1 smoke regression notes"
```

---

## Phase 2 — 邮件改管理员重置

把找回密码邮件流程换成"管理员重置"，并增加 `MAXKB_ENABLE_EMAIL` 总开关。

### Task 2.1: 后端新增"管理员重置密码"接口

**Files:**
- Modify: `apps/users/serializers/user.py`（新增 `AdminResetPasswordSerializer`）
- Modify: `apps/users/views/user.py`（新增 `AdminResetPassword` view）
- Modify: `apps/users/urls.py`（新增路由）
- Modify: `apps/users/api/user.py`（新增 API schema）

- [ ] **Step 1: 阅读现有 ResetCurrentUserPassword 风格**

```bash
grep -n 'class ResetCurrentUserPassword\|class ChangeUserPasswordApi' apps/users/serializers/user.py apps/users/api/user.py
```

记下方法签名、字段命名习惯。

- [ ] **Step 2: 在 serializers/user.py 末尾新增 serializer**

打开 `apps/users/serializers/user.py`，文件末尾追加：

```python
class AdminResetPasswordSerializer(serializers.Serializer):
    target_user_id = serializers.UUIDField(required=True, label=_("Target user id"))
    new_password = serializers.CharField(required=True, min_length=6, max_length=64,
                                         label=_("New password"))

    def reset(self):
        from users.models import User
        from common.utils.common import password_encrypt
        self.is_valid(raise_exception=True)
        user = User.objects.filter(id=self.validated_data['target_user_id']).first()
        if user is None:
            raise AppApiException(500, _("User does not exist"))
        user.password = password_encrypt(self.validated_data['new_password'])
        user.save()
        return {'id': str(user.id), 'username': user.username}
```

如果 `password_encrypt` 名称不同，先 grep 确认：

```bash
grep -n 'def password_encrypt\|password = ' apps/users/serializers/user.py | head -10
```

按真实名称替换。

- [ ] **Step 3: 在 views/user.py 末尾新增 view**

```python
class AdminResetPassword(APIView):
    authentication_classes = [TokenAuth]

    @extend_schema(methods=['POST'],
                   summary=_("Admin reset user password"),
                   tags=[_("User Management")],
                   request=AdminResetPasswordAPI.get_request(),
                   responses=AdminResetPasswordAPI.get_response())
    @log(menu='User management', operate='Admin reset password',
         get_operation_object=lambda r, k: {'name': r.data.get('target_user_id', None)})
    @has_permissions(RoleConstants.ADMIN)
    def post(self, request: Request):
        from users.serializers.user import AdminResetPasswordSerializer
        return result.success(AdminResetPasswordSerializer(data=request.data).reset())
```

- [ ] **Step 4: 在 api/user.py 新增 API schema**

参考同文件 `class ChangeUserPasswordApi` 写法，追加：

```python
class AdminResetPasswordAPI(APIMixin):
    @staticmethod
    def get_request():
        return AdminResetPasswordRequest

    @staticmethod
    def get_response():
        return DefaultResultSerializer


class AdminResetPasswordRequest(serializers.Serializer):
    target_user_id = serializers.UUIDField(required=True)
    new_password = serializers.CharField(required=True, min_length=6, max_length=64)
```

- [ ] **Step 5: 在 urls.py 末尾新增路由**

打开 `apps/users/urls.py`，在 urlpatterns 列表末尾追加：

```python
path('user/admin_reset_password', views.AdminResetPassword.as_view()),
```

- [ ] **Step 6: 验证管理员可调用、普通用户不能调用**

```bash
python apps/manage.py shell <<'EOF'
from users.serializers.user import AdminResetPasswordSerializer
from users.models import User
import uuid
u = User.objects.filter(role='ADMIN').first()
s = AdminResetPasswordSerializer(data={'target_user_id': str(u.id), 'new_password': 'TestPwd123'})
s.is_valid(raise_exception=True)
print('serializer ok')
EOF
```

Expected: 输出 `serializer ok`，无异常。

- [ ] **Step 7: 提交**

```bash
git add apps/users/serializers/user.py apps/users/views/user.py apps/users/api/user.py apps/users/urls.py
git commit -m "feat(users): add admin password reset API"
```

### Task 2.2: 把找回密码邮件流程包到 MAXKB_ENABLE_EMAIL 开关下

**Files:**
- Modify: `apps/users/serializers/user.py:1098`（send_mail 调用处）
- Modify: `apps/users/views/user.py:306-325`（SendEmail view）
- Modify: `apps/maxkb/conf.py`（新增 getter）

- [ ] **Step 1: 在 conf.py 新增 getter**

```python
def get_enable_email(self):
    val = self.get('ENABLE_EMAIL')
    if val is None:
        return False  # 默认关闭
    return str(val).lower() in ('1', 'true', 'yes', 'on')
```

- [ ] **Step 2: 在 SendEmail view 顶部加开关判断**

定位 `apps/users/views/user.py:306` 的 `class SendEmail(APIView):`，在其 `post` 方法体首行插入：

```python
def post(self, request: Request):
    from maxkb.const import CONFIG
    if not CONFIG.get_enable_email():
        from common.exception.app_exception import AppApiException
        raise AppApiException(1004, _('Email feature is disabled. Contact administrator to reset password.'))
    serializer_obj = SendEmailSerializer(data=request.data)
    ...
```

`...` 部分保留原有代码。

- [ ] **Step 3: 在 serializers/user.py 的 send_mail 调用前加同样的开关**

定位 `apps/users/serializers/user.py:1098` 的 `send_mail(...)` 调用，在它所在方法（grep `def .*\(self.*email` 找到包含此 send_mail 的 method）的开头加：

```python
from maxkb.const import CONFIG
if not CONFIG.get_enable_email():
    raise AppApiException(1004, _('Email feature is disabled.'))
```

- [ ] **Step 4: 验证默认关闭后接口拒绝**

```bash
python apps/manage.py shell <<'EOF'
from users.views.user import SendEmail
print(SendEmail.__module__)
EOF
```

后用浏览器或 curl 调用 `POST /admin/api/user/send_email`，应返回错误码 1004 + 提示"Email feature is disabled"。

- [ ] **Step 5: 提交**

```bash
git add apps/users/views/user.py apps/users/serializers/user.py apps/maxkb/conf.py
git commit -m "feat: gate email-based password recovery behind MAXKB_ENABLE_EMAIL"
```

### Task 2.3: 前端找回密码页改为"联系管理员"

**Files:**
- Modify: `ui/src/views/login/forgot-password.vue` 或同名同位的入口页

- [ ] **Step 1: 定位前端找回密码页面**

```bash
grep -rln 'forgot\|forgotPwd\|forgot_password\|sendEmail\|verifyCode' ui/src/views/login/ ui/src/api/user/ 2>/dev/null
```

找到入口组件（通常是 `ui/src/views/login/forgot-password.vue` 或 `forgotPwd/index.vue`）。

- [ ] **Step 2: 改写组件**

把发送邮件 + 输入验证码 + 重置 3 步流程，改为单页提示：

```vue
<template>
  <div class="forgot-password">
    <h2>{{ $t('login.forgotPassword.title') }}</h2>
    <p>{{ $t('login.forgotPassword.contactAdmin') }}</p>
    <el-button type="primary" @click="$router.push('/login')">
      {{ $t('login.backToLogin') }}
    </el-button>
  </div>
</template>
<script setup lang="ts"></script>
```

把对应 i18n key 加进 `ui/src/locales/lang/zh-CN.ts`、`en-US.ts`、`zh-Hant.ts`：

```ts
forgotPassword: {
  title: '找回密码',
  contactAdmin: '当前部署未启用邮件找回功能，请联系管理员重置密码。',
}
```

英语：`'Email password recovery is disabled in this deployment. Please contact your administrator.'`

繁中：`'目前部署未啟用郵件找回功能，請聯絡管理員重設密碼。'`

- [ ] **Step 3: 重新构建前端验证**

```bash
cd ui && npm run build && ls -la dist/index.html
cd ..
```

Expected: dist 重新生成，文件大小有变化。

- [ ] **Step 4: 提交**

```bash
git add ui/src/views/login/ ui/src/locales/
git commit -m "feat(ui): replace email-based forgot-password flow with admin reset prompt"
```

### Task 2.4: Phase 2 冒烟回归

- [ ] **Step 1: 重建并启动**

```bash
docker build -f installer/Dockerfile -t maxkb-local:phase2 .
docker rm -f maxkb-phase2 2>/dev/null
docker run -d --name maxkb-phase2 -p 18082:8080 maxkb-local:phase2
sleep 60
```

- [ ] **Step 2: 走冒烟流程**

依然按 baseline.md 4 步走通；额外验证：
- 找回密码页显示"请联系管理员"
- `POST /admin/api/user/send_email` 返回错误
- 用 admin 账号调 `/admin/api/user/admin_reset_password` 重置普通用户密码成功

- [ ] **Step 3: 在 baseline.md 追加 phase2 记录**

```bash
git add docs/superpowers/plans/baseline.md
git commit -m "docs: phase 2 smoke regression notes"
```

---

## Phase 3 — Provider 懒加载与依赖切分

把 21 个 provider 的 eager import 换成按白名单懒加载，保持 `ModelProvideConstants[provider].value` 与 `ModelProvideConstants.__members__` 调用语义不变。

### Task 3.1: OpenAI provider embedding 维度改为可输入

**Files:**
- Modify: `apps/models_provider/impl/openai_model_provider/credential/embedding.py:19-35`

- [ ] **Step 1: 阅读现状**

`OpenAIEmbeddingModelParams.dimensions` 是 `forms.SingleSelect`，固定 4 档（1536/1024/768/512）。

- [ ] **Step 2: 改成可输入整数**

```python
class OpenAIEmbeddingModelParams(BaseForm):
    dimensions = forms.TextInputField(
        TooltipLabel(
            _('Dimensions'),
            _('Vector dimensions returned by the embedding model. Leave 0 to use server default.')
        ),
        required=False,
        default_value='0',
    )
```

如果 `forms.TextInputField` 不支持 default_value 类型为字符串"0"，先 grep 确认 forms 的 IntField 能力：

```bash
grep -n 'class TextInputField\|class IntField\|class IntegerInputField' apps/common/forms/*.py
```

按实际类型替换。

- [ ] **Step 3: 验证非默认维度可保存**

```bash
python apps/manage.py shell <<'EOF'
from models_provider.impl.openai_model_provider.credential.embedding import OpenAIEmbeddingModelParams
form = OpenAIEmbeddingModelParams()
print(form.to_form_list())
EOF
```

Expected: dimensions 字段输出 type 为 input/text，不是 single-select。

- [ ] **Step 4: 提交**

```bash
git add apps/models_provider/impl/openai_model_provider/credential/embedding.py
git commit -m "feat(models): OpenAI provider embedding dimensions free-input for third-party endpoints"
```

### Task 3.2: 更新 OpenAI provider API URL 文案与默认值

**Files:**
- Modify: `apps/models_provider/impl/openai_model_provider/credential/llm.py:75-76`
- Modify: `apps/models_provider/impl/openai_model_provider/credential/embedding.py:73-74`
- Modify: 其他 4 个同 provider 下的 credential 文件 (image.py / stt.py / tts.py / tti.py)

- [ ] **Step 1: 全局替换**

逐个打开 6 个 credential 文件，把：

```python
api_base = forms.TextInputField('API URL', required=True)
```

替换为：

```python
api_base = forms.TextInputField(
    TooltipLabel(_('API URL'),
                 _('Custom OpenAI-compatible base URL. Leave empty to use OpenAI official.')),
    required=True,
    default_value='https://api.openai.com/v1',
)
```

确保每个文件已经 import 了 `TooltipLabel`（grep 顶部 imports，缺失则补）。

- [ ] **Step 2: 重启后端，前端打开模型新增表单确认提示更新**

不写自动化校验。手测一次。

- [ ] **Step 3: 提交**

```bash
git add apps/models_provider/impl/openai_model_provider/credential/
git commit -m "feat(models): annotate OpenAI provider api_base as customizable for compatible endpoints"
```

### Task 3.3: 新增 ProviderRegistry 兼容层

**Files:**
- Create: `apps/models_provider/registry.py`

- [ ] **Step 1: 写注册表**

写入 `apps/models_provider/registry.py`：

```python
"""
Provider 懒加载注册表。

兼容旧 ModelProvideConstants[name].value 与 ModelProvideConstants.__members__ 的访问形态。
真实加载时机：第一次按 name 取值或迭代成员。
"""
import importlib
import os
import threading
from typing import Dict, Iterable, Tuple


# (key) -> (module path, class name)
_PROVIDER_PATHS: Dict[str, Tuple[str, str]] = {
    'model_azure_provider':
        ('models_provider.impl.azure_model_provider.azure_model_provider', 'AzureModelProvider'),
    'model_wenxin_provider':
        ('models_provider.impl.wenxin_model_provider.wenxin_model_provider', 'WenxinModelProvider'),
    'model_ollama_provider':
        ('models_provider.impl.ollama_model_provider.ollama_model_provider', 'OllamaModelProvider'),
    'model_openai_provider':
        ('models_provider.impl.openai_model_provider.openai_model_provider', 'OpenAIModelProvider'),
    'model_docker_ai_provider':
        ('models_provider.impl.docker_ai_model_provider.docker_ai_model_provider', 'DockerModelProvider'),
    'model_kimi_provider':
        ('models_provider.impl.kimi_model_provider.kimi_model_provider', 'KimiModelProvider'),
    'model_zhipu_provider':
        ('models_provider.impl.zhipu_model_provider.zhipu_model_provider', 'ZhiPuModelProvider'),
    'model_xf_provider':
        ('models_provider.impl.xf_model_provider.xf_model_provider', 'XunFeiModelProvider'),
    'model_deepseek_provider':
        ('models_provider.impl.deepseek_model_provider.deepseek_model_provider', 'DeepSeekModelProvider'),
    'model_gemini_provider':
        ('models_provider.impl.gemini_model_provider.gemini_model_provider', 'GeminiModelProvider'),
    'model_volcanic_engine_provider':
        ('models_provider.impl.volcanic_engine_model_provider.volcanic_engine_model_provider', 'VolcanicEngineModelProvider'),
    'model_tencent_provider':
        ('models_provider.impl.tencent_model_provider.tencent_model_provider', 'TencentModelProvider'),
    'model_tencent_cloud_provider':
        ('models_provider.impl.tencent_cloud_model_provider.tencent_cloud_model_provider', 'TencentCloudModelProvider'),
    'model_aws_bedrock_provider':
        ('models_provider.impl.aws_bedrock_model_provider.aws_bedrock_model_provider', 'BedrockModelProvider'),
    'model_local_provider':
        ('models_provider.impl.local_model_provider.local_model_provider', 'LocalModelProvider'),
    'model_xinference_provider':
        ('models_provider.impl.xinference_model_provider.xinference_model_provider', 'XinferenceModelProvider'),
    'model_vllm_provider':
        ('models_provider.impl.vllm_model_provider.vllm_model_provider', 'VllmModelProvider'),
    'aliyun_bai_lian_model_provider':
        ('models_provider.impl.aliyun_bai_lian_model_provider.aliyun_bai_lian_model_provider', 'AliyunBaiLianModelProvider'),
    'model_anthropic_provider':
        ('models_provider.impl.anthropic_model_provider.anthropic_model_provider', 'AnthropicModelProvider'),
    'model_siliconCloud_provider':
        ('models_provider.impl.siliconCloud_model_provider.siliconCloud_model_provider', 'SiliconCloudModelProvider'),
    'model_regolo_provider':
        ('models_provider.impl.regolo_model_provider.regolo_model_provider', 'RegoloModelProvider'),
}

_DEFAULT_ENABLED = ['model_openai_provider',
                    'model_anthropic_provider',
                    'model_siliconCloud_provider']

_lock = threading.Lock()


def _enabled_keys() -> list:
    raw = os.environ.get('MAXKB_ENABLED_PROVIDERS')
    if not raw:
        return list(_PROVIDER_PATHS.keys())  # 兼容默认：全开
    keys = [k.strip() for k in raw.split(',') if k.strip()]
    unknown = [k for k in keys if k not in _PROVIDER_PATHS]
    if unknown:
        from common.utils.logger import maxkb_logger
        maxkb_logger.warning(f'Unknown provider keys ignored: {unknown}')
    return [k for k in keys if k in _PROVIDER_PATHS]


class _Member:
    __slots__ = ('name', '_value')

    def __init__(self, name: str):
        self.name = name
        self._value = None

    @property
    def value(self):
        if self._value is None:
            with _lock:
                if self._value is None:
                    module_path, class_name = _PROVIDER_PATHS[self.name]
                    cls = getattr(importlib.import_module(module_path), class_name)
                    self._value = cls()
        return self._value


class _Registry:
    def __init__(self):
        self._members = None

    def _ensure(self):
        if self._members is None:
            with _lock:
                if self._members is None:
                    self._members = {k: _Member(k) for k in _enabled_keys()}

    @property
    def __members__(self) -> Dict[str, _Member]:
        self._ensure()
        return self._members

    def __getitem__(self, key: str) -> _Member:
        self._ensure()
        if key not in self._members:
            raise KeyError(f'Provider {key} is not enabled (MAXKB_ENABLED_PROVIDERS).')
        return self._members[key]

    def __iter__(self) -> Iterable[_Member]:
        self._ensure()
        return iter(self._members.values())

    def __contains__(self, key: str) -> bool:
        self._ensure()
        return key in self._members


ModelProvideConstants = _Registry()
```

- [ ] **Step 2: 单元验证（不需要 pytest，shell 即可）**

```bash
MAXKB_ENABLED_PROVIDERS=model_openai_provider,model_anthropic_provider \
python apps/manage.py shell <<'EOF'
from models_provider.registry import ModelProvideConstants
print('members:', list(ModelProvideConstants.__members__.keys()))
print('openai:', ModelProvideConstants['model_openai_provider'].value)
try:
    ModelProvideConstants['model_kimi_provider'].value
except KeyError as e:
    print('correctly rejected:', e)
EOF
```

Expected: 列出 2 个 member、openai 实例打印、拒绝 kimi。

- [ ] **Step 3: 提交**

```bash
git add apps/models_provider/registry.py
git commit -m "feat(models): introduce lazy ProviderRegistry compatible with old Enum API"
```

### Task 3.4: 切换 ModelProvideConstants 到懒加载注册表

**Files:**
- Rewrite: `apps/models_provider/constants/model_provider_constants.py`

- [ ] **Step 1: 替换文件全文**

```python
"""
保留原导入路径，实际转发给 models_provider.registry。
旧代码路径 from models_provider.constants.model_provider_constants import ModelProvideConstants 仍然可用。
"""
from models_provider.registry import ModelProvideConstants  # noqa: F401
```

21 个 eager import 全部删除。

- [ ] **Step 2: 验证调用方不报错**

```bash
python apps/manage.py shell <<'EOF'
from models_provider.constants.model_provider_constants import ModelProvideConstants
print(list(ModelProvideConstants.__members__.keys())[:3])
print(ModelProvideConstants['model_openai_provider'].value)
EOF
```

Expected: 输出至少 3 个 key，并打印 openai provider 实例。

- [ ] **Step 3: 启动 web 进程冒烟**

```bash
python apps/manage.py runserver 0.0.0.0:18083 &
sleep 8
curl -s http://127.0.0.1:18083/admin/api/provider/list 2>&1 | head -c 200
kill %1
```

Expected: 返回 JSON 列表，无 ImportError / AttributeError。

- [ ] **Step 4: 提交**

```bash
git add apps/models_provider/constants/model_provider_constants.py
git commit -m "refactor(models): switch ModelProvideConstants to lazy registry"
```

### Task 3.5: 默认 provider 收敛到 OpenAI + Anthropic + SiliconFlow

**Files:**
- Modify: `apps/models_provider/registry.py`

- [ ] **Step 1: 把"未配置则全开"改为"未配置则用 _DEFAULT_ENABLED"**

修改 `_enabled_keys`：

```python
def _enabled_keys() -> list:
    raw = os.environ.get('MAXKB_ENABLED_PROVIDERS')
    if not raw:
        return list(_DEFAULT_ENABLED)
    keys = [k.strip() for k in raw.split(',') if k.strip()]
    if keys == ['all'] or keys == ['*']:
        return list(_PROVIDER_PATHS.keys())
    unknown = [k for k in keys if k not in _PROVIDER_PATHS]
    if unknown:
        from common.utils.logger import maxkb_logger
        maxkb_logger.warning(f'Unknown provider keys ignored: {unknown}')
    return [k for k in keys if k in _PROVIDER_PATHS]
```

约定：
- 不设置环境变量 → 默认 3 个 provider
- `MAXKB_ENABLED_PROVIDERS=all` → 全部
- 显式列名单 → 只启用名单内的

- [ ] **Step 2: 验证三种行为**

```bash
unset MAXKB_ENABLED_PROVIDERS
python -c "from models_provider.registry import ModelProvideConstants; print(list(ModelProvideConstants.__members__.keys()))"

MAXKB_ENABLED_PROVIDERS=all python -c "from models_provider.registry import ModelProvideConstants; print(len(list(ModelProvideConstants.__members__.keys())))"

MAXKB_ENABLED_PROVIDERS=model_openai_provider python -c "from models_provider.registry import ModelProvideConstants; print(list(ModelProvideConstants.__members__.keys()))"
```

Expected:
- 默认 3 项
- `all` 显示 21 项
- 显式列单项时只 1 项

- [ ] **Step 3: 提交**

```bash
git add apps/models_provider/registry.py
git commit -m "feat(models): default provider whitelist to openai+anthropic+siliconflow"
```

### Task 3.6: pyproject.toml 拆分 optional-dependencies

**Files:**
- Modify: `pyproject.toml`

- [ ] **Step 1: 重写依赖**

把 `dependencies` 数组拆为"core"必装 + 三组可选：

```toml
[project]
name = "maxkb"
version = "2.0.0"
description = "强大易用的开源企业级智能体平台"
authors = [{ name = "shaohuzhang1", email = "shaohu.zhang@fit2cloud.com" }]
requires-python = "~=3.11.0"
readme = "README.md"
dependencies = [
    "django==5.2.13",
    "drf-spectacular[sidecar]==0.28.0",
    "django-redis==6.0.0",
    "django-db-connection-pool==1.2.6",
    "django-mptt==0.17.0",
    "psycopg[binary]==3.2.9",
    "python-dotenv==1.1.1",
    "uuid-utils==0.14.0",
    "captcha==0.7.1",
    "pytz==2025.2",
    "psutil==7.0.0",
    "cffi==1.17.1",
    "beautifulsoup4==4.13.4",
    "jieba==0.42.1",
    "langchain==1.2.15",
    "langchain-openai==1.1.12",
    "langchain-anthropic==1.4.0",
    "langchain-community==0.4.1",
    "langchain-mcp-adapters==0.2.2",
    "langgraph==1.1.6",
    "deepagents==0.4.12",
    "numpy==1.26.4",
    "celery[sqlalchemy]==5.5.3",
    "django-celery-beat==2.8.1",
    "celery-once==3.0.1",
    "django-apscheduler==0.7.0",
    "html2text==2025.4.15",
    "openpyxl==3.1.5",
    "python-docx==1.2.0",
    "xlrd==2.0.2",
    "xlwt==1.3.0",
    "pymupdf==1.26.3",
    "pypdf==6.10.0",
    "gunicorn==23.0.0",
    "python-daemon==3.1.2",
    "websockets==15.0.1",
    "pylint==3.3.7",
    "jsonpath-ng==1.8.0",
    "anthropic==0.89.0",
]

[project.optional-dependencies]
local-model = [
    "torch==2.8.0",
    "sentence-transformers==5.0.0",
    "langchain-huggingface==1.2.1",
]

multimodal = [
    "pydub==0.25.1",
    "pysilk==0.0.1",
]

providers-cn = [
    "dashscope==1.25.7",
    "qianfan==0.4.12.3",
    "zhipuai==2.1.5.20250708",
    "tencentcloud-sdk-python==3.0.1420",
    "volcengine-python-sdk[ark]==4.0.5",
    "langchain-deepseek==1.0.1",
]

providers-extras = [
    "boto3==1.42.46",
    "langchain-aws==1.4.3",
    "langchain-google-genai==4.2.1",
    "langchain-ollama==1.1.0",
    "xinference-client==1.7.1.post1",
    "cohere==5.17.0",
]

tools = [
    "pymysql",
    "psycopg2-binary",
]
```

- [ ] **Step 2: 同步 Dockerfile 安装命令**

把 `installer/Dockerfile:19` 的：

```dockerfile
python -m uv pip install -r pyproject.toml
```

改为（保留 all-in-one 兼容，默认装全集）：

```dockerfile
python -m uv pip install ".[local-model,multimodal,providers-cn,providers-extras,tools]"
```

注意：uv 0.4+ 支持 `pip install` 接 extras 路径，确认本地 uv 版本：

```bash
docker run --rm ghcr.io/1panel-dev/maxkb-base:python3.11-pg17.9-20260326 pip install --upgrade uv && uv --version
```

如果 uv 不支持 extras 语法，改为：

```dockerfile
python -m uv pip install -e ".[local-model,multimodal,providers-cn,providers-extras,tools]"
```

- [ ] **Step 3: 重建 all-in-one 镜像验证**

```bash
docker build -f installer/Dockerfile -t maxkb-local:phase3 .
docker run --rm maxkb-local:phase3 python -c "import torch, sentence_transformers, dashscope; print('ok')"
```

Expected: `ok`

- [ ] **Step 4: 提交**

```bash
git add pyproject.toml installer/Dockerfile
git commit -m "build: split deps into core + optional extras (local-model/multimodal/providers-cn/providers-extras/tools)"
```

### Task 3.7: Phase 3 冒烟回归

- [ ] **Step 1: 启动镜像并验证默认 provider 列表**

```bash
docker rm -f maxkb-phase3 2>/dev/null
docker run -d --name maxkb-phase3 -p 18084:8080 \
  -e MAXKB_ENABLED_PROVIDERS=all \
  maxkb-local:phase3
sleep 60
curl -s http://127.0.0.1:18084/admin/api/provider/list -H "Authorization: anon" | head -c 500
```

Expected: 返回所有 21 个 provider。

- [ ] **Step 2: 切换到默认白名单**

```bash
docker rm -f maxkb-phase3
docker run -d --name maxkb-phase3 -p 18084:8080 maxkb-local:phase3
sleep 60
curl -s http://127.0.0.1:18084/admin/api/provider/list -H "Authorization: anon"
```

Expected: 只有 3 个 provider（openai / anthropic / silicon）。

- [ ] **Step 3: 走冒烟流程（用 OpenAI provider 接 OpenAI 官方或自部署 OpenAI 兼容端点）**

完成 baseline.md 4 步。

- [ ] **Step 4: 在 baseline.md 追加 phase3 记录并提交**

```bash
git add docs/superpowers/plans/baseline.md
git commit -m "docs: phase 3 smoke regression notes"
```

---

## Phase 4 — 镜像与前端拆分

新增 `app-only` 镜像（不带 PG/Redis/前端），新增 `ui` 镜像（nginx + 前端 dist），新增 `docker-compose.split.yml`。**保留原 all-in-one 镜像不动**。

### Task 4.1: 增加 MAXKB_ENABLE_UI 开关

**Files:**
- Modify: `apps/maxkb/conf.py`
- Modify: `apps/maxkb/urls/web.py:78-141`

- [ ] **Step 1: 在 conf.py 新增 getter**

```python
def get_enable_ui(self):
    val = self.get('ENABLE_UI')
    if val is None:
        return True  # 默认开启，兼容 all-in-one
    return str(val).lower() in ('1', 'true', 'yes', 'on')
```

- [ ] **Step 2: 包裹 pro() 与 handler404 的静态文件部分**

打开 `apps/maxkb/urls/web.py`，把 78-79 行的：

```python
if not settings.DEBUG:
    pro()
```

改为：

```python
if not settings.DEBUG and CONFIG.get_enable_ui():
    pro()
```

把 105-137 行的 `page_not_found` 函数，整体包到一个 enable_ui 判断里：

```python
def page_not_found(request, exception):
    if not CONFIG.get_enable_ui():
        from rest_framework import status as drf_status
        return Result(response_status=drf_status.HTTP_404_NOT_FOUND, code=404, message="HTTP_404_NOT_FOUND")
    # 以下为原有逻辑
    if request.path.startswith(admin_ui_prefix + '/api/'):
        return Result(response_status=status.HTTP_404_NOT_FOUND, code=404, message="HTTP_404_NOT_FOUND")
    ...
```

- [ ] **Step 3: 验证 enable_ui=False 时 / 路径返回纯 JSON 404**

```bash
MAXKB_ENABLE_UI=false python apps/manage.py runserver 0.0.0.0:18085 &
sleep 5
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18085/some-random-path
kill %1
```

Expected: `404`，且响应体是 JSON 不是 HTML。

- [ ] **Step 4: 提交**

```bash
git add apps/maxkb/conf.py apps/maxkb/urls/web.py
git commit -m "feat: add MAXKB_ENABLE_UI switch to skip frontend static handling"
```

### Task 4.2: 新建 Dockerfile.app-only

**Files:**
- Create: `installer/Dockerfile.app-only`

- [ ] **Step 1: 写 Dockerfile.app-only**

```dockerfile
# app-only: backend + Python runtime only. No PG, no Redis, no frontend, no model files.
FROM python:3.11-slim-trixie AS stage-build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc g++ gettext libexpat1-dev libffi-dev \
        ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/maxkb-app
COPY --chmod=700 . /opt/maxkb-app

# Compile sandbox.so (LD_PRELOAD-based syscall filter for tool execution)
ENV MAXKB_SANDBOX_HOME=/opt/maxkb-app/sandbox
RUN mkdir -p ${MAXKB_SANDBOX_HOME}/lib && \
    gcc -shared -fPIC -o ${MAXKB_SANDBOX_HOME}/lib/sandbox.so \
        /opt/maxkb-app/installer/sandbox.c -ldl

# Install Python deps WITHOUT local-model extra by default
RUN pip install uv --break-system-packages && \
    python -m uv pip install ".[multimodal,providers-cn,providers-extras,tools]" && \
    find /opt/maxkb-app -depth \
         \( -name ".git*" -o -name ".docker*" -o -name ".idea*" \
            -o -name ".editorconfig*" -o -name ".prettierrc*" \) \
         -exec rm -rf {} + && \
    python /opt/maxkb-app/apps/manage.py compilemessages && \
    rm -rf /opt/maxkb-app/ui /opt/maxkb-app/installer

FROM python:3.11-slim-trixie

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libexpat1 libffi8 libpq5 ca-certificates wait-for-it && \
    rm -rf /var/lib/apt/lists/*

ARG DOCKER_IMAGE_TAG=dev \
    BUILD_AT \
    GITHUB_COMMIT
ENV MAXKB_VERSION="${DOCKER_IMAGE_TAG} (build at ${BUILD_AT}, commit: ${GITHUB_COMMIT})" \
    MAXKB_CONFIG_TYPE=ENV \
    MAXKB_LOG_LEVEL=INFO \
    MAXKB_ENABLE_UI=false \
    MAXKB_ENABLE_API_DOCS=false \
    MAXKB_ENABLE_EMAIL=false \
    MAXKB_SANDBOX=1 \
    MAXKB_SANDBOX_HOME=/opt/maxkb-app/sandbox \
    MAXKB_SANDBOX_PYTHON_BANNED_HOSTS="127.0.0.0/8,localhost,169.254.0.0/16,::1/128" \
    PYTHONUNBUFFERED=1 \
    PIP_TARGET=/opt/maxkb/python-packages \
    PATH=/usr/local/bin:$PATH

WORKDIR /opt/maxkb-app
COPY --from=stage-build /opt/maxkb-app /opt/maxkb-app
COPY --from=stage-build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

EXPOSE 8080
VOLUME /opt/maxkb

ENTRYPOINT ["python", "/opt/maxkb-app/main.py"]
CMD ["start", "web"]
```

- [ ] **Step 2: 构建并验证大小**

```bash
docker build -f installer/Dockerfile.app-only -t maxkb-app:test .
docker images maxkb-app:test --format '{{.Size}}'
```

Expected: 镜像大小 1–2 GB（vs all-in-one 6–10 GB）。

- [ ] **Step 3: 验证启动需要外部 PG/Redis**

```bash
docker run --rm maxkb-app:test python /opt/maxkb-app/main.py upgrade_db 2>&1 | head -10
```

Expected: 报数据库连接失败（因为没有外部 PG），不报 ImportError 等启动期错误。

- [ ] **Step 4: 提交**

```bash
git add installer/Dockerfile.app-only
git commit -m "build: add app-only Dockerfile (backend + sandbox, no PG/Redis/UI/local-model)"
```

### Task 4.3: 新建 Dockerfile.ui

**Files:**
- Create: `installer/Dockerfile.ui`
- Create: `installer/nginx.ui.conf`

- [ ] **Step 1: 写 Dockerfile.ui**

```dockerfile
FROM node:24-alpine AS web-build
WORKDIR /build
COPY ui/package.json ui/package-lock.json* ./ui/
WORKDIR /build/ui
RUN npm ci --prefer-offline --no-audit
COPY ui /build/ui
RUN NODE_OPTIONS="--max-old-space-size=4096" \
    npx concurrently --kill-others-on-fail "npm run build" "npm run build-chat"

FROM nginx:1.27-alpine
COPY --from=web-build /build/ui/dist /usr/share/nginx/html/admin
COPY --from=web-build /build/ui/dist-chat /usr/share/nginx/html/chat
COPY installer/nginx.ui.conf /etc/nginx/conf.d/default.conf

ENV MAXKB_API_UPSTREAM=http://maxkb-app:8080

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

- [ ] **Step 2: 写 nginx.ui.conf**

```nginx
server {
    listen 80 default_server;
    server_name _;
    client_max_body_size 100m;

    location /admin/api/ {
        proxy_pass http://maxkb-app:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 300s;
    }

    location /chat/api/ {
        proxy_pass http://maxkb-app:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 300s;
    }

    location /admin/ {
        alias /usr/share/nginx/html/admin/;
        try_files $uri $uri/ /admin/index.html;
    }

    location /chat/ {
        alias /usr/share/nginx/html/chat/;
        try_files $uri $uri/ /chat/index.html;
    }

    location = / {
        return 301 /admin/;
    }
}
```

- [ ] **Step 3: 检查 ui 构建产出目录名**

```bash
grep -n 'outDir\|build:' ui/vite.config.ts ui/package.json
```

如果 `build-chat` 输出不是 `dist-chat` 而是 `dist/chat` 或别的，按真实目录名替换 Dockerfile.ui 第 9 行的路径。

- [ ] **Step 4: 构建并跑空容器验证 nginx 配置**

```bash
docker build -f installer/Dockerfile.ui -t maxkb-ui:test .
docker run --rm -d --name maxkb-ui-test -p 18086:80 maxkb-ui:test
sleep 3
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18086/admin/
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18086/chat/
docker rm -f maxkb-ui-test
```

Expected: 两个 200。

- [ ] **Step 5: 提交**

```bash
git add installer/Dockerfile.ui installer/nginx.ui.conf
git commit -m "build: add standalone UI image (nginx + admin + chat dist)"
```

### Task 4.4: 新建 docker-compose.split.yml

**Files:**
- Create: `installer/docker-compose.split.yml`
- Create: `installer/.env.split.example`

- [ ] **Step 1: 写 .env.split.example**

```env
# Postgres
POSTGRES_USER=maxkb
POSTGRES_PASSWORD=ChangeMe_Pg_123
POSTGRES_DB=maxkb

# Redis
REDIS_PASSWORD=ChangeMe_Redis_123

# MaxKB
MAXKB_DJANGO_SECRET_KEY=ChangeMe_Secret_64bytes_random
MAXKB_ENABLED_PROVIDERS=model_openai_provider,model_anthropic_provider,model_siliconCloud_provider
MAXKB_ENABLE_API_DOCS=false
MAXKB_ENABLE_EMAIL=false

# Public URL (used by nginx)
MAXKB_PUBLIC_PORT=8080
```

- [ ] **Step 2: 写 docker-compose.split.yml**

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg17
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 10

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 10

  maxkb-app:
    image: maxkb-app:latest
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      MAXKB_DB_HOST: postgres
      MAXKB_DB_PORT: 5432
      MAXKB_DB_USER: ${POSTGRES_USER}
      MAXKB_DB_PASSWORD: ${POSTGRES_PASSWORD}
      MAXKB_DB_NAME: ${POSTGRES_DB}
      MAXKB_REDIS_HOST: redis
      MAXKB_REDIS_PORT: 6379
      MAXKB_REDIS_PASSWORD: ${REDIS_PASSWORD}
      MAXKB_REDIS_DB: 0
      MAXKB_ENABLE_UI: "false"
      MAXKB_ENABLE_API_DOCS: ${MAXKB_ENABLE_API_DOCS:-false}
      MAXKB_ENABLE_EMAIL: ${MAXKB_ENABLE_EMAIL:-false}
      MAXKB_ENABLE_SCHEDULER: "true"
      MAXKB_ENABLED_PROVIDERS: ${MAXKB_ENABLED_PROVIDERS}
      MAXKB_SECRET_KEY: ${MAXKB_DJANGO_SECRET_KEY}
    command: ["start", "web"]
    volumes:
      - maxkb-data:/opt/maxkb

  maxkb-worker:
    image: maxkb-app:latest
    restart: unless-stopped
    depends_on:
      maxkb-app:
        condition: service_started
    environment:
      MAXKB_DB_HOST: postgres
      MAXKB_DB_PORT: 5432
      MAXKB_DB_USER: ${POSTGRES_USER}
      MAXKB_DB_PASSWORD: ${POSTGRES_PASSWORD}
      MAXKB_DB_NAME: ${POSTGRES_DB}
      MAXKB_REDIS_HOST: redis
      MAXKB_REDIS_PORT: 6379
      MAXKB_REDIS_PASSWORD: ${REDIS_PASSWORD}
      MAXKB_REDIS_DB: 0
      MAXKB_ENABLE_UI: "false"
      MAXKB_ENABLE_SCHEDULER: "false"
      MAXKB_ENABLED_PROVIDERS: ${MAXKB_ENABLED_PROVIDERS}
      MAXKB_SECRET_KEY: ${MAXKB_DJANGO_SECRET_KEY}
      SERVER_NAME: celery
    # 通过 Django manage.py 启动；main.py 不识别 task 之外的细分 service
    command: ["python", "/opt/maxkb-app/apps/manage.py", "start", "task"]
    volumes:
      - maxkb-data:/opt/maxkb

  maxkb-ui:
    image: maxkb-ui:latest
    restart: unless-stopped
    depends_on:
      - maxkb-app
    ports:
      - "${MAXKB_PUBLIC_PORT:-8080}:80"

volumes:
  pgdata:
  maxkb-data:
```

- [ ] **Step 3: 端到端验证**

```bash
cd installer
cp .env.split.example .env.split
docker build -f Dockerfile.app-only -t maxkb-app:latest ..
docker build -f Dockerfile.ui -t maxkb-ui:latest ..
docker compose --env-file .env.split -f docker-compose.split.yml up -d
sleep 90
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/admin/
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/admin/api/profile
docker compose --env-file .env.split -f docker-compose.split.yml ps
```

Expected: 两个 curl 都拿到 200，所有 4 个服务 healthy/running。

- [ ] **Step 4: 走 baseline.md 4 步冒烟**

通过 `http://127.0.0.1:8080/admin/` 登录 → 建库 → 上传 → 命中 → 对话。

- [ ] **Step 5: 清理并提交**

```bash
docker compose --env-file .env.split -f docker-compose.split.yml down -v
git add installer/docker-compose.split.yml installer/.env.split.example
git commit -m "build: add split docker-compose template (app/worker/ui/postgres/redis)"
```

### Task 4.5: Phase 4 冒烟回归

- [ ] **Step 1: 验证 all-in-one 仍可启动**

```bash
docker build -f installer/Dockerfile -t maxkb-local:phase4 .
docker rm -f maxkb-phase4 2>/dev/null
docker run -d --name maxkb-phase4 -p 18087:8080 maxkb-local:phase4
sleep 60
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18087/admin/
docker logs --tail 30 maxkb-phase4 | grep -i error || echo "no errors"
```

Expected: 200，"no errors"

- [ ] **Step 2: 在 baseline.md 追加 phase4 记录并提交**

```bash
git add docs/superpowers/plans/baseline.md
git commit -m "docs: phase 4 smoke regression notes"
```

---

## Phase 5 — Celery 队列拆分

把单一 `celery` 队列拆为 `rag_parse / rag_embedding / rag_index / chat / workflow / tool / multimodal / maintenance`。每个 task 默认仍走兼容 queue，新增 `MAXKB_TASK_QUEUE_PREFIX` 控制路由前缀。

### Task 5.1: 增加 task-routing 配置

**Files:**
- Create: `apps/ops/celery/routing.py`
- Modify: `apps/ops/celery/__init__.py`

- [ ] **Step 1: 写 routing.py**

```python
"""
Celery 任务到队列的映射表。
任务名 prefix（celery_app.task 中 name= 字段的前缀）-> 队列名。
未匹配的回落到默认 'celery' 队列，兼容老部署。
"""
import os

# 任务名前缀 -> 队列后缀
TASK_NAME_PREFIX_TO_QUEUE = {
    'celery:embedding_': 'rag_embedding',
    'celery:sync_web_': 'rag_parse',
    'celery:generate_related_': 'rag_embedding',
    'celery:create_knowledge_index': 'rag_index',
    'celery:drop_knowledge_index': 'rag_index',
    'celery:deploy_scheduled_trigger': 'maintenance',
    'celery:undeploy_scheduled_trigger': 'maintenance',
}

DEFAULT_QUEUE = 'celery'

QUEUE_KEYS = sorted(set(TASK_NAME_PREFIX_TO_QUEUE.values())) + [DEFAULT_QUEUE]


def queue_for_task(task_name: str) -> str:
    """
    给定任务名，返回它该进入的队列名。

    若 MAXKB_TASK_QUEUE_PREFIX 环境变量为空，强制返回 DEFAULT_QUEUE（兼容老部署）。
    若设置了前缀，按 TASK_NAME_PREFIX_TO_QUEUE 路由；否则回落 DEFAULT_QUEUE。
    """
    if not os.environ.get('MAXKB_TASK_QUEUE_PREFIX_ENABLED'):
        return DEFAULT_QUEUE
    for prefix, queue in TASK_NAME_PREFIX_TO_QUEUE.items():
        if task_name.startswith(prefix):
            return queue
    return DEFAULT_QUEUE


def task_router(name, args, kwargs, options, task=None, **kw):
    return {'queue': queue_for_task(name)}


def all_queues():
    return QUEUE_KEYS
```

- [ ] **Step 2: 在 celery init 注册 router 与 queue 列表**

把 `apps/ops/celery/__init__.py:24-27` 改为：

```python
from kombu import Exchange, Queue
from .routing import all_queues, task_router

configs["task_queues"] = [
    Queue(name, Exchange(name), routing_key=name) for name in all_queues()
]
configs["task_routes"] = (task_router,)
```

- [ ] **Step 3: 验证默认行为不变**

```bash
unset MAXKB_TASK_QUEUE_PREFIX_ENABLED
python -c "
from ops.celery.routing import queue_for_task
print(queue_for_task('celery:embedding_by_document'))
print(queue_for_task('celery:sync_web_knowledge'))
"
```

Expected: 两个都是 `celery`（默认禁用前缀，全走老队列）。

```bash
MAXKB_TASK_QUEUE_PREFIX_ENABLED=1 python -c "
from ops.celery.routing import queue_for_task
print(queue_for_task('celery:embedding_by_document'))
print(queue_for_task('celery:sync_web_knowledge'))
"
```

Expected: `rag_embedding`、`rag_parse`。

- [ ] **Step 4: 提交**

```bash
git add apps/ops/celery/routing.py apps/ops/celery/__init__.py
git commit -m "feat(celery): add task routing table behind MAXKB_TASK_QUEUE_PREFIX_ENABLED flag"
```

### Task 5.2: 新增按队列启动 worker 的 service 类

**Files:**
- Modify: `apps/common/management/commands/services/services/celery_default.py`
- Modify: `apps/common/management/commands/services/command.py`

- [ ] **Step 1: 把 CeleryDefaultService 改成可参数化 queue**

打开 `apps/common/management/commands/services/services/celery_default.py`，重写为支持自定义 queue：

```python
import os
import subprocess

from .celery_base import CeleryBaseService
from django.conf import settings

__all__ = ['CeleryDefaultService', 'CeleryQueueService']


class CeleryDefaultService(CeleryBaseService):
    def __init__(self, **kwargs):
        kwargs['queue'] = kwargs.get('queue', 'celery')
        super().__init__(**kwargs)

    def open_subprocess(self):
        env = os.environ.copy()
        env['LC_ALL'] = 'C.UTF-8'
        env['PYTHONOPTIMIZE'] = '1'
        env['ANSIBLE_FORCE_COLOR'] = 'True'
        env['PYTHONPATH'] = settings.APPS_DIR
        env['SERVER_NAME'] = 'celery'
        if os.getuid() == 0:
            env.setdefault('C_FORCE_ROOT', '1')
        kwargs = {
            'cwd': self.cwd,
            'stderr': self.log_file,
            'stdout': self.log_file,
            'env': env,
        }
        self._process = subprocess.Popen(self.cmd, **kwargs)


def make_queue_service(queue_name: str):
    """工厂函数：为给定队列名生成 service 类。"""
    cls = type(
        f'Celery_{queue_name}_Service',
        (CeleryDefaultService,),
        {
            '__init__': lambda self, **kwargs: CeleryDefaultService.__init__(
                self, **{**kwargs, 'queue': queue_name}
            )
        },
    )
    return cls
```

- [ ] **Step 2: 重写 command.py，按字符串名而不是 Enum 成员驱动 service**

由于 `TextChoices/Enum` 不能动态注入成员，把 `Services` 内部所有方法改为返回字符串列表，并相应改写 `get_service_objects`。整体替换 `apps/common/management/commands/services/command.py`：

```python
import math
import os

from django.core.management.base import BaseCommand
from django.db.models import TextChoices

from .utils import ServicesUtil
from ops.celery.routing import all_queues


class Services(TextChoices):
    gunicorn = 'gunicorn', 'gunicorn'
    celery_default = 'celery_default', 'celery_default'
    local_model = 'local_model', 'local_model'
    web = 'web', 'web'
    celery = 'celery', 'celery'
    task = 'task', 'task'
    all = 'all', 'all'

    @classmethod
    def get_service_object_class(cls, name):
        from . import services
        if name == cls.gunicorn.value:
            return services.GunicornService
        if name == cls.local_model.value:
            return services.GunicornLocalModelService
        if name == cls.celery_default.value:
            return services.CeleryDefaultService
        if name.startswith('celery_'):
            queue = name[len('celery_'):]
            if queue in all_queues():
                return services.make_queue_service(queue)
        return None

    @classmethod
    def web_services(cls):
        return [cls.gunicorn.value, cls.local_model.value]

    @classmethod
    def celery_services(cls):
        if os.environ.get('MAXKB_TASK_QUEUE_PREFIX_ENABLED'):
            return [f'celery_{q}' for q in all_queues()]
        return [cls.celery_default.value]

    @classmethod
    def task_services(cls):
        return cls.celery_services()

    @classmethod
    def all_services(cls):
        return cls.web_services() + cls.task_services()

    @classmethod
    def export_services_values(cls):
        per_queue = [f'celery_{q}' for q in all_queues()]
        base = [cls.all.value, cls.web.value, cls.task.value,
                cls.gunicorn.value, cls.celery_default.value, cls.local_model.value]
        # 去重保序
        seen = set()
        result = []
        for v in base + per_queue:
            if v not in seen:
                seen.add(v)
                result.append(v)
        return result

    @classmethod
    def get_service_objects(cls, service_names, **kwargs):
        # 一律以字符串 service-name 流转
        names = []
        seen = set()
        for raw in service_names:
            method_name = f'{raw}_services'
            if hasattr(cls, method_name):
                expanded = getattr(cls, method_name)()
            elif hasattr(cls, raw):
                expanded = [getattr(cls, raw).value]
            elif raw.startswith('celery_'):
                expanded = [raw]
            else:
                continue
            for n in expanded:
                if n in seen:
                    continue
                seen.add(n)
                names.append(n)

        service_objects = []
        for n in names:
            service_class = cls.get_service_object_class(n)
            if service_class is None:
                continue
            kwargs_with_name = {**kwargs, 'name': n}
            service_objects.append(service_class(**kwargs_with_name))
        return service_objects


class Action(TextChoices):
    start = 'start', 'start'
    status = 'status', 'status'
    stop = 'stop', 'stop'
    restart = 'restart', 'restart'


class BaseActionCommand(BaseCommand):
    help = 'Service Base Command'

    action = None
    util = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def add_arguments(self, parser):
        parser.add_argument(
            'services', nargs='+', choices=Services.export_services_values(), help='Service',
        )
        parser.add_argument('-d', '--daemon', nargs="?", const=True)
        parser.add_argument('-w', '--worker', type=int, nargs="?",
                            default=3 if os.cpu_count() > 6 else max(1, math.floor(os.cpu_count() / 2)))
        parser.add_argument('-f', '--force', nargs="?", const=True)

    def initial_util(self, *args, **options):
        service_names = options.get('services')
        service_kwargs = {
            'worker_gunicorn': options.get('worker')
        }
        services = Services.get_service_objects(service_names=service_names, **service_kwargs)

        kwargs = {
            'services': services,
            'run_daemon': options.get('daemon', False),
            'stop_daemon': self.action == Action.stop.value and Services.all.value in service_names,
            'force_stop': options.get('force') or False,
        }
        self.util = ServicesUtil(**kwargs)

    def handle(self, *args, **options):
        self.initial_util(*args, **options)
        assert self.action in Action.values, f'The action {self.action} is not in the optional list'
        _handle = getattr(self, f'_handle_{self.action}', lambda: None)
        _handle()

    def _handle_start(self):
        self.util.start_and_watch()
        os._exit(0)

    def _handle_stop(self):
        self.util.stop()

    def _handle_restart(self):
        self.util.restart()

    def _handle_status(self):
        self.util.show_status()
```

- [ ] **Step 3: 同步 services/__init__.py 导出**

```bash
grep -n 'CeleryDefaultService' apps/common/management/commands/services/services/__init__.py
```

确保有 `from .celery_default import CeleryDefaultService, make_queue_service`，不在则补。

- [ ] **Step 4: 验证未启用前缀时仍只起 1 个 worker**

```bash
unset MAXKB_TASK_QUEUE_PREFIX_ENABLED
python apps/manage.py start task --help 2>&1 | head -10
```

Expected: 列出 task 选项，没有 KeyError。

```bash
MAXKB_TASK_QUEUE_PREFIX_ENABLED=1 python apps/manage.py shell <<'EOF'
from common.management.commands.services.command import Services
print([s.value for s in Services.celery_services()])
EOF
```

Expected: 列出 `celery_rag_parse`、`celery_rag_embedding`、`celery_rag_index`、`celery_maintenance`、`celery_celery` 等多个。

- [ ] **Step 5: 提交**

```bash
git add apps/common/management/commands/services/
git commit -m "feat(celery): per-queue worker services launched when MAXKB_TASK_QUEUE_PREFIX_ENABLED=1"
```

### Task 5.3: 在 split compose 中起多 worker

**Files:**
- Modify: `installer/docker-compose.split.yml`

- [ ] **Step 1: 把单 worker 拆成 4 个 worker service**

替换原 `maxkb-worker` 块（一个）为 4 个：

```yaml
  maxkb-worker-rag:
    image: maxkb-app:latest
    restart: unless-stopped
    depends_on:
      maxkb-app:
        condition: service_started
    environment: &worker-env
      MAXKB_DB_HOST: postgres
      MAXKB_DB_PORT: 5432
      MAXKB_DB_USER: ${POSTGRES_USER}
      MAXKB_DB_PASSWORD: ${POSTGRES_PASSWORD}
      MAXKB_DB_NAME: ${POSTGRES_DB}
      MAXKB_REDIS_HOST: redis
      MAXKB_REDIS_PORT: 6379
      MAXKB_REDIS_PASSWORD: ${REDIS_PASSWORD}
      MAXKB_REDIS_DB: 0
      MAXKB_ENABLE_UI: "false"
      MAXKB_ENABLE_SCHEDULER: "false"
      MAXKB_TASK_QUEUE_PREFIX_ENABLED: "1"
      MAXKB_ENABLED_PROVIDERS: ${MAXKB_ENABLED_PROVIDERS}
      MAXKB_SECRET_KEY: ${MAXKB_DJANGO_SECRET_KEY}
      MAXKB_TMPDIR: /opt/maxkb-app/tmp
      SERVER_NAME: celery
    # 直接走 Django manage.py，绕过 main.py 的 services choices 限制（main.py:121 仅识别 all/web/task）
    entrypoint: ["python", "/opt/maxkb-app/apps/manage.py"]
    command: ["start", "celery_rag_parse", "celery_rag_embedding", "celery_rag_index"]
    volumes:
      - maxkb-data:/opt/maxkb

  maxkb-worker-default:
    image: maxkb-app:latest
    restart: unless-stopped
    depends_on:
      maxkb-app:
        condition: service_started
    environment: *worker-env
    entrypoint: ["python", "/opt/maxkb-app/apps/manage.py"]
    command: ["start", "celery_celery"]
    volumes:
      - maxkb-data:/opt/maxkb

  maxkb-worker-maintenance:
    image: maxkb-app:latest
    restart: unless-stopped
    depends_on:
      maxkb-app:
        condition: service_started
    environment:
      <<: *worker-env
      MAXKB_ENABLE_SCHEDULER: "true"
    entrypoint: ["python", "/opt/maxkb-app/apps/manage.py"]
    command: ["start", "celery_maintenance"]
    volumes:
      - maxkb-data:/opt/maxkb
```

**注意：** Phase 4 的 `maxkb-app` / `maxkb-worker` 仍走 main.py（CMD `start web` / `start task`），因为这两个名字在 `main.py:121` 的 choices 里。Phase 5 拆出来的细分队列名不在 main.py choices 内，所以这三个 worker 必须用 `entrypoint: ["python", ".../manage.py"]` 直接走 Django 命令。这样做还有一个副效益：跳过 main.py 的 `collect_static() + perform_db_migrate()`，**避免多个 worker 启动时同时跑 migrate 引发竞争**。

注意 `maxkb-worker-maintenance` 单独打开 `MAXKB_ENABLE_SCHEDULER=true`，**全集群只有这一个进程跑 apscheduler**。

同时让 `maxkb-app` 的 `MAXKB_ENABLE_SCHEDULER` 改为 `false`（避免重复）：

```yaml
  maxkb-app:
    ...
    environment:
      ...
      MAXKB_ENABLE_SCHEDULER: "false"
```

- [ ] **Step 2: 端到端验证**

```bash
cd installer
docker build -f Dockerfile.app-only -t maxkb-app:latest ..
docker compose --env-file .env.split -f docker-compose.split.yml up -d
sleep 90
docker compose --env-file .env.split -f docker-compose.split.yml ps
```

Expected: 6 个服务都 running（postgres, redis, maxkb-app, ui, worker-rag, worker-default, worker-maintenance）。

- [ ] **Step 3: 验证 worker 在消费指定队列**

```bash
docker exec -it $(docker ps -qf name=maxkb-worker-rag) celery -A ops inspect active_queues 2>&1 | grep -E 'rag_|name'
```

Expected: 看到 `rag_parse / rag_embedding / rag_index` 三个 queue 名。

- [ ] **Step 4: 走 baseline.md 4 步冒烟**

确保上传文档后 worker-rag 消费、对话经过 worker-default。

- [ ] **Step 5: 清理 + 提交**

```bash
docker compose --env-file .env.split -f docker-compose.split.yml down -v
git add installer/docker-compose.split.yml
git commit -m "build(compose): split worker into rag/default/maintenance with single scheduler"
```

### Task 5.4: Phase 5 冒烟回归

- [ ] **Step 1: 验证 all-in-one 默认未启用前缀，仍走单队列**

```bash
docker build -f installer/Dockerfile -t maxkb-local:phase5 .
docker rm -f maxkb-phase5 2>/dev/null
docker run -d --name maxkb-phase5 -p 18088:8080 maxkb-local:phase5
sleep 60
docker exec maxkb-phase5 ps -ef | grep '[c]elery'
```

Expected: 只有一个 `-Q celery` worker。

- [ ] **Step 2: 在 baseline.md 追加 phase5 记录并提交**

```bash
git add docs/superpowers/plans/baseline.md
git commit -m "docs: phase 5 smoke regression notes"
```

---

## Phase 6 — RAG 与数据库优化

加 workspace_id、加复合索引/GIN 索引、HNSW 阈值化与异步化、keyset 分页。

### Task 6.1: Embedding 表加 workspace_id 列与回填

**Files:**
- Modify: `apps/knowledge/models/knowledge.py:312-326`
- Create: `apps/knowledge/migrations/0009_embedding_workspace_id.py`

- [ ] **Step 1: 模型加字段（含 db_default 让 DB 层有持久 DEFAULT）**

打开 `apps/knowledge/models/knowledge.py`，把 `class Embedding` 改为：

```python
class Embedding(models.Model):
    id = models.CharField(max_length=128, primary_key=True, verbose_name="主键id")
    source_id = models.CharField(max_length=128, verbose_name="资源id", db_index=True)
    source_type = models.CharField(verbose_name='资源类型', max_length=5, choices=SourceType.choices,
                                   default=SourceType.PROBLEM, db_index=True)
    is_active = models.BooleanField(verbose_name="是否可用", max_length=1, default=True)
    # db_default 让 PostgreSQL 列上有持久 DEFAULT 'default'，旧版本 ORM 插入时也能落盘；
    # default 让 Django 在新代码 INSERT 时显式带值；两者并存是 Django 5.0+ 推荐写法。
    workspace_id = models.CharField(max_length=64, verbose_name="工作空间id",
                                    default="default", db_default="default", db_index=True)
    knowledge = models.ForeignKey(Knowledge, on_delete=models.DO_NOTHING, verbose_name="文档关联", db_constraint=False)
    document = models.ForeignKey(Document, on_delete=models.DO_NOTHING, verbose_name="文档关联", db_constraint=False)
    paragraph = models.ForeignKey(Paragraph, on_delete=models.DO_NOTHING, verbose_name="段落关联", db_constraint=False)
    embedding = VectorField(verbose_name="向量")
    search_vector = SearchVectorField(verbose_name="分词", default="")
    meta = models.JSONField(verbose_name="元数据", default=dict)

    class Meta:
        db_table = "embedding"
```

- [ ] **Step 2: 写 migration**

写入 `apps/knowledge/migrations/0009_embedding_workspace_id.py`：

```python
from django.db import migrations, models


def backfill_workspace_id(apps, schema_editor):
    """从 Knowledge 表回填到 Embedding。"""
    with schema_editor.connection.cursor() as c:
        c.execute("""
            UPDATE embedding
               SET workspace_id = COALESCE(k.workspace_id, 'default')
              FROM knowledge k
             WHERE embedding.knowledge_id = k.id
               AND (embedding.workspace_id IS NULL OR embedding.workspace_id = 'default')
        """)


class Migration(migrations.Migration):

    dependencies = [
        ('knowledge', '0008_file_sha256_index'),
    ]

    operations = [
        migrations.AddField(
            model_name='embedding',
            name='workspace_id',
            # db_default 让 PG 列层 DEFAULT 'default'，旧二进制不带 workspace_id 也能写
            field=models.CharField(default='default', db_default='default', max_length=64,
                                   db_index=True, verbose_name='工作空间id'),
        ),
        migrations.RunPython(backfill_workspace_id, reverse_code=migrations.RunPython.noop),
        # 双保险：即使将来 db_default 被 ORM 改写，也保证列上有 DEFAULT
        migrations.RunSQL(
            sql="ALTER TABLE embedding ALTER COLUMN workspace_id SET DEFAULT 'default'",
            reverse_sql="ALTER TABLE embedding ALTER COLUMN workspace_id DROP DEFAULT",
        ),
    ]
```

- [ ] **Step 3: 让写入路径同步带 workspace_id**

打开 `apps/knowledge/vector/pg_vector.py:45-82`，给 `_save` 与 `_batch_save` 增加 workspace_id：

```python
def _save(self, text, source_type: SourceType, knowledge_id: str, document_id: str, paragraph_id: str,
          source_id: str,
          is_active: bool,
          embedding: Embeddings):
    text = normalize_for_embedding(text)
    text_embedding = [float(x) for x in embedding.embed_query(text)]
    workspace_id = self._resolve_workspace_id(knowledge_id)
    embedding_obj = Embedding(
        id=uuid.uuid7(),
        knowledge_id=knowledge_id,
        document_id=document_id,
        is_active=is_active,
        paragraph_id=paragraph_id,
        source_id=source_id,
        embedding=text_embedding,
        source_type=source_type,
        workspace_id=workspace_id,
        search_vector=to_ts_vector(text)
    )
    embedding_obj.save()
    return True

def _batch_save(self, text_list: List[Dict], embedding: Embeddings, is_the_task_interrupted):
    texts = [normalize_for_embedding(row.get('text')) for row in text_list]
    embeddings = embedding.embed_documents(texts)
    workspace_cache = {}
    embedding_list = []
    for index in range(0, len(texts)):
        kid = text_list[index].get('knowledge_id')
        if kid not in workspace_cache:
            workspace_cache[kid] = self._resolve_workspace_id(kid)
        embedding_list.append(Embedding(
            id=uuid.uuid7(),
            document_id=text_list[index].get('document_id'),
            paragraph_id=text_list[index].get('paragraph_id'),
            knowledge_id=kid,
            workspace_id=workspace_cache[kid],
            is_active=text_list[index].get('is_active', True),
            source_id=text_list[index].get('source_id'),
            source_type=text_list[index].get('source_type'),
            embedding=[float(x) for x in embeddings[index]],
            search_vector=SearchVector(Value(to_ts_vector(text_list[index]['text'])))
        ))
    if not is_the_task_interrupted():
        QuerySet(Embedding).bulk_create(embedding_list) if len(embedding_list) > 0 else None
    return True

@staticmethod
def _resolve_workspace_id(knowledge_id):
    from knowledge.models import Knowledge
    k = QuerySet(Knowledge).filter(id=knowledge_id).only('workspace_id').first()
    return k.workspace_id if k and k.workspace_id else 'default'
```

- [ ] **Step 4: 跑 migration 与回填验证**

```bash
python apps/manage.py migrate knowledge
python apps/manage.py shell <<'EOF'
from django.db import connection
with connection.cursor() as c:
    c.execute("SELECT COUNT(*) FROM embedding WHERE workspace_id IS NULL OR workspace_id=''")
    print('null count:', c.fetchone()[0])
    c.execute("SELECT workspace_id, count(*) FROM embedding GROUP BY workspace_id LIMIT 5")
    print(c.fetchall())
EOF
```

Expected: null count 为 0，能看到至少一个 workspace_id 分组。

- [ ] **Step 5: 提交**

```bash
git add apps/knowledge/models/knowledge.py apps/knowledge/migrations/0009_embedding_workspace_id.py apps/knowledge/vector/pg_vector.py
git commit -m "feat(rag): add workspace_id to embedding table with backfill"
```

### Task 6.2: 增加 embedding 复合索引

**Files:**
- Create: `apps/knowledge/migrations/0010_embedding_indexes.py`

- [ ] **Step 1: 写 migration（CONCURRENTLY 不锁表）**

```python
from django.db import migrations


class Migration(migrations.Migration):

    # CONCURRENTLY 不能在事务里跑，必须关掉 atomic
    atomic = False

    dependencies = [
        ('knowledge', '0009_embedding_workspace_id'),
    ]

    operations = [
        migrations.RunSQL(
            sql=[
                # 检索热路径：knowledge_id + is_active + source_type
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS embedding_kid_active_stype_idx
                   ON embedding (knowledge_id, is_active, source_type)""",
                # 删除/统计热路径：document_id
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS embedding_document_id_idx
                   ON embedding (document_id)""",
                # paragraph_id
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS embedding_paragraph_id_idx
                   ON embedding (paragraph_id)""",
                # GIN: 关键词检索（大表上同步建会长时间锁写）
                """CREATE INDEX CONCURRENTLY IF NOT EXISTS embedding_search_vector_gin
                   ON embedding USING gin (search_vector)""",
            ],
            reverse_sql=[
                "DROP INDEX CONCURRENTLY IF EXISTS embedding_kid_active_stype_idx",
                "DROP INDEX CONCURRENTLY IF EXISTS embedding_document_id_idx",
                "DROP INDEX CONCURRENTLY IF EXISTS embedding_paragraph_id_idx",
                "DROP INDEX CONCURRENTLY IF EXISTS embedding_search_vector_gin",
            ],
        ),
    ]
```

**说明：** `CONCURRENTLY` 在 PG 不会获取写锁，建索引期间表仍可读写，但代价是构建时间更长，且如果中途中断会留下 INVALID 索引（需要手动 DROP 后重建）。生产环境上线前建议先在 staging 跑一次评估时长。

构建中失败的应急清理：

```sql
-- 检测 INVALID 索引
SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
-- 清理后重新跑 migration
DROP INDEX CONCURRENTLY <invalid_index_name>;
```

- [ ] **Step 2: 跑 migration**

```bash
python apps/manage.py migrate knowledge
python apps/manage.py shell <<'EOF'
from django.db import connection
with connection.cursor() as c:
    c.execute("SELECT indexname FROM pg_indexes WHERE tablename='embedding' ORDER BY indexname")
    for r in c.fetchall():
        print(r[0])
EOF
```

Expected: 列表里包含 `embedding_kid_active_stype_idx`, `embedding_search_vector_gin`, `embedding_document_id_idx`, `embedding_paragraph_id_idx`。

- [ ] **Step 3: 提交**

```bash
git add apps/knowledge/migrations/0010_embedding_indexes.py
git commit -m "perf(rag): add composite + GIN indexes on embedding"
```

### Task 6.3: HNSW 阈值化创建（小库不建索引）

**Files:**
- Modify: `apps/knowledge/serializers/common.py:243-265`
- Modify: `apps/maxkb/conf.py`

- [ ] **Step 1: 在 conf.py 新增阈值 getter**

```python
def get_hnsw_min_rows(self):
    val = self.get('HNSW_INDEX_MIN_ROWS')
    try:
        return int(val) if val else 5000
    except (TypeError, ValueError):
        return 5000
```

- [ ] **Step 2: 改写 create_knowledge_index**

打开 `apps/knowledge/serializers/common.py:243-265`，整段替换为：

```python
def create_knowledge_index(knowledge_id=None, document_id=None):
    if knowledge_id is None and document_id is None:
        raise AppApiException(500, _('Knowledge ID or Document ID must be provided'))

    if knowledge_id is not None:
        k_id = knowledge_id
    else:
        document = QuerySet(Document).filter(id=document_id).first()
        k_id = document.knowledge_id

    # 已存在索引：跳过
    sql = f"SELECT indexname FROM pg_indexes WHERE tablename = 'embedding' AND indexname = 'embedding_hnsw_idx_{k_id}'"
    if sql_execute(sql, []):
        return

    # 检查行数，未达阈值不建（用复合索引兜底）
    from maxkb.const import CONFIG
    min_rows = CONFIG.get_hnsw_min_rows()
    count_sql = f"SELECT count(*) AS c FROM embedding WHERE knowledge_id = '{k_id}'"
    count_result = sql_execute(count_sql, [])
    if not count_result or count_result[0]['c'] < min_rows:
        maxkb_logger.info(
            f'Skip HNSW index creation for knowledge_id={k_id}: rows={count_result[0]["c"] if count_result else 0} < {min_rows}'
        )
        return

    # 取维度
    dims_sql = f"SELECT vector_dims(embedding) AS dims FROM embedding WHERE knowledge_id = '{k_id}' LIMIT 1"
    dims_result = sql_execute(dims_sql, [])
    if not dims_result:
        return
    dims = dims_result[0]['dims']
    if dims >= 2000:
        maxkb_logger.warning(f'HNSW does not support dims>=2000, skip k_id={k_id}')
        return

    create_sql = (
        f'CREATE INDEX "embedding_hnsw_idx_{k_id}" '
        f'ON embedding USING hnsw ((embedding::vector({dims})) vector_cosine_ops) '
        f"WHERE knowledge_id = '{k_id}'"
    )
    update_execute(create_sql, [])
    maxkb_logger.info(f'Created HNSW index for knowledge ID: {k_id} (rows={count_result[0]["c"]})')
```

- [ ] **Step 3: 验证小库不建索引**

```bash
python apps/manage.py shell <<'EOF'
from knowledge.serializers.common import create_knowledge_index
from django.db import connection
# 假设有个测试小库 kid
with connection.cursor() as c:
    c.execute("SELECT id FROM knowledge LIMIT 1")
    kid = c.fetchone()[0]
create_knowledge_index(knowledge_id=kid)
with connection.cursor() as c:
    c.execute(f"SELECT indexname FROM pg_indexes WHERE indexname='embedding_hnsw_idx_{kid}'")
    print('exists:', c.fetchone())
EOF
```

Expected：行数 < 5000 时输出 `exists: None`，并日志显示 "Skip HNSW index creation"。

- [ ] **Step 4: 提交**

```bash
git add apps/knowledge/serializers/common.py apps/maxkb/conf.py
git commit -m "perf(rag): only build HNSW index when knowledge has >= MAXKB_HNSW_INDEX_MIN_ROWS rows"
```

### Task 6.4: HNSW 索引创建迁到 rag_index 队列

**Files:**
- Create: `apps/knowledge/task/index.py`
- Modify: `apps/common/event/listener_manage.py:295`

**与队列拆分开关的兼容关系：**

- `MAXKB_TASK_QUEUE_PREFIX_ENABLED=1`（split 部署默认）：`celery:create_knowledge_index` 由 `apps/ops/celery/routing.py` 路由到 `rag_index` 队列；compose 中 `maxkb-worker-rag` service 消费此队列，索引建在工作流外异步执行。
- 不启用此环境变量（all-in-one 默认）：`task_router` 一律返回 `DEFAULT_QUEUE='celery'`；任务进入唯一的 `celery` 队列，由 `CeleryDefaultService` 消费。**功能行为与原同步实现等价**，唯一区别是异步：embedding 完成后任务投递到队列、worker 拣起后再执行 `create_knowledge_index`。
- 这种"统一改异步、按开关分流"的设计避免了 all-in-one 模式下 `rag_index` 队列没人消费的死信问题，也避免了为兼容老部署而保留同步路径的代码分叉。

- [ ] **Step 1: 写异步任务**

写入 `apps/knowledge/task/index.py`：

```python
"""
HNSW 索引异步构建任务，路由到 rag_index 队列。
"""
from celery_once import QueueOnce

from common.utils.logger import maxkb_logger
from ops.celery import app as celery_app


@celery_app.task(base=QueueOnce, once={'keys': ['knowledge_id']},
                 name='celery:create_knowledge_index')
def create_knowledge_index_task(knowledge_id):
    from knowledge.serializers.common import create_knowledge_index
    try:
        create_knowledge_index(knowledge_id=knowledge_id)
    except Exception as e:
        maxkb_logger.error(f'create_knowledge_index_task failed knowledge_id={knowledge_id}: {e}')


@celery_app.task(name='celery:drop_knowledge_index')
def drop_knowledge_index_task(knowledge_id):
    from knowledge.serializers.common import drop_knowledge_index
    try:
        drop_knowledge_index(knowledge_id=knowledge_id)
    except Exception as e:
        maxkb_logger.error(f'drop_knowledge_index_task failed knowledge_id={knowledge_id}: {e}')
```

- [ ] **Step 2: 改 listener_manage 调用同步函数 → 异步任务**

打开 `apps/common/event/listener_manage.py:295`，把：

```python
create_knowledge_index(document_id=document_id)
```

改为：

```python
from knowledge.models import Document
from knowledge.task.index import create_knowledge_index_task
doc = QuerySet(Document).filter(id=document_id).only('knowledge_id').first()
if doc:
    create_knowledge_index_task.delay(str(doc.knowledge_id))
```

确认顶部 `from knowledge.serializers.common import create_knowledge_index` 这行可以删（它已不再被同步调用），但保留也没坏处——因为新任务内部还会调它。检查后保留。

- [ ] **Step 3: 把 knowledge.py 中调用 drop_knowledge_index 的两处也异步化**

```bash
grep -n 'drop_knowledge_index' apps/knowledge/serializers/knowledge.py apps/knowledge/task/embedding.py
```

把每处 `drop_knowledge_index(knowledge_id=...)` 替换为：

```python
from knowledge.task.index import drop_knowledge_index_task
drop_knowledge_index_task.delay(str(knowledge_id))
```

- [ ] **Step 4: 验证 task 注册**

```bash
python apps/manage.py shell <<'EOF'
from ops.celery import app
print('create:' , 'celery:create_knowledge_index' in app.tasks)
print('drop:', 'celery:drop_knowledge_index' in app.tasks)
EOF
```

Expected: 两个都是 True。

- [ ] **Step 5: 验证路由**

```bash
MAXKB_TASK_QUEUE_PREFIX_ENABLED=1 python -c "
from ops.celery.routing import queue_for_task
print(queue_for_task('celery:create_knowledge_index'))
print(queue_for_task('celery:drop_knowledge_index'))
"
```

Expected: 两个都是 `rag_index`。

- [ ] **Step 6: 提交**

```bash
git add apps/knowledge/task/index.py apps/common/event/listener_manage.py apps/knowledge/serializers/knowledge.py apps/knowledge/task/embedding.py
git commit -m "perf(rag): move HNSW index create/drop to async rag_index queue"
```

### Task 6.5: keyset 分页工具

**Files:**
- Modify: `apps/common/utils/page_utils.py`

- [ ] **Step 1: 在 page_utils.py 末尾追加 keyset 工具（兼容 dict 和 model 实例）**

```python
def page_keyset(query_set, page_size, handler, key_field='id', is_the_task_interrupted=lambda: False):
    """
    用 keyset 取代 offset 的批处理迭代。要求 key_field 单调递增（通常 uuid7 / 自增 id）。

    @param query_set:                 查询 query_set。不要事先 order_by；如果用了 .values(...)，确保
                                      key_field 在 values 列表里。
    @param page_size:                 每次查询大小
    @param handler:                   数据处理器，接收一页 list
    @param key_field:                 排序字段，默认 'id'
    @param is_the_task_interrupted:   任务是否被中断的回调
    """
    def _get_key(row):
        # 同时兼容 dict（.values() 出来）与 model 实例
        if isinstance(row, dict):
            return row[key_field]
        return getattr(row, key_field)

    last_value = None
    while not is_the_task_interrupted():
        qs = query_set.order_by(key_field)
        if last_value is not None:
            qs = qs.filter(**{f'{key_field}__gt': last_value})
        rows = list(qs[:page_size])
        if not rows:
            return
        handler(rows)
        last_value = _get_key(rows[-1])
        if len(rows) < page_size:
            return
```

- [ ] **Step 2: 验证函数语义**

```bash
python apps/manage.py shell <<'EOF'
from knowledge.models import Paragraph
from common.utils.page_utils import page_keyset
seen = []
def h(batch):
    seen.extend([str(p.id) for p in batch])
page_keyset(Paragraph.objects.all(), 50, h)
print('total seen:', len(seen), 'unique:', len(set(seen)))
EOF
```

Expected: total 与 unique 相等（即没有重复也没有漏页）。

- [ ] **Step 3: 提交**

```bash
git add apps/common/utils/page_utils.py
git commit -m "feat(common): add keyset pagination helper page_keyset"
```

### Task 6.6: 把热点批处理改用 keyset 分页

**Files:**
- Modify: `apps/common/event/listener_manage.py`（embedding by document 内部）

**作用域说明（仅切热点，不全量切）：**

- 本任务**只**替换 `listener_manage.py` 中向量化文档的批处理调用（`page_desc` → `page_keyset`）。这是 RAG 写入路径中段落量最大的批处理点，offset 越深越慢，是高优先级目标。
- `apps/common/utils/page_utils.py` 里的 `page` / `page_desc` **保留不删**，其它仍调用它们的代码不动。
- 后续如发现新的深 offset 热点（例如 `application_chat_record` 后台导出），再单独评估并在新计划里替换。"全量切"会触发大范围回归测试，本计划不做。

- [ ] **Step 1: 找到使用 page_desc 的关键调用点**

```bash
grep -rn 'page_desc\|from common.utils.page_utils' apps/
```

- [ ] **Step 2: 在 listener_manage.py 中把 page_desc 替换为 page_keyset**

打开 `apps/common/event/listener_manage.py:283-293`，把：

```python
page_desc(QuerySet(Paragraph)
          .annotate(
    reversed_status=Reverse('status'),
    task_type_status=Substr('reversed_status', TaskType.EMBEDDING.value,
                            1),
).filter(task_type_status__in=state_list, document_id=document_id)
          .values('id'), 5,
          ListenerManagement.get_embedding_paragraph_apply(...),
          is_the_task_interrupted)
```

改为（注意三处差异：函数名、传 `is_the_task_interrupted` 给 page_keyset、`.values('id')` 保留——因 page_keyset 现已兼容 dict）：

```python
from common.utils.page_utils import page_keyset
page_keyset(QuerySet(Paragraph)
            .annotate(
    reversed_status=Reverse('status'),
    task_type_status=Substr('reversed_status', TaskType.EMBEDDING.value,
                            1),
).filter(task_type_status__in=state_list, document_id=document_id)
            .values('id'), 5,
            ListenerManagement.get_embedding_paragraph_apply(embedding_model, is_the_task_interrupted,
                                                             ListenerManagement.get_aggregation_document_status(
                                                                 document_id)),
            is_the_task_interrupted=is_the_task_interrupted)
```

**关键点：** `is_the_task_interrupted` 必须传给 page_keyset（不传则中断不生效），原 `page_desc` 调用此参数也是位置参数第 4 位；切换函数名时容易漏传，**使用关键字传参显式标记**。

**顺序差异：** 原 `page_desc` 是倒序 offset，但 embedding 任务对顺序无依赖（每段落独立），切到 keyset 正序对业务无影响。

- [ ] **Step 3: 跑一次完整 embedding 流程验证**

```bash
# 上传一个文档（约 200 段以上），观察 worker 日志，确认 embedding 全部完成且没有遗漏 / 重复
docker logs -f maxkb-phase5 2>&1 | grep -i 'embed\|paragraph' | head -50
```

冒烟通过即可。

- [ ] **Step 4: 提交**

```bash
git add apps/common/event/listener_manage.py
git commit -m "perf(rag): switch document-embedding batch loop to keyset pagination"
```

### Task 6.7: Phase 6 冒烟回归

- [ ] **Step 1: 重建 all-in-one 启动**

```bash
docker build -f installer/Dockerfile -t maxkb-local:phase6 .
docker rm -f maxkb-phase6 2>/dev/null
docker run -d --name maxkb-phase6 -p 18089:8080 maxkb-local:phase6
sleep 60
```

- [ ] **Step 2: 验证 migration 与索引**

```bash
docker exec maxkb-phase6 python /opt/maxkb-app/apps/manage.py shell <<'EOF'
from django.db import connection
with connection.cursor() as c:
    c.execute("SELECT indexname FROM pg_indexes WHERE tablename='embedding' ORDER BY indexname")
    for r in c.fetchall(): print(r[0])
    c.execute("SELECT count(*) FROM embedding WHERE workspace_id IS NULL OR workspace_id=''")
    print('null workspace:', c.fetchone()[0])
EOF
```

Expected: 看到新增的 4 个索引；null 数量为 0。

- [ ] **Step 3: 走完整冒烟（建库、上传 200+ 段文档、命中、对话）**

观察：
- 上传后 worker 异步生成 embedding（非阻塞）
- 段数不到 5000 时不创建 HNSW 索引（看日志 "Skip HNSW"）
- 命中测试响应正常，结果合理

- [ ] **Step 4: 在 baseline.md 追加 phase6 记录并提交**

```bash
git add docs/superpowers/plans/baseline.md
git commit -m "docs: phase 6 smoke regression notes"
```

### Task 6.8: README 与运维文档

**Files:**
- Modify: `README.md`、`README_CN.md`
- Create: `docs/deployment-split.md`

- [ ] **Step 1: 写 docs/deployment-split.md**

新建文件，内容包括：
- all-in-one vs split 对比表
- split 部署步骤（指向 `installer/docker-compose.split.yml`）
- 环境变量清单与默认值（`MAXKB_ENABLE_UI / MAXKB_ENABLE_API_DOCS / MAXKB_ENABLE_EMAIL / MAXKB_ENABLE_SCHEDULER / MAXKB_ENABLED_PROVIDERS / MAXKB_TASK_QUEUE_PREFIX_ENABLED / MAXKB_HNSW_INDEX_MIN_ROWS`）
- provider 接入第三方（DeepSeek/Kimi/SiliconFlow）操作示例
- 多 worker 扩容 cookbook：知识库导入多 → 加 worker-rag 副本

- [ ] **Step 2: 在 README 顶部 Quick Start 旁加 split 部署 link**

简单一行：
```markdown
## 部署方式
- 体验 / 单机：`docker run ... ghcr.io/1panel-dev/maxkb:latest` （all-in-one）
- 生产 / 多 worker 扩容：参见 [docs/deployment-split.md](docs/deployment-split.md)
```

- [ ] **Step 3: 提交**

```bash
git add README.md README_CN.md docs/deployment-split.md
git commit -m "docs: add split deployment guide and environment variable reference"
```

---

## 自检清单

执行完所有任务后，依次确认：

1. **all-in-one 镜像仍可启动**：`docker run -d ghcr.io/.../maxkb:final` → `/admin/` 返回 200，建库 → 上传 → 命中 → 对话全流程通过。
2. **split 部署可启动**：`docker compose -f installer/docker-compose.split.yml up -d` → 6 个服务 healthy → 全流程通过。
3. **provider 默认白名单生效**：未设 `MAXKB_ENABLED_PROVIDERS` 时仅 OpenAI / Anthropic / SiliconFlow 可见。
4. **API doc 默认关闭**：默认 404；`MAXKB_ENABLE_API_DOCS=true` 时 + `MAXKB_DOC_PASSWORD=maxkb` 时 200。
5. **邮件默认关闭**：`/admin/api/user/send_email` 返回 1004；`/admin/api/user/admin_reset_password` 由管理员可调用。
6. **调度器全集群只一个**：split compose 中只有 `maxkb-worker-maintenance` 跑 apscheduler。
7. **HNSW 索引按阈值建**：小库（< 5000 行）不建；大库（≥ 5000）建。
8. **embedding 复合索引存在**：`embedding_kid_active_stype_idx`、`embedding_search_vector_gin` 都在。
9. **workspace_id 已回填**：`SELECT count(*) FROM embedding WHERE workspace_id=''` 返回 0。
10. **File sha256 复用语义保留**：上传两次相同内容 → 两条 File 行（不同 source_id/type 允许），但共享同一 loid。`file_sha256_hash_idx` 索引存在但**不是 unique**。

---

## 回滚策略

每个 Phase 末尾的提交都是独立可 revert 的边界。

| 紧急回滚目标 | 回滚命令 |
|------------|---------|
| 还原代码到 Phase 0 之前 | `git revert <Phase X..Phase 6 commits>` 重建镜像 |
| 仅回滚 RAG 数据层改动 | `git revert <Phase 6 commits>` 然后重建（DB 改动见下表） |
| 仅回滚队列拆分 | 不设 `MAXKB_TASK_QUEUE_PREFIX_ENABLED`（默认即老单队列） |
| 仅回滚 provider 懒加载 | `MAXKB_ENABLED_PROVIDERS=all` 即恢复全开（注意：仍走懒加载注册表，但白名单全开） |
| 关闭 split 部署，回到 all-in-one | 切换镜像与 compose 文件，DB 兼容（见下表） |

### 数据库 migration 兼容性

| Migration | 内容 | 旧二进制能否继续写入此 DB |
|-----------|-----|------------------------|
| `0008_file_sha256_index` | 新增 `file_sha256_hash_idx` 普通索引 | ✅ 旧二进制无感知 |
| `0009_embedding_workspace_id` | 新增 `workspace_id` 列，**带 DB 层 DEFAULT 'default'** | ✅ 旧二进制 INSERT 不带此列时由 PG 兜底为 `'default'` |
| `0010_embedding_indexes` | 新增 4 个索引 | ✅ 旧二进制无感知 |

**重要前提：** 0009 必须验证 `ALTER TABLE ... SET DEFAULT 'default'` 已落盘（计划中 Step 2 的 RunSQL 是双保险），否则旧二进制 INSERT 会因为列无 DEFAULT 而失败。

### 不可回滚的项

以下改动一旦执行**不能"用旧二进制继续"**：
- Phase 6 Task 6.4 的"HNSW 创建迁到 rag_index 队列"——旧版本同步逻辑被拆掉，旧 worker 不知道 `rag_index` 队列。回到旧版本意味着新创建的知识库不会自动建 HNSW（数据无损，但需手动调 API）。
- Phase 6 Task 6.6 的 page_keyset 切换——若回滚到 page_desc，行为差异是顺序而非正确性，可接受。
- Phase 5 队列拆分——回滚需要在 worker 端关掉 `MAXKB_TASK_QUEUE_PREFIX_ENABLED`，**任务在新队列里堆积时需要先消费完再切**，否则消息丢失。

**最稳妥回滚路径：** Phase 6 数据迁移不要回滚（它们是加列加索引，旧版本兼容）；只回滚 Phase 1–5 的代码与 compose 即可。
