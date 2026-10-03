# IIOP

**基于微服务与 DeepSeek 大模型的工业设备智能巡检运维平台**

IIOP 是课程实训项目，围绕工业设备“巡检发现问题、诊断问题、维修问题、验收闭环”的真实业务过程实现。

当前代码已经覆盖核心业务主链，项目处于联调、回归、团队交付和答辩准备阶段。

---

## 1. 核心业务

系统主链：

```text
设备
→ 巡检模板
→ 巡检计划
→ 巡检任务
→ 巡检执行
→ 异常上报
→ RocketMQ
→ 缺陷
→ AI 辅助诊断
→ 人工确认
→ 维修工单
→ 工单分派
→ 维修执行
→ 验收
→ 历史与通知
```

AI 只提供辅助诊断和工单草案。

正式工单、人员分派、维修结果和验收都必须由人完成。

---

## 2. 固定角色

第一版固定四个业务角色：

| 角色 | 职责 |
| --- | --- |
| `SUPER_ADMIN` | 系统治理、最高权限保护、业务兜底 |
| `ADMIN` | 设备、巡检、维修业务管理，用户管理，工单验收 |
| `INSPECTOR` | 执行本人巡检任务、填写检查项、上报异常 |
| `MAINTAINER` | 处理本人维修工单、提交维修结果 |

授权判断不只依赖角色。

实际业务动作由以下条件共同决定：

```text
permission
∩ role
∩ data scope
∩ state
∩ ownership
```

例如 MAINTAINER 即使拥有工单处理 permission，也只能处理分派给自己的工单。

---

## 3. 技术栈

### 后端

- JDK 17
- Spring Boot 3.5.0
- Spring Cloud 2025.0.0
- Spring Cloud Alibaba 2025.0.0.0
- MyBatis-Plus 3.5.17
- Sa-Token 1.46.0
- OpenFeign
- MySQL 8.x
- Redis
- Nacos
- RocketMQ
- Sentinel
- Spring WebSocket

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

---

## 4. 后端服务

后端包含 6 个可启动服务和 1 个公共模块：

| 模块 | 默认端口 | 数据库 | 主要职责 |
| --- | ---: | --- | --- |
| `iiop-gateway` | 8080 | 无 | API/WS 统一入口、登录校验、Sentinel |
| `iiop-auth` | 9201 | `iiop_auth` | 登录、用户、RBAC、通知、WebSocket |
| `iiop-device` | 9202 | `iiop_device` | 设备、分类、指标、SOP |
| `iiop-inspection` | 9203 | `iiop_inspection` | 模板、计划、任务、异常 |
| `iiop-maintenance` | 9204 | `iiop_maintenance` | 告警、缺陷、工单、维修、验收 |
| `iiop-ai` | 9205 | `iiop_ai` | DeepSeek 诊断、五节点工作流 |
| `iiop-common` | 无 | 无 | 公共返回、错误码、分页、MQ DTO |

PC Web 和 HarmonyOS 只通过 Gateway 访问公开业务 API。

---

## 5. 微服务关系

```text
PC Web ───────────────┐
                      ▼
                 iiop-gateway
                      │
        ┌─────────────┼─────────────┬─────────────┬─────────────┐
        ▼             ▼             ▼             ▼             ▼
     iiop-auth    iiop-device   iiop-inspection  iiop-maintenance  iiop-ai
        │             │             │             │             │
   iiop_auth     iiop_device   iiop_inspection  iiop_maintenance  iiop_ai
                                    │
                                    │ RocketMQ
                                    ▼
                              iiop-maintenance

HarmonyOS ───────────► iiop-gateway

iiop-ai ─────────────► DeepSeek API
```

服务注册与发现使用 Nacos。

Sa-Token Session 使用 Redis。

---

## 6. RocketMQ 业务链

第一版只保留一条核心异步业务链：

```text
巡检异常
→ iiop_inspection_abnormal
→ Maintenance Consumer
→ 缺陷
```

Producer：

```text
iiop-inspection
group: iiop-inspection-producer
```

Consumer：

```text
iiop-maintenance
group: iiop-maintenance-defect
```

重复消息由业务查询和数据库唯一约束共同保证幂等。

Consumer 处理失败会向消息框架重新抛出异常，不会静默吞掉。

---

## 7. AI 诊断

AI 服务实际运行五节点 LangGraph4j 工作流：

```text
LOAD_CONTEXT
→ ANALYZE_WITH_DEEPSEEK
→ RISK_CHECK
→ GENERATE_ADVICE
→ PREPARE_WORK_ORDER_DRAFT
```

AI 上下文来自：

- Device 设备与指标；
- SOP；
- Inspection 巡检历史和异常；
- Maintenance 告警和维修历史。

AI 输出包括：

- 风险等级；
- 异常摘要；
- 可能原因；
- 排查步骤；
- 维修建议；
- 安全提示；
- 工单草案。

正式工单仍必须经过人工确认和人工创建。

---

## 8. PC Web

PC Web 目录：

```text
frontend/iiop-web
```

当前主要页面：

- 登录
- Dashboard
- 设备列表 / 详情
- Three.js 设备空间视图
- 巡检模板 / 计划 / 任务 / 异常
- Vue Flow 模板流程
- 缺陷
- 维修工单
- AI 诊断
- 用户管理
- 角色只读
- 权限只读
- 通知中心
- 403 / 404 / 无角色 / 身份恢复失败

Dashboard 使用真实 API 数据。

WebSocket 用于业务通知和 AI 工作流进度。

---

## 9. HarmonyOS

HarmonyOS 工程：

```text
harmony
```

移动端主要服务现场岗位。

### INSPECTOR

```text
登录
→ 今日巡检
→ 任务详情
→ 巡检执行
→ 异常
→ AI
```

### MAINTAINER

```text
登录
→ 我的工单
→ 工单详情
→ 开始维修
→ 提交维修结果
→ AI
```

同时拥有 INSPECTOR + MAINTAINER 的用户可以切换两个现场工作区。

ADMIN / SUPER_ADMIN 的复杂管理继续在 PC 完成。

---

## 10. 数据库

项目当前实际使用：

```text
5 个逻辑数据库
25 张表
```

| 数据库 | 表数 |
| --- | ---: |
| `iiop_auth` | 6 |
| `iiop_device` | 5 |
| `iiop_inspection` | 6 |
| `iiop_maintenance` | 6 |
| `iiop_ai` | 2 |

每个业务服务只直接访问自己的数据库。

跨服务业务关系通过 ID + REST / Feign 维护，不做跨库 JOIN。

---

## 11. 关键数据一致性

数据库当前有以下关键唯一约束：

```text
ins_task(plan_id, scheduled_start_time)
→ 同一计划窗口任务唯一

mt_defect(source_type, source_id)
→ 同一异常来源缺陷唯一

mt_work_order(defect_id)
→ 同一缺陷正式工单唯一

mt_work_order(ai_diagnosis_id)
→ 同一 AI 正式工单唯一

ai_diagnosis(trigger_type, trigger_id)
→ 同一非 MANUAL 触发对象诊断唯一
```

设备删除前还会调用 Inspection 和 Maintenance 检查活动引用。

存在活动引用或检查服务不可用时，Device 不执行删除。

---

## 12. 项目目录

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
│
├─ frontend
│  └─ iiop-web
│
├─ harmony
│
├─ infra
│  ├─ sql
│  └─ local
│
├─ scripts
│
├─ docs
│  └─ spec
│
├─ 01-需求文档.md
├─ 02-数据库设计.md
├─ 03-微服务架构设计.md
└─ README.md
```

---

## 13. 正式文档

仓库根目录的三份正式设计文档：

- [01-需求文档.md](./01-需求文档.md)
- [02-数据库设计.md](./02-数据库设计.md)
- [03-微服务架构设计.md](./03-微服务架构设计.md)

其中：

### 需求与业务

查看：

```text
01-需求文档.md
```

包含：

- 四角色；
- 主业务链；
- 状态约束；
- PC / Harmony；
- AI 人工确认；
- 验收标准。

### 数据库

查看：

```text
02-数据库设计.md
```

包含：

- 5 个逻辑库；
- 25 张表；
- 关键字段；
- 状态；
- 唯一约束；
- 跨库关系；
- 初始化流程。

### 微服务架构

查看：

```text
03-微服务架构设计.md
```

包含：

- Gateway；
- Auth；
- Device；
- Inspection；
- Maintenance；
- AI；
- Nacos；
- Redis；
- RocketMQ；
- WebSocket；
- 服务调用关系。

---

## 14. 内部实现规范

`docs/spec` 继续保留开发过程中的详细规范：

- `docs/spec/00-overview.md`
- `docs/spec/01-database.md`
- `docs/spec/02-backend.md`
- `docs/spec/03-client.md`
- `docs/spec/04-ai.md`
- `docs/spec/05-roadmap.md`
- `docs/spec/06-role-usecases.md`

其中角色、数据范围、状态机和职责分离仍以：

```text
docs/spec/06-role-usecases.md
```

作为冻结业务依据。

---

## 15. 本地开发前置条件

后端和 PC 开发需要：

- JDK 17
- Maven
- Node.js / npm
- MySQL 8.x
- Redis
- Nacos
- RocketMQ

HarmonyOS 开发另外需要：

- DevEco Studio
- 对应 SDK
- Emulator 或真机
- Debug 构建与签名环境

本项目第一版不使用 Docker 作为标准开发运行方式。

各成员电脑的软件安装位置由各自环境决定。

仓库文档不规定个人磁盘盘符或工具安装目录。

---

## 16. 默认本地服务地址

以下是代码中的本地默认值，不是某个成员电脑的安装目录。

| 组件 | 默认地址 |
| --- | --- |
| MySQL | `127.0.0.1:3306` |
| Redis | `127.0.0.1:6379` |
| Nacos | `127.0.0.1:8848` |
| RocketMQ NameServer | `127.0.0.1:9876` |
| Gateway | `127.0.0.1:8080` |

`127.0.0.1` 在每台电脑上都表示当前电脑本机。

如果基础设施部署在其他机器或使用不同端口，通过对应环境变量修改。

---

## 17. 本地配置

真实 Secret 不提交 Git。

包括：

- MySQL 密码；
- Redis 密码；
- DeepSeek API Key；
- Token；
- 个人环境配置。

主要环境变量：

### Auth DB

```text
MYSQL_AUTH_URL
MYSQL_AUTH_USERNAME
MYSQL_AUTH_PASSWORD
```

### Device DB

```text
MYSQL_DEVICE_URL
MYSQL_DEVICE_USERNAME
MYSQL_DEVICE_PASSWORD
```

### Inspection DB

```text
MYSQL_INSPECTION_URL
MYSQL_INSPECTION_USERNAME
MYSQL_INSPECTION_PASSWORD
```

### Maintenance DB

```text
MYSQL_MAINTENANCE_URL
MYSQL_MAINTENANCE_USERNAME
MYSQL_MAINTENANCE_PASSWORD
```

### AI DB

```text
MYSQL_AI_URL
MYSQL_AI_USERNAME
MYSQL_AI_PASSWORD
```

### Redis

```text
REDIS_HOST
REDIS_PORT
REDIS_PASSWORD
```

### Nacos

```text
NACOS_SERVER_ADDR
NACOS_NAMESPACE
NACOS_GROUP
```

### RocketMQ

```text
ROCKETMQ_NAME_SERVER
```

### DeepSeek

```text
DEEPSEEK_API_KEY
DEEPSEEK_BASE_URL
DEEPSEEK_MODEL
```

### PC Gateway

```text
VITE_GATEWAY_URL
```

配置细节以各服务 `application.yml` 为准。

---

## 18. 初始化数据库

全新数据库第一次初始化顺序：

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

- 四个固定角色；
- 33 个 permission；
- 固定角色权限矩阵；
- 虚构设备、指标、SOP、巡检模板等基础演示数据。

它不创建真实登录账号，也不写入真实密码、API Key 或 Token。

### 关于 07

```text
infra/sql/07_final_functional_closure.sql
```

属于历史收口迁移脚本。

当前 fresh schema 已经包含其中的关键唯一约束，所以全新数据库不要再次执行 07。

---

## 19. 构建后端

进入：

```bash
cd backend
```

执行测试：

```bash
mvn clean test
```

构建：

```bash
mvn package -DskipTests
```

构建后可以：

- 在 IDE 中分别启动各服务 Application；
- 或运行各模块 `target` 中生成的 Spring Boot Jar。

启动前需要确保当前任务依赖的：

- MySQL；
- Redis；
- Nacos；
- RocketMQ；

已经可用。

AI 功能还需要有效 DeepSeek API Key。

---

## 20. 启动 PC Web

进入：

```bash
cd frontend/iiop-web
```

安装依赖：

```bash
npm install
```

启动：

```bash
npm run dev
```

构建：

```bash
npm run build
```

Web 开发服务器地址以 Vite 终端实际输出为准。

默认 Gateway 配置为本机 8080，也可以通过 `VITE_GATEWAY_URL` 修改。

---

## 21. 启动 HarmonyOS

使用 DevEco Studio 打开：

```text
harmony
```

完成：

1. SDK 配置；
2. Emulator 或真机准备；
3. Debug 签名；
4. Gateway 网络地址配置；
5. 构建；
6. 安装；
7. 运行。

网络配置位于：

```text
harmony/entry/src/main/ets/network/NetworkConfig.ets
```

模拟器和真机访问开发机的地址可能不同，应按实际网络环境配置。

详细说明：

```text
harmony/README.md
```

---

## 22. 仓库中的本地启动脚本

仓库保留 Windows 本地辅助启动脚本。

这些脚本属于开发辅助工具，不是团队统一安装目录规范。

不同组员电脑：

- 项目目录可能不同；
- JDK 目录可能不同；
- DevEco 目录可能不同；
- Nacos / RocketMQ 安装目录可能不同。

因此团队文档以标准 Maven、npm 和 DevEco 流程为准。

需要使用本地辅助脚本时，由对应成员按自己的环境处理。

---

## 23. 团队协作建议

`main` 作为稳定分支。

建议流程：

```text
main
 ↓
feature/<name>
或
fix/<name>
 ↓
commit
 ↓
push
 ↓
Pull Request
 ↓
review
 ↓
main
```

不要多人直接覆盖 `main`。

提交前至少确认：

- 没有真实密码；
- 没有 API Key；
- 没有 Token；
- 没有个人私有配置；
- 没有无关构建产物。

---

## 24. 最小回归主链

代码合并前建议验证：

```text
登录
→ /me
→ 设备
→ 巡检计划
→ 巡检任务
→ 巡检执行
→ 异常
→ RocketMQ 缺陷
→ AI
→ 人工确认
→ 工单
→ 分派
→ 维修
→ 验收
```

同时检查：

- 401；
- 403；
- 409；
- 429；
- WebSocket；
- 多角色；
- 无角色；
- Device 删除引用保护。

---

## 25. 当前实现边界

当前项目没有实现：

- Docker / Kubernetes 标准部署；
- 分布式事务；
- Outbox；
- Service Mesh；
- 完整生产级可观测性平台；
- RAG；
- Vector DB；
- Agent；
- 多模型；
- AI 自动创建正式工单；
- AI 自动控制设备；
- 完整数字孪生平台；
- 低代码平台；
- BI 平台。

这些内容不应在实训报告和答辩中描述为“已经完成”。

---

## 26. 当前阶段

当前代码已经完成主要业务模块。

现阶段重点：

- 完整业务主链联调；
- 权限和多角色回归；
- RocketMQ 异常链验证；
- WebSocket 验证；
- AI 成功 / 失败场景验证；
- HarmonyOS 联调；
- 团队环境复现；
- 最终代码冻结；
- 实训报告；
- 答辩材料。

项目当前以“真实可运行、业务闭环、角色职责明确、实现与文档一致”为第一优先级。
