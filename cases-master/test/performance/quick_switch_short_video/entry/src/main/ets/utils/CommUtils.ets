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

import { AVPlayerState, CommConstants } from '../common/CommonData';
import { media } from '@kit.MediaKit';
import Logger from './Logger';

export function secondToTime(seconds: number): string {
  let hourUnit = CommConstants.HOUR_UNIT * CommConstants.HOUR_UNIT;
  let hour: number = Math.floor(seconds / hourUnit);
  let minute: number = Math.floor((seconds = hour * hourUnit) / CommConstants.HOUR_UNIT);
  let second: number = seconds - hour * hourUnit - minute * CommConstants.HOUR_UNIT;
  let hourStr: string = hour < CommConstants.TIME_CONST_TEN ? `0${hour.toString()}` : `${hour.toString()}`
  let minuteStr: string = minute < CommConstants.TIME_CONST_TEN ? `0${minute.toString()}` : `${minute.toString()}`
  let secondStr: string = second < CommConstants.TIME_CONST_TEN ? `0${second.toString()}` : `${second.toString()}`
  if (hour > 0) {
    return `${hourStr}:${minuteStr}:${secondStr}`;
  }
  if (minute > 0) {
    return `${minuteStr}:${secondStr}`;
  } else {
    return `00:${secondStr}`;
  }
}

export function setSeek(avPlayer: media.AVPlayer | undefined, seek: number) {
  if (avPlayer) {
    if (avPlayer.state != AVPlayerState.PREPARED && avPlayer.state != AVPlayerState.PLAYING &&
      avPlayer.state != AVPlayerState.PAUSED && avPlayer.state != AVPlayerState.COMPLETED) {
      return
    }
    avPlayer.seek(seek, media.SeekMode.SEEK_PREV_SYNC);
  }
}

const TAG = '[VideoPlayer]';

export async function playVideo(avPlayer: media.AVPlayer | undefined, curIndex: number, index: number) {
  if (avPlayer) {
    if (avPlayer.state != AVPlayerState.PREPARED && avPlayer.state != AVPlayerState.PAUSED &&
      avPlayer.state != AVPlayerState.COMPLETED) {
      return;
    }
    Logger.info(TAG,"playVideo:" + ` state:${avPlayer.state} this.curIndex:${curIndex} this.index:${index}`);
    await avPlayer.play();
  } else {
  Logger.info(TAG,"playVideo: avPlayer NULL," + ` this.curIndex:${curIndex} this.index.${index}`);
  }
}

export async function pauseVideo(avPlayer: media.AVPlayer | undefined, curIndex: number, index: number){
  if(avPlayer) {
    Logger.info(TAG,"pauseVideo:" + ` state:${avPlayer.state} this.curIndex:${curIndex} this.index:${index}`);
    await avPlayer.pause();
  } else {
  Logger.info(TAG,"pauseVideo avPlayer NULL," + ` this.curIndex:${curIndex} this.index:${index}`);
  }
}

export async function stopVideo(avPlayer: media.AVPlayer | undefined,curIndex:number, index: number) {
  if(avPlayer) {
    Logger.info(TAG,"stopVideo:" + ` state: ${avPlayer.state}` + ` this.curIndex:${curIndex} this.index:${index}`);
    if (avPlayer.state != AVPlayerState.PREPARED && avPlayer.state != AVPlayerState.PLAYING &&
      avPlayer.state != AVPlayerState.PAUSED && avPlayer.state != AVPlayerState.COMPLETED) {
      return;
    }
    Logger.info(TAG,"stopVideo begin:" + ` state: ${avPlayer.state}` + ` this.curIndex:${curIndex} this.index:${index}`);
    await avPlayer.stop();
  } else {
    Logger.info(TAG,"stopVideo avPlayer NULL," + ` this.curIndex:${curIndex} this.index:${index}`);
  }
}

export function releaseVideo(avPlayer: media.AVPlayer | undefined, curIndex: number, index: number) {
  if (avPlayer) {
    Logger.info(TAG, "releaseVideo: " + ` state:${avPlayer.state}` + ` this.curIndex:${curIndex} this.index:${index}`);
    avPlayer.off('timeUpdate');
    avPlayer.off('seekDone');
    avPlayer.off('speedDone');
    avPlayer.off('error');
    avPlayer.off('stateChange');
    avPlayer.release();
  }
}