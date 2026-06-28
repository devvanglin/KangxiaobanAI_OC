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

import { ListView } from '../view/ListView';
import { LoadingStatus } from '../common/CommonEnums';
import { Model } from '../model/Model';
import { http } from '@kit.NetworkKit';
import { CommonConstants } from '../common/CommonConstants';
import LazyDataSource from '../model/LazyDataSource';
import { navDestinationTitle } from '../view/CommonView';

@Builder
export function PageFiveCounterBuilder() {
  PageFiveCounter()
}

// json数据的网络请求地址
const REQUEST_URL: string =
  "https://gitee.com/harmonyos-cases/cases/raw/master/CommonAppDevelopment/feature/skeletondiagram/src/main/resources/rawfile/skeletondiagram.json";

@Component
export struct PageFiveCounter {
  @State loadingCollectedStatus: LoadingStatus = LoadingStatus.OFF;
  @State dataSource: LazyDataSource<Model> = new LazyDataSource();
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear() {
    this.loadList();
  }

  // 加载网络数据
  loadList() {
    // 正在加载状态
    this.loadingCollectedStatus = LoadingStatus.LOADING;
    let httpRequest = http.createHttp();
    // 设置发起请求可选参数
    let options: http.HttpRequestOptions = {
      expectDataType: http.HttpDataType.OBJECT, // 可选，指定返回数据的类型
    };
    // TODO: 知识点：request(url: string, callback: AsyncCallback<HttpResponse>): void此接口仅支持数据大小为5M以内的数据接收。若url包含中文或其他语言，需先调用encodeURL(url)编码，再发起请求。
    // TODO: 知识点：需要权限：ohos.permission.INTERNET在entry/src/main/module.json5文件中添加
    httpRequest.request(REQUEST_URL, options, (err: Error, data: http.HttpResponse) => {
      if (!err) {
        if (data.responseCode === CommonConstants.SUCCESS) {
          // 数据加载成功
          this.loadingCollectedStatus = LoadingStatus.SUCCESS;
          // 加载数据的处理
          this.dataSource.pushArrayData(data.result['data'] as Array<Model>);
        } else {
          // 数据加载失败
          this.loadingCollectedStatus = LoadingStatus.FAILED;
        }
      } else {
        // 数据加载失败
        this.loadingCollectedStatus = LoadingStatus.FAILED;
      }
    });
  }

  build() {
    NavDestination() {
      navDestinationTitle('5.1反例', () => {
        this.pathStack.pop();
      })
      Column() {
        // 加载列表
        ListView({ listData: this.dataSource })
      }
      .justifyContent(FlexAlign.Center)
      .height('90%')
      .width('100%')
    }
    .backgroundColor(Color.White)
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}