import { router } from '@kit.ArkUI';
import ApiClient from '../network/ApiClient';
import AuthStore from '../network/AuthStore';
import { LoginResp } from '../network/Dto';
import Logger from '../util/Logger';

const TAG: string = '[LoginPage]';

@Entry
@ComponentV2
struct LoginPage {
  @Local account: string = '';
  @Local password: string = '';
  @Local loading: boolean = false;
  @Local error: string = '';

  private async handleLogin(): Promise<void> {
    if (!this.account || !this.password) {
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const resp = await ApiClient.post<LoginResp>('/auth/login', { username: this.account, password: this.password });
      if (resp.code === 0 && resp.data && resp.data.token.length > 0) {
        AuthStore.setSession(resp.data.token, resp.data.user);
        router.replaceUrl({ url: 'pages/MainPage' });
        return;
      }
      this.error = resp.msg || '登录失败';
    } catch (err) {
      Logger.error(TAG, `login err: ${JSON.stringify(err)}`);
      this.error = '无法连接服务器，请确认后端已运行';
    }
    this.loading = false;
  }

  build() {
    Column({ space: 14 }) {
      Blank().layoutWeight(1)

      Text('康小伴 · 家属端')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
      Text('关切家人，一屏尽知')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))

      TextInput({ placeholder: '手机号 / 工号', text: this.account })
        .height(52)
        .fontSize(16)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(14)
        .padding({ left: 16, right: 16 })
        .margin({ top: 24 })
        .onChange((v: string) => { this.account = v; })

      TextInput({ placeholder: '密码', text: this.password })
        .type(InputType.Password)
        .height(52)
        .fontSize(16)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(14)
        .padding({ left: 16, right: 16 })
        .onChange((v: string) => { this.password = v; })

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(13)
          .fontColor(Color.fromRgb(255, 93, 108))
      }

      Button() {
        if (this.loading) {
          LoadingProgress().width(20).height(20).color($r('app.color.text_on_brand'))
        } else {
          Text('登录').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_on_brand'))
        }
      }
      .width('100%')
      .height(52)
      .backgroundColor($r('app.color.brand_blue'))
      .borderRadius(14)
      .enabled(!this.loading && this.account.length > 0 && this.password.length > 0)
      .onClick(() => { this.handleLogin(); })

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor($r('sys.color.background_primary'))
  }
}