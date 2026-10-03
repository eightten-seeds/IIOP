import { MyWorkOrdersPage } from './MyWorkOrdersPage';
import { WorkOrderDetailPage } from './WorkOrderDetailPage';
import { AiResultPage } from '../ai/AiResultPage';
import { ProfilePage } from '../profile/ProfilePage';
import { Tokens } from '../../theme/Tokens';
import { SessionStore } from '../../stores/SessionStore';

enum MaintainerView { Orders, Detail, Ai, Profile }

@Component
export struct MaintainerWorkspace {
  onLoggedOut: () => void = () => {};
  onSwitchRole: () => void = () => {};
  @State view: MaintainerView = MaintainerView.Orders;
  @State selectedOrder: string = '';
  @State selectedDiagnosis: string = '';

  build() {
    Column() {
      if (this.view === MaintainerView.Orders) { MyWorkOrdersPage({ onOpen: (id: string) => { this.selectedOrder = id; this.view = MaintainerView.Detail; } }) }
      else if (this.view === MaintainerView.Detail) { WorkOrderDetailPage({ orderId: this.selectedOrder, onBack: () => this.view = MaintainerView.Orders, onOpenAi: (id: string) => { this.selectedDiagnosis = id; this.view = MaintainerView.Ai; } }) }
      else if (this.view === MaintainerView.Ai) { AiResultPage({ diagnosisId: this.selectedDiagnosis, onBack: () => this.view = MaintainerView.Detail }) }
      else { ProfilePage({ onLoggedOut: this.onLoggedOut, onOpenBusiness: (bizType: string, bizId: string) => { if (bizType === 'WORK_ORDER') { this.selectedOrder = bizId; this.view = MaintainerView.Detail; } else if (bizType === 'AI_DIAGNOSIS') { this.selectedDiagnosis = bizId; this.view = MaintainerView.Ai; } } }) }
      if (this.view === MaintainerView.Orders || this.view === MaintainerView.Profile) {
        Row() { Button('我的工单').layoutWeight(1).height(54).backgroundColor(this.view === MaintainerView.Orders ? Tokens.primary : Tokens.surface).fontColor(this.view === MaintainerView.Orders ? '#0C1925' : Tokens.textSecondary).onClick(() => this.view = MaintainerView.Orders); if (SessionStore.hasRole('INSPECTOR')) { Button('切换巡检').layoutWeight(1).height(54).backgroundColor(Tokens.surface).fontColor(Tokens.primary).onClick(this.onSwitchRole) } Button('我的').layoutWeight(1).height(54).backgroundColor(this.view === MaintainerView.Profile ? Tokens.primary : Tokens.surface).fontColor(this.view === MaintainerView.Profile ? '#0C1925' : Tokens.textSecondary).onClick(() => this.view = MaintainerView.Profile) }.width('100%').padding({ left: 14, right: 14, bottom: 8 }).backgroundColor(Tokens.background)
      }
    }.width('100%').height('100%').backgroundColor(Tokens.background)
  }
}
