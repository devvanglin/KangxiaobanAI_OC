import { isCleartextHermesServerUrl, normalizeHermesServerUrl } from '../common/HermesUrl';

@ComponentV2
export struct HermesLoginPage {
  @Param wide: boolean = false;
  @Event onLogin: (serverUrl: string, userName: string, password: string, profile: string) => Promise<string> =
    (_serverUrl: string, _userName: string, _password: string, _profile: string): Promise<string> => Promise.resolve('');
  @Local serverUrl: string = '';
  @Local userName: string = 'admin';
  @Local password: string = '';
  @Local profile: string = 'default';
  @Local showPassword: boolean = false;
  @Local errorText: string = '';
  @Local submitting: boolean = false;

  private previewMode(): boolean {
    return normalizeHermesServerUrl(this.serverUrl).status === 'empty';
  }

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (this.userName.trim().length === 0 || this.password.length === 0) {
      this.errorText = '请输入用户名和密码';
      return;
    }
    const serverResult = normalizeHermesServerUrl(this.serverUrl);
    if (serverResult.status === 'invalid') {
      this.errorText = serverResult.message;
      return;
    }
    this.errorText = '';
    this.submitting = true;
    try {
      const resultMessage: string = await this.onLogin(this.serverUrl, this.userName.trim(), this.password,
        this.profile.trim() || 'default');
      this.errorText = resultMessage;
    } catch (_error) {
      this.errorText = '登录流程发生未预期错误，请重试';
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Scroll() {
      Row() {
        if (this.wide) {
          Column({ space: 22 }) {
            Image($r('app.media.hermes_logo'))
              .width(230)
              .height(230)
              .objectFit(ImageFit.Contain)
              .accessibilityText('Hermes Studio 吉祥物')
            Column({ space: 8 }) {
              Text('Hermes Studio')
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.hermes_text_primary'))
              Text('Agent 对话、工作流与本地控制台')
                .fontSize($r('app.float.hermes_text_body'))
                .fontColor($r('app.color.hermes_text_secondary'))
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('46%')
          .justifyContent(FlexAlign.Center)
        }

        Column({ space: 18 }) {
          if (!this.wide) {
            Image($r('app.media.hermes_logo'))
              .width(108)
              .height(108)
              .objectFit(ImageFit.Contain)
              .alignSelf(ItemAlign.Center)
              .accessibilityText('Hermes Studio')
          }

          Column({ space: 5 }) {
            Text($r('app.string.login_title'))
              .fontSize($r('app.float.hermes_text_heading'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.hermes_text_primary'))
            Text($r('app.string.login_subtitle'))
              .fontSize($r('app.float.hermes_text_body'))
              .fontColor($r('app.color.hermes_text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 8 }) {
            Text('Hermes Server URL（可选）')
              .fontSize($r('app.float.hermes_text_caption'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.hermes_text_primary'))
              .width('100%')
            TextInput({ placeholder: 'https://hermes.example.com', text: this.serverUrl })
              .width('100%')
              .height(44)
              .fontSize($r('app.float.hermes_text_body'))
              .backgroundColor($r('app.color.hermes_bg_surface'))
              .border({ width: 1, color: $r('app.color.hermes_border') })
              .borderRadius($r('app.float.hermes_radius_medium'))
              .onChange((value: string) => this.serverUrl = value)
            Text(this.previewMode() ? '留空使用明确标注的本地预览；填写地址后执行真实认证。' :
              (normalizeHermesServerUrl(this.serverUrl).status === 'invalid' ?
                '地址格式尚未完成，登录时会阻止无效请求。' :
                (isCleartextHermesServerUrl(this.serverUrl.trim()) ?
                  '当前为 HTTP 明文连接，仅建议可信局域网调试使用。' :
                  '将连接真实 Hermes Studio 服务，token 仅保存在当前进程内存。')))
              .fontSize(10)
              .fontColor(normalizeHermesServerUrl(this.serverUrl).status === 'invalid' ?
                $r('app.color.hermes_error') :
                (isCleartextHermesServerUrl(this.serverUrl.trim()) ? $r('app.color.hermes_warning') :
                  $r('app.color.hermes_text_muted')))
              .lineHeight(16)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 8 }) {
            Text('Profile')
              .fontSize($r('app.float.hermes_text_caption'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.hermes_text_primary'))
              .width('100%')
            TextInput({ placeholder: 'default', text: this.profile })
              .width('100%')
              .height(44)
              .fontSize($r('app.float.hermes_text_body'))
              .backgroundColor($r('app.color.hermes_bg_surface'))
              .border({ width: 1, color: $r('app.color.hermes_border') })
              .borderRadius($r('app.float.hermes_radius_medium'))
              .onChange((value: string) => this.profile = value)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 8 }) {
            Text($r('app.string.login_username'))
              .fontSize($r('app.float.hermes_text_caption'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.hermes_text_primary'))
              .width('100%')
            TextInput({ placeholder: $r('app.string.login_username'), text: this.userName })
              .width('100%')
              .height(44)
              .fontSize($r('app.float.hermes_text_body'))
              .backgroundColor($r('app.color.hermes_bg_surface'))
              .border({ width: 1, color: $r('app.color.hermes_border') })
              .borderRadius($r('app.float.hermes_radius_medium'))
              .onChange((value: string) => this.userName = value)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 8 }) {
            Text($r('app.string.login_password'))
              .fontSize($r('app.float.hermes_text_caption'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.hermes_text_primary'))
              .width('100%')
            Stack({ alignContent: Alignment.End }) {
              TextInput({ placeholder: $r('app.string.login_password'), text: this.password })
                .width('100%')
                .height(44)
                .type(this.showPassword ? InputType.Normal : InputType.Password)
                .padding({ left: 12, right: 54 })
                .fontSize($r('app.float.hermes_text_body'))
                .backgroundColor($r('app.color.hermes_bg_surface'))
                .border({ width: 1, color: $r('app.color.hermes_border') })
                .borderRadius($r('app.float.hermes_radius_medium'))
                .onChange((value: string) => this.password = value)
                .onSubmit(() => this.submit())
              Text(this.showPassword ? '隐藏' : '显示')
                .fontSize(11)
                .fontColor($r('app.color.hermes_text_secondary'))
                .margin({ right: 12 })
                .focusable(true)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .onClick(() => this.showPassword = !this.showPassword)
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize($r('app.float.hermes_text_caption'))
              .fontColor($r('app.color.hermes_error'))
              .width('100%')
              .accessibilityText(this.errorText)
          }

          Button(this.submitting ? '正在连接…' : (this.previewMode() ? '进入本地预览' : $r('app.string.login_action')))
            .width('100%')
            .height(44)
            .fontSize($r('app.float.hermes_text_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.hermes_text_on_accent'))
            .backgroundColor($r('app.color.hermes_accent'))
            .borderRadius($r('app.float.hermes_radius_medium'))
            .enabled(!this.submitting)
            .onClick(() => this.submit())

          Text(this.previewMode() ? $r('app.string.login_demo_hint') : '真实模式会调用 /api/auth/login 并加载当前 Profile 会话。')
            .fontSize(11)
            .fontColor($r('app.color.hermes_text_muted'))
            .lineHeight(18)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .width(this.wide ? 390 : '88%')
        .constraintSize({ minWidth: 300, maxWidth: 420 })
        .padding(this.wide ? 30 : 22)
        .backgroundColor($r('app.color.hermes_bg_surface'))
        .border({ width: 1, color: $r('app.color.hermes_border') })
        .borderRadius($r('app.float.hermes_radius_shell'))
        .shadow({ radius: 24, color: '#16000000', offsetY: 8 })
      }
      .width(this.wide ? 920 : '100%')
      .padding({ top: this.wide ? 64 : 24, bottom: this.wide ? 64 : 24 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('app.color.hermes_bg_primary'))
  }
}
