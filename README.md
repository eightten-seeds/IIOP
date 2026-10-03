# 基于微服务与 DeepSeek 大模型的工业设备智能巡检运维平台（IIOP）

## 项目目标

课程实训项目，当前进入团队协作、联调和交付阶段。

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

已完成主要代码实现：

- S1 基础设施
- S2 后端与业务主链
- S3 DeepSeek + LangChain4j + LangGraph4j
- S4 PC Web 核心业务、可视化与交互
- S5 HarmonyOS 现场端核心流程

当前进入：

**S6 联调、回归、团队交付与答辩准备。**

角色、权限、数据范围和业务流程的冻结基线以 `docs/spec/06-role-usecases.md` 为准。完整阶段定义见 `docs/spec/05-roadmap.md`。

## 组员首次运行

本节用于组员在自己的电脑上建立 IIOP 本地开发环境。每个人的安装目录、磁盘盘符、数据库账号、Secret 和开发工具位置都可能不同，仓库文档不约定这些个人路径。

### 1. 克隆仓库

使用 Git 克隆仓库并进入项目目录：

```bash
git clone <GitHub 或 Gitee 仓库地址>
cd IIOP
```

团队协作以 `main` 为稳定基线。开发或修复从 `main` 创建个人分支，通过 PR 合并，避免多人直接覆盖主分支。

### 2. 准备本地依赖

PC 与后端开发需要：

- JDK 17
- Maven
- Node.js / npm
- MySQL
- Redis
- Nacos
- RocketMQ

HarmonyOS 开发另外需要：

- DevEco Studio
- 对应 HarmonyOS / OpenHarmony SDK
- 可用 Emulator 或真机
- Debug 构建与签名环境

本项目第一版不使用 Docker。

各工具安装到哪里由组员自己的电脑决定。需要通过 `JAVA_HOME`、系统 `PATH`、服务配置或本地环境变量让项目能够找到这些工具和服务。

### 3. 配置本地环境

仓库不保存真实数据库密码、Redis 密码、DeepSeek API Key、Token 等 Secret。

各后端服务的可配置项以对应的 `application.yml` 为准。常见配置包括：

- MySQL 连接地址、用户名和密码
- Redis 地址和密码
- Nacos 地址、namespace、group
- RocketMQ NameServer
- DeepSeek API Key、Base URL、模型名称

如果某个组件不运行在本机、端口与默认配置不同，按该组员自己的实际环境修改对应环境变量或本地配置。

不要把个人密码、API Key、Token 或本机私有配置提交到 GitHub / Gitee。

### 4. 初始化数据库

全新数据库第一次初始化按顺序执行：

```text
infra/sql/00_create_databases.sql
infra/sql/01_auth_schema.sql
infra/sql/02_device_schema.sql
infra/sql/03_inspection_schema.sql
infra/sql/04_maintenance_schema.sql
infra/sql/05_ai_schema.sql
infra/sql/06_seed_data.sql
```

`06_seed_data.sql` 初始化固定四角色、权限基线和演示业务基础数据。

`07_final_functional_closure.sql` 是历史收口脚本，当前不作为全新数据库首次初始化的必跑脚本。旧数据库迁移时应先核对已有索引和约束，再决定是否执行。

### 5. 构建后端

进入 `backend`：

```bash
mvn clean test
mvn package -DskipTests
```

后端包含 Gateway、Auth、Device、Inspection、Maintenance、AI 六个可启动服务。客户端统一通过 Gateway 访问业务。

如果构建失败，优先检查：

- JDK 是否为 17
- Maven 是否可用
- Maven 依赖是否完整
- 本地环境变量是否配置
- 基础设施是否按当前开发任务要求启动

### 6. 启动 PC Web

进入：

```text
frontend/iiop-web
```

执行：

```bash
npm install
npm run dev
```

开发服务器地址以终端实际输出为准。Web 访问的 Gateway 地址可通过前端环境配置调整。

### 7. 关于仓库中的一键启动脚本

仓库保留 Windows 一键启动脚本，用于现有开发环境快速启动。

这些脚本依赖本机已安装的软件、服务和开发工具，因此不作为所有组员电脑的统一环境标准。组员电脑环境不同时，应按自己的安装位置和服务配置运行项目，或在本机自行调整对应脚本。

本轮团队交付文档不会把任何成员电脑的盘符或软件安装目录写成公共规范。

### 8. HarmonyOS 本地运行

HarmonyOS 端统一通过 Gateway 访问业务。

网络配置位于：

```text
harmony/entry/src/main/ets/network/NetworkConfig.ets
```

Emulator、真机和不同网络环境访问宿主机的地址可能不同。组员应根据自己的 DevEco、设备和网络环境设置 Gateway 地址，不要直接照搬其他成员电脑的网络地址。

详细说明见 `harmony/README.md`。

### 9. 首次运行最小检查

环境准备完成后至少确认：

1. 所需基础设施已启动；
2. 六个后端服务能正常启动并注册；
3. Gateway 能访问 Auth 和业务服务；
4. Web 能通过 Gateway 调用真实 API；
5. 数据库表和基础数据已初始化；
6. 当前开发所需的业务主链可以完成；
7. 使用 AI 功能时，本机 DeepSeek 配置有效；
8. HarmonyOS 开发成员能从自己的设备环境访问 Gateway。

如果只开发某个模块，可以按需要启动相关服务；提交合并前应完成受影响业务链的回归。

## 文档入口

- 项目总纲：`docs/spec/00-overview.md`
- 数据库：`docs/spec/01-database.md`
- 后端：`docs/spec/02-backend.md`
- PC / Harmony 客户端：`docs/spec/03-client.md`
- AI：`docs/spec/04-ai.md`
- 路线与验收：`docs/spec/05-roadmap.md`
- 角色、权限、业务流程冻结基线：`docs/spec/06-role-usecases.md`
- HarmonyOS 运行说明：`harmony/README.md`
