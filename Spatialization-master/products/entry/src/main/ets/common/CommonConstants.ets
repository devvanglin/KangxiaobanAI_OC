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

export class CommonConstants {
  // device aspect threshold
  public static ASPECT_LANDSCAPE_SQUARE: number = 9 / 7.2;
  public static ASPECT_SQUARE_PORTRAIT: number = 9 / 10.8;
}

export enum StorageKey {
  UI_CONTEXT = 'spatialization_sample_UIContext',
  GLOBAL_INFO = 'spatialization_sample_GlobalInfoModel',
  MATERIAL_LEVEL = 'spatialization_sample_CustomMaterialLevel',
}