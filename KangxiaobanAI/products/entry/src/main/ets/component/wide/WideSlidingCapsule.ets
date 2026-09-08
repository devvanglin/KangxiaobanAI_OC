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

import { curves } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';

export interface WideSlidingCapsuleItem {
  title: string;
  index: number;
  symbol?: Resource;
  badgeText?: string;
  badgeTextColor?: ResourceColor;
  badgeBackgroundColor?: ResourceColor;
  badgeAtCorner?: boolean;
}

// 滑块位移由显式 animateTo + 临界阻尼弹簧补间（见 applySelection）：到位即停
// 不过冲，快速连点时按 springMotion 语义继承当前值与速度。本组件由父级挂在
// 页面稳定节点上（不再进 HdsNavigation 标题栏 stackBuilder），实例生命周期
// 稳定，补间不会被标题栏重建打断；可靠性约定仍是：点击同步上抛，父级把
// 最新选中索引回传给 selectedIndex。

@ComponentV2
export struct WideSlidingCapsule {
  @Param @Require items: WideSlidingCapsuleItem[];
  @Param @Require selectedIndex: number;
  @Param @Require itemWidth: number;
  @Param itemFontSize: number = 16;
  @Param fillWidth: boolean = false;
  @Param iconOnly: boolean = false;
  @Event onSelect: (index: number) => void = (_index: number) => {};
  @Local hoveredIndex: number = -1;
  @Local focusedIndex: number = -1;
  @Local measuredWidth: number = 0;
  @Local animatedPosition: number = 0;
  @Local visualSelectedIndex: number = -1;

  private selectedPosition(): number {
    return this.items.findIndex((item: WideSlidingCapsuleItem) => item.index === this.visualSelectedIndex);
  }

  private selectionOffset(): number {
    return this.animatedPosition * (this.effectiveItemWidth() + 4);
  }

  aboutToAppear(): void {
    this.visualSelectedIndex = this.selectedIndex;
    const position: number = this.selectedPosition();
    this.animatedPosition = position < 0 ? 0 : position;
  }

  @Monitor('selectedIndex')
  onSelectedIndexChange(): void {
    if (this.selectedIndex === this.visualSelectedIndex) {
      return;
    }
    this.applySelection(this.selectedIndex);
  }

  private applySelection(index: number): void {
    const position: number = this.items.findIndex((item: WideSlidingCapsuleItem) => item.index === index);
    if (position < 0) {
      return;
    }
    this.visualSelectedIndex = index;
    // 临界阻尼弹簧（阻尼系数 1）：到位即停，不会滑过目标再弹回；
    // 快速连点时按 springMotion 语义继承当前值与速度，反向衔接平滑。
    // 时长由弹簧参数与属性变化量自动决定，不手动指定 duration。
    this.getUIContext().animateTo({ curve: curves.springMotion(0.3, 1.0) }, (): void => {
      this.animatedPosition = position;
    });
  }

  private slideTo(index: number): void {
    if (index === this.visualSelectedIndex && index === this.selectedIndex) {
      return;
    }
    if (this.items.findIndex((item: WideSlidingCapsuleItem) => item.index === index) < 0) {
      return;
    }
    // 选择必须同步上抛，不允许延迟：历史上本组件挂在标题栏 stackBuilder 里，
    // "延迟上抛 + token 取消"机制在宿主重建落在窗口内时会把 onSelect 整个吞掉，
    // 表现为点击后高亮滑过去又弹回、内容不切换。现在点击立即上抛，选中与内容
    // 同帧切换；宿主已稳定，补间总能完整播放。
    this.applySelection(index);
    this.onSelect(index);
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

  private badgeTextColor(item: WideSlidingCapsuleItem): ResourceColor {
    if (item.badgeTextColor !== undefined) {
      return item.badgeTextColor;
    }
    return this.visualSelectedIndex === item.index ? $r('app.color.brand_blue') : $r('sys.color.font_secondary');
  }

  private badgeBackgroundColor(item: WideSlidingCapsuleItem): ResourceColor {
    if (item.badgeBackgroundColor !== undefined) {
      return item.badgeBackgroundColor;
    }
    return this.visualSelectedIndex === item.index ? $r('sys.color.comp_background_secondary') :
      $r('sys.color.comp_background_primary');
  }

  private showInlineBadge(item: WideSlidingCapsuleItem): boolean {
    return item.badgeText !== undefined && item.badgeAtCorner !== true;
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  @Builder
  private capsuleItem(item: WideSlidingCapsuleItem) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row({ space: this.iconOnly || (item.symbol === undefined && !this.showInlineBadge(item)) ? 0 : 7 }) {
        if (item.symbol !== undefined) {
          SymbolGlyph(item.symbol)
            .fontSize(this.iconOnly ? 19 : 17)
            .fontColor([this.visualSelectedIndex === item.index ? $r('app.color.brand_blue') :
              $r('sys.color.icon_secondary')])
        }

        if (!this.iconOnly) {
          Text(item.title)
            .fontSize(this.itemFontSize)
            .fontWeight(this.visualSelectedIndex === item.index ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.visualSelectedIndex === item.index ? $r('app.color.brand_blue') :
              $r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        if (this.showInlineBadge(item)) {
          Text(item.badgeText)
            .fontSize($r('sys.float.Caption_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.badgeTextColor(item))
            .width(22)
            .height(22)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.badgeBackgroundColor(item))
            .borderRadius(11)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: this.iconOnly ? 0 : 12, right: this.iconOnly ? 0 : 12 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      if (item.badgeText !== undefined && item.badgeAtCorner === true) {
        Text(item.badgeText)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.badgeTextColor(item))
          .width(18)
          .height(18)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.badgeBackgroundColor(item))
          .borderRadius(9)
          .margin({ top: 1, right: 3 })
      }
    }
    .width(this.effectiveItemWidth())
    .height(38)
    .borderRadius(19)
    .backgroundColor(this.visualSelectedIndex !== item.index && this.hoveredIndex === item.index ?
      $r('sys.color.interactive_hover') : Color.Transparent)
    .border({
      width: this.focusedIndex === item.index ? 2 : 0,
      color: $r('app.color.brand_blue')
    })
    .focusable(true)
    .focusOnTouch(true)
    .accessibilityText(this.accessibilityLabel(item))
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilitySelected(this.visualSelectedIndex === item.index)
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
      this.activateWithKeyboard(event, () => this.slideTo(item.index));
    })
    .onClick(() => {
      this.slideTo(item.index);
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

      Row({ space: 4 }) {
        ForEach(this.items, (item: WideSlidingCapsuleItem) => {
          this.capsuleItem(item)
        // Badge values are often derived from an async server snapshot. Include
        // the rendered badge in the key so a reused capsule item cannot retain
        // its initial count when the parent supplies a new items array.
        }, (item: WideSlidingCapsuleItem) => `${item.index}-${item.title}-${item.badgeText ?? ''}`)
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
