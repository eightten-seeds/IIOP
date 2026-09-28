# IIOP 开发约束

## 项目与开发模式

- 项目根目录：`E:\IIOP`
- 当前由单人完整开发，优先保证项目整体能够真实运行、测试和答辩。
- Codex 的职责以实现、验证和小范围修复为主，不重新设计已经冻结的系统架构。

## 最小实现原则

本项目时间优先，第一版只实现课程要求、核心业务闭环和答辩可展示能力。

- 能用一个简单方案完成时，不增加第二套方案。
- 不为了“企业级”“高可用”“可扩展”提前增加无当前业务价值的设计。
- 不引入服务网格、分布式事务框架、Outbox、复杂缓存体系、复杂重试/熔断链、额外监控平台或新的基础设施。
- Nacos、Redis、RocketMQ、Sentinel、WebSocket、AI 等固定技术只实现能证明其真实使用的最小闭环。
- 缓存、幂等、重试、降级只在当前真实场景需要时实现最小版本，不做通用框架。
- 测试以核心主链、权限边界和关键失败场景为主，不做生产级混沌、容量或高可用测试。
- Codex 不得把可选增强项自行升级为必做项。
- 审查发现“可以删掉且不影响课程要求、业务闭环、技术栈展示”的复杂代码时，优先删除或不实现。

## 规范优先级

第一版开发规范已经完成简化版 G0 收口并冻结：

1. `docs/spec/00-overview.md`：系统范围、服务边界和总体架构；
2. `docs/spec/01-database.md`：数据库事实来源；
3. `docs/spec/02-backend.md`：后端、API、中间件和权限契约；
4. `docs/spec/03-client.md`：PC 与 HarmonyOS 客户端契约；
5. `docs/spec/04-ai.md`：DeepSeek、LangChain4j、LangGraph4j 实现契约；
6. `docs/spec/05-roadmap.md`：阶段顺序、门禁、验收和 Codex 执行规则。

执行任务时必须同时遵守当前阶段对应 spec 和 `05-roadmap.md`。

除非当前任务明确要求修正规范，否则不要修改 00 到 05。

如果代码实现与规范发生不可兼容冲突，停止并报告事实，不自行改规范绕过问题。

## 阶段纪律

- 每次只实现一个明确里程碑或一个明确修复任务。
- 先阅读现有代码，再修改相关文件。
- 完成当前阶段规定的静态检查、构建或测试。
- 执行 `git diff --check`。
- 只提交当前阶段相关文件。
- commit 并 push `origin/main` 后停止。
- 禁止在完成一个阶段后自行继续下一个阶段。
- 禁止未经要求进行大规模重构。
- 禁止为了展示技术引入无业务价值的组件或新微服务。

## 微服务与数据边界

- 可启动服务固定为 `iiop-gateway`、`iiop-auth`、`iiop-device`、`iiop-inspection`、`iiop-maintenance`、`iiop-ai`。
- 数据库固定 5 个逻辑库、25 张业务表。
- `iiop-common` 是普通 Jar，不启动。
- 每个业务服务只能直接访问自己的逻辑数据库。
- 跨服务同步调用使用明确的 Feign DTO。
- 跨服务异步状态传播按规范使用 RocketMQ。
- 禁止跨服务直接访问其他服务数据库。
- 禁止形成同步循环依赖。
- Entity 不跨服务边界。

## API 与数据约定

- REST API 路径、权限码、状态枚举、MQ Topic 和内部 API 以 spec 为准。
- Java/数据库内部业务 ID 使用 `Long`。
- 面向 PC/HarmonyOS 的外部 VO 中业务 ID 使用字符串契约。
- 禁止把所有 `Long` 全局序列化为字符串，分页 `total`、耗时、统计数值等保持数值语义。
- 数据库字段使用 `snake_case`，Java 属性使用 `camelCase`。
- Java 使用 UTF-8；业务注释使用中文；类名、方法名、变量名使用规范英文。
- Spring Cloud Alibaba 2025.x 使用规范中已确认的当前接入方式，不复制旧版 bootstrap 配置。

## 安全与 Secret

- 禁止提交真实 API Key、数据库密码、Redis 密码、Token、Same-Token Secret 或其他 Secret。
- 使用环境变量和可提交的示例配置。
- 禁止日志输出完整 Token、密码、DeepSeek Key 或敏感请求体。
- AI 只实现结构化辅助诊断，不扩展其他 AI 子系统。
- LangGraph4j 固定 5 节点：LOAD_CONTEXT → ANALYZE_WITH_DEEPSEEK → RISK_CHECK → GENERATE_ADVICE → PREPARE_WORK_ORDER_DRAFT。
- AI 不得直接控制设备、修改工业参数或绕过人工确认。
- 测试 Stub 必须与正式实现明确隔离，不得在最终运行路径返回伪造成功结果。

## 磁盘约束

- 禁止主动向 C 盘写入项目依赖、项目数据库数据或上传文件。
- Maven repo：`E:/DevCache/maven/repository`
- npm cache：`E:/DevCache/npm`
- npm global 如需要：`E:/DevCache/npm-global`
- 项目运行数据与上传文件：`E:/IIOP-data/`

第一次执行可能下载依赖的 Maven、npm 或 ohpm 命令前，必须先检查实际缓存/数据位置。不确定时停止并报告。

## 测试与文档

- 修改业务功能后执行当前阶段要求的对应测试。
- 不删除测试来规避错误。
- 不伪造运行结果、性能数据、测试通过记录或 Git 历史。
- 重要架构变更只有在明确批准后才同步修改 spec。
- 原生 WebSocket 只用于 JSON 通知，不叠加额外实时通信协议。
- 第一版不引入与核心要求无关的额外监控、存储、事务或消息组件。
- 本地基础设施固定使用 Windows 本地服务，不使用 Docker。
- 最终正式材料只有团队项目实训报告、个人实训报告、答辩 PPT 和答辩讲稿，其内容必须基于真实最终代码和测试结果。
