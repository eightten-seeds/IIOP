import { Device } from '../../models/CommonModels';
import { InspectionAbnormal, TaskDetail, TaskItem } from '../../models/InspectionModels';
import { DeviceService } from '../../services/DeviceService';
import { InspectionService } from '../../services/InspectionService';
import { Tokens } from '../../theme/Tokens';
import { ErrorView, LoadingView } from '../../components/common/StateViews';
import { formatTime, statusText } from '../../utils/Display';
import { BackNavigationStore } from '../../stores/BackNavigationStore';
import { SessionStore } from '../../stores/SessionStore';

@Component
export struct TaskDetailPage {
  private readonly backOwner: string = 'inspection-task-detail';
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

  aboutToAppear(): void {
    BackNavigationStore.register(this.backOwner, () => { this.requestBack(); return true; });
    this.load();
  }
  aboutToDisappear(): void { BackNavigationStore.clear(this.backOwner); }

  async load(): Promise<void> {
    this.loading = true; this.errorText = '';
    try {
      const value = await InspectionService.detail(this.taskId);
      this.detail = value; this.device = await DeviceService.detail(value.task.deviceId);
      value.items.forEach(item => {
        if (!this.dirty.has(item.id)) {
          this.drafts.set(item.id, item.actualValue ?? '');
          this.remarks.set(item.id, item.remark ?? '');
          this.results.set(item.id, item.resultStatus);
        }
      });
      this.revision++;
    } catch (error) { this.errorText = error instanceof Error ? error.message : '任务详情加载失败'; }
    finally { this.loading = false; }
  }

  private isAssignee(): boolean {
    return SessionStore.hasRole('INSPECTOR') &&
           SessionStore.user !== undefined &&
           this.detail?.task.assigneeUserId !== undefined &&
           String(SessionStore.user.id) === String(this.detail?.task.assigneeUserId);
  }

  private setValue(item: TaskItem, value: string): void {
    this.drafts.set(item.id, value);
    this.dirty.add(item.id);
    if (item.itemType === 'NUMBER') {
      const trimmed = value.trim();
      if (trimmed.length === 0) {
        this.results.set(item.id, 'PENDING');
      } else {
        const n = Number(trimmed);
        if (!isNaN(n) && Number.isFinite(n)) {
          const abnormal = (item.lowerLimit !== undefined && item.lowerLimit !== null && n < item.lowerLimit) ||
                           (item.upperLimit !== undefined && item.upperLimit !== null && n > item.upperLimit);
          this.results.set(item.id, abnormal ? 'ABNORMAL' : 'NORMAL');
        } else {
          this.results.set(item.id, 'PENDING');
        }
      }
    } else if (item.itemType === 'TEXT') {
      this.results.set(item.id, value.trim().length === 0 ? 'PENDING' : 'NORMAL');
    }
    this.revision++;
  }

  private normalizeBool(value?: string): string | undefined {
    if (value === undefined || value === null) return undefined;
    const v = value.trim().toLowerCase();
    if (v === 'true' || v === '1' || v === 'normal' || v === '正常') return 'true';
    if (v === 'false' || v === '0' || v === 'abnormal' || v === '异常') return 'false';
    return undefined;
  }

  private booleanStandard(item: TaskItem): string | undefined {
    return this.normalizeBool(item.standardValue);
  }

  private setBoolean(item: TaskItem, result: string): void {
    const standard = this.booleanStandard(item);
    if (standard === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '该检查项缺少标准结果，无法提交' });
      return;
    }
    const actual = result === 'NORMAL' ? standard : (standard === 'true' ? 'false' : 'true');
    this.drafts.set(item.id, actual);
    this.results.set(item.id, result);
    this.dirty.add(item.id);
    if (this.detail) {
      this.detail = {
        task: this.detail.task,
        items: [...this.detail.items],
        abnormals: this.detail.abnormals
      };
    }
    this.revision++;
  }

  async saveItem(item: TaskItem): Promise<void> {
    if (this.busy.length > 0) return;
    if (!this.isAssignee()) {
      this.getUIContext().getPromptAction().showToast({ message: '仅任务负责人可执行保存' });
      return;
    }
    if (this.detail?.task.taskStatus !== 'IN_PROGRESS') {
      this.getUIContext().getPromptAction().showToast({ message: '仅巡检进行中允许保存检查项' });
      return;
    }
    const value = this.drafts.get(item.id) ?? '';
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请先填写检查结果' });
      return;
    }
    if (item.itemType === 'NUMBER') {
      const n = Number(trimmed);
      if (isNaN(n) || !Number.isFinite(n)) {
        this.getUIContext().getPromptAction().showToast({ message: '请输入有效数字，可填写正数、负数或小数' });
        return;
      }
    }
    if (item.itemType === 'BOOLEAN' && this.booleanStandard(item) === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '该检查项缺少标准结果，无法提交' });
      return;
    }
    this.busy = 'item-' + item.id;
    try {
      const updated = await InspectionService.saveItem(this.taskId, item.id, {
        actualValue: trimmed,
        resultStatus: this.results.get(item.id) ?? 'NORMAL',
        remark: this.remarks.get(item.id) ?? ''
      });
      this.dirty.delete(item.id);
      this.drafts.set(item.id, updated.actualValue ?? trimmed);
      this.remarks.set(item.id, updated.remark ?? '');
      this.results.set(item.id, updated.resultStatus);
      if (this.detail) {
        const idx = this.detail.items.findIndex(i => i.id === item.id);
        if (idx >= 0) {
          this.detail.items[idx] = updated;
        }
        const doneCount = this.detail.items.filter(i => i.resultStatus !== 'PENDING').length;
        this.detail.task.completionRate = Math.round((doneCount / this.detail.items.length) * 100);
        this.detail = {
          task: this.detail.task,
          items: [...this.detail.items],
          abnormals: this.detail.abnormals
        };
      }
      this.revision++;
      this.getUIContext().getPromptAction().showToast({ message: '检查项已保存' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '保存失败' });
    } finally {
      this.busy = '';
    }
  }

  async start(): Promise<void> {
    if (this.busy.length > 0) return;
    if (!this.isAssignee()) {
      this.getUIContext().getPromptAction().showToast({ message: '仅任务负责人可开始巡检' });
      return;
    }
    if (this.detail?.task.taskStatus !== 'PENDING') {
      this.getUIContext().getPromptAction().showToast({ message: '仅待执行任务可以开始巡检' });
      return;
    }
    this.busy = 'start';
    try {
      const started = await InspectionService.start(this.taskId);
      if (this.detail) {
        this.detail = {
          task: started,
          items: this.detail.items,
          abnormals: this.detail.abnormals
        };
      }
      this.getUIContext().getPromptAction().showToast({ message: '巡检已开始' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '开始失败' });
    } finally {
      this.busy = '';
    }
  }

  confirmComplete(): void {
    if (!this.isAssignee()) {
      this.getUIContext().getPromptAction().showToast({ message: '仅任务负责人可完成巡检' });
      return;
    }
    if (this.detail?.task.taskStatus !== 'IN_PROGRESS') {
      this.getUIContext().getPromptAction().showToast({ message: '仅巡检进行中允许完成任务' });
      return;
    }
    if (this.dirty.size > 0) {
      this.getUIContext().getPromptAction().showToast({ message: '存在未保存的检查项草稿，请先保存' });
      return;
    }
    const uncompletedRequired = this.detail?.items.find(i => i.requiredFlag === 1 && (this.results.get(i.id) ?? i.resultStatus) === 'PENDING');
    if (uncompletedRequired !== undefined) {
      this.getUIContext().getPromptAction().showToast({ message: `必填检查项【${uncompletedRequired.itemName}】尚未完成` });
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '完成巡检',
      message: '确认所有必填检查项已经完成并提交？',
      buttons: [{ text: '取消', color: '#9FB0C1' }, { text: '确认完成', color: '#55B6D9' }]
    }).then(result => {
      if (result.index === 1) this.complete();
    });
  }

  async complete(): Promise<void> {
    if (this.busy.length > 0) return;
    if (!this.isAssignee() || this.detail?.task.taskStatus !== 'IN_PROGRESS' || this.dirty.size > 0) {
      this.getUIContext().getPromptAction().showToast({ message: '任务状态或草稿已变化，请检查后重试' });
      return;
    }
    const pendingRequired = this.detail.items.find(i => i.requiredFlag === 1 && i.resultStatus === 'PENDING');
    if (pendingRequired !== undefined) {
      this.getUIContext().getPromptAction().showToast({ message: `必填检查项【${pendingRequired.itemName}】尚未完成` });
      return;
    }
    this.busy = 'complete';
    try {
      const completed = await InspectionService.complete(this.taskId);
      if (this.detail) {
        this.detail = {
          task: completed,
          items: this.detail.items,
          abnormals: this.detail.abnormals
        };
      }
      this.getUIContext().getPromptAction().showToast({ message: '巡检已完成' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '完成失败' });
    } finally {
      this.busy = '';
    }
  }

  async submitReport(): Promise<void> {
    if (!this.isAssignee()) {
      this.getUIContext().getPromptAction().showToast({ message: '仅任务负责人可上报异常' });
      return;
    }
    if (this.detail?.task.taskStatus !== 'IN_PROGRESS') {
      this.getUIContext().getPromptAction().showToast({ message: '仅巡检进行中允许上报异常' });
      return;
    }
    if (this.reportDescription.trim().length === 0 || this.busy.length > 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请填写异常描述' });
      return;
    }
    this.busy = 'report';
    const linked = this.detail?.items.find(item => item.id === this.reportItemId);
    try {
      const reported = await InspectionService.report({
        taskId: this.taskId,
        taskItemId: this.reportItemId.length > 0 ? this.reportItemId : undefined,
        severity: this.reportSeverity,
        title: (linked?.itemName ?? this.device?.deviceName ?? '现场巡检') + '异常',
        description: this.reportDescription.trim()
      });
      this.reportVisible = false;
      this.reportDescription = '';
      this.reportItemId = '';
      this.reportSeverity = 'MEDIUM';
      if (this.detail) {
        this.detail = {
          task: this.detail.task,
          items: this.detail.items,
          abnormals: [reported, ...this.detail.abnormals]
        };
        this.revision++;
      }
      this.getUIContext().getPromptAction().showToast({ message: '巡检异常已上报' });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: error instanceof Error ? error.message : '异常上报失败' });
    } finally {
      this.busy = '';
    }
  }

  requestBack(): void {
    if (this.reportVisible) {
      this.closeReport();
      return;
    }
    if (this.dirty.size === 0) {
      this.onBack();
    } else {
      this.getUIContext().getPromptAction().showDialog({
        title: '存在未保存内容',
        message: '当前填写内容尚未保存，确定离开吗？',
        buttons: [{ text: '继续编辑', color: '#9FB0C1' }, { text: '确认放弃', color: '#EF6B73' }]
      }).then(result => {
        if (result.index === 1) this.onBack();
      });
    }
  }

  private reportDirty(): boolean {
    return this.reportDescription.trim().length > 0 || this.reportItemId.length > 0 || this.reportSeverity !== 'MEDIUM';
  }

  private openReport(): void {
    if (!this.isAssignee()) {
      this.getUIContext().getPromptAction().showToast({ message: '仅任务负责人可上报异常' });
      return;
    }
    if (this.detail?.task.taskStatus !== 'IN_PROGRESS') {
      this.getUIContext().getPromptAction().showToast({ message: '仅巡检进行中允许上报异常' });
      return;
    }
    this.reportVisible = true;
  }

  private closeReport(): void {
    if (!this.reportDirty()) {
      this.reportVisible = false;
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '存在未保存内容',
      message: '异常上报内容尚未提交，确定放弃吗？',
      buttons: [{ text: '继续编辑', color: '#9FB0C1' }, { text: '确认放弃', color: '#EF6B73' }]
    }).then(result => {
      if (result.index === 1) {
        this.reportVisible = false;
        this.reportDescription = '';
        this.reportItemId = '';
        this.reportSeverity = 'MEDIUM';
      }
    });
  }

  private requestRefresh(): void {
    if (this.dirty.size === 0 && !this.reportDirty()) {
      this.load();
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '存在未保存内容',
      message: '当前有未保存的检查项或异常表单，刷新将放弃未保存草稿，确定刷新吗？',
      buttons: [{ text: '继续编辑', color: '#9FB0C1' }, { text: '确认放弃', color: '#EF6B73' }]
    }).then(result => {
      if (result.index === 1) {
        this.dirty.clear();
        this.reportVisible = false;
        this.reportDescription = '';
        this.reportItemId = '';
        this.reportSeverity = 'MEDIUM';
        this.load();
      }
    });
  }

  private requestOpenAi(id: string): void {
    if (this.dirty.size > 0 || this.reportDirty()) {
      this.getUIContext().getPromptAction().showToast({ message: '请先保存检查项并提交或清空异常表单' });
      return;
    }
    this.onOpenAi(id);
  }

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
        Text('标准 ' + (item.standardValue ?? '—') + ' · 范围 ' + (item.lowerLimit !== undefined && item.lowerLimit !== null ? item.lowerLimit : '不限') + ' ~ ' + (item.upperLimit !== undefined && item.upperLimit !== null ? item.upperLimit : '不限') + (item.unit ? ' ' + item.unit : '')).fontSize(13).fontColor(Tokens.textSecondary)
        TextInput({ text: this.drafts.get(item.id) ?? '', placeholder: '请输入数字（支持负数和小数）' }).enabled(this.detail?.task.taskStatus === 'IN_PROGRESS' && this.isAssignee()).type(InputType.Normal).height(48).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => this.setValue(item, value))
      } else if (item.itemType === 'BOOLEAN') {
        if (this.booleanStandard(item) === undefined) {
          Text('标准结果缺失，当前检查项不可提交').fontColor(Tokens.danger).fontSize(13)
        } else {
          Text('标准要求: ' + (this.booleanStandard(item) === 'true' ? '是 / 正常状态' : '否 / 无异常状态')).fontSize(13).fontColor(Tokens.textSecondary)
        }
        Row({ space: 10 }) {
          Button('正常（符合）').layoutWeight(1).height(46).enabled(this.booleanStandard(item) !== undefined && this.detail?.task.taskStatus === 'IN_PROGRESS' && this.isAssignee()).backgroundColor(this.results.get(item.id) === 'NORMAL' ? Tokens.success : Tokens.elevated).onClick(() => this.setBoolean(item, 'NORMAL'));
          Button('异常（不符合）').layoutWeight(1).height(46).enabled(this.booleanStandard(item) !== undefined && this.detail?.task.taskStatus === 'IN_PROGRESS' && this.isAssignee()).backgroundColor(this.results.get(item.id) === 'ABNORMAL' ? Tokens.danger : Tokens.elevated).onClick(() => this.setBoolean(item, 'ABNORMAL'))
        }.width('100%')
      } else if (item.itemType === 'TEXT') {
        TextArea({ text: this.drafts.get(item.id) ?? '', placeholder: '请输入现场检查结果' }).enabled(this.detail?.task.taskStatus === 'IN_PROGRESS' && this.isAssignee()).height(90).backgroundColor(Tokens.elevated).fontColor(Tokens.text).onChange(value => this.setValue(item, value))
      } else {
        Text('当前版本暂不支持图片检查项，请联系管理员调整巡检模板。').fontColor(Tokens.warning).fontSize(14)
      }
      if (item.itemType !== 'PHOTO') {
        Row() {
          Text(statusText(this.results.get(item.id) ?? item.resultStatus)).fontColor((this.results.get(item.id) ?? item.resultStatus) === 'ABNORMAL' ? Tokens.danger : (this.results.get(item.id) ?? item.resultStatus) === 'NORMAL' ? Tokens.success : Tokens.textSecondary);
          Blank();
          Button(this.busy === 'item-' + item.id ? '保存中' : '保存检查项').height(42).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0 && this.detail?.task.taskStatus === 'IN_PROGRESS' && this.isAssignee()).onClick(() => this.saveItem(item))
        }.width('100%')
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
      Row({ space: 10 }) { Button('取消').layoutWeight(1).height(48).backgroundColor(Tokens.elevated).onClick(() => this.closeReport()); Button(this.busy === 'report' ? '提交中' : '确认上报').layoutWeight(1).height(48).backgroundColor(Tokens.danger).enabled(this.busy.length === 0).onClick(() => this.submitReport()) }.width('100%')
    }.padding(20).width('92%').backgroundColor('#19283A').borderRadius(18)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 12 }) {
        Row() { Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(Tokens.primary).onClick(() => this.requestBack()); Blank(); Button('刷新').backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.requestRefresh()) }.width('100%')
        if (this.loading) { LoadingView({ message: '正在加载任务详情' }) }
        else if (this.errorText.length > 0 || this.detail === undefined) { ErrorView({ message: this.errorText, onRetry: () => this.load() }) }
        else {
          List({ space: 12 }) {
            ListItem() { Column({ space: 8 }) { Text(this.device?.deviceName ?? '设备').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Tokens.text); Text((this.device?.deviceCode ?? '') + ' · ' + (this.device?.installLocation ?? '位置未填写')).fontColor(Tokens.textSecondary); Row() { Text(statusText(this.detail?.task.taskStatus ?? '')).fontColor(Tokens.primary); Blank(); Text(Math.round(this.detail?.task.completionRate ?? 0) + '%').fontColor(Tokens.primary) }; Progress({ value: this.detail?.task.completionRate ?? 0, total: 100 }).color(Tokens.primary).backgroundColor(Tokens.border) }.alignItems(HorizontalAlign.Start).padding(18).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) }
            ForEach(this.detail.items, (item: TaskItem) => { ListItem() { this.itemCard(item) } }, (item: TaskItem) => `${item.id}_${item.resultStatus}_${this.results.get(item.id) ?? ''}_${this.revision}`)
            if (this.detail.abnormals.length > 0) { ListItem() { Text('已上报异常').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Tokens.text).padding({ top: 8 }) } }
            ForEach(this.detail.abnormals, (abnormal: InspectionAbnormal) => { ListItem() { Column({ space: 7 }) { Text(abnormal.title).fontColor(Tokens.text).fontWeight(FontWeight.Medium); Text(statusText(abnormal.severity) + ' · ' + formatTime(abnormal.reportedAt)).fontColor(Tokens.warning).fontSize(13); if (abnormal.aiDiagnosisId !== undefined) { Button('查看 AI 诊断').height(40).backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.requestOpenAi(abnormal.aiDiagnosisId ?? '')) } else { Text('AI 诊断尚未关联').fontColor(Tokens.textSecondary).fontSize(13) } }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) } }, (abnormal: InspectionAbnormal) => `${abnormal.id}_${this.revision}`)
            ListItem() { Row() {}.height(84) }
          }.layoutWeight(1).width('100%')
          Row({ space: 10 }) {
            if (!this.isAssignee()) {
              Text('当前账号不是任务责任人，仅可浏览巡检内容。').width('100%').padding(14).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.textSecondary).borderRadius(12)
            } else if (this.detail.task.taskStatus === 'PENDING') {
              Button(this.busy === 'start' ? '启动中' : '开始巡检').layoutWeight(1).height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.start())
            } else if (this.detail.task.taskStatus === 'IN_PROGRESS') {
              Button('上报异常').layoutWeight(1).height(52).backgroundColor(Tokens.warning).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.openReport());
              Button(this.busy === 'complete' ? '提交中' : '完成巡检').layoutWeight(1).height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').enabled(this.busy.length === 0).onClick(() => this.confirmComplete())
            } else if (this.detail.task.taskStatus === 'COMPLETED') {
              Button('巡检已完成').layoutWeight(1).height(52).backgroundColor(Tokens.elevated).fontColor(Tokens.success).enabled(false)
            } else {
              Text(statusText(this.detail.task.taskStatus)).width('100%').padding(14).textAlign(TextAlign.Center).backgroundColor(Tokens.elevated).fontColor(Tokens.textSecondary).borderRadius(12)
            }
          }.width('100%').padding({ top: 10 }).backgroundColor(Tokens.background)
        }
      }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
      if (this.reportVisible) { Stack() { this.reportPanel() }.width('100%').height('100%').backgroundColor('#99000000').alignContent(Alignment.Center) }
    }.width('100%').height('100%')
  }
}
