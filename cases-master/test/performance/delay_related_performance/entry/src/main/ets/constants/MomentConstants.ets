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

export class MomentConstants {
  static readonly DEFAULT_OFFSET: number = 1000; // 默认跳转位置，用于第一次进入页面的跳转位置
  static readonly ANIMATION_DURATION: number = 500; // 动画持续时间
  static readonly SWITCH_BUTTON: number = 3; // 当前显示在屏幕上的子组件Index到达该阈值时，将跳转到历史记录按钮切换成跳转到顶部
}