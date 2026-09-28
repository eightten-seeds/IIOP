# 基于微服务与 DeepSeek 大模型的工业设备智能巡检运维平台（IIOP）

## 项目目标

单人课程实训项目。

核心业务：

设备  
→ 巡检  
→ 异常  
→ 缺陷/工单  
→ AI 辅助诊断  
→ 维修  
→ 验收

## 技术栈

后端：

- JDK 17
- Spring Boot 3.5.0
- Spring Cloud 2025.0.0
- Spring Cloud Alibaba 2025.0.0.0
- MySQL / MyBatis-Plus
- Redis / Sa-Token
- Nacos / Sentinel / RocketMQ
- WebSocket

AI：

- DeepSeek
- LangChain4j
- LangGraph4j

客户端：

- Vue 3 / Element Plus / ECharts / Three.js / Vue Flow
- HarmonyOS / ArkTS / ArkUI

## 模块

- iiop-common
- iiop-gateway
- iiop-auth
- iiop-device
- iiop-inspection
- iiop-maintenance
- iiop-ai

## 第一版最简原则

只实现：

- Nacos 服务发现
- Redis 登录 Session
- 一个 RocketMQ 异步链
- 一个 Sentinel 限流示例
- 一个 WebSocket 通知链
- 一个 DeepSeek 5 节点诊断链
- 一个 PC 主业务端
- 一个 HarmonyOS 现场端

不做生产级复杂治理、额外平台或新微服务。

## 当前阶段

已完成：

- 工程与规范
- 5 个数据库 / 25 张表
- 本地基础设施
- common + auth + gateway

当前执行：

**S2-B：device + inspection + maintenance + 最小 RocketMQ/WebSocket/Sentinel 闭环。**

完整实施顺序见：

`docs/spec/05-roadmap.md`
