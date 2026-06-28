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

import { AAID, pushCommon, pushService } from '@kit.PushKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// Define the profileId to be bound. You are advised to use an anonymous identifier generated based on the account ID
const profileId: string = '111***222';

@Component
export struct ExamplePage {

  @Builder
  CustomButton(label: string, callback: () => void) {
    Button(label)
      .margin({ top: 10 })
      .width('48%')
      .height(30)
      .onClick(callback)
  }

  build() {
    NavDestination() {
      Column() {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          this.CustomButton('Get AAID', this.getAAID);
          this.CustomButton('Delete AAID', this.deleteAAID);

          this.CustomButton('Bind Profile', this.bindAppProfileId);
          this.CustomButton('Unbind Profile', this.unbindAppProfileId);
        }
      }

    }
  }

  private getAAID = (): void => {
    AAID.getAAID()
      .then(aaid => {
        hilog.info(0x0000, 'testTag', 'succeed to get aaid.');
      })
      .catch((err: BusinessError) => {
        hilog.error(0x0000, 'testTag', 'Failed to get aaid: code %{public}d, message %{public}s', err.code, err.message);
      });
  }
  private deleteAAID = (): void => {
    AAID.deleteAAID()
      .then(() => {
        hilog.info(0x0000, 'testTag', 'succeed to delete aaid.');
      })
      .catch((err: BusinessError) => {
        hilog.error(0x0000, 'testTag', 'Failed to delete aaid: code %{public}d, message %{public}s', err.code, err.message);
      });
  }
  private bindAppProfileId = (): void => {
    // Bind the app account
    pushService.bindAppProfileId(pushCommon.AppProfileType.PROFILE_TYPE_APPLICATION_ACCOUNT, profileId)
      .then(() => {
        hilog.info(0x0000, 'testTag', 'Succeeded in binding app profile id');
      })
      .catch((err: BusinessError) => {
        hilog.error(0x0000, 'testTag', 'Failed to bind app profile id: %{public}d %{public}s', err.code, err.message);
      });
  }
  private unbindAppProfileId = () => {
    pushService.unbindAppProfileId(profileId)
      .then(() => {
        hilog.info(0x0000, 'testTag', 'Succeeded to unbind app profile id');
      })
      .catch((err: BusinessError) => {
        hilog.error(0x0000, 'testTag', 'Failed to unbind app profile id: %{public}d %{public}s', err.code, err.message);
      });
  }
}