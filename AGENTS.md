# IIOP Codex 开发约束

## 1. 第一原则

这是课程实训团队项目，时间优先。

目标只有三个：

1. 真实能运行
2. 核心业务闭环完整
3. 指定技术栈能在答辩中证明使用

不要做生产级架构。

## 2. 禁止复杂化

Codex 不得主动增加：

- 新微服务
- 新数据库表
- 新中间件
- 分布式事务框架
- Outbox
- 服务网格
- 多级缓存
- 分布式锁框架
- 复杂熔断/重试框架
- 配置治理平台
- 动态路由平台
- 监控平台
- RAG
- 向量库
- Agent
- 多模型
- 低代码
- BI 平台

“建议”“可选”“以后可以”默认不实现。

## 3. 固定模块

只有：

- iiop-common
- iiop-gateway
- iiop-auth
- iiop-device
- iiop-inspection
- iiop-maintenance
- iiop-ai

数据库固定 5 库 25 表。

## 4. 最小技术用法

- Nacos：服务注册发现
- Redis：Sa-Token Session
- RocketMQ：inspection abnormal -> maintenance defect
- Sentinel：一个 Gateway 限流规则
- WebSocket：PC 通知 JSON
- DeepSeek：结构化诊断
- LangChain4j：模型接入
- LangGraph4j：固定 5 节点
- ECharts：少量 Dashboard 图表
- Three.js：简单设备场景
- Vue Flow：保存巡检 flow JSON
- HarmonyOS：现场巡检和维修

不要扩展成通用平台。

## 5. 认证

使用 Sa-Token + Redis + RBAC。

客户端统一走 Gateway。

第一版不要求 Same-Token 全局微服务认证。

/internal/** 不通过 Gateway 路由即可。

## 6. AI

AI 使用同步诊断。

不做 TaskExecutor、Worker、AI MQ、Chat、RAG、Tool Calling、MCP、多 Agent。

固定：

LOAD_CONTEXT
→ ANALYZE_WITH_DEEPSEEK
→ RISK_CHECK
→ GENERATE_ADVICE
→ PREPARE_WORK_ORDER_DRAFT

## 7. 数据边界

每个服务只访问自己的数据库。

跨服务读取使用 Feign DTO。

Entity 不跨服务。

数据库事实以 `docs/spec/01-database.md` 为准。

## 8. Secret

禁止提交：

- 数据库密码
- Redis 密码
- DeepSeek API Key
- Token
- 其他 Secret

使用环境变量。

## 9. 本地环境

组员电脑的项目目录、磁盘盘符、JDK、Maven、Node、Nacos、RocketMQ、DevEco Studio 和 Emulator 安装位置均由各自本地环境决定。

仓库规范不得把某个成员电脑的绝对路径当成团队统一路径。

要求：

- JDK 版本满足项目要求；
- Maven、Node/npm 等命令可由本机环境找到；
- 数据库、中间件和 AI Secret 使用本地环境变量或本地配置；
- 真实密码、Token、API Key 不提交 Git；
- 一键启动脚本属于本地开发辅助工具，不作为跨机器环境事实来源；
- 不使用 Docker。

## 10. 每轮流程

1. git status
2. 阅读当前 spec
3. 只实现当前阶段
4. 普通错误自己最小修复
5. 服务暂未就绪时有限等待重试
6. build/test
7. git diff --check
8. Secret 检查
9. commit
10. push 当前开发分支
11. 通过 PR 合并到 main，避免多人直接覆盖 main
12. 报告
13. 停止

不要自动进入下一阶段。

## 11. 测试原则

只测试：

- 当前阶段主链
- 权限
- 必要失败场景

不做生产级性能、高可用、混沌、集群测试。

不得伪造测试结果。

## 12. 文档

规范优先级：

1. 00-overview.md
2. 01-database.md
3. 06-role-usecases.md（角色、数据范围、业务流程、人机交互冻结基线）
4. 02-backend.md
5. 03-client.md
6. 04-ai.md
7. 05-roadmap.md

当前规范已经按“最小可交付”重新收口。

未经用户明确要求，不得再次扩大范围。
