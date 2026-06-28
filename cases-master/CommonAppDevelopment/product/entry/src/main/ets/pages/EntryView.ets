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
import { SearchComponent } from 'searchcomponent/Index';
import { DynamicsRouter, FoldableRouter, NavMode } from 'routermodule/Index';
import { FunctionalScenes, SceneModuleInfo } from 'functionalscenes/Index';
import { createNWeb } from 'utils/Index';
import { GlobalStateDialog, GlobalStateDialogManager } from 'shortvideo/Index';
import { waterFlowData } from '../data/WaterFlowData';
import { HelperView } from '../view/HelperView';
import { HomePageSwiper } from '../view/HomePageSwiper';
import { display, promptAction, window } from '@kit.ArkUI';
import { deviceInfo, emitter } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { BreakpointConstants } from '../common/breakpoint/BreakpointConstants';
import { HelperConstants } from '../constants/HelperConstants';
import { ShareButton } from 'sharebutton';
import { HashMap } from '@kit.ArkTS';

const CANCEL_ROUTE_TITLE: string[] =
  ['mediafullscreen/MediaFullScreen', 'fitfordarkmode/FitForDarkMode',
    'foldablescreencases/MusicPlayerPageComponent', 'pageflip/PageFlip',
    'secondfloorloadanimation/SecondFloorLoadAnimation', 'diggingholescreen/DiggingHoleScreen',
    'dynamicattributes/ShoppingCartComponent', 'dynamicattributes/Details',
    'bottomdrawerslidecase/BottomDrawerSlideComponent', 'danmakuplayer/DanmakuVideoDemoComponent',
    'effectKit/MainPage', 'videoscreendirectionswitching/VideoScreenDirectionSwitching',
    'operaterdbintaskpool/OperateRDBInTaskPoolComponent', 'videolistautoplay/VideoListAutoplay',
    'imagecompression/ImageCompression', 'statusbaranimation/StatusBarAnimation',
    'statusbaranimation/StatusBarAnimation', 'collapsemenu/ArticleWebComponent',
    'groupavatar/GroupAvatarMainPageComponent', 'immersive/ImmersiveView',
    'containernestedslide/NewsDetailPageComponent', 'multiplescreening/MultipleScreening',
    'encapsulationdialog/DialogExample', 'videotrimmer/VideoDetail',
    'videotrimmer/VideoUpload', 'clickanimation/ClickAnimationPage', 'shortvideo/ShortVideoComponent',
    'toolbox/ToolBoxComponent']; // 取消相关页面路由标题的路由信息

const NO_NEED_PULL_UP_KEYBOARD: string[] =
  ['miniplayeranimation/MiniPlayerAnimationComponent']; // 不需要拉起键盘，取消相关页面路由标题的路由信息

export const FULL_SCREEN_ROUTE = ['foldablescreencases/MusicPlayerPageComponent', 'mediafullscreen/MediaFullScreen',
  'multimodaltransion/HalfModalWindow', 'customscan/CustomScanPageComponent', 'videocache/VideoCacheView',
  'videoscreendirectionswitching/VideoScreenDirectionSwitching', 'collapsemenu/ArticleWebComponent',
  "sharebutton/MockSharePage",
  "videocreategif/VideoCreateGifView"]; // 折叠屏展开时需要全屏的路由信息

const FULL_SCREEN_COMPONENT: string[] = ['danmakuplayer/DanmakuVideoDemoComponent', 'toolbox/ToolBoxComponent'];

const NEED_WINDOW_FULL_SCREEN: string[] =
  ['pageflip/PageFlip', 'bottomdrawerslidecase/BottomDrawerSlideComponent', 'customscan/CustomScanPageComponent',
    'diggingholescreen/DiggingHoleScreen', 'effectKit/MainPage', 'immersive/ImmersiveView',
    'mediafullscreen/MediaFullScreen', 'secondfloorloadanimation/SecondFloorLoadAnimation',
    'statusbaranimation/StatusBarAnimation', 'videocreategif/VideoCreateGifView',
    'videoscreendirectionswitching/VideoScreenDirectionSwitching',
    'miniplayeranimation/MiniPlayerAnimationComponent', 'dynamicattributes/ShoppingCartComponent',
    'foldablescreencases/MusicPlayerPageComponent',
    'videotrimmer/VideoDetail', 'videotrimmer/VideoUpload', 'clickanimation/ClickAnimationPage',
    'videoscreendirectionswitching/VideoScreenDirectionSwitching', 'shortvideo/ShortVideoComponent']; // 需要设置窗口全屏的案例

const LAYOUT_WEIGHT: number = 1; // layoutWeight值
let storage = LocalStorage.getShared(); // 从卡片处点击时获取的LocalStorage
const PRIVACY_AGREEMENT = '隐私协议';
const USER_AGREEMENT = '用户协议';
const AGC_APP_LINK = "https://appgallery.huawei.com/app/detail?id=com.north.cases"
const SHARE_TITLE = getContext().resourceManager.getStringSync($r("app.string.EntryAbility_label"));

PersistentStorage.persistProp('home_option_badge_clicked', false);
PersistentStorage.persistProp('home_option_plugin_button_clicked', false);

@Entry(storage)
  // 获取从卡片处点击时的LocalStorage，用于跳转具体案例名称
@Component
struct EntryView {
  @StorageLink('formNavigationRouter') formRouter: string = '';
  // Navigation路由栈,控制页面跳转
  @Provide('pageStack') pageStack: NavPathStack = DynamicsRouter.navPathStack;
  // TODO:需求：路由栈信息，待后续封装路由管理HAR
  @State listData: SceneModuleInfo[] = waterFlowData;
  @Provide('isFullScreen') isFullScreen: boolean = false;
  @State navigationMode: NavigationMode = NavigationMode.Stack;
  @State curFoldStatus: number = 0;
  @State @Watch('onModeChange') navMode: NavMode = NavMode.DefaultMode;
  @StorageProp('windowSize') @Watch('onWindowSizeChange') windowSize: window.Size = {
    width: display.getDefaultDisplaySync().width,
    height: display.getDefaultDisplaySync().height
  };
  @StorageProp('enterRouteName') enterRouteName: string = '';
  @Provide('swiperDisplayCount') swiperDisplayCount: number = 1; // 首页swiper展示item数量
  @State privacyAgreementUri: string = 'privacyagreement/PrivacyAgreementComponent';
  @State sideBarIsShow: boolean = false;
  @State isMarquee: boolean = false;
  @StorageLink('bottomHeight') bottomHeight: number = 0;
  @StorageLink('currentBreakpoint') @Watch('onWindowSizeChange') currentBreakpoint: string = '';
  private readonly statusBarAnimation: string = 'statusbaranimation/StatusBarAnimation';
  private readonly pageFlipPage: string = 'pageflip/PageFlip';
  private readonly miniPlayerAnimationPage: string = 'miniplayeranimation/MiniPlayerAnimationComponent';
  private readonly bottomDrawerSlideCase: string = 'bottomdrawerslidecase/BottomDrawerSlideCase';
  private readonly loginPage: string = 'multimodaltransion/HalfModalWindow';
  private readonly sharePage: string = "sharebutton/MockSharePage";
  private readonly navdestinationdialog: string = "navdestinationdialog/NavDestinationDialogComponent";
  private readonly keyboardAvoid: string = 'keyboardavoid/KeyboardAvoidComponent';
  private readonly verifyCode: string = 'verifycode/VerifyCodeView';
  private readonly webPageSnapShot: string = 'webpagesnapshot/WebPageSnapshot';
  private readonly transitionAnimation: string = 'transitionanimation/TransitionAnimationComponent';
  private readonly shortVideo: string = 'shortvideo/ShortVideoComponent';
  private screenW: number = px2vp(display.getDefaultDisplaySync().width);
  private readonly DEVICESIZE: number =
    600; // 依据Navigation的mode属性说明，如使用Auto，窗口宽度>=600vp时，采用Split模式显示；窗口宽度<600vp时，采用Stack模式显示。
  private isSecondPressBack: boolean = false; // 在侧滑退出应用时，用于判断是否第二次滑动
  private readonly EXIT_TOAST_DURATION: number = 1800; // 侧滑拦截toast提示时长
  private readonly EXIT_PRESS_BACK_DURATION: number = 1000; // 两次侧滑事件间隔时长
  private readonly OPEN_EMULATOR_TOAST_DURATION: number = 2000; // 模拟器打开应用toast提示时长
  private isFoldable: boolean = false; // 是否为折叠屏
  private windowClass?: window.Window; // 窗口实例
  private pluginText: HashMap<string, ESObject> = new HashMap<string, ESObject>();
  @StorageLink('home_option_badge_clicked') homeOptionBadgeClicked: boolean = false;
  @StorageLink('home_option_plugin_button_clicked') homeOptionPluginButtonClicked: boolean = false;

  aboutToAppear(): void {
    // 获取应用窗口实例
    window.getLastWindow(getContext(this)).then((data: window.Window) => {
      this.windowClass = data;
    });
    this.onWindowSizeChange();
    // 更新helperUrl
    this.updateHelperUri();
    // 存储初始数据用于搜索筛选
    AppStorage.setOrCreate('listData', this.listData);
    // 初始化登录状态
    AppStorage.setOrCreate("login", false);
    GlobalStateDialogManager.getGlobalStateDialogNodeController().setUIContext(this.getUIContext());
    // 存储折叠屏设备信息
    this.isFoldable = display.isFoldable();
    AppStorage.setOrCreate('isFoldable', this.isFoldable);
    // 设置折叠屏展开态下全屏路由信息
    DynamicsRouter.setFullScreenRoutes(FULL_SCREEN_ROUTE);
    // 首次进入应用判断页面展示类型
    this.navMode = NavMode.HomePageMode;
    let innerEvent: emitter.InnerEvent = {
      eventId: 3
    };
    // 收到eventId为3的事件后执行回调函数
    emitter.on(innerEvent, (params) => {
      if (params.data && params.data.navMode) {
        this.navMode = params.data.navMode;
      }
    });
    let backEvent: emitter.InnerEvent = {
      eventId: 100
    };
    // 收到eventId为3的事件后执行回调函数
    emitter.on(backEvent, (params) => {
      DynamicsRouter.popAppRouter();
    });
    // 获取当前设备外部产品系列
    const marketNameInfo: string = deviceInfo.marketName;
    if (marketNameInfo === 'emulator') {
      promptAction.showToast({
        message: $r('app.string.app_open_emulator_toast_msg'),
        duration: this.OPEN_EMULATOR_TOAST_DURATION
      });
    }
    // TODO：知识点： 默认加载一个空白的Web组件，预先拉起Web渲染进程
    createNWeb('about://blank', this.getUIContext());
    this.initPluginText();
  }

  onPageShow(): void {
    let shareImageUri: string | undefined = AppStorage.get('imageUri');
    if (shareImageUri !== '' && shareImageUri !== undefined) {
      if (DynamicsRouter.appRouterStack.find(item => (item.name === 'shareimagepage/ShareImagePage')) === undefined) {
        DynamicsRouter.pushUri('shareimagepage/ShareImagePage');
      }
    }
    // 从卡片进入页面时判断具体跳转页面
    if (this.formRouter) {
      waterFlowData.forEach((item: SceneModuleInfo) => {
        let index = item.appUri.indexOf(this.formRouter);
        if (index > -1) {
          if (DynamicsRouter.appRouterStack.slice(-1)[0].name !== item.appUri) {
            DynamicsRouter.clear();
            DynamicsRouter.pushUri(item.appUri);
          }
          return;
        }
      })
      this.formRouter = '';
    }
  }

  // 侧滑返回拦截功能：用于首页侧滑返回时，需在1秒内侧滑两次才能退出应用
  onBackPress(): boolean {
    if (this.sideBarIsShow) {
      animateTo({
        duration: 300
      }, () => {
        this.sideBarIsShow = false;
      })
      return true;
    }
    // 若子路由还发生了跳转先返回再退出应用
    if (this.pageStack.size() > 0) {
      DynamicsRouter.popAppRouter();
      return true;
    }
    if (this.isSecondPressBack) {
      return false;
    } else {
      this.isSecondPressBack = true;
      setTimeout(() => {
        this.isSecondPressBack = false;
      }, this.EXIT_PRESS_BACK_DURATION);
      promptAction.showToast({
        message: $r('app.string.app_exit_toast_msg'),
        duration: this.EXIT_TOAST_DURATION
      });
      return true;
    }
  }

  onModeChange() {
    // 获取路由栈最后一个路由的名称
    let lastRouteName = DynamicsRouter.appRouterStack.slice(-1)[0].name;
    switch (this.navMode) {
      // 当设备折叠态发生改变或屏幕旋转时响应以下逻辑
      case NavMode.FoldMode:
        // 全屏案例在折叠态变化时不需要切换NavigationMode
        if (FULL_SCREEN_ROUTE.includes(lastRouteName)) {
          this.navigationMode = NavigationMode.Stack;
          break;
        }
        if (this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM) {
          if (this.pageStack.size() > 0) {
            // 宽屏条件下且展示了子路由，NavigationMode为Split
            this.navigationMode = NavigationMode.Split;
            this.swiperDisplayCount = 1;
          } else {
            // 宽屏条件下且未展示子路由，NavigationMode为Stack
            this.navigationMode = NavigationMode.Stack;
            this.swiperDisplayCount = 2;
          }
        } else {
          this.navigationMode = NavigationMode.Stack;
          this.swiperDisplayCount = 1;
        }
        break;
    // 当应用进入子路由时响应以下逻辑
      case NavMode.ChildPageMode:
        // 进入全屏案例需切换为Stack
        if (FULL_SCREEN_ROUTE.includes(this.enterRouteName)) {
          this.navigationMode = NavigationMode.Stack;
          break;
        }
        // 根据屏幕宽度决定NavigationMode
        if (this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM) {
          this.navigationMode = NavigationMode.Split;
        } else {
          this.navigationMode = NavigationMode.Stack;
        }
        this.swiperDisplayCount = 1;
        break;
    // 当应用返回首页时响应以下逻辑
      case NavMode.HomePageMode:
        if (this.currentBreakpoint !== BreakpointConstants.BREAKPOINT_SM) {
          this.navigationMode = NavigationMode.Stack;
          this.swiperDisplayCount = 2;
        } else {
          this.navigationMode = NavigationMode.Stack;
          this.swiperDisplayCount = 1;
          this.isFullScreen = false;
        }
        this.pageStack.disableAnimation(false);
        break;
      default:
        break;
    }
    // 重置NavMode
    if (this.navMode !== NavMode.DefaultMode) {
      this.navMode = NavMode.DefaultMode;
    }
  }

  // 屏幕尺寸发生改变时触发navMode改变
  onWindowSizeChange() {
    if (DynamicsRouter.appRouterStack.length > 1 &&
      !FULL_SCREEN_COMPONENT.includes(DynamicsRouter.appRouterStack[1].name)) {
      if (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM) {
        this.navMode = NavMode.HomePageMode;
      } else {
        this.navMode = NavMode.FoldMode;
      }
    }
  }

  updateHelperUri(): void {
    this.listData.forEach((data: SceneModuleInfo) => {
      let moduleName: string = data.appUri.split('/')[0];
      if (data.category.includes('性能示例') && data.name !== '解决相机预览花屏案例') {
        data.helperUrl = HelperConstants.HELPER_URL_PROTOTYPE_PERFERMANCE.replace("{placeholder}", moduleName);
      } else {
        data.helperUrl = HelperConstants.HELPER_URL_PROTOTYPE.replace("{placeholder}", moduleName);
      }
    });
  }

  // 取消全屏
  cancelFullScreen(name: string): void {
    if (NEED_WINDOW_FULL_SCREEN.includes(name)) {
      this.windowClass?.setWindowLayoutFullScreen(false)
        .then(() => {
          this.windowClass?.setWindowSystemBarEnable(['status', 'navigation']);
          let sysBarProps: window.SystemBarProperties = {
            statusBarContentColor: '#000000'
          };
          this.windowClass?.setWindowSystemBarProperties(sysBarProps);
        })
    }
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
      .onWillDisappear(() => {
        // 设置了全屏的案例在退出时取消全屏
        this.cancelFullScreen(name);
      })
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
        } else if (name === this.shortVideo) {
          let innerEvent: emitter.InnerEvent = { eventId: 8 }
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
      .padding({ bottom: px2vp(this.bottomHeight) })
      .onShown(() => {
        this.windowClass?.setWindowLayoutFullScreen(true);
      })
      .onWillDisappear(() => {
        // 设置了全屏的案例在退出时取消全屏
        this.cancelFullScreen(name);
      })
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
    } else if (this.sharePage === name) {
      NavDestination() {
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      .onWillDisappear(() => {
        // 设置了全屏的案例在退出时取消全屏
        this.cancelFullScreen(name);
      })
      .onBackPressed(() => {
        let innerEvent: emitter.InnerEvent = { eventId: 4 }
        let eventData: emitter.EventData = {
          data: {
            "backPressed": true
          }
        }
        emitter.emit(innerEvent, eventData);
        DynamicsRouter.popAppRouter();
        return true;
      })
      // 登录页是半模态，需要背景透明，设置为DIALOG
      .mode(NavDestinationMode.DIALOG)
      .hideTitleBar(true)
    } else if (this.loginPage === name) {
      NavDestination() {
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      .onWillDisappear(() => {
        // 退出时取消全屏
        this.cancelFullScreen(name);
      })
      // 登录页是半模态，需要背景透明，设置为DIALOG
      .mode(NavDestinationMode.DIALOG)
      .hideTitleBar(true)
    } else if (name === this.keyboardAvoid) {
      // 显示标题
      NavDestination() {
        this.navDestinationTitle(name);
        // 根据模块名，获取WrappedBuilder对象，通过builder接口创建页面
        DynamicsRouter.getBuilder(name).builder(param);
      }
      .onWillDisappear(() => {
        // 设置了全屏的案例在退出时取消全屏
        this.cancelFullScreen(name);
      })
      .padding({
        bottom: 64
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
      .onHidden(() => {
        // 设置了全屏的案例在退出时取消全屏
        this.cancelFullScreen(name);
      })
      .padding({
        bottom: 64
      })
      .backgroundColor($r('app.color.main_background_color'))
      .hideTitleBar(true)
      .onBackPressed(() => {
        if (name === this.verifyCode) {
          let innerEvent: emitter.InnerEvent = { eventId: 5 }
          let eventData: emitter.EventData = {
            data: {
              "backPressed": true
            }
          }
          emitter.emit(innerEvent, eventData);
          return true;
        } else if (name === this.transitionAnimation) {
          let innerEvent: emitter.InnerEvent = { eventId: 7 }
          let eventData: emitter.EventData = {
            data: {
              "backPressed": true
            }
          }
          emitter.emit(innerEvent, eventData);
          return true;
        } else if (this.navdestinationdialog === name) {
          let innerEvent: emitter.InnerEvent = { eventId: 4 }
          let eventData: emitter.EventData = {
            data: {
              "backPressed": true
            }
          }
          emitter.emit(innerEvent, eventData);
          return false;
        }
        DynamicsRouter.popAppRouter();
        return true;
      })
    }
  }

  @Builder
  navDestinationTitle(name: string) {
    Column() {
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
              } else if (name === this.webPageSnapShot ||
                name === "networkstatusobserver/NetworkStatusObserverComponent") {
                // 页面长截图案例中，拦截左上角返回按钮点击事件
                let innerEvent: emitter.InnerEvent = { eventId: 6 };
                emitter.emit(innerEvent);
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
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .fontSize($r('app.integer.nav_destination_title_text_size'))
              .margin({ left: $r('app.integer.nav_destination_title_text_margin') })
              .width(AppStorage.get('isFoldable') ? $r('app.integer.nav_destination_title_text_foldable_width') :
              $r('app.integer.nav_destination_title_text_width'))
              .onDisAppear(() => {
                this.isMarquee = false;
              })
              .onAppear(() => {
                setTimeout(() => {
                  this.isMarquee = true;
                }, 5000)
              })
              .textOverflow(this.isMarquee ? { overflow: TextOverflow.MARQUEE } : { overflow: TextOverflow.None })
              .id('case_name')
          }

          HelperView({ name: name })
            .visibility(this.getModuleTitle(name) === PRIVACY_AGREEMENT ||
              this.getModuleTitle(name) === USER_AGREEMENT ?
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
  }

  // 侧边栏遮罩层
  @Builder
  OverlayNode() {
    Row() {
    }
    .onClick(() => {
      animateTo({
        duration: 300
      }, () => {
        this.sideBarIsShow = false;
      })
    })
    .visibility(this.sideBarIsShow ? Visibility.Visible : Visibility.Hidden)
    .width('100%')
    .height('120%')
    .backgroundColor(Color.Black)
    .opacity(0.3)
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

  initPluginText() {
    this.pluginText.set('text', '开发插件');
    this.pluginText.set('fontColor', Color.Black);
    this.pluginText.set('backgroundColor', Color.White);
    this.pluginText.set('width', '100%');
  }

  build() {
    Stack() {
      SideBarContainer(SideBarContainerType.Overlay) {
        Column() {
          Column({ space: 16 }) {
            Button($r('app.string.privacy_agreement'))
              .width('100%')
              .backgroundColor(Color.White)
              .fontColor(Color.Black)
              .onClick(() => {
                animateTo({
                  duration: 300
                }, () => {
                  this.sideBarIsShow = false;
                })
                let context = getContext() as common.UIAbilityContext
                context.resourceManager.getStringValue($r('app.string.privacy_agreement')).then((data) => {
                  AppStorage.setOrCreate('agreementTitle', data)
                  FoldableRouter.pushUri('privacyagreement/PrivacyAgreementComponent', '');
                })
              })

            Button($r('app.string.user_agreement'))
              .width('100%')
              .backgroundColor(Color.White)
              .fontColor(Color.Black)
              .onClick(() => {
                animateTo({
                  duration: 300
                }, () => {
                  this.sideBarIsShow = false;
                })
                let context = getContext() as common.UIAbilityContext
                context.resourceManager.getStringValue($r('app.string.user_agreement')).then((data) => {
                  AppStorage.setOrCreate('agreementTitle', data)
                  FoldableRouter.pushUri('privacyagreement/PrivacyAgreementComponent', '');
                })
              })
            ShareButton({
              url: AGC_APP_LINK,
              linkTitle: SHARE_TITLE
            }) {
              Button($r('app.string.entry_quick_share'))
                .width('100%')
                .backgroundColor(Color.White)
                .fontColor(Color.Black)
            }

            HelperView({
              helperUrl: HelperConstants.IDE_PLUGIN_URL,
              textInfoMap: this.pluginText
            })
          }

          Text($r('app.string.cases_version_number'))
            .fontSize($r('app.integer.nav_destination_title_padding'))
            .opacity(0.7)
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({
          left: $r('app.integer.nav_destination_title_padding'),
          right: $r('app.integer.nav_destination_title_padding'),
        })
        .backgroundColor($r('app.color.advertising_backgroundColor'))
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        Navigation(this.pageStack) {
          // 使用规避手段增加外层嵌套，待系统问题修复后去除
          Column() {
            Row() {
              // 首页搜索组件
              SearchComponent()

              if (this.homeOptionBadgeClicked && this.homeOptionPluginButtonClicked) {
                Image($r('app.media.ic_public_drawer_filled'))
                  .margin({ left: $r('app.integer.privacy_agreement_dialog_button_margin_left') })
                  .width($r('app.integer.advertising_page_font_size'))
                  .height($r('app.integer.advertising_page_font_size'))
                  .onClick(() => {
                    animateTo({
                      duration: 300
                    }, () => {
                      this.sideBarIsShow = true;
                    })
                  })
              } else {
                Badge({
                  value: '',
                  style: { badgeSize: 10, badgeColor: $r('app.color.home_option_badge_color') },
                }) {
                  Image($r('app.media.ic_public_drawer_filled'))
                    .margin({ left: $r('app.integer.privacy_agreement_dialog_button_margin_left') })
                    .width($r('app.integer.advertising_page_font_size'))
                    .height($r('app.integer.advertising_page_font_size'))
                    .onClick(() => {
                      animateTo({
                        duration: 300
                      }, () => {
                        this.sideBarIsShow = true;
                        AppStorage.setOrCreate('home_option_badge_clicked', true);
                        PersistentStorage.persistProp('home_option_badge_clicked', true);
                      })
                    })
                }
                .padding({
                  right: $r('app.integer.home_option_badge_padding_right')
                })
              }

            }
            .justifyContent(FlexAlign.SpaceBetween)
            .padding({
              left: $r('app.integer.search_component_search_foldable_padding1'),
              right: $r('app.integer.search_component_search_foldable_padding1')
            })
            .width('100%')

            Scroll() {
              Column() {
                // 首页轮播图组件
                HomePageSwiper()
                // 首页列表组件
                FunctionalScenes({ listData: this.listData })
              }
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
            }
            .width('100%')
            .layoutWeight(LAYOUT_WEIGHT)
            .scrollBar(BarState.Off)
            .scrollable(ScrollDirection.Vertical)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          }
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        }
        .overlay(this.OverlayNode())
        .backgroundColor($r('app.color.main_background_color'))
        .hideTitleBar(true)
        .navBarWidth($r('app.string.entry_half_size'))
        .hideNavBar(this.isFullScreen)
        .navDestination(this.pageMap)
        .mode(this.navigationMode)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .sideBarWidth(180)
      .showSideBar($$this.sideBarIsShow)
      .showControlButton(false)
      .sideBarPosition(SideBarPosition.End)
      .clip(false)


      // 全局状态保留能力弹窗
      GlobalStateDialog()
    }
    .alignContent(Alignment.BottomEnd)
    .height('100%')
    .backgroundColor($r('app.color.main_background_color'))
  }
}