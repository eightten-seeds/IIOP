import { AuthService } from '../../services/AuthService';
import { Captcha } from '../../models/CommonModels';
import { Tokens } from '../../theme/Tokens';

@Component
export struct LoginPage {
  onLoggedIn: () => void = () => {};
  @State username: string = '';
  @State password: string = '';
  @State captchaCode: string = '';
  @State captchaId: string = '';
  @State captchaImage: string = '';
  @State submitting: boolean = false;
  @State captchaLoading: boolean = false;
  @State errorText: string = '';

  aboutToAppear(): void { this.refreshCaptcha(); }

  async refreshCaptcha(): Promise<void> {
    this.captchaLoading = true;
    this.captchaCode = '';
    try {
      const value: Captcha = await AuthService.captcha();
      this.captchaId = value.captchaId;
      this.captchaImage = value.image;
    } catch (error) { this.errorText = error instanceof Error ? error.message : '验证码加载失败'; }
    finally { this.captchaLoading = false; }
  }

  async submit(): Promise<void> {
    if (this.submitting) return;
    if (this.username.trim().length === 0 || this.password.length === 0 || this.captchaCode.trim().length === 0) {
      this.errorText = '请完整填写账号、密码和验证码'; return;
    }
    this.submitting = true; this.errorText = '';
    try {
      await AuthService.login({ username: this.username.trim(), password: this.password, captchaId: this.captchaId, captchaCode: this.captchaCode.trim() });
      this.password = '';
      this.getUIContext().getPromptAction().showToast({ message: '登录成功' });
      this.onLoggedIn();
    } catch (error) {
      this.password = '';
      this.errorText = error instanceof Error ? error.message : '登录失败，请重试';
      await this.refreshCaptcha();
    } finally { this.submitting = false; }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 8 }) {
          Text('IIOP').fontSize(36).fontWeight(FontWeight.Bold).fontColor(Tokens.primary).letterSpacing(3)
          Text('工业设备智能运维平台').fontSize(20).fontWeight(FontWeight.Medium).fontColor(Tokens.text)
          Text('现场巡检 · 维修处置 · AI 辅助诊断').fontSize(13).fontColor(Tokens.textSecondary)
        }.alignItems(HorizontalAlign.Start).width('100%').margin({ bottom: 22 })
        if (this.errorText.length > 0) { Text(this.errorText).width('100%').padding(12).borderRadius(10).backgroundColor('#3B222A').fontColor(Tokens.danger) }
        TextInput({ text: this.username, placeholder: '账号' }).height(52).backgroundColor(Tokens.elevated).fontColor(Tokens.text).placeholderColor(Tokens.textSecondary).borderRadius(12).onChange(v => this.username = v)
        TextInput({ text: this.password, placeholder: '密码' }).type(InputType.Password).height(52).backgroundColor(Tokens.elevated).fontColor(Tokens.text).placeholderColor(Tokens.textSecondary).borderRadius(12).onChange(v => this.password = v)
        Row({ space: 10 }) {
          TextInput({ text: this.captchaCode, placeholder: '图形验证码' }).layoutWeight(1).height(52).backgroundColor(Tokens.elevated).fontColor(Tokens.text).placeholderColor(Tokens.textSecondary).borderRadius(12).onChange(v => this.captchaCode = v)
          Stack() {
            if (this.captchaImage.length > 0) { Image(this.captchaImage).objectFit(ImageFit.Fill).width(118).height(50).borderRadius(10) }
            else { Text(this.captchaLoading ? '加载中' : '换一张').fontColor(Tokens.primary) }
          }.width(118).height(52).backgroundColor('#F4F6F8').borderRadius(10).onClick(() => this.refreshCaptcha())
        }.width('100%')
        Button(this.submitting ? '登录中…' : '登录').width('100%').height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').fontWeight(FontWeight.Bold).enabled(!this.submitting).onClick(() => this.submit())
        Text('账号由系统管理员统一创建与分配').fontSize(12).fontColor(Tokens.textSecondary).margin({ top: 8 })
      }.width('100%').padding(Tokens.pagePadding).margin({ top: 72 })
    }.width('100%').height('100%').backgroundColor(Tokens.background)
  }
}
