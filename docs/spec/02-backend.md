# IIOP 后端架构与实现规范

> 文档编号：IIOP-SPEC-02  
> 文档性质：后端工程、微服务通信、认证授权与基础设施实现基线  
> 上位规范：`docs/spec/00-overview.md`、`docs/spec/01-database.md`  
> 适用对象：Codex、后端开发、代码审查、联调与测试  
> 当前状态：设计基线。后续 Codex 生成后端代码时必须优先遵循本文档。

---

## 1. 文档目的

本文档回答后端实现阶段必须提前固定的问题：

1. 6 个可启动微服务和 1 个公共模块怎样组织；
2. Maven 依赖应该放到哪个模块；
3. Gateway 使用哪一种技术栈和配置前缀；
4. Nacos 如何同时承担注册发现和配置管理；
5. Sa-Token 如何处理登录、RBAC、网关鉴权和微服务内部调用；
6. Redis 的职责和 Key 如何规划；
7. OpenFeign 的调用方向、DTO 和降级边界如何定义；
8. RocketMQ 的 Topic、事件结构和幂等规则如何设计；
9. Sentinel 应保护哪些资源；
10. WebSocket 放在哪个服务中；
11. Controller、Service、Mapper、DTO、VO、Entity 如何分层；
12. 各服务暴露哪些 REST API；
13. 事务、状态机、异常、日志、测试和启动验收如何执行。

后续实现若与本文档冲突，Codex 不得自行选择“更方便”的做法。应停止并报告，由项目设计先修改规范。

---

# 2. 已核实的后端技术基线

## 2.1 Spring 技术栈

固定：

| 技术 | 版本 |
|---|---|
| JDK | 17 |
| Spring Boot | 3.5.0 |
| Spring Cloud | 2025.0.0 |
| Spring Cloud Alibaba | 2025.0.0.0 |
| Spring Cloud Gateway | 4.3.0，由 Spring Cloud BOM 管理 |
| Spring Cloud OpenFeign | 4.3.0，由 Spring Cloud BOM 管理 |
| Nacos | 3.0.3 |
| Sentinel | 1.8.9 |
| RocketMQ | 5.3.1 |

说明：

- Spring Cloud 2025.0.0 官方与 Spring Boot 3.5.0 对应；
- Spring Cloud Alibaba 2025.0.0.0 官方兼容矩阵对应 Spring Cloud 2025.0.0 和 Spring Boot 3.5.0；
- Spring Cloud 2025.0.0 中 Gateway 和 OpenFeign 均进入 4.3.0 版本线；
- 项目固定该基线是为了符合既定实训技术要求，开发过程中禁止 Codex 自行升级到 Spring Boot 4 或 Spring Cloud 2025.1.x。

## 2.2 Spring Cloud Gateway 选择

项目明确使用 **Gateway Server WebFlux**。

Maven artifact：

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-gateway-server-webflux</artifactId>
</dependency>
```

原因：

1. Spring Cloud 2025.0 已将原 `spring-cloud-starter-gateway` 标记为旧名称；
2. 新的 WebFlux starter 名称明确区分 Gateway Server WebFlux 与 Server Web MVC；
3. Sa-Token 对 Spring Cloud Gateway 的官方方案提供 Reactor 集成；
4. WebSocket 代理由 WebFlux Gateway 直接支持。

Gateway 模块禁止引入：

- `spring-boot-starter-web`
- Servlet MVC Controller 业务代码
- MyBatis-Plus
- MySQL Driver

Gateway 使用新的配置前缀：

`spring.cloud.gateway.server.webflux.*`

Codex 不得继续生成旧版 `spring.cloud.gateway.routes` 作为项目正式配置。

## 2.3 MyBatis-Plus

固定使用 Spring Boot 3 starter：

`com.baomidou:mybatis-plus-spring-boot3-starter`

当前实现基线：

`3.5.17`

分页插件需要显式加入：

`com.baomidou:mybatis-plus-jsqlparser`

不得同时重复引入：

- mybatis-spring-boot-starter
- 另一套 MyBatis starter
- Spring Boot 2 专用的 mybatis-plus-boot-starter

## 2.4 Sa-Token

当前实现基线：

`1.46.0`

Spring Boot 3 MVC 服务使用：

`sa-token-spring-boot3-starter`

Gateway WebFlux 使用：

`sa-token-reactor-spring-boot3-starter`

分布式会话使用：

`sa-token-redis-template`

项目第一版不采用 Sa-Token JWT 模式。

第一版采用 Sa-Token 原生 Token + Redis 分布式 Session，减少 JWT 密钥、续签和撤销逻辑的额外复杂度。

---

# 3. 服务名称与端口

本地开发端口固定如下：

| 模块 | spring.application.name | HTTP 端口 |
|---|---|---:|
| iiop-gateway | iiop-gateway | 8080 |
| iiop-auth | iiop-auth | 9201 |
| iiop-device | iiop-device | 9202 |
| iiop-inspection | iiop-inspection | 9203 |
| iiop-maintenance | iiop-maintenance | 9204 |
| iiop-ai | iiop-ai | 9205 |

基础设施默认开发端口：

| 基础设施 | 端口 |
|---|---:|
| MySQL | 3306 |
| Redis | 6379 |
| Nacos | 8848 |
| RocketMQ NameServer | 9876 |
| Sentinel Dashboard | 8858 |

Sentinel 客户端 transport 端口在同一开发机上不得冲突，规划：

| 服务 | Sentinel transport port |
|---|---:|
| gateway | 8719 |
| auth | 8720 |
| device | 8721 |
| inspection | 8722 |
| maintenance | 8723 |
| ai | 8724 |

端口属于本地开发约定。若本机发生端口冲突，可通过环境变量调整，但 README 和运行脚本必须同步。

---

# 4. Maven 父工程设计

`backend/pom.xml` 继续作为聚合父工程。

父工程职责：

1. 管理 7 个子模块；
2. 统一 Java 17；
3. 引入 Spring Boot Parent 3.5.0；
4. 导入 Spring Cloud BOM 2025.0.0；
5. 导入 Spring Cloud Alibaba BOM 2025.0.0.0；
6. 管理 MyBatis-Plus 3.5.17；
7. 管理 Sa-Token 1.46.0；
8. 统一 compiler、test 等插件的版本策略。

建议父工程增加：

```xml
<properties>
    <java.version>17</java.version>
    <spring-cloud.version>2025.0.0</spring-cloud.version>
    <spring-cloud-alibaba.version>2025.0.0.0</spring-cloud-alibaba.version>
    <mybatis-plus.version>3.5.17</mybatis-plus.version>
    <sa-token.version>1.46.0</sa-token.version>
</properties>
```

MyBatis-Plus 与 Sa-Token 的版本由父工程统一管理，子模块不得重复写版本号。

AI 依赖版本不在本文档中提前固定，由 `04-ai.md` 单独确定。

---

# 5. 模块依赖矩阵

原则：

- 依赖只放到真正使用它的模块；
- 禁止把所有 starter 全塞进父 POM；
- 父 POM 的 `dependencyManagement` 只管理版本；
- 子模块的 `dependencies` 表达真实能力。

## 5.1 iiop-common

性质：普通 Jar，不启动。

允许：

- 纯 Java 公共模型；
- `Result<T>`；
- `PageResult<T>`；
- 公共错误码；
- `BizException`；
- 公共常量；
- MQ 事件信封基础对象；
- 请求链路 ID 常量。

尽量不依赖 Spring Boot starter。

禁止：

- DataSource；
- Mapper；
- Controller；
- Redis；
- Nacos；
- Sa-Token starter；
- RocketMQ；
- 具体业务 Entity。

## 5.2 iiop-gateway

依赖：

- `spring-cloud-starter-gateway-server-webflux`
- `spring-cloud-starter-loadbalancer`
- `spring-cloud-starter-alibaba-nacos-discovery`
- `spring-cloud-starter-alibaba-nacos-config`
- `spring-cloud-starter-alibaba-sentinel`
- `spring-cloud-alibaba-sentinel-gateway`
- `sa-token-reactor-spring-boot3-starter`
- `sa-token-redis-template`
- `spring-boot-starter-data-redis`
- `commons-pool2`
- `spring-boot-starter-actuator`
- `iiop-common`

禁止：

- Spring MVC starter；
- MyBatis-Plus；
- MySQL；
- 业务 Entity；
- 业务 Service。

## 5.3 iiop-auth

依赖：

- `spring-boot-starter-web`
- `spring-boot-starter-validation`
- `spring-boot-starter-websocket`
- `spring-boot-starter-data-redis`
- `spring-security-crypto`
- `mybatis-plus-spring-boot3-starter`
- `mybatis-plus-jsqlparser`
- `mysql-connector-j`
- Nacos Discovery
- Nacos Config
- `sa-token-spring-boot3-starter`
- `sa-token-redis-template`
- `commons-pool2`
- Spring Cloud Stream RocketMQ binder
- Actuator
- `iiop-common`

auth 第一版不需要 OpenFeign。RocketMQ 仅用于消费告警、工单和 AI 诊断事件并生成持久化通知。

## 5.4 iiop-device

依赖：

- Spring Web
- Validation
- MyBatis-Plus Boot3 Starter
- MyBatis-Plus JSqlParser
- MySQL Driver
- Redis
- Nacos Discovery
- Nacos Config
- OpenFeign
- Spring Cloud LoadBalancer
- Sa-Token Boot3
- Sa-Token Redis
- Actuator
- iiop-common

device 不引入 RocketMQ，除非后续真实业务需要设备状态事件。

## 5.5 iiop-inspection

依赖：

- Spring Web
- Validation
- MyBatis-Plus
- MySQL
- Nacos Discovery/Config
- OpenFeign
- LoadBalancer
- Sa-Token Boot3 + Redis
- Spring Cloud Stream RocketMQ binder
- Actuator
- iiop-common

inspection 是 `iiop.inspection.abnormal` 的生产者。

## 5.6 iiop-maintenance

依赖：

- Spring Web
- Validation
- MyBatis-Plus
- MySQL
- Nacos Discovery/Config
- OpenFeign
- LoadBalancer
- Sa-Token Boot3 + Redis
- Spring Cloud Stream RocketMQ binder
- Actuator
- iiop-common

maintenance 同时是异常事件消费者、维护事件生产者。

## 5.7 iiop-ai

后端基础依赖：

- Spring Web
- Validation
- MyBatis-Plus
- MySQL
- Nacos Discovery/Config
- OpenFeign
- LoadBalancer
- Sa-Token Boot3 + Redis
- Spring Cloud Stream RocketMQ binder
- Actuator
- iiop-common

LangChain4j、LangGraph4j、DeepSeek 具体依赖由 `04-ai.md` 定义。

---

# 6. Java 包结构

每个业务服务采用统一分层。

以 `iiop-device` 为例：

```text
com.iiop.device
├─ DeviceApplication.java
├─ config
├─ controller
├─ service
│  └─ impl
├─ mapper
├─ domain
│  ├─ entity
│  ├─ dto
│  ├─ vo
│  └─ query
├─ enums
├─ client
│  ├─ feign
│  └─ dto
├─ mq
│  ├─ producer
│  └─ consumer
├─ security
├─ support
└─ task
```

规则：

- `controller` 只负责协议层；
- `service` 负责业务规则和事务；
- `mapper` 只负责当前服务数据库；
- `entity` 与数据库表一一对应；
- `dto` 用于写请求；
- `vo` 用于对外返回；
- `query` 用于复杂查询条件；
- `client.feign` 只放跨服务客户端；
- `client.dto` 只放跨服务契约；
- `mq` 只放事件发布和消费；
- `task` 只放真实的定时任务；
- 禁止 Controller 直接调用 Mapper；
- 禁止对外直接返回 Entity；
- 禁止跨服务共享 Entity。

---

# 7. iiop-common 公共模型

## 7.1 Result<T>

统一 HTTP 响应：

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "traceId": "..."
}
```

字段：

- `code`：业务码；
- `message`：用户可理解的信息；
- `data`：数据；
- `traceId`：请求链路标识。

成功：

`code = 0`

## 7.2 PageResult<T>

统一分页：

```json
{
  "pageNum": 1,
  "pageSize": 20,
  "total": 100,
  "records": []
}
```

前端请求参数固定：

- pageNum，从 1 开始；
- pageSize，默认 20；
- 第一版最大 100。

## 7.3 错误码分区

建议：

| 范围 | 含义 |
|---|---|
| 0 | 成功 |
| 40000-40099 | 参数格式、校验和一般请求错误 |
| 40100-40199 | 未登录/Token 问题 |
| 40300-40399 | 权限问题 |
| 40400-40499 | 业务对象不存在 |
| 40900-40999 | 状态冲突/重复操作 |
| 42900-42999 | 限流 |
| 50000-50999 | 系统内部异常 |
| 50300-50399 | 下游或外部依赖不可用 |

业务异常不得直接把 SQL 异常、堆栈或密钥信息返回前端。

---

# 8. 全局异常与参数校验

所有 MVC 业务服务使用：

`@RestControllerAdvice`

统一处理：

- `MethodArgumentNotValidException`
- `ConstraintViolationException`
- `BizException`
- Sa-Token 登录异常
- Sa-Token 权限异常
- Feign 调用异常
- 兜底 Exception

Gateway 使用 WebFlux 异常处理机制，禁止复制 MVC Advice。

规则：

1. 参数错误返回明确字段级提示；
2. 业务状态冲突使用业务码；
3. 下游服务不可用返回 503 类业务码；
4. 未识别异常仅记录 traceId，客户端收到通用错误；
5. 生产/答辩模式不向前端泄露 stack trace。

---

# 9. MyBatis-Plus 统一规则

## 9.1 Mapper

Mapper：

`extends BaseMapper<Entity>`

简单 CRUD 使用 BaseMapper。

只有确实需要复杂聚合查询时编写 XML。

禁止为了展示 MyBatis XML 而把简单 CRUD 重写成 XML。

## 9.2 分页

统一注册：

`MybatisPlusInterceptor + PaginationInnerInterceptor(DbType.MYSQL)`

所有列表 API 的分页结果转换为 `PageResult<T>`。

## 9.3 ID

所有 Entity：

`@TableId(type = IdType.ASSIGN_ID)`

Java 类型：

`Long`

## 9.4 逻辑删除

只有数据库规范中明确存在 `deleted` 的表使用：

`@TableLogic`

禁止给交易历史表擅自增加逻辑删除。

## 9.5 自动填充

对 `created_at`、`updated_at` 使用统一 `MetaObjectHandler`。

数据库默认值仍保留，Java 自动填充作为应用侧一致实现。

## 9.6 Enum

状态字段在 Java 中优先使用 Enum。

枚举持久化值必须和 `01-database.md` 完全一致。

不得使用枚举 ordinal 入库。

## 9.7 JSON

数据库 JSON 字段使用统一 Jackson 序列化策略。

使用 MyBatis-Plus `JacksonTypeHandler` 时：

- Entity 需要正确开启 `autoResultMap`；
- 字段明确指定 TypeHandler；
- Java 类型应为明确 DTO/List/Map，避免到处使用 Object。

---

# 10. Nacos 注册发现与配置管理

## 10.1 Namespace 和 Group

开发环境建议建立独立 Namespace：

`iiop-dev`

Group：

`IIOP_GROUP`

不要把项目配置散落在 DEFAULT_GROUP。

生产概念只做设计，不要求课程项目真正部署生产集群。

## 10.2 application.yml 的职责

每个可启动服务本地 `application.yml` 只保留启动 Nacos 所必需的信息和安全默认值：

- spring.application.name；
- server.port；
- Nacos server address；
- namespace；
- group；
- `spring.config.import`；
- profile；
- 极少量无法从 Nacos 获取的启动前配置。

业务配置放 Nacos。

## 10.3 配置导入

Spring Cloud Alibaba 2025.x 使用：

`spring.config.import`

禁止以 `bootstrap.yml` 作为正式方案。

每个服务建议显式导入：

1. `iiop-shared.yaml`
2. 自己的服务配置文件，例如 `iiop-auth.yaml`

例如 auth：

```yaml
spring:
  application:
    name: iiop-auth

  cloud:
    nacos:
      discovery:
        server-addr: ${NACOS_SERVER_ADDR:127.0.0.1:8848}
        namespace: ${NACOS_NAMESPACE:}
        group: ${NACOS_GROUP:IIOP_GROUP}
      config:
        server-addr: ${NACOS_SERVER_ADDR:127.0.0.1:8848}
        namespace: ${NACOS_NAMESPACE:}
        group: ${NACOS_GROUP:IIOP_GROUP}

  config:
    import:
      - nacos:iiop-shared.yaml?group=${NACOS_GROUP:IIOP_GROUP}
      - nacos:iiop-auth.yaml?group=${NACOS_GROUP:IIOP_GROUP}
```

M2 真正实现时若 namespace 的实际 ID 与名称不同，以 Nacos 控制台创建后得到的 namespace ID 为准，并通过环境变量传入。

## 10.4 Nacos 配置内容

### iiop-shared.yaml

只放跨服务共享配置：

- Redis 地址；
- Sa-Token 通用参数；
- Actuator 暴露范围；
- 基础日志级别；
- 通用超时。

### iiop-auth.yaml

- iiop_auth datasource；
- WebSocket；
- auth 专属配置。

### iiop-device.yaml

- iiop_device datasource；
- 设备缓存 TTL。

### iiop-inspection.yaml

- iiop_inspection datasource；
- RocketMQ binding；
- 计划调度参数。

### iiop-maintenance.yaml

- iiop_maintenance datasource；
- RocketMQ binding。

### iiop-ai.yaml

- iiop_ai datasource；
- RocketMQ；
- DeepSeek/LangChain4j/LangGraph4j 配置。

### iiop-gateway.yaml

- Gateway routes；
- CORS；
- Sentinel；
- Gateway timeout。

## 10.5 敏感变量

不得在 Git 和 Nacos 示例文件中写真实：

- MYSQL_PASSWORD
- REDIS_PASSWORD
- DeepSeek API Key
- 其他 Secret

Nacos 配置使用环境变量占位符。

---

# 11. Gateway 设计

## 11.1 固定路由

不启用“发现一个服务就自动公开一个路由”的全开放 Discovery Locator。

显式配置：

| Route ID | Path | URI |
|---|---|---|
| auth-api | /api/auth/** | lb://iiop-auth |
| device-api | /api/device/** | lb://iiop-device |
| inspection-api | /api/inspection/** | lb://iiop-inspection |
| maintenance-api | /api/maintenance/** | lb://iiop-maintenance |
| ai-api | /api/ai/** | lb://iiop-ai |
| auth-websocket | /ws/** | lb:ws://iiop-auth |

使用 Spring Cloud 2025.0 的新配置层级：

`spring.cloud.gateway.server.webflux.routes`

`/internal/**` 禁止在 Gateway 配置公开路由。

## 11.2 Gateway 请求处理顺序

推荐：

1. 生成或透传 X-Request-Id；
2. 处理 CORS；
3. Sentinel 入口保护；
4. Sa-Token 登录检查；
5. 增加 Same-Token；
6. 转发下游服务；
7. 统一处理网关级错误。

## 11.3 白名单

仅开放必要路径：

- POST /api/auth/login
- OPTIONS /**
- WebSocket 初始握手路径
- Gateway 自身健康检查

是否公开服务健康检查由开发环境决定，不通过 Gateway 暴露所有下游 Actuator。

## 11.4 CORS

开发阶段允许：

- PC Vite 开发地址；
- HarmonyOS 调试来源按实际网络模型处理。

最终禁止无条件同时使用：

`allowedOrigins = *`

与：

`allowCredentials = true`

CORS 配置集中在 Gateway，业务服务不重复配置跨域。

---

# 12. Sa-Token 认证与 RBAC

## 12.1 总体策略

采用三层概念：

1. **用户登录态**：Sa-Token + Redis；
2. **业务权限**：RBAC + Sa-Token Permission；
3. **微服务来源可信**：Same-Token。

## 12.2 登录流程

```text
PC/HarmonyOS
→ Gateway
→ iiop-auth /api/auth/login
→ 查询 sys_user
→ 校验状态
→ BCrypt 校验密码
→ 查询用户角色和权限
→ StpUtil.login(userId)
→ 将角色/权限快照写入 SaSession
→ 返回 tokenName + tokenValue + 用户摘要
```

密码：

- 使用 BCrypt；
- 只保存 `password_hash`；
- 不自行实现 MD5/SHA 拼接密码方案。

## 12.3 登录返回

建议：

```json
{
  "tokenName": "satoken",
  "tokenValue": "...",
  "user": {
    "id": "...",
    "username": "...",
    "realName": "..."
  },
  "roles": ["ADMIN"],
  "permissions": ["device:view"]
}
```

## 12.4 权限缓存策略

登录成功时 auth 从数据库加载：

- roleCodes；
- permissionCodes。

写入当前登录用户的 SaSession。

各业务服务中的 `StpInterface` 从共享 Redis 中的 SaSession 获取权限列表。

这样避免每次权限校验都远程调用 auth 数据库。

角色或权限发生修改后：

- 清理相关业务权限缓存；
- 对受影响用户执行重新登录要求或踢下线；
- 下一次登录重新构建权限快照。

## 12.5 Gateway 登录校验

Gateway 负责：

- 白名单；
- 其余 `/api/**` 检查登录。

Gateway 不承担全部细粒度业务权限判断。

原因：

- 权限与具体业务接口更接近；
- 避免 Gateway 维护一份重复的业务权限路由表；
- 下游服务仍可通过注解明确表达权限。

## 12.6 下游权限

Controller/Service 的用户业务入口使用：

- `@SaCheckLogin`
- `@SaCheckPermission`
- 必要时 `@SaCheckRole`

权限编码以 01-database.md 的 seed 清单为唯一基线。

固定权限：

### 通用与设备

- dashboard:view
- device:view
- device:create
- device:update
- device:delete

### 巡检

- inspection:view
- inspection:template:manage
- inspection:plan:manage
- inspection:execute
- inspection:abnormal:process

### 运维

- maintenance:view
- maintenance:alarm:process
- maintenance:defect:process
- maintenance:workorder:create
- maintenance:workorder:process
- maintenance:workorder:accept

### AI

- ai:view
- ai:diagnosis
- ai:confirm
- ai:chat

### 系统管理

- system:user:view
- system:user:create
- system:user:update
- system:user:delete
- system:user:role
- system:role:view
- system:role:create
- system:role:update
- system:role:delete
- system:role:permission
- system:permission:view
- system:permission:create
- system:permission:update
- system:permission:delete

后续若需要新增权限码，必须先修改 01、02、03 的规范和 seed，再写代码。

## 12.7 Same-Token

Gateway 为转发请求增加 Sa-Token 官方 Same-Token Header。

业务服务使用全局 Servlet Filter 校验 Same-Token。

效果：

- 浏览器不能绕过 Gateway 直接访问 9201-9205 的业务 API；
- Gateway 转发请求可通过；
- Feign 内部调用可通过。

课程开发环境采用 Sa-Token 默认的 Same-Token 生命周期即可，不额外创建 Token 刷新微服务。

## 12.8 Feign 内部鉴权

所有 Feign 请求通过统一 `RequestInterceptor` 写入 Same-Token。

内部接口只要求：

- Same-Token 校验；
- 必要的业务参数校验。

内部接口不要求存在最终用户登录态。

这样 MQ 消费者或后台任务也可以正常发起内部服务调用。

---

# 13. OpenFeign 设计

## 13.1 使用方向

允许：

| 调用方 | 被调用方 |
|---|---|
| device | auth（必要的用户摘要/存在性） |
| inspection | device |
| inspection | auth |
| maintenance | device |
| maintenance | auth |
| ai | device |
| ai | inspection |
| ai | maintenance |

禁止形成 A → B → A 的同步循环依赖。maintenance 不同步调用 ai；AI 诊断完成后通过 RocketMQ 事件把 diagnosisId 传给 maintenance，前端需要完整诊断详情时直接调用 iiop-ai。

## 13.2 内部 API 前缀

所有跨服务内部接口统一：

`/internal/**`

示例：

- `GET /internal/auth/users/{id}/summary`
- `GET /internal/device/devices/{id}/context`
- `GET /internal/inspection/devices/{id}/recent-history`
- `GET /internal/maintenance/devices/{id}/history`

Gateway 不路由 `/internal/**`。

## 13.3 DTO

Feign DTO 必须独立于 Entity。

例如 `DeviceContextDTO` 可以包含：

- id
- deviceCode
- deviceName
- categoryName
- model
- status
- riskLevel
- workshop
- productionLine
- installLocation
- currentMetrics

不得把 `DevDevice` Entity 直接作为 Feign 返回类型。

## 13.4 超时

内部调用必须配置：

- connect timeout；
- read timeout。

AI 获取上下文时，非关键历史接口超时可以降级为空列表。

设备核心信息获取失败时，AI 诊断必须失败，不能编造设备数据。

---

# 14. Redis 设计

## 14.1 使用范围

Redis 只用于：

1. Sa-Token 分布式会话；
2. 权限快照；
3. 设备实时状态；
4. Dashboard 短缓存；
5. MQ 幂等；
6. 分布式短锁；
7. WebSocket 在线辅助状态。

不保存唯一业务事实。

## 14.2 Key 规范

统一前缀：

`iiop:`

业务 Key：

```text
iiop:device:status:{deviceId}
iiop:dashboard:device-overview
iiop:dashboard:inspection-overview
iiop:dashboard:maintenance-overview
iiop:event:consumed:{consumer}:{eventId}
iiop:lock:inspection-plan:{planId}
iiop:ws:user:{userId}
```

Sa-Token 自身 Key 使用框架默认命名，不自行重复造一套 Session Key。

## 14.3 TTL

建议：

- Dashboard：30-60 秒；
- 设备实时状态：1-5 分钟，根据采集频率决定；
- MQ 幂等：至少覆盖消息可能重试周期，课程项目先设 7 天；
- 分布式锁：必须设置短 TTL；
- WebSocket 在线状态：连接期间维护。

不要设置永久缓存替代数据库。

---

# 15. RocketMQ 事件架构

项目采用 Spring Cloud Alibaba 官方提供的 Spring Cloud Stream RocketMQ Binder。

依赖：

`spring-cloud-starter-stream-rocketmq`

第一版只设计四类高价值 Topic。

## 15.1 通用事件信封

统一事件结构：

```json
{
  "eventId": "...",
  "eventType": "INSPECTION_ABNORMAL_CREATED",
  "source": "iiop-inspection",
  "occurredAt": "2026-09-28T16:00:00",
  "traceId": "...",
  "data": {}
}
```

要求：

- eventId 全局唯一；
- occurredAt 记录业务事件发生时间；
- traceId 尽量继承原请求；
- data 使用明确事件 DTO；
- 消费者不得依赖生产者数据库。

## 15.2 Topic：iiop.inspection.abnormal

生产者：

iiop-inspection

事件：

`INSPECTION_ABNORMAL_CREATED`

data：

- abnormalId
- abnormalCode
- deviceId
- severity
- title
- reportedAt

消费者：

- iiop-maintenance
- iiop-ai

## 15.3 Topic：iiop.maintenance.alarm

生产者：

iiop-maintenance

事件：

- ALARM_CREATED
- ALARM_LEVEL_CHANGED

消费者：

- iiop-ai
- iiop-auth 通知逻辑

## 15.4 Topic：iiop.maintenance.workorder

生产者：

iiop-maintenance

事件：

- WORK_ORDER_CREATED
- WORK_ORDER_ASSIGNED
- WORK_ORDER_STATUS_CHANGED

消费者：

iiop-auth 通知逻辑。

第一版 AI 不需要消费所有工单状态事件。

## 15.5 Topic：iiop.ai.diagnosis

生产者：

iiop-ai

事件：

- AI_DIAGNOSIS_SUCCEEDED
- AI_DIAGNOSIS_FAILED
- AI_DIAGNOSIS_CONFIRMED

消费者：

- iiop-maintenance：仅处理与 defect/work-order 的 diagnosisId 关联，不同步查询 AI 详情
- iiop-auth 通知逻辑

## 15.6 Spring Cloud Stream Binding 命名

第一版固定以下函数和 binding 名，避免每个服务自行发明命名。

### inspection

生产绑定：

- binding：`abnormal-out-0`
- destination：`iiop.inspection.abnormal`

### maintenance

消费函数：

- `inspectionAbnormalConsumer`
- `aiDiagnosisLinkConsumer`

消费绑定：

- `inspectionAbnormalConsumer-in-0`
  - destination：`iiop.inspection.abnormal`
  - group：`iiop-maintenance-abnormal-consumer`
- `aiDiagnosisLinkConsumer-in-0`
  - destination：`iiop.ai.diagnosis`
  - group：`iiop-maintenance-ai-diagnosis-consumer`

`aiDiagnosisLinkConsumer` 只处理 `AI_DIAGNOSIS_SUCCEEDED`。当 triggerType/triggerId 能定位 maintenance 中由同一异常或告警形成的 defect 时，写入 `mt_defect.ai_diagnosis_id`；已有工单时可同步补写 `mt_work_order.ai_diagnosis_id`。它不调用 iiop-ai 查询详情。

生产绑定：

- `alarm-out-0` → `iiop.maintenance.alarm`
- `workorder-out-0` → `iiop.maintenance.workorder`

### ai

消费函数：

- `aiAbnormalConsumer`
- `aiAlarmConsumer`

绑定：

- `aiAbnormalConsumer-in-0` → `iiop.inspection.abnormal`
- `aiAlarmConsumer-in-0` → `iiop.maintenance.alarm`

对应 group 必须不同于 maintenance 和 auth 的 group。

生产绑定：

- `diagnosis-out-0` → `iiop.ai.diagnosis`

### auth

通知消费函数：

- `alarmNotificationConsumer`
- `workorderNotificationConsumer`
- `aiNotificationConsumer`

分别消费：

- `alarmNotificationConsumer-in-0`
  - destination：`iiop.maintenance.alarm`
  - group：`iiop-auth-alarm-notification-consumer`
- `workorderNotificationConsumer-in-0`
  - destination：`iiop.maintenance.workorder`
  - group：`iiop-auth-workorder-notification-consumer`
- `aiNotificationConsumer-in-0`
  - destination：`iiop.ai.diagnosis`
  - group：`iiop-auth-ai-notification-consumer`

Spring Cloud Stream 使用函数式 Consumer/Function 模式。实际 `spring.cloud.function.definition` 和 bindings 配置按本节名称生成。

## 15.7 Consumer Group

每个业务目的使用独立 Group。

示例：

- `iiop-maintenance-abnormal-consumer`
- `iiop-maintenance-ai-diagnosis-consumer`
- `iiop-ai-abnormal-consumer`
- `iiop-ai-alarm-consumer`
- `iiop-auth-alarm-notification-consumer`
- `iiop-auth-workorder-notification-consumer`
- `iiop-auth-ai-notification-consumer`

不同业务目的不得错误使用同一个 consumer group，否则集群消费会导致只有其中一方获得消息。

## 15.8 幂等

每次消费：

1. 读取 eventId；
2. 检查 `iiop:event:consumed:{consumer}:{eventId}`；
3. 已处理则直接成功返回；
4. 未处理则执行本地事务；
5. 业务成功后写幂等 Key；
6. 数据库同时用自然唯一约束兜底。

例如 maintenance 从巡检异常创建 defect 时，数据库规范已有：

`UNIQUE(source_type, source_id)`

用于第二层去重。

## 15.9 发送时机

重要事件只能在本地数据库事务成功后发送。

第一版不引入 Seata，不引入复杂 Outbox 基础设施。

实现原则：

- 本地事务先保证本服务业务正确；
- MQ 失败时记录错误并允许补偿/重试；
- 消费端必须幂等；
- 最终一致性优先于为实训项目引入过重分布式事务框架。

---

# 16. Sentinel 设计

## 16.1 依赖

普通服务：

`spring-cloud-starter-alibaba-sentinel`

Gateway：

在普通 Sentinel starter 基础上增加：

`spring-cloud-alibaba-sentinel-gateway`

## 16.2 保护对象

第一版重点：

1. Gateway 总入口；
2. `POST /api/auth/login`；
3. `/api/ai/**`；
4. `POST /api/device/metric-data`；
5. Dashboard 统计接口；
6. 必要的 Feign 下游调用。

## 16.3 规则原则

规则必须可解释。

示例目标：

- 防止登录接口暴力高频访问；
- 防止 AI 调用快速耗尽模型额度；
- 防止监测数据瞬时写入压垮数据库；
- 防止 Dashboard 高频刷新重复聚合。

具体 QPS 数值在真实联调后确定，规范中不提前伪造性能数据。

## 16.4 降级响应

被 Sentinel Block 时：

- HTTP 状态使用 429；
- Result.code 使用 429xx；
- message 为明确的“请求过于频繁，请稍后再试”；
- AI 场景不能伪装成模型成功。

---

# 17. WebSocket 与通知

## 17.1 所属服务

WebSocket 明确放在：

`iiop-auth`

理由：

- `sys_notification` 属于 iiop_auth；
- auth 已维护用户登录态；
- 不新增 notification 微服务；
- 课程项目单实例/少实例足以使用 Spring 内置 STOMP broker。

## 17.2 技术方案

使用：

- Spring WebSocket；
- STOMP；
- Spring Simple Broker；
- `SimpMessagingTemplate`。

第一版不再额外部署 RabbitMQ 作为 STOMP broker。

RocketMQ 仍承担服务间业务事件；WebSocket 只承担服务到客户端的实时推送。两者职责不同。

## 17.3 Gateway 路由

WebSocket：

`/ws/** → lb:ws://iiop-auth`

如果后续启用 SockJS fallback，需要同时配置对应 HTTP route。

第一版 PC 优先使用原生 WebSocket + STOMP，不强制 SockJS。

## 17.4 STOMP 目的地

建议：

- 客户端 CONNECT endpoint：`/ws/notifications`
- 用户订阅：`/user/queue/notifications`
- 可选公共系统消息：`/topic/system`

用户告警、工单、AI 通知优先走 user queue，避免广播敏感业务信息。

## 17.5 WebSocket 鉴权

STOMP CONNECT 时携带 Sa-Token token。

auth 服务通过 `ChannelInterceptor` 校验 Token 并绑定 userId。

禁止仅依赖浏览器页面“已经登录”这一前提。

## 17.6 推送流程

```text
MQ/业务事件
→ auth 生成 sys_notification
→ 数据库提交成功
→ 在线则 SimpMessagingTemplate 推送
→ 离线则只保留数据库记录
→ 用户下次登录通过 REST 查询
```

因此 WebSocket 失败不会造成通知事实丢失。

---

# 18. 请求链路与日志

## 18.1 Request ID

Gateway：

- 如果请求已有合法 `X-Request-Id` 可以透传；
- 否则生成新的 UUID 或等价唯一 ID。

向下游透传：

`X-Request-Id`

业务服务放入 MDC：

`traceId`

Result 中回传 traceId。

MQ 事件同样带 traceId。

## 18.2 日志要求

日志至少包含：

- timestamp；
- level；
- application name；
- traceId；
- thread；
- logger；
- message。

禁止日志输出：

- 明文密码；
- Sa-Token 完整 Token；
- DeepSeek API Key；
- 数据库密码；
- 大段完整 AI Prompt 中的敏感内容。

## 18.3 日志等级

开发：

- 项目包 INFO；
- 调试时局部 DEBUG。

默认禁止整个框架全局 DEBUG。

---

# 19. 数据库事务边界

## 19.1 原则

`@Transactional` 只覆盖当前微服务数据库。

禁止用一个本地事务假装包住多个微服务。

## 19.2 典型事务

auth：

- 创建用户 + 用户角色；
- 修改角色权限；
- 状态变更。

inspection：

- 生成 task + task items；
- 提交检查项；
- 完成任务；
- 创建异常。

maintenance：

- 创建 defect；
- 创建工单 + 首条流转日志；
- 状态迁移 + 流转日志；
- 提交维修结果；
- 验收 + 工单状态更新。

ai：

- 创建 diagnosis；
- 更新诊断结果；
- 写 workflow trace。

## 19.3 状态更新防重

任务和工单状态更新采用条件更新。

例如：

```text
UPDATE ...
WHERE id = ?
AND status = expectedStatus
```

更新条数为 0 时返回状态冲突。

第一版不为此额外引入分布式事务。

---

# 20. 定时任务

第一版只保留真正必要的后台任务。

## 20.1 巡检计划任务生成

所属：

iiop-inspection

职责：

- 查询 ENABLED 且 next_generate_time 到期的计划；
- 使用 Redis 短锁 `iiop:lock:inspection-plan:{planId}`；
- 生成 task；
- 复制 template items 为 task item 快照；
- 更新 last_generate_time；
- 计算 next_generate_time。

要求：

- 同一计划、同一调度时间不得重复生成任务；
- 生成过程在 inspection 本地事务中完成；
- Redis 锁只是并发保护，数据库查询仍需防重复。

## 20.2 逾期任务

周期扫描未完成且超过 scheduled_end_time 的任务：

- 设置 `overdue_flag = 1`；
- 不改变 task_status 的 PENDING / IN_PROGRESS 生命周期语义。

---

# 21. API 设计总则

## 21.1 URL

外部：

`/api/{domain}/...`

内部：

`/internal/{domain}/...`

URL 使用复数资源名。

动作型状态迁移可以使用子资源/动作，例如：

`POST /api/inspection/tasks/{id}/start`

## 21.2 HTTP 方法

- GET：查询；
- POST：创建或明确业务动作；
- PUT：完整或明确更新；
- DELETE：删除可删除的主数据。

禁止所有业务都使用 POST。

## 21.3 参数

- DTO 使用 Bean Validation；
- Path ID 使用 Long；
- 分页 pageNum/pageSize；
- 时间使用 ISO-8601；
- 状态从枚举集合校验。

## 21.4 返回

Controller 返回：

`Result<VO>`

分页：

`Result<PageResult<VO>>`

DELETE 成功返回空 data 或 Boolean，整个项目保持统一。

## 21.5 外部 ID 序列化契约

数据库 Entity 和 Service 内部 ID 使用 `Long`。

面向 PC/HarmonyOS 的外部 Request/VO 中，所有业务 ID 字段按字符串契约处理，避免 JavaScript Number 超出安全整数范围。

规则：

1. Entity 的 id、deviceId 等仍为 Long；
2. 外部 VO 的 id、deviceId、taskId、workOrderId、diagnosisId 等使用 String，或在字段级显式使用 ToStringSerializer；
3. 禁止配置“所有 Long 全局转字符串”，避免把分页 total、耗时等普通 Long 数值意外转换；
4. 前端禁止 parseInt 业务 ID；
5. 内部 Feign DTO 可以继续使用 Long，因为调用双方均为 Java 服务；
6. PageResult.total 保持数值语义。

## 21.6 附件上传与本地存储契约

第一版不新增文件微服务。文件物理根目录固定：

`E:/IIOP-data/uploads/`

业务服务只处理自己领域的附件。

### inspection

上传：

`POST /api/inspection/attachments/images`

权限：

- inspection:execute 或 inspection:abnormal:process

请求：

`multipart/form-data`，字段名 `file`。

读取：

`GET /api/inspection/attachments/{fileKey}`

读取至少要求登录，并结合 inspection:view / inspection:execute 做领域授权。

用途：

- PHOTO 巡检项；
- ins_task_item.evidence_urls；
- ins_abnormal.evidence_urls。

### maintenance

上传：

`POST /api/maintenance/attachments/images`

权限：

- maintenance:workorder:process

读取：

`GET /api/maintenance/attachments/{fileKey}`

读取至少要求 maintenance:view。

用途：

- 工单处理图片；
- mt_work_order_log.attachments。

### AttachmentVO

返回至少：

- fileKey
- originalName
- contentType
- size
- url

其中 url 为经过 Gateway 的业务 URL，例如 `/api/inspection/attachments/{fileKey}`。

安全规则：

1. 只允许 image/jpeg、image/png、image/webp；
2. 单文件上限第一版为 10 MiB；
3. 服务端生成 UUID 或等价不可预测文件名；
4. 禁止使用用户原始文件名作为物理路径；
5. 必须规范化并校验目录，阻止路径穿越；
6. 文件存放在 `E:/IIOP-data/uploads/inspection/` 或 `maintenance/`；
7. GET 仍要求正常 Sa-Token 登录和 Same-Token 网关链路；
8. 前端需要显示图片时，通过带 Token 的请求读取 Blob/字节，不假设匿名静态资源；
9. 业务 JSON 只保存返回 URL，不保存 base64 或二进制；
10. 第一版不提供物理删除 API，用户在业务提交前先完成本地选择，确认提交时再上传，尽量减少孤儿文件；
11. 项目运行目录和上传目录不得进入 Git；
12. 附件 GET 返回二进制响应，是统一 Result<VO> JSON 契约的明确例外；错误响应仍使用统一业务错误结构。

iiop-common 可以提供纯 Java 的安全文件名、路径规范化、MIME/大小校验和本地存储抽象；业务 Controller、业务权限和目录配置保留在 inspection/maintenance 服务。

---

# 22. iiop-auth API

## 22.1 登录

### POST /api/auth/login

公开。

请求：

- username
- password

返回：

- tokenName
- tokenValue
- user summary
- roles
- permissions

失败场景：

- 用户不存在；
- 密码错误；
- 用户禁用；
- 用户锁定。

禁止向外部返回能够精确判断账号是否存在的差异化提示，降低账号枚举风险。

## 22.2 退出

### POST /api/auth/logout

已登录。

调用 Sa-Token logout。

## 22.3 当前用户

### GET /api/auth/me

返回：

- 用户资料；
- roles；
- permissions。

## 22.4 用户管理

- GET /api/auth/users
- GET /api/auth/users/{id}
- POST /api/auth/users
- PUT /api/auth/users/{id}
- PUT /api/auth/users/{id}/status
- PUT /api/auth/users/{id}/roles
- DELETE /api/auth/users/{id}

权限建议：

- system:user:view
- system:user:create
- system:user:update
- system:user:delete
- system:user:role

创建用户时密码必须 BCrypt。

删除采用数据库规范中的逻辑删除。

## 22.5 角色

- GET /api/auth/roles
- GET /api/auth/roles/{id}
- POST /api/auth/roles
- PUT /api/auth/roles/{id}
- DELETE /api/auth/roles/{id}
- PUT /api/auth/roles/{id}/permissions

权限：

- system:role:view
- system:role:create
- system:role:update
- system:role:delete
- system:role:permission

## 22.6 权限

- GET /api/auth/permissions/tree → system:permission:view
- GET /api/auth/permissions → system:permission:view
- POST /api/auth/permissions → system:permission:create
- PUT /api/auth/permissions/{id} → system:permission:update
- DELETE /api/auth/permissions/{id} → system:permission:delete

## 22.7 通知

- GET /api/auth/notifications
- GET /api/auth/notifications/unread-count
- PUT /api/auth/notifications/{id}/read
- PUT /api/auth/notifications/read-all

用户只能修改自己的通知状态。

## 22.8 内部用户摘要

### GET /internal/auth/users/{id}/summary

仅 Same-Token。

返回：

- id
- username
- realName
- status

---

# 23. iiop-device API

## 23.1 分类

- GET /api/device/categories/tree
- GET /api/device/categories
- POST /api/device/categories
- PUT /api/device/categories/{id}
- DELETE /api/device/categories/{id}

## 23.2 设备

- GET /api/device/devices
- GET /api/device/devices/{id}
- POST /api/device/devices
- PUT /api/device/devices/{id}
- PUT /api/device/devices/{id}/status
- DELETE /api/device/devices/{id}

筛选：

- keyword
- categoryId
- status
- riskLevel
- workshop
- productionLine

## 23.3 指标定义

- GET /api/device/devices/{deviceId}/metrics
- POST /api/device/devices/{deviceId}/metrics
- PUT /api/device/metrics/{id}
- DELETE /api/device/metrics/{id}

## 23.4 指标数据

- GET /api/device/devices/{deviceId}/metric-data
- POST /api/device/metric-data

查询参数：

- metricId
- startTime
- endTime
- pageNum
- pageSize

后续 ECharts 趋势使用：

### GET /api/device/devices/{deviceId}/metric-trend

返回适合图表的数据 DTO，不返回 Entity。

实时监测和设备摘要使用：

### GET /api/device/devices/{deviceId}/metric-snapshot

一次返回该设备各启用指标的最新值、单位、采集时间和阈值摘要，避免前端按指标逐个轮询。

## 23.5 SOP

- GET /api/device/sops
- GET /api/device/sops/{id}
- POST /api/device/sops
- PUT /api/device/sops/{id}
- DELETE /api/device/sops/{id}

## 23.6 统计

- GET /api/device/statistics/overview
- GET /api/device/statistics/status-distribution
- GET /api/device/statistics/risk-distribution

## 23.7 内部设备上下文

### GET /internal/device/devices/{id}/context

面向 inspection、maintenance、ai。

AI 使用两个明确的只读内部契约：

### GET /internal/device/devices/{id}/ai-context

包含：

- device summary；
- 当前或近期关键指标摘要。

### GET /internal/device/devices/{id}/sop-context

只返回与该设备相关且状态为 EFFECTIVE 的 SOP 摘要/受控内容，优先设备专属，再按设备分类匹配。

这样 LangGraph4j 的 LOAD_DEVICE 与 LOAD_SOP 节点具有独立、可审计的数据来源。

禁止让 AI 服务直接查 iiop_device。

---

# 24. iiop-inspection API

## 24.1 模板

- GET /api/inspection/templates
- GET /api/inspection/templates/{id}
- POST /api/inspection/templates
- PUT /api/inspection/templates/{id}
- DELETE /api/inspection/templates/{id}
- PUT /api/inspection/templates/{id}/flow

flow 保存 Vue Flow JSON。

## 24.2 模板项

- GET /api/inspection/templates/{templateId}/items
- POST /api/inspection/templates/{templateId}/items
- PUT /api/inspection/template-items/{id}
- DELETE /api/inspection/template-items/{id}
- PUT /api/inspection/templates/{templateId}/items/sort

## 24.3 计划

- GET /api/inspection/plans
- GET /api/inspection/plans/{id}
- POST /api/inspection/plans
- PUT /api/inspection/plans/{id}
- PUT /api/inspection/plans/{id}/status
- DELETE /api/inspection/plans/{id}

创建或启用计划时校验：

- device 存在；
- template 可用；
- assignee 用户可用。

## 24.4 任务

- GET /api/inspection/tasks
- GET /api/inspection/tasks/{id}
- POST /api/inspection/tasks/manual
- POST /api/inspection/tasks/{id}/start
- POST /api/inspection/tasks/{id}/items/{itemId}/submit
- POST /api/inspection/tasks/{id}/complete
- POST /api/inspection/tasks/{id}/cancel

列表筛选：

- deviceId
- assigneeUserId
- taskStatus
- resultStatus
- overdue
- startDate
- endDate

`GET /api/inspection/abnormals` 至少支持：

- deviceId
- severity
- status
- startDate
- endDate

INSPECTOR 默认只能执行分配给自己的任务，管理员可查看全部。

## 24.5 异常

- GET /api/inspection/abnormals
- GET /api/inspection/abnormals/{id}
- POST /api/inspection/tasks/{taskId}/abnormals
- PUT /api/inspection/abnormals/{id}/status

## 24.6 统计

- GET /api/inspection/statistics/overview
- GET /api/inspection/statistics/trend

## 24.7 内部历史

### GET /internal/inspection/devices/{deviceId}/recent-history

供 AI 使用。

返回最近若干：

- task summary；
- abnormal summary；
- task item 异常结果。

不得返回无限历史数据。

---

# 25. iiop-maintenance API

## 25.1 告警

`GET /api/maintenance/alarms` 至少支持 deviceId、alarmLevel、status、startTime、endTime、pageNum、pageSize。

- GET /api/maintenance/alarms
- GET /api/maintenance/alarms/{id}
- POST /api/maintenance/alarms/manual
- POST /api/maintenance/alarms/{id}/acknowledge
- POST /api/maintenance/alarms/{id}/recover
- POST /api/maintenance/alarms/{id}/close

## 25.2 缺陷

`GET /api/maintenance/defects` 至少支持 deviceId、severity、status、sourceType、pageNum、pageSize。

- GET /api/maintenance/defects
- GET /api/maintenance/defects/{id}
- POST /api/maintenance/defects/manual
- POST /api/maintenance/defects/{id}/confirm
- POST /api/maintenance/defects/{id}/resolve
- POST /api/maintenance/defects/{id}/close

## 25.3 工单

`GET /api/maintenance/work-orders` 至少支持 keyword、deviceId、priority、status、assigneeUserId、startTime、endTime、pageNum、pageSize。

- GET /api/maintenance/work-orders
- GET /api/maintenance/work-orders/{id}
- POST /api/maintenance/work-orders
- PUT /api/maintenance/work-orders/{id}
- POST /api/maintenance/work-orders/{id}/submit
- POST /api/maintenance/work-orders/{id}/assign
- POST /api/maintenance/work-orders/{id}/start
- POST /api/maintenance/work-orders/{id}/repair
- POST /api/maintenance/work-orders/{id}/submit-acceptance
- POST /api/maintenance/work-orders/{id}/accept
- POST /api/maintenance/work-orders/{id}/reject
- POST /api/maintenance/work-orders/{id}/cancel
- GET /api/maintenance/work-orders/{id}/logs

每个动作严格校验 `01-database.md` 状态机。

从 defect 创建工单时，如果 defect 已通过 AI_DIAGNOSIS_SUCCEEDED 事件关联 `ai_diagnosis_id`，工单默认继承该 diagnosisId。maintenance 只保存引用，不同步读取 AI 详情。

## 25.4 统计

- GET /api/maintenance/statistics/overview
- GET /api/maintenance/statistics/alarm-trend
- GET /api/maintenance/statistics/work-order-distribution

## 25.5 内部维修历史

### GET /internal/maintenance/devices/{deviceId}/history

供 AI 使用。

返回：

- 近期告警；
- 近期缺陷；
- 已完成维修记录；
- 验收摘要。

限制条数，避免一次把全部历史传给大模型。

---

# 26. iiop-ai API

AI 业务细节以 `04-ai.md` 为准。

`POST /api/ai/diagnoses` 的 MANUAL 请求至少包含：

- deviceId
- abnormalSummary
- description，可选，对应 ai_diagnosis.user_description

后端路由先固定：

- POST /api/ai/chat
- GET /api/ai/sessions
- GET /api/ai/sessions/{id}/messages
- POST /api/ai/diagnoses
- GET /api/ai/diagnoses
- GET /api/ai/diagnoses/{id}
- GET /api/ai/diagnoses/{id}/workflow
- POST /api/ai/diagnoses/{id}/confirm
- POST /api/ai/diagnoses/{id}/reject

确认和拒绝必须记录：

- confirmedBy；
- confirmedAt；
- comment。

AI API 不提供执行停机、修改设备参数等物理控制端点。

---

# 27. Dashboard 数据聚合

不新增 dashboard 微服务。

PC 首页分别调用：

- device statistics；
- inspection statistics；
- maintenance statistics。

前端可以并行请求后组合展示。

原因：

- 项目规模有限；
- 避免新增只为大屏服务的微服务；
- 统计数据天然属于各自业务域。

Redis 对各服务统计结果做短缓存。

---

# 28. 初始管理员创建方案

`06_seed_data.sql` 不保存用户密码。

为了让项目第一次启动后可登录，auth 提供 **仅开发环境启用** 的 Bootstrap Admin 初始化逻辑。

环境变量：

- `IIOP_BOOTSTRAP_ADMIN_ENABLED`
- `IIOP_BOOTSTRAP_ADMIN_USERNAME`
- `IIOP_BOOTSTRAP_ADMIN_PASSWORD`

规则：

1. 仅 `dev` profile 可启用；
2. enabled != true 时完全不执行；
3. 密码必须通过 BCrypt 后入库；
4. 若 username 已存在则不重复创建；
5. 自动绑定 SUPER_ADMIN；
6. 不把密码写日志；
7. README 只写变量名，不写真实默认密码；
8. 完成首次初始化后建议关闭开关。

---

# 29. Actuator

所有启动服务引入 Actuator。

至少使用：

- health；
- info。

开发阶段不公开：

- env；
- beans；
- configprops 等可能泄露配置的端点。

业务服务的 Actuator 不经 Gateway 对公网路由。

---

# 30. 测试策略

## 30.1 单元测试

重点测试：

- 状态机；
- 业务编码生成；
- 权限判断；
- DTO 校验；
- AI 结构解析；
- MQ 幂等逻辑。

## 30.2 Service 测试

重点：

- 创建任务时模板快照；
- 异常创建；
- defect 幂等；
- 工单状态迁移；
- 验收驳回；
- AI 人工确认。

## 30.3 Controller/API 测试

至少验证：

- 正常请求；
- 参数错误；
- 未登录；
- 无权限；
- 对象不存在；
- 状态冲突。

## 30.4 集成测试

后期真实基础设施启动后验证：

- Nacos 注册；
- Gateway lb 路由；
- Redis Session；
- Same-Token；
- Feign；
- RocketMQ；
- Sentinel；
- WebSocket。

不得通过删除失败测试来让构建通过。

---

# 31. 分阶段后端实施顺序

后端实际编码不得一次生成全部服务。

## B1：公共基础

实现：

- iiop-common；
- parent POM 依赖管理；
- Result；
- PageResult；
- 错误码；
- BizException。

## B2：auth

实现：

- Entity；
- Mapper；
- RBAC Service；
- 登录；
- Sa-Token；
- Bootstrap Admin；
- 通知 REST；
- WebSocket。

## B3：gateway

实现：

- WebFlux Gateway；
- Nacos；
- 显式 routes；
- Sa-Token Reactor；
- Same-Token；
- CORS；
- traceId；
- Sentinel 基础接入。

此时必须完成第一条真正可运行链：

`客户端 → 8080 Gateway → 9201 auth`

## B4：device

实现完整设备域和内部 context API。

## B5：inspection

实现模板、计划、任务、执行、异常和异常 MQ。

## B6：maintenance

实现告警、缺陷、工单、维修、验收和 MQ。

## B7：AI

按照 `04-ai.md` 实现。

## B8：基础设施完善

集中完成：

- Sentinel 实际规则；
- Redis 缓存；
- MQ 幂等；
- Feign timeout/fallback；
- WebSocket 联调；
- Dashboard 缓存。

---

# 32. 每阶段构建规则

第一次真正允许 Maven 下载依赖前，Codex 必须先确认：

`.mvn/maven.config`

仍然包含：

`-Dmaven.repo.local=E:/DevCache/maven/repository`

然后执行 Maven 时从：

`E:\IIOP`

使用：

`mvn -f backend/pom.xml ...`

所有 Maven 依赖必须进入：

`E:/DevCache/maven/repository`

不得修改 Maven repo 指向 C 盘。

开发阶段推荐优先执行最小模块构建，例如：

`mvn -f backend/pom.xml -pl iiop-common -am test`

而不是每次全量 clean install。

只有需要验证聚合工程时才运行全量构建。

---

# 33. 代码质量规则

后端必须遵守：

1. Controller 不写复杂业务；
2. Service 不直接拼 HTTP response；
3. Mapper 不跨库；
4. Entity 不出服务边界；
5. DTO/VO 命名表达用途；
6. 不使用 Map 代替稳定业务 DTO；
7. 禁止大段复制粘贴 Controller；
8. 禁止在 Service 中硬编码 API Key；
9. 禁止在代码中写数据库密码；
10. 关键状态变化必须校验前置状态；
11. MQ 消费必须幂等；
12. Feign 失败不能被吞掉；
13. AI 失败不能伪装成功；
14. 日志不得泄密；
15. 业务异常要有可定位的 traceId；
16. 不为了技术栈齐全创建无用途类。

---

# 34. 后端验收链路

项目最终至少必须演示以下链路。

## 34.1 登录链

```text
POST /api/auth/login
→ Gateway
→ Auth
→ MySQL 用户
→ BCrypt
→ Sa-Token
→ Redis Session
→ 返回 Token
```

## 34.2 设备链

```text
Gateway
→ Device
→ MyBatis-Plus
→ iiop_device
→ Redis 短缓存
→ PC 设备页面
```

## 34.3 巡检链

```text
计划
→ 定时生成任务
→ HarmonyOS 执行
→ 任务项
→ 异常
→ RocketMQ
```

## 34.4 维护链

```text
异常事件
→ Maintenance Consumer
→ Defect
→ Work Order
→ Assign
→ Repair
→ Acceptance
→ Completed
```

## 34.5 AI 链

```text
异常/告警事件
→ AI Consumer
→ OpenFeign 获取上下文
→ LangGraph4j
→ LangChain4j
→ DeepSeek
→ ai_diagnosis
→ 人工确认
```

## 34.6 通知链

```text
业务/MQ事件
→ Auth Notification
→ sys_notification
→ WebSocket
→ PC/HarmonyOS
```

这些链路能够跑通，才说明项目确实使用了微服务、中间件和大模型，而不只是 POM 中声明了依赖。

---

# 35. M2 开始前的约束

在数据库 M1 完成并审查通过前，不进入大规模后端业务生成。

M2 或后续后端任务中，Codex 每次只能实现明确阶段。

Codex 如果发现：

- BOM 解析失败；
- 依赖 artifact 不存在；
- Spring Cloud Gateway 新旧配置前缀冲突；
- Sa-Token Boot3 starter 不兼容；
- Nacos 配置无法加载；
- Sentinel Gateway 与新 Gateway starter 存在兼容问题；

必须报告真实错误。

禁止通过：

- 随意降级 Spring Boot；
- 随意升级 Spring Cloud；
- 改回过时 starter；
- 删除目标技术；

来隐藏兼容问题。

---

# 36. 官方实现依据

本文档中的版本和关键集成方式基于以下官方资料核对：

1. Spring Cloud 2025.0.0 Release Train，确认 Boot 3.5.0、Gateway 4.3.0、OpenFeign 4.3.0；
2. Spring Cloud 2025.0 Release Notes，确认 Gateway 4.3 的新 starter 名称与新配置前缀；
3. Spring Cloud Gateway 4.3 Reference，确认 WebFlux starter、LoadBalancer 和 WebSocket 路由；
4. Spring Cloud Alibaba 2025.x 版本说明，确认 Nacos 3.0.3、Sentinel 1.8.9、RocketMQ 5.3.1；
5. Spring Cloud Alibaba Nacos 2025.x 文档，确认 `spring.config.import`；
6. Spring Cloud Alibaba RocketMQ 2025.x 文档，确认 `spring-cloud-starter-stream-rocketmq`；
7. Sa-Token 1.46 官方文档，确认 Spring Boot 3 MVC/Reactor starter、Redis 分布式会话和 Same-Token 微服务方案；
8. MyBatis-Plus 官方文档，确认 Spring Boot 3 starter 与 3.5.17；
9. Spring Framework WebSocket/STOMP 文档，确认 STOMP endpoint、user destination 和 Simple Broker 能力。

---

# 37. 当前结论

后端第一版架构固定为：

```text
PC / HarmonyOS
        ↓
iiop-gateway :8080
        ↓
Sa-Token + Sentinel + Same-Token
        ↓
┌────────────┬─────────────┬─────────────────┬──────────────────┬───────────┐
│ iiop-auth  │ iiop-device │ iiop-inspection │ iiop-maintenance │ iiop-ai   │
│ :9201      │ :9202       │ :9203           │ :9204            │ :9205     │
└────────────┴─────────────┴─────────────────┴──────────────────┴───────────┘
      ↓              ↓              ↓                  ↓              ↓
 iiop_auth      iiop_device   iiop_inspection    iiop_maintenance   iiop_ai

共享基础设施：
Nacos + Redis + RocketMQ + Sentinel

同步跨服务：
OpenFeign + Same-Token

异步跨服务：
RocketMQ

实时客户端通知：
iiop-auth + STOMP/WebSocket

AI：
iiop-ai + LangChain4j + LangGraph4j + DeepSeek
```

该方案控制实训项目复杂度，同时真实体现微服务注册发现、网关、认证授权、缓存、消息队列、流量保护、服务调用、实时通信和大模型工作流。

未经明确确认，Codex 不得重新拆分服务或引入新的基础设施组件。
