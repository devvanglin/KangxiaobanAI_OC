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
import { CommonConstants } from '../constants/CommonConstants';

export class TabBarListModel {
  loadTabs(): TabBarModel[] {
    return [
      {
        index: CommonConstants.TAB_HOME_INDEX,
        img: $r('app.media.house_fill'),
        selectImg: $r('app.media.house_fill_select'),
        title: $r('app.string.home')
      },
      {
        index: CommonConstants.TAB_HOT_PAGE_INDEX,
        img: $r('app.media.star_fill'),
        selectImg: $r('app.media.star_select'),
        title: $r('app.string.hot')
      },
      {
        index: CommonConstants.TAB_VIDEO_PAGE_INDEX,
        img: $r('app.media.play_round_rectangle'),
        selectImg: $r('app.media.play_round_rectangle_select'),
        title: $r('app.string.videos')
      },
      {
        index: CommonConstants.TAB_MINE_PAGE_INDEX,
        img: $r('app.media.person_crop_circle'),
        selectImg: $r('app.media.person_crop_circle_select'),
        title: $r('app.string.mine')
      }
    ]
  };
}

export interface TabBarModel {
  index: number;
  img: Resource;
  selectImg?: Resource;
  title: Resource;
}