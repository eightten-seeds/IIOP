# IIOP 压缩实施路线与阶段门禁

> 文档编号：IIOP-SPEC-05  
> 文档性质：实施路线、Codex 执行顺序与阶段验收基线  
> 上位规范：`docs/spec/00-overview.md`  
> 关联规范：`01-database.md`、`02-backend.md`、`03-client.md`、`04-ai.md`  
> 当前策略：时间优先，合并原 M2-M36 的细碎里程碑，保留关键门禁

---

## 1. 目的

本项目由单人开发，时间优先级高于过程拆分粒度。

原路线把实现拆到 M36，便于教学审计，但会产生过多轮次、重复上下文读取和频繁提交。当前改为 8 个执行阶段 S1-S8。

阶段名称合并，不代表取消验收。每个阶段仍必须：

1. 只实现当前范围；
2. 使用 00-04 的冻结架构；
3. 完成对应构建、运行或静态验证；
4. 检查敏感信息；
5. commit + push；
6. ChatGPT 审查后再进入下一阶段。

Codex 不重新设计架构，只负责按规范实现。

---

## 2. 已完成基线

以下工作已经完成，不再重复：

### M0 工程初始化

已完成：

- 根目录和 Git 仓库；
- `AGENTS.md`；
- `README.md`；
- `.gitignore`；
- `.mvn/maven.config`；
- backend 父工程；
- 7 个 Maven 模块；
- web / harmony / docs / infra 目录。

### G0 规范收口

00-05 已完成横向一致性检查并冻结第一版范围：

- 6 个可启动服务 + `iiop-common`；
- 5 个逻辑数据库；
- 25 张业务表；
- AI 只做结构化设备诊断；
- LangGraph4j 固定 5 节点；
- 原生 WebSocket JSON 通知；
- 不引入无关微服务和额外基础设施。

### M1 数据库 SQL

已完成：

- `infra/sql/00_create_databases.sql`
- `01_auth_schema.sql`
- `02_device_schema.sql`
- `03_inspection_schema.sql`
- `04_maintenance_schema.sql`
- `05_ai_schema.sql`
- `06_seed_data.sql`

SQL 结构静态审查已通过，实际数据库导入归入 S1 验收。

### M2-A 环境预检

已完成主要工具和路径准备：

- JDK 17 可用；
- Maven 3.9.10 可用；
- Maven repository 指向 `E:/DevCache/maven/repository`；
- npm cache / prefix 指向 E 盘；
- MySQL 8.0.x 已存在；
- Redis 已存在；
- 本项目不使用 Docker。

---

## 3. 新路线总览

~~~text
S1 基础设施
  ↓
S2 后端核心
  ↓
S3 AI
  ↓
S4 PC Web
  ↓
S5 HarmonyOS
  ↓
S6 全链路联调与测试
  ↓
S7 演示、修复与冻结
  ↓
S8 最终答辩材料
~~~

预计主任务轮次控制在 12-14 轮，不再按原 M3-M36 逐个执行。

---

# 4. S1 基础设施

## 4.1 目标

完成本机可运行的开发基础设施，并执行 M1 SQL。

固定使用 Windows 本地服务，不使用 Docker。

## 4.2 组件

必须具备：

1. MySQL 8.x；
2. Redis；
3. Nacos 3.0.3；
4. RocketMQ 5.3.1；
5. Sentinel Dashboard 1.8.9。

## 4.3 当前已知环境

可直接复用：

- MySQL 8.0.43；
- Redis 5.0.14.1；
- RocketMQ 5.3.1；
- Sentinel Dashboard 1.8.9。

Nacos 必须最终恢复到可连接状态。

## 4.4 数据与端口

默认：

- MySQL 3306；
- Redis 6379；
- Nacos 8848；
- Nacos Console 本机避免占用 Gateway 8080；
- RocketMQ NameServer 9876；
- RocketMQ Broker 10911；
- Sentinel Dashboard 8858。

项目数据、可控日志和缓存尽量放 E 盘。

## 4.5 SQL 验收

必须实际执行 M1 SQL 并确认：

- `iiop_auth` 6 张；
- `iiop_device` 5 张；
- `iiop_inspection` 6 张；
- `iiop_maintenance` 6 张；
- `iiop_ai` 2 张；
- 总计 25 张。

同时确认角色、33 个权限码和安全演示数据存在。

## 4.6 S1 PASS

只有以下全部成立才通过：

1. MySQL 可连接；
2. 25 张业务表已实际创建；
3. Redis `PING -> PONG`；
4. Nacos 可连接；
5. RocketMQ NameServer/Broker 可连接；
6. Sentinel Dashboard 可访问；
7. 无 Secret 提交到 Git；
8. 无项目基础设施数据主动写入 C 盘。

---

# 5. S2 后端核心

S2 合并原 common、auth、gateway、WebSocket、device、attachment、inspection、maintenance 和中间件闭环。

为控制一次改动规模，S2 固定分 3 轮。

## 5.1 S2-A common + auth + gateway

实现：

### common

- `Result<T>`；
- `PageResult<T>`；
- 统一错误码；
- `BizException`；
- traceId / requestId 基础；
- MQ event envelope；
- 外部业务 ID 字符串契约辅助。

### auth

- 用户；
- 角色；
- 权限；
- RBAC；
- BCrypt；
- Sa-Token；
- Redis Session；
- login / logout / me；
- 通知 REST；
- Bootstrap Admin；
- Nacos Discovery/Config。

### gateway

- Spring Cloud Gateway WebFlux；
- Nacos；
- 显式路由；
- LoadBalancer；
- Sa-Token Reactor；
- Same-Token；
- CORS；
- requestId；
- Sentinel；
- 禁止公开 `/internal/**`。

验收：

- Maven build/test 通过；
- auth 可启动并注册到 Nacos；
- Gateway 8080 可转发 login；
- Redis 存在登录态；
- 未登录和越权保护正常；
- 业务服务直连受 Same-Token 保护。

建议提交：

~~~text
feat: implement common auth and gateway foundation
~~~

## 5.2 S2-B device + inspection + attachment

实现：

### device

- category；
- device；
- metric；
- metric data；
- SOP；
- CRUD；
- risk/status；
- trend；
- metric-snapshot；
- stats；
- AI context；
- SOP context。

### attachment

- 本地文件安全存储；
- 根目录 `E:/IIOP-data/uploads/`；
- JPEG/PNG/WebP；
- 单文件 10 MiB；
- 防路径穿越；
- 不新增 file 微服务。

### inspection

- template；
- template item；
- plan；
- task；
- task item；
- abnormal；
- 任务快照；
- PHOTO；
- 异常事件；
- internal recent-history。

验收：

- device/inspection build 和测试通过；
- 两服务注册到 Nacos；
- CRUD 和核心状态机可跑；
- metric-snapshot / trend 可返回真实数据库数据；
- 巡检任务可以执行并生成异常；
- 附件实际写到 E 盘。

建议提交：

~~~text
feat: implement device and inspection domains
~~~

## 5.3 S2-C maintenance + WebSocket + middleware closure

实现：

### maintenance

- alarm；
- defect；
- work order；
- work order log；
- maintenance record；
- acceptance；
- 完整工单状态流；
- AI diagnosis ID 关联字段逻辑。

### WebSocket

iiop-auth：

- `TextWebSocketHandler`；
- `HandshakeInterceptor`；
- `/ws/notifications`；
- Sa-Token 握手校验；
- `userId -> WebSocketSession` 内存映射；
- JSON 文本通知；
- 通知先持久化再推送。

Gateway：

- `/ws/** -> lb:ws://iiop-auth`。

### middleware closure

- RocketMQ Topic / Consumer Group；
- inspection abnormal -> maintenance defect；
- alarm / work order / AI 通知；
- MQ 幂等；
- Redis 设备快照和必要统计缓存；
- Sentinel 基础规则。

验收：

- maintenance 可启动；
- 异常 -> defect -> work order -> repair -> acceptance 可跑；
- MQ 事件可实际消费；
- 在线 WebSocket 能收通知；
- 离线 REST 仍能查通知；
- Redis 丢缓存后数据库仍能工作；
- 6 个后端启动服务全部可注册。

建议提交：

~~~text
feat: complete backend business and middleware closure
~~~

---

# 6. S3 AI

S3 合并原 AI foundation、LangGraph4j、DeepSeek、异步 MQ 和人工确认。

默认一轮完成。只有真实兼容问题才拆修复轮。

## 6.1 固定范围

AI 只做结构化设备诊断。

依赖：

- DeepSeek；
- LangChain4j；
- LangGraph4j。

固定 5 节点：

~~~text
LOAD_CONTEXT
→ ANALYZE_WITH_DEEPSEEK
→ RISK_CHECK
→ GENERATE_ADVICE
→ PREPARE_WORK_ORDER_DRAFT
~~~

## 6.2 实现

- `ai_diagnosis`；
- `ai_workflow_trace`；
- Context Feign；
- Stub Model 测试；
- DeepSeek 真调用；
- 结构化 JSON 校验；
- RiskGuard；
- 诊断异步 TaskExecutor；
- MQ 触发和结果事件；
- confirm / reject；
- maintenance 异步关联 diagnosisId。

公共 API 仅：

- POST `/api/ai/diagnoses`
- GET `/api/ai/diagnoses`
- GET `/api/ai/diagnoses/{id}`
- GET `/api/ai/diagnoses/{id}/workflow`
- POST `/api/ai/diagnoses/{id}/confirm`
- POST `/api/ai/diagnoses/{id}/reject`

## 6.3 禁止

- AI chat；
- session/message；
- Chat Memory；
- Tool Calling；
- RAG；
- 向量库；
- MCP；
- 多智能体；
- 自动控制设备；
- AI 直接创建真实工单；
- 保存 reasoning_content。

## 6.4 S3 PASS

必须完成：

- Stub 测试；
- 至少一次真实 DeepSeek 集成验证；
- 5 节点 trace；
- 结构化结果可入库；
- 失败明确标记 FAILED；
- HIGH/CRITICAL 有人工确认边界；
- MQ 与 maintenance 关联正常。

建议提交：

~~~text
feat: implement AI diagnosis workflow
~~~

---

# 7. S4 PC Web

S4 固定分 2 轮。

## 7.1 S4-A Web 基础 + 业务页面

初始化：

- Vue 3；
- Vite；
- TypeScript；
- Vue Router；
- Axios；
- Pinia；
- pinia-plugin-persistedstate；
- Element Plus。

实现：

- 登录；
- Layout；
- 权限路由；
- 设备；
- 指标；
- SOP；
- 巡检模板；
- 巡检计划；
- 巡检任务；
- 异常；
- 告警；
- 缺陷；
- 工单；
- 维修；
- 验收；
- AI diagnosis list/detail/manual；
- 用户；
- 角色；
- 权限；
- 通知中心。

原则：

- 只调用真实已存在 API；
- 不长期保留 Mock；
- 外部业务 ID 使用 string；
- 401/403/409/503 正确处理。

建议提交：

~~~text
feat: implement web business application
~~~

## 7.2 S4-B 可视化 + 实时能力

实现：

### Dashboard + ECharts

- KPI；
- device status/risk；
- inspection trend；
- alarm trend；
- work-order distribution；
- recent activity。

### Three.js

- Scene / Camera / Renderer / Light；
- Grid；
- OrbitControls；
- GLTFLoader；
- fallback；
- device positions；
- status/risk；
- Raycaster；
- detail card。

### Vue Flow

固定 5 个基础节点：

- START；
- CHECK_ITEM；
- CONDITION；
- REPORT_ABNORMAL；
- END。

只做可视化编辑，保存 `flow_definition`，不承担后端工作流引擎。

### AI

- 5 节点 trace；
- PENDING/RUNNING 刷新；
- confirm/reject。

### WebSocket

- 浏览器原生 WebSocket；
- JSON；
- reconnect；
- unread；
- REST 补漏。

验收：

- `npm build` 通过；
- 页面使用真实 API；
- 1366x768 和 1920x1080 基本可用；
- Three.js 无模型有 fallback；
- Vue Flow 刷新后可回显；
- WebSocket 可重连。

建议提交：

~~~text
feat: complete web visualization and realtime features
~~~

---

# 8. S5 HarmonyOS

S5 固定分 2 轮。

## 8.1 S5-A 环境 + 基础 + 巡检

先确认：

- DevEco Studio；
- HarmonyOS SDK；
- ArkTS；
- API Level；
- 模拟器或真机；
- ohpm/cache 路径；
- Gateway 局域网地址。

然后实现：

- Pages / ViewModel / API / Model；
- Login；
- Home；
- Profile；
- TodayInspection；
- TaskDetail；
- NUMBER / BOOLEAN / TEXT / PHOTO；
- abnormal；
- complete；
- DeviceDetail。

验收：

真实 Gateway 登录并完成一条巡检。

## 8.2 S5-B 维修 + AI

实现：

- Alarm；
- MyWorkOrder；
- WorkOrderDetail；
- start repair；
- repair result；
- submit acceptance；
- AI diagnosis；
- confirm/reject；
- notification REST。

验收：

现场端可以完成工单处理，并查看/确认 AI 结果。

建议提交：

~~~text
feat: complete HarmonyOS field workflows
~~~

---

# 9. S6 全链路联调与测试

S6 固定分 2 轮。

## 9.1 S6-A E2E + 权限

必须跑通：

~~~text
Login -> Gateway -> Auth -> Redis
Device -> Metric -> ECharts / Three.js
Plan -> Task -> Harmony Inspection -> Abnormal -> MQ
Abnormal -> Defect -> WorkOrder -> Repair -> Acceptance
Abnormal -> AI -> DeepSeek -> Human Confirm -> WorkOrder reference
Alarm/WorkOrder/AI -> MQ -> Notification -> WebSocket -> PC
~~~

同时验证：

- SUPER_ADMIN；
- ADMIN；
- INSPECTOR；
- MAINTAINER；
- 未登录；
- Token 失效；
- 禁用用户；
- 403；
- 直接访问 920x；
- `/internal/**`；
- Same-Token；
- WebSocket 鉴权。

## 9.2 S6-B 故障 + 基础体验

至少模拟：

- Redis 暂不可用；
- Nacos 服务发现问题；
- MQ 重复消费；
- DeepSeek timeout / 429 / 5xx；
- AI JSON invalid；
- Context API timeout；
- WebSocket 断开；
- glTF 加载失败。

并做真实基础体验检查：

- CRUD；
- Dashboard 请求数量；
- metric trend；
- 页面资源；
- DeepSeek 延迟；
- WebSocket；
- HarmonyOS 列表和表单。

不伪造压测成绩。

建议提交：

~~~text
test: verify end-to-end and failure scenarios
~~~

---

# 10. S7 演示、修复与冻结

S7 最多 2 轮。

## 10.1 S7-A 演示数据 + 缺陷修复

准备一条完整演示链，例如 CNC 主轴异常：

~~~text
设备
→ 指标异常
→ 巡检异常
→ defect
→ AI diagnosis
→ 人工确认
→ work order
→ repair
→ acceptance
→ lifecycle history
~~~

数据必须明确是虚构演示数据。

修复范围只包括：

- 阻塞链路；
- 页面错误；
- 权限错误；
- 测试错误；
- AI 错误；
- 可视化错误；
- HarmonyOS 错误。

禁止此时重写架构或升级核心框架。

## 10.2 S7-B 最终冻结

冻结条件：

- main 工作区干净；
- backend build 通过；
- web build 通过；
- HarmonyOS build 通过；
- 核心 E2E 通过；
- 无 API Key / password / Secret；
- README 与真实运行方式一致；
- spec 与最终实现无重大冲突。

用户确认后再创建：

~~~text
v1.0.0-defense
~~~

---

# 11. S8 最终答辩材料

代码冻结后才执行。

正式产物只有四份：

1. 团队项目实训报告；
2. 个人实训报告；
3. 答辩 PPT；
4. 答辩讲稿。

材料必须依据：

- 最终真实代码；
- SQL；
- Git 历史；
- 真实运行结果；
- 真实页面截图；
- 真实测试结果。

禁止伪造：

- commit；
- 日志；
- 测试；
- 性能数字；
- 团队成员贡献。

---

# 12. 阶段门禁

每个阶段只允许三种结论。

## PASS

核心验收全部满足，可以进入下一阶段。

## PASS WITH NOTES

主链通过，仅有不阻塞后续的小问题。问题必须记录，允许进入下一阶段。

## FAIL

出现以下任一情况时停止：

- build 失败；
- 核心测试失败；
- 运行主链失败；
- 数据库违反 spec；
- 跨服务越界；
- Secret 进入 Git；
- 使用错误的固定框架版本；
- Codex 擅自扩展范围；
- 依赖伪造数据才能工作；
- 当前阶段核心验收未满足。

---

# 13. Git 与 Codex 规则

每一轮 Codex：

1. `git status`；
2. 阅读 `AGENTS.md`；
3. 阅读当前阶段需要的 00-04 spec；
4. 只修改当前轮文件；
5. 完成允许的构建/运行/测试；
6. 检查 Secret；
7. `git diff --check`；
8. commit；
9. push `origin/main`；
10. 报告；
11. 停止。

禁止：

- force push；
- reset --hard；
- clean -fd；
- 重写已 push 的 main 历史；
- 一次实现 S2 到 S5；
- 顺手重构无关模块。

---

# 14. 磁盘与依赖门禁

固定：

- 项目：`E:/IIOP`
- Maven repository：`E:/DevCache/maven/repository`
- npm cache：`E:/DevCache/npm`
- npm global：`E:/DevCache/npm-global`
- 上传目录：`E:/IIOP-data/uploads/`

本项目不使用 Docker。

第一次执行会下载项目依赖的命令前，必须确认缓存位置：

- Maven build/test/package；
- npm install / npm ci；
- ohpm install。

如果确认会主动把项目依赖写 C 盘且无法安全调整，停止。

---

# 15. 规范优先级

实现事实来源：

1. `00-overview.md`：总架构；
2. `01-database.md`：数据库；
3. `02-backend.md`：后端/API/中间件；
4. `03-client.md`：PC/HarmonyOS；
5. `04-ai.md`：AI；
6. 本文件：执行顺序和阶段门禁。

本文件只合并实施阶段，不改变 00-04 的技术架构和业务契约。

---

# 16. 当前阶段

当前已完成：

- M0；
- G0；
- M1 SQL 文件；
- M2-A 环境准备；
- **S1 基础设施：PASS**。

S1 已实机验证：

- MySQL 8.0.43 可连接；
- 5 个 IIOP 逻辑数据库已创建；
- 25 张业务表已实际导入并验证；
- 4 个角色、33 个权限码和演示设备数据已验证；
- Redis `PING -> PONG`；
- RocketMQ NameServer/Broker 正常；
- Sentinel Dashboard 正常；
- Nacos 3.0.3 已从失败的 Derby 切换到独立 MySQL `nacos_config`，8848 与本机 Console 端口可访问；
- Nacos 使用独立数据库账号；
- Git 工作区无 Secret 提交。

当前执行：

**S2-A common + auth + gateway。**

本轮完成后必须先验收和审查，再进入 S2-B。

---

# 17. 后续默认 Codex Prompt

后续不再使用原 M3-M36 长编号。

标准格式：

~~~text
当前项目 E:/IIOP。

阅读 AGENTS.md、docs/spec/05-roadmap.md 和本轮相关 00-04 spec。

严格执行 Sx 或 Sx-X。
只修改本轮必要文件。
按当前阶段验收标准完成构建、运行或测试。
检查 Secret 和 git diff --check。
commit 并 push origin/main。
完成后报告并停止，不进入下一阶段。
~~~

发现问题时只发最小修复任务，不重新执行整个阶段。
