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
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiObserver } from '@kit.ArkUI';
import { CommonConstants } from 'commonmulticommunityapplication';

/**
 * Image Detail Page
 */
@ComponentV2
export struct ImageDetailView {
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Consumer() pathStack: NavPathStack = new NavPathStack();
  @Consumer() sideBar: boolean = false;
  @Local imageSrc: Resource = $r('app.media.ic_follow_picture1');
  private moduleName: string = '';
  build() {
    if (deviceInfo.distributionOSApiVersion >= 60100 && this.moduleName !== CommonConstants.DEVICE_TYPE_PC) {
      NavDestination() {
        Stack() {
          Image(this.imageSrc)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .draggable(false)
        }
        .backgroundColor($r('app.color.image_background_color'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .onBackPressed(() => {
        this.pathStack.pop();
        this.sideBar = true;
        return true;
      })
      .onClick(() => {
        this.pathStack.pop();
        this.sideBar = true;
      })
      .hideTitleBar(true)
      .onReady((context: NavDestinationContext) => {
        this.imageSrc = context.pathInfo.param as Resource;
      })
    } else {
      NavDestination() {
        Stack() {
          Image(this.imageSrc)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .draggable(false)
        }
        .backgroundColor($r('app.color.image_background_color'))
      }
      .hideTitleBar(true)
      .onReady((context: NavDestinationContext) => {
        this.imageSrc = context.pathInfo.param as Resource;
      })
      .onBackPressed(() => {
        this.pathStack.pop();
        return true;
      })
      .onClick(() => {
        this.pathStack.pop();
      })
      .width('100%')
      .height('100%')
    }
  }
}

@Builder
export function ImageDetailBuilder() {
  ImageDetailView();
}