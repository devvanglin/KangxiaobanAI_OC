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

import { VoipCallService } from '../service/VoipCallService';
import { voipCall } from '@kit.CallServiceKit';

@Component
export default struct CallComponent {
  @StorageLink('close') end: boolean | undefined = undefined;

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceBetween }) {
      Row() {
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Row({ space: 30 }) {

        Column() {
          Button()
            .width(80)
            .height(80)
            .backgroundColor(Color.Green)
            .onClick(() => {
              VoipCallService.processVoipCallEvent(voipCall.VoipCallUiEvent.VOIP_CALL_EVENT_VIDEO_ANSWER);
            })

          Text('Answer').fontColor(Color.White).padding({ top: 5 })
        }

        Column() {
          Button()
            .width(80)
            .height(80)
            .backgroundColor(Color.Red)
            .onClick(() => {
              this.end = true;
              VoipCallService.close();
            })

          Text('Hang Up').fontColor(Color.White).padding({ top: 5 })
        }

      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .padding('30 10')
    .backgroundColor(Color.Black)
  }
}