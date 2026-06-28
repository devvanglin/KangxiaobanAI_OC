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

import { promptAction } from '@kit.ArkUI';
import LazyDataSource from '../model/LazyDataSource';
import { Model } from '../model/Model';
import { CommonConstants } from '../common/CommonConstants';
import { ReusableItemView } from './ReusableItemView';

@Component
export struct ReusableListView {
  @Link listData: LazyDataSource<Model>;
  @State selectedId: number = -1; // 刚加载完成无选中状态

  build() {
    Column() {
      List({ space: CommonConstants.SPACE_12 }) {
        LazyForEach(this.listData, (item: Model) => {
          ListItem() {
            ReusableItemView({ item: item, isSelected: this.selectedId === item.id })
              .reuseId('reuse_item_' + item.type)
          }
          .onClick(() => {
            this.selectedId = item.id;
            promptAction.showToast({ message: $r('app.string.ske_prompt_text') });
          })
        }, (item: Model) => item.id.toString())
      }
      .id('skeleton_list')
      .padding({
        left: $r("app.float.ske_md_padding_margin"),
        right: $r("app.float.ske_md_padding_margin")
      })
      .width(CommonConstants.FULL_PERCENT)
      .height(CommonConstants.FULL_PERCENT)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
  }
}

