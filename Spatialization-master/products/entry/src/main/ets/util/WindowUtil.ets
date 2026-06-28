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

import { AppStorageV2, UIContext, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { CommonConstants, StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import Logger from './Logger';

const TAG: string = '[WindowUtil]';

export class WindowUtil {
  private static windowClass?: window.Window;
  private static uiContext: UIContext;

  public static initialize(windowStage: window.WindowStage) {
    try {
      WindowUtil.windowClass = windowStage.getMainWindowSync();
      const uiContext: UIContext = WindowUtil.windowClass.getUIContext();
      WindowUtil.uiContext = uiContext;
      AppStorageV2.connect(UIContext, StorageKey.UI_CONTEXT, () => uiContext);
      WindowUtil.registerBreakpoint(WindowUtil.windowClass);
    } catch (err) {
      Logger.error(TAG, `WindowUtil initialize failed. Cause: ${err.code} ${err.message}`);
    }
  }

  private static getDeviceSize(): void {
    // Get device height.
    try {
      const properties = WindowUtil.windowClass?.getWindowProperties();
      WindowUtil.setWindowSize(properties?.windowRect)
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(TAG, `Get and setDeviceSize failed. code: ${error.code}, message: ${error.message}`);
    }
  }

  private static registerBreakpoint(windowClass: window.Window) {
    try {
      WindowUtil.getDeviceSize();
      const globalInfoModel: GlobalInfoModel =
        AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel()) ??
          new GlobalInfoModel();
      const systemAvoidArea: window.AvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      globalInfoModel.statusBarHeight = WindowUtil.uiContext.px2vp(systemAvoidArea?.topRect?.height ?? 0);
      const bottomArea: window.AvoidArea =
        windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      globalInfoModel.naviIndicatorHeight = WindowUtil.uiContext.px2vp(bottomArea?.bottomRect?.height ?? 0);
      AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => globalInfoModel);
      windowClass.on('windowSizeChange', (windowSize: window.Size) => WindowUtil.setWindowSize(windowSize));
      windowClass.on('avoidAreaChange', (avoidAreaOption) => {
        if (avoidAreaOption.type === window.AvoidAreaType.TYPE_SYSTEM ||
          avoidAreaOption.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          WindowUtil.setAvoidArea(avoidAreaOption.type, avoidAreaOption.area);
        }
      });
    } catch (err) {
      Logger.error(TAG, `getWindowAvoidArea failed. error message: ${err.message}`);
    }
  }

  // Get status bar height and indicator height.
  public static setAvoidArea(type: window.AvoidAreaType, area: window.AvoidArea) {
    const globalInfoModel: GlobalInfoModel =
      AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel()) ??
        new GlobalInfoModel();
    if (type === window.AvoidAreaType.TYPE_SYSTEM) {
      globalInfoModel.statusBarHeight = WindowUtil.uiContext.px2vp(area?.topRect?.height ?? 0);
    } else {
      globalInfoModel.naviIndicatorHeight = WindowUtil.uiContext.px2vp(area?.bottomRect?.height ?? 0);
    }
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => globalInfoModel);
  }

  public static setWindowSize(windowSize?: window.Size | window.Rect) {
    const globalInfoModel: GlobalInfoModel =
      AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel()) ??
        new GlobalInfoModel();
    if (windowSize) {
      const vpHeight = WindowUtil.uiContext.px2vp(windowSize.height);
      const vpWidth = WindowUtil.uiContext.px2vp(windowSize.width);
      globalInfoModel.deviceHeight = vpHeight;
      globalInfoModel.deviceWidth = vpWidth;
      if (vpHeight > 0) {
        globalInfoModel.aspectRatio = vpWidth / vpHeight;
      }
    }
    globalInfoModel.widthBreakpoint = WindowUtil.uiContext.getWindowWidthBreakpoint();
    globalInfoModel.heightBreakpoint = WindowUtil.uiContext.getWindowHeightBreakpoint();
    if ((globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      (globalInfoModel.aspectRatio > CommonConstants.ASPECT_SQUARE_PORTRAIT)) ||
      (globalInfoModel.widthBreakpoint === WidthBreakpoint.WIDTH_MD &&
        (globalInfoModel.aspectRatio > CommonConstants.ASPECT_LANDSCAPE_SQUARE))) {
      globalInfoModel.needDynamicHideBar = true;
    } else {
      globalInfoModel.needDynamicHideBar = false;
    }
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => globalInfoModel);
  }
}