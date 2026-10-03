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

首次需在 DevEco Studio 的 Device Manager 创建并启动 Phone Emulator，并为 Debug 构建完成自动签名配置。

组员机器先确认：

1. PC 端 Gateway 已在宿主机 `8080` 启动；
2. Emulator 能访问 `http://10.0.2.2:8080`；
3. DevEco Studio 已安装对应 SDK、hvigor 与 hdc；
4. Debug 签名可生成可安装 HAP；
5. 真机调试时按实际局域网地址调整 `entry/src/main/ets/network/NetworkConfig.ets`，不要继续使用 Emulator 专用的 `10.0.2.2`。

仓库根目录的 `启动IIOP鸿蒙端.bat` 仍依赖原开发机的部分 DevEco / Emulator 绝对路径。原开发机可继续使用；组员机器路径不一致时，优先从 DevEco Studio 手工构建、安装和启动，或先按本机路径调整启动脚本。

脚本会检查 Gateway、构建签名 HAP、安装并启动应用；如果仅生成 unsigned HAP，会停止而不会尝试安装无效包。

完整团队环境步骤见根目录 `README.md` 的“组员首次运行”章节。
