# 基于微服务与 DeepSeek 大模型的工业设备智能巡检运维平台（IIOP）

## 项目简介

IIOP 面向工业设备巡检与运维场景，计划建设由微服务后端、Vue3 PC 管理端和 HarmonyOS 移动端组成的平台，并逐步引入大模型辅助故障诊断与维修决策能力。

## 核心业务链

设备建档 → 巡检计划 → 巡检任务 → 执行巡检 → 发现异常 → 异常/告警 → AI 辅助诊断 → 生成维修建议 → 创建维修工单 → 维修处理 → 验收关闭 → 写入设备生命周期档案

## 计划技术栈

- 后端：JDK 17、Spring Boot 3.5.0、Spring Cloud 2025.0.0、Spring Cloud Alibaba 2025.0.0.0
- 后端配套：MySQL、MyBatis-Plus、Redis、Nacos、Sentinel、RocketMQ、Sa-Token、WebSocket
- AI：DeepSeek OpenAI Compatible API、LangChain4j、LangGraph4j
- PC：Vue 3、Vite、Axios、Pinia、Element Plus、Three.js、ECharts、Vue Flow
- 移动端：HarmonyOS、ArkTS、ArkUI

## 计划模块

- `iiop-common`：公共共享能力
- `iiop-gateway`：统一入口与网关能力
- `iiop-auth`：用户、权限与认证
- `iiop-device`：工业设备领域
- `iiop-inspection`：巡检计划、任务与记录
- `iiop-maintenance`：异常、告警与维修工单
- `iiop-ai`：智能诊断与 AI 工作流

## 目录说明

- `backend`：Spring Cloud 后端聚合工程
- `web`：Vue3 PC 管理端预留目录
- `harmony`：HarmonyOS 移动端预留目录
- `docs`：项目文档
- `infra`：基础设施配置与脚本

## 开发环境要求

- JDK 17
- Maven（本项目通过 `.mvn/maven.config` 使用 `E:/DevCache/maven/repository`）
- 后续前端和基础设施工具按兼容性单独确定

## 当前开发阶段

工程初始化已经完成，`docs/spec/00-overview.md` 到 `05-roadmap.md` 已完成 G0 最终一致性收口并作为第一版开发基线冻结。

当前尚未实现业务代码。下一阶段按照 `05-roadmap.md` 执行 M1 数据库 SQL，随后逐阶段完成基础设施、后端、AI、PC、HarmonyOS、联调测试和最终答辩材料。
