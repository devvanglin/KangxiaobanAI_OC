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

import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'; // 程序访问控制管理模块
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog, hiTraceMeter } from '@kit.PerformanceAnalysisKit'; // 性能打点模块
import {
  geoLocationManager
} from '@kit.LocationKit'; // 位置服务模块。需要在module.json5中配置ohos.permission.APPROXIMATELY_LOCATION权限。

// 写入与读取缓存位置数据的key值
const MYLOCATION = 'myLocation';
// 定义获取模糊位置的权限
const PERMISSIONS: Array<Permissions> = ['ohos.permission.APPROXIMATELY_LOCATION'];
// 获取上下文信息
const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
// 初始化PersistentStorage。PersistentStorage用于持久化存储选定的AppStorage属性
PersistentStorage.persistProp(MYLOCATION, '');

@Entry
@Component
struct Index {
  // 创建状态变量@StorageLink(MYLOCATION) myLocation，和AppStorage中MYLOCATION双向绑定
  @StorageLink(MYLOCATION) myLocation: string = '';

  aboutToAppear() {
    // ApiDataTime表示从getCurrentLocation接口获取位置信息的性能打点起始位置。
    hiTraceMeter.startTrace("ApiDataTime", 1);
    // CacheDataTime表示从AppStorage缓存中获取位置信息的性能打点起始位置。
    hiTraceMeter.startTrace("CacheDataTime", 1);
    // 从AppStorage缓存中获取位置信息
    let cacheData = AppStorage.get<string>(MYLOCATION);
    // 缓存中如果有位置信息，则直接从缓存获取位置信息。如果没有，则从getCurrentLocation接口获取位置信息。
    if (cacheData !== '') {
      // 缓存中有位置信息，则从缓存中直接获取位置信息，并结束性能打点
      hiTraceMeter.finishTrace("CacheDataTime", 1);
      AlertDialog.show({
        message: 'AppStorage:' + cacheData,
        alignment: DialogAlignment.Center
      });
    } else {
      // 缓存中没有位置信息，则从接口获取位置信息
      this.apiGetLocation(PERMISSIONS, context);
    }
  }

  /**
   * 从getCurrentLocation接口获取位置信息。用户需要先授权。
   */
  apiGetLocation(permissions: Array<Permissions>, context: common.UIAbilityContext): void {
    // 获取访问控制模块对象
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    // 拉起弹框请求用户授权。requestPermissionsFromUser会判断权限的授权状态来决定是否唤起弹窗
    atManager.requestPermissionsFromUser(context, permissions).then((data) => {
      // 获取相应请求权限的结果。 0表示已授权，否则表示未授权
      let grantStatus: Array<number> = data.authResults;
      let length: number = grantStatus.length;
      for (let i = 0; i < length; i++) {
        // 如果用户已授权模糊位置的权限，则调用getCurrentLocation获取位置信息，并保存到AppStorage
        if (data.permissions[i] === 'ohos.permission.APPROXIMATELY_LOCATION' && grantStatus[i] === 0) {
          // 设置位置请求参数
          let requestInfo: geoLocationManager.CurrentLocationRequest = {
            'priority': geoLocationManager.LocationRequestPriority.FIRST_FIX, // 设置优先级信息。FIRST_FIX表示快速获取位置优先，如果应用希望快速拿到一个位置，可以将优先级设置为该字段。
            'scenario': geoLocationManager.LocationRequestScenario.UNSET // 设置场景信息。UNSET表示未设置场景信息。当scenario取值为UNSET时，priority参数生效，否则priority参数不生效；
          };
          try {
            // 获取当前位置
            geoLocationManager.getCurrentLocation(requestInfo).then((result) => {
              // 获取位置信息后，结束性能打点
              hiTraceMeter.finishTrace("ApiDataTime", 1);
              let locationData = JSON.stringify(result);
              // 保存到本地缓存
              AppStorage.setOrCreate(MYLOCATION, JSON.stringify(locationData));
              AlertDialog.show({
                message: 'getCurrentLocation:' + locationData,
                alignment: DialogAlignment.Center
              });
            })
              .catch((error: BusinessError) => {
                hilog.error(0x0000, "UseCacheInsteadAddressInquiry", `getCurrentLocation: error= ${error}`);
              });
          } catch (err) {
            hilog.error(0x0000, "UseCacheInsteadAddressInquiry", `err: ${err}`);
          }
        } else {
          // 如果用户未授权，提示用户授权。
          AlertDialog.show({
            message: $r('app.string.message'),
            alignment: DialogAlignment.Center
          });
          return;
        }
      }
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, "UseCacheInsteadAddressInquiry", `failed to request permissions from user. Code is ${err.code} , message is ${err.message}`);
    })
  }

  build() {
    Column() {
      Button('clear cache').onClick(() => {
        // 清除AppStorage缓存中的位置信息
        this.myLocation = '';
        AlertDialog.show({
          message: 'cache cleared',
          alignment: DialogAlignment.Center
        });
      })
    }
    .height('100%')
    .width('100%')
  }
}