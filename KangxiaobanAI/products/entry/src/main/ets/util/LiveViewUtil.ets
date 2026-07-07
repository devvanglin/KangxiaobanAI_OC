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

import { liveViewManager } from '@kit.LiveViewKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import Logger from './Logger';

const TAG: string = '[LiveViewUtil]';

/**
 * 实况窗工具类 —— 上班中胶囊态实况窗
 * app 进入后台时在状态栏显示胶囊：左图标 + 右"上班中"文字
 */
export class LiveViewUtil {
  /** 实况窗唯一 ID（同一 id 反复更新/停止） */
  private static readonly LIVE_VIEW_ID: number = 1001;
  /** 递增序号，每次 start/update/stop 需 +1 */
  private static sequence: number = 0;
  private static isActive: boolean = false;

  /** 包名与主 Ability 名，用于点击胶囊拉起 app */
  private static readonly BUNDLE_NAME: string = 'com.gxoc.kxbai';
  private static readonly ABILITY_NAME: string = 'KanxiaobanAbility';

  /** 加载 foreground 图标为 PixelMap（实况窗 icon 字段只接受 string | PixelMap） */
  private static async loadIconPixelMap(context: common.UIAbilityContext): Promise<image.PixelMap> {
    const data: Uint8Array = await context.resourceManager.getMediaContent($r('app.media.foreground'));
    return image.createPixelMap(data.buffer);
  }

  /**
   * 启动"上班中"实况窗
   * @param context UIAbilityContext，用于获取资源与构建 WantAgent
   */
  static async startWorkStatus(context: common.UIAbilityContext): Promise<void> {
    if (LiveViewUtil.isActive) {
      Logger.info(TAG, 'LiveView already active, skip start');
      return;
    }
    try {
      const enabled: boolean = await liveViewManager.isLiveViewEnabled();
      if (!enabled) {
        Logger.warn(TAG, 'LiveView not enabled (need AGC liveview-rights)');
        return;
      }

      // 构建点击胶囊拉起 app 的 WantAgent
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: LiveViewUtil.BUNDLE_NAME,
          abilityName: LiveViewUtil.ABILITY_NAME
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0
      };
      const wantAgentObj: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);

      // 加载图标 PixelMap
      const iconPixelMap: image.PixelMap = await LiveViewUtil.loadIconPixelMap(context);

      LiveViewUtil.sequence += 1;

      // 构建实况窗对象：胶囊态（图标 + 文字）+ 卡片态主体
      const liveView: liveViewManager.LiveView = {
        id: LiveViewUtil.LIVE_VIEW_ID,
        event: 'COUNTDOWN',
        sequence: LiveViewUtil.sequence,
        isMute: true,
        liveViewData: {
          capsule: {
            type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
            status: 0,
            icon: iconPixelMap,
            title: '上班中',
            content: '护理值守',
            backgroundColor: '#E8F0FE'
          },
          primary: {
            title: '上班中',
            content: [{ text: '康小班护理值守中' }],
            keepTime: 0,
            clickAction: wantAgentObj
          }
        }
      };

      const result: liveViewManager.LiveViewResult = await liveViewManager.startLiveView(liveView);
      LiveViewUtil.isActive = true;
      Logger.info(TAG, `startLiveView success, resultCode=${result.resultCode}`);
    } catch (err) {
      const e = err as Error;
      Logger.error(TAG, `startLiveView failed: ${e.message}`);
    }
  }

  /**
   * 停止"上班中"实况窗
   */
  static async stopWorkStatus(): Promise<void> {
    if (!LiveViewUtil.isActive) {
      return;
    }
    try {
      LiveViewUtil.sequence += 1;

      const liveView: liveViewManager.LiveView = {
        id: LiveViewUtil.LIVE_VIEW_ID,
        event: 'COUNTDOWN',
        sequence: LiveViewUtil.sequence,
        isMute: true,
        liveViewData: {
          capsule: {
            type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
            status: 0,
            title: '上班中',
            content: '护理值守',
            backgroundColor: '#E8F0FE'
          },
          primary: {
            title: '上班中',
            content: [{ text: '康小班护理值守中' }],
            keepTime: 0
          }
        }
      };

      await liveViewManager.stopLiveView(liveView);
      LiveViewUtil.isActive = false;
      Logger.info(TAG, 'stopLiveView success');
    } catch (err) {
      const e = err as Error;
      Logger.error(TAG, `stopLiveView failed: ${e.message}`);
    }
  }
}
