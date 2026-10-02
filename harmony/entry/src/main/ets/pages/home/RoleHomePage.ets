import { SessionStore } from '../../stores/SessionStore';
import { Tokens } from '../../theme/Tokens';

@Component
export struct RoleHomePage {
  onLogout: () => void = () => {};
  build() {
    Column({ space: 18 }) {
      Text('IIOP').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Tokens.primary).width('100%')
      Column({ space: 10 }) {
        Text(SessionStore.user?.realName ?? SessionStore.user?.username ?? '当前用户').fontSize(22).fontColor(Tokens.text).fontWeight(FontWeight.Medium)
        Text(SessionStore.roles.join(' / ')).fontColor(Tokens.info).fontSize(14)
      }.alignItems(HorizontalAlign.Start).width('100%').padding(20).backgroundColor(Tokens.surface).borderRadius(Tokens.radius)
      Column({ space: 10 }) {
        Text('移动端岗位提示').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Tokens.text)
        Text('当前岗位主要通过 PC 管理端完成业务管理。移动端保留身份识别、通知与必要只读信息。').fontSize(15).lineHeight(23).fontColor(Tokens.textSecondary)
      }.alignItems(HorizontalAlign.Start).width('100%').padding(20).backgroundColor(Tokens.surface).borderRadius(Tokens.radius)
      Blank()
      Button('退出当前账号').width('100%').height(Tokens.touchHeight).backgroundColor(Tokens.elevated).fontColor(Tokens.danger).onClick(this.onLogout)
    }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
  }
}
