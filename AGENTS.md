# IIOP Codex 开发约束

## 1. 第一原则

这是单人课程项目，时间优先。

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

## 9. 本地路径

- 项目：E:/IIOP
- Maven repo：E:/DevCache/maven/repository
- npm cache：E:/DevCache/npm
- npm global：E:/DevCache/npm-global
- 项目运行数据：E:/IIOP-data

不使用 Docker。

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
10. push origin/main
11. 报告
12. 停止

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
3. 02-backend.md
4. 03-client.md
5. 04-ai.md
6. 05-roadmap.md

当前规范已经按“最小可交付”重新收口。

未经用户明确要求，不得再次扩大范围。
