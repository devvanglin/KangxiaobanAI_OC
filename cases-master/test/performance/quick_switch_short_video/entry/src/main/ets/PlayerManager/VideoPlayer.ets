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
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { CommConstants } from '../common/CommonData';
import { secondToTime, setSeek, playVideo, pauseVideo, releaseVideo } from '../utils/CommUtils';
import Logger from '../utils/Logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { display, window } from '@kit.ArkUI';

const TAG = '[VideoPlayer]';

@Component
export struct VideoPlayer {
  @Prop @Watch('onIndexChange') curIndex: number = CommConstants.CURINDEX_DEFAULT_NUM;
  @Prop @Watch('onPageShowWatch') isPageShow: boolean = false;
  @Prop @Watch('onFoldStatusChange') foldStatus: number = 0;
  private index: number = 0;
  private curSource: media.AVFileDescriptor | string = '';
  @State isPlaying: boolean = false;
  @State isTimeDisplay: number = 0;
  @State trackThicknessSize: number = CommConstants.TRACK_SIZE_MIN;
  @State flag: boolean = false;
  @State currentTime: number = 0;
  @State durationTime: number = 0;
  @State durationStringTime: string = '00:00';
  @State currentStringTime: string = '00:00';
  private duration: number = 0;
  private surfaceID: string = '';
  private xComponentController = new XComponentController();
  private avPlayer: media.AVPlayer | undefined = undefined;
  private isSliderMoving: boolean = false;
  @Link firstFlag: boolean;
  @State aspRatio: number = 0.5;
  @State XComponentHeight: number = CommConstants.SURFACE_HEIGHT;
  @State XComponentWidth: number = CommConstants.SURFACE_WIDTH;
  private viewWidth: number = CommConstants.SURFACE_WIDTH;
  private viewHeight: number = CommConstants.SURFACE_HEIGHT;
  private videoRatio: number = this.viewWidth / this.viewHeight;
  @State screenWidth: number = CommConstants.SURFACE_WIDTH;
  @State screenHeight: number = CommConstants.SURFACE_HEIGHT;

  onPageShowWatch() {
    if (!this.isPageShow && this.curIndex === this.index) {
      pauseVideo(this.avPlayer, this.curIndex, this.index);
      this.isPlaying = false;
      this.trackThicknessSize = CommConstants.TRACK_SIZE_MIN;
    }
  }

  onIndexChange() {
    if (this.curIndex !== this.index) {
      pauseVideo(this.avPlayer, this.curIndex, this.index);
      this.isPlaying = false;
      this.trackThicknessSize = CommConstants.TRACK_SIZE_MIN;
      return
    }
    if (this.flag === true) {
      playVideo(this.avPlayer, this.curIndex, this.index);
      this.isPlaying = true;
      this.trackThicknessSize = CommConstants.TRACK_SIZE_MIN;
      return
    }
    let countNum = 0;
    let interValFlag = setInterval(() => {
      countNum++;
      // 此处有必要再次判断索引，否则会出现索引错乱导致播放异常
      if (this.curIndex !== this.index) {
        clearInterval(interValFlag);
      }
      if (this.flag === true && this.isPageShow) {
        countNum = 0;
        playVideo(this.avPlayer, this.curIndex, this.index);
        this.isPlaying = true;
        this.trackThicknessSize = CommConstants.TRACK_SIZE_MIN;
        clearInterval(interValFlag);
      } else {
        if (countNum > 15) {
          countNum = 0;
          this.initAVPlayer();
        }
      }
    }, 100);
  }

  onFoldStatusChange() {
    this.autoVideoSize();
  }

  autoVideoSize() {
    display.getAllDisplays((_err, data) => {
      this.screenWidth = data[0].width
      this.screenHeight = data[0].height
      const viewRatio: number = Number(this.viewWidth) / Number(this.viewHeight);
      this.videoRatio = this.screenWidth / this.screenHeight;
      if (viewRatio > this.videoRatio) {
        this.XComponentHeight = px2vp(this.viewHeight * this.screenWidth / this.viewWidth);
        this.XComponentWidth = px2vp(this.screenWidth);
      } else {
        this.XComponentWidth = px2vp(this.viewWidth * this.screenHeight / this.viewHeight);
        this.XComponentHeight = px2vp(this.screenHeight);
      }
    })
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Stack() {
          if (!this.isPlaying) {
            Image($r('app.media.shortvideo_pau'))
              .width(CommConstants.IMAGE_PLAY_WIDTH)
              .height(CommConstants.IMAGE_PLAY_HEIGHT)
              .zIndex(CommConstants.PLAY_IMAGE_INDEX)
          }
          Column() {
            XComponent({
              id: 'XComponent',
              type: XComponentType.SURFACE,
              controller: this.xComponentController
            })
              .width(this.XComponentWidth)
              .height(this.XComponentHeight)
              .onLoad(async () => {
                this.surfaceID = this.xComponentController.getXComponentSurfaceId();
                this.initAVPlayer(); // 优化点：创建AVPlayer的播放器放入到缓存池中，不可共用播放器。
              })
          }
          .zIndex(CommConstants.COLUMN_INDEX)
        }

        this.PlayControl()
      }
      .width(CommConstants.WIDTH_FULL_PERCENT)
      .height(CommConstants.HEIGHT_FULL_PERCENT)
      .backgroundColor(Color.Black)
    }
    .width(CommConstants.WIDTH_FULL_PERCENT)
    .height(CommConstants.HEIGHT_FULL_PERCENT)
    .onClick(() => {
      this.iconOnClick();
    })
  }

  @Builder
  PlayControl() {
    Column() {
      Blank(CommConstants.BLANK_LEN_600)
      Row() {
        Text(this.currentStringTime)
          .fontSize(CommConstants.TEXT_FRONT_SIZE)
          .fontColor(Color.White)
          .margin({ left: CommConstants.TEXT_MARGIN_LEFT })
          .width(CommConstants.TEXT_LEFT_WIDTH)
          .textAlign(TextAlign.End)
          .zIndex(CommConstants.SLIDER_INDEX)
        Divider()
          .vertical(true)
          .height(CommConstants.DIVIDER_HEIGHT)
          .width(CommConstants.DIVIDER_WIDTH)
          .backgroundBlurStyle(BlurStyle.Regular, { colorMode: ThemeColorMode.LIGHT })
          .color(Color.White)
          .opacity(CommConstants.DIVIDER_OPACITY)
          .margin({ left: CommConstants.DIVIDER_MARGIN, right: CommConstants.DIVIDER_MARGIN })
          .rotate({
            x: CommConstants.DIVIDER_X,
            y: CommConstants.DIVIDER_y,
            z: CommConstants.DIVIDER_Z,
            centerX: CommConstants.DIVIDER_CENTER_X,
            centerY: CommConstants.DIVIDER_CENTER_Y,
            angle: CommConstants.DIVIDER_ANGLE
          })
        Text(this.durationStringTime)
          .fontSize(CommConstants.TEXT_FRONT_SIZE)
          .fontColor(Color.White)
          .margin({ left: CommConstants.TEXT_MARGIN_LEFT })
          .width(CommConstants.TEXT_LEFT_WIDTH)
          .textAlign(TextAlign.Start)
          .opacity(CommConstants.SLIDER_OPACITY)
          .zIndex(CommConstants.SLIDER_INDEX)
      }.width(CommConstants.TEXT_TIME_ALL_WIDTH).opacity(this.isTimeDisplay)

      Blank(CommConstants.BLANK_LEN_50)
      Slider({
        value: this.currentTime,
        step: CommConstants.SLIDER_STEP,
        min: CommConstants.SLIDER_MIN,
        max: this.durationTime,
        style: SliderStyle.NONE
      })
        .width(CommConstants.SLIDER_WIDTH)
        .height(CommConstants.SLIDER_HEIGHT)
        .trackColor(Color.Black)
        .showSteps(false)
        .showTips(false)
        .trackThickness(this.trackThicknessSize)
        .trackBorderRadius(CommConstants.TRACK_BORDER_RADIUS)
        .zIndex(CommConstants.SLIDER_INDEX)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.sliderOnChange(value, mode);
        });
    }
  }

  async iconOnClick() {
    if (this.isPlaying) {
      pauseVideo(this.avPlayer, this.curIndex, this.index);
      this.isPlaying = false;
      this.isTimeDisplay = 0;
      this.trackThicknessSize = CommConstants.TRACK_SIZE_MIN;
      let context = getContext(this);
      let windowClass = await window.getLastWindow(context)
      await windowClass.setWindowKeepScreenOn(false)
      return;
    }
    if (this.flag === true) {
      playVideo(this.avPlayer, this.curIndex, this.index);
      this.isPlaying = true;
      this.isTimeDisplay = 0;
      this.trackThicknessSize = CommConstants.TRACK_SIZE_MIN;
    } else {
      let intervalFlag = setInterval(async () => {
        if (this.flag) {
          playVideo(this.avPlayer, this.curIndex, this.index);
          this.isPlaying = true;
          this.isTimeDisplay = 0;
          this.trackThicknessSize = CommConstants.TRACK_SIZE_MIN;
          clearInterval(intervalFlag)
        }
      }, CommConstants.TIMER_INTERVAL)
    }
    let context = getContext(this);
    let windowClass = await window.getLastWindow(context);
    await windowClass.setWindowKeepScreenOn(true)
  }

  sliderOnChange(value: number, mode: SliderChangeMode) {
    this.currentTime = value;
    let seekTime: number = value * this.duration / this.durationTime;
    if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
      this.isTimeDisplay = 1;
      this.trackThicknessSize = CommConstants.TRACK_SIZE_MAX;
    }
    if (mode === SliderChangeMode.Moving) {
      this.currentStringTime = secondToTime(Math.floor(seekTime / CommConstants.SECOND_TO_MS));
      this.isSliderMoving = true;
    }
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.currentStringTime = secondToTime(Math.floor(seekTime / CommConstants.SECOND_TO_MS));
      setSeek(this.avPlayer, seekTime);
      this.isTimeDisplay = 0;
      this.trackThicknessSize = CommConstants.TRACK_SIZE_MIN;
      this.isSliderMoving = false;
    }
  }

  async initAVPlayer() {
    Logger.info(TAG, 'createAVPlayer begin');
    media.createAVPlayer().then((video: media.AVPlayer) => {
      if (video !== null) {
        this.avPlayer = video;
        this.setAVPlayerCallback(this.avPlayer);
        // 设置播放源，使其进入initialized状态
        if (typeof this.curSource === 'string') {
          this.avPlayer.url = this.curSource;
        } else {
          this.avPlayer.fdSrc = this.curSource;
        }
        Logger.info(TAG, 'createAVPlayer success');
      } else {
        Logger.error(TAG, 'createAVPlayer fail');
      }
    }).catch((error: BusinessError) => {
      Logger.error(TAG, `AVPlayer catchCallback,error message:${error.message}`);
    })
  }

  setAVPlayerCallback(avPlayer: media.AVPlayer) {
    // 用于进度条，监听进度条当前位置，刷新当前时间
    avPlayer.on('timeUpdate', (time: number) => {
      if (!this.isSliderMoving) {
        this.currentTime = Math.floor(time * this.durationTime / this.duration);
        this.currentStringTime = secondToTime(Math.floor((time / CommConstants.SECOND_TO_MS)));
      }
    })
    // 适配一多，根据屏幕尺寸的变化同步更新视频的长宽
    avPlayer.on('videoSizeChange', (width: number, height: number) => {
      this.viewHeight = height;
      this.viewWidth = width;
      this.autoVideoSize();
    })
    // 必要事件，监听播放器的错误信息
    avPlayer.on('error', (error: BusinessError) => {
      Logger.error(TAG,
        `Invoke avPlayer failed, code is ${error.code},message is ${error.message}` + `---state:${avPlayer.state}`);
      avPlayer.reset();
    })
    this.setAVPlayerStateListen(avPlayer);
  }

  setAVPlayerStateListen(avPlayer: media.AVPlayer) {
    avPlayer.on('stateChange', async (state: string) => {
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报
          Logger.info(TAG,
            'AVPlayer state idle called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}`);
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          Logger.info(TAG,
            'AVPlayer state initialized called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}`);
          avPlayer.surfaceId = this.surfaceID;
          avPlayer.prepare();
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          Logger.info(TAG,
            'AVPlayer state prepared called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}`);
          avPlayer.audioInterruptMode = audio.InterruptMode.INDEPENDENT_MODE; // 避免同时出现两个视频的声音
          this.flag = true;
          avPlayer.loop = true;
          this.duration = avPlayer.duration;
          this.durationTime = Math.floor(this.duration / CommConstants.SECOND_TO_MS);
          this.currentStringTime = secondToTime(this.durationTime);
          if (this.firstFlag && this.index === 0 && this.isPageShow) {
            avPlayer.play(); // 应用启动后的第一个视频启动播放
            this.firstFlag = false;
          }
          break;
        case 'completed': // 播放结束后触发该状态机上报
          Logger.info(TAG,
            'AVPlayer state completed called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}`);
          this.isPlaying = false;
          break;
        case 'playing': // play成功调用后触发该状态机上报
          Logger.info(TAG,
            'AVPlayer state playing called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}` +
              `source:${this.curSource}`);
          this.isPlaying = true;
          break;
        case 'paused': // pause成功调用后触发该状态机上报
          Logger.info(TAG,
            'AVPlayer state paused called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}`);
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报
          Logger.info(TAG,
            'AVPlayer state stopped called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}`);
          break;
        case 'released':
          Logger.info(TAG,
            'AVPlayer state released called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}`);
          break;
        case 'error':
          Logger.info(TAG,
            'AVPlayer state released called.' + `this.curIndex:${this.curIndex}` + `this.index:${this.index}`);
          avPlayer.reset();
          break;
        default:
          Logger.info(TAG, 'AVPlayer state unknown called.' + state);
          break;
      }
    })
  }

  aboutToDisappear(): void {
    Logger.info(TAG, `enter aboutToDisappear. ` +
      ` this.curIndex:${this.curIndex} this.index:${this.index} isPageShow:${this.isPageShow}`);
    releaseVideo(this.avPlayer, this.curIndex, this.index);
  }
}
