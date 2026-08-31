interface PromptItem { title: string; prompt: string; enabled: boolean; }

@ComponentV2
export struct WideModelManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Local provider: string = 'local';
  @Local baseUrl: string = '';
  @Local modelName: string = 'kxb-local';
  @Local apiKey: string = '';
  @Local systemPrompt: string = '你是康小伴智慧康养护理平台的照护助理，回答谨慎、贴题，仅作参考，不做临床诊断。';
  @Local saved: boolean = false;
  private scroller: Scroller = new Scroller();

  private saveSample(): void {
    this.saved = true;
    try { this.getUIContext().getPromptAction().showToast({ message: '配置样例已保存到当前页面' }); } catch (_error) {}
  }

  @Builder
  private configSection() {
    Column({ space: 14 }) {
      Text('全局模型配置').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Text('用于统一控制照护 AI 的 Provider、接口地址、模型和系统提示词').fontSize(11).fontColor($r('sys.color.font_secondary'))
      Row({ space: 14 }) {
        Column({ space: 6 }) { Text('Provider').fontSize(12).fontColor($r('sys.color.font_secondary')); Text(this.provider).fontSize(14).fontColor($r('sys.color.font_primary')).padding(12).borderRadius(6).border({ width: 0.5, color: $r('sys.color.comp_divider') }).onClick(() => this.provider = this.provider === 'local' ? 'http' : 'local') }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 6 }) { Text('模型名称').fontSize(12).fontColor($r('sys.color.font_secondary')); TextInput({ text: $$this.modelName, placeholder: '例如 qwen-plus' }).height(42).fontSize(13) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Column({ space: 6 }) { Text('API Base URL').fontSize(12).fontColor($r('sys.color.font_secondary')); TextInput({ text: $$this.baseUrl, placeholder: 'https://your-model.example/v1' }).height(42).fontSize(13) }.width('100%').alignItems(HorizontalAlign.Start)
      Column({ space: 6 }) { Text('API Key').fontSize(12).fontColor($r('sys.color.font_secondary')); TextInput({ text: $$this.apiKey, placeholder: '留空表示不配置远端密钥' }).height(42).fontSize(13).type(InputType.Password) }.width('100%').alignItems(HorizontalAlign.Start)
      Column({ space: 6 }) { Text('系统提示词').fontSize(12).fontColor($r('sys.color.font_secondary')); TextArea({ text: $$this.systemPrompt, placeholder: '输入全局系统提示词' }).height(120).fontSize(13) }.width('100%').alignItems(HorizontalAlign.Start)
      Row() { Button(this.saved ? '已保存' : '保存配置').height(38).fontSize(13).borderRadius(6).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.saveSample()); Blank().layoutWeight(1); Text('当前为管理端配置样板').fontSize(10).fontColor($r('sys.color.font_tertiary')) }.width('100%')
    }.width('100%')
  }

  @Builder
  private promptSection() {
    Column({ space: 12 }) {
      Text('提示词管理').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Row() { Text('名称').width(180).fontSize(12).fontWeight(FontWeight.Medium); Text('提示词内容').layoutWeight(1).fontSize(12).fontWeight(FontWeight.Medium); Text('状态').width(90).fontSize(12).fontWeight(FontWeight.Medium) }.width('100%').height(40).padding({ left: 12, right: 12 }).backgroundColor($r('sys.color.comp_background_secondary'))
      ForEach([{ title: '照护摘要', prompt: '请汇总今天需要优先关注的照护事项', enabled: true }, { title: '跌倒处置', prompt: '跌倒属于高风险事件，请按机构 SOP 给出谨慎建议', enabled: true }, { title: '健康阈值', prompt: '请结合机构服务器配置的体征阈值解释异常风险', enabled: true }] as PromptItem[], (item: PromptItem) => {
        Row() { Text(item.title).width(180).fontSize(13); Text(item.prompt).layoutWeight(1).fontSize(12).fontColor($r('sys.color.font_secondary')); Text(item.enabled ? '启用' : '停用').width(90).fontSize(12).fontColor(item.enabled ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary')) }.width('100%').height(48).padding({ left: 12, right: 12 }).border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
      }, (item: PromptItem) => item.title)
    }.width('100%')
  }

  build() {
    Scroll(this.scroller) { Column({ space: 26 }) { this.configSection(); Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')); this.promptSection() }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight }) }.width('100%').height('100%').scrollBar(BarState.Off)
  }
}
