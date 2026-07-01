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

import { AppStorageV2, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  DividerShowType,
  hdsMaterial,
  HdsListItemCard,
  HdsNavDestination,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixArrow,
  SuffixText
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { BreakpointType } from '../util/BreakpointSystem';

type StepKey = 'info' | 'assess' | 'room' | 'care' | 'face';

interface StepMeta {
  key: StepKey;
  title: string;
}

interface FormRowData {
  label: string;
  value: string;
  placeholder?: string;
}

interface RoomData {
  id: string;
  room: string;
  type: string;
  floor: string;
  status: 'available' | 'occupied';
}

interface CarePackage {
  id: string;
  name: string;
  level: string;
  detail: string;
  price: string;
}

interface AssessItem {
  id: string;
  label: string;
  options: string[];
  selected: number;
}

@ComponentV2
export struct CheckInFlowPage {
  @Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local currentStep: number = 0;
  @Local selectedRoomId: string = '';
  @Local selectedCareId: string = 'care_2';
  @Local faceScanned: boolean = false;

  private steps(): StepMeta[] {
    return [
      { key: 'info', title: '信息填写' },
      { key: 'assess', title: '健康评估' },
      { key: 'room', title: '选择房间' },
      { key: 'care', title: '护理套餐' },
      { key: 'face', title: '扫脸登记' }
    ];
  }

  private contentTopPadding(): number {
    return this.globalInfoModel.statusBarHeight + 80;
  }

  private pagePadding(): number {
    return new BreakpointType<number>({
      sm: 16, md: 24, lg: 28, xl: 32
    }).getValue(this.globalInfoModel.widthBreakpoint);
  }

  private bottomBarHeight(): number {
    return 76;
  }

  private bottomPadding(): number {
    return this.bottomBarHeight() + 36;
  }

  // ---------------- data ----------------

  private formData(): FormRowData[] {
    return [
      { label: '姓名', value: '', placeholder: '请输入长者姓名' },
      { label: '性别', value: '', placeholder: '请选择' },
      { label: '出生日期', value: '', placeholder: '请选择日期' },
      { label: '身份证号', value: '', placeholder: '请输入身份证号' },
      { label: '联系电话', value: '', placeholder: '请输入手机号' },
      { label: '紧急联系人', value: '', placeholder: '请输入联系人姓名' },
      { label: '联系人关系', value: '', placeholder: '请选择关系' },
      { label: '联系人电话', value: '', placeholder: '请输入联系人手机号' }
    ];
  }

  private assessItems(): AssessItem[] {
    return [
      { id: 'a1', label: '自理能力', options: ['完全自理', '半自理', '不能自理'], selected: 0 },
      { id: 'a2', label: '行动能力', options: ['正常', '需搀扶', '轮椅', '卧床'], selected: 0 },
      { id: 'a3', label: '认知状态', options: ['清晰', '偶有遗忘', '认知障碍'], selected: 0 },
      { id: 'a4', label: '慢性病史', options: ['无', '高血压', '糖尿病', '心脏病', '其他'], selected: 0 },
      { id: 'a5', label: '过敏史', options: ['无', '药物过敏', '食物过敏'], selected: 0 },
      { id: 'a6', label: '饮食要求', options: ['正常', '低盐', '低糖', '流食'], selected: 0 }
    ];
  }

  private rooms(): RoomData[] {
    return [
      { id: 'rm1', room: '3F-302', type: '单人间', floor: '3楼东区', status: 'available' },
      { id: 'rm2', room: '3F-306', type: '单人间', floor: '3楼东区', status: 'available' },
      { id: 'rm3', room: '2F-201', type: '双人间A床', floor: '2楼西区', status: 'available' },
      { id: 'rm4', room: '2F-208', type: '双人间A床', floor: '2楼西区', status: 'available' },
      { id: 'rm5', room: '2F-215', type: '双人间B床', floor: '2楼西区', status: 'occupied' },
      { id: 'rm6', room: '3F-310', type: '套间', floor: '3楼东区', status: 'available' }
    ];
  }

  private carePackages(): CarePackage[] {
    return [
      { id: 'care_1', name: '基础护理', level: '三级', detail: '日常巡视 · 用药提醒 · 每日体征记录', price: '¥3,800/月' },
      { id: 'care_2', name: '标准护理', level: '二级', detail: '基础护理 · 每周医生查房 · 康复指导 · 情绪关怀', price: '¥5,600/月' },
      { id: 'care_3', name: '专属护理', level: '一级', detail: '标准护理 · 专属护工 · 每日医生查房 · 营养定制', price: '¥8,800/月' }
    ];
  }

  // ---------------- shared builders ----------------

  @Builder
  private sectionHeader(title: string) {
    Text(title)
      .fontSize($r('sys.float.Body_M'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
      .height(40)
  }

  @Builder
  private divider(isLast: boolean) {
    if (!isLast) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
    }
  }

  @Builder
  private stepIndicator() {
    Row({ space: 0 }) {
      ForEach(this.steps(), (step: StepMeta, index: number) => {
        Row({ space: 6 }) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(24)
              .height(24)
              .backgroundColor(index <= this.currentStep ?
                $r('sys.color.font_emphasize') : $r('sys.color.comp_background_secondary'))
              .borderRadius(12)
            Text(`${index + 1}`)
              .fontSize($r('sys.float.Caption_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor(index <= this.currentStep ?
                $r('sys.color.font_on_primary') : $r('sys.color.font_tertiary'))
          }
          .width(24)
          .height(24)

          if (index < this.steps().length - 1) {
            Row()
              .width(24)
              .height(2)
              .backgroundColor(index < this.currentStep ?
                $r('sys.color.font_emphasize') : $r('sys.color.comp_background_secondary'))
              .borderRadius(1)
          }
        }
      }, (item: StepMeta, index: number) => `step-${index}`)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: this.contentTopPadding(), bottom: 12 })
  }

  @Builder
  private bottomBar() {
    Row({ space: 12 }) {
      if (this.currentStep > 0) {
        Button('上一步')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .layoutWeight(1)
          .height(44)
          .borderRadius(12)
          .onClick(() => {
            this.currentStep--;
          })
      }

      Button(this.currentStep === this.steps().length - 1 ? '完成登记' : '下一步')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_on_primary'))
        .backgroundColor($r('sys.color.font_emphasize'))
        .layoutWeight(1)
        .height(44)
        .borderRadius(12)
        .onClick(() => {
          if (this.currentStep < this.steps().length - 1) {
            this.currentStep++;
          } else {
            this.pathStack.pop();
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  // ---------------- step 1: info ----------------

  @Builder
  private infoRow(item: FormRowData, isLast: boolean) {
    Row() {
      Text(item.label)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .width(88)

      TextInput({ placeholder: item.placeholder, text: item.value })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor('rgba(0,0,0,0)')
        .layoutWeight(1)
        .height(48)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))

    this.divider(isLast)
  }

  @Builder
  private stepInfo() {
    Column({ space: 0 }) {
      this.sectionHeader('基本信息')
      Column({ space: 0 }) {
        Repeat(this.formData())
          .each((repeatItem: RepeatItem<FormRowData>) => {
            this.infoRow(repeatItem.item, repeatItem.index === this.formData().length - 1)
          })
      }
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .clip(true)
    }
  }

  // ---------------- step 2: assess ----------------

  @Builder
  private assessRow(item: AssessItem, isLast: boolean) {
    Column({ space: 8 }) {
      Text(item.label)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))

      Scroll() {
        Row({ space: 8 }) {
          ForEach(item.options, (option: string, index: number) => {
            Text(option)
              .fontSize($r('sys.float.Body_S'))
              .fontColor(item.selected === index ?
                $r('sys.color.font_on_primary') : $r('sys.color.font_secondary'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(item.selected === index ?
                $r('sys.color.font_emphasize') : $r('sys.color.comp_background_secondary'))
              .borderRadius(16)
          }, (option: string, index: number) => `${item.id}-${index}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))

    this.divider(isLast)
  }

  @Builder
  private stepAssess() {
    Column({ space: 0 }) {
      this.sectionHeader('健康评估')
      Column({ space: 0 }) {
        Repeat(this.assessItems())
          .each((repeatItem: RepeatItem<AssessItem>) => {
            this.assessRow(repeatItem.item, repeatItem.index === this.assessItems().length - 1)
          })
      }
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .clip(true)
    }
  }

  // ---------------- step 3: room ----------------

  @Builder
  private roomRow(item: RoomData, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(
            item.status === 'available' ? $r('sys.symbol.house_fill') : $r('sys.symbol.house')
          )
            .fontColor([item.status === 'available' ?
              $r('sys.color.font_emphasize') : $r('sys.color.font_tertiary')])
        }
      }),
      textItem: {
        primaryText: {
          text: item.room
        },
        secondaryText: {
          text: `${item.type} · ${item.floor}`
        }
      },
      suffixItem: item.status === 'available' ?
        (this.selectedRoomId === item.id ?
          new SuffixText({ text: '已选' }) :
          new SuffixArrow({ color: $r('sys.color.font_tertiary') })) :
        new SuffixText({ text: '已占用' }),
      cardBorderRadius: 16,
      cardBackgroundColor: this.selectedRoomId === item.id ?
        $r('sys.color.comp_background_secondary') : 'rgba(0,0,0,0)',
      cardHeight: 64,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      onClick: () => {
        if (item.status === 'available') {
          this.selectedRoomId = item.id;
        }
      }
    })
      .border({
        width: {
          bottom: isLast ? 0 : 0.5
        },
        color: $r('sys.color.comp_divider')
      })
  }

  @Builder
  private stepRoom() {
    Column({ space: 0 }) {
      this.sectionHeader('选择房间')
      Column({ space: 0 }) {
        Repeat(this.rooms())
          .each((repeatItem: RepeatItem<RoomData>) => {
            this.roomRow(repeatItem.item, repeatItem.index === this.rooms().length - 1)
          })
      }
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .clip(true)
    }
  }

  // ---------------- step 4: care ----------------

  @Builder
  private careRow(item: CarePackage, isLast: boolean) {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text(item.name)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(`护理等级 · ${item.level}`)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(item.price)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_emphasize'))

        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(20)
            .height(20)
            .backgroundColor(this.selectedCareId === item.id ?
              $r('sys.color.font_emphasize') : 'rgba(0,0,0,0)')
            .borderRadius(10)
            .border({
              width: this.selectedCareId === item.id ? 0 : 1,
              color: $r('sys.color.comp_divider')
            })
          if (this.selectedCareId === item.id) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(12)
              .fontColor([$r('sys.color.font_on_primary')])
          }
        }
        .width(20)
        .height(20)
      }
      .width('100%')

      Text(item.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.selectedCareId === item.id ?
      $r('sys.color.comp_background_secondary') : $r('sys.color.comp_background_primary'))
    .borderRadius(this.selectedCareId === item.id ? 16 : 0)
    .onClick(() => {
      this.selectedCareId = item.id;
    })

    this.divider(isLast)
  }

  @Builder
  private stepCare() {
    Column({ space: 0 }) {
      this.sectionHeader('护理套餐')
      Column({ space: 0 }) {
        Repeat(this.carePackages())
          .each((repeatItem: RepeatItem<CarePackage>) => {
            this.careRow(repeatItem.item, repeatItem.index === this.carePackages().length - 1)
          })
      }
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .clip(true)
    }
  }

  // ---------------- step 5: face ----------------

  @Builder
  private stepFace() {
    Column({ space: 24 }) {
      this.sectionHeader('扫脸登记')

      Column({ space: 16 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(160)
            .height(160)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(80)
          if (this.faceScanned) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(64)
              .fontColor([$r('sys.color.font_emphasize')])
          } else {
            SymbolGlyph($r('sys.symbol.person_fill'))
              .fontSize(56)
              .fontColor([$r('sys.color.font_tertiary')])
          }
        }
        .width(160)
        .height(160)

        Text(this.faceScanned ? '登记成功' : '请将长者面部对准摄像头')
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.faceScanned ?
            $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))

        if (!this.faceScanned) {
          Button('开始扫脸')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor($r('sys.color.font_emphasize'))
            .height(44)
            .borderRadius(12)
            .padding({ left: 32, right: 32 })
            .onClick(() => {
              this.faceScanned = true;
            })
        }
      }
      .width('100%')
      .padding({ top: 32, bottom: 32 })
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
    }
  }

  // ---------------- page ----------------

  @Builder
  private stepContent() {
    if (this.currentStep === 0) {
      this.stepInfo();
    } else if (this.currentStep === 1) {
      this.stepAssess();
    } else if (this.currentStep === 2) {
      this.stepRoom();
    } else if (this.currentStep === 3) {
      this.stepCare();
    } else {
      this.stepFace();
    }
  }

  build() {
    HdsNavDestination() {
      Column({ space: 0 }) {
        this.stepIndicator()

        Scroll() {
          Column({ space: 16 }) {
            this.stepContent()
          }
          .width('100%')
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding(),
            bottom: this.bottomPadding()
          })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor($r('sys.color.background_secondary'))

        this.bottomBar()
      }
      .width('100%')
      .height('100%')
    }
    .backgroundColor($r('sys.color.background_secondary'))
    .titleBar({
      content: {
        title: {
          mainTitle: $r('app.string.check_in_page_title')
        },
        divider: {
          showType: DividerShowType.OFF
        }
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .onBackPressed(() => {
      if (this.currentStep > 0) {
        this.currentStep--;
        return true;
      }
      this.pathStack.pop();
      return true;
    })
    .width('100%')
    .height('100%')
  }
}
