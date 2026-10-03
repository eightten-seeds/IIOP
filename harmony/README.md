# IIOP HarmonyOS

IIOP 原生 HarmonyOS 现场移动端，采用 Stage Model、ArkTS、ArkUI，并统一通过 Gateway `8080` 访问现有业务服务。

## 功能范围

- 登录、图形验证码、Asset Store Token 安全持久化与 `/me` 身份恢复
- INSPECTOR：今日巡检、检查项显式保存、异常上报、完成巡检、AI 结果查看
- MAINTAINER：我的工单、开始维修、维修结果、待验收、驳回返修、再次提交、AI 建议查看
- SUPER_ADMIN / ADMIN：轻量身份与岗位提示，不复制 PC 管理后台
- REST 通知、统一错误语义、弱网重试、Dirty Form 离开保护、关键写操作防重复

## 网络

唯一 Gateway 配置位于 `entry/src/main/ets/network/NetworkConfig.ets`。默认使用 Emulator 的宿主机别名 `10.0.2.2:8080`，没有任何业务服务直连地址。

## 安全

仓库不包含账号、密码、Token 或其他 Secret。自动化凭据只能通过本机环境变量注入；当前应用登录页仅接受人工输入。

## 首次运行

首次运行需要在组员自己的 DevEco Studio 环境中完成：

1. 安装项目所需 SDK；
2. 准备可用 Emulator 或真机；
3. 完成 Debug 构建与签名配置；
4. 确认设备能够访问当前电脑上运行的 Gateway；
5. 根据当前设备和网络环境检查 `entry/src/main/ets/network/NetworkConfig.ets` 中的 Gateway 地址；
6. 构建、安装并启动应用。

不同组员的 DevEco Studio 安装目录、SDK 目录、Emulator 实例目录和网络地址可能不同，文档不规定统一的本机绝对路径。

仓库根目录保留 HarmonyOS 启动脚本作为本地开发辅助工具。如果脚本与组员电脑环境不一致，优先使用 DevEco Studio 的标准构建、安装和调试流程，或仅在本机调整脚本配置。

应用只通过 Gateway 访问业务服务，不应直接连接各业务微服务。

完整团队环境说明见根目录 `README.md` 的“组员首次运行”章节。
