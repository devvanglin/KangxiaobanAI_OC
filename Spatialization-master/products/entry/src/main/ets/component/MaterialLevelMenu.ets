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

import { AppStorageV2, LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { hdsMaterial } from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';

@ComponentV2
struct MenuComponent {
  @Local customMaterialLevel: MaterialLevelItem =
    AppStorageV2.connect(MaterialLevelItem, StorageKey.MATERIAL_LEVEL) ?? new MaterialLevelItem();
  endIconModifier: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.checkmark'));

  build() {
    Menu() {
      ForEach(materialLevelItems, (item: MaterialLevelItem) => {
        MenuItem({
          content: item.title,
          symbolEndIcon: this.customMaterialLevel.level === item.level ? this.endIconModifier : undefined
        })
          .onChange((selected: boolean) => {
            if (selected) {
              this.customMaterialLevel.level = item.level;
            }
          })
      }, (item: MaterialLevelItem)=>item.level.toString())

    }
    .backgroundColor(Color.Transparent)
    .width(224)
    .menuItemDivider({
      strokeWidth: LengthMetrics.px(1),
      color: $r('sys.color.comp_divider'),
      startMargin: LengthMetrics.vp(16),
    })
  }
}

const materialLevelItems: MaterialLevelItem[] = [
  { title: $r('app.string.strong'), level: hdsMaterial.MaterialLevel.EXQUISITE },
  { title: $r('app.string.balanced'), level: hdsMaterial.MaterialLevel.GENTLE },
  { title: $r('app.string.weak'), level: hdsMaterial.MaterialLevel.SMOOTH }];

@Builder
export function materialLevelMenu() {
  MenuComponent()
}

@ObservedV2
export class MaterialLevelItem {
  public title: ResourceStr = '';
  @Trace public level: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.GENTLE;
}