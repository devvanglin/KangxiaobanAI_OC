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

import { AppStorageV2 } from '@kit.ArkUI';
import {
  DividerShowType,
  hdsMaterial,
  HdsNavDestination,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';

interface CheckInStep {
  title: string;
  status: string;
}

interface CheckInInfoRow {
  label: string;
  value: string;
}

interface CheckInChecklistItem {
  title: string;
  detail: string;
}

@ComponentV2
export struct CheckInFlowPage {
  @Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();

  private contentTopPadding(): number {
    return this.globalInfoModel.statusBarHeight + 84;
  }

  private steps(): CheckInStep[] {
    return [
      {
        title: '资料确认',
        status: '当前'
      },
      {
        title: '房间床位',
        status: '待办'
      },
      {
        title: '健康初评',
        status: '待办'
      },
      {
        title: '交接完成',
        status: '末步'
      }
    ];
  }

  private infoRows(): CheckInInfoRow[] {
    return [
      {
        label: '入住长者',
        value: '肖爷爷'
      },
      {
        label: '预计到院',
        value: '14:30'
      },
      {
        label: '家属联系人',
        value: '女儿 / 已尝试回电'
      },
      {
        label: '预留床位',
        value: '3F-302 / 靠窗'
      }
    ];
  }

  private checklistItems(): CheckInChecklistItem[] {
    return [
      {
        title: '核验基础信息',
        detail: '确认身份、既往病史、过敏信息和紧急联系人。'
      },
      {
        title: '同步护理计划',
        detail: '根据饮食、用药、作息和情绪风险建立首日提醒。'
      },
      {
        title: '通知值班组',
        detail: '把家属联络情况、情绪线索和夜间观察点写入交接摘要。'
      }
    ];
  }

  @Builder
  private pill(text: string, backgroundColor: ResourceColor, fontColor: ResourceColor = '#344054') {
    Text(text)
      .fontSize($r('sys.float.Caption_M'))
      .fontColor(fontColor)
      .padding({
        left: $r('sys.float.padding_level3'),
        right: $r('sys.float.padding_level3'),
        top: 4,
        bottom: 4
      })
      .backgroundColor(backgroundColor)
      .borderRadius($r('sys.float.corner_radius_level8'))
  }

  @Builder
  private sectionTitle(title: string, detail: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stepRow(step: CheckInStep, index: number) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(30)
          .height(30)
          .fill(index === 0 ? '#1F8EFA' : '#E8ECF2')
        Text(`${index + 1}`)
          .fontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor(index === 0 ? '#FFFFFF' : '#344054')
      }
      Text(step.title)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_primary'))
      this.pill(step.status, index === 0 ? '#EAF3FF' : '#F2F4F7', index === 0 ? '#245BDB' : '#475467')
    }
    .width(72)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private infoRow(row: CheckInInfoRow, isLast: boolean) {
    Row() {
      Text(row.label)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
      Blank()
      Text(row.value)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
    }
    .padding({
      top: $r('sys.float.padding_level4'),
      bottom: $r('sys.float.padding_level4')
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E8EAED'
    })
  }

  @Builder
  private checklistRow(item: CheckInChecklistItem, isLast: boolean) {
    Row({ space: $r('sys.float.padding_level4') }) {
      Circle()
        .width(8)
        .height(8)
        .fill('#1F8EFA')
        .margin({ top: 7 })

      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(item.detail)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .padding({
      top: $r('sys.float.padding_level4'),
      bottom: $r('sys.float.padding_level4')
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E8EAED'
    })
  }

  build() {
    HdsNavDestination() {
      List({ space: 16 }) {
        ListItem() {
          Column({ space: 16 }) {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 4 }) {
                  Text('入住登记')
                    .fontSize($r('sys.float.Title_S'))
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.font_primary'))
                  Text('把资料确认、房间安排、健康初评和交接摘要一次完成。')
                    .fontSize($r('sys.float.Body_S'))
                    .fontColor($r('sys.color.font_secondary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                this.pill('剩余床位 XX', '#EEF2F6')
              }

              Row({ space: $r('sys.float.padding_level5') }) {
                Column({ space: 2 }) {
                  Text('3')
                    .fontSize($r('sys.float.Title_L'))
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.font_primary'))
                  Text('今日待办理')
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor($r('sys.color.font_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Column({ space: 2 }) {
                  Text('1')
                    .fontSize($r('sys.float.Title_L'))
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.font_primary'))
                  Text('家属未接通')
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor($r('sys.color.font_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Column({ space: 2 }) {
                  Text('14:30')
                    .fontSize($r('sys.float.Title_L'))
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.font_primary'))
                  Text('预计到院')
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor($r('sys.color.font_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
            }
            .padding($r('sys.float.padding_level6'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)

            Column({ space: 14 }) {
              this.sectionTitle('流程', '保持简洁，先确认信息，再做床位与交接。')
              Row() {
                Repeat(this.steps())
                  .each((repeatItem: RepeatItem<CheckInStep>) => {
                    this.stepRow(repeatItem.item, repeatItem.index)
                    if (repeatItem.index < this.steps().length - 1) {
                      Blank()
                        .height(1)
                        .layoutWeight(1)
                        .backgroundColor('#D8DEE6')
                        .margin({ top: 15, left: 8, right: 8 })
                    }
                  })
              }
              .alignItems(VerticalAlign.Top)
            }
            .padding($r('sys.float.padding_level6'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)
          }
        }
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          top: this.contentTopPadding()
        })

        ListItem() {
          Column({ space: 12 }) {
            this.sectionTitle('入住对象', '护工先看到最关键的信息，不把页面做成冗长表单。')
            Column() {
              Repeat(this.infoRows())
                .each((repeatItem: RepeatItem<CheckInInfoRow>) => {
                  this.infoRow(repeatItem.item, repeatItem.index === this.infoRows().length - 1)
                })
            }
            .padding($r('sys.float.padding_level6'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)
          }
        }
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8')
        })

        ListItem() {
          Column({ space: 12 }) {
            this.sectionTitle('办理清单', '重点不是填很多东西，而是把首日照护真正准备好。')
            Column() {
              Repeat(this.checklistItems())
                .each((repeatItem: RepeatItem<CheckInChecklistItem>) => {
                  this.checklistRow(repeatItem.item, repeatItem.index === this.checklistItems().length - 1)
                })
            }
            .padding($r('sys.float.padding_level6'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(20)
          }
        }
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          bottom: 48
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor('#F5F7FA')
    }
    .backgroundColor('#F5F7FA')
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
      this.pathStack.pop();
      return true;
    })
    .width('100%')
    .height('100%')
  }
}
