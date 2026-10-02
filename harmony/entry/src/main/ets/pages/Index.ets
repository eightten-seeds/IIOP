import { AuthService } from '../services/AuthService';
import { SessionStore } from '../stores/SessionStore';
import { ApiError, ApiErrorKind } from '../network/ApiError';
import { Tokens } from '../theme/Tokens';
import { LoginPage } from './login/LoginPage';
import { RoleHomePage } from './home/RoleHomePage';
import { InspectorWorkspace } from './inspection/InspectorWorkspace';
import { MaintainerWorkspace } from './maintenance/MaintainerWorkspace';

enum RootState { Restoring, Login, Inspector, Maintainer, Manager, RestoreError }

@Entry
@Component
struct Index {
  @State rootState: RootState = RootState.Restoring;
  @State restoreError: string = '';

  aboutToAppear(): void { this.restore(); }

  private routeByRole(): void {
    if (SessionStore.hasRole('INSPECTOR')) this.rootState = RootState.Inspector;
    else if (SessionStore.hasRole('MAINTAINER')) this.rootState = RootState.Maintainer;
    else this.rootState = RootState.Manager;
  }

  async restore(): Promise<void> {
    this.rootState = RootState.Restoring; this.restoreError = '';
    const token = await SessionStore.restoreToken();
    if (token.length === 0) { this.rootState = RootState.Login; return; }
    try { await AuthService.me(); this.routeByRole(); }
    catch (error) {
      if (error instanceof ApiError && error.kind === ApiErrorKind.Unauthorized) this.rootState = RootState.Login;
      else { this.restoreError = '暂时无法验证登录状态，请检查网络后重试。'; this.rootState = RootState.RestoreError; }
    }
  }

  async logout(): Promise<void> { await AuthService.logout(); this.rootState = RootState.Login; }

  build() {
    Stack() {
      if (this.rootState === RootState.Restoring) {
        Column({ space: 14 }) { LoadingProgress().color(Tokens.primary).width(38); Text('正在恢复登录状态').fontColor(Tokens.textSecondary) }.width('100%')
      } else if (this.rootState === RootState.Login) {
        LoginPage({ onLoggedIn: () => this.routeByRole() })
      } else if (this.rootState === RootState.RestoreError) {
        Column({ space: 18 }) { Text('身份验证暂不可用').fontSize(21).fontColor(Tokens.text); Text(this.restoreError).fontColor(Tokens.textSecondary); Button('重试').height(Tokens.touchHeight).backgroundColor(Tokens.primary).onClick(() => this.restore()) }.padding(28)
      } else if (this.rootState === RootState.Inspector) {
        InspectorWorkspace({ onLoggedOut: () => this.rootState = RootState.Login })
      } else if (this.rootState === RootState.Maintainer) {
        MaintainerWorkspace({ onLoggedOut: () => this.rootState = RootState.Login })
      } else {
        RoleHomePage({ onLogout: () => this.logout() })
      }
    }.width('100%').height('100%').backgroundColor(Tokens.background)
  }
}
