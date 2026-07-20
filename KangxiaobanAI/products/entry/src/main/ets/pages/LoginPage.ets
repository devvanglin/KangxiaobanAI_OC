/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AppStorageV2, router } from '@kit.ArkUI';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';
import Logger from '../util/Logger';

const TAG: string = '[LoginPage]';

@Entry
@ComponentV2
struct LoginPage {
  @Local account: string = '';
  @Local password: string = '';
  @Local showPassword: boolean = false;
  @Local isLoading: boolean = false;
  @Local rememberMe: boolean = false;
  @Local keyboardOffset: number = 0;
  @Local selectedRole: string = '护工';
  @Local isRoleMenuOpen: boolean = false;
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel()) ?? new GlobalInfoModel();

  @Monitor('globalInfoModel.keyboardHeight')
  onKeyboardHeightChange(): void {
    this.getUIContext().animateTo({
      duration: 400,
      curve: Curve.EaseOut
    }, () => {
      this.keyboardOffset = this.globalInfoModel.keyboardHeight;
    })
  }

  private isWideLayout(): boolean {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    return widthBreakpoint === WidthBreakpoint.WIDTH_MD ||
      widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  private contentWidth(): string | number {
    return this.isWideLayout() ? 400 : '100%';
  }

  private async handleLogin(): Promise<void> {
    if (!this.account || !this.password) {
      return;
    }
    this.isLoading = true;
    setTimeout(async () => {
      this.isLoading = false;
      this.globalInfoModel.role = this.selectedRole;
      try {
        await router.replaceUrl({ url: 'pages/MainPage' });
      } catch (err) {
        Logger.error(TAG, `login route failed: ${JSON.stringify(err)}`);
      }
    }, 800);
  }

  private roleOptions: string[] = ['护工', '医师', '管理'];

  @Builder
  private roleSelector() {
    Row({ space: 4 }) {
      Text(this.selectedRole)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_blue'))
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(14)
        .fontColor([$r('app.color.brand_blue')])
    }
    .height(36)
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .bindMenu(this.roleOptions.map((role: string): MenuElement => ({
      value: role,
      action: () => {
        this.selectedRole = role;
        this.globalInfoModel.role = role;
      }
    })))
  }

  @Builder
  private brandHeader() {
    Column({ space: 6 }) {
      Text('康小伴 AI')
        .fontSize(this.isWideLayout() ? 30 : 28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .letterSpacing(0.5)

      Text('智慧养老管理平台')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .letterSpacing(1)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private accountInput() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.person_fill'))
        .fontSize(18)
        .fontColor([$r('sys.color.icon_tertiary')])

      TextInput({ placeholder: '手机号 / 工号', text: this.account })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .height(56)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onChange((val: string) => {
          this.account = val;
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 20 })
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private passwordInput() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.lock_fill'))
        .fontSize(18)
        .fontColor([$r('sys.color.icon_tertiary')])

      TextInput({ placeholder: '密码', text: this.password })
        .type(this.showPassword ? InputType.Normal : InputType.Password)
        .showPasswordIcon(false)
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .height(56)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onChange((val: string) => {
          this.password = val;
        })

      Row() {
        SymbolGlyph(this.showPassword ? $r('sys.symbol.eye') : $r('sys.symbol.eye_slash'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.showPassword = !this.showPassword;
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 12 })
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private loginButton() {
    Button() {
      if (this.isLoading) {
        LoadingProgress()
          .width(22)
          .height(22)
          .color($r('app.color.text_on_brand'))
      } else {
        Text('登录')
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_brand'))
      }
    }
    .width('100%')
    .height(54)
    .backgroundColor($r('app.color.brand_blue'))
    .borderRadius(16)
    .enabled(!this.isLoading && this.account.length > 0 && this.password.length > 0)
    .opacity((!this.isLoading && this.account.length > 0 && this.password.length > 0) ? 1 : 0.4)
    .animation({ duration: 200, curve: Curve.EaseInOut })
    .onClick(() => {
      this.handleLogin();
    })
  }

  build() {
    Column() {
      // 顶部行：左上角角色选择器
      Row() {
        this.roleSelector()
      }
      .width('100%')
      .height(40)
      .padding({ left: 0, right: 0 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      // 中间内容区（随键盘动画上移）
      Column() {
        // 上方弹性空间
        Blank()
          .layoutWeight(1)

        // 品牌标识区
        Column() {
          this.brandHeader()
        }
        .width(this.contentWidth())
        .margin({ bottom: 48 })

        // 表单区
        Column({ space: 14 }) {
          this.accountInput()
          this.passwordInput()

          Row() {
            Row({ space: 6 }) {
              Checkbox()
                .select(this.rememberMe)
                .selectedColor($r('app.color.brand_blue'))
                .width(18)
                .height(18)
                .onChange((val: boolean) => {
                  this.rememberMe = val;
                })
              Text('记住我')
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }

            Text('忘记密码？')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: 4, bottom: 8 })

          this.loginButton()
        }
        .width(this.contentWidth())

        // 下方弹性空间
        Blank()
          .layoutWeight(1)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ bottom: this.keyboardOffset })
      .alignItems(HorizontalAlign.Center)

      // 底部帮助（固定不随键盘移动）
      Row({ space: 4 }) {
        Text('还没有账号？')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_tertiary'))
        Text('联系管理员')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.brand_blue'))
          .onClick(() => {
            // TODO: 联系管理员
          })
      }
      .width('100%')
      .height(44)
      .margin({ bottom: 20 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.globalInfoModel.statusBarHeight,
      left: this.isWideLayout() ? 0 : 28,
      right: this.isWideLayout() ? 0 : 28
    })
    .alignItems(HorizontalAlign.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
