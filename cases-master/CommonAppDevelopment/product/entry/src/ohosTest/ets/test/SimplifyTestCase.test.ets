/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { it } from "@ohos/hypium";
import { Driver, ON } from "@kit.TestKit";
import exit from "./common/Exit.test";
import searchCaseClickIn from "./common/SearchCaseClickIn.test";

const Cases =
  ['地址交换动画', '自定义TabBar页签案例', '全屏登录页面', 'MpChart图表实现案例', '滑动页面信息隐藏与组件位移效果案例',
    '图片缩放效果实现', '阻塞事件冒泡', '列表二级联动', '列表编辑', '预加载so并读取RawFile文件', 'GBK文本格式解码',
    'Tab组件实现增删Tab标签', '使用AKI轻松实现跨语言调用', '多层嵌套类对象监听', '图片选择和下载保存案例',
    '应用异常处理案例', '深色模式案例', '跑马灯案例', '下拉刷新与上滑加载案例', '翻页动效案例',
    '在Native侧实现进度通知功能', '验证码布局', '使用弹簧曲线实现抖动动画及手机振动效果案例',
    '状态栏显隐变化', 'Navigation页面跳转对象传递案例', '视频全屏切换案例', '发布图片评论',
    '折叠屏音乐播放器案例', 'Worker子线程中解压文件', '自定义视图实现Tab效果', '滚动吸顶效果实现案例',
    '自定义日历选择器', '听歌识曲水波纹特效案例', 'Swiper高度可变化效果实现', '多层级轮播图方案',
    '城市选择案例', '短视频切换', 'Native保存图片到应用沙箱', '页面加载效果实现案例',
    'SideBarContainer侧边栏淡入淡出', 'Lottie动画', '图片压缩方案', '使用绘制组件实现自定义进度动画',
    '标题下拉缩放案例', '长列表滑动到指定列表项动效实现案例', '图片拖拽AI抠图案例', '数字滚动动效实现',
    '元素超出List区域', 'Web获取相机拍照图片案例', '大文件拷贝案例', 'MpChart运动健康', '底部抽屉滑动效果案例',
    '汉字转拼音案例', '投票动效实现案例', '左右拖动切换图片效果案例', '适配挖孔屏案例', '自定义安全键盘案例',
    '多文件下载监听案例', '页面间共享组件实例的案例', 'ArkWeb同层渲染', 'NAPI封装ArkTS接口案例',
    '侧滑返回事件拦截案例', 'swiper指示器导航点位于swiper下方', '页面转场一镜到底动画', '多模态页面转场动效实现案例',
    '手写绘制及保存图片', '配置ImageKnife请求头实现防盗链功能', '应用新功能引导实现案例', '数据库版本升级案例',
    '图片九宫格封装案例', '跨文件样式复用和组件复用', 'PixelMap深拷贝案例', 'Web组件预览PDF及office文件实现案例',
    '自定义Swiper卡片预览效果实现', '根据icon自适应背景颜色', '文字识别案例', '使用colorPicker实现背景跟随主题颜色转换',
    '边缓存边播放案例', '动态注册字体案例', '列表项交换案例', '底部面板嵌套列表滑动案例', '阅读翻页方式案例',
    'Web自定义长按菜单案例', '悬浮窗拖拽和吸附动画', '视频弹幕功能', 'Grid和List内拖拽交换子组件位置',
    'Canvas实现模拟时钟案例', 'XComponent + Vsync 实现自定义动画', 'tabContent内容可以在tabBar上显示并响应滑动事件案例',
    '音乐播放转场一镜到底效果实现', '页面长截图', '表情聊天案例', '下拉展开图片和时间轴效果实现案例',
    '网格元素交换案例', '图片混合案例', '首页下拉进入二楼效果案例', 'Text实现部分文本高亮和超链接样式',
    'Navigation路由拦截案例', '文字展开收起案例', '边框或背景图片拉伸案例', '水印案例',
    'textOverflow长文本省略', '边缘渐变实现', '自定义Stepper', '搜索框热搜词自动滚动',
    '合理处理高负载组件的渲染文章示例代码', '视频卡片和列表区域的联动滚动', 'NavDestination弹窗',
    'H5页面调用自定义输入法案例', '全局自定义组件复用实现案例', 'TaskPool线程中操作关系型数据库实现案例', '发短信案例',
    '骨架屏实现案例', '画笔调色板案例', '图片编辑实现马赛克效果', '橡皮擦案例',
    '蓝牙实现服务端和客户端通讯', '使用ArkUI的FrameNode扩展实现动态布局类框架', '滑动视频自动播放',
    '视频横竖屏切换及进度条热区拖动案例', '编辑收货地址案例', '自定义TabBar页签凸起和凹陷案例', '状态栏动画实现案例',
    '纵向横向列表联动', '群头像拼接案例', 'AI图片文字智能识别', 'H5页面资源离线缓存案例', 'HEIF软解码器案例',
    '人脸识别验证案例', '自定义动效tab', '图形锁屏案例', '多媒体发布', '沉浸式适配案例',
    'Scroll容器嵌套多种组件事件处理案例', '背景模糊效果的自定义TabBar实现案例', '图片分享案例', '文本选择菜单案例',
    '视频悬浮窗', '地图定位打卡案例', '文件压缩案例', '自定义地址选择案例', '视频截取gif图',
    '直播界面双击效果动画实现案例', '悬浮工具箱', '网络状态监听', '多重筛选案例', '限制高度底部弹窗',
    '人脸指纹解锁案例', '3D立方体旋转轮播实现案例', '多段混合数据展示', '视频下载保存及剪辑压缩上传', '弹窗封装',
    '智能填充案例'];

/**
 * 主要功能：全量自动化测试用例（只验证应用是否可以正常进入和退出）
 */
export default function simplifyTestCase() {
  for (let i = 0; i < Cases.length; i++) {
    // 案例搜索并进入
    searchCaseClickIn(Cases[i]);
    // 退出案例
    exit(Cases[i]);
  }

  let driver = Driver.create();
  // 折叠屏扫描二维码方案
  searchCaseClickIn('折叠屏扫描二维码方案');
  it('Pop', 0, async (done: Function) => {
    const permission = await driver.findComponent(ON.text('允许'));
    if (permission !== null && permission !== undefined) {
      await permission!.click();
      await driver.delayMs(1000);
    }
    done();
  });
  exit('折叠屏扫描二维码方案');

  // 语音录制和声音动效实现
  searchCaseClickIn('语音录制和声音动效实现');
  it('Pop', 0, async (done: Function) => {
    const permission = await driver.findComponent(ON.text('允许'));
    if (permission !== null && permission !== undefined) {
      await permission!.click();
      await driver.delayMs(1000);
    }
    done();
  });
  exit('语音录制和声音动效实现');

  // 全局弹窗封装案例
  searchCaseClickIn('全局弹窗封装案例');
  it('Pop', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text('领取红包'));
    let closeButton = await driver.findComponent(ON.id('close_button'));
    await closeButton.click();
    await driver.delayMs(1000);
    done();
  });
  exit('全局弹窗封装案例');

  // 日历切换案例
  searchCaseClickIn('日历切换案例');
  it('Pop', 0, async (done: Function) => {
    const permission = await driver.findComponent(ON.text('允许'));
    if (permission !== null && permission !== undefined) {
      await permission!.click();
      await driver.delayMs(1000);
    }
    done();
  });
  exit('日历切换案例');

  // 组件随软键盘弹出避让案例
  searchCaseClickIn('组件随软键盘弹出避让案例');
  it('KeyBoard', 0, async (done: Function) => {
    // 收起键盘
    await driver.pressBack();
    await driver.delayMs(1000);
    done();
  });
  exit('组件随软键盘弹出避让案例');

  // 解决相机预览花屏案例
  searchCaseClickIn('解决相机预览花屏案例');
  it('Pop', 0, async (done: Function) => {
    const permission = await driver.findComponent(ON.text('允许'));
    if (permission !== null && permission !== undefined) {
      await permission!.click();
      await driver.delayMs(1000);
    }
    done();
  });
  exit('解决相机预览花屏案例');
}