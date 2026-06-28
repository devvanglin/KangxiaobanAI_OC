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
import { common } from '@kit.AbilityKit';
import { uiObserver } from '@kit.ArkUI';
import { CommonConstants, MSVEmptyComponent } from 'commonmulticommunityapplication';
import { RealTimeView } from 'contentcommunity';
import { secNavigationHot } from '../viewmodel/HomeViewModel';
import { CommonIcon, SearchBar } from './CommonView';
import { TopSecNavView } from './TopSecNavView';

@ComponentV2
export struct HotCommonView {
  private moduleName: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Consumer() pathStack: NavPathStack = new NavPathStack();
  @Require @Param activeIndex: number;
  @Local topBarHeight: number = 56;
  @Local currentYOffset: number = 0;
  @Local barOpacity: number = 1;

  aboutToAppear(): void {
    this.moduleName = this.context.abilityInfo.moduleName;
  }

  @Monitor('activeIndex')
  onActiveIndex(mon: IMonitor) {
    const value: IMonitorValue<number> | undefined = mon.value();
    if (!value) {
      return;
    }
    if (this.pathStack.size() > 0) {
      this.pathStack.clear();
    }
  }

  build() {
    Column() {
      Stack() {
        TopSecNavView({
          viewModel: secNavigationHot,
          firstTitle: $r('app.string.realTime'),
          secondTitle: $r('app.string.local'),
          onFirstClick: () => {
            secNavigationHot.switchSecNavigationTab(0);
          },
          onSecondClick: () => {
            secNavigationHot.switchSecNavigationTab(1);
          }
        })
        // Search component
        if (this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
          // Circular search button
          Row() {
            CommonIcon($r('sys.symbol.magnifyingglass'))
          }
          .height(56)
          .position({ right: 24 })
        } else {
          Row() {
            SearchBar()
          }
          .height(56)
          .position({
            right: this.moduleName === CommonConstants.DEVICE_TYPE_PC ? 160 : 16
          })
        }
      }
      .opacity(this.barOpacity)
      .height(this.topBarHeight)

      // Secondary navigation content area
      Tabs({ barPosition: BarPosition.Start, index: secNavigationHot.currentSubTabIndex }) {
        TabContent() {
          Row() {
            Scroll() {
              RealTimeView()
            }
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.None)
            .align(Alignment.Top)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .onScrollFrameBegin((offset: number) => {
              if (this.breakpoint.widthBreakpoint !== WidthBreakpoint.WIDTH_SM ||
                (this.breakpoint.heightBreakpoint !== HeightBreakpoint.HEIGHT_MD &&
                  this.breakpoint.heightBreakpoint !== HeightBreakpoint.HEIGHT_SM)) {
                return { offsetRemain: offset };
              }
              if (offset > 0) {
                this.currentYOffset += offset;
              }
              if (offset < 0) {
                this.currentYOffset -= offset;
              }
              this.getUIContext().animateTo({
                duration: 300
              }, () => {
                this.topBarHeight = 0;
                this.barOpacity = 0;
              });
              return { offsetRemain: offset };
            })
            .onScrollStop(() => {
              setTimeout(() => {
                this.getUIContext().animateTo({
                  duration: 300
                }, () => {
                  this.topBarHeight = 56;
                  this.barOpacity = 1;
                });
              }, 500);
            });
          }
        }
        .tabBar($r('app.string.realTime'))

        TabContent() {
          Column(){
            MSVEmptyComponent()
          }
          .width('100%')
          .height('100%')
        }
        .tabBar($r('app.string.local'))
      }
      .barHeight(0)
      .barWidth(0)
      .animationDuration(300)
      .onChange((index: number) => {
        secNavigationHot.switchSecNavigationTab(index);
      })
    }
    .backgroundColor($r('app.color.background_primary'))
  }
}

@Builder
export function HotPageBuilder() {
  HotCommonView({ activeIndex: CommonConstants.TAB_HOT_PAGE_INDEX });
}