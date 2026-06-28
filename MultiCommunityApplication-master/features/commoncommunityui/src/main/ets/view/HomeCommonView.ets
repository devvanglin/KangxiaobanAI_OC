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
import uiObserver from '@ohos.arkui.observer';
import { BreakpointType, CommonConstants, MSVEmptyComponent } from 'commonmulticommunityapplication';
import { HorizontalContacts, SideContacts } from 'socialcommunity';
import { FollowerPostsView } from 'contentcommunity';
import { secNavigationHome } from '../viewmodel/HomeViewModel';
import { CommonIcon, SearchBar } from './CommonView';
import { TopSecNavView } from './TopSecNavView';

@ComponentV2
export struct HomeCommonView {
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
    if (value.now === CommonConstants.TAB_MINE_PAGE_INDEX) {
      if (this.pathStack.size() > 0) {
        this.pathStack.clear();
      }
    }
  }

  onPageShow(): void {
    if (this.breakpoint.widthBreakpoint !== WidthBreakpoint.WIDTH_SM) {
      this.pathStack.pushPath({ name: 'FollowerPostsView' });
    }
  }

  build() {
    Column() {
      Column() {
        Stack() {
          TopSecNavView({
            viewModel: secNavigationHome,
            firstTitle: $r('app.string.attention'),
            secondTitle: $r('app.string.discovery'),
            onFirstClick: () => {
              secNavigationHome.switchSecNavigationTab(0);
            },
            onSecondClick: () => {
              secNavigationHome.switchSecNavigationTab(1);
            }
          })

          // Search component
          if (this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
            // Circular search button
            Row() {
              CommonIcon($r('sys.symbol.magnifyingglass'))
            }
            .height(56)
            .position({
              right: 24
            })
          } else {
            Row() {
              SearchBar()
            }
            .height(56)
            .position({
              right: this.moduleName === CommonConstants.DEVICE_TYPE_PC ? 160 : 24
            })
          }
        }
        .opacity(this.barOpacity)
        .height(this.topBarHeight)

        // Secondary navigation content area
        Tabs({ barPosition: BarPosition.Start, index: secNavigationHome.currentSubTabIndex }) {
          TabContent() {
            Row() {
              if (this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
                // Lateral observer
                Scroll() {
                  Column() {
                    HorizontalContacts()
                    FollowerPostsView()
                  }
                }
                .width('100%')
                .height('100%')
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
                .nestedScroll({
                  scrollForward: NestedScrollMode.PARENT_FIRST,
                  scrollBackward: NestedScrollMode.SELF_FIRST
                })
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
              } else {
                SideBarContainer(SideBarContainerType.Embed) {
                  // All Followed List on the Left Side
                  SideContacts()
                  FollowerPostsView()
                }
                .sideBarPosition(SideBarPosition.Start)
                .showSideBar(true)
                .autoHide(false)
                .minSideBarWidth(new BreakpointType<number>(0, 209, 240, 240).getValue(this.breakpoint.widthBreakpoint))
                .maxSideBarWidth(new BreakpointType<number>(0, 209, 240, 240).getValue(this.breakpoint.widthBreakpoint))
                .showControlButton(false)
                .divider({ strokeWidth: 0 })
              }
            }
            .border({ width: { top: 1 }, color: $r('app.color.background_secondary') })
          }
          .tabBar($r('app.string.attention'))

          TabContent() {
            Column(){
              MSVEmptyComponent()
            }
            .width('100%')
            .height('100%')
          }
          .tabBar($r('app.string.discovery'))
        }
        .scrollable(false)
        .barHeight(0)
        .barWidth(0)
        .animationDuration(300)
        .onChange((index: number) => {
          secNavigationHome.switchSecNavigationTab(index);
        })
      }
    }
  }
}

@Builder
export function HomePageBuilder() {
  HomeCommonView({ activeIndex: CommonConstants.TAB_MINE_PAGE_INDEX });
}