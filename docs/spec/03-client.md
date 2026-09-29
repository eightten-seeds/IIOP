# IIOP 客户端实现规范

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
→ 工单详情
→ AI 诊断详情

详情页需要显示后端已有的关联 ID，并提供进入相关对象的明确入口。

不得为了跳转额外复制业务数据到前端。

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

### /system/roles

- 角色列表
- 角色信息
- 权限查看或轻量编辑

不做复杂权限设计器。

菜单和页面入口需要根据当前 permissions 做 RBAC 控制。

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

## 15. S4 分阶段

S4 仍然是一个 PC Web 阶段，为降低返工允许拆成两轮。

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

S4-A 先保证真实页面结构、API 和业务链可跑，同时保持基础视觉完整。

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
- loading/empty/error/success 等状态补齐

不得在 S4-B 扩张业务范围。

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

用户可以：

- 查看工单
- 开始维修
- 填写维修结果
- 提交验收

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
- 可以处理一条工单
- 可以查看 AI 结果

达到以上即可，不扩展额外功能。
