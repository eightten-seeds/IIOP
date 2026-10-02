import { Tokens } from '../../theme/Tokens';

@Component
export struct LoadingView {
  @Prop message: string = '正在加载';
  build() { Column({ space: 12 }) { LoadingProgress().color(Tokens.primary).width(34).height(34); Text(this.message).fontColor(Tokens.textSecondary).fontSize(14) }.width('100%').padding(32) }
}

@Component
export struct EmptyView {
  @Prop message: string = '暂无数据';
  build() { Column({ space: 10 }) { Text('—').fontSize(34).fontColor(Tokens.border); Text(this.message).fontColor(Tokens.textSecondary).fontSize(15).textAlign(TextAlign.Center) }.width('100%').padding(36) }
}

@Component
export struct ErrorView {
  @Prop message: string = '加载失败';
  onRetry: () => void = () => {};
  build() { Column({ space: 14 }) { Text('暂时无法加载').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Tokens.text); Text(this.message).fontColor(Tokens.textSecondary).textAlign(TextAlign.Center); Button('重试').height(Tokens.touchHeight).backgroundColor(Tokens.primary).fontColor('#0D1A27').onClick(this.onRetry) }.width('100%').padding(32) }
}
