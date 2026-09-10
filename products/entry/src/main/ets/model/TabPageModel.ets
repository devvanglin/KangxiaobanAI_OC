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

export interface TabPageConfig {
  title: ResourceStr;
  subtitle: ResourceStr;
  heroSymbol: Resource;
}

export const TAB_PAGE_CONFIGS: TabPageConfig[] = [
  {
    title: $r('app.string.tab_home'),
    subtitle: $r('app.string.page_home_subtitle'),
    heroSymbol: $r('sys.symbol.house_fill')
  },
  {
    title: $r('app.string.tab_music'),
    subtitle: $r('app.string.page_elder_subtitle'),
    heroSymbol: $r('sys.symbol.person_2_fill')
  },
  {
    title: $r('app.string.tab_message'),
    subtitle: $r('app.string.page_task_subtitle'),
    heroSymbol: $r('sys.symbol.message_on_message_fill')
  },
  {
    title: $r('app.string.tab_mine'),
    subtitle: $r('app.string.page_mine_subtitle'),
    heroSymbol: $r('sys.symbol.person_crop_circle_fill')
  }
];
