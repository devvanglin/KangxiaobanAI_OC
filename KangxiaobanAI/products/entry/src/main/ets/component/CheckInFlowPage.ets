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
import { BreakpointType } from '../util/BreakpointSystem';

interface CheckInStep {
  title: string;
  status: string;
  detail: string;
}

interface KeyValueData {
  label: string;
  value: string;
  detail: string;
}

interface ReadyItem {
  title: string;
  detail: string;
}

@ComponentV2
export struct CheckInFlowPage {
  @Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();

  private contentTopPadding(): number {
    return this.globalInfoModel.statusBarHeight + 68;
  }

  private isWideLayout(): boolean {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    return widthBreakpoint === WidthBreakpoint.WIDTH_MD ||
      widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  private pagePadding(): number {
    return new BreakpointType<number>({
      sm: 16,
      md: 24,
      lg: 28,
      xl: 32
    }).getValue(this.globalInfoModel.widthBreakpoint);
  }

  private cardRadius(): number {
    return this.isWideLayout() ? 16 : 14;
  }

  private steps(): CheckInStep[] {
    return [
      {
        title: '资料核验',
        status: '当前',
        detail: '身份、病史、过敏与家属授权'
      },
      {
        title: '床位安排',
        status: '待办',
        detail: '房间、陪护、呼叫器与安全标识'
      },
      {
        title: '照护初评',
        status: '待办',
        detail: '生命体征、风险等级与作息习惯'
      },
      {
        title: '交接同步',
        status: '末步',
        detail: '护理站、值班组与家属摘要'
      }
    ];
  }

  private baseInfo(): KeyValueData[] {
    return [
      {
        label: '入住长者',
        value: '肖爷爷',
        detail: '家属送住，首次接入情绪主动关怀方案'
      },
      {
        label: '预计到院',
        value: '14:30',
        detail: '资料袋与病历摘要已到护理站'
      },
      {
        label: '预留床位',
        value: '3F-302',
        detail: '靠窗，靠近护理呼叫点，便于夜间观察'
      },
      {
        label: '主要联系人',
        value: '女儿',
        detail: '电话暂未接通，建议晚饭后再次回访'
      }
    ];
  }

  private readyItems(): ReadyItem[] {
    return [
      {
        title: '基础资料齐备',
        detail: '入住表、身份证明、过敏史、家属授权书和既往病史需全部存档。'
      },
      {
        title: '房间环境就绪',
        detail: '床品、扶手、防滑设施、呼叫器、夜灯和安全标识全部完成检查。'
      },
      {
        title: '首日照护计划',
        detail: '饮食、用药、康复、作息和夜间巡视频次要在入住后立即同步。'
      }
    ];
  }

  @Builder
  private tag(text: string, backgroundColor: ResourceColor, fontColor: ResourceColor = '#305C88') {
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
      .borderRadius(10)
  }

  @Builder
  private sectionTitle(title: string, detail: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor('#526277')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stepCard(step: CheckInStep, index: number) {
    Column({ space: 10 }) {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(32)
            .height(32)
            .backgroundColor(index === 0 ? '#1D63ED' : '#EFF4FA')
            .borderRadius(12)
          Text(`${index + 1}`)
            .fontSize($r('sys.float.Caption_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor(index === 0 ? '#FFFFFF' : '#45617E')
        }
        .width(32)
        .height(32)
        Blank()
        this.tag(step.status, index === 0 ? '#EAF1FD' : '#F3F6FA', index === 0 ? '#1D63ED' : '#526277')
      }
      Text(step.title)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(step.detail)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor('#526277')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level5'))
    .layoutWeight(1)
    .backgroundColor('#FFFFFF')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#DCE5EF'
    })
  }

  @Builder
  private infoRow(item: KeyValueData, isLast: boolean) {
    Row() {
      Column({ space: 2 }) {
        Text(item.label)
          .fontSize($r('sys.float.Body_S'))
          .fontColor('#6B7C93')
        Text(item.detail)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#526277')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(item.value)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
    }
    .padding({
      top: 12,
      bottom: 12
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E4EAF1'
    })
  }

  @Builder
  private readyRow(item: ReadyItem, isLast: boolean) {
    Row({ space: 12 }) {
      Blank()
        .width(8)
        .height(8)
        .backgroundColor('#1D63ED')
        .borderRadius(4)
        .margin({ top: 7 })

      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
        Text(item.detail)
          .fontSize($r('sys.float.Body_S'))
          .fontColor('#526277')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .padding({
      top: 12,
      bottom: 12
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E4EAF1'
    })
  }

  @Builder
  private summaryHero() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('入住登记')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#C3D2E2')
          Text('首日办理工作台')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FBFF')
          Text('围绕资料、床位、照护计划与交接同步，做一套真正适合护工端的入住流程。')
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#D8E4F0')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.tag('可用床位 12', '#20496B', '#E6F1FF')
      }

      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text('03')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('今日待办理')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D8E4F0')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('01')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('家属待回访')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D8E4F0')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('14:30')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('预计到院')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D8E4F0')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#16324A')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#244B70'
    })
  }

  @Builder
  private rightSummaryCard() {
    Column({ space: 14 }) {
      this.sectionTitle('办理侧重点', '先确保护理真实可执行，再补齐系统信息。')

      Column({ space: 8 }) {
        this.tag('当前步骤：资料核验', '#EAF1FD', '#1D63ED')
        this.tag('责任人：前台接待护工', '#F3F6FA', '#526277')
        this.tag('需护理站复核', '#FDEFD8', '#B7791F')
      }

      Divider()
        .strokeWidth(1)
        .color('#E4EAF1')

      Text('若家属再次未接通，系统将在晚饭后自动补发陪伴摘要，并提示值班护工人工跟进。')
        .fontSize($r('sys.float.Body_S'))
        .fontColor('#526277')
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#FFFFFF')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#DCE5EF'
    })
  }

  build() {
    HdsNavDestination() {
      List({ space: 16 }) {
        ListItem() {
          if (this.isWideLayout()) {
            Row({ space: 16 }) {
              this.summaryHero()
              Column() {
                this.rightSummaryCard()
              }
              .width(340)
            }
          } else {
            Column({ space: 16 }) {
              this.summaryHero()
              this.rightSummaryCard()
            }
          }
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          top: this.contentTopPadding()
        })

        ListItem() {
          Column({ space: 12 }) {
            this.sectionTitle('办理流程', '减少冗长表单，把关键信息前置给护工。')
            if (this.isWideLayout()) {
              Row({ space: 12 }) {
                Repeat(this.steps())
                  .each((repeatItem: RepeatItem<CheckInStep>) => {
                    this.stepCard(repeatItem.item, repeatItem.index)
                  })
              }
            } else {
              Column({ space: 12 }) {
                Repeat(this.steps())
                  .each((repeatItem: RepeatItem<CheckInStep>) => {
                    this.stepCard(repeatItem.item, repeatItem.index)
                  })
              }
            }
          }
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding()
        })

        ListItem() {
          if (this.isWideLayout()) {
            Row({ space: 16 }) {
              Column({ space: 12 }) {
                this.sectionTitle('入住对象', '先看到最关键的信息，而不是一长串表单。')
                Column() {
                  Repeat(this.baseInfo())
                    .each((repeatItem: RepeatItem<KeyValueData>) => {
                      this.infoRow(repeatItem.item, repeatItem.index === this.baseInfo().length - 1)
                    })
                }
                .padding($r('sys.float.padding_level6'))
                .backgroundColor('#FFFFFF')
                .borderRadius(this.cardRadius())
                .border({
                  width: 1,
                  color: '#DCE5EF'
                })
              }
              .layoutWeight(1)

              Column({ space: 12 }) {
                this.sectionTitle('办理准备', '把首日照护真正准备好，比填更多字段更重要。')
                Column() {
                  Repeat(this.readyItems())
                    .each((repeatItem: RepeatItem<ReadyItem>) => {
                      this.readyRow(repeatItem.item, repeatItem.index === this.readyItems().length - 1)
                    })
                }
                .padding($r('sys.float.padding_level6'))
                .backgroundColor('#FFFFFF')
                .borderRadius(this.cardRadius())
                .border({
                  width: 1,
                  color: '#DCE5EF'
                })
              }
              .width(360)
            }
          } else {
            Column({ space: 12 }) {
              this.sectionTitle('入住对象', '先看到最关键的信息，而不是一长串表单。')
              Column() {
                Repeat(this.baseInfo())
                  .each((repeatItem: RepeatItem<KeyValueData>) => {
                    this.infoRow(repeatItem.item, repeatItem.index === this.baseInfo().length - 1)
                  })
              }
              .padding($r('sys.float.padding_level6'))
              .backgroundColor('#FFFFFF')
              .borderRadius(this.cardRadius())
              .border({
                width: 1,
                color: '#DCE5EF'
              })

              this.sectionTitle('办理准备', '把首日照护真正准备好，比填更多字段更重要。')
              Column() {
                Repeat(this.readyItems())
                  .each((repeatItem: RepeatItem<ReadyItem>) => {
                    this.readyRow(repeatItem.item, repeatItem.index === this.readyItems().length - 1)
                  })
              }
              .padding($r('sys.float.padding_level6'))
              .backgroundColor('#FFFFFF')
              .borderRadius(this.cardRadius())
              .border({
                width: 1,
                color: '#DCE5EF'
              })
            }
          }
        }
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          bottom: this.isWideLayout() ? 36 : 56
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor('#EEF2F6')
    }
    .backgroundColor('#EEF2F6')
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
