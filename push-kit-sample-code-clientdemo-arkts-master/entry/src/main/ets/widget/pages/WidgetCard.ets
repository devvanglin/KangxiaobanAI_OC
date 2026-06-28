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

// Define LocalStorage that stores the page-level UI state
const storage = new LocalStorage();

@Entry(storage)
@Component
struct WidgetCard {

  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('text_key') text: string = '';
  @LocalStorageProp('image_key') image: string = '';

  build() {
    Flex({ direction: FlexDirection.Column }) {
      Row() {
        Text() {
          // Span is a subcomponent of the Text component and is used to display the inline text
          Span('formID:')
          Span(this.formId)
        }
        .fontSize(10)
      }

      Row() {
        Text() {
          Span('文本:')
          Span(this.text)
        }
        .fontSize(10)
      }

      Row() {
        if (this.image) {
          Image('memory://' + this.image).height(80)
        }
      }
    }
    .padding(10)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility', // Set this parameter to the actual ability name of the app
      });
    })
  }
}