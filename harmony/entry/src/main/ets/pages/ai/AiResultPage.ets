import { DiagnosisView, WorkflowTrace } from '../../models/AiModels';
import { AiService } from '../../services/AiService';
import { EmptyView, ErrorView, LoadingView } from '../../components/common/StateViews';
import { Tokens } from '../../theme/Tokens';
import { formatTime, statusText } from '../../utils/Display';
import { BackNavigationStore } from '../../stores/BackNavigationStore';

interface WorkflowStepView { code: string; label: string }

@Component
export struct AiResultPage {
  private readonly backOwner: string = 'ai-result';
  diagnosisId: string = '';
  onBack: () => void = () => {};
  @State view: DiagnosisView | undefined = undefined;
  @State traces: WorkflowTrace[] = [];
  @State loading: boolean = true;
  @State errorText: string = '';
  private readonly steps: WorkflowStepView[] = [
    { code: 'LOAD_CONTEXT', label: '数据汇聚' },
    { code: 'ANALYZE_WITH_DEEPSEEK', label: 'AI 智能研判' },
    { code: 'RISK_CHECK', label: '风险校验' },
    { code: 'GENERATE_ADVICE', label: '处置方案' },
    { code: 'PREPARE_WORK_ORDER_DRAFT', label: '工单草案' }
  ];
  aboutToAppear(): void { BackNavigationStore.register(this.backOwner, () => { this.onBack(); return true; }); this.load(); }
  aboutToDisappear(): void { BackNavigationStore.clear(this.backOwner); }
  async load(): Promise<void> { this.loading = true; this.errorText = ''; try { this.view = await AiService.detail(this.diagnosisId); this.traces = await AiService.workflow(this.diagnosisId); } catch (error) { this.errorText = error instanceof Error ? error.message : 'AI 结果加载失败'; } finally { this.loading = false; } }
  private traceFor(code: string): WorkflowTrace | undefined { return this.traces.find(item => item.nodeCode === code); }

  @Builder section(title: string, content?: string) { if (content !== undefined && content.length > 0) { Column({ space: 7 }) { Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(Tokens.text); Text(content).fontSize(15).lineHeight(23).fontColor(Tokens.textSecondary).copyOption(CopyOptions.LocalDevice) }.alignItems(HorizontalAlign.Start).padding(16).width('100%').backgroundColor(Tokens.surface).borderRadius(Tokens.radius) } }

  build() {
    Column({ space: 12 }) {
      Row() { Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(Tokens.primary).onClick(this.onBack); Blank(); Button('刷新').backgroundColor(Tokens.elevated).fontColor(Tokens.primary).onClick(() => this.load()) }.width('100%')
      if (this.loading) { LoadingView({ message: '正在加载 AI 诊断' }) }
      else if (this.errorText.length > 0) { ErrorView({ message: this.errorText, onRetry: () => this.load() }) }
      else if (this.view === undefined) { EmptyView({ message: '尚无 AI 诊断结果' }) }
      else {
        List({ space: 12 }) {
          ListItem() { Column({ space: 8 }) { Text('AI 辅助诊断').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Tokens.text); Row() { Text(statusText(this.view?.diagnosis.diagnosisStatus ?? '')).fontColor(Tokens.primary); Blank(); Text(statusText(this.view?.diagnosis.riskLevel ?? '')).fontColor((this.view?.diagnosis.riskLevel === 'HIGH' || this.view?.diagnosis.riskLevel === 'CRITICAL') ? Tokens.danger : Tokens.warning) }; Text('诊断时间 ' + formatTime(this.view?.diagnosis.createdAt)).fontColor(Tokens.textSecondary).fontSize(13); Text('AI 内容为辅助推测，最终故障原因以人工维修记录为准。').fontColor(Tokens.warning).fontSize(13) }.alignItems(HorizontalAlign.Start).padding(18).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) }
          ListItem() { Column({ space: 10 }) { Text('诊断流程').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Tokens.text); ForEach(this.steps, (step: WorkflowStepView, index: number) => { Row({ space: 12 }) { Text((index + 1).toString()).width(28).height(28).textAlign(TextAlign.Center).fontColor('#0C1925').backgroundColor(this.traceFor(step.code)?.status === 'SUCCEEDED' ? Tokens.success : Tokens.primary).borderRadius(14); Text(step.label).fontColor(Tokens.text).layoutWeight(1); Text(this.traceFor(step.code) !== undefined ? statusText(this.traceFor(step.code)?.status ?? '') : '—').fontSize(12).fontColor(Tokens.textSecondary) }.width('100%') }, (step: WorkflowStepView) => step.code) }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) }
          ListItem() { this.section('现场事实摘要', this.view?.diagnosis.abnormalSummary) }
          ListItem() { this.section('AI 推测原因', (this.view?.possibleCauses ?? []).join('\n• ')) }
          ListItem() { this.section('排查建议', (this.view?.investigationSteps ?? []).join('\n• ')) }
          ListItem() { this.section('维修建议', this.view?.diagnosis.maintenanceAdvice) }
          ListItem() { this.section('安全注意事项', this.view?.diagnosis.safetyNotice) }
          ListItem() { Column({ space: 6 }) { Text('数据完整性').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Tokens.text); Text(this.view?.diagnosis.diagnosisStatus === 'SUCCEEDED' ? '诊断数据已完成汇聚并生成结构化结果。' : '诊断未完成，可稍后刷新或返回业务对象。').fontColor(Tokens.textSecondary) }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Tokens.surface).borderRadius(Tokens.radius) }
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').padding(Tokens.pagePadding).backgroundColor(Tokens.background)
  }
}
