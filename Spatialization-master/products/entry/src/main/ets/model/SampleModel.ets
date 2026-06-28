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

export const SAMPLE_LIST: SampleData[] = [
  {
    id: 1,
    title: $r('app.string.sample_1_title'),
    desc: $r('app.string.sample_1_desc'),
    detailImg: $r('app.media.ic_sample_1'),
  },
  {
    id: 2,
    title: $r('app.string.sample_2_title'),
    desc: $r('app.string.sample_2_desc'),
    detailImg: $r('app.media.ic_sample_2'),
  },
  {
    id: 3,
    title: $r('app.string.sample_3_title'),
    desc: $r('app.string.sample_3_desc'),
    detailImg: $r('app.media.ic_sample_3'),
    isFullImg: true,
    routerName: 'ImmersiveLightView',
  },
  {
    id: 4,
    title: $r('app.string.sample_4_title'),
    desc: $r('app.string.sample_4_desc'),
    detailImg: $r('app.media.ic_sample_4'),
    routerName: 'AdaptiveTabView',
  },
  {
    id: 5,
    title: $r('app.string.sample_5_title'),
    desc: $r('app.string.sample_5_desc'),
    detailImg: $r('app.media.ic_sample_5'),
    routerName: 'SmartReachView',
  },
  {
    id: 6,
    title: $r('app.string.sample_6_title'),
    desc: $r('app.string.sample_6_desc'),
    detailImg: $r('app.media.ic_sample_6'),
    routerName: 'ToolBarListView',
  },
];

export interface SampleData {
  id: number;
  title: ResourceStr;
  desc: ResourceStr;
  detailImg: ResourceStr,
  routerName?: string;
  isFullImg?: boolean;
}

export interface DetailParam {
  currentIndex: number;
}