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
 * “提升应用冷启动速度 - 合理拆分导出文件，减少冗余文件执行” 优化方案二：导入冷启动文件时全路径展开
 */

import { MainPage } from 'library/src/main/ets/components/mainpage/MainPage';

@Entry
@Component
export struct Index {
  @Provide pathStack: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.pathStack) {
      Row() {
        // 引用HAR的自定义组件
        MainPage()
      }
    }
    .width('100%')
    .height('100%')
  }
}