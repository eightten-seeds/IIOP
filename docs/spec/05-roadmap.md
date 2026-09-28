# IIOP 开发路线、阶段门禁与 Codex 执行规范

> 文档编号：IIOP-SPEC-05  
> 文档性质：项目实施路线、阶段验收、Codex 执行与 Git 提交基线  
> 上位规范：docs/spec/00-overview.md、01-database.md、02-backend.md、03-client.md、04-ai.md  
> 适用对象：ChatGPT、Codex、项目开发者、代码审查、联调、测试与最终答辩准备  
> 当前状态：实施基线。项目进入代码开发后必须按本路线逐阶段推进。

---

# 1. 文档目的

本文档不再新增业务需求。

它只负责把前四份规范转换成可以逐步执行、逐步验证、逐步提交的开发路线。

核心目标：

1. 控制 Codex 单轮任务范围，减少重复探索和额度消耗；
2. 先建立可运行基础，再扩展业务，降低大面积返工；
3. 每个阶段都有明确输入、产物、允许命令、禁止事项和验收条件；
4. 每个阶段完成后必须提交并 push，形成可追溯 Git 历史；
5. 任何阶段未通过验收，不进入下一阶段；
6. 最终四份答辩材料只基于真实代码、真实测试和真实页面生成；
7. 不制造虚假运行记录、虚假测试结果或虚假成员贡献记录。

---

# 2. 当前项目基线

当前已经完成：

## M0-A 工程初始化

已完成：

1. 根目录初始化；
2. AGENTS.md；
3. README.md；
4. .gitignore；
5. .mvn/maven.config；
6. backend 父工程；
7. 7 个 Maven 模块；
8. web/harmony/docs/infra 目录。

已提交：

chore: initialize IIOP project structure

## M0-B 设计规范

当前已存在：

1. docs/spec/00-overview.md
2. docs/spec/01-database.md
3. docs/spec/02-backend.md
4. docs/spec/03-client.md
5. docs/spec/04-ai.md
6. docs/spec/05-roadmap.md

开发阶段这些文件属于内部施工规范。

它们不计入最终正式答辩文档数量。

---

# 3. 实施总原则

开发顺序必须满足：

~~~text
规范收口
  ↓
数据库 SQL
  ↓
本机环境与依赖门禁
  ↓
公共后端基础
  ↓
认证
  ↓
网关
  ↓
设备
  ↓
巡检
  ↓
维护
  ↓
中间件闭环
  ↓
AI
  ↓
PC 基础
  ↓
PC 业务
  ↓
PC 可视化
  ↓
HarmonyOS
  ↓
全链路联调
  ↓
测试与修复
  ↓
演示数据与答辩证据
  ↓
最终四份答辩材料
~~~

不得一次让 Codex “把整个项目做完”。

不得在后端核心链路还没稳定时先堆大量前端静态页面。

不得在业务基础链路尚未完成时把大量额度消耗在 AI 和视觉细节上。

---

# 4. 阶段门禁概念

“阶段门禁”定义：

某一阶段必须满足规定验收条件，才能进入下一阶段。

验收结果分三种：

## PASS

所有核心条件满足。

允许进入下一阶段。

## PASS WITH NOTES

核心能力通过，但存在不阻塞后续的小问题。

问题必须明确记录在当前对话或 Git issue/commit 中。

允许后续修复。

## FAIL

存在以下任一情况：

1. 编译失败；
2. 测试失败且未解释；
3. 运行链路失败；
4. 数据库结构违背 spec；
5. 跨服务越界；
6. 使用了错误技术版本；
7. 敏感信息进入 Git；
8. Codex 擅自扩展范围；
9. 实现依赖伪造数据才能工作；
10. 验收条件未满足。

FAIL 时停止推进。

---

# 5. Codex 每轮固定执行流程

每一轮 Codex 都必须按以下顺序工作：

1. 定位项目根 E:/IIOP；
2. 阅读 AGENTS.md；
3. 阅读当前阶段明确指定的 spec；
4. 阅读与本阶段相关的已有代码；
5. 执行 git status；
6. 确认工作区状态；
7. 只实现当前阶段；
8. 执行当前阶段允许的静态检查/构建/测试；
9. 检查敏感信息；
10. 执行 git diff --check；
11. git add 仅添加当前阶段文件；
12. commit；
13. push origin main；
14. 输出阶段结果摘要；
15. 停止。

不得在提交后自行继续下一个里程碑。

---

# 6. Codex 输出格式

每轮完成后只需要报告：

1. 修改文件；
2. 实现功能；
3. 执行的验证命令；
4. 验证结果；
5. commit hash；
6. push 是否成功；
7. 剩余问题；
8. 是否满足当前阶段验收。

避免输出长篇自我总结。

---

# 7. Git 规则

主分支：

main

第一版课程项目采用线性小步提交。

规则：

1. 不使用 force push；
2. 不使用 git reset --hard；
3. 不使用 git clean -fd；
4. 不擅自 rebase 已 push 的 main；
5. 不重写历史；
6. 不把多个大型阶段塞进一个提交；
7. commit message 必须表达实际内容。

推荐前缀：

1. feat:
2. fix:
3. refactor:
4. test:
5. docs:
6. chore:

阶段提交示例：

~~~text
feat: implement initial database schemas
feat: add common backend foundation
feat: implement auth service
feat: configure API gateway
feat: implement device service
feat: implement inspection workflow
feat: implement maintenance workflow
feat: integrate messaging and notifications
feat: implement AI diagnosis workflow
feat: initialize web application
feat: implement web business pages
feat: add industrial visualization
feat: implement HarmonyOS inspection client
test: verify end-to-end business flows
fix: resolve integration defects
~~~

---

# 8. 磁盘和下载门禁

用户明确要求项目依赖与项目数据不得主动写入 C 盘。

固定：

项目：

E:/IIOP

Maven：

E:/DevCache/maven/repository

npm cache：

E:/DevCache/npm

npm global 如确有需要：

E:/DevCache/npm-global

计划中的基础设施数据：

E:/IIOP-data/

Docker 如使用：

必须确认 Docker 数据位置已经符合 E 盘要求。

任何会下载依赖的阶段开始前，都要先检查对应路径。

Codex 不得假设 Docker Desktop、Maven、npm、ohpm 已经配置正确。

---

# 9. 下载命令门禁

以下命令第一次执行前必须明确检查缓存和安装路径：

1. mvn test
2. mvn package
3. mvn dependency:*
4. npm install
5. npm ci
6. ohpm install
7. docker pull
8. docker compose up

如果确认会写 C 盘且无法安全调整：

停止。

不要为了赶进度绕过约束。

---

# 10. 规范收口阶段 G0

G0 已完成。

本轮对 00 到 05 做了横向一致性检查，并把发现的问题直接回写到源规范。

检查范围：

1. 服务同步依赖；
2. 数据库字段与 API；
3. API 与 PC/HarmonyOS 页面；
4. AI 表、状态与 LangGraph4j；
5. RocketMQ Topic、事件和 Consumer Group；
6. RBAC 权限码；
7. PREPARE_WORK_ORDER_DRAFT；
8. 外部业务 ID；
9. 附件上传；
10. AI 内部 Context API；
11. maintenance 与 AI 的异步关联；
12. Redis Key 命名；
13. API Result.traceId。

G0 结论：

**PASS。**

随后根据项目单人开发和“不要过度复杂”的要求执行了一次减法收口，删除 AI Assistant、Chat Memory、Tool Calling、STOMP、Actuator 等非核心能力，数据库缩减为 25 张表，AI 工作流缩减为 5 个节点。

从本次 G0 完成开始，00 到 05 作为第一版冻结基线。真实编码若暴露新的兼容问题，先记录事实，再受控修改对应 spec。

---

# 11. G0 冻结决策

## 11.1 附件

固定：

1. 不新增文件微服务；
2. 物理根目录 E:/IIOP-data/uploads/；
3. inspection 使用 /api/inspection/attachments/**；
4. maintenance 使用 /api/maintenance/attachments/**；
5. JPEG/PNG/WebP；
6. 单文件 10 MiB；
7. GET 需要登录；
8. 数据库只存 URL。

## 11.2 权限

01、02、03、04 统一使用固定权限编码。

AI：

- ai:view
- ai:diagnosis
- ai:confirm

巡检流程编辑：

- inspection:template:manage

其他权限以 01-database.md 第 14.2 节为准。

## 11.3 外部 ID

固定：

1. Entity/Service 内部业务 ID 使用 Long；
2. 外部 PC/HarmonyOS VO 中的业务 ID 使用字符串契约；
3. 不把所有 Long 全局序列化为字符串；
4. PageResult.total 等普通数值保持数值；
5. 前端业务 ID 使用 string。

## 11.4 AI Context

固定：

- GET /internal/device/devices/{id}/ai-context
- GET /internal/device/devices/{id}/sop-context
- GET /internal/inspection/devices/{deviceId}/recent-history
- GET /internal/maintenance/devices/{deviceId}/history

客户端禁止访问 /internal/**。

## 11.5 AI 与 Maintenance

固定：

1. maintenance 不同步调用 ai；
2. AI_DIAGNOSIS_SUCCEEDED 通过 RocketMQ 传 diagnosisId；
3. maintenance 把 diagnosisId 关联到 mt_defect.ai_diagnosis_id；
4. 已存在工单时补写 mt_work_order.ai_diagnosis_id；
5. 从 defect 新建工单时继承 ai_diagnosis_id；
6. 诊断正文由客户端直接从 iiop-ai 公共 API 获取。

## 11.6 AI 幂等

ai_diagnosis 固定：

UNIQUE(trigger_type, trigger_id)

MANUAL 的 trigger_id 为 NULL，因此 MySQL 仍允许多条人工诊断。

## 11.7 手工诊断补充描述

POST /api/ai/diagnoses 的 description：

持久化到：

ai_diagnosis.user_description

## 11.8 设备当前指标

PC/HarmonyOS 当前指标统一使用：

GET /api/device/devices/{deviceId}/metric-snapshot

趋势仍使用：

GET /api/device/devices/{deviceId}/metric-trend

---

# 12. M1 数据库 SQL

## 12.1 目标

把 01-database.md 转换成可执行 MySQL 8 SQL。

## 12.2 必读

1. AGENTS.md
2. 00-overview.md
3. 01-database.md
4. 05-roadmap.md

## 12.3 产物

~~~text
infra/sql/
├─ 00_create_databases.sql
├─ 01_auth_schema.sql
├─ 02_device_schema.sql
├─ 03_inspection_schema.sql
├─ 04_maintenance_schema.sql
├─ 05_ai_schema.sql
└─ 06_seed_data.sql
~~~

## 12.4 范围

只实现 SQL。

不生成 Java。

不运行数据库。

不下载 MySQL。

不运行 Docker。

## 12.5 验收

必须满足：

1. 五个逻辑数据库；
2. 25 张业务表；
3. 表数量与 spec 一致；
4. 字段类型正确；
5. code 唯一；
6. 索引合理；
7. 无跨库外键；
8. 无明文密码；
9. 无 API Key；
10. 演示数据安全；
11. 状态值与 spec 完全一致；
12. ai_diagnosis 使用 diagnosis_status + confirmation_status；
13. ai_diagnosis 包含 user_description；
14. ai_diagnosis 有 UNIQUE(trigger_type, trigger_id)；
15. mt_defect 包含 ai_diagnosis_id；
16. ins_task 使用 overdue_flag；
17. seed 权限码与 01 第 14.2 节一致；
18. PREPARE_WORK_ORDER_DRAFT 只出现在 AI 工作流概念中，不是数据库状态。

## 12.6 验证

允许：

1. 静态阅读；
2. XML/SQL 文本检查；
3. git diff --check。

当前阶段禁止为验证而安装数据库。

## 12.7 Commit

~~~text
feat: implement initial database schemas
~~~

---

# 13. M2 开发环境与基础设施准备

M1 通过后开始。

M2 分为 M2-A 预检和 M2-B 基础设施落地。M2-A 不下载大体积组件；只有预检明确通过后，才进入 M2-B。

## 13.1 M2-A 工具与路径预检

1. java -version
2. mvn -version
3. node --version
4. npm --version
5. git --version
6. Docker 是否存在，仅检查
7. DevEco Studio 后续再检查

## 13.2 Maven

检查：

.mvn/maven.config

必须包含：

-Dmaven.repo.local=E:/DevCache/maven/repository

如果 E:/DevCache/maven/repository 不存在：

允许创建目录。

## 13.3 npm

检查 npm cache。

需要时设置项目级 .npmrc：

cache=E:/DevCache/npm

## 13.4 基础设施方案

只在此阶段确定本机实际采用：

A. Docker

或

B. 本地服务

优先依据用户当前电脑已有环境选择，避免为了规范额外安装整套工具。

如果 Docker 已安装但数据目录在 C 盘且修改存在风险：

停止并报告。

## 13.5 M2-A 验收

输出：

1. JDK；
2. Maven；
3. Node；
4. npm；
5. Docker；
6. E 盘缓存检查；
7. 采用 Docker 还是本地服务；
8. 是否允许继续下载和启动基础设施。

M2-A 完成后先停止。如果基础设施需要新的大体积下载、Docker 数据目录调整或系统级安装，先由用户确认。

## 13.6 M2-B 基础设施落地

在 M2-A 已确认方案后准备开发环境需要的：

1. MySQL 8.x；
2. Redis；
3. Nacos 3.0.3；
4. RocketMQ 5.3.1；
5. Sentinel Dashboard 1.8.9。

原则：

1. 项目数据和可配置缓存放 E 盘；
2. 不搭生产集群；
3. 开发环境只需要单机可演示；
4. Nacos、RocketMQ、Sentinel 的启动配置统一保存在 infra 下的必要文件中；
5. 不把密码和 Secret 提交 Git；
6. 如果已有本地服务可复用，优先复用，不重复下载。

基础设施启动后：

1. 执行 M1 SQL；
2. 确认 5 个逻辑数据库和 25 张表；
3. 确认 Redis 可连接；
4. 确认 Nacos 控制台/服务端可连接；
5. 确认 RocketMQ NameServer/Broker 可连接；
6. 确认 Sentinel Dashboard 可访问。

只有 M2-B 通过，后续服务的“可启动验收”才有完整环境。

M2 如果新增 infra 配置文件，使用：

~~~text
chore: configure local development infrastructure
~~~

提交并 push。

---

# 14. M3 公共后端基础

## 14.1 目标

让 backend 父工程和 iiop-common 成为真实可编译基础。

## 14.2 必读

1. 00
2. 02
3. 05

## 14.3 实现

父 POM：

1. Spring Boot 3.5.0；
2. Spring Cloud 2025.0.0；
3. Spring Cloud Alibaba 2025.0.0.0；
4. MyBatis-Plus 版本；
5. Sa-Token 版本；
6. 编译插件；
7. 测试插件。

iiop-common：

1. Result<T>；
2. PageResult<T>；
3. error code；
4. BizException；
5. request ID 常量；
6. 通用 event envelope；
7. 外部业务 ID 字符串契约的公共映射/字段级序列化辅助能力。

## 14.4 禁止

1. 不做 auth 业务；
2. 不做数据库 Entity；
3. 不做 Nacos 运行；
4. 不做 MQ；
5. 不做 AI；
6. 不让 common 变成启动服务。

## 14.5 验证

第一次允许 Maven 下载依赖。

执行前再次检查 E 盘 Maven repo。

优先：

~~~text
mvn -f backend/pom.xml -pl iiop-common -am test
~~~

## 14.6 验收

1. Maven 依赖解析成功；
2. iiop-common 测试通过；
3. 没有 Spring 版本漂移；
4. Maven 依赖实际位于 E 盘；
5. 外部业务 ID 返回字符串且 PageResult.total 等普通数值仍为数字的契约测试通过；
6. 未启用“所有 Long 全局转字符串”。

## 14.7 Commit

~~~text
feat: add common backend foundation
~~~

---

# 15. M4 Auth 核心服务

## 15.1 目标

建立第一套真实业务服务。

## 15.2 必读

1. 01 auth 数据库章节；
2. 02 auth/Sa-Token/Nacos 章节；
3. 05。

## 15.3 实现范围

Entity：

1. SysUser
2. SysRole
3. SysPermission
4. SysUserRole
5. SysRolePermission
6. SysNotification

Mapper。

Service。

DTO/VO。

登录。

退出。

/me。

用户。

角色。

权限。

通知 REST。

BCrypt。

Bootstrap Admin。

Sa-Token MVC。

Redis Session。

Nacos Discovery/Config 基础接入。

## 15.4 首次数据库运行

M4 进入运行验收前，M2-B 必须已经通过。

执行：

1. 确认 iiop_auth schema 已由 M2-B 导入；
2. 配置 iiop_auth datasource；
3. 确认 MySQL、Redis、Nacos 正常；
4. 启动 iiop-auth。

## 15.5 验收

至少：

1. auth 可编译；
2. auth 可启动；
3. Nacos 可看到 iiop-auth；
4. Bootstrap Admin 可创建；
5. 密码为 BCrypt；
6. login 成功；
7. login 错误安全；
8. /me 成功；
9. Redis 中存在 Sa-Token 登录态；
10. 用户/角色/权限基础 API 可用；
11. 无真实密码进入 Git。

## 15.6 Commit

~~~text
feat: implement authentication service
~~~

---

# 16. M5 Gateway

## 16.1 目标

建立真实入口：

客户端 → Gateway → Auth。

## 16.2 实现

1. WebFlux Gateway；
2. 新 starter；
3. 新配置前缀；
4. Nacos；
5. 显式路由；
6. LoadBalancer；
7. Sa-Token Reactor；
8. Same-Token；
9. CORS；
10. requestId；
11. 基础 Sentinel；
12. Actuator。

## 16.3 验收链

~~~text
POST :8080/api/auth/login
→ iiop-gateway
→ lb://iiop-auth
→ login
→ Redis
→ response
~~~

并验证：

1. 未登录保护；
2. 白名单；
3. 直接访问业务服务被 Same-Token 保护；
4. Gateway 正常转发；
5. /internal/** 不公开。

## 16.4 Commit

~~~text
feat: configure API gateway and authentication chain
~~~

---

# 17. M6 WebSocket 通知基础

这一步紧跟 auth/gateway，先把实时通知基础打通，后续告警、工单、AI 都可以复用。

## 17.1 实现

iiop-auth：

1. Spring WebSocket；
2. 原生 WebSocket；
3. endpoint；
4. ChannelInterceptor；
5. Sa-Token 鉴权；
6. user destination；
7. SimpMessagingTemplate；
8. NotificationService。

Gateway：

WebSocket route。

## 17.2 验收

1. 登录用户可建立连接；
2. 未登录连接失败；
3. 测试通知先落 sys_notification；
4. 在线用户收到消息；
5. 离线后 REST 仍能查询；
6. WebSocket 失败不丢持久化通知。

## 17.3 Commit

~~~text
feat: add realtime notification channel
~~~

---

# 18. M7 Device 服务

## 18.1 目标

完成设备领域。

## 18.2 实现

1. dev_category；
2. dev_device；
3. dev_metric；
4. dev_metric_data；
5. dev_sop；
6. CRUD；
7. 状态；
8. risk；
9. 指标趋势；
10. metric-snapshot；
11. 统计接口；
12. internal context；
13. AI context；
14. SOP context。

## 18.3 Feign

如果 device 需要校验责任人：

调用 auth summary。

必须使用 Same-Token。

## 18.4 Redis

实现：

1. 设备状态快照；
2. 统计短缓存。

先保证数据库正确，再加缓存。

## 18.5 验收

1. 设备 CRUD；
2. 分类树；
3. 指标定义；
4. 指标数据；
5. ECharts trend 数据；
6. metric-snapshot；
7. SOP；
8. /internal/device/devices/{id}/ai-context；
9. /internal/device/devices/{id}/sop-context；
10. 缓存丢失后数据库仍可用；
11. Three.js 所需字段完整。

## 18.6 Commit

~~~text
feat: implement device service
~~~

---

# 19. M8 附件存储基础

在巡检 PHOTO 和 HarmonyOS 开发前完成通用存储基础。具体业务上传端点分别在 M9 inspection 和 M10 maintenance 中落地。

## 19.1 架构边界

不增加独立 file 微服务。

iiop-auth 和 iiop-gateway 不承担业务附件上传。

第一版采用：

1. iiop-common 只提供无业务状态的本地文件存储抽象和安全工具；
2. iiop-inspection 在 M9 提供巡检与异常附件上传；
3. iiop-maintenance 在 M10 提供工单附件上传；
4. 各服务只保存自己领域中的附件 URL。

文件根目录：

E:/IIOP-data/uploads/

URL、API 路径和访问控制已经在 G0 写入 02-backend.md，M8 直接按该契约实现。

## 19.2 common 可包含

允许：

1. LocalFileStorage 接口或纯 Java 工具；
2. 安全文件名生成；
3. 路径规范化；
4. MIME/扩展名白名单校验；
5. 文件大小校验；
6. 安全目录拼接。

如果 FileStorageProperties 需要 Spring ConfigurationProperties，应放到具体启动服务，不为了附件让 iiop-common 引入 Spring Boot starter。

common 禁止：

1. Controller；
2. 业务数据库；
3. inspection/maintenance 专属 DTO；
4. 业务附件记录。

## 19.3 安全要求

1. 使用 UUID 或等价唯一新文件名；
2. 防止 ../ 路径穿越；
3. 限制允许 MIME；
4. 限制大小；
5. 不执行上传文件；
6. 不信任原始扩展名；
7. 文件根目录必须在 E 盘；
8. 原始文件名仅可作为脱敏展示元数据，不能直接作为物理路径；
9. 禁止上传脚本、可执行文件和服务端可执行内容。

## 19.4 M8 验收

本阶段只验收存储基础：

1. 文件能够写入 E:/IIOP-data/uploads；
2. 自动生成安全文件名；
3. 路径穿越测试失败；
4. 非允许类型测试失败；
5. 超限大小测试失败；
6. 无业务数据库依赖；
7. 无独立文件微服务；
8. common 没有因为文件功能变成启动服务。

M9/M10 再分别验收真实业务上传端点和 evidence_urls/attachments URL。

## 19.5 Commit

~~~text
feat: add local attachment storage foundation
~~~

02-backend.md 的附件 API 契约已在 G0 固定。

---

# 20. M9 Inspection 服务

## 20.1 目标

完成从模板到异常的巡检业务。

## 20.2 实现

1. ins_template；
2. ins_template_item；
3. ins_plan；
4. ins_task；
5. ins_task_item；
6. ins_abnormal；
7. Vue Flow JSON；
8. 计划生成任务；
9. 任务项快照；
10. start；
11. submit item；
12. complete；
13. cancel；
14. overdue_flag；
15. abnormal；
16. 巡检 PHOTO/异常 evidence 上传端点；
17. 统计；
18. recent history internal API。

## 20.3 Feign

校验：

1. device；
2. user。

## 20.4 定时任务

实现：

1. plan scan；
2. Redis 短锁；
3. task 生成；
4. snapshot；
5. next_generate_time。

## 20.5 MQ

先完成 Producer：

iiop.inspection.abnormal

事件：

INSPECTION_ABNORMAL_CREATED

## 20.6 验收

完整跑通：

~~~text
template
→ plan
→ task
→ task item
→ start
→ submit
→ abnormal
→ complete
~~~

检查：

1. 模板修改不影响历史任务；
2. overdue_flag 独立；
3. abnormal 事件真实发送；
4. 失败状态不会伪装成功。

## 20.7 Commit

~~~text
feat: implement inspection workflow
~~~

---

# 21. M10 Maintenance 服务

## 21.1 目标

形成维修闭环。

## 21.2 实现

1. mt_alarm；
2. mt_defect；
3. mt_work_order；
4. mt_work_order_log；
5. mt_maintenance_record；
6. mt_acceptance；
7. 工单附件上传端点；
8. mt_defect.ai_diagnosis_id 和 mt_work_order.ai_diagnosis_id 的关联逻辑。

## 21.3 MQ Consumer

消费：

1. iiop.inspection.abnormal，生成 defect；
2. iiop.ai.diagnosis，仅在 AI_DIAGNOSIS_SUCCEEDED 时关联 diagnosisId。

必须：

1. eventId 幂等；
2. UNIQUE(source_type, source_id) 兜底；
3. 重复消息不重复创建；
4. AI 诊断事件只建立引用，不同步调用 iiop-ai。

## 21.4 工单状态机

验证：

~~~text
DRAFT
→ PENDING
→ ASSIGNED
→ PROCESSING
→ WAITING_ACCEPTANCE
→ COMPLETED
~~~

驳回：

WAITING_ACCEPTANCE → PROCESSING

## 21.5 告警与事件

实现：

1. manual alarm；
2. acknowledge；
3. recover；
4. close；
5. alarm event；
6. workorder event。

## 21.6 验收

至少跑通：

~~~text
inspection abnormal
→ RocketMQ
→ defect
→ work order
→ assign
→ start
→ repair
→ acceptance
→ completed
~~~

## 21.7 Commit

~~~text
feat: implement maintenance workflow
~~~

---

# 22. M11 MQ、Redis、Sentinel、通知闭环

前几个业务服务已经用到基础能力。

M11 做集中完整化。

## 22.1 RocketMQ

核对：

1. 4 类 Topic；
2. binding 名；
3. Consumer Group；
4. event envelope；
5. eventId；
6. traceId；
7. 幂等；
8. 失败日志。

## 22.2 auth 通知消费者

消费：

1. alarm；
2. workorder；
3. 后续 ai diagnosis。

生成：

sys_notification。

在线：

原生 WebSocket。

## 22.3 Redis

核对：

1. Sa-Token；
2. 权限；
3. device status；
4. dashboard；
5. event consumed；
6. inspection plan lock。

## 22.4 Sentinel

真正配置和验证：

1. Gateway；
2. login；
3. AI 路径先预留；
4. metric data；
5. Dashboard。

QPS 数值必须根据真实联调确定。

## 22.5 验收

1. 重复异常消息只产生一个 defect；
2. 工单事件产生通知；
3. WebSocket 到达；
4. Redis 清缓存后业务事实不丢；
5. Sentinel 能触发 429；
6. 系统恢复后正常请求可用。

## 22.6 Commit

~~~text
feat: complete middleware integration
~~~

---

# 23. M12 AI 服务基础

AI 分多步开发，不一轮全部生成。

## 23.1 M12-A 依赖与模型配置

读取：

1. 00；
2. 02；
3. 04；
4. 05。

实现：

1. LangChain4j 固定版本；
2. LangGraph4j 固定版本；
3. AiProperties；
4. DeepSeek Config；
5. PromptLoader；
6. Stub model。

验收：

1. 编译；
2. 不需要真实 Key；
3. 测试通过；
4. no secret。

Commit：

~~~text
feat: add AI model foundation
~~~

## 23.2 M12-B AI 数据和 API

实现：

1. ai_diagnosis；
2. ai_workflow_trace；
3. Mapper；
4. Diagnosis Query；
5. Diagnosis API；
6. workflow trace API；
7. confirm/reject API。

Commit：

~~~text
feat: implement AI persistence and APIs
~~~

## 23.3 M12-C Context Feign

实现：

1. DeviceClient；
2. InspectionClient；
3. MaintenanceClient；
4. DTO；
5. timeout；
6. Same-Token。

验收：

真实调用三个业务服务。

Commit：

~~~text
feat: add AI context clients
~~~

---

# 24. M13 LangGraph4j 诊断工作流

## 24.1 实现

1. DiagnosisState；
2. StateGraph；
3. 5 个固定节点；
4. Graph Factory；
5. Trace Recorder；
6. Context Snapshot；
7. Failure rules；
8. Stub DeepSeek。

## 24.2 验收

必须能证明代码使用真实 LangGraph4j StateGraph。

Stub 测试覆盖：

1. 全成功；
2. device 失败；
3. inspection 降级；
4. maintenance 降级；
5. SOP 空；
6. model 失败；
7. trace。

不得用普通 Service 链伪装 Graph。

## 24.3 Commit

~~~text
feat: implement LangGraph4j diagnosis workflow
~~~

---

# 25. M14 DeepSeek 真正接入

## 25.1 前置检查

1. DEEPSEEK_API_KEY 已由用户在本机环境设置；
2. Git 不包含 Key；
3. Nacos 不包含明文 Key；
4. 模型名合法；
5. 网络可访问；
6. 实际 API 额度允许测试。

## 25.2 实现

1. diagnosisChatModel；
2. toolChatModel；
3. diagnosis-v1；
4. JSON Mode；
5. Output Parser；
6. Validator；
7. RiskGuard；
8. TokenUsage；
9. error mapping。

## 25.3 真实调用

只跑少量集成测试。

必须验证：

1. deepseek-flash；
2. JSON 可解析；
3. thinking 诊断；
4. timeout；
5. failure。

## 25.4 验收

真实诊断能：

~~~text
device context
+ history
+ SOP
→ LangGraph4j
→ LangChain4j
→ DeepSeek
→ valid JSON
→ RiskGuard
→ ai_diagnosis
~~~

## 25.5 Commit

~~~text
feat: integrate DeepSeek diagnosis
~~~

---

# 26. M15 AI 异步、MQ 与人工确认

## 26.1 异步执行

实现：

1. 固定小线程池 diagnosisExecutor；
2. PENDING → RUNNING；
3. 手工诊断提交异步任务；
4. MQ 触发诊断提交异步任务；
5. SUCCEEDED / FAILED。

不实现数据库轮询 Worker。

## 26.2 MQ

AI 消费：

1. inspection abnormal；
2. maintenance alarm。

AI 生产：

1. diagnosis succeeded；
2. diagnosis failed；
3. diagnosis confirmed。

## 26.3 确认

实现：

1. confirm；
2. reject；
3. ai:confirm 权限；
4. confirmedBy/confirmedAt/comment。

## 26.4 验收

1. MQ 异常触发诊断；
2. HTTP 手工触发诊断；
3. 同一异常不重复生成诊断；
4. 5 节点 LangGraph4j trace 正确；
5. DeepSeek 失败不影响 maintenance 主业务；
6. confirmation 独立于 diagnosis_status；
7. AI_DIAGNOSIS_SUCCEEDED 能让 maintenance 关联 defect/work-order 的 diagnosisId。

## 26.5 Commit

~~~text
feat: complete AI diagnosis workflow
~~~

---

# 27. M16 Web 基础工程

后端核心 API 稳定后开始 PC。

## 27.1 前置

检查：

1. Node/npm；
2. E 盘 npm cache；
3. web 目录；
4. 后端 Gateway 可用。

## 27.2 初始化

实现：

1. Vue 3；
2. Vite；
3. TypeScript；
4. Element Plus；
5. Router；
6. Axios；
7. Pinia；
8. persistedstate；
9. App Layout；
10. Login；
11. 权限 Router；
12. 403/404。

## 27.3 验收

真实登录 Gateway。

刷新后：

1. Token 仍在；
2. /me 恢复权限；
3. 未登录进入 login；
4. 403 正常；
5. npm build 通过。

## 27.4 Commit

~~~text
feat: initialize web application
~~~

---

# 28. M17 Web 设备域

实现：

1. categories；
2. devices；
3. device detail；
4. metric；
5. monitor；
6. SOP。

先功能正确，再做视觉细节。

验收：

1. CRUD 真后端；
2. 分页；
3. 筛选；
4. 状态；
5. trend；
6. loading/empty/error。

Commit：

~~~text
feat: implement web device pages
~~~

---

# 29. M18 Web 巡检域

实现：

1. templates；
2. template items；
3. plans；
4. tasks；
5. task execution；
6. abnormal；
7. PHOTO attachment；
8. Vue Flow 可先放下一阶段。

验收：

通过 PC 完成：

~~~text
template
→ plan
→ task
→ execution
→ abnormal
→ complete
~~~

Commit：

~~~text
feat: implement web inspection pages
~~~

---

# 30. M19 Web 维护域

实现：

1. alarm；
2. defect；
3. work-order list；
4. work-order detail；
5. logs；
6. repair；
7. acceptance；
8. AI diagnosis card placeholder with real API。

验收：

PC 完成真实工单闭环。

Commit：

~~~text
feat: implement web maintenance pages
~~~

---

# 31. M20 Web AI

实现：

1. diagnosis list；
2. manual diagnosis；
3. diagnosis detail；
4. 5 节点 workflow trace；
5. confirm/reject；
6. PENDING/RUNNING polling；
7. AI notification refresh。

验收：

1. 真 DeepSeek 结果；
2. 无 reasoning content；
3. 5 节点 workflow trace；
4. 人工确认；
5. 工单能显示关联 diagnosisId。

Commit：

~~~text
feat: implement web AI features
~~~

---

# 32. M21 Dashboard + ECharts

实现：

1. KPI；
2. status distribution；
3. risk distribution；
4. inspection trend；
5. alarm trend；
6. work-order distribution；
7. recent activity。

验收：

1. 全部真实 API；
2. 无随机数据；
3. resize；
4. empty；
5. error；
6. 1366×768；
7. 1920×1080。

Commit：

~~~text
feat: add industrial dashboard
~~~

---

# 33. M22 Three.js

实现：

1. Scene；
2. Camera；
3. Renderer；
4. Light；
5. Grid；
6. OrbitControls；
7. GLTFLoader；
8. placeholder；
9. device positions；
10. status/risk；
11. Raycaster；
12. detail card；
13. cleanup。

验收：

1. 模型可加载；
2. 没模型可 fallback；
3. 点击设备；
4. 进入详情；
5. resize；
6. 无明显资源泄漏。

Commit：

~~~text
feat: add Three.js equipment scene
~~~

---

# 34. M23 Vue Flow

实现：

1. 8 节点类型；
2. add；
3. drag；
4. edge；
5. delete；
6. property panel；
7. save JSON；
8. reload；
9. fit view。

验收：

1. flow_definition 真入库；
2. 刷新后回显；
3. 不承担业务引擎执行；
4. AI node 只表达流程语义。

Commit：

~~~text
feat: add inspection flow designer
~~~

---

# 35. M24 PC WebSocket 与系统管理

实现：

1. 原生 WebSocket；
2. user queue；
3. reconnect；
4. notification store；
5. unread；
6. notification center；
7. users；
8. roles；
9. permissions；
10. profile。

验收：

1. 真实通知；
2. 重连；
3. REST 补漏；
4. role permission；
5. 禁止前端越权。

Commit：

~~~text
feat: complete web notifications and system management
~~~

---

# 36. M25 HarmonyOS 环境预检

在开始写 HarmonyOS 前确认：

1. DevEco Studio；
2. HarmonyOS SDK；
3. ArkTS；
4. API Level；
5. 模拟器或真机；
6. 项目路径在 E 盘；
7. ohpm/cache 路径是否满足磁盘约束；
8. Windows Gateway 局域网 IP。

把实际 API Level 固定后再写代码。

不得提前从旧教程复制 API。

---

# 37. M26 HarmonyOS 基础

实现：

1. ArkTS/ArkUI；
2. Stage；
3. Navigation；
4. HttpClient；
5. ApiConfig；
6. AuthStorage；
7. Models；
8. Login；
9. Home；
10. Profile。

验收：

真实 Gateway 登录。

Commit：

~~~text
feat: initialize HarmonyOS client
~~~

---

# 38. M27 HarmonyOS 巡检

实现：

1. TodayInspection；
2. TaskDetail；
3. start；
4. NUMBER；
5. BOOLEAN；
6. TEXT；
7. PHOTO；
8. abnormal；
9. complete；
10. DeviceDetail。

验收：

真机/模拟器完成一条巡检。

Commit：

~~~text
feat: implement HarmonyOS inspection workflow
~~~

---

# 39. M28 HarmonyOS 维修与 AI

实现：

1. Alarm；
2. MyWorkOrder；
3. WorkOrderDetail；
4. start；
5. repair；
6. submit acceptance；
7. AI diagnosis；
8. confirm/reject；
9. notification REST。

验收：

1. 维修人员能处理工单；
2. AI 结果可查看；
3. 高风险提示；
4. no device control；
5. 401/403/409/503 状态正确。

Commit：

~~~text
feat: complete HarmonyOS maintenance features
~~~

---

# 40. M29 全链路业务联调

这一阶段不新增大功能。

目标：

把所有真实模块连接起来。

## 40.1 链路一

~~~text
PC Login
→ Gateway
→ Auth
→ Redis
~~~

## 40.2 链路二

~~~text
Device
→ Metric Data
→ ECharts
→ Three.js
~~~

## 40.3 链路三

~~~text
Plan
→ Task
→ HarmonyOS Inspection
→ Abnormal
→ RocketMQ
~~~

## 40.4 链路四

~~~text
Abnormal
→ Maintenance Defect
→ Work Order
→ Repair
→ Acceptance
~~~

## 40.5 链路五

~~~text
Abnormal
→ AI
→ LangGraph4j
→ DeepSeek
→ Human Confirm
→ Work Order reference
~~~

## 40.6 链路六

~~~text
Alarm / Work Order / AI
→ RocketMQ
→ auth notification
→ WebSocket
→ PC
~~~

验收要求：

六条链都必须真实可跑。

---

# 41. M30 权限与安全测试

验证四角色。

## SUPER_ADMIN

所有系统能力。

## ADMIN

业务管理。

## INSPECTOR

不能：

1. 改用户；
2. 改角色；
3. 分派不属于自己的高权限工单动作。

能：

1. 执行巡检；
2. 上报异常；
3. 查看允许设备；
4. 使用允许 AI。

## MAINTAINER

能：

1. 查看告警；
2. 处理工单；
3. 查看/确认允许的 AI。

不能：

1. 改系统权限；
2. 修改巡检模板，除非明确授权。

测试：

1. 未登录；
2. Token 失效；
3. 禁用用户；
4. 无权限；
5. 直接访问 920x；
6. /internal；
7. Same-Token；
8. WebSocket 鉴权。

---

# 42. M31 故障与降级测试

至少模拟：

1. Redis 暂时不可用；
2. Nacos 服务发现问题；
3. RocketMQ 消费重试；
4. 重复 MQ；
5. DeepSeek timeout；
6. DeepSeek 429；
7. DeepSeek 5xx；
8. AI JSON invalid；
9. inspection history timeout；
10. maintenance history timeout；
11. WebSocket 断开；
12. glTF 加载失败。

目标：

系统基础设备、巡检、工单功能不能因为 AI 或可视化功能失败而整体不可用。

---

# 43. M32 性能与体验检查

不伪造压测成绩。

只对真实本地环境做基础检查。

包括：

1. CRUD 响应；
2. Dashboard 请求数量；
3. 索引；
4. metric trend；
5. Three.js 帧率肉眼/DevTools 检查；
6. 页面资源大小；
7. DeepSeek 延迟；
8. WebSocket；
9. HarmonyOS 列表体验。

任何具体毫秒数只有实际测得后才能写入最终报告。

---

# 44. M33 演示数据整理

开发中 seed data 是基础演示数据。

最终答辩前补充一套能够展示完整业务链的数据。

建议场景：

CNC-01 主轴异常。

事实：

1. 设备 ONLINE 或 FAULT；
2. 主轴温度高；
3. 振动趋势上升；
4. 巡检发现润滑异常；
5. 生成 abnormal；
6. maintenance 生成 defect；
7. AI 结合 SOP 和历史诊断；
8. 人工确认；
9. 工单维修；
10. 验收完成。

所有展示数据均为虚构演示数据。

不能使用虚假“实际企业生产数据”叙述。

---

# 45. M34 最终缺陷修复

只修：

1. 阻塞链路；
2. 页面错误；
3. 权限错误；
4. 测试错误；
5. 可视化错误；
6. AI 错误；
7. HarmonyOS 错误。

禁止答辩前最后阶段进行：

1. 大规模架构重写；
2. 升级核心框架；
3. 换 UI 框架；
4. 增加新微服务；
5. 引入向量数据库；
6. 引入新消息队列。

---

# 46. M35 最终代码冻结

冻结条件：

1. main 干净；
2. backend build 通过；
3. web build 通过；
4. HarmonyOS build 通过；
5. 核心 E2E 通过；
6. 无 API Key；
7. README 运行说明与真实项目一致；
8. spec 与真实实现无重大冲突。

打一个 Git Tag：

建议：

~~~text
v1.0.0-defense
~~~

Tag 只在用户确认最终版本后创建。

---

# 47. 最终答辩证据

最终四份文档必须使用真实证据。

可使用：

1. Git 提交历史；
2. 最终目录树；
3. SQL；
4. Maven POM；
5. Nacos 服务列表截图；
6. Gateway；
7. Redis Session；
8. RocketMQ；
9. Sentinel；
10. PC 页面截图；
11. Three.js；
12. ECharts；
13. Vue Flow；
14. AI diagnosis；
15. workflow trace；
16. HarmonyOS 页面；
17. 测试结果。

不能使用：

1. 伪造 commit；
2. 伪造运行日志；
3. 伪造测试通过；
4. 伪造其他成员的具体代码贡献。

---

# 48. M36 最终四份答辩材料

项目代码冻结后才生成。

由 ChatGPT 根据真实仓库和用户提供的真实运行截图生成。

正式材料只有：

1. 团队项目实训报告；
2. 用户个人实训报告；
3. 答辩 PPT；
4. 答辩讲稿。

---

# 49. 团队项目实训报告内容来源

报告可以包含：

1. 项目背景；
2. 需求；
3. 用户角色；
4. 架构；
5. 数据库；
6. 微服务；
7. 核心业务；
8. PC；
9. HarmonyOS；
10. AI；
11. 测试；
12. 总结与展望。

技术实现只能依据真实最终代码。

如果课程模板要求成员分工，应使用真实、可核实的实际情况表述。

---

# 50. 个人实训报告内容来源

重点写：

1. 本人的实际工作；
2. 技术难点；
3. 关键模块；
4. 排错过程；
5. 学习收获；
6. 项目不足。

不得根据尚未完成的功能提前写“已实现”。

---

# 51. 答辩 PPT

建议控制在课程答辩适合的页数。

核心顺序：

1. 项目背景；
2. 需求与角色；
3. 架构；
4. 核心业务闭环；
5. 数据库；
6. 微服务；
7. PC；
8. HarmonyOS；
9. DeepSeek/LangChain4j/LangGraph4j；
10. 中间件；
11. 测试；
12. 演示亮点；
13. 总结。

PPT 的截图在代码冻结后采集。

---

# 52. 答辩讲稿

讲稿与 PPT 一一对应。

必须能清楚解释：

1. 为什么拆这些微服务；
2. 为什么不跨库；
3. RocketMQ 在哪里使用；
4. Redis 在哪里使用；
5. Sentinel 在哪里使用；
6. WebSocket 在哪里使用；
7. Three.js 的业务作用；
8. Vue Flow 的业务作用；
9. HarmonyOS 为什么只做现场流程；
10. DeepSeek、LangChain4j、LangGraph4j 分别做什么；
11. AI 为什么必须人工确认。

---

# 53. 阶段依赖图

~~~text
M0 工程与规范
        ↓
G0 规范收口
        ↓
M1 SQL
        ↓
M2-A 环境预检
        ↓
M2-B 基础设施
        ↓
M3 common
        ↓
M4 auth
        ↓
M5 gateway
        ↓
M6 websocket
        ↓
M7 device
        ↓
M8 attachment
        ↓
M9 inspection
        ↓
M10 maintenance
        ↓
M11 middleware closure
        ↓
M12 AI foundation
        ↓
M13 LangGraph4j
        ↓
M14 DeepSeek
        ↓
M15 AI async + confirm
        ↓
M16 web base
        ↓
M17 device web
        ↓
M18 inspection web
        ↓
M19 maintenance web
        ↓
M20 AI web
        ↓
M21 ECharts
        ↓
M22 Three.js
        ↓
M23 Vue Flow
        ↓
M24 WebSocket/system web
        ↓
M25 Harmony preflight
        ↓
M26 Harmony base
        ↓
M27 Harmony inspection
        ↓
M28 Harmony maintenance/AI
        ↓
M29 E2E
        ↓
M30 security
        ↓
M31 failure tests
        ↓
M32 experience
        ↓
M33 demo data
        ↓
M34 fixes
        ↓
M35 freeze
        ↓
M36 final documents
~~~

---

# 54. 可并行与不可并行

当前由单人完整开发，因此路线以串行为主。

可以在不产生冲突时小范围穿插：

1. 后端某服务测试和对应页面 TypeScript 类型；
2. PC 样式优化与已有 API 联调；
3. HarmonyOS UI 与稳定 API 绑定。

禁止并行制造：

1. 前端自定义一套后端 API；
2. AI 自定义一套设备 DTO；
3. HarmonyOS 自定义业务状态；
4. 两边同时修改同一核心状态机。

单人开发的优势是架构一致性，应优先保持一致。

---

# 55. Codex 额度控制策略

每轮任务必须尽量让 Codex“执行”，少让 Codex“重新设计”。

固定做法：

1. 架构由 spec 给出；
2. Prompt 只指出当前阶段；
3. Codex 先读取指定 spec；
4. 不要求它重新规划整个系统；
5. 不一次生成过多模块；
6. 失败时只修失败范围；
7. 通过 GitHub 由 ChatGPT审查代码，再给下一轮任务。

遇到普通 CRUD、页面和明确改动：

使用成本较低、速度较快的 Codex 模型即可。

遇到：

1. 大面积版本冲突；
2. LangGraph4j API 迁移；
3. Spring Cloud Gateway/Sentinel 兼容问题；
4. 多服务难定位故障；

再升级高能力模型。

具体模型名称和额度属于产品设置，不写死为项目代码规范。

---

# 56. Codex 通用短 Prompt

规范冻结后，标准 Prompt：

~~~text
当前项目 E:/IIOP。

先阅读 AGENTS.md、docs/spec/05-roadmap.md，以及 Mx 指定的 spec。

严格实现 Mx。
只修改本阶段必要文件。
按该阶段验收标准完成允许的构建/测试。
检查敏感信息和 git diff --check。
commit 并 push origin/main。
完成后报告结果并停止，不进入下一阶段。
~~~

这段应作为默认模板。

---

# 57. M1 短 Prompt

~~~text
当前项目 E:/IIOP。

阅读：
AGENTS.md
docs/spec/00-overview.md
docs/spec/01-database.md
docs/spec/05-roadmap.md

严格实现 M1 数据库 SQL。
本阶段只生成 infra/sql 中规定的 SQL。
不要生成 Java，不运行 MySQL，不运行 Docker，不下载依赖。

完成静态检查后：
git diff --check
commit: feat: implement initial database schemas
push origin/main
然后停止。
~~~

---

# 58. M3 短 Prompt

~~~text
阅读 AGENTS.md、00-overview.md、02-backend.md、05-roadmap.md。

严格实现 M3 公共后端基础。
执行前确认 Maven repo 为 E:/DevCache/maven/repository。
完成测试、commit、push 后停止。
~~~

---

# 59. 业务服务短 Prompt

例如 M7：

~~~text
阅读 AGENTS.md、01-database.md、02-backend.md、05-roadmap.md。

严格实现 M7 iiop-device。
以现有代码和 spec 为准，不扩展服务边界。
完成测试、commit、push 后停止。
~~~

后续 inspection、maintenance 使用同一结构。

---

# 60. AI 短 Prompt

例如 M13：

~~~text
阅读 AGENTS.md、00、01、02、04、05。

严格实现 M13 LangGraph4j 诊断工作流。
使用 04-ai.md 固定版本和 5 节点结构。
本阶段使用 Stub 模型，不调用真实 DeepSeek。
完成测试、commit、push 后停止。
~~~

---

# 61. Web 短 Prompt

~~~text
阅读 AGENTS.md、02-backend.md、03-client.md、05-roadmap.md。

严格实现 Mx。
只使用真实已存在 API。
不擅自新增后端接口，不保留最终随机 Mock。
完成 npm build、commit、push 后停止。
~~~

---

# 62. HarmonyOS 短 Prompt

~~~text
阅读 AGENTS.md、02-backend.md、03-client.md、05-roadmap.md。

严格实现 Mx HarmonyOS 阶段。
以当前已锁定 API Level 的官方 SDK 为准。
复用 Gateway API，不新增独立后端协议。
完成可执行验证、commit、push 后停止。
~~~

---

# 63. 修复任务 Prompt

发现问题时，不重新给大任务。

使用：

~~~text
先阅读当前错误涉及的代码和对应 spec。

只修复以下问题：
<问题>

不得顺带重构其他模块。
保留正确实现。
完成最小相关测试。
commit: fix: ...
push 后停止。
~~~

---

# 64. Codex 停止条件

任何阶段出现下列情况，Codex立即停止：

1. 依赖版本无法解析；
2. 需要改变固定框架基线；
3. 需要写 C 盘依赖；
4. 发现真实 Secret；
5. Git 冲突；
6. 远程出现未知提交；
7. 数据库 spec 存在矛盾；
8. API spec 和当前实现不可兼容；
9. 需要删除大量现有代码；
10. 需要新增微服务；
11. 需要 force push；
12. 真实 DeepSeek API 返回与当前规范存在重大不兼容。

停止后报告事实，不自行绕过。

---

# 65. ChatGPT 审查规则

每次 Codex push 后，用户只需告诉 ChatGPT：

“Mx 已推送，审查。”

ChatGPT 直接读取 GitHub。

审查重点：

1. 是否完成当前范围；
2. 是否改了不相关文件；
3. 是否符合 spec；
4. 是否有明显 bug；
5. 是否存在安全问题；
6. 是否需要测试；
7. 是否可以 PASS。

如果 FAIL：

ChatGPT 给最小修复 Prompt。

如果 PASS：

进入下一阶段。

---

# 66. 不采用的开发方式

本项目明确不采用：

1. 一次性生成整个系统；
2. 先生成所有 Controller 再补业务；
3. 所有服务共享同一批 Entity；
4. 一个 common 模块承载所有 DTO；
5. 前端大量 Mock 后最后一天才联调；
6. AI 最后只补一个 DeepSeek HTTP 接口；
7. 为了展示 LangChain4j 再增加 AI Assistant、Chat Memory 或 Tool Calling；
7. 为展示技术强行引入 Kafka/Seata/Elasticsearch/向量库；
8. 为了“微服务”继续拆十几个服务；
9. 为了“实时”模拟高频随机设备数据；
10. 为了答辩伪造测试和运行证据。

---

# 67. 项目复杂度控制

第一版必须保证“有真实闭环”优先于“功能数量”。

如果时间不足，优先级：

P0：

1. 登录；
2. 设备；
3. 巡检；
4. 异常；
5. 工单；
6. DeepSeek 诊断；
7. PC；
8. HarmonyOS 现场巡检。

P1：

1. RocketMQ；
2. Redis；
3. Nacos；
4. Gateway；
5. Sentinel；
6. WebSocket；
7. ECharts；
8. Three.js；
9. Vue Flow。

上述 P1 实际上仍属于课程要求，应完成，但在排错时先保证 P0 主链不被破坏。

禁止为了做漂亮三维页面而让核心巡检工单链无法运行。

---

# 68. 最终完成定义

项目只有同时满足以下条件才算“完成”。

## 后端

1. 6 个启动服务；
2. common；
3. 5 个逻辑数据库；
4. 25 张表；
5. Nacos；
6. Gateway；
7. Redis；
8. Sa-Token；
9. RocketMQ；
10. Sentinel；
11. WebSocket；
12. OpenFeign。

## 业务

1. 设备；
2. 巡检；
3. 异常；
4. 告警；
5. 缺陷；
6. 工单；
7. 维修；
8. 验收。

## AI

1. DeepSeek；
2. LangChain4j；
3. LangGraph4j 5 节点；
4. workflow trace；
5. 人工确认。

## PC

1. CRUD；
2. Dashboard；
3. ECharts；
4. Three.js；
5. Vue Flow；
6. AI；
7. 原生 WebSocket。

## HarmonyOS

1. 登录；
2. 巡检；
3. 异常；
4. 工单；
5. AI；
6. 通知。

## 测试

1. 核心链通过；
2. 权限通过；
3. AI 失败降级；
4. MQ 幂等；
5. WebSocket；
6. PC build；
7. HarmonyOS build。

## 文档

最终四份答辩材料完成。

---

# 69. 下一步

G0 已完成，第一版规范已冻结。

接下来：

1. 用户让 Codex 在 E:/IIOP 执行 git status；
2. 工作区干净时 git pull --ff-only origin main；
3. 只确认 00 到 05 已同步，不修改代码；
4. 然后单独执行 M1；
5. M1 commit + push；
6. 用户告诉 ChatGPT“M1 已推送，审查”；
7. ChatGPT 审查通过后再进入 M2-A。

不要让 Codex 在一次任务里同时 pull、实现 M1、继续 M2。

---

# 70. 当前结论

IIOP 的实施路线已经由“概念性模块列表”细化为带门禁的工程计划。

最重要的执行纪律：

1. 一阶段一提交；
2. 一阶段一验收；
3. 代码以 spec 为准；
4. 失败只修当前问题；
5. 不跨阶段；
6. 不伪造运行结果；
7. 不把依赖写到 C 盘；
8. 不把 Secret 写进 Git；
9. AI 不自动控制设备；
10. 最终报告只写真实完成内容。

从本文件生效开始，Codex 的任务提示词应该变短，设计信息由 spec 持久提供，Codex 的主要职责变成实现和验证。
