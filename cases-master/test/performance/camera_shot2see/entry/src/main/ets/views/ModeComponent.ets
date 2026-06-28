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

import { router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import image from '@ohos.multimedia.image';
import CameraService from '../mode/CameraService';
import Logger from '../common/utils/Logger';
import { GlobalContext } from '../common/utils/GlobalContext';
import { Constants } from '../common/Constants';

const TAG: string = 'ModeComponent';

@Component
export struct ModeComponent {
  @StorageLink('isOpenEditPage') @Watch('changePageState') isOpenEditPage: boolean = false;
  @State isClick: boolean = false;

  changePageState(): void {
    if (this.isOpenEditPage) {
      this.onJumpClick();
    }
  }

  aboutToAppear(): void {
    Logger.info(TAG, 'aboutToAppear');
    CameraService.setSavePictureCallback(this.handleSavePicture);
  }

  handleSavePicture = (imageInfo: photoAccessHelper.PhotoAsset | image.PixelMap): void => {
    Logger.info(TAG, 'handleSavePicture');
    this.setImageInfo(imageInfo);
    AppStorage.set<boolean>('isOpenEditPage', true);
    Logger.info(TAG, 'setImageInfo end');
  }

  setImageInfo(imageInfo: photoAccessHelper.PhotoAsset | image.PixelMap): void {
    Logger.info(TAG, 'setImageInfo');
    GlobalContext.get().setObject('imageInfo', imageInfo);
  }

  onJumpClick(): void {
    // 目标url
    router.pushUrl({ url: 'pages/EditPage' }, router.RouterMode.Single, (err) => {
      if (err) {
        Logger.error(TAG, `Invoke pushUrl failed, code is ${err.code}, message is ${err.message}`);
        return;
      }
      this.isClick = false;
      Logger.info(TAG, 'Invoke pushUrl succeeded.');
    });
  }

  build() {
    Column() {
      Button() {
        Text()
          .width($r('app.string.120px'))
          .height($r('app.string.120px'))
          .borderRadius($r('app.string.40px'))
          .backgroundColor(this.isClick ? Color.Red : Color.White)
      }
      .border({
        width: Constants.CAPTURE_BUTTON_BORDER_WIDTH,
        color: $r('app.color.border_color'),
        radius: Constants.CAPTURE_BUTTON_BORDER_RADIUS
      })
      .width($r('app.string.200px'))
      .height($r('app.string.200px'))
      .backgroundColor(Color.Black)
      .onClick(async () => {
        this.isClick = true;
        await CameraService.takePicture();
      })
    }
    .width(Constants.FULL_PERCENT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height(Constants.TEN_PERCENT)
    .padding({
      left: Constants.CAPTURE_BUTTON_COLUMN_PADDING,
      right: Constants.CAPTURE_BUTTON_COLUMN_PADDING
    })
    .margin({ bottom: Constants.CAPTURE_BUTTON_COLUMN_MARGIN })
    .position({
      x: Constants.ZERO_PERCENT,
      y: Constants.EIGHTY_FIVE_PERCENT
    })
  }
}
