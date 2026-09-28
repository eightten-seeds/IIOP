# IIOP 后端实现规范

## 1. 通用返回

所有 HTTP API 统一：

```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```

分页统一：
- pageNum
- pageSize
- total
- records

## 2. 基础依赖策略

只在实际使用的模块引入依赖。

### common
- Spring 基础
- validation
- 可选 lombok
- 不引入数据库、Nacos、Redis、RocketMQ

### gateway
- Spring Cloud Gateway
- Nacos Discovery
- Sentinel Gateway
- Sa-Token Reactor 集成

### auth/device/inspection/maintenance
- Spring Web
- MyBatis-Plus
- MySQL Driver
- Nacos Discovery/Config
- validation
- Redis 按实际需要引入

### ai
- Spring Web
- MyBatis-Plus
- MySQL Driver
- Nacos
- RocketMQ
- LangChain4j
- LangGraph4j
- DeepSeek OpenAI-compatible client

## 3. 最小可运行链路

最先完成：

1. iiop-common
2. iiop-auth
3. iiop-gateway

验收：
- auth 可以启动
- gateway 可以启动
- auth 注册到 Nacos
- gateway 注册到 Nacos
- gateway 能通过 lb:// 转发 auth
- 登录可返回 Sa-Token
- 受保护接口能校验登录态

## 4. REST API 规划

### auth
- POST /api/auth/login
- POST /api/auth/logout
- GET /api/auth/me
- CRUD /api/auth/users
- CRUD /api/auth/roles
- CRUD /api/auth/permissions
- GET /api/auth/notifications
- PUT /api/auth/notifications/{id}/read

### device
- CRUD /api/device/categories
- CRUD /api/device/devices
- GET /api/device/devices/{id}/metrics
- GET /api/device/devices/{id}/metric-data
- POST /api/device/metric-data
- CRUD /api/device/sops
- GET /api/device/devices/{id}/context
  - 给 inspection、maintenance、ai 使用的精简上下文 DTO

### inspection
- CRUD /api/inspection/templates
- CRUD /api/inspection/plans
- GET /api/inspection/tasks
- GET /api/inspection/tasks/{id}
- POST /api/inspection/tasks/{id}/start
- POST /api/inspection/tasks/{id}/items/{itemId}/submit
- POST /api/inspection/tasks/{id}/complete
- GET /api/inspection/abnormals
- GET /api/inspection/devices/{deviceId}/history

### maintenance
- GET /api/maintenance/alarms
- POST /api/maintenance/alarms/{id}/ack
- GET /api/maintenance/defects
- CRUD /api/maintenance/work-orders
- POST /api/maintenance/work-orders/{id}/assign
- POST /api/maintenance/work-orders/{id}/start
- POST /api/maintenance/work-orders/{id}/repair
- POST /api/maintenance/work-orders/{id}/submit-acceptance
- POST /api/maintenance/work-orders/{id}/accept
- GET /api/maintenance/devices/{deviceId}/history

### ai
- POST /api/ai/chat
- POST /api/ai/diagnosis
- GET /api/ai/diagnosis/{id}
- POST /api/ai/diagnosis/{id}/confirm
- GET /api/ai/diagnosis/{id}/workflow

## 5. RocketMQ 事件

Topic 只保留必要事件。

### iiop.inspection.abnormal
生产者：inspection
消费者：maintenance、ai

消息至少：
- eventId
- abnormalId
- deviceId
- severity
- occurredAt

### iiop.maintenance.alarm
生产者：maintenance
消费者：ai、auth(notification)

### iiop.maintenance.workorder
生产者：maintenance
消费者：auth(notification)

### iiop.ai.diagnosis
生产者：ai
消费者：maintenance、auth(notification)

必须设计幂等消费，eventId 作为事件去重依据。

## 6. Redis

只用于明确场景：

- Sa-Token 会话
- 权限缓存
- 设备实时状态快照
- 首页统计短缓存
- 幂等/去重键
- WebSocket 用户会话辅助信息

不要把 Redis 当主数据库。

建议 Key：

iiop:auth:permission:{userId}
iiop:device:status:{deviceId}
iiop:dashboard:overview
iiop:event:consumed:{eventId}

## 7. Nacos

每个启动服务：
- 服务注册
- 配置加载

配置至少拆：
- datasource
- redis
- mq
- satoken
- deepseek
- logging

敏感值通过环境变量引用。

Spring Cloud Alibaba 2025.x 使用当前推荐的 spring.config.import 方式。

## 8. Sentinel

重点保护：
- gateway 总入口
- /api/auth/login
- /api/ai/**
- /api/device/metric-data
- 高频 dashboard 查询

初期规则简单可解释，答辩时要能说明限流对象和目的。

## 9. WebSocket

由 auth 或独立通知组件承担连接管理，不再新增微服务。

推送类型：
- ALARM
- INSPECTION
- WORK_ORDER
- AI
- SYSTEM

持久化落 sys_notification，WebSocket 只负责实时送达。

## 10. 业务闭环约束

- 巡检异常产生后，inspection 发布异常事件。
- maintenance 根据异常生成/合并缺陷。
- ai 异步生成辅助诊断。
- 维修工单可以引用 ai_diagnosis_id。
- AI 不允许自动执行停机、维修、参数修改。
- 工单必须通过维修和验收才能完成闭环。
