import { NotificationItem } from '../../models/CommonModels';
import { AuthService } from '../../services/AuthService';
import { NotificationService } from '../../services/NotificationService';
import { SessionStore } from '../../stores/SessionStore';
import { Tokens } from '../../theme/Tokens';
import { EmptyView, ErrorView, LoadingView } from '../../components/common/StateViews';
import { formatTime } from '../../utils/Display';

@Component
export struct ProfilePage {
  onLoggedOut: () => void = () => {};
  onOpenBusiness: (bizType: string, bizId: string) => void = () => {};
  @State notifications: NotificationItem[] = [];
  @State loading: boolean = true;
  @State errorText: string = '';
  aboutToAppear(): void { this.load(); }
  async load(): Promise<void> { this.loading = true; this.errorText = ''; try { this.notifications = (await NotificationService.list()).records; } catch (error) { this.errorText = error instanceof Error ? error.message : '通知加载失败'; } finally { this.loading = false; } }
  async logout(): Promise<void> { await AuthService.logout(); this.onLoggedOut(); }
  async openNotification(item: NotificationItem): Promise<void> {
    if (item.readStatus === 'UNREAD') {
      try {
        await NotificationService.read(item.id);
        item.readStatus = 'READ';
        this.notifications = [...this.notifications];
      } catch (error) {
        this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '标记已读失败' });
        return;
      }
    }
    if (item.bizType !== undefined && item.bizId !== undefined) this.onOpenBusiness(item.bizType, item.bizId);
  }
  build() {
    Column({ space: 14 }) {
      Text('我的').fontSize(26).fontWeight(FontWeight.Bold).fontColor(Tokens.text).width('100%')
      Column({ space: 6 }) { Text(SessionStore.user?.realName ?? SessionStore.user?.username ?? '').fontSize(21).fontColor(Tokens.text); Text(SessionStore.roles.join(' / ')).fontColor(Tokens.primary) }.alignItems(HorizontalAlign.Start).padding(18).width('100%').backgroundColor(Tokens.surface).borderRadius(Tokens.radius)
      Row() { Text('通知' + (this.notifications.filter(i => i.readStatus === 'UNREAD').length > 0 ? (' (' + this.notifications.filter(i => i.readStatus === 'UNREAD').length + ' 未读)') : '')).fontSize(19).fontWeight(FontWeight.Medium).fontColor(Tokens.text); Blank(); Button('刷新').backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.load()) }.width('100%')
      if (this.loading) { LoadingView({ message: '正在加载通知' }) }
      else if (this.errorText.length > 0) { ErrorView({ message: this.errorText, onRetry: () => this.load() }) }
      else if (this.notifications.length === 0) { EmptyView({ message: '暂无通知' }) }
      else { List({ space: 8 }) { ForEach(this.notifications, (item: NotificationItem) => { ListItem() { Column({ space: 5 }) { Row() { Text(item.title).fontColor(Tokens.text).fontWeight(FontWeight.Medium).layoutWeight(1); if (item.readStatus === 'UNREAD') { Text('未读').fontSize(11).fontColor(Tokens.primary) } }; Text(item.content).fontColor(Tokens.textSecondary).fontSize(13).maxLines(3); Text(formatTime(item.createdAt)).fontColor(Tokens.textSecondary).fontSize(12) }.alignItems(HorizontalAlign.Start).padding(14).backgroundColor(Tokens.surface).borderRadius(10).onClick(() => this.openNotification(item)) } }, (item: NotificationItem) => item.id) }.layoutWeight(1).width('100%') }
      Button('退出当前账号').width('100%').height(48).backgroundColor(Tokens.elevated).fontColor(Tokens.danger).onClick(() => this.logout())
    }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
  }
}
