/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

import { display, router, window } from '@kit.ArkUI';
import { waterFlowData } from '../data/WaterFlowData';
import { PrivacyAgreementDialog } from '../view/PrivacyAgreementDialog';
import { emitter } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

// 持久化存储是否同意隐私弹窗
PersistentStorage.persistProp('isConfirmPrivacyAgreement', false);

const OFFSET_RIGHT_LEN = 320; // 按键靠近右侧屏幕距离

@Entry
@Component
struct TransitionsAnimation {
  @State pageCountDown: number = 6; // 进场动画总用时6s
  @StorageProp('windowSize') windowSize: window.Size = {
    width: display.getDefaultDisplaySync().width,
    height: display.getDefaultDisplaySync().height
  };
  @StorageLink('isConfirmPrivacyAgreement') @Watch('isConfirm') isConfirmPrivacyAgreement: boolean = false; // 是否同意隐私弹窗
  @State isConfirmPrivacyAgreementOpen: boolean = false; // 隐私弹窗是否打开
  private timer: number = 0;
  dialogController: CustomDialogController | null = new CustomDialogController({
    builder: PrivacyAgreementDialog(),
    autoCancel: false,
    width: 340,
    height: 372,
    customStyle: true,
    backgroundColor: Color.White,
    alignment: DialogAlignment.Center,
    cornerRadius: 11,
    // 防止用户点击遮罩层、侧滑返回关闭弹窗
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      return;
    }
  })

  isConfirm() {
    if (this.isConfirmPrivacyAgreement) {
      this.timer = setInterval(() => {
        this.pageCountDown--;
        if (this.pageCountDown === 0) {
          clearInterval(this.timer); // 关闭定时器
          router.replaceUrl({ url: 'pages/EntryView' });
        }
      }, 1000)
    }
  }

  // 页面显示时打开定时器
  onPageShow() {
    if (!this.isConfirmPrivacyAgreement) {
      if (!this.isConfirmPrivacyAgreementOpen) {
        this.dialogController?.open();
        this.isConfirmPrivacyAgreementOpen = true;
      }
    } else {
      emitter.emit('agreedPrivacyAgreement');
      this.timer = setInterval(() => {
        this.pageCountDown--;
        if (this.pageCountDown === 0) {
          clearInterval(this.timer); // 关闭定时器
          router.replaceUrl({ url: 'pages/EntryView' });
        }
      }, 1000)
    }
    // 列表数据提前排序
    waterFlowData.sort((a, b) => b.serialNumber - a.serialNumber)
  }

  build() {
    Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center }) {
      // 广告页动图和描述
      Column() {
        Row() {
          Image($r('app.media.enter_app_animation'))
            .objectFit(ImageFit.Contain)
            .width('100%')
            .aspectRatio(1.4)
        }
        .margin({ top: $r('app.integer.advertising_page_gif_margin') })

        Column() {
          Text($r('app.string.advertising_page'))
            .fontSize($r('app.integer.advertising_page_font_size'))
          Text($r('app.string.advertising_description'))
            .margin({ top: $r('app.integer.advertising_description_text_margin') })
            .fontSize($r('app.integer.advertising_description_font_size'))
            .opacity(0.6)
        }
        .margin({ top: $r('app.integer.advertising_description_margin') })
      }
      .width('100%')

      // 跳过按钮和倒计时
      Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
        Text($r('app.string.skip'))
          .fontSize($r('app.integer.advertising_description_skip_font_size'))
          .textAlign(TextAlign.Center)
          .fontColor(Color.White)
        Text(`${this.pageCountDown}`)
          .fontSize($r('app.integer.advertising_description_skip_font_size'))
          .textAlign(TextAlign.Center)
          .fontColor(Color.White)
          .margin({ left: $r('app.integer.advertising_description_pageCountDown_margin') })
      }
      .position({
        x: px2vp(this.windowSize.width - OFFSET_RIGHT_LEN)
      })
      .width($r('app.integer.advertising_description_skip_width'))
      .aspectRatio(2.4)
      .backgroundColor($r('app.string.advertising_description_backgroundColor'))
      .borderRadius($r('app.integer.advertising_description_skip_borderRadius'))
      .onClick(() => {
        this.pageCountDown = 0;
        clearInterval(this.timer); // 手动跳过时关闭定时器
        router.replaceUrl({ url: 'pages/EntryView' });
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.advertising_backgroundColor'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}