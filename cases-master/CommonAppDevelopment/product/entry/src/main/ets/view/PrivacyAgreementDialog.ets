import { common } from "@kit.AbilityKit";
import { emitter } from "@kit.BasicServicesKit";

const PRIVACY_AGREEMENT =
  'http://113.44.157.14/privacy-agreement/';
const USER_AGREEMENT = 'http://113.44.157.14/user-agreement/';

/**
 * 用户隐私弹窗
 */
@CustomDialog
export struct PrivacyAgreementDialog {
  @StorageLink('isConfirmPrivacyAgreement') isConfirmPrivacyAgreement: boolean = false; // 是否同意隐私弹窗
  @State isSheetShow: boolean = false;
  @State agreementSrc: string = '';
  dialogController?: CustomDialogController;

  implicitStartAbility(uri: string) {
    let context = getContext(this) as common.UIAbilityContext;
    context.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: uri
    })
  }

  build() {
    Column() {
      Text($r('app.string.privacy_agreement_dialog_title'))
        .fontWeight(700)
        .fontSize($r('app.integer.privacy_agreement_dialog_title_font_size'))
        .margin({ top: $r('app.integer.privacy_agreement_dialog_title_font_margin') })
      Column() {
        Text() {
          Span($r('app.string.privacy_agreement_dialog_content1'))
            .fontWeight(400)
            .fontColor($r('app.color.privacy_agreement_dialog_font_color1'))
            .fontSize($r('app.integer.privacy_agreement_dialog_content_font_size'))
          Span($r('app.string.privacy_agreement_dialog_content2'))
            .fontWeight(400)
            .fontColor($r('app.color.privacy_agreement_dialog_font_color2'))
            .onClick(() => {
              //点击用户协议打开弹窗展示用户协议
              this.implicitStartAbility(USER_AGREEMENT);
            })
            .fontColor(Color.Blue)
            .fontSize($r('app.integer.privacy_agreement_dialog_content_font_size'))
          Span($r('app.string.privacy_agreement_dialog_content3'))
            .fontWeight(400)
            .fontColor($r('app.color.privacy_agreement_dialog_font_color1'))
            .fontSize($r('app.integer.privacy_agreement_dialog_content_font_size'))
          Span($r('app.string.privacy_agreement_dialog_content4'))
            .fontWeight(400)
            .fontColor($r('app.color.privacy_agreement_dialog_font_color2'))
            .onClick(() => {
              //点击隐私协议打开弹窗展示隐私协议
              this.implicitStartAbility(PRIVACY_AGREEMENT);
            })
            .fontColor(Color.Blue)
            .fontSize($r('app.integer.privacy_agreement_dialog_content_font_size'))
          Span($r('app.string.privacy_agreement_dialog_content6'))
            .fontWeight(400)
            .fontColor($r('app.color.privacy_agreement_dialog_font_color1'))
            .fontSize($r('app.integer.privacy_agreement_dialog_content_font_size'))
        }
        .textAlign(TextAlign.JUSTIFY)
        .lineHeight($r('app.integer.privacy_agreement_dialog_content_text_line_height'))

        Text($r('app.string.privacy_agreement_dialog_content5'))
          .fontWeight(400)
          .fontColor($r('app.color.privacy_agreement_dialog_font_color1'))
          .fontSize($r('app.integer.privacy_agreement_dialog_content_font_size'))
          .lineHeight($r('app.integer.privacy_agreement_dialog_content_text_line_height'))
          .margin({ top: 16 })
          .textAlign(TextAlign.JUSTIFY)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ top: $r('app.integer.privacy_agreement_dialog_content_column_margin') })

      Column() {
        Button($r('app.string.privacy_agreement_dialog_confirm'))
          .shadow({
            radius: 4,
            offsetX: 2,
            offsetY: 2,
            color: $r('app.color.privacy_agreement_dialog_button_confirm')
          })
          .borderRadius($r('app.integer.privacy_agreement_dialog_button_border_radius'))
          .width($r('app.integer.privacy_agreement_dialog_confirm_button_width'))
          .height($r('app.integer.privacy_agreement_dialog_button_confirm_height'))
          .backgroundColor('#3C7CFC')
          .fontColor(Color.White)
          .fontSize($r('app.integer.privacy_agreement_dialog_button_font_size'))
          .fontWeight(700)
          .id('btn_privacy_agreement')
          .onClick(() => {
            this.isConfirmPrivacyAgreement = true;
            this.dialogController?.close();
            emitter.emit('agreedPrivacyAgreement');
          })
        Text($r('app.string.privacy_agreement_dialog_refuse'))
          .fontSize($r('app.integer.privacy_agreement_dialog_button_refuse_font_size'))
          .fontWeight(400)
          .fontColor($r('app.color.privacy_agreement_dialog_button_refuse_font_color'))
          .margin({ top: $r('app.integer.privacy_agreement_dialog_content_column_margin') })
          .onClick(() => {
            this.isConfirmPrivacyAgreement = false;
            let context = getContext() as common.UIAbilityContext;
            context.terminateSelf();
          })
      }
      .margin({ top: $r('app.integer.privacy_agreement_dialog_button_margin') })
    }
    .borderRadius($r('app.integer.privacy_agreement_dialog_border_radius'))
    .backgroundColor(Color.White)
    .padding({
      left: $r('app.integer.privacy_agreement_dialog_button_padding'),
      right: $r('app.integer.privacy_agreement_dialog_button_padding')
    })
    .width($r('app.integer.privacy_agreement_dialog_height'))
    .height($r('app.integer.privacy_agreement_dialog_width'))
  }
}
