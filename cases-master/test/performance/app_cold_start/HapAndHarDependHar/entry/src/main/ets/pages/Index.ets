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

/*
 * “提升应用冷启动速度 - 减少多个HSP/HAP对于相同HAR的引用” 正例
 */

import { MainPage } from 'har_library';
import { funcResult } from 'har_common';

@Entry
@Component
struct Index {
  @State message: string = 'Hello World' + funcResult;

  build() {
    Row() {
      // 引用HSP的自定义组件
      MainPage()
    }
    .height('100%')
    .width('100%')
  }
}