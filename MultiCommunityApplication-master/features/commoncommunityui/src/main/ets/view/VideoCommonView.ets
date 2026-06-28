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
import { CommonConstants, MSVEmptyComponent } from 'commonmulticommunityapplication';

@ComponentV2
export struct VideoCommonView {
  @Require @Param activeIndex: number;

  @Monitor('activeIndex')
  onActiveIndex(mon: IMonitor) {
    const value: IMonitorValue<number> | undefined = mon.value();
    if (!value) {
      return;
    }
  }

  build() {
    NavDestination() {
      Column(){
        MSVEmptyComponent()
      }
      .width('100%')
      .height('100%')
    }
  }
}

@Builder
export function VideoPageBuilder() {
  VideoCommonView({ activeIndex: CommonConstants.TAB_VIDEO_PAGE_INDEX });
}