# IIOP 客户端实现规范

> 角色、数据范围、角色用例、主业务交接、异常路径和状态驱动交互以 `06-role-usecases.md` 为冻结基线。若本文件旧页面描述与其冲突，以 `06-role-usecases.md` 为准；数据库字段/枚举仍以 `01-database.md` 为准。

## 1. 总原则

PC 与 HarmonyOS 只实现课程项目主业务、真实业务联动和指定技术展示。

架构保持简单，界面完成度不能以“最简”为理由降低。PC 端应达到答辩演示可用的视觉和交互质量。

客户端统一通过 Gateway 访问：

http://127.0.0.1:8080

所有业务页面优先使用真实后端 API 和数据库数据。允许数据库存在演示种子数据，但禁止用大段前端静态假数据代替真实业务接口。

不增加新的微服务、表、中间件或前端大型设计系统。

## 2. PC 技术栈

- Vue 3
- Vite
- TypeScript
- Vue Router
- Axios
- Pinia
- pinia-plugin-persistedstate
- Element Plus
- ECharts
- Three.js
- @vue-flow/core

依赖第一次可运行后锁定版本，不随意升级。

样式实现保持轻量：

- CSS/SCSS 变量
- Element Plus 主题覆盖
- 少量共享布局组件
- 页面局部样式

不引入大型 Design System。

## 3. PC 路由与页面边界

核心业务必须使用真实 Vue Router 路由和独立 URL。

禁止把全部业务功能塞进一个 Dashboard。
禁止通过一个页面内大量 activePanel / v-if 模拟路由。

Dashboard 只负责总览和导航入口。

固定路由基线：

- /login
- /dashboard
- /devices
- /devices/:id
- /devices/scene
- /inspection/templates
- /inspection/templates/:id
- /inspection/plans
- /inspection/tasks
- /inspection/tasks/:id
- /inspection/abnormals
- /inspection/abnormals/:id
- /maintenance/defects
- /maintenance/defects/:id
- /maintenance/work-orders
- /maintenance/work-orders/:id
- /ai/diagnoses
- /ai/diagnoses/:id
- /system/users
- /system/roles
- /notifications
- /403

允许为表单增加必要的 create/edit 子路由或弹窗，但不得改变上述主路由结构。

必须支持：

- 左侧菜单导航
- 面包屑
- 列表进入详情
- 详情进入关联对象
- 浏览器前进/后退
- 刷新详情 URL 后可恢复页面
- 未登录访问业务路由时跳转 /login
- 根据 RBAC 权限控制菜单、页面入口和关键操作

## 4. PC 业务导航主链

前端必须体现真实业务对象之间的关联关系。

答辩主链至少可以通过页面自然跳转：

Dashboard
→ 设备详情
→ 巡检任务详情
→ 巡检异常详情
→ 缺陷详情
→ AI 诊断详情
→ 人工确认
→ 人工创建工单
→ 工单详情
→ 维修处理
→ 验收

详情页需要显示后端已有的关联 ID，并提供进入相关对象的明确入口。

不得为了跳转额外复制业务数据到前端。

角色交接基线：

- INSPECTOR：执行巡检并上报异常。
- 系统：通过 RocketMQ 将异常转成 maintenance 缺陷。
- ADMIN / MAINTAINER：查看缺陷、发起或查看 AI 诊断，并在有 ai:confirm 权限时完成人工确认。
- AI：只生成诊断和工单草案，不直接创建工单。
- ADMIN / MAINTAINER：在诊断 CONFIRMED 后，使用 maintenance:workorder:create 人工审核草案并提交真实工单。
- MAINTAINER：执行维修处理。
- ADMIN / SUPER_ADMIN：执行工单验收。

如果现有 API 无法按真实关联关系查询目标对象，Gate 2 允许在数据所属服务中增加最小只读查询参数或查询端点；禁止新增表、微服务或通过前端扫描分页数据伪造关联。

## 5. 登录与整体布局

### 登录页

登录页需要具有工业科技项目视觉，不使用只有白底表单的默认样式。

至少包括：

- IIOP 项目名称或标识
- username
- password
- 登录按钮
- 登录中状态
- 登录失败提示

### 后台主布局

设备、巡检、维修、AI、系统、通知使用统一后台框架：

- 左侧 Sidebar
- 顶部 Header
- Breadcrumb
- 内容区
- 通知入口
- 当前用户和退出入口

布局、间距、按钮层级和状态颜色保持统一。

## 5.1 角色工作视角与默认落地页

PC 必须保存登录接口和 /api/auth/me 返回的 roles 与 permissions。

- roles 用于工作视角、默认落地页、Dashboard 重点和菜单优先级。
- permissions 用于页面、按钮和 API 的最终授权。
- 禁止使用角色名绕过 permission 检查。

SUPER_ADMIN：系统管理员，默认 /dashboard，可进行全部业务与系统治理。

ADMIN：业务管理员，默认 /dashboard，负责设备、巡检、维修、AI 等业务管理，可维护日常用户并分配已有的 ADMIN / INSPECTOR / MAINTAINER 角色，可查看角色与权限，但不能授予或移除 SUPER_ADMIN，也不能修改平台权限模型。

INSPECTOR：巡检人员，默认 /inspection/tasks，重点是设备查看、巡检执行、异常上报和 AI 辅助诊断。系统管理、维修管理、巡检模板/计划管理入口不显示。

MAINTAINER：维修人员，默认 /maintenance/work-orders，重点是设备、告警、缺陷、工单处理和 AI 辅助诊断。维修人员不执行工单验收，验收由 ADMIN 或 SUPER_ADMIN 完成。

无权限处理：

- 未登录跳 /login。
- 已登录但无页面权限跳 /403。
- 禁止把无权限用户循环重定向到 /dashboard。
- /403 提供返回当前角色默认首页的入口。

S4-A 必须用四类本地测试身份分别验证 SUPER_ADMIN、ADMIN、INSPECTOR、MAINTAINER。四类身份都要验证默认落地页和可见菜单。SUPER_ADMIN 验证至少一个系统治理操作和一个业务操作；ADMIN、INSPECTOR、MAINTAINER 各验证至少一个允许操作、一个禁止操作或隐藏入口，并验证直接输入无权限 URL 时进入 /403 或得到明确无权限反馈。

测试账号和密码只存在本机开发环境，不进入 Git。

## 6. Dashboard

Dashboard 定位为工业设备智能巡检运维总览。

建议使用深色工业监控视觉。

展示真实业务统计：

- 设备总数
- 在线/离线/故障等状态
- 巡检任务统计
- 异常统计
- 缺陷统计
- 工单统计
- 风险分布

使用 2 到 4 个 ECharts 图表即可。

图表要求：

- 统一主题
- tooltip 可读
- legend 清晰
- 坐标轴和字体正常
- 状态颜色语义统一
- 禁止随机彩虹配色

Dashboard 只做总览和入口，不承载设备、巡检、维修的完整 CRUD。

## 7. 设备模块

### /devices

- 设备列表
- 筛选
- 分页
- 新增
- 编辑
- 进入设备详情

### /devices/:id

至少展示：

- 基础档案
- 分类
- 状态
- 风险等级
- 指标
- SOP
- 最近巡检信息
- 最近维修相关信息
- 可进入关联巡检任务、异常、缺陷、工单、AI 诊断

### /devices/scene

Three.js 使用独立业务页面。

必须真实使用：

- Scene
- Camera
- Light
- Grid
- OrbitControls
- 设备位置
- 状态/风险颜色
- 点击设备后显示业务摘要

如果设备没有 glTF 模型，允许使用视觉完整的 Box fallback。

Three.js 页面需要使用真实设备数据，不做孤立 Demo。

不做复杂数字孪生、动画系统或模型管理平台。

## 8. 巡检模块

### /inspection/templates

- 模板列表
- 新增/编辑
- 进入模板详情

### /inspection/templates/:id

- 模板基本信息
- 检查项
- Vue Flow 流程图
- 保存/回显 flow_definition

Vue Flow 支持的业务节点：

- START
- CHECK_ITEM
- CONDITION
- REPORT_ABNORMAL
- END

需要对节点、连线、选中状态进行基础视觉定制，禁止直接保留默认 Demo 外观。

### /inspection/plans

- 计划列表
- 新增/编辑
- CRON 计划字段
- 人工生成任务入口

### /inspection/tasks

- 任务列表
- 状态筛选
- 进入任务详情

### /inspection/tasks/:id

- 任务信息
- 检查项快照
- 开始执行
- NUMBER / BOOLEAN / TEXT 填写
- 完成任务
- 查看产生的异常

### /inspection/abnormals

- 异常列表
- 风险/状态筛选
- 进入异常详情

### /inspection/abnormals/:id

- 异常详情
- 设备关联
- 巡检任务关联
- 缺陷关联
- AI 诊断入口或关联结果

## 9. 维修模块

### /maintenance/defects

- 缺陷列表
- 来源
- 风险
- 状态
- 进入详情

### /maintenance/defects/:id

- 缺陷详情
- 来源异常或告警
- 设备
- AI 诊断
- 相关工单
- 创建工单入口

### /maintenance/work-orders

- 工单列表
- 状态筛选
- 负责人
- 进入详情

### /maintenance/work-orders/:id

至少支持：

- 工单详情
- 缺陷关联
- 设备关联
- AI 诊断关联
- ASSIGNED / PROCESSING 等状态展示
- 开始维修
- 填写维修记录
- 提交验收
- 查看验收记录

工单生命周期应与后端现有状态保持一致，不在前端重新定义状态机。

## 10. AI 模块

### /ai/diagnoses

- 诊断列表
- 状态
- 风险
- 触发类型
- 发起诊断
- 进入详情

### /ai/diagnoses/:id

展示真实结构化结果：

- 风险等级
- 异常摘要
- possibleCauses
- investigationSteps
- maintenanceAdvice
- safetyNotice
- workOrderDraft
- humanConfirmationRequired
- 5 节点 workflow trace
- confirm
- reject

5 个固定节点：

1. LOAD_CONTEXT
2. ANALYZE_WITH_DEEPSEEK
3. RISK_CHECK
4. GENERATE_ADVICE
5. PREPARE_WORK_ORDER_DRAFT

AI 页面不做聊天、Chat Memory、RAG、Tool Calling 或 Agent 操作界面。

AI 只能提供诊断和工单草案建议，前端不得把 AI 结果表现成已自动创建工单。

## 11. 系统模块

### /system/users

- 用户列表
- 新增/编辑
- 启用/禁用
- 角色分配
- 角色分配调用现有用户角色 API
- ADMIN 只能分配 ADMIN / INSPECTOR / MAINTAINER
- ADMIN 不能禁用或锁定当前具有 SUPER_ADMIN 的账号
- SUPER_ADMIN 的授予、移除，以及 SUPER_ADMIN 账号状态变更必须由后端强制要求 system:role:permission，不能只依赖前端隐藏
- 用户状态修改调用后端专用 status API，不能把 status 塞进普通用户编辑 DTO

### /system/roles

- 角色列表
- 角色信息
- 权限查看
- SUPER_ADMIN 可进行轻量权限编辑
- ADMIN 只能查看角色/权限并给用户分配已有角色，不能修改权限模型

不做复杂权限设计器。

菜单和页面入口根据 permissions 做 RBAC 控制；roles 只用于岗位工作视角和默认落地。

## 12. 通知与 WebSocket

### /notifications

- 通知列表
- 已读/未读状态
- 未读数量

PC 使用浏览器原生 WebSocket：

ws://127.0.0.1:8080/ws/notifications?token=...

只处理通知 JSON。

业务要求：

- 顶部通知入口
- 未读数量
- 收到真实 WS 消息后自然提示
- 刷新通知列表
- 简单定时重连

WebSocket 是实时提醒，sys_notification 仍是通知事实来源。

不使用 STOMP、SockJS、Redis Pub/Sub。

## 13. PC 状态管理

Pinia 只保存必要全局状态：

- token
- currentUser
- roles
- permissions
- notification unread count

业务列表、详情和表单数据尽量由页面按 API 生命周期管理。

不要把所有业务数据塞进 Store。

## 14. 视觉质量

“课程项目简化”只约束系统复杂度，不等于页面简陋。

视觉目标：

- 登录页具有工业科技感
- Dashboard 深色工业监控风格
- 设备、巡检、维修、AI、系统页采用统一的浅色后台风格
- Header、Sidebar、内容区、表格、筛选、表单、详情保持一致
- 统一主色、状态色、圆角、阴影、字体层级、间距、图标和按钮层级

关键页面必须有：

- loading
- empty
- error
- disabled
- success feedback

重点适配：

- 1920x1080
- 1440x900
- 1366x768

在这些尺寸下不得出现明显布局断裂、主内容被遮挡或关键操作不可见。

## 14.1 界面语言与字段显示

PC 端面向用户的界面文本默认使用中文，答辩演示页面不得大量直接暴露后端英文字段名、枚举值或组件默认英文文案。

必须中文化：

- Sidebar 菜单
- Breadcrumb
- 页面标题
- 表格列名
- 表单标签
- 筛选项
- 按钮
- 对话框
- 空状态
- loading / error / success 提示
- 状态与风险等级的主要显示文本

后端字段名只用于代码和接口映射，例如 `deviceName`、`riskLevel`、`possibleCauses`，页面应显示“设备名称”“风险等级”“可能原因”等中文业务名称。

后端枚举值保持原始值传输，不修改 API 语义，但前端必须建立集中或可复用的显示映射。例如：

- ONLINE → 在线
- OFFLINE → 离线
- FAULT → 故障
- MAINTENANCE → 维护中
- LOW → 低
- MEDIUM → 中
- HIGH → 高
- CRITICAL → 严重
- PENDING → 待处理
- RUNNING / IN_PROGRESS / PROCESSING → 进行中
- COMPLETED / SUCCEEDED → 已完成 / 成功
- FAILED → 失败
- CONFIRMED → 已确认
- REJECTED → 已拒绝

实际中文文案需结合具体业务上下文，不能机械地对所有不同状态复用错误翻译。

允许保留常用技术缩写与标识：

- IIOP
- AI
- SOP
- ID
- CRON
- API
- WebSocket
- Three.js
- Vue Flow

AI 五节点页面应以中文节点名称作为主要展示，同时可以保留固定 nodeCode 作为次级技术信息，便于答辩说明 LangGraph4j 真实节点。

S4-A Gate 1 及后续运行验收时，如果核心页面仍大量显示原始英文字段名、默认英文按钮、英文枚举值或未翻译组件文案，不判定为可验收完成。

## 14.2 人机交互与业务状态驱动

S4-A 的页面不能只做到“字段展示 + 表格 + 详情”。核心业务页必须让用户清楚知道当前对象处于什么状态、现在可以做什么、下一步去哪里、操作成功或失败后发生了什么。

交互设计以“任务驱动”和“状态驱动”为原则。

### 设备详情

设备详情除基础档案外，应提供与当前设备真实关联的业务入口，例如：

- 查看巡检任务
- 查看异常
- 查看缺陷
- 查看工单
- 发起或查看 AI 诊断

只有真实关联存在时显示对应入口，不使用假 ID。

### 巡检任务详情

操作区必须随任务状态变化。

例如：

- PENDING：显示“开始巡检”
- IN_PROGRESS：显示检查项输入与“完成巡检”
- COMPLETED：输入项只读，显示结果与异常入口
- CANCELLED：显示已取消状态，执行操作禁用

NUMBER / BOOLEAN / TEXT 必须使用适合的数据输入控件，不能统一退化为普通文本框。

### 巡检异常详情

至少清楚展示：

- 异常来源
- 设备
- 巡检任务
- 严重程度
- 缺陷关联
- AI 诊断关联

提供真实业务入口，例如“查看设备”“查看巡检任务”“查看缺陷”“查看 AI 诊断”。

### 缺陷详情

根据已有数据和权限提供：

- 查看来源异常或告警
- 查看设备
- 查看 AI 诊断
- 查看已有工单
- 创建工单

已有工单时避免继续突出重复创建入口。

### 工单详情

操作区必须依据后端真实工单状态变化。

例如：

- ASSIGNED：可以开始维修
- PROCESSING：可以填写或提交维修处理
- WAITING_ACCEPTANCE：进入验收操作
- COMPLETED：只读查看完整维修与验收结果

实际按钮必须以后端现有 API 和状态机为准，前端不新增状态。

### AI 诊断详情

需要形成完整操作闭环：

- 展示风险、原因、排查步骤、维修建议、安全提示
- 展示五节点 trace
- PENDING confirmation 时显示确认/拒绝操作
- CONFIRMED / REJECTED 后显示最终状态，不能继续重复提交
- CONFIRMED 且当前用户拥有 maintenance:workorder:create 时，可以显示“根据诊断草案创建工单”
- 创建工单必须由用户检查并显式提交，携带真实 aiDiagnosisId，并在已有真实关联时携带 defectId/deviceId
- AI confirm 本身绝不直接创建 maintenance 数据
- confirm/reject 使用确认对话框或明确操作区域
- 提交时 loading/disabled
- 成功后刷新真实状态
- 失败时显示明确错误

### 操作反馈

关键写操作至少满足：

点击操作
→ 按钮进入 loading / disabled
→ 必要时二次确认
→ 调用真实 API
→ 成功提示
→ 局部刷新数据或状态
→ 用户能立即看到状态变化

失败时必须有可理解的错误提示，不能静默失败。

### 空状态和下一步

空数据页不能只显示空白表格。

应根据页面给出合理提示，例如：

- 暂无巡检任务
- 暂无关联异常
- 暂无维修工单
- 暂无 AI 诊断

如果当前用户有权限且业务允许，可以提供“新建”“发起诊断”“创建工单”等下一步入口。

### Gate 2 验收重点

S4-A Gate 2 重点检查：

- 核心页面是否按业务状态变化操作区
- 用户是否能从当前对象自然进入下一业务对象
- 写操作是否有 loading / disabled / confirm / success / error
- 页面是否使用用户能理解的中文业务文案
- 是否仍存在大量只有字段展示、缺少操作闭环的“数据浏览器式页面”

如果核心业务页仍主要是通用表格、Descriptions 和原始字段展示，即使 build 通过，也不能判定 Gate 2 PASS。

## 14.3 业务化交互控件与可用性

Gate 2 必须把核心页面从“字段填写器”提升为业务操作界面。

### 表单控件

禁止要求用户手工输入可以从系统选择的业务 ID。

例如：

- categoryId 使用设备分类选择器，显示分类名称，提交真实 ID。
- templateId 使用巡检模板选择器。
- deviceId 使用设备选择器，显示设备编码 + 名称。
- assigneeUserId 使用用户/负责人选择器。
- roleIds 使用角色多选。
- permissionIds 使用权限分组或树形多选。

状态、风险、周期、工单类型、结果状态等有限枚举必须使用 Select、Radio、Tag 等受控组件，不能退化为任意文本输入。

### 列表筛选

筛选项必须提供真实合法选项并中文显示，不能只有空的“状态筛选”控件。

至少覆盖：

- 设备：状态、风险等级。
- 巡检任务：任务状态、结果状态。
- 巡检异常：严重程度、状态。
- 缺陷：严重程度、状态。
- 工单：状态、优先级。
- AI：诊断状态、风险等级、确认状态。

### 详情页

核心详情页不得直接遍历对象字段名作为页面标签，也不得用 pre / JSON.stringify 代替主要业务展示。

设备、异常、缺陷、工单、AI、用户、角色等核心对象应按业务分组展示：

- 基本信息
- 当前状态
- 关联对象
- 当前可执行操作
- 历史/记录

### 巡检执行

巡检任务详情应显示完成进度。

如果仍有 requiredFlag=1 且 resultStatus=PENDING 的检查项：

- 明确提示剩余必填项数量；
- “完成巡检”禁用或不可执行；
- 不把后端 409 作为主要交互提示。

任务项：

- NUMBER 使用数值控件；
- BOOLEAN 使用开关或明确“正常/异常”选择；
- TEXT 使用文本输入；
- resultStatus 使用 NORMAL / ABNORMAL 受控选择，不允许自由文本。

### 工单流程

工单详情按真实状态只展示当前阶段允许的动作。

维修日志、维修记录、验收记录优先使用时间线、描述列表或结构化表格，不能以原始 JSON/pre 作为最终展示。

### AI 人工确认

AI confirmationStatus=PENDING 时才显示确认/拒绝。

HIGH / CRITICAL 且 humanConfirmationRequired=true 时应有醒目的人工确认提示。

确认和拒绝：

- 使用确认对话框；
- 允许填写 comment；
- 提交时 loading/disabled；
- 成功后刷新；
- CONFIRMED / REJECTED 后隐藏重复操作；
- 展示确认结果、确认人、时间和备注（后端已有字段时）。

### 错误与重试

页面加载失败不能永久保持 loading。

至少形成：

loading
→ success / empty / error

error 状态提供可理解的中文错误和“重试”入口。

### 危险与状态流转操作

以下操作按风险提供二次确认：

- 完成巡检
- 生成巡检任务
- AI confirm/reject
- 提交维修结果
- 工单验收
- 用户禁用
- 角色权限修改
- 删除类操作

### Dashboard 待办导向

Dashboard 除统计外还要回答“当前用户下一步做什么”。

根据角色突出：

- SUPER_ADMIN：系统治理入口 + 全局风险/业务概况。
- ADMIN：高风险设备、待处理异常/缺陷、待验收工单。
- INSPECTOR：待巡检/进行中任务、近期异常。
- MAINTAINER：待处理工单、高风险缺陷、维修中工单。

数据必须来自真实 API；缺少后端聚合接口时允许用少量并行列表/统计请求组合，不为了 Dashboard 新增复杂服务。

### Gate 2 反模式

以下情况即使 build 通过也不能判 PASS：

- 让用户直接填写业务 ID；
- 所有字段统一 el-input；
- 核心详情页直接显示字段名或 JSON；
- 不同业务状态显示同一套操作按钮；
- 写操作没有 loading/disabled/反馈；
- 空状态没有业务说明；
- 页面加载失败无限转圈；
- 核心跨模块关系只显示裸 ID，没有业务名称或明确导航。

## 15. S4 分阶段

S4 仍然是一个 PC Web 阶段。S4-A 内部使用三个质量 Gate，S4-B 单独完成可视化和视觉强化。

### S4-A PC Core

完成：

- Vue 项目基础
- Vue Router
- Axios
- Pinia
- Element Plus
- 登录
- 路由守卫
- RBAC
- AdminLayout
- Breadcrumb
- Dashboard 基础数据
- 设备
- 巡检
- 维修
- AI
- 用户/角色
- 通知
- 列表/详情
- 跨模块业务跳转

S4-A 先保证真实页面结构、API、角色体验和业务链可跑，同时保持基础视觉完整。

#### S4-A Gate 1：身份、角色与交互基础

- login/logout/me
- token/currentUser/roles/permissions
- 四角色默认落地页
- Router Guard 与 /403
- RBAC Sidebar 与关键按钮基础能力
- AdminLayout / Header / Breadcrumb
- 中文化与公共状态映射
- loading / disabled / success / error / confirm 基础反馈

#### S4-A Gate 2：业务交互

- 设备、巡检、异常、缺陷、工单、AI、用户、角色、通知
- 状态驱动操作
- 用户角色分配；角色/权限矩阵按 06-role-usecases.md 只读展示，不在第一版 UI 动态修改冻结权限基线
- 真实关联导航
- 写操作完整反馈闭环

#### S4-A Gate 3：真实运行

- 四角色真实登录
- 四角色菜单、按钮和 /403
- 完整业务主链运行
- 详情 URL 刷新与浏览器前进/后退
- 最终 npm build
- Secret 检查

Gate 1、Gate 2、Gate 3 均通过后，S4-A 才能 PASS。

### S4-B Visualization & Polish

完成：

- ECharts
- Three.js
- Vue Flow
- WebSocket UX
- Dashboard 完整视觉
- 登录页视觉
- 页面统一视觉
- 响应式修整
- 对 S4-A 已有 loading/empty/error/success 状态进行视觉统一和精修

不得在 S4-B 扩张业务范围。

## 15.1 指定技术真实使用矩阵

指定技术必须参与真实业务，不能只安装依赖或制作孤立 Demo。

S1-S3 已落地并在 S6 复核：MySQL、MyBatis-Plus、Redis、Sa-Token、Nacos、Sentinel、RocketMQ、OpenFeign、DeepSeek、LangChain4j、LangGraph4j、Spring 原生 WebSocket。

S4-A 必须真实使用：Vue 3、Vite、TypeScript、Vue Router、Axios、Pinia、pinia-plugin-persistedstate、Element Plus。

S4-B 必须真实使用：

- ECharts：Dashboard 绑定真实设备、巡检、异常、缺陷、工单统计。
- Three.js：/devices/scene 绑定真实设备坐标、状态、风险和点击摘要。
- @vue-flow/core：巡检模板 flow_definition 的编辑、保存和回显。
- 浏览器原生 WebSocket：接收 /ws/notifications 实时通知并刷新未读数和通知列表。

上述 S4-B 技术如果只安装依赖、使用静态假数据或做与业务无关 Demo，S4 PC 不判 PASS。

S5 必须真实使用 HarmonyOS、ArkTS、ArkUI，并通过 HTTP REST 访问 Gateway，完成真实登录、巡检执行、异常上报、工单处理和 AI 结果查看。

## 16. S4 PC PASS

至少满足：

- npm build 通过
- 登录、退出和未登录路由守卫可用
- Vue Router 独立业务 URL 可直接刷新
- RBAC 菜单和关键入口生效
- 设备、巡检、维修、AI 主业务页面使用真实 API
- 业务详情可以沿关联对象跳转
- Dashboard 使用真实数据
- ECharts 可见
- Three.js 可交互且绑定真实设备
- Vue Flow 可保存并回显真实模板 flow_definition
- WebSocket 可收到真实通知
- AI 可发起、查看结果和 trace，并 confirm/reject
- 关键页面具备完整反馈状态
- 1366x768、1440x900、1920x1080 无明显布局问题

## 17. HarmonyOS 技术栈

- ArkTS
- ArkUI
- HTTP REST

HarmonyOS 第一版不做 WebSocket。

## 18. HarmonyOS 页面

只做：

1. Login
2. TodayInspection
3. TaskDetail
4. AbnormalReport
5. MyWorkOrders
6. WorkOrderDetail
7. AiResult

Home/Profile 如有需要可以作为简单入口，不扩展额外业务。

## 19. HarmonyOS 巡检

用户可以：

- 查看今日任务
- 开始任务
- 填 NUMBER / BOOLEAN / TEXT
- 提交异常
- 完成任务

PHOTO 第一版可以不作为阻塞项。

## 20. HarmonyOS 维修

面向 MAINTAINER 的现场端可以：

- 查看工单
- 开始维修
- 填写并提交维修结果
- 将工单推进到 WAITING_ACCEPTANCE

HarmonyOS 第一版不提供工单验收。验收由 PC 端 ADMIN / SUPER_ADMIN 完成。

## 21. HarmonyOS AI

只展示：

- 风险等级
- 原因
- 排查步骤
- 维修建议
- 是否需要人工确认

不做聊天。

## 22. HarmonyOS PASS

- 可以登录
- 可以完成一条巡检
- 可以提交异常
- 可以处理一条工单并提交维修结果至待验收状态
- 可以查看 AI 结果

达到以上即可，不扩展额外功能。
