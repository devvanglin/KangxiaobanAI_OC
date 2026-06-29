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

export interface TabPageStat {
  label: ResourceStr;
  value: ResourceStr;
  note: ResourceStr;
}

export interface TabPageListItem {
  title: ResourceStr;
  subtitle: ResourceStr;
  tag: ResourceStr;
}

export interface TabPageSection {
  title: ResourceStr;
  description: ResourceStr;
  items: TabPageListItem[];
}

export interface TabPageConfig {
  title: ResourceStr;
  subtitle: ResourceStr;
  heroSymbol: Resource;
  heroValue: ResourceStr;
  heroNote: ResourceStr;
  stats: TabPageStat[];
  primarySection: TabPageSection;
  secondarySection: TabPageSection;
}

export const TAB_PAGE_CONFIGS: TabPageConfig[] = [
  {
    title: $r('app.string.tab_home'),
    subtitle: $r('app.string.page_home_subtitle'),
    heroSymbol: $r('sys.symbol.house_fill'),
    heroValue: $r('app.string.page_home_hero_value'),
    heroNote: $r('app.string.page_home_hero_note'),
    stats: [
      {
        label: $r('app.string.page_home_stat_1_label'),
        value: $r('app.string.page_home_stat_1_value'),
        note: $r('app.string.page_home_stat_1_note')
      },
      {
        label: $r('app.string.page_home_stat_2_label'),
        value: $r('app.string.page_home_stat_2_value'),
        note: $r('app.string.page_home_stat_2_note')
      }
    ],
    primarySection: {
      title: $r('app.string.page_home_section_1_title'),
      description: $r('app.string.page_home_section_1_desc'),
      items: [
        {
          title: $r('app.string.page_home_section_1_item_1_title'),
          subtitle: $r('app.string.page_home_section_1_item_1_subtitle'),
          tag: $r('app.string.page_home_section_1_item_1_tag')
        },
        {
          title: $r('app.string.page_home_section_1_item_2_title'),
          subtitle: $r('app.string.page_home_section_1_item_2_subtitle'),
          tag: $r('app.string.page_home_section_1_item_2_tag')
        },
        {
          title: $r('app.string.page_home_section_1_item_3_title'),
          subtitle: $r('app.string.page_home_section_1_item_3_subtitle'),
          tag: $r('app.string.page_home_section_1_item_3_tag')
        }
      ]
    },
    secondarySection: {
      title: $r('app.string.page_home_section_2_title'),
      description: $r('app.string.page_home_section_2_desc'),
      items: [
        {
          title: $r('app.string.page_home_section_2_item_1_title'),
          subtitle: $r('app.string.page_home_section_2_item_1_subtitle'),
          tag: $r('app.string.page_home_section_2_item_1_tag')
        },
        {
          title: $r('app.string.page_home_section_2_item_2_title'),
          subtitle: $r('app.string.page_home_section_2_item_2_subtitle'),
          tag: $r('app.string.page_home_section_2_item_2_tag')
        }
      ]
    }
  },
  {
    title: $r('app.string.tab_music'),
    subtitle: $r('app.string.page_elder_subtitle'),
    heroSymbol: $r('sys.symbol.person_2_fill'),
    heroValue: $r('app.string.page_elder_hero_value'),
    heroNote: $r('app.string.page_elder_hero_note'),
    stats: [
      {
        label: $r('app.string.page_elder_stat_1_label'),
        value: $r('app.string.page_elder_stat_1_value'),
        note: $r('app.string.page_elder_stat_1_note')
      },
      {
        label: $r('app.string.page_elder_stat_2_label'),
        value: $r('app.string.page_elder_stat_2_value'),
        note: $r('app.string.page_elder_stat_2_note')
      }
    ],
    primarySection: {
      title: $r('app.string.page_elder_section_1_title'),
      description: $r('app.string.page_elder_section_1_desc'),
      items: [
        {
          title: $r('app.string.page_elder_section_1_item_1_title'),
          subtitle: $r('app.string.page_elder_section_1_item_1_subtitle'),
          tag: $r('app.string.page_elder_section_1_item_1_tag')
        },
        {
          title: $r('app.string.page_elder_section_1_item_2_title'),
          subtitle: $r('app.string.page_elder_section_1_item_2_subtitle'),
          tag: $r('app.string.page_elder_section_1_item_2_tag')
        },
        {
          title: $r('app.string.page_elder_section_1_item_3_title'),
          subtitle: $r('app.string.page_elder_section_1_item_3_subtitle'),
          tag: $r('app.string.page_elder_section_1_item_3_tag')
        }
      ]
    },
    secondarySection: {
      title: $r('app.string.page_elder_section_2_title'),
      description: $r('app.string.page_elder_section_2_desc'),
      items: [
        {
          title: $r('app.string.page_elder_section_2_item_1_title'),
          subtitle: $r('app.string.page_elder_section_2_item_1_subtitle'),
          tag: $r('app.string.page_elder_section_2_item_1_tag')
        },
        {
          title: $r('app.string.page_elder_section_2_item_2_title'),
          subtitle: $r('app.string.page_elder_section_2_item_2_subtitle'),
          tag: $r('app.string.page_elder_section_2_item_2_tag')
        }
      ]
    }
  },
  {
    title: $r('app.string.tab_cafe'),
    subtitle: $r('app.string.page_task_subtitle'),
    heroSymbol: $r('sys.symbol.square_and_pencil_fill'),
    heroValue: $r('app.string.page_task_hero_value'),
    heroNote: $r('app.string.page_task_hero_note'),
    stats: [
      {
        label: $r('app.string.page_task_stat_1_label'),
        value: $r('app.string.page_task_stat_1_value'),
        note: $r('app.string.page_task_stat_1_note')
      },
      {
        label: $r('app.string.page_task_stat_2_label'),
        value: $r('app.string.page_task_stat_2_value'),
        note: $r('app.string.page_task_stat_2_note')
      }
    ],
    primarySection: {
      title: $r('app.string.page_task_section_1_title'),
      description: $r('app.string.page_task_section_1_desc'),
      items: [
        {
          title: $r('app.string.page_task_section_1_item_1_title'),
          subtitle: $r('app.string.page_task_section_1_item_1_subtitle'),
          tag: $r('app.string.page_task_section_1_item_1_tag')
        },
        {
          title: $r('app.string.page_task_section_1_item_2_title'),
          subtitle: $r('app.string.page_task_section_1_item_2_subtitle'),
          tag: $r('app.string.page_task_section_1_item_2_tag')
        },
        {
          title: $r('app.string.page_task_section_1_item_3_title'),
          subtitle: $r('app.string.page_task_section_1_item_3_subtitle'),
          tag: $r('app.string.page_task_section_1_item_3_tag')
        }
      ]
    },
    secondarySection: {
      title: $r('app.string.page_task_section_2_title'),
      description: $r('app.string.page_task_section_2_desc'),
      items: [
        {
          title: $r('app.string.page_task_section_2_item_1_title'),
          subtitle: $r('app.string.page_task_section_2_item_1_subtitle'),
          tag: $r('app.string.page_task_section_2_item_1_tag')
        },
        {
          title: $r('app.string.page_task_section_2_item_2_title'),
          subtitle: $r('app.string.page_task_section_2_item_2_subtitle'),
          tag: $r('app.string.page_task_section_2_item_2_tag')
        }
      ]
    }
  },
  {
    title: $r('app.string.tab_mine'),
    subtitle: $r('app.string.page_mine_subtitle'),
    heroSymbol: $r('sys.symbol.person_crop_circle_fill'),
    heroValue: $r('app.string.page_mine_hero_value'),
    heroNote: $r('app.string.page_mine_hero_note'),
    stats: [
      {
        label: $r('app.string.page_mine_stat_1_label'),
        value: $r('app.string.page_mine_stat_1_value'),
        note: $r('app.string.page_mine_stat_1_note')
      },
      {
        label: $r('app.string.page_mine_stat_2_label'),
        value: $r('app.string.page_mine_stat_2_value'),
        note: $r('app.string.page_mine_stat_2_note')
      }
    ],
    primarySection: {
      title: $r('app.string.page_mine_section_1_title'),
      description: $r('app.string.page_mine_section_1_desc'),
      items: [
        {
          title: $r('app.string.page_mine_section_1_item_1_title'),
          subtitle: $r('app.string.page_mine_section_1_item_1_subtitle'),
          tag: $r('app.string.page_mine_section_1_item_1_tag')
        },
        {
          title: $r('app.string.page_mine_section_1_item_2_title'),
          subtitle: $r('app.string.page_mine_section_1_item_2_subtitle'),
          tag: $r('app.string.page_mine_section_1_item_2_tag')
        },
        {
          title: $r('app.string.page_mine_section_1_item_3_title'),
          subtitle: $r('app.string.page_mine_section_1_item_3_subtitle'),
          tag: $r('app.string.page_mine_section_1_item_3_tag')
        }
      ]
    },
    secondarySection: {
      title: $r('app.string.page_mine_section_2_title'),
      description: $r('app.string.page_mine_section_2_desc'),
      items: [
        {
          title: $r('app.string.page_mine_section_2_item_1_title'),
          subtitle: $r('app.string.page_mine_section_2_item_1_subtitle'),
          tag: $r('app.string.page_mine_section_2_item_1_tag')
        },
        {
          title: $r('app.string.page_mine_section_2_item_2_title'),
          subtitle: $r('app.string.page_mine_section_2_item_2_subtitle'),
          tag: $r('app.string.page_mine_section_2_item_2_tag')
        }
      ]
    }
  }
];
