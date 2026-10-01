# IIOP 最简实施路线

> 原则：阶段少、任务大一些、每阶段真实验收，不做生产级复杂度。

## 1. 总路线

整个项目只保留 6 个阶段：

S1 基础设施  
→ S2 后端  
→ S3 AI  
→ S4 PC Web  
→ S5 HarmonyOS  
→ S6 联调、演示、冻结和答辩材料

当前：

- S1：PASS
- S2：PASS
- S3：PASS
- S4：进行中
- S5：未开始
- S6：未开始

## 2. S1 基础设施

状态：PASS。

已确认：

- MySQL
- 25 张业务表
- Redis
- Nacos
- RocketMQ
- Sentinel

不再返工。

## 3. S2 后端

### S2-A common + auth + gateway

状态：PASS。

已完成：

- common
- auth
- gateway
- Sa-Token
- Redis Session + 验证码（120s TTL 一次性校验，防刷限流）
- Nacos 注册
- Gateway 路由与基础限流
- 基础 RBAC 与 4 角色 x 33 权限只读模型
- 完整账号生命周期：无公开注册（管理员建号）、统一 8~72 位密码规则、登录图形验证码（captchaId/image 120s TTL）、401 统一失败语义防探测、个人修改密码、管理员重置密码（自锁与超级管理员保护）、全端强制下线机制

当前规则：

- 不要求 Same-Token 全局保护
- 不要求完整 Nacos Config 搬迁
- 不因为生产级治理能力返工
- 系统无公开注册，全部由管理员创建/分配
- 角色权限矩阵运行时冻结，UI 仅支持只读查看，禁止动态改写矩阵

### S2-B 业务后端 + 最小中间件闭环

状态：PASS。

已完成：

device：

- 分类
- 设备
- 指标
- SOP
- 简单统计

inspection：

- 模板
- 计划
- 人工生成任务
- 执行任务
- 异常

maintenance：

- 告警
- 缺陷
- 工单
- 维修
- 验收

中间件：

- inspection abnormal -> RocketMQ -> maintenance defect
- auth 原生 WebSocket 通知
- Gateway 一个 Sentinel 限流规则

## 4. S3 AI

状态：PASS。

已完成：

- 2 张 AI 表对应 Entity/Mapper
- Feign 读取上下文
- DeepSeek
- LangChain4j
- LangGraph4j 5 节点
- 同步 POST diagnosis
- 结果与 workflow trace
- confirm/reject
- 真实 DeepSeek 联调
- HIGH/CRITICAL 风险兜底
- 受控失败持久化
- JSON 字段真实类型验证

不做：

- TaskExecutor
- AI MQ
- Worker
- RAG
- Chat
- Tool Calling

S3 最终运行修复基线：

586246ec3966d8139fdc32699c574e61bb6ef1e0

## 5. S4 PC Web

状态：进行中。

S4 仍算一个阶段。S4-A 内部设置三个质量 Gate，S4-B 完成指定可视化技术和视觉强化。

### S4-A PC Core

Gate 1 通过后，Gate 2 开发前必须先冻结并遵守 `docs/spec/06-role-usecases.md`。Gate 2 先补角色数据范围、状态约束和最小关联 API，再开发业务化页面，禁止先画页面后补业务规则。

完成：

- Vue 3 / Vite / TypeScript 基础
- Vue Router
- Axios
- Pinia
- Element Plus
- 登录/退出
- 路由守卫
- RBAC
- AdminLayout
- Sidebar / Header / Breadcrumb
- Dashboard 基础数据
- 设备页面
- 巡检页面
- 维修页面
- AI 页面
- 用户/角色
- 通知
- 列表/详情
- 真实 API
- 跨模块业务跳转

核心业务必须使用独立 URL，不允许把全部功能放进一个 Dashboard。

S4-A 内部验收：

Gate 1：PASS WITH NOTES（提交 d387e463de6b598088ffd31a3c548c1284e552fd）
- Auth / roles / permissions
- 四角色默认落地
- Router Guard / 403
- RBAC 菜单与关键按钮
- AdminLayout / Breadcrumb
- 中文化与公共交互反馈

Gate 2：
- 业务专用页面
- 状态驱动操作
- 用户角色分配，ADMIN 不得授予或移除 SUPER_ADMIN
- 角色/权限矩阵只读展示；冻结权限基线不在第一版 UI 或公开业务 API 动态修改
- INSPECTOR/MAINTAINER 本人数据范围与直接详情校验
- 工单分派/维修/验收职责分离与多角色自验收保护
- 核心状态转换使用条件更新并在冲突时返回 409
- Defect ↔ AI 显式关联与 AI 草案创建工单后端校验
- 真实关联导航
- 写操作反馈闭环

Gate 3：
- SUPER_ADMIN / ADMIN / INSPECTOR / MAINTAINER 四角色真实运行
- 完整业务主链
- 详情刷新与浏览器前进后退
- 最终 build 与 Secret 检查

每个 Gate Codex push 后都由 ChatGPT 独立检查 GitHub；前一 Gate 未 PASS 不进入下一 Gate。

角色、数据范围、状态机和职责交接以 docs/spec/06-role-usecases.md 为准；页面技术与交互实现细节同时遵守 docs/spec/03-client.md。

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
- 对 S4-A 已实现的 loading / empty / error / success feedback 做视觉统一

S4-B 不扩张业务范围。

验收：

- npm build
- 独立业务路由可访问和刷新
- 真实 API
- 设备/巡检/维修/AI 主链可用
- ECharts 可见
- Three.js 可交互并绑定真实设备
- Vue Flow 可保存回显真实 flow_definition
- WebSocket 可收到通知
- ECharts 使用真实业务统计数据
- Three.js 使用真实设备坐标/状态/风险
- Vue Flow 保存并回显真实 flow_definition
- 关键页面具有答辩演示级视觉完成度

## 6. S5 HarmonyOS

S5 必须真实使用 HarmonyOS + ArkTS + ArkUI，并通过 HTTP REST 访问 Gateway。

一轮完成核心移动流程：

- 登录
- 今日巡检
- 巡检执行
- 异常上报
- 我的工单
- 工单处理至 WAITING_ACCEPTANCE
- AI 结果

不做：

- 系统管理
- Three.js
- Vue Flow
- WebSocket
- 复杂 Dashboard

验收：

- 能登录
- 能完成巡检
- 能上报异常
- 能处理工单并提交维修结果至待验收状态
- 能查看 AI

## 7. S6 联调、演示、冻结和答辩

### 代码验收

只跑一条完整主链：

登录  
→ 设备  
→ 巡检任务  
→ 异常  
→ RocketMQ  
→ 缺陷  
→ AI 诊断  
→ 人工确认  
→ 工单  
→ 维修  
→ 验收  
→ PC/HarmonyOS 查看

额外测试：

- DeepSeek 失败
- MQ 重复消息
- WebSocket 断线

然后：

- 修阻塞 Bug
- backend build
- web build
- HarmonyOS build
- Secret 检查
- Git 工作区干净
- 创建最终 tag

### 演示数据

只准备 1 条完整演示链，例如 CNC 主轴温度异常。

### 最终材料

代码冻结后生成：

1. 团队项目实训报告
2. 个人实训报告
3. 答辩 PPT
4. 答辩讲稿

材料必须基于真实代码、截图、测试和 Git 历史。

## 8. Codex 执行规则

每轮：

1. 读 AGENTS.md
2. 读当前相关 spec
3. 只做当前阶段
4. 自动处理普通编译/配置错误
5. 服务启动慢时有限等待重试
6. build/test
7. git diff --check
8. Secret 检查
9. commit + push
10. 停止

Codex 不得自行进入下一阶段。

## 9. 阶段审查

每个阶段 Codex push 后，由 ChatGPT 独立检查 GitHub 实际代码。

结论只有：

- PASS
- PASS WITH NOTES
- FAIL

只有真正影响主业务、固定技术栈、数据正确性、安全基本要求的问题才判 FAIL。

可选增强项缺失不判 FAIL。

## 10. 当前阶段

S1：PASS  
S2-A：PASS  
S2-B：PASS  
S3：PASS  
S4-A：当前阶段

当前：

**S4-A PACK 2 已完成。Defect、WorkOrder、AI 已使用专用业务页面，真实链路已通过 Gateway、MySQL、Redis、RocketMQ 与 DeepSeek 跑通：巡检异常 → 缺陷 → AI 五节点诊断与人工确认 → 显式绑定 → 工单分派/维修/验收 → 缺陷关闭。下一步等待独立验收，不提前进入 PACK 3。**
