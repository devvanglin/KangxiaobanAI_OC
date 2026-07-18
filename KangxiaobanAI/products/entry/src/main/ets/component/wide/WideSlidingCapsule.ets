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

import { KeyCode } from '@kit.InputKit';

export interface WideSlidingCapsuleItem {
  title: string;
  index: number;
  symbol?: Resource;
  badgeText?: string;
}

@ComponentV2
export struct WideSlidingCapsule {
  @Param @Require items: WideSlidingCapsuleItem[];
  @Param @Require selectedIndex: number;
  @Param @Require itemWidth: number;
  @Param fillWidth: boolean = false;
  @Event onSelect: (index: number) => void = (_index: number) => {};
  @Local hoveredIndex: number = -1;
  @Local focusedIndex: number = -1;
  @Local measuredWidth: number = 0;

  private selectedPosition(): number {
    return this.items.findIndex((item: WideSlidingCapsuleItem) => item.index === this.selectedIndex);
  }

  private selectionOffset(): number {
    const position: number = this.selectedPosition();
    return position < 0 ? 0 : position * (this.effectiveItemWidth() + 4);
  }

  private containerWidth(): number {
    return this.items.length * this.itemWidth + Math.max(0, this.items.length - 1) * 4 + 6;
  }

  private effectiveItemWidth(): number {
    if (!this.fillWidth || this.measuredWidth <= 0 || this.items.length === 0) {
      return this.itemWidth;
    }
    const fixedWidth: number = Math.max(0, this.items.length - 1) * 4 + 6;
    return Math.max(1, (this.measuredWidth - fixedWidth) / this.items.length);
  }

  private updateMeasuredWidth(width: Length): void {
    let nextWidth: number = 0;
    if (typeof width === 'number') {
      nextWidth = width;
    } else if (typeof width === 'string') {
      nextWidth = parseFloat(width);
    }
    if (nextWidth > 0 && Math.abs(nextWidth - this.measuredWidth) > 0.5) {
      this.measuredWidth = nextWidth;
    }
  }

  private accessibilityLabel(item: WideSlidingCapsuleItem): string {
    return item.badgeText === undefined ? item.title : `${item.title} ${item.badgeText}`;
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  @Builder
  private capsuleItem(item: WideSlidingCapsuleItem) {
    Row({ space: item.symbol === undefined && item.badgeText === undefined ? 0 : 7 }) {
      if (item.symbol !== undefined) {
        SymbolGlyph(item.symbol)
          .fontSize(17)
          .fontColor([this.selectedIndex === item.index ? $r('app.color.brand_blue') :
            $r('sys.color.icon_secondary')])
      }

      Text(item.title)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(this.selectedIndex === item.index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selectedIndex === item.index ? $r('app.color.brand_blue') :
          $r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (item.badgeText !== undefined) {
        Text(item.badgeText)
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedIndex === item.index ? $r('app.color.brand_blue') :
            $r('sys.color.font_secondary'))
          .width(22)
          .height(22)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.selectedIndex === item.index ? $r('sys.color.comp_background_secondary') :
            $r('sys.color.comp_background_primary'))
          .borderRadius(11)
      }
    }
    .width(this.effectiveItemWidth())
    .height(38)
    .padding({ left: 12, right: 12 })
    .borderRadius(19)
    .backgroundColor(this.selectedIndex !== item.index && this.hoveredIndex === item.index ?
      $r('sys.color.interactive_hover') : Color.Transparent)
    .border({
      width: this.focusedIndex === item.index ? 2 : 0,
      color: $r('app.color.brand_blue')
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .focusable(true)
    .focusOnTouch(true)
    .accessibilityText(this.accessibilityLabel(item))
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilitySelected(this.selectedIndex === item.index)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onFocus(() => {
      this.focusedIndex = item.index;
    })
    .onBlur(() => {
      if (this.focusedIndex === item.index) {
        this.focusedIndex = -1;
      }
    })
    .onHover((isHover: boolean) => {
      this.hoveredIndex = isHover ? item.index : -1;
    })
    .onKeyEvent((event: KeyEvent) => {
      this.activateWithKeyboard(event, () => this.onSelect(item.index));
    })
    .onClick(() => {
      this.onSelect(item.index);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width(this.effectiveItemWidth())
        .height(38)
        .borderRadius(19)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .shadow({ radius: 6, color: 'rgba(0,0,0,0.05)', offsetY: 1 })
        .translate({ x: this.selectionOffset() })
        .opacity(this.selectedPosition() >= 0 ? 1 : 0)
        .animation({ duration: 260, curve: Curve.Friction })

      Row({ space: 4 }) {
        ForEach(this.items, (item: WideSlidingCapsuleItem) => {
          this.capsuleItem(item)
        }, (item: WideSlidingCapsuleItem) => item.index.toString())
      }
    }
    .width(this.fillWidth ? '100%' : this.containerWidth())
    .height(44)
    .padding(3)
    .borderRadius(22)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      if (this.fillWidth) {
        this.updateMeasuredWidth(newValue.width);
      }
    })
  }
}
