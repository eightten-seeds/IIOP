import { Device } from '../../models/CommonModels';
import { WorkOrder } from '../../models/MaintenanceModels';
import { DeviceService } from '../../services/DeviceService';
import { MaintenanceService } from '../../services/MaintenanceService';
import { EmptyView, ErrorView, LoadingView } from '../../components/common/StateViews';
import { Tokens } from '../../theme/Tokens';
import { formatTime, statusText } from '../../utils/Display';

@Component
export struct MyWorkOrdersPage {
  onOpen: (id: string) => void = () => {};
  @State orders: WorkOrder[] = [];
  @State loading: boolean = true;
  @State errorText: string = '';
  @State revision: number = 0;
  private devices: Map<string, Device> = new Map();
  aboutToAppear(): void { this.load(); }

  async load(): Promise<void> {
    this.loading = true; this.errorText = '';
    try {
      const page = await MaintenanceService.orders(); this.orders = page.records;
      const ids: string[] = [];
      this.orders.forEach(order => { if (!ids.includes(order.deviceId)) ids.push(order.deviceId); });
      await Promise.all(ids.map(async id => { try { this.devices.set(id, await DeviceService.detail(id)); } catch (error) {} })); this.revision++;
    } catch (error) { this.errorText = error instanceof Error ? error.message : '工单加载失败'; }
    finally { this.loading = false; }
  }

  @Builder orderCard(order: WorkOrder) {
    Column({ space: 9 }) {
      Row() { Text(this.devices.get(order.deviceId)?.deviceName ?? '设备信息加载中').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Tokens.text).maxLines(2).layoutWeight(1); Text(statusText(order.status)).fontSize(12).fontColor(order.status === 'COMPLETED' ? Tokens.success : order.status === 'PROCESSING' ? Tokens.warning : Tokens.primary).padding({ left: 9, right: 9, top: 5, bottom: 5 }).backgroundColor(Tokens.elevated).borderRadius(12) }.width('100%')
      Text(order.title).fontSize(15).fontColor(Tokens.text).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text((this.devices.get(order.deviceId)?.installLocation ?? '位置未填写') + ' · ' + order.workOrderCode).fontSize(13).fontColor(Tokens.textSecondary)
      Row() { Text('优先级 ' + statusText(order.priority)).fontColor(order.priority === 'HIGH' || order.priority === 'CRITICAL' ? Tokens.danger : Tokens.warning).fontSize(13); Blank(); Text(formatTime(order.updatedAt)).fontColor(Tokens.textSecondary).fontSize(12) }.width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%').padding(18).backgroundColor(Tokens.surface).borderRadius(Tokens.radius).onClick(() => this.onOpen(order.id))
  }

  build() {
    Column({ space: 14 }) {
      Row() { Column({ space: 3 }) { Text('我的维修工单').fontSize(26).fontWeight(FontWeight.Bold).fontColor(Tokens.text); Text('待开工 · 维修中 · 返修 · 待验收').fontSize(13).fontColor(Tokens.textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Button('刷新').backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.load()) }.width('100%')
      if (this.loading) { LoadingView({ message: '正在加载维修工单' }) }
      else if (this.errorText.length > 0) { ErrorView({ message: this.errorText, onRetry: () => this.load() }) }
      else if (this.orders.length === 0) { EmptyView({ message: '当前没有分配给你的维修工单。' }) }
      else { List({ space: 12 }) { ForEach(this.orders, (order: WorkOrder) => { ListItem() { this.orderCard(order) } }, (order: WorkOrder) => order.id) }.layoutWeight(1).width('100%') }
    }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
  }
}
