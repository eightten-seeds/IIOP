import { Device } from '../../models/CommonModels';
import { Acceptance, Defect, MaintenanceRecord, WorkOrderDetail } from '../../models/MaintenanceModels';
import { DeviceService } from '../../services/DeviceService';
import { MaintenanceService } from '../../services/MaintenanceService';
import { ErrorView, LoadingView } from '../../components/common/StateViews';
import { Tokens } from '../../theme/Tokens';
import { formatTime, statusText } from '../../utils/Display';

@Component
export struct WorkOrderDetailPage {
  orderId: string = '';
  onBack: () => void = () => {};
  onOpenAi: (id: string) => void = () => {};
  @State detail: WorkOrderDetail | undefined = undefined;
  @State device: Device | undefined = undefined;
  @State defect: Defect | undefined = undefined;
  @State loading: boolean = true;
  @State errorText: string = '';
  @State busy: string = '';
  @State formVisible: boolean = false;
  @State faultCause: string = '';
  @State solution: string = '';
  @State partsUsed: string = '';
  @State downtime: string = '';
  @State cost: string = '';
  @State repairResult: string = 'SUCCESS';
  @State comment: string = '';
  @State dirty: boolean = false;

  aboutToAppear(): void { this.load(); }
  private rejected(): Acceptance | undefined { const values = this.detail?.acceptances ?? []; return [...values].reverse().find(item => item.acceptanceResult === 'REJECTED'); }

  async load(): Promise<void> {
    this.loading = true; this.errorText = '';
    try {
      const value = await MaintenanceService.detail(this.orderId); this.detail = value;
      this.device = await DeviceService.detail(value.workOrder.deviceId);
      this.defect = value.workOrder.defectId !== undefined ? await MaintenanceService.defect(value.workOrder.defectId) : undefined;
    } catch (error) { this.errorText = error instanceof Error ? error.message : '工单详情加载失败'; }
    finally { this.loading = false; }
  }

  async start(): Promise<void> {
    if (this.busy.length > 0) return; this.busy = 'start';
    try { await MaintenanceService.start(this.orderId, '移动端现场开工'); this.getUIContext().getPromptAction().showToast({ message: '维修已开始' }); await this.load(); }
    catch (error) { this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '开始维修失败' }); }
    finally { this.busy = ''; }
  }

  openForm(): void {
    const last = this.detail?.records.length ? this.detail.records[this.detail.records.length - 1] : undefined;
    this.faultCause = last?.faultCause ?? ''; this.solution = last?.solution ?? ''; this.partsUsed = last?.partsUsed ?? ''; this.downtime = last?.downtimeMinutes?.toString() ?? ''; this.cost = last?.maintenanceCost?.toString() ?? ''; this.repairResult = last?.result ?? 'SUCCESS'; this.comment = ''; this.dirty = false; this.formVisible = true;
  }
  markDirty(): void { this.dirty = true; }

  closeForm(): void { if (!this.dirty) this.formVisible = false; else this.getUIContext().getPromptAction().showDialog({ title: '尚未提交', message: '当前填写内容尚未保存，确定离开吗？', buttons: [{ text: '继续填写', color: '#9FB0C1' }, { text: '离开', color: '#EF6B73' }] }).then(result => { if (result.index === 1) { this.formVisible = false; this.dirty = false; } }); }

  async submitRepair(): Promise<void> {
    if (this.solution.trim().length === 0) { this.getUIContext().getPromptAction().showToast({ message: '请填写维修方案' }); return; }
    if (this.busy.length > 0) return;
    this.busy = 'repair';
    try {
      await MaintenanceService.submitRepair(this.orderId, { faultCause: this.faultCause.trim(), solution: this.solution.trim(), partsUsed: this.partsUsed.trim(), downtimeMinutes: this.downtime.length ? Number(this.downtime) : undefined, maintenanceCost: this.cost.length ? Number(this.cost) : undefined, result: this.repairResult, comment: this.comment.trim() });
      this.formVisible = false; this.dirty = false; this.getUIContext().getPromptAction().showToast({ message: '维修结果已提交，等待管理员验收' }); await this.load();
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '维修结果提交失败' }); }
    finally { this.busy = ''; }
  }

  requestBack(): void { if (!this.dirty) this.onBack(); else this.closeForm(); }

  @Builder repairPanel() {
    Column({ space: 10 }) {
      Text(this.rejected() !== undefined ? '返修结果录入' : '维修结果录入').fontSize(21).fontWeight(FontWeight.Bold).fontColor(Tokens.text).width('100%')
      TextArea({ text: this.faultCause, placeholder: '故障原因' }).height(76).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.faultCause = value; this.markDirty(); })
      TextArea({ text: this.solution, placeholder: '维修方案（必填）' }).height(92).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.solution = value; this.markDirty(); })
      TextInput({ text: this.partsUsed, placeholder: '使用备件' }).height(46).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.partsUsed = value; this.markDirty(); })
      Row({ space: 10 }) { TextInput({ text: this.downtime, placeholder: '停机分钟' }).type(InputType.Number).layoutWeight(1).height(46).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.downtime = value; this.markDirty(); }); TextInput({ text: this.cost, placeholder: '维修费用' }).type(InputType.NUMBER_DECIMAL).layoutWeight(1).height(46).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.cost = value; this.markDirty(); }) }.width('100%')
      Row({ space: 10 }) { Button('修复成功').layoutWeight(1).height(42).backgroundColor(this.repairResult === 'SUCCESS' ? Tokens.success : Tokens.elevated).onClick(() => { this.repairResult = 'SUCCESS'; this.markDirty(); }); Button('部分修复').layoutWeight(1).height(42).backgroundColor(this.repairResult === 'PARTIAL' ? Tokens.warning : Tokens.elevated).onClick(() => { this.repairResult = 'PARTIAL'; this.markDirty(); }) }.width('100%')
      TextArea({ text: this.comment, placeholder: '备注' }).height(70).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.comment = value; this.markDirty(); })
      Row({ space: 10 }) { Button('取消').layoutWeight(1).height(48).backgroundColor(Tokens.elevated).onClick(() => this.closeForm()); Button(this.busy === 'repair' ? '提交中' : '提交待验收').layoutWeight(1).height(48).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.submitRepair()) }.width('100%')
    }.padding(18).width('94%').constraintSize({ maxHeight: '92%' }).backgroundColor('#19283A').borderRadius(18)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 12 }) {
        Row() { Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(Tokens.primary).onClick(() => this.requestBack()); Blank(); Button('刷新').backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.load()) }.width('100%')
        if (this.loading) { LoadingView({ message: '正在加载工单详情' }) }
        else if (this.errorText.length > 0 || this.detail === undefined) { ErrorView({ message: this.errorText, onRetry: () => this.load() }) }
        else {
          List({ space: 12 }) {
            ListItem() { Column({ space: 8 }) { Row() { Text(this.device?.deviceName ?? '设备').fontSize(23).fontWeight(FontWeight.Bold).fontColor(Tokens.text).layoutWeight(1); Text(statusText(this.detail?.workOrder.status ?? '')).fontColor(Tokens.primary) }; Text(this.detail?.workOrder.title ?? '').fontSize(17).fontColor(Tokens.text); Text((this.device?.installLocation ?? '位置未填写') + ' · ' + (this.detail?.workOrder.workOrderCode ?? '')).fontColor(Tokens.textSecondary); Text('优先级 ' + statusText(this.detail?.workOrder.priority ?? '')).fontColor(Tokens.warning) }.alignItems(HorizontalAlign.Start).padding(18).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) }
            if (this.rejected() !== undefined) { ListItem() { Column({ space: 7 }) { Text('验收未通过').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Tokens.danger); Text(this.rejected()?.acceptanceContent ?? '管理员要求继续返修').fontColor(Tokens.text); Text('驳回时间 ' + formatTime(this.rejected()?.acceptedAt)).fontColor(Tokens.textSecondary).fontSize(13) }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor('#3B222A').borderRadius(Tokens.radius) } }
            if (this.defect !== undefined) { ListItem() { Column({ space: 7 }) { Text('关联缺陷').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Tokens.text); Text(this.defect?.title ?? '').fontColor(Tokens.text); Text(statusText(this.defect?.severity ?? '') + ' · ' + (this.defect?.description ?? '暂无异常描述')).fontColor(Tokens.textSecondary); if ((this.detail?.workOrder.aiDiagnosisId ?? this.defect?.aiDiagnosisId) !== undefined) { Button('查看 AI 建议与安全事项').height(42).backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.onOpenAi(this.detail?.workOrder.aiDiagnosisId ?? this.defect?.aiDiagnosisId ?? '')) } }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) } }
            if ((this.detail?.records.length ?? 0) > 0) { ListItem() { Text('维修记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Tokens.text).padding({ top: 8 }) } }
            ForEach(this.detail.records, (record: MaintenanceRecord) => { ListItem() { Column({ space: 5 }) { Text(record.solution ?? '未填写维修方案').fontColor(Tokens.text).fontWeight(FontWeight.Medium); Text('原因：' + (record.faultCause ?? '—')).fontColor(Tokens.textSecondary); Text('结果：' + statusText(record.result) + ' · ' + formatTime(record.repairedAt)).fontColor(Tokens.textSecondary).fontSize(13) }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) } }, (record: MaintenanceRecord) => record.id)
            ListItem() { Row() {}.height(82) }
          }.layoutWeight(1).width('100%')
          if (this.detail.workOrder.status === 'ASSIGNED') { Button(this.busy === 'start' ? '启动中' : '开始维修').width('100%').height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.start()) }
          else if (this.detail.workOrder.status === 'PROCESSING') { Button(this.rejected() !== undefined ? '继续维修并再次提交' : '录入维修结果').width('100%').height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').onClick(() => this.openForm()) }
          else if (this.detail.workOrder.status === 'WAITING_ACCEPTANCE') { Text('维修结果已提交，等待管理员验收。').width('100%').padding(16).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.warning).borderRadius(12) }
          else { Text('工单已完成，当前为只读状态。').width('100%').padding(16).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.success).borderRadius(12) }
        }
      }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
      if (this.formVisible) { Stack() { Scroll() { this.repairPanel() } }.width('100%').height('100%').backgroundColor('#99000000').alignContent(Alignment.Center) }
    }.width('100%').height('100%')
  }
}
