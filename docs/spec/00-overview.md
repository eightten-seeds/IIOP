# IIOP 项目总纲（最简版）

> 项目：基于微服务与 DeepSeek 大模型的工业设备智能巡检运维平台  
> 用途：课程实训、项目实现、答辩  
> 原则：先完成真实可运行主链，再考虑可选增强

## 1. 项目目标

系统只围绕一条主业务链：

设备建档  
→ 巡检计划/任务  
→ 执行巡检  
→ 发现异常  
→ RocketMQ 形成缺陷  
→ AI 辅助诊断  
→ 人工确认  
→ 人工创建维修工单  
→ 维修处理  
→ 验收关闭  
→ 查询历史

第一版不追求生产级高可用、复杂治理、复杂自动化或额外平台能力。

## 2. 固定技术栈

后端：

- JDK 17
- Spring Boot 3.5.0
- Spring Cloud 2025.0.0
- Spring Cloud Alibaba 2025.0.0.0
- MySQL
- MyBatis-Plus
- Redis
- Sa-Token
- Nacos
- Sentinel
- RocketMQ
- WebSocket

AI：

- DeepSeek
- LangChain4j
- LangGraph4j

PC：

- Vue 3
- Axios
- Pinia
- Element Plus
- ECharts
- Three.js
- Vue Flow

移动端：

- HarmonyOS
- ArkTS
- ArkUI

本项目不使用 Docker。

## 3. 后端模块

固定 6 个可启动服务和 1 个公共 Jar：

- iiop-gateway
- iiop-auth
- iiop-device
- iiop-inspection
- iiop-maintenance
- iiop-ai
- iiop-common

不新增其他微服务。

职责：

- gateway：统一入口和基础鉴权
- auth：用户、角色、权限、登录、通知、WebSocket
- device：设备、分类、指标、SOP
- inspection：模板、计划、任务、巡检结果、异常
- maintenance：告警、缺陷、工单、维修、验收
- ai：DeepSeek 结构化诊断
- common：通用返回、异常、公共 DTO

## 4. 数据库

保持现有 5 个逻辑数据库、25 张表，不增表：

- iiop_auth：6
- iiop_device：5
- iiop_inspection：6
- iiop_maintenance：6
- iiop_ai：2

数据库字段、索引、枚举和 seed 以 `01-database.md` 为唯一事实来源。

禁止跨服务直接访问其他服务数据库。

## 5. 基础设施最小用法

### Nacos

只要求：

- 服务注册与发现真实可用
- 所有服务可在 `iiop-dev / IIOP_GROUP` 中看到

配置中心不是第一版必做项。已有接入如果稳定可保留，但不继续扩展。

### Redis

只要求：

- Sa-Token 登录 Session

其他缓存只有真实页面需要时再加。

### RocketMQ

只要求一个真实异步业务链：

`iiop_inspection_abnormal`

inspection 发布巡检异常事件，maintenance 消费并创建或关联缺陷。

第一版不再设计多 Topic 事件体系。

### Sentinel

只要求一个能演示的限流规则，例如登录接口。

### WebSocket

只用于 PC 通知提醒：

- auth 保存通知
- 在线时推送 JSON
- 历史通知仍通过 REST 查询

不使用 STOMP、SockJS、Redis Pub/Sub 或外部 WebSocket Broker。

## 6. 认证和权限

> 角色定义、数据范围、角色用例、状态交接与人机交互以 `06-role-usecases.md` 为冻结事实来源；本节只保留总纲级约束。

使用 Sa-Token + Redis。

固定业务角色：

- SUPER_ADMIN：超级管理员，负责系统治理和全部业务。
- ADMIN：业务管理员，负责设备、巡检、维修、AI 等业务管理，可管理日常用户并分配已有的非 SUPER_ADMIN 角色，但不拥有最高级角色/权限治理能力。
- INSPECTOR：巡检人员，面向现场巡检执行、异常上报和 AI 辅助诊断。
- MAINTAINER：维修人员，面向缺陷、维修工单、维修记录和 AI 辅助诊断。

要求：

- 登录
- 退出
- 当前用户
- 返回 roles + permissions
- RBAC 权限
- BCrypt 密码
- 未登录返回 401
- 无权限返回 403
- PC 根据角色形成工作视角，根据 permissions 做最终授权判断

Gateway 是客户端统一入口。

第一版不再要求额外 Same-Token 微服务来源认证体系。已有内部接口只要不通过 Gateway 暴露即可。

权限码保持 `01-database.md` 中现有 33 个，不新增。

## 7. 设备域

只完成：

- 分类 CRUD
- 设备 CRUD
- 设备状态与风险
- 指标定义
- 指标数据查询
- SOP
- 简单统计
- AI 读取设备上下文

Three.js 直接使用设备表已有 model_url 和 position_x/y/z。

## 8. 巡检域

只完成：

- 模板
- 模板项
- 计划
- 任务
- 任务项
- 异常

计划第一版允许人工点击“生成任务”，不要求复杂自动调度器。

巡检异常创建后发送一条 RocketMQ 事件给 maintenance。

PHOTO/附件不是主线阻塞项。若时间允许再做简单本地上传；没有附件也不能阻塞巡检主链。

## 9. 维修域

只完成：

- 告警基础查询/处理
- 缺陷
- 工单
- 工单日志
- 维修记录
- 验收

核心状态只保证：

待处理  
→ 处理中  
→ 待验收  
→ 已完成

具体数据库状态编码仍以 `01-database.md` 为准。

## 10. AI

AI 只做设备异常辅助诊断。

固定 5 节点：

LOAD_CONTEXT  
→ ANALYZE_WITH_DEEPSEEK  
→ RISK_CHECK  
→ GENERATE_ADVICE  
→ PREPARE_WORK_ORDER_DRAFT

要求：

- 使用 LangChain4j 调 DeepSeek
- 使用 LangGraph4j 真正执行 5 节点
- 保存 ai_diagnosis
- 保存 ai_workflow_trace
- 输出结构化 JSON
- HIGH/CRITICAL 需要人工确认
- AI 不直接控制设备
- AI 不自动创建真实工单

第一版采用同步诊断接口，不做后台 Worker、TaskExecutor、AI MQ 结果事件、多模型、RAG、向量库、Tool Calling 或 Agent。

## 11. PC Web

PC 只实现能完成管理和答辩演示的核心页面：

- 登录
- Dashboard
- 设备
- 巡检
- 维修
- AI 诊断
- 用户/角色
- 通知

技术展示：

- ECharts：Dashboard 2 到 4 个图表
- Three.js：一个设备场景，设备状态、位置、点击详情
- Vue Flow：一个巡检模板流程编辑页，保存 JSON
- WebSocket：通知提醒

不做低代码、BI 平台、数字孪生引擎、主题编辑器或复杂动态路由。

## 12. HarmonyOS

移动端只做现场最需要的流程：

- 登录
- 今日巡检任务
- 巡检任务详情/执行
- 异常上报
- 我的工单
- 工单处理
- 查看 AI 结果

不复制 PC 系统管理、Three.js、Vue Flow、复杂 Dashboard。

通知第一版通过 REST 查询即可。

## 13. 测试

只做真实核心验收：

- 登录和权限
- 设备 CRUD
- 巡检任务到异常
- RocketMQ 异常到缺陷
- 工单到验收
- DeepSeek 诊断
- PC 页面主链
- HarmonyOS 主链
- WebSocket 通知
- 一个 Sentinel 限流演示

只额外检查三个失败场景：

- DeepSeek 失败
- WebSocket 断线
- MQ 重复消息

不做生产级压力测试、混沌测试、高可用或集群故障演练。

## 14. 最终交付

最终正式产物只有：

1. 源代码
2. 团队项目实训报告
3. 个人实训报告
4. 答辩 PPT
5. 答辩讲稿

所有报告必须以真实最终代码和真实运行结果为依据。

## 15. 当前状态

- S1 基础设施：PASS
- S2-A common + auth + gateway：PASS
- S2-B device + inspection + maintenance + RocketMQ/WebSocket/Sentinel：PASS
- S3 DeepSeek + LangChain4j + LangGraph4j：PASS
- S4 PC Web：进行中
- S5 HarmonyOS：未开始
- S6 联调、演示、冻结和答辩材料：未开始

当前工作：

**S4-A PC Core。先校正角色/权限与交互基线，再按 Gate 1、Gate 2、Gate 3 逐关验收。**
