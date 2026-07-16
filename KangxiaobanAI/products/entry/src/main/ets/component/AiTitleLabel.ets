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

export const AI_BRAND_NAME: string = '康小伴 AI';

@ComponentV2
export struct AiTitleLabel {
  @Param text: string = AI_BRAND_NAME;
  @Param compact: boolean = false;

  build() {
    Text(this.text)
      .fontSize(this.compact ? $r('sys.float.Body_L') : $r('sys.float.Title_M'))
      .fontWeight(this.compact ? FontWeight.Medium : FontWeight.Bold)
      .fontColor($r('sys.color.font_primary'))
      .maxLines(1)
      .ellipsisMode(EllipsisMode.END)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .accessibilityText(this.text)
  }
}
