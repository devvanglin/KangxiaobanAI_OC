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

/**
 * Secondary Navigation ViewModel
 */
@ObservedV2
export class SecNavigationViewModel {
  @Trace public currentSubTabIndex: number = 0;

  switchSecNavigationTab(index: number): void {
    this.currentSubTabIndex = index;
  }
}

// Home page secondary navigation
export const secNavigationHome: SecNavigationViewModel = new SecNavigationViewModel();

// Hot page secondary navigation
export const secNavigationHot: SecNavigationViewModel = new SecNavigationViewModel();
