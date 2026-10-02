import { TodayInspectionPage } from './TodayInspectionPage';
import { TaskDetailPage } from './TaskDetailPage';
import { AiResultPage } from '../ai/AiResultPage';
import { ProfilePage } from '../profile/ProfilePage';
import { Tokens } from '../../theme/Tokens';

enum InspectorView { Tasks, Detail, Ai, Profile }

@Component
export struct InspectorWorkspace {
  onLoggedOut: () => void = () => {};
  @State view: InspectorView = InspectorView.Tasks;
  @State selectedTask: string = '';
  @State selectedDiagnosis: string = '';

  build() {
    Column() {
      if (this.view === InspectorView.Tasks) { TodayInspectionPage({ onOpen: (id: string) => { this.selectedTask = id; this.view = InspectorView.Detail; } }) }
      else if (this.view === InspectorView.Detail) { TaskDetailPage({ taskId: this.selectedTask, onBack: () => this.view = InspectorView.Tasks, onOpenAi: (id: string) => { this.selectedDiagnosis = id; this.view = InspectorView.Ai; } }) }
      else if (this.view === InspectorView.Ai) { AiResultPage({ diagnosisId: this.selectedDiagnosis, onBack: () => this.view = InspectorView.Detail }) }
      else { ProfilePage({ onLoggedOut: this.onLoggedOut, onOpenBusiness: (bizType: string, bizId: string) => { if (bizType === 'INSPECTION_TASK') { this.selectedTask = bizId; this.view = InspectorView.Detail; } else if (bizType === 'AI_DIAGNOSIS') { this.selectedDiagnosis = bizId; this.view = InspectorView.Ai; } } }) }
      if (this.view === InspectorView.Tasks || this.view === InspectorView.Profile) {
        Row() { Button('今日巡检').layoutWeight(1).height(54).backgroundColor(this.view === InspectorView.Tasks ? Tokens.primary : Tokens.surface).fontColor(this.view === InspectorView.Tasks ? '#0C1925' : Tokens.textSecondary).onClick(() => this.view = InspectorView.Tasks); Button('我的').layoutWeight(1).height(54).backgroundColor(this.view === InspectorView.Profile ? Tokens.primary : Tokens.surface).fontColor(this.view === InspectorView.Profile ? '#0C1925' : Tokens.textSecondary).onClick(() => this.view = InspectorView.Profile) }.width('100%').padding({ left: 14, right: 14, bottom: 8 }).backgroundColor(Tokens.background)
      }
    }.width('100%').height('100%').backgroundColor(Tokens.background)
  }
}
