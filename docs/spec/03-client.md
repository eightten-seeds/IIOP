# IIOP PC 与 HarmonyOS 客户端实现规范

> 文档编号：IIOP-SPEC-03  
> 文档性质：PC 管理端、工业可视化端与 HarmonyOS 移动端实现基线  
> 上位规范：docs/spec/00-overview.md、docs/spec/01-database.md、docs/spec/02-backend.md  
> 适用对象：Codex、前端开发、HarmonyOS 开发、联调、测试与最终答辩  
> 当前状态：设计基线。后续客户端代码生成必须遵循本文档。

---

# 1. 文档目的

本文档固定 IIOP 两类客户端的产品范围和实现边界：

1. Vue 3 PC 管理端负责管理、监控、统计、三维可视化、流程设计和 AI 诊断；
2. HarmonyOS 移动端负责现场巡检、异常上报、维修工单和移动查看；
3. 两端统一经过 iiop-gateway 访问后端；
4. 两端共享同一套账号、权限、设备、巡检、维修和 AI 数据；
5. PC 必须真实使用 ECharts、Three.js、Vue Flow 和 WebSocket；
6. HarmonyOS 必须使用 ArkTS、ArkUI 和后端 REST API；
7. 页面不能使用大规模硬编码数据伪装已完成业务；
8. 客户端展示和交互必须与 00、01、02 三份规范中的业务状态、API、权限和数据边界一致。

本文档承担“页面级施工图”角色。Codex 在实现页面前应先阅读本文档对应章节，再读取后端真实 API 代码，不能根据常见后台模板自行扩充业务。

---

# 2. 客户端总体架构

系统客户端分为两个独立工程。

~~~text
E:/IIOP
├─ web
│  └─ Vue 3 PC 管理端
└─ harmony
   └─ HarmonyOS ArkTS 移动端
~~~

访问链路：

~~~text
PC Web
   │
   ├──────────────┐
   │              │
HarmonyOS         │
   │              │
   └──────► iiop-gateway :8080
                    │
                    ├─ /api/auth/**
                    ├─ /api/device/**
                    ├─ /api/inspection/**
                    ├─ /api/maintenance/**
                    ├─ /api/ai/**
                    └─ /ws/**
~~~

约束：

1. PC 和 HarmonyOS 禁止直连业务服务 9201 到 9205；
2. 两端禁止直接访问 Nacos、Redis、RocketMQ 或数据库；
3. 业务接口统一访问 Gateway；
4. PC 实时通知通过 Gateway WebSocket 路由；
5. HarmonyOS 第一版通知以 REST 拉取为主，后续若时间充足再接原生 WebSocket；
6. 业务 ID 在客户端统一当作字符串处理，避免 JavaScript Number 精度问题；
7. 后端 Entity/内部服务仍使用 Long，但外部 VO 的 id/deviceId/taskId/workOrderId/diagnosisId 等业务 ID 按字符串契约返回；
8. PageResult.total、duration 等普通数值继续保持数值语义。

第 6 到 8 条与 02-backend.md 的外部 ID 契约保持一致。

---

# 3. PC 技术栈与版本策略

固定技术：

1. Vue 3
2. Vite
3. TypeScript
4. Vue Router
5. Axios
6. Pinia
7. pinia-plugin-persistedstate
8. Element Plus
9. ECharts
10. Three.js
11. @vue-flow/core

工程初始化时选择当时与 Vue 3 和 Vite 兼容的稳定版本，并立即提交 package.json 与 package-lock.json。

依赖版本一旦首次可运行并锁定，后续 Codex 不得自行升级大版本。

官方资料当前能够确认：

1. Element Plus 面向 Vue 3；
2. Vue Flow 面向 Vue 3，支持拖拽节点、连线、缩放、选择和自定义节点；
3. Element Plus 当前版本线仍快速发布，因此项目首次初始化后必须锁定版本，避免实训开发过程中自动漂移。

---

# 4. PC 工程目录

建议最终结构：

~~~text
web/
├─ package.json
├─ package-lock.json
├─ .npmrc
├─ .env.example
├─ .env.development
├─ index.html
├─ vite.config.ts
├─ tsconfig.json
└─ src/
   ├─ main.ts
   ├─ App.vue
   ├─ api/
   │  ├─ http.ts
   │  ├─ auth.ts
   │  ├─ device.ts
   │  ├─ inspection.ts
   │  ├─ maintenance.ts
   │  └─ ai.ts
   ├─ assets/
   │  ├─ styles/
   │  └─ images/
   ├─ components/
   │  ├─ common/
   │  ├─ dashboard/
   │  ├─ device/
   │  ├─ inspection/
   │  ├─ maintenance/
   │  ├─ ai/
   │  └─ three/
   ├─ layout/
   │  ├─ AppLayout.vue
   │  ├─ AppSidebar.vue
   │  ├─ AppHeader.vue
   │  └─ NotificationPanel.vue
   ├─ router/
   │  ├─ index.ts
   │  └─ routes.ts
   ├─ stores/
   │  ├─ auth.ts
   │  ├─ app.ts
   │  └─ notification.ts
   ├─ types/
   │  ├─ api.ts
   │  ├─ auth.ts
   │  ├─ device.ts
   │  ├─ inspection.ts
   │  ├─ maintenance.ts
   │  └─ ai.ts
   ├─ utils/
   │  ├─ date.ts
   │  ├─ permission.ts
   │  └─ format.ts
   └─ views/
      ├─ login/
      ├─ dashboard/
      ├─ scene/
      ├─ device/
      ├─ inspection/
      ├─ maintenance/
      ├─ ai/
      ├─ system/
      ├─ notification/
      └─ profile/
~~~

规则：

1. API 请求集中在 src/api；
2. 页面不得自己创建 Axios 实例；
3. TypeScript 类型集中管理；
4. Pinia Store 只保存跨页面状态；
5. 页面临时表单状态留在页面或 composable；
6. 不把所有页面逻辑塞入单个 store；
7. Three.js 场景逻辑拆为组件或 composable；
8. ECharts 图表初始化和 resize 逻辑封装；
9. Vue Flow 自定义节点单独组件化。

---

# 5. PC 本地依赖与 E 盘约束

web 工程路径：

E:/IIOP/web

npm cache：

E:/DevCache/npm

项目应创建：

web/.npmrc

至少设置：

~~~text
cache=E:/DevCache/npm
~~~

node_modules 位于 E:/IIOP/web/node_modules。

执行 npm install 前，Codex 必须检查：

1. 当前工作目录为 E:/IIOP/web；
2. npm cache 指向 E 盘；
3. 不主动把项目缓存切回 C 盘；
4. package-lock.json 必须提交 Git。

---

# 6. PC 环境变量

开发环境至少规划：

~~~text
VITE_APP_TITLE=工业设备智能巡检运维平台
VITE_API_BASE_URL=http://127.0.0.1:8080
VITE_WS_BASE_URL=ws://127.0.0.1:8080
~~~

.env.example 可以提交。

真实私密信息禁止写入 Vite 环境变量，因为前端构建变量最终可被浏览器读取。

PC 端不保存：

1. 数据库密码；
2. Redis 密码；
3. DeepSeek API Key；
4. Same-Token Secret；
5. 其他服务端密钥。

---

# 7. PC HTTP 封装

## 7.1 Axios 实例

统一在 src/api/http.ts 创建 Axios 实例。

基础要求：

1. baseURL 来自 VITE_API_BASE_URL；
2. 设置合理 timeout；
3. 请求头统一 application/json；
4. multipart 请求按上传场景单独处理；
5. 不在每个 API 文件重复创建实例。

## 7.2 Sa-Token 请求头

登录接口返回：

1. tokenName；
2. tokenValue。

auth store 保存二者。

后续请求拦截器使用动态 Header：

~~~text
[tokenName]: tokenValue
~~~

禁止把 Header 名硬编码成 Authorization，除非后端最终 Sa-Token 配置明确改成 Authorization。

## 7.3 响应处理

后端结构：

~~~json
{
  "code": 0,
  "message": "success",
  "data": {},
  "traceId": "..."
}
~~~

Axios 响应拦截器处理：

1. code = 0，返回 data；
2. 401xx，清理登录态并跳转 login；
3. 403xx，提示无权限；
4. 429xx，提示请求过于频繁；
5. 503xx，提示相关服务暂不可用；
6. 其他业务码显示 message；
7. 未知异常显示通用错误，并保留 traceId 便于排查。

禁止把所有错误都显示成“网络异常”。

---

# 8. PC 登录状态与 Pinia

auth store 保存：

1. tokenName；
2. tokenValue；
3. currentUser；
4. roles；
5. permissions；
6. login 状态。

使用 pinia-plugin-persistedstate 持久化最小必要字段：

1. tokenName；
2. tokenValue；
3. currentUser 基本信息。

roles 和 permissions 在刷新页面后优先通过 GET /api/auth/me 重新获取，避免长期持有过期权限快照。

退出时：

1. 调用 POST /api/auth/logout；
2. 清理 Pinia；
3. 断开 WebSocket；
4. 跳转 /login。

---

# 9. PC Router 与菜单权限

## 9.1 路由策略

路由定义保存在代码中。

登录后根据 /api/auth/me 返回的 permissions 对菜单进行过滤。

第一版不从数据库动态下载完整 Vue Route 代码。

这样可以减少动态路由复杂度，同时 sys_permission 仍然用于后端 RBAC 和菜单权限控制。

## 9.2 路由 meta

每个业务路由应包含：

1. title；
2. icon；
3. permission；
4. keepAlive 可选；
5. hidden 可选。

路由守卫：

1. /login 对未登录用户开放；
2. 其他页面必须登录；
3. 无 permission 时进入 403 页面；
4. 404 路由进入 NotFound；
5. 后端仍必须执行权限校验，前端菜单隐藏不能代替后端鉴权。

---

# 10. PC 主导航结构

建议菜单：

~~~text
首页
├─ 工业驾驶舱
└─ 三维设备场景

设备管理
├─ 设备分类
├─ 设备台账
├─ 实时监测
└─ SOP 管理

巡检管理
├─ 巡检模板
├─ 巡检计划
├─ 巡检任务
└─ 巡检异常

运维管理
├─ 告警中心
├─ 缺陷管理
└─ 维修工单

AI 智能运维
└─ 智能诊断

系统管理
├─ 用户管理
├─ 角色管理
└─ 权限管理

顶部区域
├─ 通知中心
└─ 个人中心
~~~

菜单按权限过滤。

---

# 11. PC 路由清单

| 路径 | 页面 | 主要权限 |
|---|---|---|
| /login | 登录 | public |
| /dashboard | 工业驾驶舱 | dashboard:view |
| /scene | 三维设备场景 | device:view |
| /device/categories | 设备分类 | device:view |
| /device/list | 设备台账 | device:view |
| /device/:id | 设备详情 | device:view |
| /device/monitor | 实时监测 | device:view |
| /device/sops | SOP 管理 | device:view |
| /inspection/templates | 巡检模板 | inspection:view |
| /inspection/templates/:id/flow | 流程设计 | inspection:template:manage |
| /inspection/plans | 巡检计划 | inspection:view |
| /inspection/tasks | 巡检任务 | inspection:view |
| /inspection/tasks/:id | 巡检任务详情 | inspection:view |
| /inspection/abnormals | 巡检异常 | inspection:view |
| /maintenance/alarms | 告警中心 | maintenance:view |
| /maintenance/defects | 缺陷管理 | maintenance:view |
| /maintenance/work-orders | 维修工单 | maintenance:view |
| /maintenance/work-orders/:id | 工单详情 | maintenance:view |
| /ai/diagnoses | AI 诊断 | ai:view |
| /ai/diagnoses/:id | AI 诊断详情 | ai:view |
| /system/users | 用户管理 | system:user:view |
| /system/roles | 角色管理 | system:role:view |
| /system/permissions | 权限管理 | system:permission:view |
| /notifications | 通知中心 | 登录即可 |
| /profile | 个人中心 | 登录即可 |

如果后端最终权限码稍有调整，03 与 02 必须同步修改。

---

# 12. PC 视觉设计原则

参考项目演示风格，PC 采用“工业监控区深色、管理区高可读性”的视觉策略。

## 12.1 工业驾驶舱与三维场景

采用深色工业监控风格。

要求：

1. 深色背景；
2. 卡片边界清晰；
3. 数字指标高对比；
4. 告警和风险等级使用一致的状态语义；
5. 图表背景透明或半透明；
6. 三维场景与实时指标视觉一致。

## 12.2 业务管理页面

采用高可读性的管理后台布局。

要求：

1. 左侧导航固定；
2. 顶部 Header；
3. 主体区域使用表格、表单、抽屉、详情卡片；
4. 表格密度适中；
5. 状态 Tag 统一；
6. 危险操作需要二次确认。

## 12.3 状态语义

全项目统一状态视觉映射。

例如：

设备：

1. ONLINE：正常；
2. OFFLINE：离线；
3. FAULT：故障；
4. MAINTENANCE：维修中；
5. SCRAPPED：停用/报废。

风险：

1. LOW；
2. MEDIUM；
3. HIGH；
4. CRITICAL。

具体颜色由主题 token 统一定义，页面组件不得自行随意指定不同颜色。

---

# 13. 登录页

路由：

/login

接口：

POST /api/auth/login

页面元素：

1. 项目名称；
2. 工业设备运维副标题；
3. username；
4. password；
5. 登录按钮；
6. 登录中状态；
7. 错误提示。

登录成功：

1. 保存 token；
2. 保存用户摘要；
3. 请求 /api/auth/me；
4. 初始化权限；
5. 建立 PC WebSocket；
6. 跳转 /dashboard。

禁止：

1. 在页面写死管理员密码；
2. 自动填入真实账号；
3. 把密码写入 localStorage；
4. 展示“账号存在/不存在”的差异化错误。

---

# 14. 工业驾驶舱

路由：

/dashboard

主要用户：

SUPER_ADMIN、ADMIN，可按需要让其他角色只读。

## 14.1 顶部 KPI

至少展示：

1. 设备总数；
2. ONLINE；
3. OFFLINE；
4. FAULT；
5. MAINTENANCE；
6. 今日巡检任务；
7. 今日已完成；
8. 当前活跃告警；
9. 待处理工单。

接口来源：

1. GET /api/device/statistics/overview
2. GET /api/inspection/statistics/overview
3. GET /api/maintenance/statistics/overview

前端并行请求。

## 14.2 图表

### 图表 A：设备状态分布

类型：

ECharts 饼图或环图。

接口：

GET /api/device/statistics/status-distribution

维度：

ONLINE、OFFLINE、FAULT、MAINTENANCE、SCRAPPED。

### 图表 B：设备风险分布

类型：

ECharts 柱状图或环图。

接口：

GET /api/device/statistics/risk-distribution

维度：

LOW、MEDIUM、HIGH、CRITICAL。

### 图表 C：巡检趋势

类型：

ECharts 折线图。

接口：

GET /api/inspection/statistics/trend

默认最近 7 天。

至少展示：

1. 任务总数；
2. 完成数；
3. 异常任务数。

### 图表 D：告警趋势

类型：

ECharts 折线图。

接口：

GET /api/maintenance/statistics/alarm-trend

默认最近 7 天。

### 图表 E：工单状态

类型：

ECharts 柱状图或饼图。

接口：

GET /api/maintenance/statistics/work-order-distribution

## 14.3 最近动态

页面底部可展示：

1. 最近告警；
2. 最近异常；
3. 最近工单。

如果后端还没有专用 Dashboard 聚合 API，第一版通过各列表接口 pageSize=5 获取。

不新增 dashboard 微服务。

---

# 15. ECharts 实现规则

ECharts 必须封装通用组件或 composable，至少解决：

1. init；
2. setOption；
3. ResizeObserver 或 window resize；
4. 页面销毁 dispose；
5. loading；
6. empty state；
7. 接口失败状态。

图表数据禁止直接写死在组件中。

允许开发阶段使用 Mock 的前提是：

1. 明确标记 mock；
2. 联调后必须替换；
3. 最终演示模式不得保留随机数据作为正式数据来源。

---

# 16. 三维设备场景

路由：

/scene

核心技术：

Three.js。

业务目标：

通过三维视图快速查看车间设备位置、状态和风险。

## 16.1 数据来源

使用：

GET /api/device/devices

第一版演示设备数量较少，可按 pageSize 最大值获取。

每台设备至少需要：

1. id；
2. deviceCode；
3. deviceName；
4. status；
5. riskLevel；
6. modelUrl；
7. positionX；
8. positionY；
9. positionZ；
10. workshop；
11. productionLine。

## 16.2 场景基础

至少包含：

1. Scene；
2. PerspectiveCamera；
3. WebGLRenderer；
4. 环境光；
5. 方向光；
6. 地面网格；
7. OrbitControls；
8. resize；
9. requestAnimationFrame 生命周期管理。

## 16.3 模型加载

有 modelUrl：

1. 使用 GLTFLoader；
2. 加载 glTF/glb；
3. 根据设备坐标放置；
4. 绑定 deviceId 到 Object3D userData。

无 modelUrl：

1. 使用 Box/Cylinder 等几何体占位；
2. 仍然必须能够点击；
3. 仍然显示真实设备状态。

单个模型加载失败：

1. 不让整个场景崩溃；
2. 使用占位模型；
3. 控制台记录设备编码和错误。

## 16.4 状态表达

设备外观根据：

1. status；
2. riskLevel；

生成统一状态效果。

禁止每帧创建新材质。

需要高亮时复用材质或 Outline 效果。

## 16.5 交互

使用 Raycaster。

点击设备后右侧展示摘要卡：

1. 设备名称；
2. 编码；
3. 状态；
4. 风险；
5. 车间；
6. 产线；
7. 最近关键指标，若接口允许；
8. 查看详情按钮。

查看详情进入：

/device/{id}

## 16.6 性能边界

第一版目标是实训演示场景，不追求超大数字孪生。

要求：

1. 模型数量控制；
2. renderer 在组件卸载时释放；
3. geometry/material/texture 释放；
4. 不在 Vue 响应式对象中保存整个 Three.js Scene；
5. 避免每个设备单独建立高频定时器。

---

# 17. 设备分类页

路由：

/device/categories

接口：

1. GET /api/device/categories/tree
2. POST /api/device/categories
3. PUT /api/device/categories/{id}
4. DELETE /api/device/categories/{id}

页面：

左侧或主体树形表格。

字段：

1. categoryCode；
2. categoryName；
3. parent；
4. status；
5. sortOrder；
6. description。

操作：

1. 新增根分类；
2. 新增子分类；
3. 编辑；
4. 删除；
5. 启用/禁用，若后端采用统一更新接口。

删除前提示影响。

---

# 18. 设备台账页

路由：

/device/list

接口：

GET /api/device/devices

筛选：

1. keyword；
2. categoryId；
3. status；
4. riskLevel；
5. workshop；
6. productionLine。

表格列：

1. deviceCode；
2. deviceName；
3. categoryName；
4. model；
5. workshop；
6. productionLine；
7. status；
8. riskLevel；
9. responsibleUserName；
10. updatedAt。

按钮：

1. 查看；
2. 新增；
3. 编辑；
4. 状态变更；
5. 删除。

权限控制：

1. device:view；
2. device:create；
3. device:update；
4. device:delete。

新增/编辑表单至少包含数据库规范中的设备主数据字段。

Three.js 坐标和 modelUrl 放到“数字场景配置”区域，不与基础信息混杂。

---

# 19. 设备详情页

路由：

/device/:id

主接口：

GET /api/device/devices/{id}

采用 Tab：

1. 基础信息；
2. 监测指标；
3. 监测趋势；
4. SOP；
5. 巡检历史；
6. 维修历史。

数据来源：

设备信息：

GET /api/device/devices/{id}

指标：

GET /api/device/devices/{id}/metrics

当前指标：

GET /api/device/devices/{id}/metric-snapshot

趋势：

GET /api/device/devices/{id}/metric-trend

巡检历史当前由 inspection 外部列表接口按 deviceId 查询。

维修历史可由 maintenance 的工单/历史接口按 deviceId 查询。

如果某个历史专用外部 API 在后端实现阶段没有提供，前端不得直接调用 /internal 接口，应补齐外部查询 API 后再实现。

---

# 20. 实时监测页

路由：

/device/monitor

第一版“实时”定义：

1. 展示设备当前状态；
2. 展示最新指标值；
3. 指标趋势可定时刷新；
4. 告警通过 WebSocket 通知。

无需模拟毫秒级工业 SCADA。

界面：

左侧设备列表。

右侧：

1. 设备卡片；
2. 指标卡；
3. ECharts 趋势；
4. 告警摘要。

数据接口：

GET /api/device/devices/{id}/metric-snapshot

刷新策略：

1. 当前选中设备的 metric-snapshot 5 到 10 秒轮询一次，具体由联调确定；
2. 页面隐藏或销毁时停止轮询；
3. 不允许每个列表行建立一个轮询定时器。

---

# 21. SOP 管理页

路由：

/device/sops

接口：

1. GET /api/device/sops
2. GET /api/device/sops/{id}
3. POST /api/device/sops
4. PUT /api/device/sops/{id}
5. DELETE /api/device/sops/{id}

字段：

1. sopCode；
2. title；
3. sopType；
4. category；
5. device；
6. version；
7. status；
8. effectiveDate；
9. content。

content 第一版使用文本编辑区域。

不引入富文本编辑器依赖，除非后续确有必要。

---

# 22. 巡检模板页

路由：

/inspection/templates

接口：

1. GET /api/inspection/templates
2. POST /api/inspection/templates
3. PUT /api/inspection/templates/{id}
4. DELETE /api/inspection/templates/{id}

列表：

1. templateCode；
2. templateName；
3. category；
4. version；
5. status；
6. updatedAt。

详情或编辑时管理模板项：

1. itemCode；
2. itemName；
3. itemType；
4. unit；
5. standardValue；
6. lowerLimit；
7. upperLimit；
8. requiredFlag；
9. inspectionMethod；
10. abnormalHint；
11. sortOrder。

模板项支持排序。

“流程设计”按钮进入：

/inspection/templates/{id}/flow

---

# 23. Vue Flow 巡检流程设计

技术：

@vue-flow/core

用途：

把巡检模板的检查逻辑以节点和边的形式可视化。

该功能第一版只承担流程设计和展示，不承担独立 BPMN 执行引擎。

实际巡检任务仍以 ins_template_item 和 ins_task_item 为业务事实。

## 23.1 页面结构

左侧：

节点工具栏。

中间：

Vue Flow Canvas。

右侧：

节点属性面板。

顶部：

1. 保存；
2. 自动适配；
3. 清空；
4. 返回模板。

## 23.2 节点类型

Vue Flow 第一版只做流程可视化，节点保持简单：

1. START
2. CHECK_ITEM
3. CONDITION
4. REPORT_ABNORMAL
5. END

Vue Flow 不模拟 LangGraph4j 的 AI 工作流，也不承担 BPMN 执行。

## 23.3 节点数据

统一：

~~~json
{
  "id": "node-1",
  "type": "CHECK_ITEM",
  "position": {
    "x": 100,
    "y": 200
  },
  "data": {
    "label": "检查主轴温度",
    "templateItemId": "123"
  }
}
~~~

## 23.4 保存

接口：

PUT /api/inspection/templates/{id}/flow

保存：

1. nodes；
2. edges；
3. viewport 可选；
4. schemaVersion。

建议 flow_definition：

~~~json
{
  "schemaVersion": 1,
  "nodes": [],
  "edges": [],
  "viewport": {
    "x": 0,
    "y": 0,
    "zoom": 1
  }
}
~~~

禁止保存 Vue 组件实例、函数或无法 JSON 序列化对象。

---

# 24. 巡检计划页

路由：

/inspection/plans

接口：

1. GET /api/inspection/plans
2. GET /api/inspection/plans/{id}
3. POST /api/inspection/plans
4. PUT /api/inspection/plans/{id}
5. PUT /api/inspection/plans/{id}/status
6. DELETE /api/inspection/plans/{id}

字段：

1. planCode；
2. planName；
3. device；
4. template；
5. scheduleType；
6. cronExpression；
7. startDate；
8. endDate；
9. assignee；
10. status；
11. nextGenerateTime。

scheduleType=CRON 时显示 cronExpression。

第一版不实现复杂的 Cron 可视化生成器，可以输入并做基本格式提示。

---

# 25. 巡检任务页

路由：

/inspection/tasks

接口：

GET /api/inspection/tasks

筛选：

1. keyword 可选；
2. deviceId；
3. assigneeUserId；
4. taskStatus；
5. resultStatus；
6. overdue；
7. startDate；
8. endDate。

表格：

1. taskCode；
2. deviceName；
3. assignee；
4. scheduledStartTime；
5. scheduledEndTime；
6. taskStatus；
7. overdue；
8. resultStatus；
9. completionRate。

操作：

1. 查看；
2. 手工创建任务，管理员；
3. 开始；
4. 取消；
5. 继续执行。

任务详情页：

/inspection/tasks/:id

展示任务项并允许有权限的巡检人员执行。

---

# 26. PC 巡检任务执行页

PC 同样支持任务执行，便于开发联调和答辩。

流程：

1. GET task；
2. POST start；
3. 展示所有 taskItem；
4. 根据 itemType 渲染不同输入；
5. 提交每个 item；
6. 异常项可以创建 abnormal；
7. 全部必填项完成后 complete。

itemType：

NUMBER：

数值输入。

BOOLEAN：

正常/异常或是/否选择，具体语义由检查项定义。

TEXT：

文本输入。

PHOTO：

图片证据。

上传使用：

POST /api/inspection/attachments/images

提交 task item 或 abnormal 时只保存上传接口返回的 URL。

客户端不得把 base64 大图长期写入业务 JSON，也不得伪造上传成功 URL。

---

# 27. 巡检异常页

路由：

/inspection/abnormals

接口：

1. GET /api/inspection/abnormals
2. GET /api/inspection/abnormals/{id}
3. PUT /api/inspection/abnormals/{id}/status

字段：

1. abnormalCode；
2. deviceName；
3. taskCode；
4. title；
5. severity；
6. status；
7. reportedBy；
8. reportedAt。

详情：

1. description；
2. evidence；
3. 对应任务项；
4. 后续缺陷/AI 关联信息如果后端提供。

---

# 28. 告警中心

路由：

/maintenance/alarms

接口：

1. GET /api/maintenance/alarms
2. GET /api/maintenance/alarms/{id}
3. POST /api/maintenance/alarms/{id}/acknowledge
4. POST /api/maintenance/alarms/{id}/recover
5. POST /api/maintenance/alarms/{id}/close

筛选：

1. deviceId；
2. alarmLevel；
3. status；
4. 时间范围。

表格：

1. alarmCode；
2. device；
3. alarmLevel；
4. alarmTitle；
5. alarmValue；
6. thresholdValue；
7. occurTime；
8. status。

CRITICAL 和 MAJOR 在 UI 中必须突出。

告警 WebSocket 到达后：

1. 顶部通知；
2. 更新未读数；
3. 用户在告警页时可刷新列表；
4. 不强制自动弹出阻断式对话框。

---

# 29. 缺陷管理

路由：

/maintenance/defects

接口：

1. GET /api/maintenance/defects
2. GET /api/maintenance/defects/{id}
3. POST /api/maintenance/defects/manual
4. POST confirm
5. POST resolve
6. POST close

列表：

1. defectCode；
2. sourceType；
3. device；
4. severity；
5. title；
6. status；
7. reportedAt。

详情显示：

1. sourceType；
2. sourceId；
3. description；
4. 关联设备；
5. 是否已有工单；
6. 相关 AI 诊断 ID，如果后端已关联。

---

# 30. 维修工单页

路由：

/maintenance/work-orders

接口以 02-backend.md 第 25 章为准。

列表：

1. workOrderCode；
2. deviceName；
3. title；
4. type；
5. priority；
6. status；
7. assignee；
8. plannedStartTime；
9. createdAt。

筛选：

1. keyword；
2. device；
3. priority；
4. status；
5. assignee；
6. 时间范围。

根据状态显示允许动作。

禁止把所有动作按钮永久显示。

---

# 31. 工单详情页

路由：

/maintenance/work-orders/:id

建议布局：

左侧主体：

1. 工单基本信息；
2. 缺陷来源；
3. 维修信息；
4. 验收信息。

右侧：

1. 当前状态；
2. 操作按钮；
3. AI 辅助诊断卡。

底部：

工单时间线。

接口：

GET /api/maintenance/work-orders/{id}

日志：

GET /api/maintenance/work-orders/{id}/logs

AI 诊断：

前端根据 aiDiagnosisId 调用：

GET /api/ai/diagnoses/{id}

状态动作：

1. submit；
2. assign；
3. start；
4. repair；
5. submit-acceptance；
6. accept；
7. reject；
8. cancel。

按钮显示取决于：

1. 用户权限；
2. 当前状态；
3. 当前 assignee；
4. 后端允许的状态迁移。

前端只用于降低误操作，后端仍必须重新校验。

---

# 32. AI 智能诊断列表

路由：

/ai/diagnoses

接口：

1. GET /api/ai/diagnoses
2. POST /api/ai/diagnoses

列表：

1. diagnosisCode；
2. device；
3. triggerType；
4. riskLevel；
5. diagnosisStatus；
6. confirmationStatus；
7. modelName；
8. createdAt。

支持：

1. 按设备筛选；
2. 按状态筛选；
3. 按风险筛选；
4. 人工发起诊断。

人工发起表单：

1. device；
2. abnormalSummary；
3. 可选补充描述。

具体 AI 请求模型以 04-ai.md 为准。

---

# 33. AI 诊断详情

路由：

/ai/diagnoses/:id

接口：

1. GET /api/ai/diagnoses/{id}
2. GET /api/ai/diagnoses/{id}/workflow
3. POST /api/ai/diagnoses/{id}/confirm
4. POST /api/ai/diagnoses/{id}/reject

必须展示：

1. 设备；
2. 触发来源；
3. 诊断状态；
4. 风险等级；
5. 异常摘要；
6. 可能原因；
7. 每个原因的依据或可信说明，若 AI 输出包含；
8. 排查步骤；
9. 维修建议；
10. 安全提示；
11. 模型名称；
12. Prompt 版本；
13. 人工确认状态；
14. workflow trace。

页面固定醒目标识：

“AI 诊断结果仅用于辅助判断，高风险操作必须由具备权限的人员确认后执行。”

## 33.1 工作流展示

使用时间线或步骤条。

节点：

1. LOAD_CONTEXT；
2. ANALYZE_WITH_DEEPSEEK；
3. RISK_CHECK；
4. GENERATE_ADVICE；
5. PREPARE_WORK_ORDER_DRAFT。

每个节点展示：

1. nodeName；
2. nodeStatus；
3. startedAt；
4. finishedAt；
5. errorMessage，可选。

不得把完整敏感 Prompt 直接展示给普通用户。

---

# 34. 用户管理

路由：

/system/users

接口：

02-backend.md 第 22.4 节。

功能：

1. 分页；
2. username 搜索；
3. 状态筛选；
4. 新增；
5. 编辑；
6. 启用/禁用/锁定；
7. 分配角色；
8. 逻辑删除。

密码：

1. 创建时输入；
2. 不在表格展示；
3. 不回显 passwordHash；
4. 编辑普通资料时不回传密码字段。

---

# 35. 角色管理

路由：

/system/roles

功能：

1. 角色列表；
2. 新增角色；
3. 编辑；
4. 删除；
5. 分配权限。

预置四角色可以允许查看和权限配置。

是否允许删除系统预置角色由后端规则决定，前端不能自行假设。

权限分配使用树形控件。

---

# 36. 权限管理

路由：

/system/permissions

页面使用树形表格。

字段：

1. permissionCode；
2. permissionName；
3. permissionType；
4. routePath；
5. apiPath；
6. httpMethod；
7. status；
8. sortOrder。

只有 SUPER_ADMIN 或具有相应系统权限的用户显示入口。

---

# 37. 通知中心

顶部 Header：

1. 铃铛图标；
2. 未读数量；
3. 最近若干通知；
4. 查看全部。

REST：

1. GET /api/auth/notifications
2. GET /api/auth/notifications/unread-count
3. PUT /api/auth/notifications/{id}/read
4. PUT /api/auth/notifications/read-all

通知类型：

1. ALARM；
2. INSPECTION；
3. WORK_ORDER；
4. AI；
5. SYSTEM。

点击通知：

根据 bizType 跳转对应详情。

若关联对象不可访问，提示无权限或对象不存在。

---

# 38. PC 原生 WebSocket

后端约定：

1. Gateway 路径 /ws/**；
2. endpoint /ws/notifications；
3. 用户订阅 /user/queue/notifications。

PC 初始化时：

1. 用户登录成功后连接；
2. CONNECT Header 携带 Sa-Token；
3. 连接成功后订阅 user queue；
4. 消息进入 notification store；
5. 更新未读数量；
6. 按业务类型展示轻提示。

断线策略：

1. 指数或分级重连；
2. 页面隐藏不强制关闭；
3. logout 立即关闭；
4. 网络恢复后重连；
5. 重连后通过 REST 再拉取未读数，避免漏消息。

禁止用 WebSocket 消息直接覆盖完整业务实体状态。

业务页面仍通过 REST 获取权威数据。

---

# 39. PC Loading、Empty 与 Error 状态

每个异步页面必须明确三类状态：

1. loading；
2. empty；
3. error。

表格：

加载中使用 Element Plus loading。

空列表显示明确空状态。

请求失败：

1. 保留筛选条件；
2. 提供重试；
3. 不把旧数据伪装成最新数据。

危险操作：

1. 删除；
2. 取消任务；
3. 关闭告警；
4. 工单验收；
5. AI 拒绝确认；

必须二次确认。

---

# 40. PC 表格与表单统一规范

表格：

1. 默认分页 20；
2. pageSize 可选 10/20/50/100；
3. ID 原则上不直接展示；
4. 业务 code 优先展示；
5. 时间统一格式 YYYY-MM-DD HH:mm:ss；
6. 状态通过 Tag；
7. 操作列固定右侧。

表单：

1. 标签中文；
2. 必填项明确；
3. 前端 Bean 级逻辑校验只做用户体验；
4. 后端返回校验错误仍要显示；
5. 提交中禁用重复点击；
6. 成功后刷新数据。

---

# 41. PC ID 与时间处理

## 41.1 Long ID

Java ASSIGN_ID 可能超过 JavaScript 安全整数范围。

因此：

1. PC TypeScript 所有业务 ID 类型使用 string；
2. 后端外部 VO 的业务 ID 返回字符串；
3. URL path 可以直接传 string；
4. 禁止 parseInt 后再保存；
5. total、durationMs、count 等普通统计数值仍使用 number。

## 41.2 时间

后端使用 ISO-8601 或项目统一时间字符串。

前端集中格式化。

禁止页面各自使用不同时间格式。

---

# 42. PC 响应式范围

目标设备：

主要：

1920×1080 桌面浏览器。

兼容：

1366×768。

不要求 PC 管理后台完整适配手机，因为手机业务由 HarmonyOS 承担。

要求：

1. Dashboard 在 1366 宽度仍可阅读；
2. 表格允许横向滚动；
3. Three.js 画布随容器 resize；
4. 不使用大量固定像素导致溢出。

---

# 43. HarmonyOS 产品定位

HarmonyOS 端服务现场巡检员和维修人员。

核心价值：

1. 离开 PC 后执行现场任务；
2. 快速查看设备；
3. 填写检查项；
4. 上报异常；
5. 处理维修工单；
6. 查看 AI 辅助诊断；
7. 查看通知。

移动端不实现：

1. 用户权限配置；
2. 角色配置；
3. 复杂 Dashboard；
4. Three.js 三维大场景；
5. Vue Flow 流程编辑；
6. 全量设备主数据后台管理。

---

# 44. HarmonyOS 技术原则

固定：

1. ArkTS；
2. ArkUI；
3. Stage 模型；
4. 声明式 UI；
5. 网络请求使用 HarmonyOS Network Kit 中适合所选 API Level 的 HTTP 能力；
6. 图片选择使用 Media Library Kit 的系统 Photo Picker 能力；
7. 持久化登录凭证使用 HarmonyOS 提供的持久化偏好能力；
8. 页面状态与业务逻辑分离；
9. 具体 API Level 在 DevEco 初始化时根据本机 SDK 决定，随后锁定，不由 Codex 自行升级。

当前华为官方资料确认：

1. ArkTS 是 HarmonyOS 应用开发语言；
2. ArkUI 是声明式 UI 框架；
3. Network Kit 提供 HTTP 和 WebSocket 能力；
4. Media Library Kit 提供 PhotoViewPicker/PhotoPicker；
5. HarmonyOS 提供 LocalStorage、AppStorage、PersistentStorage 等状态能力。

具体 import 名称应以最终锁定 API Level 的官方 SDK 为准，禁止从旧教程机械复制已经归档的 API。

---

# 45. HarmonyOS 分层结构

参考项目采用的移动端分层思路，IIOP 固定为：

~~~text
Pages
  ↓
ViewModel
  ↓
Api
  ↓
Model
  ↓
Common / Storage
~~~

建议目录：

~~~text
harmony/
└─ entry/src/main/ets/
   ├─ pages/
   ├─ components/
   ├─ viewmodel/
   ├─ api/
   ├─ model/
   ├─ common/
   │  ├─ HttpClient.ets
   │  ├─ ApiConfig.ets
   │  ├─ AuthStorage.ets
   │  └─ DateUtil.ets
   └─ constants/
~~~

职责：

Pages：

只负责页面和用户交互。

ViewModel：

处理页面业务状态、加载、提交和错误。

Api：

封装 REST 接口。

Model：

定义 Request/Response 数据模型。

Storage：

保存 Token 和少量用户状态。

---

# 46. HarmonyOS 网络封装

统一 HttpClient。

至少支持：

1. GET；
2. POST JSON；
3. PUT JSON；
4. DELETE；
5. multipart 文件上传。

基础 URL：

开发环境指向：

http://开发机局域网IP:8080

注意：

HarmonyOS 模拟器或真机不能默认把 127.0.0.1 当作 Windows 开发机。

开发时由 ApiConfig 集中配置 Gateway 地址。

## 46.1 Token

登录返回 tokenName/tokenValue。

AuthStorage 持久化。

每次请求自动增加：

[tokenName]: tokenValue

401xx：

1. 清理登录态；
2. 跳回登录；
3. 显示会话过期提示。

---

# 47. HarmonyOS 导航与状态

页面导航使用所选 API Level 当前推荐的 ArkUI 导航方案。

如果最终 SDK 推荐 Navigation/NavPathStack，则优先采用该方案。

禁止在锁定 SDK 后仍混用多套路由机制。

页面级状态：

使用 ArkUI 状态管理。

全局小量状态：

1. 当前用户；
2. Token；
3. 当前 API 地址；

通过应用级状态或持久化存储管理。

禁止建立一个包含所有页面业务数据的巨型全局 Store。

---

# 48. HarmonyOS 页面清单

第一版固定：

1. LoginPage
2. HomePage
3. TodayInspectionPage
4. InspectionTaskDetailPage
5. InspectionItemPage 或任务详情内部执行组件
6. AbnormalReportPage
7. DeviceDetailPage
8. AlarmPage
9. MyWorkOrderPage
10. WorkOrderDetailPage
11. WorkOrderProcessPage
12. AiDiagnosisPage
13. NotificationPage
14. ProfilePage

可以根据 ArkUI 页面组织合并部分详情页，但功能范围不能减少。

---

# 49. HarmonyOS 登录页

接口：

POST /api/auth/login

字段：

1. username；
2. password。

成功：

1. 保存 tokenName；
2. 保存 tokenValue；
3. 保存用户摘要；
4. 跳 HomePage。

移动端默认服务对象：

INSPECTOR 和 MAINTAINER。

管理员账号可以登录，但移动端不显示完整系统管理菜单。

---

# 50. HarmonyOS 首页

首页应简单，突出现场工作。

顶部：

1. 用户名称；
2. 当前日期；
3. 通知未读数。

核心卡片：

对 INSPECTOR：

1. 今日待巡检；
2. 进行中；
3. 已完成；
4. 异常数量。

对 MAINTAINER：

1. 待处理工单；
2. 处理中；
3. 待验收；
4. 高优先级。

快捷入口：

1. 今日巡检；
2. 我的工单；
3. 告警；
4. AI 诊断；
5. 通知。

数据来自现有列表/统计接口。

---

# 51. 今日巡检页

页面：

TodayInspectionPage

接口：

GET /api/inspection/tasks

参数：

1. assigneeUserId=当前用户；
2. 日期范围=今天；
3. taskStatus 可筛选。

列表卡片显示：

1. taskCode；
2. deviceName；
3. installLocation；
4. scheduledStartTime；
5. taskStatus；
6. overdue；
7. completionRate。

操作：

进入详情。

对于非本人任务，后端权限规则决定是否可查看或执行。

---

# 52. 移动巡检任务详情

流程：

1. 拉取 GET /api/inspection/tasks/{id}；
2. 显示设备摘要；
3. 显示进度；
4. 显示检查项；
5. PENDING 时提供“开始巡检”；
6. IN_PROGRESS 时允许填写；
7. COMPLETED 时只读。

开始：

POST /api/inspection/tasks/{id}/start

任务项根据类型渲染。

NUMBER：

数字输入和单位。

BOOLEAN：

选择。

TEXT：

文本。

PHOTO：

选择图片并上传。

图片上传必须等后端文件接口正式补齐后实现真实传输。

---

# 53. HarmonyOS 异常上报

页面：

AbnormalReportPage

入口：

从异常检查项进入。

字段：

1. severity；
2. title；
3. description；
4. evidence；
5. 关联 taskItem 自动带入。

接口：

POST /api/inspection/tasks/{taskId}/abnormals

提交后：

1. 异常持久化；
2. 返回异常编号；
3. 返回任务详情；
4. 后续 AI/maintenance 通过 MQ 异步处理。

客户端不能显示“AI 已诊断”直到后端真实诊断完成。

---

# 54. HarmonyOS 图片选择

使用系统 Photo Picker 能力选择巡检证据。

要求：

1. 最多图片数量由后端附件策略决定；
2. 展示缩略图；
3. 可删除尚未提交图片；
4. 上传中显示进度或明确加载状态；
5. 上传失败允许重试；
6. 不把大图永久编码成 base64 放入 task/abnormal JSON。

如果课程开发周期不足以做拍照 Camera Kit，可先实现系统相册选择。

拍照属于增强项。

---

# 55. HarmonyOS 设备详情

入口：

1. 巡检任务；
2. 工单；
3. 告警。

接口：

GET /api/device/devices/{id}

展示：

1. deviceCode；
2. deviceName；
3. model；
4. status；
5. riskLevel；
6. workshop；
7. productionLine；
8. installLocation；
9. manufacturer；
10. responsibleUser。

移动端不显示 Three.js。

可展示少量最新监测指标。

---

# 56. HarmonyOS 告警页

接口：

GET /api/maintenance/alarms

主要提供只读查看。

如果当前角色具有维护权限，可以进入告警详情后执行后端允许的 acknowledge。

列表：

1. alarmLevel；
2. deviceName；
3. alarmTitle；
4. occurTime；
5. status。

CRITICAL 优先排序或突出显示。

---

# 57. 我的工单

页面：

MyWorkOrderPage

接口：

GET /api/maintenance/work-orders

默认：

assigneeUserId=当前用户。

列表：

1. workOrderCode；
2. deviceName；
3. title；
4. priority；
5. status；
6. plannedStartTime。

Tab：

1. 待处理；
2. 处理中；
3. 待验收；
4. 已完成。

---

# 58. HarmonyOS 工单详情与处理

页面：

WorkOrderDetailPage / WorkOrderProcessPage

展示：

1. 工单；
2. 设备；
3. 缺陷来源；
4. AI 诊断摘要；
5. 流转状态。

维修人员允许：

1. start；
2. repair；
3. submit-acceptance。

repair 表单：

1. faultCause；
2. solution；
3. partsUsed；
4. downtimeMinutes；
5. maintenanceCost；
6. result。

partsUsed 第一版可以使用简单动态列表：

1. partName；
2. quantity；
3. remark。

不在移动端实现复杂库存系统。

---

# 59. HarmonyOS AI 诊断

AI 页面主要用于查看与现场辅助。

入口：

1. 异常；
2. 工单；
3. 设备；
4. 首页快捷入口。

显示：

1. riskLevel；
2. abnormalSummary；
3. possibleCauses；
4. investigationSteps；
5. maintenanceAdvice；
6. safetyNotice；
7. diagnosisStatus；
8. confirmationStatus。

高风险内容固定显示安全提示。

拥有确认权限时允许：

1. confirm；
2. reject。

移动端不执行任何物理设备控制。

---

# 60. HarmonyOS 通知

第一版通过 REST：

1. GET /api/auth/notifications；
2. GET unread-count；
3. PUT read；
4. PUT read-all。

进入首页、回到前台或用户主动刷新时更新。

是否实现 @ohos.net.webSocket 或当前 Network Kit WebSocket 作为增强项，在 M10 联调阶段决定。

项目的 WebSocket 技术要求已经由 PC 端完整体现，因此移动端不需要为了展示技术重复实现 原生 WebSocket 客户端。

---

# 61. HarmonyOS 个人中心

展示：

1. avatar；
2. username；
3. realName；
4. roles；
5. 当前 Gateway 地址，仅开发模式可见；
6. 退出登录。

第一版个人中心只读。

因为 02-backend.md 当前没有个人资料更新 API，客户端不得自行调用不存在的 update profile 接口。

---

# 62. HarmonyOS 错误与网络状态

必须处理：

1. 无网络；
2. 请求超时；
3. 401 会话过期；
4. 403 无权限；
5. 404 业务数据已删除；
6. 409 状态已变化；
7. 429 限流；
8. 503 服务不可用。

现场提交时：

如果请求失败：

1. 不显示成功；
2. 保留尚未提交的表单状态；
3. 提供重试。

第一版不实现完整离线同步数据库，避免扩大范围。

---

# 63. 附件上传与展示契约

G0 已将附件方案固定到 02-backend.md。

第一版不增加独立文件微服务。

## 63.1 巡检与异常图片

上传：

POST /api/inspection/attachments/images

请求：

multipart/form-data，字段名 file。

读取：

GET /api/inspection/attachments/{fileKey}

用途：

1. PHOTO 巡检项；
2. task item evidenceUrls；
3. abnormal evidenceUrls。

## 63.2 工单图片

上传：

POST /api/maintenance/attachments/images

读取：

GET /api/maintenance/attachments/{fileKey}

用途：

1. 工单处理证据；
2. work-order log attachments。

## 63.3 客户端处理规则

1. 只接受后端允许的 JPEG、PNG、WebP；
2. 单文件上限按后端 10 MiB；
3. 用户确认业务提交时再上传，减少未引用孤儿文件；
4. 上传响应保存 fileKey、url、contentType、size；
5. 业务请求只提交 url 数组；
6. 图片 GET 需要登录 Token，因此 PC 通过 Axios 获取 Blob 后创建 object URL，HarmonyOS 通过带 Token 的 HTTP 请求读取；
7. 页面销毁时释放浏览器 object URL；
8. 不把 base64 长期写入 Pinia、数据库或业务 JSON；
9. 上传失败必须保留本地待提交状态并允许重试；
10. 不把 Windows 本地物理路径展示给客户端。

---

# 64. 客户端权限矩阵

客户端权限以 01-database.md 与 02-backend.md 的固定权限编码为准。

## 64.1 SUPER_ADMIN

拥有全部权限，PC 显示全部菜单。

HarmonyOS 可以登录，但不提供完整系统管理页面。

## 64.2 ADMIN

拥有业务管理和系统管理权限，PC 可使用：

1. Dashboard；
2. 设备管理；
3. 巡检配置与处理；
4. 告警、缺陷、工单；
5. AI；
6. 用户、角色、权限管理。

## 64.3 INSPECTOR

基础权限：

- dashboard:view
- device:view
- inspection:view
- inspection:execute
- ai:view
- ai:diagnosis

PC 主要展示设备查看、巡检任务、巡检异常只读/本人相关功能、AI 和通知。

HarmonyOS 是主要工作端。

## 64.4 MAINTAINER

基础权限：

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

PC 和 HarmonyOS 均可处理维修主线。

前端权限只控制展示与交互，所有实际授权仍由后端 Sa-Token 校验。

---

# 65. 页面与 API 对照摘要

| 页面 | 主要 API 域 |
|---|---|
| 登录 | auth |
| Dashboard | device + inspection + maintenance |
| 三维场景 | device |
| 设备 | device |
| SOP | device |
| 模板 | inspection |
| 流程设计 | inspection |
| 计划 | inspection |
| 任务 | inspection |
| 异常 | inspection |
| 告警 | maintenance |
| 缺陷 | maintenance |
| 工单 | maintenance + ai |
| AI 诊断 | ai |
| AI 诊断 | ai |
| 用户/角色/权限 | auth |
| 通知 | auth |
| HarmonyOS 巡检 | inspection + device |
| HarmonyOS 工单 | maintenance + device + ai |

---

# 66. 前端性能要求

这些是设计目标，最终数值需用真实环境测试。

PC：

1. 首屏不打包大量 glTF 模型；
2. Three.js 页面按路由懒加载；
3. ECharts 按需加载；
4. Vue Flow 页面按路由懒加载；
5. 管理页分页查询；
6. 防止重复接口请求；
7. 页面卸载清理 timer、WebSocket listener 和 Three.js 资源。

HarmonyOS：

1. 列表分页；
2. 图片缩略图；
3. 页面退出取消不必要请求；
4. 不一次拉取完整监测历史；
5. AI 结果按需加载。

---

# 67. 可访问性与操作安全

PC：

1. 表单字段有 label；
2. 危险按钮有明确文字；
3. 图表旁提供数字摘要；
4. 不只依靠颜色表达 CRITICAL；
5. loading 不阻塞整个页面超过必要范围。

HarmonyOS：

1. 主要按钮符合触控尺寸；
2. 现场页避免过密表格；
3. 高风险提示采用文字 + 图标；
4. 提交前确认关键维修动作。

---

# 68. Mock 数据规则

允许 Mock 的阶段：

1. 后端接口尚未完成；
2. 单独开发视觉组件。

Mock 必须放在明确目录，例如：

src/mock

最终联调前：

1. 删除或关闭 Mock；
2. 页面切换到真实 Gateway；
3. 禁止根据环境偷偷使用随机结果；
4. 最终答辩演示数据来自真实数据库。

---

# 69. PC 测试范围

至少覆盖：

1. 登录成功；
2. 登录失败；
3. Token 过期；
4. 菜单权限；
5. CRUD 页面；
6. 分页筛选；
7. 状态操作；
8. Dashboard；
9. ECharts resize；
10. Three.js 加载与点击；
11. 模型加载失败 fallback；
12. Vue Flow 保存与回显；
13. WebSocket 到达；
14. WebSocket 重连；
15. AI 诊断加载；
16. AI 失败状态；
17. 工单状态按钮；
18. 1366×768；
19. 1920×1080。

---

# 70. HarmonyOS 测试范围

至少覆盖：

1. 登录；
2. Token 持久化；
3. 今日巡检；
4. 开始任务；
5. NUMBER 项；
6. BOOLEAN 项；
7. TEXT 项；
8. PHOTO 项在上传能力完成后；
9. 异常上报；
10. 完成任务；
11. 我的工单；
12. 开始维修；
13. 提交维修；
14. AI 诊断查看；
15. 通知；
16. 请求超时；
17. 会话过期；
18. 真机或模拟器访问 Windows Gateway。

---

# 71. PC 分阶段实施顺序

客户端代码不得一次生成全部页面。

## W1：基础工程

实现：

1. Vue 3 + Vite + TypeScript；
2. Element Plus；
3. Router；
4. Pinia；
5. persistedstate；
6. Axios；
7. Login；
8. Layout；
9. 权限路由；
10. Token。

验收：

可以通过 Gateway 登录并打开空 Dashboard。

## W2：设备域

实现：

1. 分类；
2. 设备；
3. 设备详情；
4. 指标；
5. SOP。

## W3：巡检域

实现：

1. 模板；
2. 模板项；
3. 计划；
4. 任务；
5. 异常。

## W4：维护域

实现：

1. 告警；
2. 缺陷；
3. 工单；
4. 工单详情。

## W5：Dashboard

实现 ECharts 驾驶舱。

## W6：Three.js

实现工业三维场景。

## W7：Vue Flow

实现巡检流程设计。

## W8：AI

实现诊断列表、手工诊断、详情、5 节点工作流轨迹和人工确认。

## W9：WebSocket

使用浏览器原生 WebSocket 实现通知中心与实时推送。

## W10：系统管理与整体优化

实现：

1. 用户；
2. 角色；
3. 权限；
4. 响应式；
5. 错误状态；
6. 联调修复。

---

# 72. HarmonyOS 分阶段实施顺序

HarmonyOS 在 PC 和后端核心链路稳定后开始。

## H1：工程与网络

1. ArkTS/ArkUI 工程；
2. HttpClient；
3. AuthStorage；
4. Login；
5. Home。

## H2：巡检

1. 今日巡检；
2. 任务详情；
3. 任务执行；
4. 异常上报。

## H3：设备与告警

1. 设备详情；
2. 告警。

## H4：维修

1. 我的工单；
2. 工单详情；
3. 维修处理。

## H5：AI 与通知

1. AI 诊断；
2. 通知；
3. 个人中心。

## H6：附件与真机联调

按第 64 章已固定的附件契约实现：

1. Photo Picker；
2. inspection 图片上传；
3. 异常图片；
4. maintenance 工单图片；
5. 带 Token 的图片读取；
6. 真机网络测试。

---

# 73. Codex 客户端开发规则

Codex 每次客户端任务必须：

1. 先读取 AGENTS.md；
2. 读取 03-client.md；
3. 读取与当前页面对应的 02-backend.md API；
4. 检查后端接口是否已经真实存在；
5. 只实现当前阶段；
6. 不自行新增后端 API；
7. 不自行修改后端状态枚举；
8. 不自行升级前端依赖；
9. 不用静态假数据代替最终功能；
10. 完成允许的 build/test；
11. commit；
12. push；
13. 停止。

若接口尚未实现：

允许先建立 API 函数和 TypeScript 类型。

页面要标记等待联调。

禁止为了让页面看起来能用而长期保留伪造成功逻辑。

---

# 74. 官方实现依据与参考原则

PC 技术选择依据：

1. Vue 3 组件化客户端；
2. Element Plus 官方定位为 Vue 3 UI Framework；
3. Vue Flow 官方支持 Vue 3、可拖拽节点、边、缩放和自定义节点；
4. Three.js 用于 WebGL 三维场景；
5. ECharts 用于驾驶舱图表。

HarmonyOS 技术选择依据：

1. 华为官方 ArkTS 作为 HarmonyOS 应用开发语言；
2. ArkUI 提供声明式 UI；
3. Network Kit 提供 HTTP 与 WebSocket 网络能力；
4. Media Library Kit 提供系统图片选择能力；
5. HarmonyOS 支持应用级与持久化状态能力。

参考实训项目的移动端采用 Pages、ViewModel、API、Model 分层，并复用后端 REST API。IIOP 沿用这一适合课程实训的分层思想，同时缩小移动端范围到工业现场核心流程。

---

# 75. G0 已收口的跨规范契约

客户端在 G0 后依赖以下固定契约：

1. 外部业务 ID 使用字符串；
2. PageResult.total 等普通数值保持 number；
3. 设备当前指标使用 GET /api/device/devices/{id}/metric-snapshot；
4. inspection 图片使用 /api/inspection/attachments/**；
5. maintenance 图片使用 /api/maintenance/attachments/**；
6. AI 诊断列表/详情使用 ai:view，发起诊断使用 ai:diagnosis，人工确认使用 ai:confirm；
7. Vue Flow 使用 inspection:template:manage；
8. 客户端不访问 /internal/**；
9. 工单中的 aiDiagnosisId 只作为 iiop-ai 公共详情 API 的引用。

如果真实后端实现必须改变上述契约，应先同步修改 02 和 03，再修改页面代码。

---

# 76. 当前客户端最终范围

PC 第一版最终必须完成：

1. 登录与权限；
2. 工业驾驶舱；
3. Three.js 三维设备场景；
4. 设备管理；
5. 实时监测；
6. SOP；
7. 巡检模板；
8. Vue Flow；
9. 巡检计划；
10. 巡检任务；
11. 巡检异常；
12. 告警；
13. 缺陷；
14. 维修工单；
15. AI 诊断；
17. WebSocket 通知；
18. 用户/角色/权限。

HarmonyOS 第一版最终必须完成：

1. 登录；
2. 首页；
3. 今日巡检；
4. 巡检任务执行；
5. 异常上报；
6. 设备详情；
7. 告警；
8. 我的工单；
9. 工单处理；
10. AI 诊断；
11. 通知；
12. 个人中心。

这两个客户端完成后，系统才具备“管理端 + 现场端 + 智能诊断”的完整展示能力。

未经明确确认，Codex 不得减少上述核心范围，也不得自行扩展到库存、采购、生产排程、IoT 协议网关等超出实训主线的系统。
