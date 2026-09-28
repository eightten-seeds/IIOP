# IIOP 项目总体实现规范

> 性质：内部开发规范，供 Codex 和后续代码审查使用。不是最终答辩交付文档。

## 1. 项目目标

项目名称：基于微服务与 DeepSeek 大模型的工业设备智能巡检运维平台（IIOP）。

核心业务闭环：

设备建档 → 巡检计划 → 巡检任务 → 执行巡检 → 异常/告警 → AI 辅助诊断 → 维修工单 → 维修执行 → 验收关闭 → 设备生命周期留痕。

系统必须包含：

- Spring Cloud 微服务后端
- Vue 3 PC 管理端
- HarmonyOS 移动端
- DeepSeek 智能诊断
- Redis、Nacos、Sentinel、RocketMQ
- Sa-Token
- WebSocket 实时通知
- Three.js 工业三维场景
- ECharts 数据驾驶舱
- Vue Flow 巡检流程设计

## 2. 技术基线

- JDK 17
- Spring Boot 3.5.0
- Spring Cloud 2025.0.0
- Spring Cloud Alibaba 2025.0.0.0
- MySQL 8.x
- MyBatis-Plus
- Redis
- Sa-Token
- Nacos
- Sentinel
- RocketMQ
- LangChain4j
- LangGraph4j
- DeepSeek OpenAI Compatible API
- Vue 3 + Vite + Axios + Pinia + pinia-plugin-persistedstate
- Element Plus
- Three.js
- ECharts
- @vue-flow/core
- HarmonyOS ArkTS + ArkUI

第三方库具体版本在首次真正引入时再确定，避免提前猜版本。

## 3. 微服务边界

### iiop-common
普通 Jar，不启动。只放跨服务通用的：
- Result<T>
- 错误码
- 公共异常
- 基础 DTO
- 常量
- 少量无业务依赖工具

不得放具体业务 Service、Mapper 或实体。

### iiop-gateway
- 统一 HTTP 入口
- 路由转发
- Sa-Token 协同鉴权
- Sentinel 网关限流
- 跨域
- 请求追踪

不拥有业务数据库。

### iiop-auth
拥有 auth 数据域：
- 用户
- 角色
- 权限
- 登录认证
- 用户通知持久化

### iiop-device
拥有 device 数据域：
- 设备分类
- 设备台账
- 设备状态
- 监测指标
- 监测数据
- SOP

### iiop-inspection
拥有 inspection 数据域：
- 巡检模板
- 巡检计划
- 巡检任务
- 巡检执行记录
- 巡检异常

### iiop-maintenance
拥有 maintenance 数据域：
- 告警
- 缺陷
- 维修工单
- 工单流转
- 维修记录
- 验收

### iiop-ai
拥有 AI 数据域：
- AI 会话
- AI 消息
- AI 诊断
- LangGraph4j 工作流轨迹

## 4. 数据与调用原则

1. 采用一个 MySQL 实例，五个逻辑数据库：
   - iiop_auth
   - iiop_device
   - iiop_inspection
   - iiop_maintenance
   - iiop_ai
2. 微服务只能直接访问自己拥有的数据库。
3. 跨服务只保存业务 ID，不创建跨库外键。
4. 跨服务数据通过 HTTP/OpenFeign 或事件获取。
5. 重要业务事件优先使用 RocketMQ 解耦。
6. 历史记录必须可追溯，模板变化不得破坏已完成任务历史。
7. AI 输出属于辅助判断，高风险工业操作必须人工确认。

## 5. 代码与 API 约定

- Java 包根：com.iiop
- Java 属性：camelCase
- 数据库字段：snake_case
- API 前缀：
  - /api/auth
  - /api/device
  - /api/inspection
  - /api/maintenance
  - /api/ai
- 统一响应：Result<T>
- 时间统一使用 ISO-8601 输出
- 所有分页接口统一 pageNum/pageSize
- 所有业务码、状态码使用明确英文枚举值
- 不允许 Controller 直接调用 Mapper
- 不允许跨服务直接共享实体类
- Feign 只使用明确 DTO

## 6. 安全和配置

- 禁止提交真实密码、Token、API Key
- DeepSeek Key、数据库密码等只通过环境变量或本地非提交配置注入
- Sa-Token 用于登录态和权限校验
- 密码只保存强哈希
- API 必须区分公开、登录、角色/权限接口
- AI 诊断结果必须保存模型名、提示词版本和人工确认状态

## 7. 本地约束

- 项目根：E:\IIOP
- Maven repo：E:/DevCache/maven/repository
- npm cache：E:/DevCache/npm
- 禁止主动把项目依赖或项目数据写入 C 盘

## 8. 最终答辩交付文档

开发阶段内部规范只服务于代码实现。最终正式文档只生成：
1. 团队项目实训报告
2. 个人实训报告
3. 答辩 PPT
4. 答辩讲稿
