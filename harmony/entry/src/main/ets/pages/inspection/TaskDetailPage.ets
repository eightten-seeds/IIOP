import { Device } from '../../models/CommonModels';
import { InspectionAbnormal, TaskDetail, TaskItem } from '../../models/InspectionModels';
import { DeviceService } from '../../services/DeviceService';
import { InspectionService } from '../../services/InspectionService';
import { Tokens } from '../../theme/Tokens';
import { ErrorView, LoadingView } from '../../components/common/StateViews';
import { formatTime, statusText } from '../../utils/Display';

@Component
export struct TaskDetailPage {
  taskId: string = '';
  onBack: () => void = () => {};
  onOpenAi: (id: string) => void = () => {};
  @State detail: TaskDetail | undefined = undefined;
  @State device: Device | undefined = undefined;
  @State loading: boolean = true;
  @State errorText: string = '';
  @State busy: string = '';
  @State reportVisible: boolean = false;
  @State reportSeverity: string = 'MEDIUM';
  @State reportItemId: string = '';
  @State reportDescription: string = '';
  @State revision: number = 0;
  private drafts: Map<string, string> = new Map();
  private remarks: Map<string, string> = new Map();
  private results: Map<string, string> = new Map();
  private dirty: Set<string> = new Set();

  aboutToAppear(): void { this.load(); }

  async load(): Promise<void> {
    this.loading = true; this.errorText = '';
    try {
      const value = await InspectionService.detail(this.taskId);
      this.detail = value; this.device = await DeviceService.detail(value.task.deviceId);
      value.items.forEach(item => { this.drafts.set(item.id, item.actualValue ?? ''); this.remarks.set(item.id, item.remark ?? ''); this.results.set(item.id, item.resultStatus === 'PENDING' ? 'NORMAL' : item.resultStatus); });
      this.dirty.clear(); this.revision++;
    } catch (error) { this.errorText = error instanceof Error ? error.message : '任务详情加载失败'; }
    finally { this.loading = false; }
  }

  private setValue(item: TaskItem, value: string): void {
    this.drafts.set(item.id, value); this.dirty.add(item.id);
    if (item.itemType === 'NUMBER') {
      const n = Number(value); const abnormal = (!Number.isNaN(n) && ((item.lowerLimit !== undefined && n < item.lowerLimit) || (item.upperLimit !== undefined && n > item.upperLimit)));
      this.results.set(item.id, abnormal ? 'ABNORMAL' : 'NORMAL');
    } else if (item.itemType === 'TEXT') this.results.set(item.id, 'NORMAL');
    this.revision++;
  }

  private setBoolean(item: TaskItem, abnormal: boolean): void { this.drafts.set(item.id, abnormal ? 'false' : 'true'); this.results.set(item.id, abnormal ? 'ABNORMAL' : 'NORMAL'); this.dirty.add(item.id); this.revision++; }

  async saveItem(item: TaskItem): Promise<void> {
    if (this.busy.length > 0) return;
    const value = this.drafts.get(item.id) ?? '';
    if (item.requiredFlag === 1 && value.trim().length === 0) { this.getUIContext().getPromptAction().showToast({ message: '请先填写检查结果' }); return; }
    this.busy = 'item-' + item.id;
    try {
      await InspectionService.saveItem(this.taskId, item.id, { actualValue: value, resultStatus: this.results.get(item.id) ?? 'NORMAL', remark: this.remarks.get(item.id) ?? '' });
      this.dirty.delete(item.id); this.getUIContext().getPromptAction().showToast({ message: '检查项已保存' }); await this.load();
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '保存失败' }); }
    finally { this.busy = ''; }
  }

  async start(): Promise<void> { if (this.busy.length > 0) return; this.busy = 'start'; try { await InspectionService.start(this.taskId); this.getUIContext().getPromptAction().showToast({ message: '巡检已开始' }); await this.load(); } catch (error) { this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '开始失败' }); } finally { this.busy = ''; } }

  confirmComplete(): void {
    if (this.dirty.size > 0) { this.getUIContext().getPromptAction().showToast({ message: '仍有未保存的检查项' }); return; }
    this.getUIContext().getPromptAction().showDialog({ title: '完成巡检', message: '确认所有必填检查项已经完成并提交？', buttons: [{ text: '取消', color: '#9FB0C1' }, { text: '确认完成', color: '#55B6D9' }] }).then(result => { if (result.index === 1) this.complete(); });
  }
  async complete(): Promise<void> { this.busy = 'complete'; try { await InspectionService.complete(this.taskId); this.getUIContext().getPromptAction().showToast({ message: '巡检已完成' }); await this.load(); } catch (error) { this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '完成失败' }); } finally { this.busy = ''; } }

  async submitReport(): Promise<void> {
    if (this.reportDescription.trim().length === 0 || this.busy.length > 0) { this.getUIContext().getPromptAction().showToast({ message: '请填写异常描述' }); return; }
    this.busy = 'report';
    const linked = this.detail?.items.find(item => item.id === this.reportItemId);
    try {
      await InspectionService.report({ taskId: this.taskId, taskItemId: this.reportItemId.length > 0 ? this.reportItemId : undefined, severity: this.reportSeverity, title: (linked?.itemName ?? this.device?.deviceName ?? '现场巡检') + '异常', description: this.reportDescription.trim() });
      this.reportVisible = false; this.reportDescription = ''; this.getUIContext().getPromptAction().showToast({ message: '巡检异常已上报' }); await this.load();
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '异常上报失败' }); }
    finally { this.busy = ''; }
  }

  requestBack(): void { if (this.dirty.size === 0 && this.reportDescription.length === 0) this.onBack(); else this.getUIContext().getPromptAction().showDialog({ title: '尚未保存', message: '当前填写内容尚未保存，确定离开吗？', buttons: [{ text: '继续填写', color: '#9FB0C1' }, { text: '离开', color: '#EF6B73' }] }).then(result => { if (result.index === 1) this.onBack(); }); }

  private reportOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '不关联具体检查项' }];
    this.detail?.items.forEach(item => options.push({ value: item.itemName }));
    return options;
  }

  private reportSelectedIndex(): number {
    if (this.reportItemId.length === 0) return 0;
    const index = this.detail?.items.findIndex(item => item.id === this.reportItemId) ?? -1;
    return index < 0 ? 0 : index + 1;
  }

  @Builder itemCard(item: TaskItem) {
    Column({ space: 10 }) {
      Row() { Text(item.itemName).fontSize(17).fontWeight(FontWeight.Medium).fontColor(Tokens.text).layoutWeight(1); Text(item.requiredFlag === 1 ? '必填' : '选填').fontSize(12).fontColor(item.requiredFlag === 1 ? Tokens.warning : Tokens.textSecondary) }.width('100%')
      if (item.inspectionMethod !== undefined) { Text(item.inspectionMethod).fontSize(13).fontColor(Tokens.textSecondary) }
      if (item.itemType === 'NUMBER') {
        Text('标准 ' + (item.standardValue ?? '—') + ' · 范围 ' + (item.lowerLimit ?? '—') + ' ~ ' + (item.upperLimit ?? '—') + ' ' + (item.unit ?? '')).fontSize(13).fontColor(Tokens.textSecondary)
        TextInput({ text: this.drafts.get(item.id) ?? '', placeholder: '请输入测量值' }).type(InputType.Number).height(48).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => this.setValue(item, value))
      } else if (item.itemType === 'BOOLEAN') {
        Row({ space: 10 }) { Button('正常').layoutWeight(1).height(46).backgroundColor(this.results.get(item.id) === 'NORMAL' ? Tokens.success : Tokens.elevated).onClick(() => this.setBoolean(item, false)); Button('异常').layoutWeight(1).height(46).backgroundColor(this.results.get(item.id) === 'ABNORMAL' ? Tokens.danger : Tokens.elevated).onClick(() => this.setBoolean(item, true)) }.width('100%')
      } else if (item.itemType === 'TEXT') {
        TextArea({ text: this.drafts.get(item.id) ?? '', placeholder: '请输入现场检查结果' }).height(90).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => this.setValue(item, value))
      } else {
        Text('当前版本暂不支持图片检查项，请联系管理员调整巡检模板。').fontColor(Tokens.warning).fontSize(14)
      }
      if (item.itemType !== 'PHOTO') {
        Row() { Text(statusText(this.results.get(item.id) ?? item.resultStatus)).fontColor((this.results.get(item.id) ?? item.resultStatus) === 'ABNORMAL' ? Tokens.danger : Tokens.success); Blank(); Button(this.busy === 'item-' + item.id ? '保存中' : '保存检查项').height(42).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0 && this.detail?.task.taskStatus === 'IN_PROGRESS').onClick(() => this.saveItem(item)) }.width('100%')
      }
    }.alignItems(HorizontalAlign.Start).padding(16).width('100%').backgroundColor(Tokens.surface).borderRadius(Tokens.radius)
  }

  @Builder reportPanel() {
    Column({ space: 12 }) {
      Text('上报巡检异常').fontSize(21).fontWeight(FontWeight.Bold).fontColor(Tokens.text).width('100%')
      Text('严重程度').fontColor(Tokens.textSecondary).width('100%')
      Row({ space: 8 }) { ForEach(['LOW','MEDIUM','HIGH','CRITICAL'], (level: string) => { Button(statusText(level)).height(40).layoutWeight(1).fontSize(12).backgroundColor(this.reportSeverity === level ? Tokens.warning : Tokens.elevated).onClick(() => this.reportSeverity = level) }) }.width('100%')
      Text('关联检查项（可选）').fontColor(Tokens.textSecondary).width('100%')
      Select(this.reportOptions()).selected(this.reportSelectedIndex()).onSelect(index => { this.reportItemId = index === 0 ? '' : (this.detail?.items[index - 1].id ?? ''); })
      TextArea({ text: this.reportDescription, placeholder: '请描述现场异常现象' }).height(110).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => this.reportDescription = value)
      Row({ space: 10 }) { Button('取消').layoutWeight(1).height(48).backgroundColor(Tokens.elevated).onClick(() => this.reportVisible = false); Button(this.busy === 'report' ? '提交中' : '确认上报').layoutWeight(1).height(48).backgroundColor(Tokens.danger).enabled(this.busy.length === 0).onClick(() => this.submitReport()) }.width('100%')
    }.padding(20).width('92%').backgroundColor('#19283A').borderRadius(18)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 12 }) {
        Row() { Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(Tokens.primary).onClick(() => this.requestBack()); Blank(); Button('刷新').backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.load()) }.width('100%')
        if (this.loading) { LoadingView({ message: '正在加载任务详情' }) }
        else if (this.errorText.length > 0 || this.detail === undefined) { ErrorView({ message: this.errorText, onRetry: () => this.load() }) }
        else {
          List({ space: 12 }) {
            ListItem() { Column({ space: 8 }) { Text(this.device?.deviceName ?? '设备').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Tokens.text); Text((this.device?.deviceCode ?? '') + ' · ' + (this.device?.installLocation ?? '位置未填写')).fontColor(Tokens.textSecondary); Row() { Text(statusText(this.detail?.task.taskStatus ?? '')).fontColor(Tokens.primary); Blank(); Text(Math.round(this.detail?.task.completionRate ?? 0) + '%').fontColor(Tokens.primary) }; Progress({ value: this.detail?.task.completionRate ?? 0, total: 100 }).color(Tokens.primary).backgroundColor(Tokens.border) }.alignItems(HorizontalAlign.Start).padding(18).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) }
            ForEach(this.detail.items, (item: TaskItem) => { ListItem() { this.itemCard(item) } }, (item: TaskItem) => item.id)
            if (this.detail.abnormals.length > 0) { ListItem() { Text('已上报异常').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Tokens.text).padding({ top: 8 }) } }
            ForEach(this.detail.abnormals, (abnormal: InspectionAbnormal) => { ListItem() { Column({ space: 7 }) { Text(abnormal.title).fontColor(Tokens.text).fontWeight(FontWeight.Medium); Text(statusText(abnormal.severity) + ' · ' + formatTime(abnormal.reportedAt)).fontColor(Tokens.warning).fontSize(13); if (abnormal.aiDiagnosisId !== undefined) { Button('查看 AI 诊断').height(40).backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.onOpenAi(abnormal.aiDiagnosisId ?? '')) } else { Text('AI 诊断尚未关联').fontColor(Tokens.textSecondary).fontSize(13) } }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) } }, (abnormal: InspectionAbnormal) => abnormal.id)
            ListItem() { Row() {}.height(84) }
          }.layoutWeight(1).width('100%')
          Row({ space: 10 }) {
            if (this.detail.task.taskStatus === 'PENDING') { Button(this.busy === 'start' ? '启动中' : '开始巡检').layoutWeight(1).height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.start()) }
            else if (this.detail.task.taskStatus === 'IN_PROGRESS') { Button('上报异常').layoutWeight(1).height(52).backgroundColor(Tokens.warning).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.reportVisible = true); Button(this.busy === 'complete' ? '提交中' : '完成巡检').layoutWeight(1).height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.confirmComplete()) }
            else { Button('巡检已完成').layoutWeight(1).height(52).backgroundColor(Tokens.elevated).fontColor(Tokens.success).enabled(false) }
          }.width('100%').padding({ top: 10 }).backgroundColor(Tokens.background)
        }
      }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
      if (this.reportVisible) { Stack() { this.reportPanel() }.width('100%').height('100%').backgroundColor('#99000000').alignContent(Alignment.Center) }
    }.width('100%').height('100%')
  }
}
