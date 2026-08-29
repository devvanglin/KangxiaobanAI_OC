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
import { BusinessStore } from '../network/BusinessStore';
import { Bed, Elder, HealthRecord, Room } from '../network/Dto';

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
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  private listScroller: ListScroller = new ListScroller();

  aboutToAppear(): void {
    this.businessStore.load();
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
      return $r('app.color.status_danger');
    }
    if (level === 'warning') {
      return $r('app.color.status_warning');
    }
    return $r('app.color.status_normal');
  }

  build() {
    Column() {
      HdsNavDestination() {
        Stack({ alignContent: Alignment.End }) {
          Scroll() {
            Row() {
              Column({ space: 12 }) {
                Repeat<ElderGroup>(this.elderGroups())
                  .each((groupItem: RepeatItem<ElderGroup>) => {
                    Column({ space: 0 }) {
                      Row() {
                        Text(`${groupItem.item.letter}F`)
                          .fontSize($r('sys.float.Caption_L'))
                          .fontColor($r('sys.color.font_secondary'))
                          .fontWeight(FontWeight.Regular)
                      }
                      .height(40)
                      .width('100%')

                      Repeat<HealthRowData>(groupItem.item.elders)
                        .each((elderItem: RepeatItem<HealthRowData>) => {
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
                        })
                        .key((item: HealthRowData) => item.id)
                    }
                    .width('100%')
                  })
                  .key((item: ElderGroup) => item.letter)
              }
              .width('100%')
              .constraintSize({ maxWidth: 960 })
              .padding({
                left: 16,
                right: 24,
                top: this.globalInfoModel.statusBarHeight + 64,
                bottom: 16 + this.globalInfoModel.naviIndicatorHeight
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height('100%')

          AlphabetIndexer({ arrayValue: this.alphabets(), selected: this.selectedIndex })
            .width(24)
            .autoCollapse(true)
            .usingPopup(true)
            .margin({ bottom: 16 + this.globalInfoModel.naviIndicatorHeight })
            .onSelect((index: number) => {
              this.onIndexerSelected(index);
            })
        }
        .width('100%')
        .height('100%')
      }
      .backgroundColor($r('sys.color.background_secondary'))
      .ignoreLayoutSafeArea(
        [LayoutSafeAreaType.SYSTEM],
        [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
      )
      .hideBackButton(true)
      .titleBar({
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false,
        style: this.titleBarStyle(),
        content: this.titleBarContent()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
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
    if (this.businessStore.loaded) {
      return this.businessStore.elders.map((elder: Elder): HealthRowData => {
        const bed: Bed | undefined = this.businessStore.beds.find((item: Bed) => item.id === elder.bed_id);
        const room: Room | undefined = bed ? this.businessStore.rooms.find((item: Room) => item.id === bed.room_id) : undefined;
        const latest: HealthRecord | undefined = this.businessStore.healthRecords.filter((item: HealthRecord) => item.elder_id === elder.id)
          .sort((left: HealthRecord, right: HealthRecord): number => right.record_time.localeCompare(left.record_time))[0];
        const abnormal: boolean = latest?.is_abnormal ?? false;
        return { id: `${elder.id}`, name: elder.name,
          age: elder.birth_date ? new Date().getFullYear() - Number(elder.birth_date.slice(0, 4)) : 0,
          room: room ? `${room.floor}F-${room.room_no}` : '未分配', bed: bed ? `${bed.bed_no}床` : '未分配',
          level: abnormal ? 'warning' : 'normal', status: abnormal ? '体征需要关注' : '稳定观察',
          mood: abnormal ? '需关注' : '平稳', moodLevel: abnormal ? 'warning' : 'normal',
          lastUpdate: latest ? latest.record_time.slice(11, 16) : '--' };
      });
    }
    return [];
  }
}
