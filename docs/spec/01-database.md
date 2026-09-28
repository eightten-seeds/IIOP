# IIOP 数据库与数据模型实现规范

> 文档编号：IIOP-SPEC-01  
> 文档性质：数据库设计与 SQL 实现基线  
> 上位规范：`docs/spec/00-overview.md`  
> 适用对象：Codex、后端开发、数据库脚本审查、最终报告数据库章节  
> 当前状态：设计基线，M1 阶段实现时必须遵循

---

## 1. 文档目的

本文档定义 IIOP 的数据库边界、逻辑库划分、表结构、字段语义、索引、唯一约束、状态枚举、跨服务引用规则、历史快照规则和初始化数据要求。

Codex 在 M1 阶段生成 SQL，以及后续生成 Entity、Mapper、Service、DTO 时，必须以本文档为数据库事实来源。不得根据页面方便程度临时增加重复字段，也不得为了减少代码量破坏微服务数据边界。

本文档当前规划 **5 个逻辑数据库、25 张业务表**。

---

## 2. 数据库总体策略

### 2.1 MySQL 实例与逻辑库

开发阶段采用一个 MySQL 8.x 实例，建立五个逻辑数据库：

| 逻辑数据库 | 数据所有者 | 主要内容 |
|---|---|---|
| `iiop_auth` | iiop-auth | 用户、角色、权限、通知 |
| `iiop_device` | iiop-device | 设备、指标、监测数据、SOP |
| `iiop_inspection` | iiop-inspection | 巡检模板、计划、任务、异常 |
| `iiop_maintenance` | iiop-maintenance | 告警、缺陷、工单、维修、验收 |
| `iiop_ai` | iiop-ai | AI 诊断、工作流轨迹 |

`iiop-gateway` 和 `iiop-common` 不拥有业务数据库。

### 2.2 数据所有权原则

每个可启动业务微服务只能直接访问自己拥有的逻辑数据库。

例如：

- iiop-inspection 可以保存 `device_id`；
- iiop-inspection 不得直接查询 `iiop_device.dev_device`；
- 需要设备详情时，通过 iiop-device 的 API 获取；
- iiop-ai 需要巡检历史时，通过 iiop-inspection API 获取；
- iiop-ai 需要维修历史时，通过 iiop-maintenance API 获取。

### 2.3 外键策略

第一版不创建跨数据库物理 FOREIGN KEY。

同一逻辑数据库内部也不强制创建物理 FOREIGN KEY，原因包括：

1. 降低初始化、演示和测试数据维护复杂度；
2. 避免未来服务拆库时产生额外迁移阻力；
3. 将一致性责任放到 Service 层事务和业务校验中；
4. 让跨服务 ID 与同库 ID 的使用方式保持一致。

因此，关联关系通过：

- 命名清晰的 `*_id` 字段；
- 必要索引；
- 唯一约束；
- Service 层存在性检查；
- 业务状态校验；

共同维护。

---

## 3. 全局数据库规范

### 3.1 字符集和存储引擎

所有数据库和表默认：

- Engine：InnoDB
- Charset：utf8mb4
- Collation：utf8mb4_0900_ai_ci

SQL 文件必须显式创建数据库并指定字符集。

### 3.2 主键

所有业务表使用：

`id BIGINT NOT NULL`

作为主键。

后续 Java 实体统一使用 `Long`，MyBatis-Plus 采用 `ASSIGN_ID`。

不得把业务编码作为主键。

不得使用 UUID 字符串作为默认主键。

### 3.3 业务编码

需要对外展示或业务追踪的核心对象必须具有业务编码，例如：

- DEV202609280001
- TASK202609280001
- ABN202609280001
- ALM202609280001
- WO202609280001
- AID202609280001

编码字段使用 `VARCHAR` 并建立唯一索引。

编码生成逻辑属于应用层，SQL 只负责唯一约束。

### 3.4 字段定义简写规则

为避免后续表格重复书写：

1. 字段列表中明确写 `NULL` 的字段允许为空；
2. 未明确写 `NULL` 的业务字段默认按 `NOT NULL` 实现；
3. 未明确给默认值的业务字段不自行增加业务默认值，由应用显式写入；
4. `created_at`、`updated_at`、`deleted` 等全局字段按本文全局规则处理；
5. 状态字段若章节明确给出默认值则使用该默认值，否则创建业务对象时由 Service 显式设置初始状态；
6. Codex 不得为了让 INSERT 更省事而擅自把核心字段改成可空。

### 3.5 时间字段

统一字段：

- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

只有确实不需要更新的日志、明细或关联表可以不包含 `updated_at`。

业务时间字段，例如：

- `reported_at`
- `scheduled_start_time`
- `repaired_at`

不得用 `created_at` 代替。

### 3.6 逻辑删除

需要允许后台“删除但保留历史”的主数据表使用：

`deleted TINYINT NOT NULL DEFAULT 0`

含义：

- 0：正常
- 1：已删除

以下类型通常使用逻辑删除：

- 用户；
- 角色；
- 权限；
- 设备分类；
- 设备；
- SOP；
- 巡检模板；
- 巡检计划。

交易历史、日志、监测数据、任务、异常、工单、AI 诊断原则上不逻辑删除。

### 3.7 状态字段

状态字段使用具有业务含义的英文编码，类型通常为 `VARCHAR(32)`。

禁止用难以理解的 0、1、2、3 表示复杂业务状态。

Java 代码后续使用 Enum 与数据库字符串对应。

### 3.8 布尔字段

布尔值使用：

`TINYINT NOT NULL DEFAULT 0`

字段名必须表达含义，例如：

- `required_flag`
- `human_confirmed`
- `success_flag`

### 3.9 JSON 使用边界

允许使用 JSON 的典型场景：

- 图片或附件 URL 列表；
- AI 原因列表；
- AI 排查步骤；
- 工作流节点输出；
- Three.js/Vue Flow 等天然 JSON 结构；
- AI 上下文快照。

禁止使用 JSON 代替：

- 用户角色关系；
- 角色权限关系；
- 设备分类；
- 巡检模板项；
- 工单流转；
- 其他明确的一对多或多对多核心关系。

### 3.10 金额、数值和百分比

- 金额：`DECIMAL(12,2)`
- 监测数值：`DECIMAL(18,6)`
- 坐标：`DECIMAL(12,3)`
- 完成率：`DECIMAL(5,2)`

禁止用 FLOAT/DOUBLE 存储金额。

### 3.11 索引原则

建立索引的依据必须是实际查询路径。

优先为以下字段建立索引：

- 业务编码；
- 状态；
- 设备 ID；
- 用户 ID；
- 时间；
- 常用组合查询条件。

避免：

- 给低选择性布尔字段单独建大量索引；
- 创建被复合索引完全覆盖的重复索引；
- 对长 TEXT 字段建普通索引。

---

# 4. iiop_auth 数据库

共 6 张表：

1. sys_user
2. sys_role
3. sys_permission
4. sys_user_role
5. sys_role_permission
6. sys_notification

---

## 4.1 sys_user 用户表

### 业务目的

保存平台登录用户和基础资料。

### 字段

| 字段 | 类型 | NULL | 默认值 | 说明 |
|---|---|---:|---|---|
| id | BIGINT | 否 | 无 | 主键 |
| username | VARCHAR(64) | 否 | 无 | 登录账号 |
| password_hash | VARCHAR(255) | 否 | 无 | 密码哈希 |
| real_name | VARCHAR(64) | 是 | NULL | 真实姓名或展示姓名 |
| phone | VARCHAR(32) | 是 | NULL | 手机号 |
| email | VARCHAR(128) | 是 | NULL | 邮箱 |
| avatar_url | VARCHAR(512) | 是 | NULL | 头像地址 |
| status | VARCHAR(32) | 否 | ENABLED | 用户状态 |
| last_login_time | DATETIME | 是 | NULL | 最近登录时间 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | 否 | 自动更新 | 更新时间 |
| deleted | TINYINT | 否 | 0 | 逻辑删除 |

### 状态

`status`：

- ENABLED
- DISABLED
- LOCKED

### 约束与索引

- PRIMARY KEY(id)
- UNIQUE(username)
- INDEX(status)
- 可对 phone/email 建普通索引，但 M1 第一版只在实际查询需要时创建

### 业务约束

- 禁止存明文密码；
- username 不因用户改名而变化；
- deleted=1 的用户不能登录。

---

## 4.2 sys_role 角色表

| 字段 | 类型 | NULL | 默认值 | 说明 |
|---|---|---:|---|---|
| id | BIGINT | 否 | 无 | 主键 |
| role_code | VARCHAR(64) | 否 | 无 | 角色编码 |
| role_name | VARCHAR(64) | 否 | 无 | 角色名称 |
| description | VARCHAR(255) | 是 | NULL | 描述 |
| status | VARCHAR(32) | 否 | ENABLED | 状态 |
| created_at | DATETIME | 否 | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | 否 | 自动更新 | 更新时间 |
| deleted | TINYINT | 否 | 0 | 逻辑删除 |

预置角色：

- SUPER_ADMIN
- ADMIN
- INSPECTOR
- MAINTAINER

约束：

- UNIQUE(role_code)

---

## 4.3 sys_permission 权限表

权限同时支持菜单、按钮和 API。

| 字段 | 类型 | NULL | 说明 |
|---|---|---:|---|
| id | BIGINT | 否 | 主键 |
| parent_id | BIGINT | 是 | 父权限 ID |
| permission_code | VARCHAR(128) | 否 | 权限编码 |
| permission_name | VARCHAR(128) | 否 | 权限名称 |
| permission_type | VARCHAR(32) | 否 | MENU/BUTTON/API |
| route_path | VARCHAR(255) | 是 | PC 路由 |
| api_path | VARCHAR(255) | 是 | API 路径 |
| http_method | VARCHAR(16) | 是 | GET/POST/PUT/DELETE 等 |
| sort_order | INT | 否 | 排序 |
| status | VARCHAR(32) | 否 | ENABLED/DISABLED |
| created_at | DATETIME | 否 | 创建时间 |
| updated_at | DATETIME | 否 | 更新时间 |
| deleted | TINYINT | 否 | 逻辑删除 |

约束：

- UNIQUE(permission_code)
- INDEX(parent_id)
- INDEX(permission_type)

---

## 4.4 sys_user_role 用户角色关联表

| 字段 | 类型 | NULL | 说明 |
|---|---|---:|---|
| id | BIGINT | 否 | 主键 |
| user_id | BIGINT | 否 | 用户 ID |
| role_id | BIGINT | 否 | 角色 ID |
| created_at | DATETIME | 否 | 创建时间 |

约束：

- UNIQUE(user_id, role_id)
- INDEX(role_id)

---

## 4.5 sys_role_permission 角色权限关联表

字段：

- id BIGINT
- role_id BIGINT
- permission_id BIGINT
- created_at DATETIME

约束：

- UNIQUE(role_id, permission_id)
- INDEX(permission_id)

---

## 4.6 sys_notification 用户通知表

### 业务目的

保存 WebSocket 通知的持久化事实。即使客户端离线，也可以在重新登录后查询。

| 字段 | 类型 | NULL | 说明 |
|---|---|---:|---|
| id | BIGINT | 否 | 主键 |
| recipient_user_id | BIGINT | 否 | 接收人 |
| notification_type | VARCHAR(32) | 否 | 通知类型 |
| title | VARCHAR(128) | 否 | 标题 |
| content | VARCHAR(1000) | 否 | 内容 |
| biz_type | VARCHAR(64) | 是 | 关联业务类型 |
| biz_id | BIGINT | 是 | 关联业务 ID |
| read_status | VARCHAR(16) | 否 | UNREAD/READ |
| read_time | DATETIME | 是 | 阅读时间 |
| created_at | DATETIME | 否 | 创建时间 |

`notification_type`：

- ALARM
- INSPECTION
- WORK_ORDER
- AI
- SYSTEM

索引：

- INDEX(recipient_user_id, read_status, created_at)
- INDEX(biz_type, biz_id)

---

# 5. iiop_device 数据库

共 5 张表：

1. dev_category
2. dev_device
3. dev_metric
4. dev_metric_data
5. dev_sop

---

## 5.1 dev_category 设备分类表

字段：

- id BIGINT
- parent_id BIGINT NULL
- category_code VARCHAR(64) NOT NULL
- category_name VARCHAR(128) NOT NULL
- description VARCHAR(500) NULL
- sort_order INT NOT NULL DEFAULT 0
- status VARCHAR(32) NOT NULL DEFAULT ENABLED
- created_at DATETIME
- updated_at DATETIME
- deleted TINYINT DEFAULT 0

约束：

- UNIQUE(category_code)
- INDEX(parent_id)
- INDEX(status)

第一版分类树深度不做硬编码限制。

---

## 5.2 dev_device 设备台账表

### 业务目的

这是整个工业运维平台的核心主数据。

### 字段

| 字段 | 类型 | NULL | 说明 |
|---|---|---:|---|
| id | BIGINT | 否 | 主键 |
| device_code | VARCHAR(64) | 否 | 设备编码 |
| device_name | VARCHAR(128) | 否 | 设备名称 |
| category_id | BIGINT | 否 | 设备分类 ID |
| model | VARCHAR(128) | 是 | 设备型号 |
| manufacturer | VARCHAR(128) | 是 | 制造商 |
| serial_number | VARCHAR(128) | 是 | 出厂序列号 |
| workshop | VARCHAR(128) | 是 | 车间 |
| production_line | VARCHAR(128) | 是 | 产线 |
| install_location | VARCHAR(255) | 是 | 安装位置 |
| responsible_user_id | BIGINT | 是 | 责任人用户 ID |
| status | VARCHAR(32) | 否 | 当前状态 |
| risk_level | VARCHAR(32) | 否 | 风险等级 |
| install_date | DATE | 是 | 安装日期 |
| warranty_expire_date | DATE | 是 | 质保截止日期 |
| model_url | VARCHAR(512) | 是 | glTF/glb 模型地址 |
| position_x | DECIMAL(12,3) | 是 | 三维 X 坐标 |
| position_y | DECIMAL(12,3) | 是 | 三维 Y 坐标 |
| position_z | DECIMAL(12,3) | 是 | 三维 Z 坐标 |
| remark | VARCHAR(1000) | 是 | 备注 |
| created_at | DATETIME | 否 | 创建时间 |
| updated_at | DATETIME | 否 | 更新时间 |
| deleted | TINYINT | 否 | 逻辑删除 |

状态：

`status`

- ONLINE
- OFFLINE
- FAULT
- MAINTENANCE
- SCRAPPED

`risk_level`

- LOW
- MEDIUM
- HIGH
- CRITICAL

约束与索引：

- UNIQUE(device_code)
- INDEX(category_id)
- INDEX(status)
- INDEX(risk_level)
- INDEX(responsible_user_id)
- INDEX(workshop)
- INDEX(production_line)

业务规则：

- 最近巡检时间和下次巡检时间属于 inspection 领域，不在 dev_device 冗余保存，避免 inspection 反向修改 device 数据库；
- PC 设备详情需要巡检摘要时通过 inspection API 聚合；
- SCRAPPED 设备不能继续生成新的巡检任务；
- FAULT 或 MAINTENANCE 可以继续查询历史；
- model_url 和 position_x/y/z 直接服务于 Three.js 场景。

---

## 5.3 dev_metric 设备监测指标定义表

### 业务目的

定义某设备可监测的数据项，例如温度、振动、压力、电流。

字段：

- id BIGINT
- device_id BIGINT
- metric_code VARCHAR(64)
- metric_name VARCHAR(128)
- unit VARCHAR(32) NULL
- value_type VARCHAR(32)
- warning_low DECIMAL(18,6) NULL
- warning_high DECIMAL(18,6) NULL
- critical_low DECIMAL(18,6) NULL
- critical_high DECIMAL(18,6) NULL
- status VARCHAR(32) DEFAULT ENABLED
- created_at DATETIME
- updated_at DATETIME
- deleted TINYINT DEFAULT 0

`value_type`：

- NUMBER
- BOOLEAN
- TEXT

约束：

- UNIQUE(device_id, metric_code)
- INDEX(device_id)
- INDEX(status)

对于 BOOLEAN/TEXT 指标，数值阈值允许为空。

---

## 5.4 dev_metric_data 设备监测数据表

### 业务目的

保存设备历史监测数据，为 ECharts 趋势、告警判断和 AI 上下文提供数据。

字段：

- id BIGINT
- device_id BIGINT
- metric_id BIGINT
- numeric_value DECIMAL(18,6) NULL
- text_value VARCHAR(255) NULL
- boolean_value TINYINT NULL
- quality VARCHAR(32) NOT NULL DEFAULT GOOD
- collect_time DATETIME NOT NULL
- created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP

`quality`：

- GOOD
- UNCERTAIN
- BAD

业务规则：

根据 dev_metric.value_type：

- NUMBER 使用 numeric_value；
- TEXT 使用 text_value；
- BOOLEAN 使用 boolean_value；

同一条记录只能有一种 value 字段代表有效值，Service 层负责校验。

索引：

- INDEX(device_id, collect_time)
- INDEX(metric_id, collect_time)

该表不做逻辑删除。

---

## 5.5 dev_sop SOP 表

字段：

- id BIGINT
- sop_code VARCHAR(64)
- title VARCHAR(128)
- category_id BIGINT NULL
- device_id BIGINT NULL
- sop_type VARCHAR(32)
- version VARCHAR(32)
- content LONGTEXT
- status VARCHAR(32)
- effective_date DATE NULL
- created_at DATETIME
- updated_at DATETIME
- deleted TINYINT DEFAULT 0

`sop_type`：

- INSPECTION
- MAINTENANCE
- SAFETY

`status`：

- DRAFT
- EFFECTIVE
- DISABLED

约束：

- UNIQUE(sop_code)
- INDEX(category_id)
- INDEX(device_id)
- INDEX(sop_type, status)

业务规则：

- device_id 有值时表示设备专属 SOP；
- category_id 有值时表示分类通用 SOP；
- AI 获取 SOP 时优先设备专属，其次设备分类。

---

# 6. iiop_inspection 数据库

共 6 张表：

1. ins_template
2. ins_template_item
3. ins_plan
4. ins_task
5. ins_task_item
6. ins_abnormal

---

## 6.1 ins_template 巡检模板表

字段：

- id BIGINT
- template_code VARCHAR(64)
- template_name VARCHAR(128)
- category_id BIGINT NULL
- version INT NOT NULL DEFAULT 1
- description VARCHAR(500) NULL
- flow_definition JSON NULL
- status VARCHAR(32) NOT NULL DEFAULT DRAFT
- created_at DATETIME
- updated_at DATETIME
- deleted TINYINT DEFAULT 0

`status`：

- DRAFT
- ENABLED
- DISABLED

`flow_definition` 用于 Vue Flow 保存巡检流程可视化 JSON。

约束：

- UNIQUE(template_code)
- INDEX(category_id)
- INDEX(status)

---

## 6.2 ins_template_item 巡检模板项表

字段：

- id BIGINT
- template_id BIGINT
- item_code VARCHAR(64)
- item_name VARCHAR(128)
- item_type VARCHAR(32)
- unit VARCHAR(32) NULL
- standard_value VARCHAR(255) NULL
- lower_limit DECIMAL(18,6) NULL
- upper_limit DECIMAL(18,6) NULL
- required_flag TINYINT NOT NULL DEFAULT 1
- sort_order INT NOT NULL DEFAULT 0
- inspection_method VARCHAR(500) NULL
- abnormal_hint VARCHAR(500) NULL
- created_at DATETIME
- updated_at DATETIME
- deleted TINYINT DEFAULT 0

`item_type`：

- NUMBER
- BOOLEAN
- TEXT
- PHOTO

约束：

- UNIQUE(template_id, item_code)
- INDEX(template_id, sort_order)

NUMBER 类型允许设置上下限。

---

## 6.3 ins_plan 巡检计划表

字段：

- id BIGINT
- plan_code VARCHAR(64)
- plan_name VARCHAR(128)
- device_id BIGINT
- template_id BIGINT
- schedule_type VARCHAR(32)
- cron_expression VARCHAR(128) NULL
- start_date DATE
- end_date DATE NULL
- assignee_user_id BIGINT
- status VARCHAR(32)
- last_generate_time DATETIME NULL
- next_generate_time DATETIME NULL
- created_at DATETIME
- updated_at DATETIME
- deleted TINYINT DEFAULT 0

`schedule_type`：

- DAILY
- WEEKLY
- MONTHLY
- CRON

`status`：

- ENABLED
- DISABLED

约束：

- UNIQUE(plan_code)
- INDEX(device_id)
- INDEX(template_id)
- INDEX(assignee_user_id)
- INDEX(status, next_generate_time)

业务规则：

- 只有 ENABLED 计划参与任务生成；
- start_date/end_date 限制生效区间；
- schedule_type=CRON 时 cron_expression 必填。

---

## 6.4 ins_task 巡检任务表

字段：

- id BIGINT
- task_code VARCHAR(64)
- plan_id BIGINT NULL
- device_id BIGINT
- template_id BIGINT
- assignee_user_id BIGINT
- task_status VARCHAR(32)
- overdue_flag TINYINT NOT NULL DEFAULT 0
- result_status VARCHAR(32)
- scheduled_start_time DATETIME
- scheduled_end_time DATETIME NULL
- actual_start_time DATETIME NULL
- actual_end_time DATETIME NULL
- completion_rate DECIMAL(5,2) NOT NULL DEFAULT 0
- remark VARCHAR(1000) NULL
- created_at DATETIME
- updated_at DATETIME

`task_status`：

- PENDING
- IN_PROGRESS
- COMPLETED
- CANCELLED

`result_status`：

- UNKNOWN
- NORMAL
- ABNORMAL

约束与索引：

- UNIQUE(task_code)
- INDEX(plan_id)
- INDEX(device_id, scheduled_start_time)
- INDEX(assignee_user_id, task_status)
- INDEX(task_status, scheduled_start_time)

状态规则：

- PENDING → IN_PROGRESS；
- IN_PROGRESS → COMPLETED；
- PENDING/IN_PROGRESS → CANCELLED（需业务权限）；
- 超过计划截止时间且仍未完成时，将 overdue_flag 标记为 1；task_status 保持 PENDING 或 IN_PROGRESS。

---

## 6.5 ins_task_item 巡检任务项表

### 业务目的

保存实际巡检结果，同时保存模板快照。

字段：

- id BIGINT
- task_id BIGINT
- template_item_id BIGINT NULL
- item_code VARCHAR(64)
- item_name VARCHAR(128)
- item_type VARCHAR(32)
- unit VARCHAR(32) NULL
- standard_value VARCHAR(255) NULL
- lower_limit DECIMAL(18,6) NULL
- upper_limit DECIMAL(18,6) NULL
- required_flag TINYINT NOT NULL DEFAULT 1
- inspection_method VARCHAR(500) NULL
- actual_value TEXT NULL
- result_status VARCHAR(32) NOT NULL DEFAULT PENDING
- remark VARCHAR(1000) NULL
- evidence_urls JSON NULL
- sort_order INT NOT NULL DEFAULT 0
- checked_at DATETIME NULL
- created_at DATETIME
- updated_at DATETIME

`result_status`：

- PENDING
- NORMAL
- ABNORMAL

约束：

- UNIQUE(task_id, item_code)
- INDEX(task_id, sort_order)
- INDEX(result_status)

业务规则：

创建任务时必须从模板复制：

- item_code
- item_name
- item_type
- unit
- standard_value
- lower_limit
- upper_limit
- required_flag
- inspection_method

因此模板后续修改不会改变历史任务。

---

## 6.6 ins_abnormal 巡检异常表

字段：

- id BIGINT
- abnormal_code VARCHAR(64)
- task_id BIGINT
- task_item_id BIGINT NULL
- device_id BIGINT
- abnormal_type VARCHAR(64)
- severity VARCHAR(32)
- title VARCHAR(128)
- description VARCHAR(2000)
- evidence_urls JSON NULL
- reported_by BIGINT
- reported_at DATETIME
- status VARCHAR(32)
- ai_diagnosis_id BIGINT NULL
- resolved_at DATETIME NULL
- created_at DATETIME
- updated_at DATETIME

`severity`：

- LOW
- MEDIUM
- HIGH
- CRITICAL

`status`：

- OPEN
- PROCESSING
- RESOLVED
- CLOSED

约束：

- UNIQUE(abnormal_code)
- INDEX(task_id)
- INDEX(device_id, reported_at)
- INDEX(severity, status)
- INDEX(reported_by, reported_at)

业务规则：

- 新建异常状态为 OPEN；
- 创建后发布 `iiop.inspection.abnormal` 事件；
- maintenance 和 ai 服务通过事件处理后续业务；
- inspection 不直接写 maintenance 或 ai 数据库。

---

# 7. iiop_maintenance 数据库

共 6 张表：

1. mt_alarm
2. mt_defect
3. mt_work_order
4. mt_work_order_log
5. mt_maintenance_record
6. mt_acceptance

---

## 7.1 mt_alarm 设备告警表

字段：

- id BIGINT
- alarm_code VARCHAR(64)
- device_id BIGINT
- metric_id BIGINT NULL
- source_type VARCHAR(32)
- source_id BIGINT NULL
- alarm_level VARCHAR(32)
- alarm_title VARCHAR(128)
- alarm_content VARCHAR(2000)
- alarm_value DECIMAL(18,6) NULL
- threshold_value DECIMAL(18,6) NULL
- occur_time DATETIME
- recover_time DATETIME NULL
- status VARCHAR(32)
- created_at DATETIME
- updated_at DATETIME

`source_type`：

- SENSOR
- INSPECTION
- MANUAL

`alarm_level`：

- INFO
- WARNING
- MAJOR
- CRITICAL

`status`：

- ACTIVE
- ACKNOWLEDGED
- RECOVERED
- CLOSED

约束：

- UNIQUE(alarm_code)
- INDEX(device_id, occur_time)
- INDEX(alarm_level, status)
- INDEX(source_type, source_id)

---

## 7.2 mt_defect 缺陷表

### 业务目的

将巡检异常、告警和人工发现的问题统一归一为可处理缺陷。

字段：

- id BIGINT
- defect_code VARCHAR(64)
- device_id BIGINT
- source_type VARCHAR(32)
- source_id BIGINT NULL
- title VARCHAR(128)
- description VARCHAR(2000)
- severity VARCHAR(32)
- reported_by BIGINT NULL
- reported_at DATETIME
- status VARCHAR(32)
- ai_diagnosis_id BIGINT NULL
- resolved_at DATETIME NULL
- created_at DATETIME
- updated_at DATETIME

`source_type`：

- INSPECTION_ABNORMAL
- ALARM
- MANUAL

`severity`：

- LOW
- MEDIUM
- HIGH
- CRITICAL

`status`：

- OPEN
- CONFIRMED
- PROCESSING
- RESOLVED
- CLOSED

约束：

- UNIQUE(defect_code)
- UNIQUE(source_type, source_id)
- INDEX(device_id, status)
- INDEX(severity, status)
- INDEX(source_type, source_id)
- INDEX(ai_diagnosis_id)
- INDEX(reported_at)

业务规则：

- 巡检异常事件创建 defect 后，后续 AI_DIAGNOSIS_SUCCEEDED 事件可把对应 diagnosisId 关联到 ai_diagnosis_id；
- maintenance 不同步调用 ai；
- 从 defect 创建工单时，如果 ai_diagnosis_id 已存在，则默认复制到 mt_work_order.ai_diagnosis_id；
- MANUAL defect 的 source_id 可以为空。

---

## 7.3 mt_work_order 维修工单表

字段：

- id BIGINT
- work_order_code VARCHAR(64)
- defect_id BIGINT NULL
- device_id BIGINT
- title VARCHAR(128)
- description VARCHAR(2000)
- work_order_type VARCHAR(32)
- priority VARCHAR(32)
- status VARCHAR(32)
- creator_user_id BIGINT
- assignee_user_id BIGINT NULL
- planned_start_time DATETIME NULL
- planned_end_time DATETIME NULL
- actual_start_time DATETIME NULL
- actual_end_time DATETIME NULL
- ai_diagnosis_id BIGINT NULL
- close_result VARCHAR(1000) NULL
- created_at DATETIME
- updated_at DATETIME

`work_order_type`：

- REPAIR
- PREVENTIVE
- EMERGENCY

`priority`：

- LOW
- MEDIUM
- HIGH
- URGENT

`status`：

- DRAFT
- PENDING
- ASSIGNED
- PROCESSING
- WAITING_ACCEPTANCE
- COMPLETED
- CANCELLED

索引：

- UNIQUE(work_order_code)
- INDEX(defect_id)
- INDEX(device_id, status)
- INDEX(assignee_user_id, status)
- INDEX(priority, status)
- INDEX(ai_diagnosis_id)
- INDEX(created_at)

推荐状态流：

DRAFT  
→ PENDING  
→ ASSIGNED  
→ PROCESSING  
→ WAITING_ACCEPTANCE  
→ COMPLETED

验收驳回时：

WAITING_ACCEPTANCE → PROCESSING

取消仅允许业务规则允许的未完成状态。

---

## 7.4 mt_work_order_log 工单流转日志

字段：

- id BIGINT
- work_order_id BIGINT
- action VARCHAR(64)
- from_status VARCHAR(32) NULL
- to_status VARCHAR(32) NULL
- operator_user_id BIGINT
- comment VARCHAR(1000) NULL
- attachments JSON NULL
- created_at DATETIME

索引：

- INDEX(work_order_id, created_at)
- INDEX(operator_user_id, created_at)

该表不修改历史记录。

---

## 7.5 mt_maintenance_record 维修记录表

字段：

- id BIGINT
- work_order_id BIGINT
- device_id BIGINT
- fault_cause VARCHAR(2000) NULL
- solution VARCHAR(3000) NOT NULL
- parts_used JSON NULL
- downtime_minutes INT NULL
- maintenance_cost DECIMAL(12,2) NULL
- result VARCHAR(32)
- repaired_by BIGINT
- repaired_at DATETIME
- created_at DATETIME
- updated_at DATETIME

`result`：

- SUCCESS
- PARTIAL
- FAILED

索引：

- INDEX(work_order_id)
- INDEX(device_id, repaired_at)
- INDEX(repaired_by, repaired_at)

---

## 7.6 mt_acceptance 维修验收表

字段：

- id BIGINT
- work_order_id BIGINT
- device_id BIGINT
- acceptance_result VARCHAR(32)
- acceptance_content VARCHAR(2000) NULL
- accepted_by BIGINT
- accepted_at DATETIME
- created_at DATETIME

`acceptance_result`：

- PASSED
- REJECTED

索引：

- INDEX(work_order_id, accepted_at)
- INDEX(device_id, accepted_at)

业务规则：

- PASSED 后工单进入 COMPLETED；
- REJECTED 后工单回到 PROCESSING；
- 每次验收都保留记录，不覆盖旧验收。

---

# 8. iiop_ai 数据库

共 2 张表：

1. ai_diagnosis
2. ai_workflow_trace

---

## 8.1 ai_diagnosis AI 诊断表

### 业务目的

保存 DeepSeek 辅助诊断的触发来源、输入快照、结构化结果、模型信息、运行状态和人工确认状态。

字段：

- id BIGINT
- diagnosis_code VARCHAR(64)
- trigger_type VARCHAR(32)
- trigger_id BIGINT NULL
- device_id BIGINT
- abnormal_summary VARCHAR(2000)
- user_description VARCHAR(2000) NULL
- risk_level VARCHAR(32) NULL
- possible_causes JSON NULL
- investigation_steps JSON NULL
- maintenance_advice LONGTEXT NULL
- safety_notice VARCHAR(2000) NULL
- context_snapshot JSON NULL
- model_name VARCHAR(128) NULL
- prompt_version VARCHAR(64) NULL
- diagnosis_status VARCHAR(32)
- confirmation_status VARCHAR(32)
- confirmed_by BIGINT NULL
- confirmed_at DATETIME NULL
- confirmation_comment VARCHAR(1000) NULL
- error_message VARCHAR(2000) NULL
- created_at DATETIME
- updated_at DATETIME

`trigger_type`：

- INSPECTION_ABNORMAL
- ALARM
- MANUAL

`risk_level`：

- LOW
- MEDIUM
- HIGH
- CRITICAL

`diagnosis_status`：

- PENDING
- RUNNING
- SUCCEEDED
- FAILED

`confirmation_status`：

- PENDING
- CONFIRMED
- REJECTED

约束与索引：

- UNIQUE(diagnosis_code)
- UNIQUE(trigger_type, trigger_id)
- INDEX(device_id, created_at)
- INDEX(diagnosis_status)
- INDEX(confirmation_status)

业务规则：

- MANUAL 诊断的 trigger_id 为 NULL；MySQL 唯一索引允许多条 NULL，因此可以重复发起人工诊断；
- INSPECTION_ABNORMAL 和 ALARM 的 trigger_type + trigger_id 唯一，作为事件幂等的数据库兜底；
- DeepSeek 调用成功且结构化结果校验通过后才能标记 SUCCEEDED；
- 调用失败或结构化结果校验失败标记 FAILED；
- AI 输出不能直接改变设备控制状态；
- 只有人工操作才能将 confirmation_status 改为 CONFIRMED/REJECTED；
- context_snapshot 保存本次诊断实际使用的关键上下文，便于追溯。

---

## 8.2 ai_workflow_trace AI 工作流轨迹表

字段：

- id BIGINT
- diagnosis_id BIGINT
- node_code VARCHAR(64)
- node_name VARCHAR(128)
- node_status VARCHAR(32)
- input_summary VARCHAR(2000) NULL
- output_data JSON NULL
- error_message VARCHAR(2000) NULL
- started_at DATETIME NULL
- finished_at DATETIME NULL
- created_at DATETIME

`node_status`：

- PENDING
- RUNNING
- SUCCEEDED
- FAILED
- SKIPPED

第一版固定 5 个节点：

1. LOAD_CONTEXT
2. ANALYZE_WITH_DEEPSEEK
3. RISK_CHECK
4. GENERATE_ADVICE
5. PREPARE_WORK_ORDER_DRAFT

索引：

- INDEX(diagnosis_id, created_at)
- INDEX(diagnosis_id, node_code)

允许同一 node_code 在故障重试或人工重新发起的新诊断中产生新的 trace；单次 diagnosis 的节点按工作流实际执行情况记录。

---

# 9. 跨服务 ID 引用清单

以下字段只保存远端服务业务 ID，不建立物理外键。

| 当前服务 | 字段 | 来源服务 |
|---|---|---|
| device | dev_device.responsible_user_id | auth |
| inspection | ins_template.category_id | device |
| inspection | ins_plan.device_id | device |
| inspection | ins_plan.assignee_user_id | auth |
| inspection | ins_task.device_id | device |
| inspection | ins_task.assignee_user_id | auth |
| inspection | ins_abnormal.device_id | device |
| inspection | ins_abnormal.reported_by | auth |
| maintenance | mt_alarm.device_id | device |
| maintenance | mt_alarm.metric_id | device |
| maintenance | mt_defect.device_id | device |
| maintenance | mt_defect.reported_by | auth |
| maintenance | mt_defect.ai_diagnosis_id | ai |
| maintenance | mt_work_order.device_id | device |
| maintenance | mt_work_order.creator_user_id | auth |
| maintenance | mt_work_order.assignee_user_id | auth |
| maintenance | mt_work_order.ai_diagnosis_id | ai |
| maintenance | 日志/维修/验收用户字段 | auth |
| ai | ai_diagnosis.device_id | device |
| ai | ai_diagnosis.confirmed_by | auth |

Service 层在关键写入前按业务需要检查远端对象是否存在。

---

# 10. 关键状态机

## 10.1 巡检任务

正常路径：

PENDING → IN_PROGRESS → COMPLETED

异常路径：

- PENDING → CANCELLED
- IN_PROGRESS → CANCELLED
逾期不作为任务生命周期状态。达到计划截止时间仍未完成时，将 \`overdue_flag\` 标记为 1；任务仍保持 PENDING 或 IN_PROGRESS。这样既保留真实生命周期状态，也能独立统计逾期任务。

## 10.2 巡检异常

OPEN → PROCESSING → RESOLVED → CLOSED

## 10.3 告警

ACTIVE → ACKNOWLEDGED → RECOVERED → CLOSED

某些自动恢复告警可以：

ACTIVE → RECOVERED

## 10.4 缺陷

OPEN → CONFIRMED → PROCESSING → RESOLVED → CLOSED

## 10.5 工单

DRAFT → PENDING → ASSIGNED → PROCESSING → WAITING_ACCEPTANCE → COMPLETED

驳回：

WAITING_ACCEPTANCE → PROCESSING

取消：

未完成状态 → CANCELLED

## 10.6 AI 诊断

运行状态：

PENDING → RUNNING → SUCCEEDED

失败：

RUNNING → FAILED

人工确认状态独立：

PENDING → CONFIRMED

或：

PENDING → REJECTED

---

# 11. 历史快照规则

为了保证报告、审计和历史查询可信，以下场景必须保存快照。

### 11.1 巡检任务项快照

任务生成后，ins_task_item 保存模板项关键字段。

后续模板变化不会修改已生成任务。

### 11.2 工单流转快照

每次状态变化写入 mt_work_order_log。

不得只保存 mt_work_order 当前状态而丢失过程。

### 11.3 AI 诊断上下文

ai_diagnosis.context_snapshot 保存诊断当时使用的关键上下文。

后续设备资料变化时，仍可以解释当时 AI 为什么给出该结果。

# 12. Three.js、ECharts、Vue Flow 对数据库的反向要求

数据库设计不能只满足 CRUD，还必须支撑项目要求中的可视化功能。

## 12.1 Three.js

依赖 dev_device：

- model_url
- position_x
- position_y
- position_z
- status
- risk_level

三维场景可以按这些字段加载模型、定位、着色和显示状态。

## 12.2 ECharts

至少依赖：

- dev_device.status
- dev_device.risk_level
- dev_metric_data.collect_time
- ins_task.task_status
- ins_task.result_status
- ins_abnormal.severity/status/reported_at
- mt_alarm.alarm_level/status/occur_time
- mt_work_order.priority/status/created_at

因此这些字段必须有适合统计的明确枚举和值。

## 12.3 Vue Flow

依赖：

`ins_template.flow_definition JSON`

用于保存巡检流程节点和边。

流程 JSON 是展示和配置数据，真正的巡检模板项仍然使用 ins_template_item 正常建模。

---

# 13. AI 对数据库的反向要求

AI 诊断需要的数据来源：

### 设备上下文

iiop_device：

- dev_device
- dev_metric
- dev_metric_data
- dev_sop

### 巡检上下文

iiop_inspection：

- ins_task
- ins_task_item
- ins_abnormal

### 维修上下文

iiop_maintenance：

- mt_alarm
- mt_defect
- mt_work_order
- mt_maintenance_record
- mt_acceptance

### AI 自身追踪

iiop_ai：

- ai_diagnosis
- ai_workflow_trace

AI 服务不得跨库直接 JOIN 上述表。

后续通过各服务 API 聚合上下文。

---

# 14. 初始化演示数据

M1 的 `06_seed_data.sql` 只生成演示数据，不生成真实账号密码。演示数据使用固定的小范围 BIGINT ID（例如 1001 起），后续 MyBatis-Plus ASSIGN_ID 生成的分布式 ID 与这些演示 ID 不会发生实际冲突。

## 14.1 角色

固定插入：

- SUPER_ADMIN
- ADMIN
- INSPECTOR
- MAINTAINER

## 14.2 权限

M1 固定插入以下权限编码。后端注解、PC 路由和按钮、HarmonyOS 功能都必须使用同一组编码，禁止后续自行发明近义权限码。

### 通用与设备

- dashboard:view
- device:view
- device:create
- device:update
- device:delete

### 巡检

- inspection:view
- inspection:template:manage
- inspection:plan:manage
- inspection:execute
- inspection:abnormal:process

### 运维

- maintenance:view
- maintenance:alarm:process
- maintenance:defect:process
- maintenance:workorder:create
- maintenance:workorder:process
- maintenance:workorder:accept

### AI

- ai:view
- ai:diagnosis
- ai:confirm

### 系统管理

- system:user:view
- system:user:create
- system:user:update
- system:user:delete
- system:user:role
- system:role:view
- system:role:create
- system:role:update
- system:role:delete
- system:role:permission
- system:permission:view
- system:permission:create
- system:permission:update
- system:permission:delete

### 预置角色的基础授权

SUPER_ADMIN：

- 拥有全部权限。

ADMIN：

- 拥有全部业务域权限；
- 拥有用户、角色和权限管理能力。

INSPECTOR：

- dashboard:view
- device:view
- inspection:view
- inspection:execute
- ai:view
- ai:diagnosis

MAINTAINER：

- device:view
- maintenance:view
- maintenance:alarm:process
- maintenance:defect:process
- maintenance:workorder:create
- maintenance:workorder:process
- maintenance:workorder:accept
- ai:view
- ai:diagnosis
- ai:confirm

06_seed_data.sql 应同时插入角色、权限以及上述角色权限关系。SUPER_ADMIN 的全部权限关系必须来自 sys_role_permission，不通过“角色名硬编码绕过 RBAC”。

## 14.3 设备分类

至少：

- 数控机床
- 工业机器人
- 空压机
- 输送设备
- 电机

## 14.4 演示设备

创建 5 到 10 台虚构工业设备。

要求：

- 覆盖至少 4 种设备状态；
- 覆盖 LOW/MEDIUM/HIGH/CRITICAL 风险；
- 具有 workshop、production_line 和三维坐标；
- 不使用真实企业、真实人员或真实生产数据。

## 14.5 监测指标

示例：

数控机床：

- 主轴温度
- 主轴振动
- 主轴电流

空压机：

- 排气压力
- 排气温度

电机：

- 温度
- 振动
- 电流

## 14.6 巡检模板

创建 2 到 3 套模板，并插入对应检查项。

示例：

- 数控机床日常巡检
- 空压机日常巡检
- 电机安全巡检

## 14.7 SOP

至少插入：

- 一个 INSPECTION SOP；
- 一个 MAINTENANCE SOP；
- 一个 SAFETY SOP。

禁止：

- 真实密码；
- DeepSeek API Key；
- 数据库密码；
- 真实手机号；
- 真实邮箱；
- 真实企业敏感数据。

---

# 15. SQL 文件拆分

M1 必须生成：

```text
infra/sql/
├─ 00_create_databases.sql
├─ 01_auth_schema.sql
├─ 02_device_schema.sql
├─ 03_inspection_schema.sql
├─ 04_maintenance_schema.sql
├─ 05_ai_schema.sql
└─ 06_seed_data.sql
```

职责：

### 00_create_databases.sql

只创建五个逻辑数据库。

### 01_auth_schema.sql

USE iiop_auth;

创建 auth 的 6 张表。

### 02_device_schema.sql

USE iiop_device;

创建 device 的 5 张表。

### 03_inspection_schema.sql

USE iiop_inspection;

创建 inspection 的 6 张表。

### 04_maintenance_schema.sql

USE iiop_maintenance;

创建 maintenance 的 6 张表。

### 05_ai_schema.sql

USE iiop_ai;

创建 ai 的 2 张表。

### 06_seed_data.sql

按逻辑数据库分别 USE 并插入演示数据。

---

# 16. SQL 编写要求

每个 SQL 文件必须：

1. UTF-8；
2. 关键表和字段包含中文 COMMENT；
3. 使用 IF NOT EXISTS 创建数据库和表；
4. 不包含 DROP DATABASE；
5. 不包含真实密钥；
6. 不包含跨库 FOREIGN KEY；
7. 不使用触发器实现核心业务；
8. 不使用存储过程实现核心业务；
9. 不把状态流转逻辑放入数据库；
10. 不把 AI Prompt 写入 SQL；
11. 插入演示数据时尽量可重复执行或至少清楚标注依赖。

---

# 17. M1 静态验收标准

Codex 完成 M1 后，必须静态检查以下内容。

### 17.1 数量

- 5 个逻辑数据库；
- 25 张业务表；
- 不多建临时业务表；
- 不漏表。

### 17.2 结构

- 每表有 BIGINT 主键；
- 主数据有 created_at/updated_at；
- 需要逻辑删除的表有 deleted；
- 业务编码有唯一约束；
- JSON 只用于适合 JSON 的字段；
- 金额使用 DECIMAL；
- 监测数值使用 DECIMAL。

### 17.3 边界

- 无跨库物理外键；
- 无服务直接共享表；
- gateway/common 无业务数据库；
- 跨服务字段只有业务 ID。

### 17.4 安全

- 无真实密码；
- 无 API Key；
- 无 Token；
- 无真实个人信息；
- 无真实企业敏感数据。

### 17.5 查询能力

至少能够支持未来实现：

- 用户登录与 RBAC；
- 设备列表和设备详情；
- Three.js 设备场景；
- ECharts 设备状态和趋势；
- 巡检计划和任务；
- 异常上报；
- 告警和缺陷；
- 工单闭环；
- AI 诊断；
- AI 工作流轨迹；
- WebSocket 历史通知。

---

# 18. Codex 在 M1 阶段的禁止事项

M1 只实现数据库 SQL。

禁止：

- 生成 Java Entity；
- 生成 Mapper；
- 生成 Controller；
- 初始化 Vue；
- 初始化 HarmonyOS；
- 下载 MySQL；
- 启动 Docker；
- 运行数据库迁移；
- 自行增加数据库；
- 自行增加微服务；
- 自行改变 25 张表的范围。

如果发现本文档存在无法实现或明显冲突的地方，Codex 应停止并报告，不应自行修改架构。

---

# 19. 与后续代码的映射

M2 以后生成 Java 实体时：

- 表名保持本文档不变；
- Java 类使用语义化名称，例如 `SysUser`、`DevDevice`、`InsTask`；
- Entity 只对应本服务数据库；
- 跨服务只使用 ID 和 DTO；
- 枚举根据本文档状态值生成；
- MyBatis-Plus 的逻辑删除仅用于明确带 deleted 的表；
- JSON 字段需要统一 TypeHandler 或明确序列化策略；
- 所有时间字段使用 Java Time API。

---

# 20. 当前结论

M1 阶段数据库范围已经固定为：

- iiop_auth：6 表；
- iiop_device：5 表；
- iiop_inspection：6 表；
- iiop_maintenance：6 表；
- iiop_ai：2 表；

合计 **25 张业务表**。

这个模型足以支撑：

- RBAC；
- 设备台账；
- 工业三维场景；
- 实时监测；
- 巡检任务；
- 异常和告警；
- 维修工单闭环；
- ECharts；
- Vue Flow；
- WebSocket 通知；
- DeepSeek 智能诊断；
- LangGraph4j 工作流追踪；
- 最终实训报告中的数据库、业务流程和核心功能说明。

未经明确确认，后续 Codex 不得重新设计该数据库边界。
