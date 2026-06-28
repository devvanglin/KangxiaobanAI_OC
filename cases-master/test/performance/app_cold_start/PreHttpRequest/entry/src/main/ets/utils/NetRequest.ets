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

import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';

// 通过http的request方法从网络下载图片资源
export function httpRequest() {
  hiTraceMeter.startTrace('Http Request', 1);
  http.createHttp()
    .request('https://gitee.com/harmonyos-cases/cases/raw/master/CommonAppDevelopment/feature/variablewatch/src/main/resources/base/media/variablewatch_grape.png',
      (error: BusinessError, data: http.HttpResponse) => {
        if (error) {
          // 下载失败时不执行后续逻辑
          return;
        }
        // 处理网络请求返回的数据
        transcodePixelMap(data);
      }
    )
}

// 使用createPixelMap将ArrayBuffer类型的图片装换为PixelMap类型
function transcodePixelMap(data: http.HttpResponse) {
  if (http.ResponseCode.OK === data.responseCode) {
    const imageData: ArrayBuffer = data.result as ArrayBuffer;
    // 通过ArrayBuffer创建图片源实例
    const imageSource: image.ImageSource = image.createImageSource(imageData);
    const options: image.InitializationOptions = {
      'alphaType': 0, // 透明度
      'editable': false, // 是否可编辑
      'pixelFormat': 3, // 像素格式
      'scaleMode': 1, // 缩略值
      'size': { height: 100, width: 100 }
    }; // 创建图片大小
    // 通过属性创建PixelMap
    imageSource.createPixelMap(options).then((pixelMap: PixelMap) => {
      AppStorage.set('netData', pixelMap);
      hiTraceMeter.finishTrace('Http Request', 1);
    });
  }
}