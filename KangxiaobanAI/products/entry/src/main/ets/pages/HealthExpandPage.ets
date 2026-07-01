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
import { HdsNavDestination, hdsMaterial, ScrollEffectType, TitleBarContentOptions, TitleBarStyleOptions } from '@kit.UIDesignKit';
import { HealthRowData, StatusLevel } from '../model/DetailTypes';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';

interface ElderGroup {
  letter: string;
  elders: HealthRowData[];
}

@ComponentV2
export struct HealthExpandPage {
  @Event onClose: () => void = () => {};
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local selectedIndex: number = 0;
  private listScroller: ListScroller = new ListScroller();

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: false,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  private titleBarContent(): TitleBarContentOptions {
    return {
      title: { mainTitle: '老人健康状态' },
      menu: {
        value: [{
          content: {
            icon: $r('sys.symbol.xmark'),
            isEnabled: true,
            action: () => {
              this.onClose();
            }
          }
        }]
      }
    };
  }

  private elderGroups(): ElderGroup[] {
    const all: HealthRowData[] = this.healthRows();
    const floorMap: Map<string, HealthRowData[]> = new Map();
    all.forEach((item: HealthRowData) => {
      const floor: string = item.room.split('-')[0];
      if (!floorMap.has(floor)) {
        floorMap.set(floor, []);
      }
      floorMap.get(floor)!.push(item);
    });
    const groups: ElderGroup[] = [];
    const letters: string[] = Array.from(floorMap.keys()).sort();
    letters.forEach((letter: string) => {
      groups.push({ letter, elders: floorMap.get(letter)! });
    });
    return groups;
  }

  private alphabets(): string[] {
    return this.elderGroups().map((group: ElderGroup) => group.letter);
  }

  private statusColor(level: StatusLevel): ResourceColor {
    if (level === 'danger') {
      return '#D92B2B';
    }
    if (level === 'warning') {
      return '#F5A623';
    }
    return '#2FA84F';
  }

  build() {
    Column() {
      HdsNavDestination() {
        Stack({ alignContent: Alignment.End }) {
          List({ scroller: this.listScroller }) {
            Repeat<ElderGroup>(this.elderGroups())
              .each((groupItem: RepeatItem<ElderGroup>) => {
                ListItemGroup({ header: this.itemGroupHeader(groupItem.item.letter) }) {
                  Repeat<HealthRowData>(groupItem.item.elders)
                    .each((elderItem: RepeatItem<HealthRowData>) => {
                      ListItem() {
                        Row({ space: 12 }) {
                          Column({ space: 4 }) {
                            Text(elderItem.item.name)
                              .fontSize($r('sys.float.Subtitle_M'))
                              .fontColor($r('sys.color.font_primary'))
                              .fontWeight(FontWeight.Medium)
                            Text(`${elderItem.item.age}岁 · ${elderItem.item.room} · ${elderItem.item.bed} · ${elderItem.item.status}`)
                              .fontSize($r('sys.float.Body_S'))
                              .fontColor($r('sys.color.font_secondary'))
                          }
                          .alignItems(HorizontalAlign.Start)
                          .layoutWeight(1)

                          Text(this.statusText(elderItem.item.level))
                            .fontSize($r('sys.float.Caption_M'))
                            .fontColor(this.statusColor(elderItem.item.level))
                        }
                        .justifyContent(FlexAlign.Start)
                        .alignItems(VerticalAlign.Center)
                        .width('100%')
                        .height(64)
                      }
                    })
                    .key((item: HealthRowData) => item.id)
                }
                .divider({
                  strokeWidth: 0.5,
                  color: $r('sys.color.comp_divider'),
                  startMargin: 0,
                  endMargin: 12
                })
              })
              .key((item: ElderGroup) => item.letter)
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .padding({
            left: 16,
            right: 24,
            top: 56,
            bottom: this.globalInfoModel.naviIndicatorHeight
          })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onScrollIndex((firstIndex: number) => {
            this.onListScrolled(firstIndex);
          })

          AlphabetIndexer({ arrayValue: this.alphabets(), selected: this.selectedIndex })
            .width(24)
            .autoCollapse(true)
            .usingPopup(true)
            .margin({ top: 56 })
            .onSelect((index: number) => {
              this.onIndexerSelected(index);
            })
        }
        .width('100%')
        .height('100%')
      }
      .backgroundColor($r('sys.color.background_secondary'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .hideBackButton(true)
      .titleBar({
        style: this.titleBarStyle(),
        content: this.titleBarContent()
      })
    }
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .padding({ top: this.globalInfoModel.statusBarHeight })
    .geometryTransition('healthCard')
    .transition(TransitionEffect.OPACITY)
  }

  private statusText(level: StatusLevel): string {
    if (level === 'danger') {
      return '风险';
    }
    if (level === 'warning') {
      return '关注';
    }
    return '正常';
  }

  private onIndexerSelected(index: number): void {
    this.selectedIndex = index;
    this.listScroller.scrollToIndex(index);
  }

  private onListScrolled(firstIndex: number): void {
    const groups: ElderGroup[] = this.elderGroups();
    if (groups[firstIndex]) {
      this.selectedIndex = firstIndex;
    }
  }

  @Builder
  private itemGroupHeader(text: string) {
    Row() {
      Text(`${text}F`)
        .fontSize($r('sys.float.Caption_L'))
        .fontColor($r('sys.color.font_secondary'))
        .fontWeight(FontWeight.Regular)
    }
    .height(40)
    .width('100%')
  }

  private healthRows(): HealthRowData[] {
    return [
      // 1F
      {
        id: 'r1', name: '肖爷爷', age: 82, room: '1F-102', bed: 'A床',
        level: 'danger', status: '情绪低落 · 拒交流', mood: '低落', moodLevel: 'danger',
        lastUpdate: '10:24'
      },
      {
        id: 'r2', name: '周奶奶', age: 78, room: '1F-115', bed: 'B床',
        level: 'warning', status: '夜间离床增加', mood: '焦虑', moodLevel: 'warning',
        lastUpdate: '09:46'
      },
      // 2F
      {
        id: 'r3', name: '王爷爷', age: 80, room: '2F-201', bed: 'A床',
        level: 'normal', status: '稳定观察', mood: '平静', moodLevel: 'normal',
        lastUpdate: '08:30'
      },
      {
        id: 'r4', name: '赵奶奶', age: 76, room: '2F-208', bed: 'A床',
        level: 'normal', status: '稳定观察', mood: '愉快', moodLevel: 'normal',
        lastUpdate: '08:15'
      },
      {
        id: 'r5', name: '钱奶奶', age: 81, room: '2F-216', bed: 'A床',
        level: 'warning', status: '血压偏高', mood: '焦虑', moodLevel: 'warning',
        lastUpdate: '07:50'
      },
      {
        id: 'r6', name: '郑奶奶', age: 77, room: '2F-209', bed: 'B床',
        level: 'normal', status: '稳定观察', mood: '平静', moodLevel: 'normal',
        lastUpdate: '07:20'
      },
      {
        id: 'r7', name: '陈奶奶', age: 75, room: '2F-205', bed: 'B床',
        level: 'normal', status: '稳定观察', mood: '愉快', moodLevel: 'normal',
        lastUpdate: '06:55'
      },
      // 3F
      {
        id: 'r8', name: '林爷爷', age: 85, room: '3F-306', bed: 'C床',
        level: 'warning', status: '社交回避', mood: '回避', moodLevel: 'warning',
        lastUpdate: '09:12'
      },
      {
        id: 'r9', name: '孙爷爷', age: 79, room: '3F-301', bed: 'B床',
        level: 'normal', status: '稳定观察', mood: '平静', moodLevel: 'normal',
        lastUpdate: '08:02'
      },
      {
        id: 'r10', name: '吴爷爷', age: 84, room: '3F-305', bed: 'A床',
        level: 'normal', status: '稳定观察', mood: '愉快', moodLevel: 'normal',
        lastUpdate: '07:35'
      },
      {
        id: 'r11', name: '冯爷爷', age: 83, room: '3F-308', bed: 'A床',
        level: 'danger', status: '跌倒风险', mood: '低落', moodLevel: 'danger',
        lastUpdate: '07:08'
      },
      {
        id: 'r12', name: '褚爷爷', age: 86, room: '3F-310', bed: 'C床',
        level: 'warning', status: '睡眠质量差', mood: '焦虑', moodLevel: 'warning',
        lastUpdate: '06:40'
      },
      // 4F
      {
        id: 'r13', name: '韩爷爷', age: 81, room: '4F-402', bed: 'A床',
        level: 'normal', status: '稳定观察', mood: '平静', moodLevel: 'normal',
        lastUpdate: '09:30'
      },
      {
        id: 'r14', name: '蒋奶奶', age: 79, room: '4F-415', bed: 'B床',
        level: 'warning', status: '服药提醒', mood: '焦虑', moodLevel: 'warning',
        lastUpdate: '08:48'
      },
      {
        id: 'r15', name: '沈爷爷', age: 84, room: '4F-406', bed: 'A床',
        level: 'normal', status: '稳定观察', mood: '愉快', moodLevel: 'normal',
        lastUpdate: '08:05'
      },
      // 5F
      {
        id: 'r16', name: '杨奶奶', age: 77, room: '5F-501', bed: 'A床',
        level: 'normal', status: '稳定观察', mood: '平静', moodLevel: 'normal',
        lastUpdate: '09:20'
      },
      {
        id: 'r17', name: '朱爷爷', age: 82, room: '5F-508', bed: 'C床',
        level: 'danger', status: '高烧观察', mood: '低落', moodLevel: 'danger',
        lastUpdate: '08:40'
      },
      {
        id: 'r18', name: '秦奶奶', age: 75, room: '5F-515', bed: 'B床',
        level: 'normal', status: '稳定观察', mood: '愉快', moodLevel: 'normal',
        lastUpdate: '07:55'
      }
    ];
  }
}
