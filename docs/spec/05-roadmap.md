# IIOP 开发路线与 Codex 执行规范

> 原则：每次 Codex 只实现一个里程碑，完成后提交并停止。由 ChatGPT 审查 GitHub 后再进入下一阶段。

## M0 工程初始化
状态：已完成。

## M1 数据库 SQL
读取：
- AGENTS.md
- docs/spec/01-database.md

产物：
- infra/sql/00_create_databases.sql
- 01_auth_schema.sql
- 02_device_schema.sql
- 03_inspection_schema.sql
- 04_maintenance_schema.sql
- 05_ai_schema.sql
- 06_seed_data.sql

验收：
- 5 个逻辑数据库
- 27 张业务表
- 无跨库外键
- 演示数据无密码/API Key

## M2 common + auth + gateway
读取：
- 00-overview.md
- 02-backend.md

实现：
- Result<T>
- 全局异常
- auth Entity/Mapper/Service/Controller
- Sa-Token 登录
- Gateway
- Nacos 注册与配置
- 基础权限
- 登录与 /me

验收：
- 三模块可编译
- auth/gateway 可启动
- 网关可转发
- 登录态有效

## M3 device
实现：
- category
- device
- metric
- metric-data
- sop
- device context API

验收：
- 设备 CRUD
- 指标 CRUD
- 数据查询
- SOP 查询
- 为 AI 提供上下文 API

## M4 inspection
实现：
- template
- template item
- plan
- task
- task item
- abnormal

验收：
- 从模板创建巡检任务快照
- 可执行任务
- 异常项可上报
- 完成任务后状态正确
- 异常事件可发布 RocketMQ

## M5 maintenance
实现：
- alarm
- defect
- work order
- flow log
- maintenance record
- acceptance

验收：
- 异常/告警形成缺陷
- 缺陷生成工单
- 工单完整流转
- 验收后闭环

## M6 AI
读取 04-ai.md。

实现：
- DeepSeek
- LangChain4j
- LangGraph4j
- ai_session/message
- ai_diagnosis
- ai_workflow_trace

验收：
- 手工触发诊断
- 异常事件触发诊断
- 结构化输出
- 工作流轨迹
- 人工确认

## M7 Redis + Sentinel + WebSocket + MQ 完善
验收：
- 登录会话 Redis
- 常用缓存
- 网关限流
- 实时通知
- 幂等 MQ 消费

## M8 PC 基础
读取 03-client.md。

实现：
- Vue3 基础工程
- 登录
- Layout
- 路由
- Pinia
- Axios
- 设备/巡检/工单 CRUD 页面

## M9 PC 可视化
实现：
- ECharts 驾驶舱
- Three.js
- Vue Flow
- WebSocket 通知
- AI 诊断页

## M10 HarmonyOS
实现移动巡检核心流程。

## M11 联调与测试
- 功能测试
- 权限测试
- MQ
- WebSocket
- AI 降级
- 页面适配
- 错误修复

## M12 最终材料
由 ChatGPT 根据最终真实代码和测试结果生成：
1. 团队项目实训报告
2. 个人实训报告
3. 答辩 PPT
4. 答辩讲稿

## Codex 每轮通用执行模板

后续提示词应尽量短：

“先阅读 AGENTS.md 和指定 spec 文件。实现 Mx，严格限定在该里程碑。完成静态检查/允许的构建验证后提交并 push，然后停止。”

不要让 Codex自行跨里程碑继续开发。
