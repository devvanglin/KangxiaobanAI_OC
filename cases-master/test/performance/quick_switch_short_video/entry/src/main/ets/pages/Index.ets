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

import { VideoPlayer } from '../PlayerManager/VideoPlayer';
import { MyDataSource } from '../model/DataSource';
import Logger from '../utils/Logger';
import { CommConstants } from '../common/CommonData';
import { display, window } from '@kit.ArkUI';

const TAG = '[VideoPlayer]';

@Entry
@Component
struct Index {
  @State sources: string[] = [
    // add network video url
    'https://assets.mixkit.co/videos/4119/4119-720.mp4',
    'https://assets.mixkit.co/videos/4366/4366-720.mp4',
    'https://assets.mixkit.co/videos/4028/4028-720.mp4',
    'https://assets.mixkit.co/videos/4119/4119-720.mp4',
    'https://assets.mixkit.co/videos/4366/4366-720.mp4',
    'https://assets.mixkit.co/videos/4028/4028-720.mp4',
    'https://assets.mixkit.co/videos/4119/4119-720.mp4',
    'https://assets.mixkit.co/videos/4366/4366-720.mp4',
    'https://assets.mixkit.co/videos/4028/4028-720.mp4',
    'https://assets.mixkit.co/videos/4119/4119-720.mp4',
    'https://assets.mixkit.co/videos/4366/4366-720.mp4',
    'https://assets.mixkit.co/videos/4028/4028-720.mp4',
    'https://assets.mixkit.co/videos/4119/4119-720.mp4',
    'https://assets.mixkit.co/videos/4366/4366-720.mp4',
    'https://assets.mixkit.co/videos/4028/4028-720.mp4',
    'https://assets.mixkit.co/videos/4119/4119-720.mp4',
    'https://assets.mixkit.co/videos/4366/4366-720.mp4',
    'https://assets.mixkit.co/videos/4028/4028-720.mp4',
  ];
  @State curIndex: number = 0;
  @State firstFlag: boolean = true;
  private swiperController: SwiperController = new SwiperController();
  @Provide isFirstAVPlayer: boolean = true;
  @State isPageShow: boolean = false;
  @State foldStatus: number = 0;

  async aboutToAppear(): Promise<void> {
    let context = getContext(this);
    let windowClass = await window.getLastWindow(context)
    await windowClass.setWindowKeepScreenOn(true)
    display.on('foldStatusChange', (foldStatus: display.FoldStatus) => {
      this.foldStatus = foldStatus;
      Logger.info(TAG, `FoldStatusChange:${this.foldStatus}`);
    })
  }

  onPageHide(): void {
    Logger.info(TAG,`onPageHide curIndex: ${this.curIndex} isPageShow:${this.isPageShow}`)
    this.isPageShow = false;
  }

  onPageShow(): void {
    Logger.info(TAG,`onPageShow curIndex: ${this.curIndex} isPageShow:${this.isPageShow}`)
    this.isPageShow = true;
  }

  build() {
    Swiper(this.swiperController) {
      LazyForEach(new MyDataSource(this.sources), (item: string, index: number) => {
        VideoPlayer({
          curSource: item,
          curIndex: this.curIndex,
          index: index,
          firstFlag: this.firstFlag,
          isPageShow: this.isPageShow,
          foldStatus: this.foldStatus
        })
      }, (item: string, index: number) => JSON.stringify(item) + index)
    }
    .cachedCount(3) // 缓存视频数量
    .width(CommConstants.WIDTH_FULL_PERCENT)
    .height(CommConstants.HEIGHT_FULL_PERCENT)
    .vertical(true)
    .loop(true)
    .curve(Curve.Ease)
    .duration(CommConstants.DURATION_TIME)
    .indicator(false)
    .backgroundColor(Color.Black)
    .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
      Logger.info(TAG, `onGestureSwipe index:${index}}`);
    })
    .onAnimationStart((index: number, targetIndex: number, extraInfo: SwiperAnimationEvent) => {
      this.curIndex = targetIndex; // 优化点：视频播放和动画启动同步进行，覆盖动画效果
    })
    .onAnimationEnd((index: number, extraInfo: SwiperAnimationEvent) => {
      Logger.info(TAG, `onAnimationEnd index:${index}}`);
    })
  }
}