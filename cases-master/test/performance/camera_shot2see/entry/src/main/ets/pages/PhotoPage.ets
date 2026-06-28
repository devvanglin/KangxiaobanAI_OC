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

import CameraService from '../mode/CameraService';
import Logger from '../common/utils/Logger';
import { ModeComponent } from '../views/ModeComponent';
import { GlobalContext } from '../common/utils/GlobalContext';
import { Constants } from '../common/Constants';

const TAG = 'Index';

@Entry
@Component
struct Index {
  // 主页面是否显示
  @StorageLink('isShow') isShow: boolean = false;
  @StorageLink('isOpenEditPage') isOpenEditPage: boolean = false;
  @State xComponentAspectRatio: number = 1;
  private mXComponentController: XComponentController = new XComponentController();
  private defaultCameraDeviceIndex = 0;
  private surfaceId = '';

  aboutToAppear(): void {
    Logger.info(TAG, 'aboutToAppear');
  }

  async aboutToDisAppear(): Promise<void> {
    Logger.info(TAG, 'aboutToDisAppear');
    await CameraService.releaseCamera();
  }

  async onPageShow(): Promise<void> {
    Logger.info(TAG, 'onPageShow');
    if (this.surfaceId !== '' && !this.isOpenEditPage) {
      await CameraService.initCamera(this.surfaceId, GlobalContext.get().getT<number>('cameraDeviceIndex'));
    }
    this.isOpenEditPage = false;
  }

  async onPageHide(): Promise<void> {
    Logger.info(TAG, 'onPageHide');
  }

  build() {
    Stack() {
      if (this.isShow) {
        XComponent({
          id: 'componentId',
          type: 'surface',
          controller: this.mXComponentController
        })
          .onLoad(async () => {
            Logger.info(TAG, 'onLoad is called');
            this.surfaceId = this.mXComponentController.getXComponentSurfaceId();
            GlobalContext.get().setObject('cameraDeviceIndex', this.defaultCameraDeviceIndex);
            GlobalContext.get().setObject('xComponentSurfaceId', this.surfaceId);
            let surfaceRect: SurfaceRect = {
              surfaceWidth: Constants.X_COMPONENT_SURFACE_HEIGHT,
              surfaceHeight: Constants.X_COMPONENT_SURFACE_WIDTH
            };
            this.mXComponentController.setXComponentSurfaceRect(surfaceRect);
            Logger.info(TAG, `onLoad surfaceId: ${this.surfaceId}`);
            await CameraService.initCamera(this.surfaceId, this.defaultCameraDeviceIndex);
          })
          .border({
            width: {
              top: Constants.X_COMPONENT_BORDER_WIDTH,
              bottom: Constants.X_COMPONENT_BORDER_WIDTH
            },
            color: Color.Black
          })
          .width(px2vp(Constants.X_COMPONENT_SURFACE_HEIGHT))
          .height(px2vp(Constants.X_COMPONENT_SURFACE_WIDTH))
      }

      // 拍照
      ModeComponent()
    }
    .size({
      width: Constants.FULL_PERCENT,
      height: Constants.FULL_PERCENT
    })
    .backgroundColor(Color.Black)
  }
}