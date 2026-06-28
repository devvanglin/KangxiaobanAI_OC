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

import { display, window } from '@kit.ArkUI';

const OFFSET_RIGHT_LEN = 320; // 按键靠近右侧屏幕距离

/**
 * 功能描述：本示例介绍了如何实现全屏启动页
 *
 * 推荐场景：应用冷启动广告页
 *
 * 核心组件：
 * 1.changeFullScreen
 * 2.timerInterval
 * 
 * 实现步骤：
 * 1.通过window.getLastWindow在页面启动时实现沉浸式布局。
 * 2.通过定时器设置自动进入页面时长，也可手动跳过进入页面。
 *
 */

@Component
export struct AdvertisingPageComponent {
  @State pageCountDown: number = 6; // 进场动画总用时6s
  @StorageProp('windowSize') windowSize: window.Size = {
    width: display.getDefaultDisplaySync().width,
    height: display.getDefaultDisplaySync().height
  };
  @Link isShow: boolean;
  private timer: number = 0;

  /**
   * 页面显示打开沉浸式，页面销毁关闭
   * @param isFull是否需要打开沉浸式
   */
  changeFullScreen(isFull: boolean) {
    let context = getContext();
    window.getLastWindow(context, (err, window) => {
      window.setWindowLayoutFullScreen(isFull);
    })
  }

  /**
   * 控制页面显示倒计时
   */
  timerInterval() {
    this.timer = setInterval(() => {
      this.pageCountDown--;
      if (this.pageCountDown === 0) {
        this.changeFullScreen(false);
        clearInterval(this.timer);
        this.isShow = false;
      }
    }, 1000)
  }

  aboutToAppear(): void {
    this.changeFullScreen(true);
    this.timerInterval();
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
        x: px2vp(this.windowSize.width - OFFSET_RIGHT_LEN),
        y: $r('app.integer.advertising_description_skip_position_y')
      })
      .width($r('app.integer.advertising_description_skip_width'))
      .aspectRatio(2.4)
      .backgroundColor($r('app.string.advertising_description_backgroundColor'))
      .borderRadius($r('app.integer.advertising_description_skip_borderRadius'))
      .onClick(() => {
        clearInterval(this.timer); // 手动跳过时关闭定时器
        this.changeFullScreen(false);
        this.pageCountDown = 0;
        this.isShow = false;
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.advertising_backgroundColor'))
  }
}