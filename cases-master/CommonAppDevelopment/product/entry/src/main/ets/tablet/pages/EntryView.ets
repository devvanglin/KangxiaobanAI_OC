/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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
import { SwiperComponent } from 'swipercomponent/Index';
import { SearchComponent } from 'searchcomponent/Index';
import { DynamicsRouter } from 'routermodule/Index';
import { FunctionalScenes, SceneModuleInfo } from 'functionalscenes/Index';
import { waterFlowData } from '../../data/WaterFlowData';
import { HelperView } from '../../view/HelperView';
import { window } from '@kit.ArkUI';
import { BusinessError, emitter } from '@kit.BasicServicesKit';

const CANCEL_ROUTE_TITLE: string[] =
  ['mediafullscreen/MediaFullScreen', 'fitfordarkmode/FitForDarkMode',
    'foldablescreencases/MusicPlayerPage', 'pageflip/PageFlip',
    'secondfloorloadanimation/SecondFloorLoadAnimation', 'diggingholescreen/DiggingHoleScreen',
    'dynamicattributes/ShoppingCart', 'dynamicattributes/Details',
    'bottomdrawerslidecase/BottomDrawerSlideComponent', 'danmakuplayer/DanmakuVideoDemo',
    'effectKit/MainPage', 'videoscreendirectionswitching/VideoScreenDirectionSwitching',
    'operaterdbintaskpool/OperateRDBInTaskPoolComponent', 'videolistautoplay/VideoListAutoplay',
    'imagecompression/ImageCompression', 'statusbaranimation/StatusBarAnimation',
    'statusbaranimation/StatusBarAnimation', 'collapsemenu/ArticleWebComponent', 'groupavatar/GroupAvatarMainPage',
    'groupavatar/GroupAvatarAddPage', 'immersive/ImmersiveView',
    'containernestedslide/NewsDetailPageComponent']; // 取消相关页面路由标题的路由信息

const NO_NEED_PULL_UP_KEYBOARD: string[] = ['miniplayeranimation/MiniPlayerAnimation']; // 不需要拉起键盘，取消相关页面路由标题的路由信息

const LAYOUT_WEIGHT: number = 1; // layoutWeight值
const PRIVACY_AGREEMENT = '隐私协议';
const USER_AGREEMENT = '用户协议';

@Entry
@Component
struct EntryView {
  // TODO:需求：路由栈信息，待后续封装路由管理HAR
  @State listData: SceneModuleInfo[] = waterFlowData;
  @Provide('fullScreenSize') fullScreenSize: string = '50%';
  @Provide('pageStack') pageStack: NavPathStack = DynamicsRouter.navPathStack;
  @State windowWidth: number = 0;
  @State privacyAgreementUri: string = 'privacyagreement/PrivacyAgreementComponent';
  private readonly statusBarAnimation: string = 'statusbaranimation/StatusBarAnimation';
  private readonly pageFlipPage: string = 'pageflip/PageFlip';
  private readonly miniPlayerAnimationPage: string = 'miniplayeranimation/MiniPlayerAnimation';
  private readonly bottomDrawerSlideCase: string = 'bottomdrawerslidecase/BottomDrawerSlideCase';
  private readonly loginPage: string = 'multimodaltransion/HalfModalWindow';
  private readonly navdestinationdialog: string = "navdestinationdialog/CommentDialog";
  private readonly keyboardAvoid: string = 'keyboardAvoid/KeyboardAvoid';

  aboutToAppear(): void {
    // 存储初始数据用于搜索筛选
    AppStorage.setOrCreate('listData', this.listData)
    window.getLastWindow(getContext(this), (err: BusinessError, data: window.Window) => {
      const rect: window.Rect = data.getWindowProperties().windowRect;
      this.windowWidth = px2vp(rect.width);
    })
  }

  /**
   * 获取当前页面name
   * @param name 模块路由信息
   * @returns
   */
  getModuleTitle(name: string): null | string {
    for (let index = 0; index < waterFlowData.length; index++) {
      if (waterFlowData[index].appUri === name) {
        return waterFlowData[index].name;
      }
    }
    if (name === this.privacyAgreementUri) {
      let value: string | undefined = AppStorage.get('agreementTitle');
      return value!;
    }
    return null;
  }

  @Builder
  pageMap(name: string, param: ESObject) {
    if (CANCEL_ROUTE_TITLE.includes(name)) {
      NavDestination() {
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      .backgroundColor($r('app.color.main_background_color'))
      .hideTitleBar(true)
      .expandSafeArea([SafeAreaType.KEYBOARD, SafeAreaType.SYSTEM])
      .onBackPressed(() => {
        if (this.pageFlipPage === name || this.statusBarAnimation === name) {
          let innerEvent: emitter.InnerEvent = { eventId: 2 };
          let eventData: emitter.EventData = {
            data: {
              'backPressed': true
            }
          }
          emitter.emit(innerEvent, eventData);
          return true;
        }
        DynamicsRouter.popAppRouter();
        return true;
      })
    } else if (NO_NEED_PULL_UP_KEYBOARD.includes(name)) {
      NavDestination() {
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      .onBackPressed(() => {
        if (this.miniPlayerAnimationPage === name || this.bottomDrawerSlideCase === name) {
          let innerEvent: emitter.InnerEvent = { eventId: 1 }
          let eventData: emitter.EventData = {
            data: {
              "backPressed": true
            }
          }
          emitter.emit(innerEvent, eventData);
          return true;
        }
        return false;
      })
      .backgroundColor($r('app.color.main_background_color'))
      .hideTitleBar(true)
    } else if (this.navdestinationdialog === name) {
      // navdestinationdialog需要设置成dialog
      NavDestination() {
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      // 登录页是半模态，需要背景透明，设置为DIALOG
      .mode(NavDestinationMode.DIALOG)
      .hideTitleBar(true)
      .expandSafeArea([SafeAreaType.KEYBOARD, SafeAreaType.SYSTEM])
    } else if (this.loginPage === name) {
      NavDestination() {
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      // 登录页是半模态，需要背景透明，设置为DIALOG
      .mode(NavDestinationMode.DIALOG)
      .hideTitleBar(true)
      .expandSafeArea([SafeAreaType.KEYBOARD, SafeAreaType.SYSTEM])
    } else if (name === this.keyboardAvoid) {
      // 显示标题
      NavDestination() {
        this.navDestinationTitle(name);
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      .padding({
        bottom: $r('app.integer.nav_destination_padding_bottom')
      })
      .backgroundColor($r('app.color.main_background_color'))
      .hideTitleBar(true)
      .onBackPressed(() => {
        DynamicsRouter.popAppRouter();
        return true;
      })
    } else {
      // 显示标题
      NavDestination() {
        this.navDestinationTitle(name);
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      .expandSafeArea([SafeAreaType.KEYBOARD, SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .padding({
        bottom: $r('app.integer.nav_destination_padding_bottom')
      })
      .backgroundColor($r('app.color.main_background_color'))
      .hideTitleBar(true)
      .onBackPressed(() => {
        DynamicsRouter.popAppRouter();
        return true;
      })
    }
  }

  @Builder
  navDestinationTitle(name: string) {
    Row() {
      Row() {
        Row() {
          Column() {
            Image($r("app.media.operate_rdb_in_taskpool_arrow_left"))
              .width($r('app.integer.nav_destination_title_image_size'))
          }
          .onClick(() => {
            // 若子路由还发生了跳转,继续返回
            if (this.pageStack.size() > 1) {
              DynamicsRouter.popAppRouter();
              return;
            }
            DynamicsRouter.popAppRouter();
          })
          .justifyContent(FlexAlign.Center)
          .width($r('app.integer.nav_destination_title_image_background_size'))
          .height($r('app.integer.nav_destination_title_image_background_size'))
          .borderRadius($r('app.integer.nav_destination_title_image_border_radius'))
          .backgroundColor($r('app.color.nav_destination_title_image_background_color'))

          Text(this.getModuleTitle(name))
            .fontWeight(FontWeight.Bold)
            .fontSize($r('app.integer.nav_destination_title_text_size'))
            .margin({ left: $r('app.integer.nav_destination_title_text_margin') })
            .width(AppStorage.get('isFoldable') ? $r('app.integer.nav_destination_title_text_foldable_width') :
            $r('app.integer.nav_destination_title_text_width'))
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        HelperView({ name: name })
          .visibility(this.getModuleTitle(name) === PRIVACY_AGREEMENT || this.getModuleTitle(name) === USER_AGREEMENT ?
          Visibility.None : Visibility.Visible)
      }
      .height($r('app.integer.nav_destination_title_height'))
      .layoutWeight(LAYOUT_WEIGHT)
      .padding({
        left: $r('app.integer.nav_destination_title_padding'),
        right: $r('app.integer.nav_destination_title_padding')
      })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .backgroundColor($r('app.color.main_background_color'))
    .margin({ bottom: $r('app.integer.nav_destination_title_bottom') })
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  build() {
    Stack() {
      Navigation(DynamicsRouter.navPathStack) {
        // 使用规避手段增加外层嵌套，待系统问题修复后去除
        Column() {
          Scroll() {
            Column() {
              // 首页搜索组件
              SearchComponent()
              // 首页轮播图组件
              SwiperComponent()
              // 首页列表组件
              FunctionalScenes({ listData: this.listData })
            }
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .scrollable(ScrollDirection.Vertical)
        }
      }
      .backgroundColor($r('app.color.main_background_color'))
      .hideTitleBar(true)
      .navBarWidth(this.fullScreenSize)
      .navDestination(this.pageMap)
      .mode(NavigationMode.Split) // 视频全屏案例横屏时使用NavigationMode.Split模式显示。


    }
    .alignContent(Alignment.BottomEnd)
    .height('100%')
    .backgroundColor($r('app.color.main_background_color'))
  }
}