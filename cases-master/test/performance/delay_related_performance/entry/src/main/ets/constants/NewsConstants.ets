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

export class NewsConstants {
  static readonly NEWS_TITLE_MAX_LINES: number = 1;
  static readonly NEWS_TITLE_TEXT_FONT_WEIGHT: number = 500;
  static readonly NEWS_CONTENT_MAX_LINES: number = 2;
  static readonly NEWS_TIME_MAX_LINES: number = 1;
  static readonly NEWS_PAGE_TEXT_FONT_WEIGHT: number = 600;
  static readonly NEWS_RESOLVE_SUCCESS : string = '刷新成功';
  static readonly NEWS_MOCK_DATA_COUNT: number = 8; // 每份模拟数据所含的新闻个数为8
  static readonly MOCK_DATA_FILE_ONE_DIR: string = 'mockDataOne.json'; // 模拟数据路径
  static readonly MOCK_DATA_FILE_TWO_DIR: string = 'mockDataTwo.json'; // 模拟数据路径
  static readonly NEWS_REFRESH_TIME: number = 300; // 数据刷新时间
}