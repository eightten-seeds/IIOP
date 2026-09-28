# IIOP 客户端实现规范（最简版）

## 1. 总原则

PC 和 HarmonyOS 只做主业务和指定技术展示。

不追求完整企业后台。

客户端统一访问：

http://127.0.0.1:8080

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

依赖第一次可运行后锁版本，不随意升级。

## 3. PC 页面

第一版只做以下页面或功能区：

### 登录

- username
- password
- 登录
- 退出

### Dashboard

只展示：

- 设备数量
- 设备状态分布
- 巡检任务数量
- 工单数量
- 2 到 4 个 ECharts 图表

不做 BI 配置。

### 设备

- 设备列表
- 新增/编辑
- 设备详情
- 指标趋势
- SOP

### Three.js

只做一个页面：

- Scene
- Camera
- Light
- Grid
- OrbitControls
- 设备位置
- 状态/风险简单颜色
- 点击显示设备摘要
- 无模型时 Box fallback

不做数字孪生、动画系统或复杂模型管理。

### 巡检

可以合并为少量页面：

- 模板
- 计划
- 任务
- 异常

Vue Flow 只放在模板编辑：

- START
- CHECK_ITEM
- CONDITION
- REPORT_ABNORMAL
- END

只保存/读取 flow_definition JSON。

### 维修

用一个或少量页面完成：

- 告警
- 缺陷
- 工单
- 维修
- 验收

### AI

只做：

- 发起诊断
- 查看结果
- 查看 5 节点 trace
- confirm / reject

不做聊天界面。

### 系统

只保留：

- 用户
- 角色

权限表可以只读，不要求复杂权限树编辑 UI。

### 通知

- 通知列表
- 未读数量
- WebSocket 到达后刷新

## 4. PC 状态管理

Pinia 只保存：

- token
- currentUser
- permissions
- notification unread count

不要把所有业务数据塞进 Store。

## 5. WebSocket

PC 使用浏览器原生 WebSocket：

ws://127.0.0.1:8080/ws/notifications?token=...

只处理通知 JSON。

断线后简单定时重连即可。

## 6. HarmonyOS 技术栈

- ArkTS
- ArkUI
- HTTP REST

第一版不做 HarmonyOS WebSocket。

## 7. HarmonyOS 页面

只做：

1. Login
2. TodayInspection
3. TaskDetail
4. AbnormalReport
5. MyWorkOrders
6. WorkOrderDetail
7. AiResult

Home/Profile 如果需要可以合并为简单入口页，不单独扩展功能。

## 8. HarmonyOS 巡检

用户可以：

- 查看今日任务
- 开始任务
- 填 NUMBER / BOOLEAN / TEXT
- 提交异常
- 完成任务

PHOTO 第一版可以不作为阻塞项。

## 9. HarmonyOS 维修

用户可以：

- 查看工单
- 开始维修
- 填写维修结果
- 提交验收

## 10. AI 移动查看

只展示：

- 风险等级
- 原因
- 排查步骤
- 维修建议
- 是否需要人工确认

不做聊天。

## 11. 客户端 PASS

PC：

- npm build 通过
- 登录可用
- 设备/巡检/维修主链可用
- ECharts 可见
- Three.js 可交互
- Vue Flow 可保存回显
- WebSocket 可收到通知
- AI 可发起并查看

HarmonyOS：

- 可以登录
- 可以完成一条巡检
- 可以提交异常
- 可以处理一条工单
- 可以查看 AI 结果

达到以上即可，不扩展额外页面。
