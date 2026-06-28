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

import { deviceInfo } from '@kit.BasicServicesKit';
import pageFlipTest from './feature/PageFlip.test';
import customAddressPickerTest from './feature/CustomAddressPicker.test';
import customAnimationTabTest from './feature/CustomAnimationTab.test';
import expandTitleTest from './feature/ExpandTitle.test';
import databaseUpgradeTest from './feature/DataBaseUpgrade.test';
import immersiveViewTest from './feature/ImmersiveView.test';
import imperativeViewTest from './feature/ImperativeView.test';
import paintComponentTest from './feature/PaintComponent.test';
import statusBarAnimationTest from './feature/StatusBarAnimation.test';
import pipWindowTest from './feature/PipWindow.test';
import votingComponentTest from './feature/VotingComponent.test';
import verticalHorizontalLinkageTest from './feature/VerticalHorizontalLinkage.test';
import hiLogMonitorManagementTest from './feature/HiLogMonitorManagement.test';
import bottomDrawerSlideCaseTest from './feature/BottomDrawerSlideCase.test';
import bottomPanelSlideTest from './feature/BottomPanelSlide.test';
import nativeRawfileTest from './feature/NativeRawFile.test';
import navigationParameterTransferTest from './feature/NavigationParameterTransfer.test';
import nativeSavePicToSandboxTest from './feature/NativeSavePicToSandbox.test';
import gridExchangeTest from './feature/GridExchange.test';
import keyboardAvoidTest from './feature/KeyboardAvoid.test';
import chatWithExpressionTest from './feature/ChatWithExpression.test';
import imageMosaicTest from './feature/ImageMosaic.test';
import imageDepthCopyTest from './feature/ImageDepthCopy.test';
import bluetoothTest from './feature/Bluetooth.test';
import multipleFilesDownloadTest from './feature/MultipleFilesDownload.test';
import akiUsePracticeTest from './feature/AkiUsePractice.test';
import groupAvatarTest from './feature/GroupAvatar.test';
import pageTurningAnimationTest from './feature/PageTurningAnimation.test';
import imageCompressionTest from './feature/ImageCompression.test';
import barChartTest from './feature/BarChart.test';
import miniPlayerAnimationTest from './feature/MiniPlayerAnimation.test';
import calendarSwitchTest from './feature/CalendarSwitch.test';
import skeletonDiagramTest from './feature/SkeletonDiagram.test';
import operateRDBInTaskPoolTest from './feature/OperateRDBInTaskPool.test';
import webPDFViewerTest from './feature/WebPDFViewer.test';
import componentStackTest from './feature/ComponentStack.test';
import fitForDarkModeTest from './feature/FitForDarkMode.test';
import pageLoadingTest from './feature/PageLoading.test';
import nativeProgressNotifyTest from './feature/NativeProgressNotify.test';
import clickAnimationTest from './feature/ClickAnimation.test';
import collapseMenuTest from './feature/CollapseMenu.test'
import decompressFileTest from './feature/DecompressFile.test';
import handWritingToImageTest from './feature/HandWritingToImage.test';
import compressFileTest from './feature/CompressFile.test';
import photoPickAndSaveTest from './feature/PhotoPickAndSave.test';
import waterRipplesTest from './feature/WaterRipples.test';
import listSlideToHistoryTest from './feature/ListSlideToHistory.test';
import imageTheftTest from './feature/ImageTheft.test';
import addressExchangeTest from './feature/AddressExchange.test';
import blendModeTest from './feature/BlendMode.test';
import clockInTest from './feature/ClockIn.test';
import customDrawTabBarTest from './feature/CustomDrawTabBar.test';
import customReusablePoolTest from './feature/CustomReusablePool.test';
import customViewTest from './feature/CustomView.test';
import dragToSwitchPictureTest from './feature/DragToSwitchPicture.test';
import handleTabsTest from './feature/HandleTabs.test';
import highLightGuideTest from './feature/HighLightGuide.test';
import iconMainColorComponentTest from './feature/IconMainColorComponent.test';
import imageCommentComponentTest from './feature/ImageCommentComponent.test';
import indicatorBelowSwiperTest from './feature/IndicatorBelowSwiper.test';
import listExchangeTest from './feature/ListExchange.test';
import navigationBarChangeTest from './feature/NavigationBarChange.test';
import paletteTest from './feature/Palette.test';
import secondFloorLoadAnimationTest from './feature/SecondFloorLoadAnimation.test';
import shortVideoTest from './feature/ShortVideo.test';
import styledTextTest from './feature/StyledText.test';
import videoCacheTest from './feature/VideoCache.test';
import videoCreateGifTest from './feature/VideoCreateGif.test';
import videoLinkageListTest from './feature/VideoLinkageList.test';
import videoListAutoplayTest from './feature/VideoListAutoplay.test';
import webCustomPressMenuTest from './feature/WebCustomPressMenu.test';
import webPageSnapShotTest from './feature/WebPageSnapShot.test';
import toolBoxTest from './feature/ToolBox.test';
import pendingItemsTest from './feature/PendingItems.test';
import chineseToPinyinTest from './feature/ChineseToPinyin.test';
import citySearchTest from './feature/CitySearch.test';
import gbkTranscodingTest from './feature/GbkFriendsBook.test';
import highlyLoadedComponentRenderTest from './feature/HighlyLoadedComponentRender.test';
import imageEnableAnalyzerTest from './feature/ImageEnableAnalyzer.test';
import secondaryLinkageTest from './feature/SecondaryLinkage.test';
import sideBarAnimationTest from './feature/SideBarAnimation.test';
import slideToHideAndDisplaceTest from './feature/SlideToHideAndDisplace.test';
import searchSwiperTest from './feature/SearchSwiper.test';
import pullToRefreshNewsTest from './feature/PullToRefreshNews.test';
import sendMessageTest from './feature/SendMessage.test';
import selectTextMenuTest from './feature/SelectTextMenu.test';
import textOverflowTest from './feature/TextOverflow.test';
import modalWindowTest from './feature/ModalWindow.test';
import multiModalTransitionTest from './feature/MultiModalTransition.test';
import navigationInterceptorTest from './feature/NavigationInterceptor.test';
import addressRecognizeTest from './feature/AddressRecognize.test';
import applicationExceptionTest from './feature/ApplicationException.test';
import analogClockTest from './feature/AnalogClock.test';
import containerNestedSlideTest from './feature/ContainerNestedSlide.test';
import customCalendarPickerDialogTest from './feature/CustomCalendarPickerDialog.test';
import editAddressTest from './feature/EditAddress.test';
import addressPopUpTest from './feature/AddressPopUp.test';
import decodeHEIFImageTest from './feature/DecodeHEIFImage.test';
import bigFileCopyTest from './feature/BigFileCopy.test';
import customDialogTest from './feature/CustomDialog.test';
import customSafeKeyboardTest from './feature/CustomSafeKeyboard.test';
import customStepperTest from './feature/CustomStepper.test';
import customTabBarTest from './feature/CustomTabBar.test';
import eventPropagationTest from './feature/EventPropagation.test';
import fontDynamicRegistrationTest from './feature/FontDynamicRegistration.test';
import functionalScenesTest from './feature/FunctionalScenes.test';
import h5CacheTest from './feature/H5Cache.test';
import healthChartTest from './feature/HealthChart.test';
import imageViewerTest from './feature/ImageViewer.test';
import liveDetectionAndEncryptiondTest from './feature/LiveDetectionAndEncryptiond.test';
import mediaFullScreenTest from './feature/MediaFullScreen.test';
import listItemOverflowTest from './feature/ListItemOverflow.test';
import preRenderingTest from './feature/PreRendering.test';
import publishMultimediaUpdatesTest from './feature/PublishMultimediaUpdates.test';
import searchComponentTest from './feature/SearchComponent.test';
import shareImagePageTest from './feature/ShareImagePage.test';
import swiperComponentTest from './feature/SwiperComponent.test';
import swiperSmoothVariationTest from './feature/SwiperSmoothVariation.test';
import tabContentOverFlowTest from './feature/TabContentOverFlow.test';
import textExpandTest from './feature/TextExpand.test';
import variableWatchTest from './feature/VariableWatch.test';
import videoScreenDirectionSwitchingTest from './feature/VideoScreenDirectionSwitching.test';
import voiceRecordDynamicEffectTest from './feature/VoiceRecorDynamicEffect.test';
import networkStatusObserverTest from './feature/NetworkStatusObserverView.test';
import componentInstanceSharedInPagesTest from './feature/ComponentInstanceSharedInPages.test';
import dragAndExchangeTest from './feature/DragAndExchange.test';
import dynamicAttributesTest from './feature/DynamicAttributes.test';
import etsWrapperTest from './feature/EtsWrapper.test';
import faceAndFingerPrintLockingTest from './feature/FaceAndFingerPrintLocking.test';
import imageGridLayoutTest from './feature/ImageGridLayout.test';
import limitedHeightBottomDialogTest from './feature/LimitedHeightBottomDialog.test';
import multipleScreeningTest from './feature/MultipleScreening.test';
import nativeEmbedTest from './feature/NativeEmbed.test';
import sideSlipInterceptTest from './feature/SideSlipIntercept.test';
import transitionAnimationTest from './feature/TransitionAnimation.test';
import customScanTest from './feature/CustomScan.test';
import foldableScreenCasesTest from './feature/FoldableScreenCases.test';
import dealStrideSolutionTest from './feature/DealStrideSolution.test';
import videoTrimmerTest from './feature/VideoTrimmer.test';
import shareButtonTest from './feature/ShareButton.test';
import danmakuPlayerTest from './feature/DanmakuPlayer.test';

/**
 * 主要功能：引入添加feature中编写的测试用例
 */
export default function assembleTestCase() {
  // 弹幕播放案例
  danmakuPlayerTest();
  // 模拟时钟案例
  analogClockTest();
  // 应用异常信息获取案例
  applicationExceptionTest();
  // 折叠屏音乐播放器案例
  foldableScreenCasesTest();
  // 折叠屏扫描二维码方案
  customScanTest();
  // 视频下载保存及剪辑压缩上传(测试前需参照feature模块readme配置http服务器，并修改VideoTrimmer.test.ets文件中server_url的地址)
  videoTrimmerTest();
  // 解决相机预览花屏案例
  dealStrideSolutionTest();
  // 短视频切换
  shortVideoTest();
  // 页面间共享组件实例
  componentInstanceSharedInPagesTest();
  // Grid和List内拖拽交换子组件位置
  dragAndExchangeTest();
  // 跨文件样式复用和组件复用
  dynamicAttributesTest();
  // 图片九宫格封装案例用
  imageGridLayoutTest();
  // 限制高度底部弹窗
  limitedHeightBottomDialogTest();
  // 滑动视频自动播放
  multipleScreeningTest();
  // ArkWeb同层渲染
  nativeEmbedTest();
  // 侧滑返回事件拦截
  sideSlipInterceptTest();
  // 页面转场一镜到底动画
  transitionAnimationTest();
  // 大文件拷贝案例
  bigFileCopyTest();
  // 全局弹窗封装案例
  customDialogTest();
  // 自定义安全键盘案例
  customSafeKeyboardTest();
  // 自定义Stepper
  customStepperTest();
  // 自定义TabBar页签案例
  customTabBarTest();
  // 阻塞事件冒泡
  eventPropagationTest();
  // 动态注册字体案例
  fontDynamicRegistrationTest();
  // 主页瀑布流实现案例
  functionalScenesTest();
  // H5页面资源离线缓存案例
  h5CacheTest();
  // MpChart运动健康
  healthChartTest();
  // 图片缩放效果实现案例
  imageViewerTest();
  // 人脸识别验证案例
  liveDetectionAndEncryptiondTest();
  // 元素超出List区域
  listItemOverflowTest();
  // 网络状态监听
  networkStatusObserverTest();
  // 使用预渲染实现Web页面顺开效果实践
  preRenderingTest();
  // 搜索功能实现案例
  searchComponentTest();
  // 多层级轮播图案例
  swiperComponentTest();
  // Swiper高度可变化效果实现
  swiperSmoothVariationTest();
  // tabContent内容可以在tabBar上显示并响应滑动事件案例
  tabContentOverFlowTest();
  // 文字展开收起案例
  textExpandTest();
  // 多层嵌套类对象监听
  variableWatchTest();
  // 视频横竖屏切换及进度条热区拖动案例
  videoScreenDirectionSwitchingTest();
  // 语音录制和声音动效实现案例
  voiceRecordDynamicEffectTest();
  // 页面间共享组件实例的案例
  addressPopUpTest();
  // 编辑收货地址案例
  editAddressTest();
  // 自定义日历选择器案例
  customCalendarPickerDialogTest();
  // Scroll容器嵌套多种组件事件处理案例
  containerNestedSlideTest();
  // Navigation路由拦截案例
  navigationInterceptorTest();
  // 多模态页面转场动效实现案例
  multiModalTransitionTest();
  // 全屏登录页面案例
  modalWindowTest();
  // textOverflow长文本省略案例
  textOverflowTest();
  // 下拉刷新与上滑加载案例
  pullToRefreshNewsTest();
  // 搜索框热搜词自动滚动
  searchSwiperTest();
  // 滑动页面信息隐藏与组件位移效果案例
  slideToHideAndDisplaceTest();
  // SideBarContainer侧边栏淡入淡出动效实现案例
  sideBarAnimationTest();
  // 列表二级联动
  secondaryLinkageTest();
  // 合理处理高负载组件的渲染文章示例代码
  highlyLoadedComponentRenderTest();
  // GBK文本格式解码
  gbkTranscodingTest();
  // 城市选择案例
  citySearchTest();
  // 汉字转拼音案例
  chineseToPinyinTest();
  // 列表编辑
  pendingItemsTest();
  // 页面长截图
  webPageSnapShotTest();
  // Web自定义长按菜单案例
  webCustomPressMenuTest();
  // 滑动视频自动播放
  videoListAutoplayTest();
  // 视频卡片和列表区域的联动滚动
  videoLinkageListTest();
  // 视频截取gif图
  videoCreateGifTest();
  // 边缓存边播放案例
  videoCacheTest();
  // Text实现部分文本高亮和超链接样式
  styledTextTest();
  // 首页下拉进入二楼效果案例
  secondFloorLoadAnimationTest();
  // 画笔调色板案例
  paletteTest();
  // 状态栏显隐变化
  navigationBarChangeTest();
  // 列表项交换案例
  listExchangeTest();
  // swiper指示器导航点位于swiper下方
  indicatorBelowSwiperTest();
  // 根据icon自适应背景颜色
  iconMainColorComponentTest();
  // 应用新功能引导实现案例
  highLightGuideTest();
  // Tab组件实现增删tab案例
  handleTabsTest();
  // 手写绘制及保存图片
  handWritingToImageTest();
  // 左右拖动切换图片效果案例
  dragToSwitchPictureTest();
  // Worker子线程中解压文件
  decompressFileTest();
  // 自定义视图实现Tab效果
  customViewTest();
  // 全局自定义组件复用实现案例
  customReusablePoolTest();
  // 自定义TabBar页签凸起和凹陷案例
  customDrawTabBarTest();
  // 图片混合案例
  blendModeTest();
  // 地址交换动画案例
  addressExchangeTest();
  // 配置ImageKnife请求头实现防盗链功能
  imageTheftTest();
  // 长列表滑动到指定列表项动效实现案例
  listSlideToHistoryTest();
  // 水波纹动画案例
  waterRipplesTest();
  //折叠面板案例
  collapseMenuTest();
  // 文件压缩案例
  compressFileTest();
  // 直播界面双击效果动画实现案例
  clickAnimationTest();
  // 在Native侧实现进度通知功能
  nativeProgressNotifyTest();
  // PixelMap深拷贝案例
  imageDepthCopyTest();
  // 悬浮工具箱案例
  toolBoxTest();
  // 群头像拼接案例
  groupAvatarTest();
  // 组件随软键盘弹出避让案例
  keyboardAvoidTest();
  // 图片编辑实现马赛克效果
  imageMosaicTest();
  // 表情聊天案例
  chatWithExpressionTest();
  // Navigation页面跳转对象传递案例
  navigationParameterTransferTest();
  // 阅读翻页方式案例
  pageFlipTest();
  // 底部抽屉滑动效果案例
  bottomDrawerSlideCaseTest();
  // 底部面板嵌套列表滑动案例
  bottomPanelSlideTest();
  // 预加载so并读取RawFile文件
  nativeRawfileTest();
  // 监听HiLog日志实现测试用例验证
  hiLogMonitorManagementTest();
  // 自定义地址选择案例
  customAddressPickerTest();
  // 网格元素交换案例
  gridExchangeTest();
  // 纵向横向列表联动
  verticalHorizontalLinkageTest();
  // 视频悬浮窗
  pipWindowTest();
  // 标题下拉案例
  expandTitleTest();
  // 自定义动效tab案例
  customAnimationTabTest();
  // 沉浸式适配案例
  immersiveViewTest();
  // 使用ArkUI的FrameNode扩展实现动态布局类框架
  imperativeViewTest();
  // 数据库版本升级案例
  databaseUpgradeTest();
  // 投票动效实现案例
  votingComponentTest();
  // 使用绘制组件实现自定义进度动画案例
  paintComponentTest();
  // 状态栏动画案例
  statusBarAnimationTest();
  // 骨架屏实现案例
  skeletonDiagramTest();
  // 在TaskPool线程中操作关系型数据库实现案例
  operateRDBInTaskPoolTest();
  // 页面加载效果实现案例
  pageLoadingTest();
  // Web组件预览PDF文件实现案例
  webPDFViewerTest();
  // 滚动吸顶效果实现案例
  componentStackTest();
  // 深色模式案例
  fitForDarkModeTest();
  // 多文件下载监听案例
  multipleFilesDownloadTest();
  // 使用AKI轻松实现跨语言调用
  akiUsePracticeTest();
  // 翻页动效案例
  pageTurningAnimationTest();
  // 图片压缩方案
  imageCompressionTest();
  // MpChart图表实现案例
  barChartTest();
  // 音乐播放转场一镜到底效果实现
  miniPlayerAnimationTest();
  // 日历切换案例
  calendarSwitchTest();
  if (deviceInfo.abiList.includes('arm64-v8a')) {
    // Native保存图片到应用沙箱
    nativeSavePicToSandboxTest();
  }
  if (deviceInfo.productModel !== 'emulator') {
    // 分享二维码按钮案例
    shareButtonTest()
    // 人脸指纹解锁案例
    faceAndFingerPrintLockingTest();
    // NAPI封装ArkTS接口
    etsWrapperTest();
    // 图片分享案例
    shareImagePageTest();
    // 视频全屏切换案例
    mediaFullScreenTest();
    // HEIF软解码器案例
    decodeHEIFImageTest();
    // 多媒体发布
    publishMultimediaUpdatesTest();
    // 文本选择菜单案例
    selectTextMenuTest();
    // AI图片文字智能识别
    addressRecognizeTest();
    // 图片拖拽AI抠图案例
    imageEnableAnalyzerTest();
    // 发短信案例
    sendMessageTest();
    // 发布图片评论
    imageCommentComponentTest();
    // 地图定位打卡案例
    clockInTest();
    // 模拟器不支持拍照
    // 图片选择与下载保存案例
    photoPickAndSaveTest();
    // 模拟器不支持蓝牙验证
    // 测试前请确保其他设备已经开启蓝牙心率服务，否则会影响部分蓝牙测试用例通过
    // 蓝牙实现服务端和客户端通讯
    bluetoothTest();
  }
}