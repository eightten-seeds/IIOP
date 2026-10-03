import { AuthService } from '../../services/AuthService';
import { Captcha } from '../../models/CommonModels';
import { Tokens } from '../../theme/Tokens';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';

@Component
export struct LoginPage {
  onLoggedIn: () => void = () => {};
  @State username: string = '';
  @State password: string = '';
  @State captchaCode: string = '';
  @State captchaId: string = '';
  @State captchaImage: string = '';
  @State captchaPixelMap: image.PixelMap | undefined = undefined;
  @State submitting: boolean = false;
  @State captchaLoading: boolean = false;
  @State errorText: string = '';
  private captchaSequence: number = 0;

  aboutToAppear(): void { this.refreshCaptcha(); }
  aboutToDisappear(): void { this.captchaPixelMap?.release(); }

  private async decodeCaptcha(value: string, sequence: number): Promise<image.PixelMap> {
    const marker = ';base64,';
    const markerIndex = value.indexOf(marker);
    if (markerIndex < 0) throw new Error('验证码图片格式无效');
    const bytes = new util.Base64Helper().decodeSync(value.substring(markerIndex + marker.length), util.Type.BASIC);
    const source = image.createImageSource(bytes.buffer as ArrayBuffer);
    try {
      const pixelMap = await source.createPixelMap();
      if (sequence !== this.captchaSequence) {
        await pixelMap.release();
        throw new Error('验证码请求已失效');
      }
      return pixelMap;
    } finally { await source.release(); }
  }

  async refreshCaptcha(clearError: boolean = true): Promise<void> {
    const sequence = ++this.captchaSequence;
    this.captchaLoading = true;
    this.captchaCode = '';
    this.captchaId = '';
    this.captchaImage = '';
    const previous = this.captchaPixelMap;
    this.captchaPixelMap = undefined;
    if (previous !== undefined) await previous.release();
    if (clearError) this.errorText = '';
    try {
      const value: Captcha = await AuthService.captcha();
      if (sequence !== this.captchaSequence) return;
      const pixelMap = await this.decodeCaptcha(value.image, sequence);
      this.captchaId = value.captchaId;
      this.captchaImage = value.image;
      this.captchaPixelMap = pixelMap;
    } catch (error) {
      if (sequence !== this.captchaSequence) return;
      this.captchaId = '';
      this.captchaImage = '';
      this.captchaPixelMap = undefined;
      const refreshError = error instanceof Error ? error.message : '验证码加载失败';
      this.errorText = clearError || this.errorText.length === 0 ? refreshError : `${this.errorText}；验证码刷新失败，请点击换一张`;
    } finally { if (sequence === this.captchaSequence) this.captchaLoading = false; }
  }

  async submit(): Promise<void> {
    if (this.submitting) return;
    if (this.username.trim().length === 0 || this.password.length === 0 || this.captchaCode.trim().length === 0) {
      this.errorText = '请完整填写账号、密码和验证码'; return;
    }
    if (this.captchaId.length === 0 || this.captchaImage.length === 0 || this.captchaLoading) {
      this.errorText = '验证码尚未成功加载，请换一张后重试'; return;
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
      await this.refreshCaptcha(false);
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
            if (this.captchaPixelMap !== undefined) { Image(this.captchaPixelMap).objectFit(ImageFit.Fill).width(118).height(50).borderRadius(10) }
            else { Text(this.captchaLoading ? '加载中' : '换一张').fontColor(Tokens.primary) }
          }.width(118).height(52).backgroundColor('#F4F6F8').borderRadius(10).onClick(() => this.refreshCaptcha())
        }.width('100%')
        Button(this.submitting ? '登录中…' : '登录').width('100%').height(52).backgroundColor(Tokens.primary).fontColor('#0C1925').fontWeight(FontWeight.Bold).enabled(!this.submitting && !this.captchaLoading && this.captchaId.length > 0).onClick(() => this.submit())
        Text('账号由系统管理员统一创建与分配').fontSize(12).fontColor(Tokens.textSecondary).margin({ top: 8 })
      }.width('100%').padding(Tokens.pagePadding).margin({ top: 72 })
    }.width('100%').height('100%').backgroundColor(Tokens.background)
  }
}
