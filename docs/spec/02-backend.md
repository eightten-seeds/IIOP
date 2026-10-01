# IIOP 后端实现规范（最简版）

> 目标：Codex 只实现课程项目需要的最小真实后端

## 1. 固定版本

- JDK 17
- Spring Boot 3.5.0
- Spring Cloud 2025.0.0
- Spring Cloud Alibaba 2025.0.0.0
- MyBatis-Plus 3.5.17
- Sa-Token 1.46.0
- Nacos 3.0.3
- Sentinel 1.8.9
- RocketMQ 5.3.1

禁止自行升级核心版本。

## 2. 服务与端口

- gateway：8080
- auth：9201
- device：9202
- inspection：9203
- maintenance：9204
- ai：9205

客户端只访问 Gateway。

## 3. common

只保留：

- Result<T>
- PageResult<T>
- ErrorCode
- BizException
- traceId/requestId
- 必要公共 DTO

common 不启动，不放业务 Service、Mapper、Entity。

## 4. Gateway

Gateway 只做：

- 显式路由
- 登录态检查
- CORS
- requestId/traceId
- 一个 Sentinel 限流规则
- WebSocket 转发

固定路由：

- /api/auth/** -> iiop-auth
- /api/device/** -> iiop-device
- /api/inspection/** -> iiop-inspection
- /api/maintenance/** -> iiop-maintenance
- /api/ai/** -> iiop-ai
- /ws/** -> iiop-auth

/internal/** 不配置 Gateway 路由。

不做复杂全局异常体系、动态路由、灰度、熔断矩阵或 Same-Token 全局认证。

## 5. Auth

> S4 起所有角色数据范围、岗位动作约束和 Gate 2 最小 API 补充，以 `06-role-usecases.md` 为准。第一版正式业务 Actor 固定为四种预置角色，33 个 permission code 与 seed/spec 角色权限矩阵运行时冻结。

实现：

- captcha（图形验证码生成与 Redis 120s TTL 一次性校验，防刷限流）
- login（验证码校验、账号状态检查、BCrypt 密码比对、Sa-Token 登录）
- logout（注销当前 Session）
- me（获取当前用户上下文、角色与 permissions）
- password（个人修改密码，旧密码校验，新旧不同，成功后登出）
- users/{id}/password（管理员重置用户密码，自锁保护与 SUPER_ADMIN 保护，成功后踢出目标用户）
- 用户 CRUD（无公开注册，全部由管理员创建/分配）
- 用户四角色分配
- 角色/权限只读查询（GET /api/auth/roles/{id}/permissions 返回冻结权限清单）
- SUPER_ADMIN 授予/移除及账号状态保护
- 通知列表/未读/已读
- BCrypt
- Sa-Token + Redis

Gate 2 与 Auth 账号生命周期约束：

- 系统无公开注册：用户账号仅允许由具备 `system:user` 权限的管理人员创建；
- 登录必须携带图形验证码：`GET /api/auth/captcha` 返回 captchaKey 与图片 Base64，Redis 存储 key `iiop:captcha:{key}`，TTL 120s，一次性消费（校验即删除）；
- 个人修改密码：`PUT /api/auth/password`，校验原密码正确性，新密码与旧密码不得相同，成功后调用 `StpUtil.logout()` 强制下线；
- 管理员重置密码：`PUT /api/auth/users/{id}/password`，需具备 `system:user` 权限；不可重置当前登录账号自身（避免自锁混淆，自身必须走修改密码流程）；不可重置 SUPER_ADMIN（若非 SUPER_ADMIN 越权）；重置成功后调用 `StpUtil.logoutByLoginId(id)` 踢出目标用户；
- 角色权限只读：`GET /api/auth/roles/{id}/permissions` 仅供只读矩阵查询，公开业务 API 不允许创建/删除角色、创建/删除 permission 或修改固定角色权限矩阵；
- Gateway 限流保护：对 `/api/auth/login` 与 `/api/auth/captcha` 配置基础限流（登录 2 QPS，验证码 5 QPS），匿名放行 captcha 与 login。
- permissions 只由 ENABLED 角色贡献；
- 用户角色分配只允许四个固定 roleCode；
- ADMIN 不能授予/移除 SUPER_ADMIN；
- 当前 SUPER_ADMIN 不能移除自己的 SUPER_ADMIN、禁用/锁定/删除自己；
- `system:role:permission` 用于 SUPER_ADMIN 角色授予/移除及保护校验，不用于动态改写固定矩阵。

现有 Role / Permission CRUD Controller、Service、permission code 可以保留代码以减少无关返工，但 Gate 2 必须让对应写 API 不再成为第一版可操作产品能力。

权限码直接使用现有数据库 seed，不新增第二套认证机制。

## 6. Nacos

第一版只要求 Discovery。

所有可启动服务：

- 注册到 Nacos
- namespace：iiop-dev
- group：IIOP_GROUP

`NACOS_NAMESPACE` 通过本机环境变量传入，避免把本机 UUID 写死。

Nacos Config 不是必做验收项。已有配置接入若稳定可保留，不继续做 DataId 治理、热更新或容灾测试。

## 7. Redis

第一版只强制用于 Sa-Token Session。

如果 RocketMQ 幂等需要，可增加一个简单 eventId Key。

不做分布式锁、多级缓存、Dashboard 缓存体系。

## 8. Device

对应 iiop_device 五张表。

公共 API 最小范围：

- categories CRUD/tree
- devices CRUD/list/detail
- device status/risk update
- metrics CRUD
- metric data list/snapshot/trend
- SOP CRUD
- statistics overview

内部 AI API：

- GET /internal/device/devices/{id}/ai-context
- GET /internal/device/devices/{id}/sop-context

复杂 SQL 能用 MyBatis-Plus 完成就不用 XML。

## 9. Inspection

对应六张 inspection 表。

最小 API：

- templates CRUD
- template items CRUD
- plans CRUD
- POST /plans/{id}/generate-task
- tasks list/detail
- start task
- submit task item
- complete task
- abnormals list/detail/create

S4 Gate 2 的本人数据范围、INSPECTOR + assignee + state 写入约束，以及计划 assignee 的 ENABLED INSPECTOR 校验以 `06-role-usecases.md` 为准。

第一版任务生成采用人工触发，不实现复杂定时调度。

创建 abnormal 后发送：

destination：`iiop_inspection_abnormal`

事件只需要：

- eventId
- abnormalId
- deviceId
- severity
- title
- occurredAt

## 10. Maintenance

对应六张 maintenance 表。

最小 API：

- alarms list/detail/process
- defects list/detail
- work-orders create/list/detail
- assign/start/repair-result
- maintenance record
- acceptance

S4 Gate 2 不提供任意状态更新式工单/缺陷 CRUD。Defect confirm/close、WorkOrder assign/start/repair/acceptance、本人数据范围、职责分离、一个 Defect 一张正式 WorkOrder、AI 关联校验及 409 条件状态更新均以 `06-role-usecases.md` 为准。

消费 `iiop_inspection_abnormal`：

- 同一 abnormalId 不重复创建 defect
- 创建成功即可

不再要求 maintenance 与 AI 之间通过 MQ 传 diagnosisId。

AI 结果由前端调用 ai 服务查看。工单若携带 aiDiagnosisId，maintenance 必须通过 AI internal summary 校验 diagnosisStatus=SUCCEEDED、confirmationStatus=CONFIRMED、deviceId 一致；不能仅信任前端传入 diagnosisId。Defect 与 AI 的显式绑定路径按 `06-role-usecases.md` 执行。

## 11. RocketMQ

第一版只保留一个 Topic：

`iiop_inspection_abnormal`

生产者：

- inspection

消费者：

- maintenance

作用：

- 证明真实异步微服务事件链

不实现其他 Topic，不做 Outbox、事务消息、复杂补偿或消息治理平台。

简单幂等：

- 以 abnormalId 或 eventId 判断重复
- 数据库唯一约束优先
- 必要时 Redis Key 辅助

## 12. Sentinel

只需要在 Gateway 配置一个可演示限流规则。

优先保护：

POST /api/auth/login

返回：

- HTTP 429
- 简单统一错误 JSON

不做大量接口规则、动态规则中心、集群流控。

## 13. WebSocket

放在 auth。

使用 Spring 原生 WebSocket：

- TextWebSocketHandler
- /ws/notifications
- JSON 文本消息
- 浏览器原生 WebSocket

第一版单实例：

- 内存保存 userId -> session
- REST 查询 sys_notification 为事实来源
- WebSocket 只做实时提醒

不使用 STOMP、SockJS、Redis Pub/Sub。

通知生成可以通过 auth 内部方法或最简单的内部 REST 调用完成，不再设计通知 MQ 体系。

## 14. AI 内部调用

AI 通过 OpenFeign 读取：

- device ai-context
- inspection recent history
- maintenance history

只读。

不要求 Same-Token。/internal/** 只是不经 Gateway 暴露。

## 15. 配置和 Secret

真实密码/API Key 不进入 Git。

使用环境变量：

- MYSQL_*_PASSWORD
- REDIS_PASSWORD
- DEEPSEEK_API_KEY
- NACOS_NAMESPACE

本地 application.yml 可以保留安全默认值和环境变量占位符。

## 16. 统一响应

普通 JSON API：

{
  "code": 0,
  "message": "success",
  "data": {},
  "traceId": "..."
}

业务 ID 对 PC/HarmonyOS 返回字符串。

## 17. 后端第一版 PASS

满足以下即可：

1. 6 个服务可以启动并注册
2. Gateway 可以路由
3. 登录/RBAC 可用
4. device 主 CRUD 可用
5. inspection 能执行任务并创建异常
6. RocketMQ 能把异常送到 maintenance
7. maintenance 能完成工单和验收
8. AI 能通过 Feign 获取上下文
9. WebSocket 能收到一条真实通知
10. Sentinel 能演示一次限流
11. Maven build/test 通过
12. Git 无 Secret

不因为未实现生产级治理能力阻塞 PASS。
