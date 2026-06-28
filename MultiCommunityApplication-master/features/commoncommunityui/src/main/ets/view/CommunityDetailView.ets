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
import { hdsMaterial, HdsTabs } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { uiObserver } from '@kit.ArkUI';
import { BreakpointType, CommonConstants } from 'commonmulticommunityapplication';
import { BottomTabs, CommentAreaView } from 'socialcommunity';
import { PostModel, PostViewModel } from 'contentcommunity';
import { CommunityDetailContent } from 'contentcommunity';

/**
 * Community Details Page
 */
@ComponentV2
export struct CommunityDetailView {
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local postViewModel: PostViewModel = new PostViewModel();
  @Local postInfo: PostModel = this.postViewModel.postList[0];
  @Local isHideTitleBar: boolean = false;
  @Local currentYOffset: number = 0;
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private moduleName: string = '';

  aboutToAppear(): void {
    this.moduleName = this.context.abilityInfo.moduleName;
  }

  private getBottomHeight(): number {
    return this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_SM &&
      this.breakpoint.heightBreakpoint === HeightBreakpoint.HEIGHT_MD ? 8 : 0
  }

  @Builder
  tabBuilder() {
    BottomTabs()
  }

  build() {
    if (deviceInfo.distributionOSApiVersion >= 60100) {
      NavDestination() {
        if (this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
          HdsTabs({ barPosition: BarPosition.End }) {
            TabContent() {
              Scroll() {
                Column() {
                  CommunityDetailContent({ postInfo: this.postInfo })
                  CommentAreaView()
                    .padding({ left: 8 })
                }
              }
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
              .backgroundColor($r('app.color.background_primary'))
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
                  this.isHideTitleBar = true;
                });
                return { offsetRemain: offset };
              })
              .onScrollStop(() => {
                setTimeout(() => {
                  this.getUIContext().animateTo({
                    duration: 300
                  }, () => {
                    this.isHideTitleBar = false;
                  });
                }, 500);
              });
            }
            .height('100%')
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
            .tabBar(this.tabBuilder())
          }
          .barOverlap(true)
          .barPosition(BarPosition.End)
          .vertical(false)
          .barFloatingStyle({
            barWidth: { smallWidth: 294, mediumWidth: 328, largeWidth: 328 },
            barSideMargin: 16,
            barBottomMargin: this.getBottomHeight(),
            gradientMask: { maskColor: $r('app.color.mask_gradient'), maskHeight: 92 },
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.IMMERSIVE,
              materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
            }
          })
        } else {
          SideBarContainer(SideBarContainerType.Embed) {
            HdsTabs({ barPosition: BarPosition.End }) {
              TabContent() {
                // Scrollable comment list
                Scroll() {
                  CommentAreaView()
                    .padding({ left: 8 })
                }
                .layoutWeight(1)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
                .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
                .nestedScroll({
                  scrollForward: NestedScrollMode.PARENT_FIRST,
                  scrollBackward: NestedScrollMode.SELF_FIRST
                })
              }
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
              .tabBar(this.tabBuilder())
              .backgroundColor($r('app.color.background_primary'))
            }
            .scrollable(false)
            .animationDuration(0)
            .barOverlap(true)
            .barPosition(BarPosition.End)
            .vertical(false)
            .barFloatingStyle({
              barWidth: { smallWidth: 294, mediumWidth: 246, largeWidth: 328 },
              barSideMargin: 16,
              barBottomMargin: this.moduleName === CommonConstants.DEVICE_TYPE_PC ? 16 : this.getBottomHeight(),
              gradientMask: { maskColor: $r('app.color.mask_gradient'), maskHeight: 92 },
              systemMaterialEffect: {
                materialType: hdsMaterial.MaterialType.IMMERSIVE,
                materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
              }
            })

            CommunityDetailContent({ postInfo: this.postInfo })
          }
          .backgroundImageSize(ImageSize.Cover)
          .sideBarPosition(SideBarPosition.End)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .showSideBar(true)
          .autoHide(false)
          .minSideBarWidth(new BreakpointType<number>(0, 330, 323, 307).getValue(this.breakpoint.widthBreakpoint))
          .maxSideBarWidth(new BreakpointType<number>(0, 330, 323, 307).getValue(this.breakpoint.widthBreakpoint))
          .showControlButton(false)
          .divider({ strokeWidth: 0 })
        }
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .title($r('app.string.detail_page'), { backgroundColor: $r('app.color.background_secondary') })
      .hideTitleBar(this.isHideTitleBar)
      .width('100%')
      .height('100%')
      .onReady((context: NavDestinationContext) => {
        this.postInfo = context.pathInfo.param as PostModel;
      })
    } else {
      NavDestination() {
        if (this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_SM) {
          Tabs({ barPosition: BarPosition.End }) {
            TabContent() {
              Scroll() {
                Column() {
                  CommunityDetailContent({ postInfo: this.postInfo })
                  CommentAreaView()
                    .padding({ left: 8 })
                }
              }
              .backgroundColor($r('app.color.background_primary'))
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            }
            .tabBar(this.tabBuilder())
          }
          .barOverlap(true)
          .barPosition(BarPosition.End)
          .vertical(false)
        } else {
          SideBarContainer(SideBarContainerType.Embed) {
            HdsTabs({ barPosition: BarPosition.End }) {
              TabContent() {
                // Scrollable comment list
                Scroll() {
                  CommentAreaView()
                    .padding({ left: 8 })
                }
                .layoutWeight(1)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
                .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
                .nestedScroll({
                  scrollForward: NestedScrollMode.PARENT_FIRST,
                  scrollBackward: NestedScrollMode.SELF_FIRST
                })
              }
              .tabBar(this.tabBuilder())
            }
            .barOverlap(true)
            .barPosition(BarPosition.End)
            .vertical(false)

            CommunityDetailContent({ postInfo: this.postInfo })
          }
          .sideBarPosition(SideBarPosition.End)
          .showSideBar(true)
          .autoHide(false)
          .minSideBarWidth(new BreakpointType<number>(0, 330, 323, 307).getValue(this.breakpoint.widthBreakpoint))
          .maxSideBarWidth(new BreakpointType<number>(0, 330, 323, 307).getValue(this.breakpoint.widthBreakpoint))
          .showControlButton(false)
          .divider({ strokeWidth: 0 })
        }
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .onReady((context: NavDestinationContext) => {
        this.postInfo = context.pathInfo.param as PostModel;
      })
      .width('100%')
      .height('100%')
      .title($r('app.string.detail_page'))
    }
  }
}

@Builder
export function CommunityDetailBuilder() {
  CommunityDetailView()
}
