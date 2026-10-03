# IIOP · 工业设备智能巡检运维平台

基于微服务与 DeepSeek 大模型的工业设备智能巡检运维平台。

当前仓库已经形成设备、巡检、异常、缺陷、AI 辅助诊断、维修工单、验收的第一版完整业务模型，并进入 S6 联调、回归、团队交付与答辩准备阶段。

## 1. 核心业务链

```text
设备建档
→ 巡检模板 / 计划
→ 生成巡检任务
→ INSPECTOR 执行巡检
→ 上报异常
→ RocketMQ 形成缺陷
→ AI 辅助诊断
→ 人工确认
→ 人工创建维修工单
→ ADMIN / SUPER_ADMIN 分派
→ MAINTAINER 维修
→ ADMIN / SUPER_ADMIN 验收
→ 历史与通知
```

AI 在本项目中只负责辅助分析和生成建议，不直接控制设备，也不自动创建正式工单。

## 2. 固定角色

第一版业务角色固定为四种：

| 角色 | 职责 |
| --- | --- |
| `SUPER_ADMIN` | 系统治理、最高权限保护、全局业务兜底 |
| `ADMIN` | 设备/巡检/维修业务管理、用户日常管理、工单验收 |
| `INSPECTOR` | 执行本人巡检任务、填写检查项、上报异常、使用 AI 辅助诊断 |
| `MAINTAINER` | 处理本人维修工单、提交维修结果、使用/确认 AI 诊断 |

数据库 seed 定义 33 个 permission code。第一版运行时冻结角色、permission 和角色权限矩阵；角色/权限页面只读，用户仍可以在固定四角色范围内分配岗位。

详细规则见 [01-需求文档.md](./01-需求文档.md) 和 `docs/spec/06-role-usecases.md`。

## 3. 技术栈

### 后端

- JDK 17
- Spring Boot 3.5.0
- Spring Cloud 2025.0.0
- Spring Cloud Alibaba 2025.0.0.0
- MyBatis-Plus 3.5.17
- Sa-Token 1.46.0
- MySQL 8.x
- Redis
- Nacos
- RocketMQ
- Sentinel
- Spring WebSocket
- OpenFeign

### AI

- DeepSeek API
- LangChain4j 1.20.2
- LangGraph4j 1.9.2

### PC Web

- Vue 3
- TypeScript
- Vite
- Vue Router
- Pinia
- Axios
- Element Plus
- ECharts
- Three.js
- Vue Flow
- Browser WebSocket

### HarmonyOS

- Stage Model
- ArkTS
- ArkUI

## 4. 后端模块

| 模块 | 默认端口 | 职责 |
| --- | ---: | --- |
| `iiop-gateway` | 8080 | API/WS 统一入口、登录校验、Sentinel |
| `iiop-auth` | 9201 | 认证、用户、RBAC、通知、WebSocket |
| `iiop-device` | 9202 | 设备、分类、指标、SOP |
| `iiop-inspection` | 9203 | 模板、计划、任务、异常 |
| `iiop-maintenance` | 9204 | 告警、缺陷、工单、维修、验收 |
| `iiop-ai` | 9205 | DeepSeek 诊断与 LangGraph4j 工作流 |
| `iiop-common` | 无 | 公共 Result、错误码、DTO、MQ 事件 |

客户端统一通过 Gateway 访问公开业务 API。

详细服务调用关系见 [03-微服务架构设计.md](./03-微服务架构设计.md)。

## 5. 数据库

项目当前使用 5 个逻辑数据库、25 张业务表：

| 数据库 | 表数 |
| --- | ---: |
| `iiop_auth` | 6 |
| `iiop_device` | 5 |
| `iiop_inspection` | 6 |
| `iiop_maintenance` | 6 |
| `iiop_ai` | 2 |

各业务服务只直接访问自己的数据库，跨服务数据通过 REST / Feign 获取，不做跨库 JOIN。

完整表结构、唯一约束、状态字段和关系见 [02-数据库设计.md](./02-数据库设计.md)。

## 6. 当前已经实现的主要能力

### Auth / RBAC

- 图形验证码
- 登录 / 登出 / `/me`
- Sa-Token + Redis Session
- BCrypt 密码
- 用户管理
- 用户角色分配
- 固定角色/权限只读查看
- 401 / 403 语义分离
- 通知 REST
- 原生 WebSocket 通知

### Device

- 分类 CRUD
- 设备 CRUD
- 设备状态与风险
- 指标定义
- 指标数据、历史、趋势、快照
- SOP
- 设备统计
- 设备删除活动引用保护

### Inspection

- 巡检模板
- 检查项
- Vue Flow 流程定义
- 巡检计划
- 人工生成任务 + 定时调度到期任务
- 巡检执行
- 异常上报
- RocketMQ 发布异常事件

### Maintenance

- 告警
- 缺陷
- Defect 与 AI 绑定
- 工单创建
- 工单分派
- 维修执行
- 维修记录
- 工单日志
- 验收
- RocketMQ 异常消费与缺陷幂等

### AI

真实五节点：

```text
LOAD_CONTEXT
→ ANALYZE_WITH_DEEPSEEK
→ RISK_CHECK
→ GENERATE_ADVICE
→ PREPARE_WORK_ORDER_DRAFT
```

AI 会保存诊断主记录和工作流轨迹，并要求正式工单继续经过人工确认和人工创建。

### PC Web

当前已经存在：

- 角色工作台
- 设备列表 / 详情 / Three.js 空间视图
- 巡检模板 / 计划 / 任务 / 异常
- Vue Flow 模板流程编辑
- 缺陷 / 工单
- AI 诊断列表 / 详情
- 用户管理
- 角色 / 权限只读页
- 通知中心
- ECharts 真实业务统计
- WebSocket 实时通知与 AI 工作流进度
- 403 / 404 / 无角色 / 身份恢复失败页面

### HarmonyOS

当前主要服务现场岗位：

INSPECTOR：

```text
登录 → 今日巡检 → 任务详情 → 巡检执行 → 异常 → AI
```

MAINTAINER：

```text
登录 → 我的工单 → 工单详情 → 开始维修 → 提交维修结果 → AI
```

多角色用户可以在巡检和维修工作区之间切换。

## 7. 目录结构

```text
IIOP
├─ backend
│  ├─ iiop-common
│  ├─ iiop-gateway
│  ├─ iiop-auth
│  ├─ iiop-device
│  ├─ iiop-inspection
│  ├─ iiop-maintenance
│  └─ iiop-ai
├─ frontend
│  └─ iiop-web
├─ harmony
├─ infra
│  ├─ sql
│  └─ local
├─ scripts
├─ docs
│  └─ spec
├─ 01-需求文档.md
├─ 02-数据库设计.md
├─ 03-微服务架构设计.md
└─ README.md
```

## 8. 本地开发前置条件

PC 与后端开发需要：

- JDK 17
- Maven
- Node.js / npm
- MySQL
- Redis
- Nacos
- RocketMQ

HarmonyOS 开发还需要：

- DevEco Studio
- 项目所需 SDK
- Emulator 或真机
- 可用的 Debug 构建与签名环境

各成员电脑的软件安装目录、磁盘盘符、数据库账号和 Secret 由各自本地环境决定，仓库不把某一台电脑的绝对路径作为团队规范。

## 9. 本地配置原则

真实 Secret 不提交 Git，包括：

- MySQL 密码
- Redis 密码
- DeepSeek API Key
- Token
- 个人本机私有配置

各服务的环境变量和默认值以对应 `application.yml` 为准。

常见环境配置包括：

- `MYSQL_*_URL`
- `MYSQL_*_USERNAME`
- `MYSQL_*_PASSWORD`
- `REDIS_HOST`
- `REDIS_PORT`
- `REDIS_PASSWORD`
- `NACOS_SERVER_ADDR`
- `NACOS_NAMESPACE`
- `NACOS_GROUP`
- `ROCKETMQ_NAME_SERVER`
- `DEEPSEEK_API_KEY`
- `DEEPSEEK_BASE_URL`
- `DEEPSEEK_MODEL`

Web Gateway 地址可通过 `VITE_GATEWAY_URL` 配置。

HarmonyOS Gateway 地址位于：

```text
harmony/entry/src/main/ets/network/NetworkConfig.ets
```

设备、模拟器和网络环境不同，Gateway 地址按各成员自己的环境设置。

## 10. 数据库初始化

全新数据库按顺序执行：

```text
infra/sql/00_create_databases.sql
infra/sql/01_auth_schema.sql
infra/sql/02_device_schema.sql
infra/sql/03_inspection_schema.sql
infra/sql/04_maintenance_schema.sql
infra/sql/05_ai_schema.sql
infra/sql/06_seed_data.sql
```

`06_seed_data.sql` 初始化：

- 固定四角色；
- 33 个权限码；
- 固定角色权限映射；
- 虚构演示设备、指标、SOP、巡检模板等基础数据。

它不写入真实密码、Token 或 API Key。

`07_final_functional_closure.sql` 属于历史收口脚本，当前不作为 fresh database 第一次初始化的默认必跑步骤。

## 11. 后端构建

```bash
cd backend
mvn clean test
mvn package -DskipTests
```

后端运行前需要确保当前开发所需的 MySQL、Redis、Nacos、RocketMQ 等依赖已经可用。

仓库中的本地辅助启动脚本可以继续用于已有开发环境，但不作为所有成员电脑的统一安装路径规范。

## 12. PC Web

```bash
cd frontend/iiop-web
npm install
npm run dev
```

生产构建：

```bash
npm run build
```

开发服务器地址以 Vite 终端实际输出为准。

## 13. HarmonyOS

使用 DevEco Studio 打开 `harmony` 工程，按本机 SDK、设备和签名环境构建运行。

HarmonyOS 客户端只通过 Gateway 访问业务服务。

详细说明见 `harmony/README.md`。

## 14. 文档

正式项目文档：

- [01-需求文档.md](./01-需求文档.md)
- [02-数据库设计.md](./02-数据库设计.md)
- [03-微服务架构设计.md](./03-微服务架构设计.md)

内部实现规范：

- `docs/spec/00-overview.md`
- `docs/spec/01-database.md`
- `docs/spec/02-backend.md`
- `docs/spec/03-client.md`
- `docs/spec/04-ai.md`
- `docs/spec/05-roadmap.md`
- `docs/spec/06-role-usecases.md`

角色、数据范围、状态机和职责交接继续以 `docs/spec/06-role-usecases.md` 为冻结业务基线。

## 15. 当前阶段

当前阶段：

```text
S1 基础设施：PASS
S2 后端：PASS
S3 AI：PASS
S4 PC Web：主要代码已完成
S5 HarmonyOS：现场核心流程已实现
S6 联调、回归、团队交付、冻结和答辩：当前阶段
```

目前重点是：

- 完整主链回归；
- 多角色与权限回归；
- RocketMQ、WebSocket、AI 失败场景检查；
- 团队环境复现；
- 最终代码冻结；
- 实训报告和答辩材料。

## 16. 当前实现边界

为了保持课程项目第一版可运行、可解释、可答辩，当前没有实现：

- Docker / Kubernetes
- 分布式事务框架
- Outbox
- 服务网格
- 完整生产监控平台
- RAG
- 向量数据库
- Agent
- 多模型
- 低代码 / BI 平台
- AI 自动创建正式工单

这些能力不属于当前仓库实现，不应在报告或答辩中描述为已经完成。
