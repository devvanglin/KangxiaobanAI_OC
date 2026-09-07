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
  badgeTextColor?: ResourceColor;
  badgeBackgroundColor?: ResourceColor;
  badgeAtCorner?: boolean;
}

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
  private slideTimerId: number = -1;

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

  aboutToDisappear(): void {
    if (this.slideTimerId >= 0) {
      clearInterval(this.slideTimerId);
      this.slideTimerId = -1;
    }
  }

  @Monitor('selectedIndex')
  onSelectedIndexChange(): void {
    if (this.selectedIndex === this.visualSelectedIndex) {
      return;
    }
    this.visualSelectedIndex = this.selectedIndex;
    const position: number = this.selectedPosition();
    if (position < 0 || position === this.animatedPosition) {
      return;
    }
    this.animatePillTo(position);
  }

  // 显式帧驱动滑动：不依赖 animateTo/.animation() 等隐式动画机制。实测隐式
  // 动画对该 translate 不生效（滑块瞬移），逐帧推进状态变量在任何环境都必然
  // 渲染出滑动过程；easeOutCubic 提供平滑减速的收尾手感。
  private animatePillTo(target: number): void {
    if (this.slideTimerId >= 0) {
      clearInterval(this.slideTimerId);
    }
    const start: number = this.animatedPosition;
    const startedAt: number = Date.now();
    const duration: number = 280;
    this.slideTimerId = setInterval((): void => {
      const progress: number = Math.min(1, (Date.now() - startedAt) / duration);
      const eased: number = 1 - Math.pow(1 - progress, 3);
      this.animatedPosition = start + (target - start) * eased;
      if (progress >= 1) {
        clearInterval(this.slideTimerId);
        this.slideTimerId = -1;
        this.animatedPosition = target;
      }
    }, 16);
  }

  private slideTo(index: number): void {
    if (index === this.visualSelectedIndex && index === this.selectedIndex) {
      return;
    }
    const position: number = this.items.findIndex((item: WideSlidingCapsuleItem) => item.index === index);
    if (position < 0) {
      return;
    }
    this.visualSelectedIndex = index;
    this.animatePillTo(position);
    // 选择必须同步上抛，不允许延迟：本组件挂在 HdsNavigation 标题栏的
    // stackBuilder 里，而标题栏 options（秒级时钟 mainTitle、返回键显隐等）
    // 每次父组件重渲都是新对象，stackBuilder 内容会被周期性销毁重建。此前的
    // "延迟 280ms + token 取消"机制在重建落在窗口内时会把 onSelect 整个吞掉，
    // 表现为点击后高亮滑过去又弹回、内容不切换。现在点击立即上抛，选择事实
    // 只存在于父级状态中；"先播动画再切内容"的体验由父级延迟挂载内容来保证
    // （MainPage.updateManagementNav 延迟 280ms 更新内容索引）。
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
