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

import { SymbolGlyphModifier } from '@kit.ArkUI';
import { bundleManager } from '@kit.AbilityKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import {
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixArrow,
  SuffixSwitch,
  SuffixText,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import Logger from '../util/Logger';
import { PreferenceManager } from '../util/PreferenceManager';

export type MineDetailType = 'about' | 'general';

const TAG: string = '[MineDetailPage]';
const PREF_REDUCE_MOTION: string = 'general_reduce_motion';
const PREF_HAPTIC_FEEDBACK: string = 'general_haptic_feedback';
const PREF_OPERATION_SOUND: string = 'general_operation_sound';

@ComponentV2
struct SettingsGroupCard {
  @BuilderParam @Require content: () => void;

  build() {
    Column({ space: 0 }) {
      this.content()
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }
}

@ComponentV2
export struct MineDetailPage {
  @Param @Require pageType: MineDetailType;
  @Local versionName: string = '1.0.0';
  @Local versionCode: number = 1000000;
  @Local reduceMotion: boolean = false;
  @Local hapticFeedback: boolean = true;
  @Local operationSound: boolean = false;
  @Local isInfoSheetOpen: boolean = false;
  @Local infoSheetTitle: string = '';
  @Local infoSheetContent: string = '';
  private scroller: Scroller = new Scroller();
  private preferenceManager: PreferenceManager = PreferenceManager.getInstance();

  aboutToAppear(): void {
    this.loadBundleInfo();
    this.reduceMotion = this.readBoolean(PREF_REDUCE_MOTION, false);
    this.hapticFeedback = this.readBoolean(PREF_HAPTIC_FEEDBACK, true);
    this.operationSound = this.readBoolean(PREF_OPERATION_SOUND, false);
  }

  private async loadBundleInfo(): Promise<void> {
    try {
      const info: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      this.versionName = info.versionName;
      this.versionCode = info.versionCode;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      Logger.error(TAG, `load bundle info failed: ${error.code}, ${error.message}`);
    }
  }

  private readBoolean(key: string, fallback: boolean): boolean {
    return this.preferenceManager.getValue<boolean>(key, JSON.stringify(fallback)) ?? fallback;
  }

  private saveBoolean(key: string, value: boolean): void {
    this.preferenceManager.setValue<boolean>(key, value);
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      Logger.error(TAG, `show toast failed: ${JSON.stringify(err)}`);
    }
  }

  private pageTitle(): string {
    return this.pageType === 'about' ? '关于我们' : '通用设置';
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  private openInfoSheet(title: string, content: string): void {
    this.infoSheetTitle = title;
    this.infoSheetContent = content;
    this.isInfoSheetOpen = true;
  }

  private resetGeneralSettings(): void {
    this.reduceMotion = false;
    this.hapticFeedback = true;
    this.operationSound = false;
    this.saveBoolean(PREF_REDUCE_MOTION, this.reduceMotion);
    this.saveBoolean(PREF_HAPTIC_FEEDBACK, this.hapticFeedback);
    this.saveBoolean(PREF_OPERATION_SOUND, this.operationSound);
    this.showToast('已恢复默认设置');
  }

  private confirmResetGeneralSettings(): void {
    try {
      this.getUIContext().showAlertDialog({
        title: '恢复默认设置',
        message: '将恢复显示与交互偏好，不会删除账号、消息、护理记录或长者数据。',
        autoCancel: true,
        alignment: DialogAlignment.Center,
        buttonDirection: DialogButtonDirection.HORIZONTAL,
        buttons: [
          {
            value: '取消',
            action: () => {
            }
          },
          {
            value: '恢复',
            fontColor: $r('app.color.status_danger'),
            action: () => {
              this.resetGeneralSettings();
            }
          }
        ]
      });
    } catch (err) {
      Logger.error(TAG, `show reset dialog failed: ${JSON.stringify(err)}`);
    }
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize($r('sys.float.Body_S'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 4, bottom: 8 })
  }

  @Builder
  private divider(isLast: boolean) {
    if (!isLast) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 52 })
    }
  }

  @Builder
  private infoRow(icon: Resource, title: string, value: string, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        prefixItem: new PrefixIcon({
          iconSize: IconSize.SYSTEM_ICON,
          iconValue: {
            symbol: new SymbolGlyphModifier(icon)
              .fontColor([$r('sys.color.font_primary')])
          }
        }),
        textItem: {
          primaryText: { text: title }
        },
        suffixItem: new SuffixText({ text: value }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 54,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
      this.divider(isLast)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private linkRow(icon: Resource, title: string, isLast: boolean, action: () => void) {
    Column({ space: 0 }) {
      HdsListItemCard({
        prefixItem: new PrefixIcon({
          iconSize: IconSize.SYSTEM_ICON,
          iconValue: {
            symbol: new SymbolGlyphModifier(icon)
              .fontColor([$r('sys.color.font_primary')])
          }
        }),
        textItem: {
          primaryText: { text: title }
        },
        suffixItem: new SuffixArrow({ color: $r('sys.color.font_tertiary') }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 54,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
      this.divider(isLast)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(action)
  }

  @Builder
  private toggleRow(title: string, description: string, isOn: boolean, isLast: boolean,
    onChange: (isOn: boolean) => void) {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: title },
          secondaryText: { text: description }
        },
        suffixItem: new SuffixSwitch({
          isCheck: isOn,
          selectColor: $r('app.color.brand_blue'),
          onChange: onChange
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 64,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
      if (!isLast) {
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private aboutHero() {
    Column({ space: 8 }) {
      Image($r('app.media.startIcon'))
        .width(80)
        .height(80)
        .borderRadius(20)
        .draggable(false)
      Text('康小伴 AI')
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text('养老护理工作助手')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text(`版本 ${this.versionName}`)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private aboutContent() {
    this.aboutHero()

    Column({ space: 0 }) {
      this.sectionTitle('版本与产品')
      SettingsGroupCard({ content: () => {
        this.infoRow($r('sys.symbol.info_circle'), '版本信息', `${this.versionName}（构建 ${this.versionCode}）`, false)
        this.linkRow($r('sys.symbol.AI_message'), '产品介绍', true, () => {
          this.openInfoSheet('产品介绍',
            '康小伴 AI 面向养老护理工作场景，帮助护理人员整理提醒、沟通信息和长者状态。应用提供的是工作辅助信息，不替代医嘱、护理规范或紧急处置流程。');
        })
      } })
    }
    .width('100%')

    Column({ space: 0 }) {
      this.sectionTitle('隐私与法律')
      SettingsGroupCard({ content: () => {
        this.linkRow($r('sys.symbol.doc_text'), '用户协议', false, () => {
          this.openInfoSheet('用户协议',
            '使用康小伴 AI 时，请遵守所在机构的账号、护理记录和信息安全规范。不得冒用他人身份、传播敏感数据或将辅助建议直接替代专业判断。');
        })
        this.linkRow($r('sys.symbol.shield_checkered'), '隐私政策', false, () => {
          this.openInfoSheet('隐私政策',
            '应用仅在提供护理工作功能所必需的范围内处理账号、业务记录和设备设置。健康、身份、联系方式和护理记录属于敏感信息，应按机构授权和最小必要原则访问。');
        })
        this.linkRow($r('sys.symbol.AI_message'), 'AI 功能与数据使用说明', false, () => {
          this.openInfoSheet('AI 功能与数据使用说明',
            'AI 生成内容用于信息整理和工作建议，可能存在遗漏或偏差。涉及健康、安全、用药和紧急事件时，必须由工作人员核验，并按照机构制度完成处置。');
        })
        this.linkRow($r('sys.symbol.doc_text'), '开源软件声明', true, () => {
          this.openInfoSheet('开源软件声明',
            '应用使用的开源软件遵循各自许可证。正式发布版本将随应用提供完整的开源组件、版权信息和许可证清单。');
        })
      } })
    }
    .width('100%')

    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.shield_checkered'))
        .fontSize(20)
        .fontColor([$r('app.color.brand_blue')])
      Text('发现健康或安全风险时，请立即按照机构制度处理。')
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private generalContent() {
    Column({ space: 0 }) {
      this.sectionTitle('显示')
      SettingsGroupCard({ content: () => {
        this.infoRow($r('sys.symbol.paintpalette'), '外观模式', '跟随系统', false)
        this.infoRow($r('sys.symbol.doc_text'), '字体大小', '跟随系统', false)
        this.toggleRow('减少动态效果', '减少页面切换和展开动画', this.reduceMotion, true, (isOn: boolean) => {
          this.reduceMotion = isOn;
          this.saveBoolean(PREF_REDUCE_MOTION, isOn);
        })
      } })
    }
    .width('100%')

    Column({ space: 0 }) {
      this.sectionTitle('交互')
      SettingsGroupCard({ content: () => {
        this.toggleRow('触感反馈', '操作成功或状态变化时提供轻触反馈', this.hapticFeedback, false,
          (isOn: boolean) => {
            this.hapticFeedback = isOn;
            this.saveBoolean(PREF_HAPTIC_FEEDBACK, isOn);
          })
        this.toggleRow('操作提示音', '重要操作完成时播放提示音', this.operationSound, true,
          (isOn: boolean) => {
            this.operationSound = isOn;
            this.saveBoolean(PREF_OPERATION_SOUND, isOn);
          })
      } })
    }
    .width('100%')

    Column({ space: 0 }) {
      this.sectionTitle('语言与时间')
      SettingsGroupCard({ content: () => {
        this.infoRow($r('sys.symbol.doc_text'), '应用语言', '跟随系统', false)
        this.infoRow($r('sys.symbol.calendar_badge_clock'), '时间格式', '跟随系统', true)
      } })
    }
    .width('100%')

    Row() {
      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
        .fontSize(20)
        .fontColor([$r('app.color.status_danger')])
      Text('恢复默认设置')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.status_danger'))
        .margin({ left: 12 })
      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.confirmResetGeneralSettings();
    })

    Text('设置保存在当前设备。系统无障碍字号和减少动态效果设置具有更高优先级。')
      .fontSize($r('sys.float.Caption_M'))
      .fontColor($r('sys.color.font_tertiary'))
      .width('100%')
      .padding({ left: 4, right: 4 })
  }

  @Builder
  private infoSheetBuilder() {
    Scroll() {
      Text(this.infoSheetContent)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(28)
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Row() {
          Column({ space: 18 }) {
            if (this.pageType === 'about') {
              this.aboutContent()
            } else {
              this.generalContent()
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({ left: 16, right: 16, top: 104, bottom: 40 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .bindSheet(this.isInfoSheetOpen, this.infoSheetBuilder, {
        detents: [SheetSize.MEDIUM],
        showClose: true,
        dragBar: true,
        title: { title: this.infoSheetTitle },
        backgroundColor: $r('sys.color.background_secondary'),
        onDisappear: () => {
          this.isInfoSheetOpen = false;
        }
      })
    }
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: this.pageTitle() }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
