import { Device } from '../../models/CommonModels';
import { Acceptance, Defect, MaintenanceRecord, WorkOrderDetail } from '../../models/MaintenanceModels';
import { DeviceService } from '../../services/DeviceService';
import { MaintenanceService } from '../../services/MaintenanceService';
import { ErrorView, LoadingView } from '../../components/common/StateViews';
import { Tokens } from '../../theme/Tokens';
import { formatTime, statusText } from '../../utils/Display';
import { BackNavigationStore } from '../../stores/BackNavigationStore';
import { SessionStore } from '../../stores/SessionStore';

@Component
export struct WorkOrderDetailPage {
  private readonly backOwner: string = 'maintenance-work-order-detail';
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

  aboutToAppear(): void {
    BackNavigationStore.register(this.backOwner, () => { this.requestBack(); return true; });
    this.load();
  }
  aboutToDisappear(): void { BackNavigationStore.clear(this.backOwner); }

  private latestAcceptance(): Acceptance | undefined {
    const values = this.detail?.acceptances ?? [];
    return [...values].sort((left, right) => right.acceptedAt.localeCompare(left.acceptedAt) || right.id.localeCompare(left.id))[0];
  }

  private rejected(): Acceptance | undefined {
    const latest = this.latestAcceptance();
    return this.detail?.workOrder.status === 'PROCESSING' && latest?.acceptanceResult === 'REJECTED' ? latest : undefined;
  }

  private latestRecord(): MaintenanceRecord | undefined {
    const values = this.detail?.records ?? [];
    return [...values].sort((left, right) => right.repairedAt.localeCompare(left.repairedAt) || right.id.localeCompare(left.id))[0];
  }

  private completedAcceptance(): Acceptance | undefined {
    const latest = this.latestAcceptance();
    return latest?.acceptanceResult === 'PASSED' ? latest : undefined;
  }

  private isAssignee(): boolean {
    return SessionStore.hasRole('MAINTAINER') &&
           SessionStore.user !== undefined &&
           this.detail?.workOrder.assigneeUserId !== undefined &&
           String(SessionStore.user.id) === String(this.detail?.workOrder.assigneeUserId);
  }

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
    if (this.busy.length > 0) return;
    if (!this.isAssignee()) {
      this.getUIContext().getPromptAction().showToast({ message: '仅工单责任人可开始维修' });
      return;
    }
    if (this.detail?.workOrder.status !== 'ASSIGNED') {
      this.getUIContext().getPromptAction().showToast({ message: '仅已分派工单可以开始维修' });
      return;
    }
    this.busy = 'start';
    try {
      const started = await MaintenanceService.start(this.orderId, '移动端现场开工');
      if (this.detail) {
        this.detail = {
          workOrder: started,
          logs: this.detail.logs,
          records: this.detail.records,
          acceptances: this.detail.acceptances
        };
      }
      this.getUIContext().getPromptAction().showToast({ message: '维修已开始' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '开始维修失败' });
    } finally {
      this.busy = '';
    }
  }

  openForm(): void {
    if (!this.isAssignee()) {
      this.getUIContext().getPromptAction().showToast({ message: '仅工单责任人可录入维修结果' });
      return;
    }
    if (this.detail?.workOrder.status !== 'PROCESSING') {
      this.getUIContext().getPromptAction().showToast({ message: '仅维修中工单可以录入维修结果' });
      return;
    }
    const last = this.latestRecord();
    this.faultCause = last?.faultCause ?? '';
    this.solution = last?.solution ?? '';
    this.partsUsed = last?.partsUsed ?? '';
    this.downtime = last?.downtimeMinutes !== undefined && last?.downtimeMinutes !== null ? last.downtimeMinutes.toString() : '0';
    this.cost = last?.maintenanceCost !== undefined && last?.maintenanceCost !== null ? last.maintenanceCost.toString() : '0';
    this.repairResult = last !== undefined && ['SUCCESS', 'PARTIAL', 'FAILED'].includes(last.result) ? last.result : 'SUCCESS';
    this.comment = '';
    this.dirty = false;
    this.formVisible = true;
  }

  markDirty(): void { this.dirty = true; }

  closeForm(): void {
    if (!this.dirty) {
      this.formVisible = false;
    } else {
      this.getUIContext().getPromptAction().showDialog({
        title: '存在未保存内容',
        message: '当前填写内容尚未保存，确定离开吗？',
        buttons: [{ text: '继续填写', color: '#9FB0C1' }, { text: '确认放弃', color: '#EF6B73' }]
      }).then(result => {
        if (result.index === 1) {
          this.formVisible = false;
          this.dirty = false;
        }
      });
    }
  }

  async submitRepair(): Promise<void> {
    if (this.busy.length > 0) return;
    if (!this.isAssignee()) {
      this.getUIContext().getPromptAction().showToast({ message: '仅工单责任人可提交维修结果' });
      return;
    }
    if (this.detail?.workOrder.status !== 'PROCESSING') {
      this.getUIContext().getPromptAction().showToast({ message: '仅维修中工单可以提交维修结果' });
      return;
    }
    if (!['SUCCESS', 'PARTIAL', 'FAILED'].includes(this.repairResult)) {
      this.getUIContext().getPromptAction().showToast({ message: '请选择有效的维修结果' });
      return;
    }
    if (this.solution.trim().length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请填写维修方案' });
      return;
    }
    if (this.downtime.trim().length === 0 || this.cost.trim().length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请填写停机分钟和维修费用' });
      return;
    }
    const downtime = Number(this.downtime.trim());
    const cost = Number(this.cost.trim());
    if (isNaN(downtime) || !Number.isFinite(downtime) || downtime < 0 || !Number.isSafeInteger(downtime) || downtime > 2147483647) {
      this.getUIContext().getPromptAction().showToast({ message: '停机分钟必须是非负整数' });
      return;
    }
    if (isNaN(cost) || !Number.isFinite(cost) || cost < 0) {
      this.getUIContext().getPromptAction().showToast({ message: '维修费用必须是非负有效数字' });
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '提交维修结果',
      message: '提交后工单将进入待验收，确认继续？',
      buttons: [{ text: '取消', color: '#9FB0C1' }, { text: '确认提交', color: '#55B6D9' }]
    }).then(result => {
      if (result.index === 1) this.performSubmitRepair(downtime, cost);
    });
  }

  async performSubmitRepair(downtime?: number, cost?: number): Promise<void> {
    if (this.busy.length > 0) return;
    if (!this.isAssignee() || this.detail?.workOrder.status !== 'PROCESSING') {
      this.getUIContext().getPromptAction().showToast({ message: '工单状态或负责人已变化，请刷新后重试' });
      return;
    }
    this.busy = 'repair';
    try {
      const repaired = await MaintenanceService.submitRepair(this.orderId, {
        faultCause: this.faultCause.trim(),
        solution: this.solution.trim(),
        partsUsed: this.partsUsed.trim(),
        downtimeMinutes: downtime,
        maintenanceCost: cost,
        result: this.repairResult,
        comment: this.comment.trim()
      });
      if (this.detail) {
        const localRecord: MaintenanceRecord = {
          id: `local-${Date.now()}`,
          faultCause: this.faultCause.trim(),
          solution: this.solution.trim(),
          partsUsed: this.partsUsed.trim(),
          downtimeMinutes: downtime,
          maintenanceCost: cost,
          result: this.repairResult,
          repairedAt: new Date().toISOString()
        };
        this.detail = {
          workOrder: repaired,
          logs: this.detail.logs,
          records: [localRecord, ...this.detail.records],
          acceptances: this.detail.acceptances
        };
      }
      this.formVisible = false;
      this.dirty = false;
      this.getUIContext().getPromptAction().showToast({ message: '维修结果已提交，等待管理员验收' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '维修结果提交失败' });
    } finally {
      this.busy = '';
    }
  }

  requestBack(): void {
    if (this.formVisible) {
      this.closeForm();
      return;
    }
    this.onBack();
  }
  requestRefresh(): void {
    if (!this.dirty) { this.load(); return; }
    this.getUIContext().getPromptAction().showDialog({
      title: '存在未保存内容',
      message: '刷新会丢弃当前维修表单，确定刷新吗？',
      buttons: [{ text: '继续填写', color: '#9FB0C1' }, { text: '确认放弃', color: '#EF6B73' }]
    }).then(result => {
      if (result.index === 1) {
        this.formVisible = false;
        this.dirty = false;
        this.load();
      }
    });
  }

  @Builder repairPanel() {
    Column({ space: 10 }) {
      Text(this.rejected() !== undefined ? '返修结果录入' : '维修结果录入').fontSize(21).fontWeight(FontWeight.Bold).fontColor(Tokens.text).width('100%')
      TextArea({ text: this.faultCause, placeholder: '故障原因' }).height(76).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.faultCause = value; this.markDirty(); })
      TextArea({ text: this.solution, placeholder: '维修方案（必填）' }).height(92).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.solution = value; this.markDirty(); })
      TextInput({ text: this.partsUsed, placeholder: '使用备件' }).height(46).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.partsUsed = value; this.markDirty(); })
      Row({ space: 10 }) {
        TextInput({ text: this.downtime, placeholder: '停机分钟' }).type(InputType.Number).layoutWeight(1).height(46).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.downtime = value; this.markDirty(); });
        TextInput({ text: this.cost, placeholder: '维修费用' }).type(InputType.NUMBER_DECIMAL).layoutWeight(1).height(46).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.cost = value; this.markDirty(); })
      }.width('100%')
      Row({ space: 6 }) {
        Button('修复成功').layoutWeight(1).height(42).fontSize(12).backgroundColor(this.repairResult === 'SUCCESS' ? Tokens.success : Tokens.elevated).onClick(() => { this.repairResult = 'SUCCESS'; this.markDirty(); });
        Button('部分修复').layoutWeight(1).height(42).fontSize(12).backgroundColor(this.repairResult === 'PARTIAL' ? Tokens.warning : Tokens.elevated).onClick(() => { this.repairResult = 'PARTIAL'; this.markDirty(); });
        Button('修复失败').layoutWeight(1).height(42).fontSize(12).backgroundColor(this.repairResult === 'FAILED' ? Tokens.danger : Tokens.elevated).onClick(() => { this.repairResult = 'FAILED'; this.markDirty(); })
      }.width('100%')
      TextArea({ text: this.comment, placeholder: '备注' }).height(70).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => { this.comment = value; this.markDirty(); })
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(48).backgroundColor(Tokens.elevated).onClick(() => this.closeForm());
        Button(this.busy === 'repair' ? '提交中' : '提交待验收').layoutWeight(1).height(48).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.submitRepair())
      }.width('100%')
    }.padding(18).width('94%').constraintSize({ maxHeight: '92%' }).backgroundColor('#19283A').borderRadius(18)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 12 }) {
        Row() { Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(Tokens.primary).onClick(() => this.requestBack()); Blank(); Button('刷新').backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.requestRefresh()) }.width('100%')
        if (this.loading) { LoadingView({ message: '正在加载工单详情' }) }
        else if (this.errorText.length > 0 || this.detail === undefined) { ErrorView({ message: this.errorText, onRetry: () => this.load() }) }
        else {
          List({ space: 12 }) {
            ListItem() { Column({ space: 8 }) { Row() { Text(this.device?.deviceName ?? '设备').fontSize(23).fontWeight(FontWeight.Bold).fontColor(Tokens.text).layoutWeight(1); Text(statusText(this.detail?.workOrder.status ?? '')).fontColor(Tokens.primary) }; Text(this.detail?.workOrder.title ?? '').fontSize(17).fontColor(Tokens.text); Text((this.device?.installLocation ?? '位置未填写') + ' · ' + (this.detail?.workOrder.workOrderCode ?? '')).fontColor(Tokens.textSecondary); Text('优先级 ' + statusText(this.detail?.workOrder.priority ?? '')).fontColor(Tokens.warning) }.alignItems(HorizontalAlign.Start).padding(18).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) }
            if (this.rejected() !== undefined) { ListItem() { Column({ space: 7 }) { Text('验收未通过').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Tokens.danger); Text(this.rejected()?.acceptanceContent ?? '管理员要求继续返修').fontColor(Tokens.text); Text('驳回时间 ' + formatTime(this.rejected()?.acceptedAt)).fontColor(Tokens.textSecondary).fontSize(13) }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor('#3B222A').borderRadius(Tokens.radius) } }
            if (this.detail?.workOrder.status === 'COMPLETED') { ListItem() { Column({ space: 7 }) { Text('验收已通过').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Tokens.success); Text(this.completedAcceptance()?.acceptanceContent ?? '管理员验收合格，工单已闭环').fontColor(Tokens.text); Text('验收时间 ' + formatTime(this.completedAcceptance()?.acceptedAt)).fontColor(Tokens.textSecondary).fontSize(13) }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor('#18342B').borderRadius(Tokens.radius) } }
            if (this.defect !== undefined) { ListItem() { Column({ space: 7 }) { Text('关联缺陷').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Tokens.text); Text(this.defect?.title ?? '').fontColor(Tokens.text); Text(statusText(this.defect?.severity ?? '') + ' · ' + (this.defect?.description ?? '暂无异常描述')).fontColor(Tokens.textSecondary); if ((this.detail?.workOrder.aiDiagnosisId ?? this.defect?.aiDiagnosisId) !== undefined) { Button('查看 AI 建议与安全事项').height(42).backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.onOpenAi(this.detail?.workOrder.aiDiagnosisId ?? this.defect?.aiDiagnosisId ?? '')) } }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) } }
            if ((this.detail?.records.length ?? 0) > 0) { ListItem() { Text('维修记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Tokens.text).padding({ top: 8 }) } }
            ForEach(this.detail.records, (record: MaintenanceRecord) => { ListItem() { Column({ space: 5 }) { Text(record.solution ?? '未填写维修方案').fontColor(Tokens.text).fontWeight(FontWeight.Medium); Text('原因：' + (record.faultCause ?? '—')).fontColor(Tokens.textSecondary); Text('结果：' + statusText(record.result) + ' · ' + formatTime(record.repairedAt)).fontColor(Tokens.textSecondary).fontSize(13) }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) } }, (record: MaintenanceRecord) => `${record.id}_${record.repairedAt}_${record.result}`)
            ListItem() { Row() {}.height(82) }
          }.layoutWeight(1).width('100%')
          if (!this.isAssignee()) { Text('当前账号不是工单责任人，仅可浏览工单内容。').width('100%').padding(16).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.textSecondary).borderRadius(12) }
          else if (this.detail.workOrder.status === 'ASSIGNED') { Button(this.busy === 'start' ? '启动中' : '开始维修').width('100%').height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.start()) }
          else if (this.detail.workOrder.status === 'PROCESSING') { Button(this.rejected() !== undefined ? '继续维修并再次提交' : '录入维修结果').width('100%').height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').onClick(() => this.openForm()) }
          else if (this.detail.workOrder.status === 'WAITING_ACCEPTANCE') { Text('维修结果已提交，等待管理员验收。').width('100%').padding(16).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.warning).borderRadius(12) }
          else if (this.detail.workOrder.status === 'PENDING') { Text('工单待管理员分配，当前只读。').width('100%').padding(16).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.textSecondary).borderRadius(12) }
          else if (this.detail.workOrder.status === 'COMPLETED') { Text('工单已完成，当前为只读状态。').width('100%').padding(16).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.success).borderRadius(12) }
          else { Text('未知工单状态，当前不可操作，请刷新后重试。').width('100%').padding(16).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.warning).borderRadius(12) }
        }
      }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
      if (this.formVisible) { Stack() { Scroll() { this.repairPanel() } }.width('100%').height('100%').backgroundColor('#99000000').alignContent(Alignment.Center) }
    }.width('100%').height('100%')
  }
}
