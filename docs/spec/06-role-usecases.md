# IIOP 角色、用例与业务交互基线

> 文档编号：IIOP-SPEC-06  
> 文档性质：角色、数据范围、业务用例、状态机与人机交互的冻结基线  
> 适用阶段：S4-A Gate 2、Gate 3、S4-B、S5、S6  
> 上位规范：`00-overview.md`、`01-database.md`  
> 关联规范：`02-backend.md`、`03-client.md`、`04-ai.md`、`05-roadmap.md`

## 1. 文档目的与优先级

本文件用于在继续开发业务页面前冻结以下问题：

- 系统到底有几种业务角色；
- 每种角色为什么使用系统；
- 每种角色能看什么、能做什么、不能做什么；
- 角色之间如何交接业务；
- 每个状态下页面应显示什么操作；
- AI 成功、失败、拒绝时业务如何继续；
- 权限、角色和数据范围如何同时生效；
- PC 与 HarmonyOS 如何使用同一套业务规则；
- 当前 API 哪些已经支持，哪些必须在 Gate 2 补齐。

第一版课程项目的业务角色、业务流程和人机交互以本文件为事实来源。

如果 `03-client.md` 中旧页面描述与本文件冲突，以本文件的角色职责、数据范围、状态流转和交接关系为准；数据库字段和枚举仍以 `01-database.md` 为准。

Gate 2 开始后不得自行增加第五种业务角色、改变角色职责、改变主业务链或发明新的权限码。发现冲突时先报告并按本文件校正，不得自行重新设计。

---

## 2. 角色模型

### 2.1 固定四种业务角色

第一版正式验收只认以下四种业务角色：

| roleCode | 中文名称 | 岗位定位 | 默认工作区 |
|---|---|---|---|
| SUPER_ADMIN | 超级管理员 | 系统治理、最高权限保护、全业务兜底 | /dashboard |
| ADMIN | 业务管理员 | 业务配置、调度、用户日常管理、工单验收 | /dashboard |
| INSPECTOR | 巡检人员 | 执行巡检、填写检查项、上报异常、查看/发起 AI | /inspection/tasks |
| MAINTAINER | 维修人员 | 缺陷处理、AI 诊断与确认、维修执行 | /maintenance/work-orders |

四种角色是课程项目的业务 Actor。

RocketMQ、IIOP 系统、DeepSeek、LangGraph4j 属于系统参与者，不属于登录角色。

现有角色/权限 CRUD API 可保留作为技术能力，但第一版 PC 和 HarmonyOS 不提供“创建第五种业务角色”“创建新权限码”的产品流程，也不把自定义角色作为答辩或验收范围。

### 2.2 Role 与 Permission 的职责

角色负责：

- 岗位身份；
- 默认首页；
- 菜单工作视角；
- 行级数据范围；
- 某些状态步骤的岗位责任，例如分派、维修、验收。

Permission 负责：

- 页面访问；
- 按钮授权；
- API 授权。

任何页面和后端 API 都不得仅凭 roleCode 绕过 permission。

当业务步骤要求特定岗位时，应同时满足：

1. 当前用户拥有对应 permission；
2. 当前角色符合岗位职责；
3. 当前业务对象状态允许；
4. 涉及本人数据时，当前用户是对象的 assignee。

### 2.3 多角色用户

数据库允许一个用户拥有多个角色，第一版允许多角色账号。

规则：

- permissions 为所有 ENABLED 角色权限的并集；
- 只有 ENABLED 角色可以贡献 permissions；
- 菜单为多个角色工作视角的并集，再由 permissions 最终过滤；
- 默认首页优先级固定为：
  SUPER_ADMIN > ADMIN > MAINTAINER > INSPECTOR；
- Header 应能显示用户全部角色，不能只让多角色用户误以为自己只有第一个角色。

SUPER_ADMIN 建议使用独立账号，不作为普通现场账号的附加角色。

### 2.4 无角色用户

用户可以存在但暂未分配岗位。

无角色用户：

- 可以通过正确账号密码完成身份认证；
- 不拥有业务 permission；
- 登录后进入专用“尚未分配岗位”页面；
- 页面提示“账号尚未分配岗位，请联系管理员”；
- 只允许退出，不进入 Dashboard 或业务模块；
- 不得因为 roles/permissions 为空反复调用 /me 或产生路由循环。

前端必须区分：

- “身份尚未加载”
- “身份已加载但 roles 为空”

这两种状态。

### 2.5 账号状态

只有 ENABLED 用户可以登录。

DISABLED / LOCKED 用户登录失败。

用户被禁用或锁定后，现有 Session 必须失效。

第一版不实现“现场人员被禁用后自动迁移全部在途任务/工单”的复杂跨服务补偿；管理员在停用现场账号前应先处理其在途工作。此限制必须在用户状态变更确认框中提示。

---

## 3. 数据范围

权限解决“能否访问模块”，数据范围解决“进入模块以后能看到哪些业务对象”。

| 对象 | SUPER_ADMIN | ADMIN | INSPECTOR | MAINTAINER |
|---|---|---|---|---|
| 设备 | 全部 | 全部 | 全部只读 | 全部只读 |
| 巡检模板 | 全部 | 全部 | 不进入管理页 | 不进入 |
| 巡检计划 | 全部 | 全部 | 不进入管理页 | 不进入 |
| 巡检任务 | 全部 | 全部 | 只看分配给本人任务 | 不进入 |
| 巡检异常 | 全部 | 全部 | 只看本人任务产生的异常 | 不作为维修入口 |
| 缺陷 | 全部 | 全部 | 不进入维修管理 | 全部可查看 |
| 维修工单 | 全部 | 全部 | 不进入 | 默认只看分配给本人；创建者可看到刚创建的待分派工单 |
| AI 诊断 | 全部 | 全部 | 可查看/发起，不确认 | 可查看/发起/确认 |
| 通知 | 仅本人 | 仅本人 | 仅本人 | 仅本人 |
| 用户 | 全部 | 普通用户管理 | 无 | 无 |
| 角色/权限 | 查看治理基线 | 只读查看 | 无 | 无 |

### 3.1 第一版不做复杂 AI 行级权限

AI 表没有 created_by 字段，第一版不新增表或字段。

因此拥有 ai:view 的业务角色可以查看 AI 诊断列表；角色工作台和业务页面应优先从当前异常/缺陷进入相关诊断，避免把 AI 列表当作主要工作入口。

INSPECTOR 不能确认 AI，也不能据 AI 草案创建维修工单。

### 3.2 后端必须执行的数据范围

以下规则不能只靠前端过滤：

- INSPECTOR 只能 start / submit item / create abnormal / complete 自己被分配的巡检任务；
- MAINTAINER 只能 start / repair-result 自己被分配的维修工单；
- MAINTAINER 不能执行 acceptance；
- ADMIN / SUPER_ADMIN 才能执行工单 assign；
- 计划 assignee 必须是 ENABLED INSPECTOR；
- 工单 assignee 必须是 ENABLED MAINTAINER。

---

## 4. SUPER_ADMIN 用例

### UC-SA-01 系统用户治理

前置：SUPER_ADMIN 已登录。

可以：

- 创建用户；
- 编辑用户基础资料；
- 启用、禁用、锁定普通用户；
- 删除普通用户；
- 为用户分配现有角色；
- 授予或移除 SUPER_ADMIN；
- 修改 SUPER_ADMIN 账号状态。

高风险操作必须二次确认。

不得在页面或日志中显示密码哈希、登录 Token 或本地测试密码。

### UC-SA-02 查看角色与权限基线

SUPER_ADMIN 可以查看：

- 四个预置业务角色；
- 每个角色当前权限；
- 33 个固定 permission code。

第一版 UI 不提供创建第五个业务角色或创建新 permission 的入口。

第一版角色权限矩阵以 seed/spec 为冻结基线，PC 只读展示，避免动态修改后造成默认首页、菜单和岗位职责互相冲突。

### UC-SA-03 全业务兜底

SUPER_ADMIN 可以在具备对应 permission 时查看和执行全部业务模块，用于系统治理、演示和异常兜底。

正常业务演示仍优先使用 ADMIN、INSPECTOR、MAINTAINER 完成岗位交接。

### UC-SA-04 工单验收

前置：WorkOrder.status = WAITING_ACCEPTANCE。

SUPER_ADMIN 可选择：

- PASSED：工单 -> COMPLETED，关联缺陷 -> RESOLVED；
- REJECTED：工单 -> PROCESSING，回到维修人员继续处理。

验收必须记录内容、验收人和时间。

---

## 5. ADMIN 用例

ADMIN 是 PC 端主要业务管理岗位。

### UC-AD-01 设备建档

流程：

选择分类
-> 填设备编码、名称、型号、位置等
-> 设置设备状态与风险
-> 保存

交互要求：

- categoryId 使用分类选择器；
- responsibleUserId 使用用户选择器；
- status / riskLevel 使用受控枚举；
- installLocation 使用真实后端字段，不使用 location 伪字段；
- 保存成功后进入设备详情或刷新列表。

### UC-AD-02 配置巡检模板

流程：

创建模板
-> 配置检查项
-> NUMBER / BOOLEAN / TEXT
-> 配置 requiredFlag
-> 启用模板

只有 ENABLED 模板可以用于生成任务。

PHOTO 第一版不是阻塞项。

### UC-AD-03 创建巡检计划

流程：

选择设备
-> 选择 ENABLED 模板
-> 选择 ENABLED INSPECTOR
-> 选择 DAILY / WEEKLY / MONTHLY / CRON
-> 保存并启用

不得要求用户手工输入 deviceId、templateId、assigneeUserId。

后端必须验证 assignee 真实具有 INSPECTOR 角色且账号为 ENABLED。

### UC-AD-04 生成巡检任务

前置：

- Plan.status = ENABLED；
- Device.status != SCRAPPED；
- Template.status = ENABLED；
- 模板至少一个检查项。

操作“生成任务”必须二次确认。

结果：

- Task.status = PENDING；
- task items 从模板项快照生成；
- assigneeUserId 来自计划。

### UC-AD-05 查看异常与缺陷

巡检异常是“现场事实记录”，Defect 是“维修处理对象”。

主链：

Abnormal
-> RocketMQ
-> Defect OPEN

第一版不在 Abnormal 页面维护第二套维修状态机。

`inspection:abnormal:process` 保留为固定 permission code，但当前没有真实处理 API 时前端不显示虚构操作。

异常详情应显示：

- 来源任务；
- 设备；
- 检查项；
- 严重程度；
- 是否已形成缺陷；
- 缺陷导航；
- AI 诊断导航。

### UC-AD-06 发起 AI 诊断

从异常/缺陷进入 AI 时，真实 trigger 映射：

- Defect.sourceType = INSPECTION_ABNORMAL
  -> triggerType = INSPECTION_ABNORMAL
  -> triggerId = defect.sourceId
- Defect.sourceType = ALARM
  -> triggerType = ALARM
  -> triggerId = defect.sourceId
- Defect.sourceType = MANUAL
  -> triggerType = MANUAL
  -> triggerId = null
  -> abnormalSummary 使用缺陷摘要

页面不得向用户暴露“请输入 triggerId”。

同步调用期间：

- 显示“AI 诊断生成中”；
- 禁止重复提交；
- 网络超时不能自动重复创建诊断，应提示“结果可能已生成，请刷新诊断列表”。

### UC-AD-07 AI 人工确认

只有：

- diagnosisStatus = SUCCEEDED
- confirmationStatus = PENDING

时显示确认/拒绝。

规则：

- 所有要用于 AI 草案转真实工单的诊断都必须先 CONFIRMED；
- HIGH / CRITICAL 显示强化人工确认警告；
- CONFIRM comment 可选；
- REJECT comment 必填；
- CONFIRMED / REJECTED 后隐藏重复操作。

REJECTED：

- 不创建工单；
- 不关闭缺陷；
- 不改变设备；
- AI 草案不能直接转工单；
- 用户可以返回缺陷页面人工创建工单。

FAILED：

- 显示失败摘要和五节点 trace；
- 可以返回缺陷人工建工单；
- 可以按业务需要重新发起 MANUAL 诊断；
- AI 失败不能阻塞维修主链。

### UC-AD-08 根据确认后的 AI 草案创建工单

前置：

- Diagnosis.status = SUCCEEDED；
- confirmationStatus = CONFIRMED；
- 用户拥有 maintenance:workorder:create。

流程：

显示 WorkOrderDraft
-> 用户检查/修改允许的工单字段
-> 明确点击创建
-> POST maintenance work-order
-> 状态 PENDING

AI confirm 本身不得创建 maintenance 数据。

真实工单至少关联：

- deviceId；
- defectId（存在时）；
- aiDiagnosisId（来自 AI 时）；
- title / description；
- workOrderType；
- priority。

第一版真实 WorkOrder 不使用持久化 DRAFT 作为主流程起点；AI WorkOrderDraft 只是前端待审核草案，正式提交后直接为 PENDING。

### UC-AD-09 分派工单

只有 ADMIN / SUPER_ADMIN 执行分派。

前置：

WorkOrder.status = PENDING。

流程：

选择 ENABLED MAINTAINER
-> 确认分派
-> PENDING -> ASSIGNED
-> 生成工单日志
-> 创建通知

后端必须验证 assignee 是 ENABLED MAINTAINER。

### UC-AD-10 工单验收

前置：

WorkOrder.status = WAITING_ACCEPTANCE。

PASSED：

- WorkOrder -> COMPLETED；
- Defect -> RESOLVED；
- 保存 acceptance；
- 保存日志。

REJECTED：

- WorkOrder -> PROCESSING；
- 保存驳回原因；
- MAINTAINER 再次维修后重新提交验收。

验收页面必须显示维修记录和历史验收结果，不能只显示原始 JSON。

### UC-AD-11 日常用户管理

ADMIN 可以：

- 创建普通用户；
- 编辑普通用户；
- 启用/停用/锁定普通用户；
- 分配 ADMIN / INSPECTOR / MAINTAINER；
- 查看角色/权限矩阵。

ADMIN 不能：

- 授予或移除 SUPER_ADMIN；
- 禁用或锁定 SUPER_ADMIN；
- 删除用户；
- 修改角色权限基线；
- 创建第五种业务角色；
- 创建新 permission。

前端分配角色必须先加载目标用户已有角色，再进行增删，禁止用空数组误覆盖现有角色。

---

## 6. INSPECTOR 用例

### UC-IN-01 我的巡检任务

默认入口：`/inspection/tasks`。

默认只显示 assigneeUserId = 当前用户的任务。

首屏重点：

- 待执行；
- 进行中；
- 已完成；
- 计划时间；
- 设备名称；
- 逾期标识。

空状态：

“当前没有分配给你的巡检任务”。

### UC-IN-02 开始巡检

前置：

- taskStatus = PENDING；
- 当前用户是 task.assigneeUserId；
- 当前用户拥有 inspection:execute。

操作：

开始巡检
-> PENDING -> IN_PROGRESS

重复开始或别人任务由后端拒绝。

### UC-IN-03 填写检查项

只有 IN_PROGRESS 可填写。

控件：

- NUMBER -> 数值输入；
- BOOLEAN -> 明确“正常/异常”选择；
- TEXT -> 文本输入；
- resultStatus -> NORMAL / ABNORMAL 受控选择。

页面实时显示：

“已完成 X / Y，剩余 N 个必填项”。

requiredFlag=1 且 resultStatus=PENDING 时，“完成巡检”禁用。

### UC-IN-04 上报异常

只有当前用户被分配且任务处于 IN_PROGRESS 时可以从该任务上报异常。

用户输入：

- 标题；
- 描述；
- severity；
- 可选关联 taskItem。

系统填充：

- deviceId；
- reportedBy；
- reportedAt；
- status=OPEN。

创建成功后发布 RocketMQ 异常事件。

### UC-IN-05 完成巡检

前置：

- IN_PROGRESS；
- 当前用户是 assignee；
- 所有 required 项已提交。

结果：

- Task -> COMPLETED；
- completionRate=100；
- 任一检查项 ABNORMAL -> Task.resultStatus=ABNORMAL；
- 否则 NORMAL。

完成巡检需要二次确认。

### UC-IN-06 AI 辅助诊断

INSPECTOR 可以：

- 从本人巡检异常发起 AI；
- 查看 AI 结果；
- 查看五节点 trace。

INSPECTOR 不可以：

- ai:confirm；
- 根据 AI 草案创建工单；
- 进入维修管理完成缺陷/工单操作。

---

## 7. MAINTAINER 用例

### UC-MA-01 查看缺陷

MAINTAINER 可以查看全部缺陷，用于识别未进入工单的维修问题。

缺陷详情显示：

- 设备；
- 来源异常/告警；
- severity；
- 当前 defect status；
- AI 诊断；
- 关联工单。

### UC-MA-02 确认缺陷

第一版缺陷不提供任意 status 下拉框。

用户直接动作仅保留：

OPEN -> CONFIRMED：“确认缺陷”

以及：

RESOLVED -> CLOSED：“归档缺陷”

CONFIRMED -> PROCESSING 由创建关联工单时自动推进。

PROCESSING -> RESOLVED 由工单验收通过自动推进。

第一版不实现复杂“误报关闭”分支。

### UC-MA-03 AI 诊断与确认

MAINTAINER 拥有：

- ai:view；
- ai:diagnosis；
- ai:confirm。

流程与 ADMIN 相同。

维修人员可以确认或拒绝 AI 建议，但 AI 仍只提供辅助决策。

### UC-MA-04 创建工单

MAINTAINER 可以从缺陷或确认后的 AI 诊断人工创建维修工单。

创建后：

PENDING

MAINTAINER 不能在创建动作中直接自分派。

### UC-MA-05 我的维修工单

默认入口：`/maintenance/work-orders`。

默认重点显示：

- 分配给当前用户的 ASSIGNED；
- PROCESSING；
- WAITING_ACCEPTANCE；
- 验收驳回后重新进入 PROCESSING 的工单。

创建者可在创建成功后查看自己刚创建的 PENDING 工单，但 PENDING 的正式调度仍由 ADMIN / SUPER_ADMIN 完成。

### UC-MA-06 开始维修

前置：

- WorkOrder.status = ASSIGNED；
- 当前用户 = assigneeUserId；
- maintenance:workorder:process。

操作：

ASSIGNED -> PROCESSING

其他 MAINTAINER 即使知道工单 ID 也必须被后端拒绝。

### UC-MA-07 提交维修结果

前置：

- WorkOrder.status = PROCESSING；
- 当前用户 = assigneeUserId。

填写：

- faultCause；
- solution；
- partsUsed；
- downtimeMinutes；
- maintenanceCost；
- result = SUCCESS / PARTIAL / FAILED；
- comment。

提交：

PROCESSING -> WAITING_ACCEPTANCE

提交维修结果必须二次确认。

### UC-MA-08 等待验收与返修

WAITING_ACCEPTANCE：

- MAINTAINER 只读查看；
- 不显示验收按钮；
- 显示“等待业务管理员验收”。

如果 ADMIN REJECTED：

WAITING_ACCEPTANCE -> PROCESSING

页面突出：

- 驳回原因；
- 驳回时间；
- 历史维修记录；
- “继续维修”。

### UC-MA-09 禁止自验收

MAINTAINER 没有 maintenance:workorder:accept。

前端不显示验收操作。

直接调用 acceptance API 必须返回 403。

---

## 8. 主业务流程

第一版唯一正式业务主链：

ADMIN
设备建档
-> 巡检模板
-> 巡检计划
-> 选择 INSPECTOR
-> 生成 PENDING 巡检任务

INSPECTOR
PENDING
-> 开始巡检
-> IN_PROGRESS
-> 填检查项
-> 上报 Abnormal
-> 完成巡检
-> COMPLETED

IIOP + RocketMQ
Abnormal
-> iiop_inspection_abnormal
-> Maintenance 消费
-> Defect OPEN

MAINTAINER / ADMIN
确认缺陷
-> CONFIRMED
-> 发起 AI

DeepSeek + LangGraph4j
LOAD_CONTEXT
-> ANALYZE_WITH_DEEPSEEK
-> RISK_CHECK
-> GENERATE_ADVICE
-> PREPARE_WORK_ORDER_DRAFT
-> SUCCEEDED / PENDING_CONFIRMATION

MAINTAINER / ADMIN
人工确认
-> CONFIRMED
-> 检查 WorkOrderDraft
-> 人工创建真实工单
-> WorkOrder PENDING
-> Defect PROCESSING

ADMIN
选择 MAINTAINER
-> PENDING -> ASSIGNED

MAINTAINER
ASSIGNED
-> 开始维修
-> PROCESSING
-> 提交维修结果
-> WAITING_ACCEPTANCE

ADMIN / SUPER_ADMIN
验收

PASSED：
WorkOrder -> COMPLETED
Defect -> RESOLVED

REJECTED：
WorkOrder -> PROCESSING
-> MAINTAINER 返修
-> WAITING_ACCEPTANCE
-> 再次验收

---

## 9. 状态机冻结

### 9.1 Inspection Task

主流程：

PENDING -> IN_PROGRESS -> COMPLETED

CANCELLED 数据库值保留，但第一版没有真实取消 API时不提供取消按钮。

### 9.2 Task Item

PENDING -> NORMAL / ABNORMAL

已完成任务只读。

### 9.3 Abnormal

第一版 Abnormal 是事实记录，不承担维修闭环。

创建时：

status = OPEN

前端以“是否已形成 Defect”作为业务进展提示，不提供任意异常状态编辑。

### 9.4 Defect

主流程：

OPEN
-> CONFIRMED
-> PROCESSING
-> RESOLVED
-> CLOSED

用户动作：

- OPEN -> CONFIRMED；
- RESOLVED -> CLOSED。

自动动作：

- 创建关联 WorkOrder -> PROCESSING；
- WorkOrder 验收 PASSED -> RESOLVED。

禁止任意枚举下拉直接跳状态。

### 9.5 WorkOrder

第一版主流程：

PENDING
-> ASSIGNED
-> PROCESSING
-> WAITING_ACCEPTANCE
-> COMPLETED

驳回：

WAITING_ACCEPTANCE -> PROCESSING

DRAFT / CANCELLED 数据库枚举保留，但第一版没有真实业务入口时不在 UI 暴露。

### 9.6 AI Diagnosis

运行状态：

PENDING -> RUNNING -> SUCCEEDED

失败：

RUNNING -> FAILED

人工确认：

PENDING -> CONFIRMED

或：

PENDING -> REJECTED

只有 SUCCEEDED + CONFIRMED 的 AI 草案可以作为“根据 AI 创建工单”的入口。

---

## 10. 人机交互基线

### 10.1 页面必须回答四个问题

每个核心页面必须让用户马上知道：

1. 我正在看什么对象；
2. 它现在是什么状态；
3. 我现在可以做什么；
4. 完成后下一步交给谁。

如果页面只展示字段和 JSON，不满足 Gate 2。

### 10.2 状态驱动操作区

按钮必须同时依据：

- permission；
- role；
- assignee；
- 当前状态。

例如 WorkOrder：

| 状态 | ADMIN / SUPER_ADMIN | 被分派 MAINTAINER | 其他 MAINTAINER |
|---|---|---|---|
| PENDING | 分派 | 等待分派 | 只读 |
| ASSIGNED | 查看 | 开始维修 | 只读 |
| PROCESSING | 查看进度 | 提交维修结果 | 只读 |
| WAITING_ACCEPTANCE | 验收通过/驳回 | 等待验收 | 只读 |
| COMPLETED | 只读 | 只读 | 只读 |

### 10.3 业务选择器

任何系统可选择的关系不得要求用户手输 ID。

必须使用真实 API 选项：

- categoryId -> 分类选择；
- deviceId -> 设备编码 + 名称；
- templateId -> 模板名称；
- assigneeUserId -> 岗位用户选择；
- roleIds -> 角色多选；
- defectId -> 缺陷编码 + 标题；
- AI / WorkOrder 关联 -> 业务编码 + 标题。

### 10.4 用户选择必须带岗位过滤

巡检计划 assignee：

ENABLED + INSPECTOR

工单 assignee：

ENABLED + MAINTAINER

选项显示：

真实姓名（username）

没有 realName 时退回 username。

### 10.5 关系展示

主要显示业务名称，ID 只作为次级技术信息。

例如：

设备：
DEV2026... 一号数控加工中心
[查看设备]

来源异常：
ABN2026... 主轴温度过高
[查看异常]

维修人员：
张维修（maintainer01）

AI 诊断：
AI2026...
[查看诊断]

### 10.6 Loading / Empty / Error

所有异步页面形成：

loading -> success / empty / error

禁止永久 loading。

空状态必须结合岗位：

- INSPECTOR：“当前没有分配给你的巡检任务”；
- MAINTAINER：“当前没有分配给你的维修工单”；
- ADMIN：“当前没有待验收工单”；
- AI：“该对象尚未发起 AI 诊断”。

可执行下一步时给出真实入口。

### 10.7 写操作反馈

标准流程：

点击
-> loading + disabled
-> 必要时确认
-> 调真实 API
-> 成功提示
-> 刷新真实状态
-> 用户看到下一状态

禁止静默失败。

### 10.8 二次确认

至少：

- 生成巡检任务；
- 完成巡检；
- AI confirm / reject；
- 创建正式工单；
- 工单分派；
- 提交维修结果；
- 工单验收；
- 用户禁用/锁定；
- 用户角色变更；
- 删除操作。

### 10.9 未保存离开保护

至少覆盖：

- 巡检执行；
- 工单创建；
- 维修结果；
- AI 确认备注；
- 模板编辑。

表单 dirty 且未保存时，路由离开、浏览器后退或关闭编辑对话框应提示。

第一版不要求自动保存。

### 10.10 并发状态变化

如果写操作返回状态冲突，例如 HTTP 409：

提示：

“当前数据已被其他操作更新，已为你刷新最新状态。”

然后重新加载对象。

适用于：

- 开始巡检；
- 完成巡检；
- AI 确认；
- 工单分派；
- 开始维修；
- 提交维修；
- 验收。

### 10.11 HTTP 语义

- 401：清空本地身份并回登录页；
- 403：显示“无权限执行此操作”，页面访问进入 /403，不清空登录；
- 409：显示业务状态冲突并刷新；
- 429：显示“操作过于频繁，请稍后再试”，不改 Sentinel；
- 5xx：显示失败信息和重试入口，保留 traceId/requestId 时可用于诊断。

### 10.12 AI 长耗时交互

AI 创建是同步调用。

提交期间：

- 明确显示 AI 正在诊断；
- 禁止重复点击；
- 网络超时不自动再次 POST；
- 提示用户刷新诊断列表确认是否已生成；
- FAILED 时允许人工流程继续。

### 10.13 Dashboard

Dashboard 必须回答“我下一步做什么”。

SUPER_ADMIN：

- 系统治理入口；
- 全局风险概况；
- 业务总体概况。

ADMIN：

- 高风险设备；
- 待确认缺陷；
- 待分派工单；
- 待验收工单。

INSPECTOR：

- 我的 PENDING 巡检；
- 我的 IN_PROGRESS 巡检；
- 近期本人异常。

MAINTAINER：

- 我的 ASSIGNED 工单；
- 我的 PROCESSING 工单；
- 验收驳回返修；
- 高风险缺陷。

S4-A 可用真实列表 API 组合；S4-B 再用 ECharts 完成视觉化。

---

## 11. PC 菜单基线

### SUPER_ADMIN

- Dashboard
- 设备
- 巡检模板
- 巡检计划
- 巡检任务
- 巡检异常
- 缺陷
- 工单
- AI
- 用户
- 角色/权限查看
- 通知

### ADMIN

与业务管理相关菜单同 SUPER_ADMIN，同时：

- 可管理普通用户；
- 角色/权限只读；
- 不显示结构性角色/权限 CRUD。

### INSPECTOR

- 我的巡检
- 设备
- 巡检异常
- AI
- 通知

### MAINTAINER

- 我的工单
- 缺陷
- 设备
- AI
- 通知

菜单最终仍由 permission 过滤。

---

## 12. HarmonyOS 角色映射

移动端第一版主要服务 INSPECTOR 和 MAINTAINER。

### INSPECTOR

登录
-> 我的巡检
-> 任务详情
-> 填写检查项
-> 上报异常
-> 完成巡检
-> 查看 AI

### MAINTAINER

登录
-> 我的工单
-> 工单详情
-> 开始维修
-> 填维修结果
-> 提交 WAITING_ACCEPTANCE
-> 查看 AI

HarmonyOS 不提供：

- SUPER_ADMIN 系统治理；
- ADMIN 复杂管理台；
- 角色/权限管理；
- 工单验收给 MAINTAINER；
- Three.js；
- Vue Flow；
- WebSocket。

---

## 13. Gate 2 前 API 反向审查

以下是以当前 d387e463de6b598088ffd31a3c548c1284e552fd 代码为基线的差距。

### 13.1 已经具备，可直接复用

- auth login/logout/me；
- users CRUD、用户角色写入；
- roles / permissions 查询；
- SUPER_ADMIN 角色与状态后端保护；
- device categories / devices / metrics / SOP；
- inspection template / item / plan；
- task start / item submit / complete；
- abnormal create；
- RocketMQ abnormal -> defect；
- defect detail；
- work-order create / assign / start / repair / acceptance；
- AI create / detail / workflow / confirm / reject；
- notification REST；
- Gateway Sentinel 登录限流。

### 13.2 Gate 2 必须补的最小后端能力

1. Auth 用户查询：
   - users list 支持 roleCode / status / keyword 过滤，用于 INSPECTOR、MAINTAINER 选择器；
   - 提供目标用户已有角色读取能力，避免角色分配空选覆盖；
   - internal auth 提供用户是否 ENABLED 且拥有指定 role 的最小校验能力。

2. Auth Snapshot：
   - 只有 ENABLED role 可以贡献 permission；
   - 无角色用户必须是合法“已加载空角色”状态。

3. Inspection 数据范围：
   - task list 支持本人范围和状态/结果/device 过滤；
   - INSPECTOR 默认后端只返回本人任务；
   - abnormal list 支持 taskId / deviceId / severity 等必要关联筛选；
   - start / submit item / create abnormal / complete 校验当前 assignee。

4. Inspection 计划：
   - 创建/更新 plan 时校验 assignee 是 ENABLED INSPECTOR。

5. Maintenance 查询：
   - defects list 支持 sourceType / sourceId / deviceId / severity / status；
   - work-orders list 支持 status / priority / deviceId / defectId / aiDiagnosisId / assignee 范围；
   - MAINTAINER 默认本人 work-orders。

6. Maintenance 状态职责：
   - assign 仅 ADMIN / SUPER_ADMIN；
   - assignee 必须 ENABLED MAINTAINER；
   - start / repair-result 只能当前 assignee；
   - acceptance 继续仅 ADMIN / SUPER_ADMIN；
   - defect 不再接受任意 status 跳转，按本文件状态机收紧。

7. Defect 与 AI：
   - AI list 至少支持 triggerType / triggerId / deviceId / diagnosisStatus / riskLevel / confirmationStatus 查询；
   - 对 INSPECTION_ABNORMAL / ALARM 缺陷按 sourceType/sourceId 定位 AI；
   - MANUAL defect 发起 MANUAL AI 后，需要一个最小、明确的 defect.aiDiagnosisId 绑定路径，禁止前端全量扫描猜关联；
   - 不新增数据库表或微服务。

8. WorkOrder 与 Defect：
   - 从 defect 创建工单时推进 defect CONFIRMED -> PROCESSING；
   - acceptance PASSED 保持 PROCESSING -> RESOLVED；
   - REJECTED 不把 defect 标记为 RESOLVED。

### 13.3 Gate 2 必须补的前端能力

- 专用用户管理和角色分配交互；
- 用户已有角色回显；
- 角色/权限矩阵只读展示；
- 业务选择器替代手填 ID；
- Device / Task / Abnormal / Defect / WorkOrder / AI 专用详情；
- 状态驱动按钮；
- 关联对象导航；
- 巡检进度；
- AI 确认与失败退路；
- WorkOrder 日志/维修/验收结构化展示；
- loading / empty / error / retry；
- dirty 离开保护；
- 409 刷新；
- 429 友好提示；
- 角色 Dashboard 待办。

### 13.4 明确禁止的 Gate 2 实现

- 新增微服务；
- 新增数据库表；
- 为了页面方便跨库查询；
- 前端全量分页扫描寻找关联；
- 手工输入业务 ID；
- 为每个角色复制一套页面；
- 角色名直接绕过 permission；
- AI 自动创建真实工单；
- MAINTAINER 自验收；
- INSPECTOR 执行别人任务；
- MAINTAINER 处理别人已分派工单；
- 为使用闲置 permission 而虚构业务按钮；
- 用静态假数据填 Dashboard。

---

## 14. Gate 2 开发顺序

Gate 2 固定按以下顺序完成：

1. 修 Auth Snapshot / 无角色边界；
2. 补用户角色读取与岗位用户查询；
3. 补 inspection 本人范围与 assignee 校验；
4. 补 maintenance 本人工单、分派职责与 assignee 校验；
5. 收紧 Defect 状态机；
6. 补最小关联查询与 Defect-AI 关系；
7. 再做 PC 业务化表单和专用详情；
8. 再做角色 Dashboard；
9. 完成真实业务主链；
10. build、Secret、push；
11. ChatGPT 独立审查。

不得先把页面“画完”后再补业务约束。

---

## 15. Gate 2 验收用例

Gate 2 至少逐条真实验证：

### ADMIN

- 创建/编辑设备使用业务控件；
- 创建模板与计划；
- 计划只能选择 ENABLED INSPECTOR；
- 生成任务；
- 查看异常 -> 缺陷；
- 发起 AI；
- AI confirm/reject；
- CONFIRMED AI 草案人工创建工单；
- 工单只能分派 ENABLED MAINTAINER；
- WAITING_ACCEPTANCE 验收通过/驳回；
- 用户角色分配保留已有角色，不发生空选覆盖。

### INSPECTOR

- 默认只看到自己的任务；
- 不能执行别人任务，即使直接调用 API；
- 按类型填写检查项；
- 必填未完成不能完成任务；
- 上报异常；
- 查看/发起 AI；
- 不能 AI confirm；
- 不能进入维修操作。

### MAINTAINER

- 默认看到自己的维修工单；
- 可以查看缺陷并发起/确认 AI；
- 可以创建 PENDING 工单；
- 不能自行分派；
- 只能开始和提交自己的 ASSIGNED/PROCESSING 工单；
- WAITING_ACCEPTANCE 只读；
- acceptance API 仍 403；
- 验收驳回后看到原因并继续维修。

### 多角色/无角色

- INSPECTOR + MAINTAINER 权限并集，默认 MAINTAINER 工作区；
- 无角色用户进入“尚未分配岗位”，不循环 /me；
- DISABLED / LOCKED 用户不能登录。

### 异常与恢复

- 409 后刷新最新状态；
- 429 有中文提示；
- AI FAILED 后可以回缺陷继续人工建工单；
- AI REJECTED 后不能一键使用该草案建工单；
- 空状态、网络错误、重试入口正常。

---

## 16. 最终冻结结论

第一版业务 Actor 固定为四种：

SUPER_ADMIN
ADMIN
INSPECTOR
MAINTAINER

正式主链固定为：

设备
-> 巡检模板/计划
-> INSPECTOR 执行巡检
-> Abnormal
-> RocketMQ
-> Defect
-> AI 辅助诊断
-> 人工确认
-> 人工创建 WorkOrder
-> ADMIN 分派
-> MAINTAINER 维修
-> ADMIN / SUPER_ADMIN 验收
-> 生命周期历史

核心职责分离：

- INSPECTOR 负责巡检；
- MAINTAINER 负责维修；
- ADMIN 负责业务配置、调度和验收；
- SUPER_ADMIN 负责系统治理和兜底；
- AI 只辅助，不替代人工决策；
- permissions 决定授权；
- roles 决定岗位、数据范围和工作视角；
- assignee 决定现场人员可以实际操作哪一条任务/工单。

未经明确确认，后续 Codex 不得改变上述基线。
