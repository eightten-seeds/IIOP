import { InspectionTask } from '../../models/InspectionModels';
import { Device } from '../../models/CommonModels';
import { InspectionService } from '../../services/InspectionService';
import { DeviceService } from '../../services/DeviceService';
import { Tokens } from '../../theme/Tokens';
import { EmptyView, ErrorView, LoadingView } from '../../components/common/StateViews';
import { formatTime, statusText } from '../../utils/Display';

@Component
export struct TodayInspectionPage {
  onOpen: (id: string) => void = () => {};
  @State tasks: InspectionTask[] = [];
  @State loading: boolean = true;
  @State errorText: string = '';
  @State revision: number = 0;
  private devices: Map<string, Device> = new Map();

  aboutToAppear(): void { this.load(); }
  private device(id: string): Device | undefined { return this.devices.get(id); }

  async load(): Promise<void> {
    this.loading = true; this.errorText = '';
    try {
      const page = await InspectionService.tasks();
      const now = new Date();
      const localDate = now.getFullYear().toString() + '-' + (now.getMonth() + 1).toString().padStart(2, '0') + '-' + now.getDate().toString().padStart(2, '0');
      this.tasks = page.records.filter(task => task.taskStatus === 'IN_PROGRESS' || task.overdueFlag === 1 || (task.scheduledStartTime ?? '').startsWith(localDate));
      const ids: string[] = [];
      this.tasks.forEach(task => { if (!ids.includes(task.deviceId)) ids.push(task.deviceId); });
      await Promise.all(ids.map(async id => { try { this.devices.set(id, await DeviceService.detail(id)); } catch (error) {} }));
      this.revision++;
    } catch (error) { this.errorText = error instanceof Error ? error.message : '今日巡检加载失败'; }
    finally { this.loading = false; }
  }

  @Builder taskCard(task: InspectionTask) {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.device(task.deviceId)?.deviceName ?? '设备信息加载中').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Tokens.text).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.device(task.deviceId)?.deviceCode ?? '').fontSize(12).fontColor(Tokens.textSecondary)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(statusText(task.taskStatus)).fontSize(12).fontColor(task.taskStatus === 'COMPLETED' ? Tokens.success : Tokens.primary).padding({ left: 10, right: 10, top: 5, bottom: 5 }).backgroundColor(Tokens.elevated).borderRadius(12)
      }.width('100%')
      Text(this.device(task.deviceId)?.installLocation ?? '位置未填写').fontSize(14).fontColor(Tokens.textSecondary)
      Row() { Text('计划 ' + formatTime(task.scheduledStartTime)).fontSize(13).fontColor(Tokens.textSecondary); Blank(); Text(Math.round(task.completionRate) + '%').fontSize(14).fontColor(Tokens.primary) }.width('100%')
      Progress({ value: task.completionRate, total: 100 }).color(Tokens.primary).backgroundColor(Tokens.border).width('100%')
      if (task.overdueFlag === 1) { Text('任务已逾期，请优先处理').fontSize(13).fontColor(Tokens.warning) }
    }.alignItems(HorizontalAlign.Start).width('100%').padding(18).backgroundColor(Tokens.surface).borderRadius(Tokens.radius).onClick(() => this.onOpen(task.id))
  }

  build() {
    Column({ space: 14 }) {
      Row() { Column({ space: 3 }) { Text('今日巡检').fontSize(26).fontWeight(FontWeight.Bold).fontColor(Tokens.text); Text('仅显示分配给你的现场任务').fontSize(13).fontColor(Tokens.textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Button('刷新').backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.load()) }.width('100%')
      if (this.loading) { LoadingView({ message: '正在加载巡检任务' }) }
      else if (this.errorText.length > 0) { ErrorView({ message: this.errorText, onRetry: () => this.load() }) }
      else if (this.tasks.length === 0) { EmptyView({ message: '当前没有分配给你的巡检任务。' }) }
      else { List({ space: 12 }) { ForEach(this.tasks, (task: InspectionTask) => { ListItem() { this.taskCard(task) } }, (task: InspectionTask) => task.id) }.layoutWeight(1).width('100%') }
    }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
  }
}
