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

本节用于组员从 GitHub / Gitee 克隆仓库后建立自己的本地开发环境。仓库不包含真实数据库密码、Redis 密码、DeepSeek API Key、Token 或个人本机配置。

### 1. 克隆仓库

建议使用 Git 克隆，不建议下载 ZIP 后重新建仓库，这样可以保留分支和提交历史。

```bash
git clone <Gitee 或 GitHub 仓库地址>
cd IIOP
```

团队协作统一以 `main` 为稳定基线。开发新功能或修复时从 `main` 创建个人分支，不直接覆盖其他成员代码。

### 2. 本地依赖

基础开发环境：

- JDK 17
- Maven 3.9+
- Node.js / npm
- MySQL 8.x
- Redis
- Nacos 3.x
- RocketMQ 5.x

HarmonyOS 开发成员另外需要：

- DevEco Studio
- OpenHarmony / HarmonyOS SDK
- Phone Emulator 或可用真机
- Debug 签名配置

本项目第一版不使用 Docker。

### 3. 创建本地 Secret 配置

复制模板：

```powershell
Copy-Item scripts\dev\local-secrets.example.ps1 scripts\dev\local-secrets.ps1
```

然后编辑：

```text
scripts/dev/local-secrets.ps1
```

至少配置：

- `MYSQL_AUTH_USERNAME` / `MYSQL_AUTH_PASSWORD`
- `MYSQL_DEVICE_USERNAME` / `MYSQL_DEVICE_PASSWORD`
- `MYSQL_INSPECTION_USERNAME` / `MYSQL_INSPECTION_PASSWORD`
- `MYSQL_MAINTENANCE_USERNAME` / `MYSQL_MAINTENANCE_PASSWORD`
- `MYSQL_AI_USERNAME` / `MYSQL_AI_PASSWORD`
- `REDIS_PASSWORD`，本地 Redis 无密码时可留空
- `DEEPSEEK_API_KEY`，需要真实 AI 诊断时填写

`local-secrets.ps1` 已被 `.gitignore` 排除。禁止把真实密码或 API Key 提交到 GitHub / Gitee。

### 4. 初始化数据库

Fresh Database 第一次初始化按顺序执行：

```text
infra/sql/00_create_databases.sql
infra/sql/01_auth_schema.sql
infra/sql/02_device_schema.sql
infra/sql/03_inspection_schema.sql
infra/sql/04_maintenance_schema.sql
infra/sql/05_ai_schema.sql
infra/sql/06_seed_data.sql
```

`06_seed_data.sql` 只初始化角色、权限和基础演示数据，不提交真实登录密码。

`07_final_functional_closure.sql` 属于历史收口脚本。当前 fresh schema 已包含其中部分最终约束，因此组员首次建库时不要再次执行 `07`，避免重复索引冲突。后续如需做旧库迁移，应先核对目标数据库版本。

### 5. 创建首个超级管理员

Fresh Database 默认没有真实用户账号。

在 `local-secrets.ps1` 中设置：

```powershell
$env:IIOP_BOOTSTRAP_ADMIN_ENABLED = "true"
$env:IIOP_BOOTSTRAP_ADMIN_USERNAME = "superadmin"
$env:IIOP_BOOTSTRAP_ADMIN_PASSWORD = "至少8位的新密码"
```

Auth 服务第一次成功启动后会在 `dev` profile 下创建该 `SUPER_ADMIN`。确认账号已创建后，可以把 `IIOP_BOOTSTRAP_ADMIN_ENABLED` 改回 `false`。

不要在文档、群聊截图或 Git 仓库中共享真实密码。

### 6. 启动基础设施

确保以下本机服务可用：

| 组件 | 默认地址 / 端口 |
| --- | --- |
| MySQL | `127.0.0.1:3306` |
| Redis | `127.0.0.1:6379` |
| Nacos | `127.0.0.1:8848` |
| RocketMQ NameServer | `127.0.0.1:9876` |
| RocketMQ Broker | `127.0.0.1:10911` |

所有后端服务通过 Nacos 做服务发现。

### 7. 构建后端

在仓库根目录进入 `backend`：

```bash
cd backend
mvn clean test
mvn package -DskipTests
```

后端服务端口：

| 服务 | 端口 |
| --- | ---: |
| Gateway | 8080 |
| Auth | 9201 |
| Device | 9202 |
| Inspection | 9203 |
| Maintenance | 9204 |
| AI | 9205 |

客户端统一通过 Gateway `8080` 访问业务，不应直接依赖 9201 到 9205。

### 8. 启动 PC Web

```bash
cd frontend/iiop-web
npm install
npm run dev
```

默认访问：

```text
http://127.0.0.1:5173
```

如只做前端页面开发，至少保证 Gateway 和当前页面依赖的后端服务已启动。

### 9. 一键启动脚本说明

仓库根目录提供：

- `启动IIOP.bat`
- `启动IIOP鸿蒙端.bat`

当前这些脚本仍保留原开发机的固定 Windows 路径，例如 `E:\IIOP`、DevEco 安装目录、RocketMQ 安装目录等。

因此：

- 原开发机可以继续使用一键脚本；
- 组员电脑如果目录不同，不要直接认为脚本可以开箱即用；
- 组员首次运行优先按本章节手工完成依赖、数据库和构建；
- 后续如需让一键脚本跨机器通用，应把这些路径继续配置化。

这属于当前本地开发工具的环境约束，不影响项目业务代码通过标准 Maven / npm / DevEco 方式运行。

### 10. HarmonyOS 首次运行

HarmonyOS 端说明见：

```text
harmony/README.md
```

默认 Gateway 地址：

```text
http://10.0.2.2:8080
```

其中 `10.0.2.2` 是 Emulator 访问宿主机的地址。真机或不同模拟器网络环境需要按实际宿主机地址调整 `entry/src/main/ets/network/NetworkConfig.ets`。

### 11. 首次运行最小验收

组员环境搭建完成后至少确认：

1. Gateway `8080` 可访问；
2. Auth 能返回验证码；
3. Bootstrap Admin 可以登录；
4. `/api/auth/me` 能返回角色和 permissions；
5. Web 可以正常进入对应角色首页；
6. 创建巡检异常后 Maintenance 可以形成缺陷；
7. 需要 AI 时，DeepSeek Key 有效并可以完成一次诊断；
8. HarmonyOS 开发成员可以通过 Gateway 登录并打开本人任务或工单。

如果只做某一个模块，可以只启动与该模块相关的依赖，但提交合并前应回到完整主链做回归。

## 文档入口

- 项目总纲：`docs/spec/00-overview.md`
- 数据库：`docs/spec/01-database.md`
- 后端：`docs/spec/02-backend.md`
- PC / Harmony 客户端：`docs/spec/03-client.md`
- AI：`docs/spec/04-ai.md`
- 路线与验收：`docs/spec/05-roadmap.md`
- 角色、权限、业务流程冻结基线：`docs/spec/06-role-usecases.md`
- HarmonyOS 运行说明：`harmony/README.md`
