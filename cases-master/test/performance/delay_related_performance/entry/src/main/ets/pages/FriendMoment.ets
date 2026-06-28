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

import { BasicDataSource, FriendMoment } from '../model/BasicDataSource';
import { OneMoment } from './components/OneMoment';
import util from '@ohos.util';
import { ListConstants } from '../constants/ListConstants';
import http from '@ohos.net.http';
import { BusinessError } from '@kit.BasicServicesKit';
import {MomentConstants} from '../constants/MomentConstants'

/**
 * 继承BasicDataSource的类
 */
@Observed
class FriendMomentsData extends BasicDataSource<FriendMoment> {
  momentList: Array<FriendMoment> = [];

  public totalCount(): number {
    return this.momentList.length;
  }

  public getData(index: number): FriendMoment {
    return this.momentList[index];
  }

  public reloadData(): void {
    this.notifyDataReload();
  }

  public addData(index: number, data: FriendMoment): void {
    this.momentList.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  public pushData(data: FriendMoment): void {
    this.momentList.push(data);
    this.notifyDataAdd(this.momentList.length - 1);
  }
}


/** 附近的人主页面
 * 实现步骤：
 * 1.使用LazyForEach+cacheCount+@Reusable实现懒加载列表。
 * 2.创建ListScroller对象，将ListScroller对象绑定到List组件内。
 * 3.在需要记录当前位置时通过currentOffset方法存储当前偏移量historyOffset，在需要跳转时用scrollTo方法跳转。
 */

@Entry
@Component
struct ListSlideToHistory {
  momentData: FriendMomentsData = new FriendMomentsData(); // 公共常亮存放LazyForEach数据实体
  @State endIndex: number = -1;
  @State cachedCountNumber: number = 1; // 懒加载缓存数
  @State firstIndex: number = 0; // 当前显示在屏幕上的子组件索引值，用来控制下方按钮跳转
  listScroller: ListScroller = new ListScroller(); // scroller控制器
  historyOffset: number = 0; // 上次浏览到列表距离顶端的偏移量offset

  aboutToAppear(): void {
    // 一个函数加载10个，为保证初始页面跳转，因此加载20个列表。
    this.getFriendMomentFromRawfile();
    this.getFriendMomentFromRawfile();
  }

  async getFriendMomentFromRawfile(): Promise<void> {
    const resourceManager = getContext().resourceManager;
    const res = await resourceManager.getRawFileContent("list_slide_to_history_mock_data.json");

    interface MyJsonModel {
      friendMoments: FriendMoment[];
    }

    const textDecoder = util.TextDecoder.create();
    const friendMomentArray = (JSON.parse(textDecoder.decodeWithStream(res)) as MyJsonModel).friendMoments;

    friendMomentArray.forEach((item, index) => {
      // 由于获取的json的id是固定0-9，所以使用当前列表数量totalCount的十位部分加上json的id生成新的不重复id。
      item.id = Math.floor(this.momentData.momentList.length / 10) + item.id;
      item.image =
        friendMomentArray[Math.floor(this.momentData.momentList.length / 10)]?.image || friendMomentArray[1].image;
      item.text =
        resourceManager.getStringSync($r('app.string.list_slide_to_history_jump_text_one'), parseInt(item.id) + 1) +
        item.text;
      this.momentData.pushData(item);
      this.momentData.reloadData();
    })
  }

  async getPicFromApi() {
    let httpRequest = http.createHttp();
    httpRequest.request(
      "https://jsonplaceholder.typicode.com/photos/5",// 填写HTTP请求的URL地址，可以带参数也可以不带参数。URL地址需要开发者自定义。请求的参数可以在extraData中指定
      (err: BusinessError, data: http.HttpResponse) => {
        if (!err) {
          console.info('HttpRequest-Result:' + JSON.stringify(data.result).slice(20));
          this.getFriendMomentFromRawfile();
          // data.result为HTTP响应内容，可根据业务需要进行解析
          // 当该请求使用完毕时，开发者务必调用destroy方法主动销毁该JavaScript Object。
          httpRequest.destroy();
        } else {
          console.info('HttpRequest-error:' + JSON.stringify(err));
          // 取消订阅HTTP响应头事件
          httpRequest.off('headersReceive');
          // 当该请求使用完毕时，开发者务必调用destroy方法主动销毁该JavaScript Object。
          httpRequest.destroy();
        }
      });
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.list_slide_to_history_near_message'))
          .fontSize($r('app.integer.list_slide_to_history_title_fontSize'))
          .fontColor($r('app.color.list_slide_to_history_title_font_color'))
          .fontWeight(FontWeight.Bold)
          .margin({ left: $r('app.integer.list_slide_to_history_title_margin_left') })
          .fontFamily($r('app.string.list_slide_to_history_harmony_hei_ti'))
          .lineHeight($r('app.integer.list_slide_to_history_title_line_height'))
          .layoutWeight(ListConstants.LAYOUT_WEIGHT)
      }
      .alignItems(VerticalAlign.Center)
      .height($r('app.integer.list_slide_to_history_title_height'))
      .width($r('app.string.list_slide_to_history_layout_100'))
      .padding({
        left: $r('app.integer.list_slide_to_history_title_padding_left'),
        right: $r('app.integer.list_slide_to_history_title_padding_right'),
        top: $r('app.integer.list_slide_to_history_title_padding_top'),
        bottom: $r('app.integer.list_slide_to_history_title_padding_bottom')
      })

      List({ space: ListConstants.LIST_SPACE, scroller: this.listScroller }) {
        // TODO：高性能知识点：列表数据较多，不需要全部渲染上屏，采用LazyForEach。
        LazyForEach(this.momentData, (moment: FriendMoment) => {
          ListItem() {
            OneMoment({ moment: moment })
          }
        }, (moment: FriendMoment) => moment.id)
      }
      .onScrollStop(() => {
        console.log('onScrollStop', this.endIndex)
        if (this.endIndex === this.momentData.momentList.length - 1) {
          this.getPicFromApi();
        }
      })
      // TODO：高性能知识点：为保证滑动流畅，采用cachedCount缓存前后节点。
      .width($r('app.string.list_slide_to_history_layout_100'))
      .height($r('app.string.list_slide_to_history_layout_100'))
      .listDirection(Axis.Vertical)
      .divider({
        strokeWidth: $r('app.integer.list_slide_to_history_divider_width'),
        color: $r('app.color.list_slide_to_history_divider_color'),
        startMargin: $r('app.integer.list_slide_to_history_list_divider_margin'),
        endMargin: $r('app.integer.list_slide_to_history_list_divider_margin')
      })
      .onScrollIndex((first: number, end: number) => {
        console.log('onScrollIndex', first, end)
        this.firstIndex = first;
        this.endIndex = end;
      })

      Button(this.firstIndex < MomentConstants.SWITCH_BUTTON ? $r('app.string.list_slide_to_history_jump_to_history') :
      $r('app.string.list_slide_to_history_jump_to_top'), {
        type: ButtonType.Normal,
        stateEffect: true
      })
        .fontColor($r('app.color.list_slide_to_history_jump_button_font_color'))
        .height($r('app.integer.list_slide_to_history_jump_button_height'))
        .borderRadius($r('app.integer.list_slide_to_history_jump_button_radius'))
        .backgroundColor($r('app.color.list_slide_to_history_jump_button_bgc'))
        .opacity($r('app.float.list_slide_to_history_jump_button_opacity'))
        .width($r('app.integer.list_slide_to_history_jump_button_width'))
        .position({
          x: $r('app.string.list_slide_to_history_jump_position_x'),
          y: $r('app.string.list_slide_to_history_jump_position_y')
        })
        .markAnchor({ x: $r('app.string.list_slide_to_history_jump_markAnchor_x') })
        .onClick(() => {
          // 当前显示的index值小于设定的SWITCH_BUTTON时，按钮为跳转到上次浏览记录，否则为跳转到顶部
          if (this.firstIndex < MomentConstants.SWITCH_BUTTON) {
            this.listScroller.scrollTo({
              xOffset: 0,
              yOffset: this.historyOffset === 0 ? MomentConstants.DEFAULT_OFFSET : this.historyOffset,
              animation: { duration: MomentConstants.ANIMATION_DURATION, curve: Curve.LinearOutSlowIn }
            });
          } else {
            this.historyOffset = this.listScroller.currentOffset().yOffset;
            this.listScroller.scrollTo({
              xOffset: 0,
              yOffset: 0,
              animation: { duration: MomentConstants.ANIMATION_DURATION, curve: Curve.LinearOutSlowIn }
            });
          }
        })
    }
    .height($r('app.string.list_slide_to_history_layout_100'))
    .width($r('app.string.list_slide_to_history_layout_100'))
  }
}
