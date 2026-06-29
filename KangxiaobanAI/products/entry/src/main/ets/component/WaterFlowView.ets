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
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import { BreakpointType } from '../util/BreakpointSystem';

@ComponentV2
export struct WaterFlowView {
  @Param @Require currentTabIndex: number;
  @Param @Require pageKey: PageKeyEnum;
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();
  @Local items: WaterFlowItem[] = [];
  @Event handleTabBarAnimation?: (yOffset: number) => void;
  private currentPage: number = 1;
  sectionOptions: WaterFlowSections = new WaterFlowSections();

  aboutToAppear(): void {
    this.loadData();
  }

  private loadData(): void {
    const newItems = this.generateMockData();
    this.items = [...this.items, ...newItems];
  }

  private generateMockData(): WaterFlowItem[] {
    const mockItems: WaterFlowItem[] = [];
    const startId = (this.currentPage - 1) * 18;

    for (let i = 0; i < 18; i++) {
      const id = startId + i;
      mockItems.push({
        id: `item-${id}`,
        image: $r(`app.media.ic_${i % 18 + 1}`),
      });
    }
    this.currentPage++;
    return mockItems;
  }

  @Computed
  get getBannerItemsCount(): number {
    this.handleTabBarAnimation?.(-1);
    const bannerItemsCount: number = new BreakpointType({
      sm: 1,
      md: this.globalInfoModel.heightBreakpoint === HeightBreakpoint.HEIGHT_LG ? 1 : 2,
      lg: 2,
    }).getValue(this.globalInfoModel.widthBreakpoint);
    return bannerItemsCount;
  }

  @Computed
  get getSections(): WaterFlowSections {
    const horizontalMargin = new BreakpointType({
      sm: $r('sys.float.padding_level8'),
      md: $r('sys.float.padding_level12'),
      lg: $r('sys.float.padding_level16'),
    }).getValue(this.globalInfoModel.widthBreakpoint)

    const bannerSection: SectionOptions = {
      itemsCount: this.getBannerItemsCount,
      crossCount: this.getBannerItemsCount,
      margin: {
        left: horizontalMargin,
        right: horizontalMargin,
        top: this.globalInfoModel.statusBarHeight + 56,
      },
    };
    const crossCount = new BreakpointType({
      sm: 1,
      md: 2,
      lg: 3,
    }).getValue(this.globalInfoModel.widthBreakpoint);

    const waterFlowSection: SectionOptions = {
      itemsCount: this.items.length,
      crossCount: crossCount,
      margin: {
        top: $r('sys.float.padding_level8'),
        left: horizontalMargin,
        right: horizontalMargin,
        bottom: this.globalInfoModel.naviIndicatorHeight + 64,
      },
    };
    this.sectionOptions.splice(0, this.sectionOptions.length(), [bannerSection, waterFlowSection]);
    return this.sectionOptions;
  }

  build() {
    WaterFlow({ scroller: PAGE_SCROLLER_MAP.get(this.pageKey)?.[this.currentTabIndex], sections: this.getSections }) {
      Repeat(this.items.slice(-this.getBannerItemsCount))
        .each((repeatItem: RepeatItem<WaterFlowItem>) => {
          FlowItem() {
            Image(repeatItem.item.image)
              .width('100%')
          }
          .width('100%')
        })

      Repeat(this.items)
        .each((repeatItem: RepeatItem<WaterFlowItem>) => {
          FlowItem() {
            Image(repeatItem.item.image)
              .width('100%')
          }
          .width('100%')
        })
    }
    .edgeEffect(EdgeEffect.Spring)
    .onScrollFrameBegin((offset: number, state: ScrollState) => {
      this.handleTabBarAnimation?.(offset);
      return { offsetRemain: offset };
    })
    .onReachEnd(() => {
      this.handleTabBarAnimation?.(-1);
    })
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .columnsGap($r('sys.float.padding_level8'))
    .rowsGap($r('sys.float.padding_level8'))
    .width('100%')
    .height('100%')
  }
}

export interface WaterFlowItem {
  id: string;
  image: ResourceStr;
}