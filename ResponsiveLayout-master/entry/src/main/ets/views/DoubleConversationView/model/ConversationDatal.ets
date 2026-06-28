/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

interface ConversationDataInterface {
  name: Resource
  msg: Resource
  time: ResourceStr
  icon: Resource
};

const ConversationListData: ConversationDataInterface[] = [
  { name: $r('app.string.ZhangXM'), msg: $r('app.string.waiting_for_long'), time: '13:55', icon: $r('app.media.avatar1') },
  { name: $r('app.string.LiuXX'), msg: $r('app.string.LiuXXMsg'), time: '13:55', icon: $r('app.media.avatar2') },
  { name: $r('app.string.DengSS'), msg: $r('app.string.DengSSMsg'), time: '12:00', icon: $r('app.media.avatar11') },
  { name: $r('app.string.FenF'), msg: $r('app.string.FenFMsg'), time: '08:00', icon: $r('app.media.avatar4') },
  { name: $r('app.string.Jack'), msg: $r('app.string.waiting_for_long'), time: $r('app.string.yesterday'), icon: $r('app.media.avatar5') },
  { name: $r('app.string.TongT'), msg: $r('app.string.waiting_for_long'), time: $r('app.string.yesterday'), icon: $r('app.media.avatar6') },
  { name: $r('app.string.Tom'), msg: $r('app.string.waiting_for_long'), time: $r('app.string.yesterday'), icon: $r('app.media.avatar7') },
  { name: $r('app.string.football'), msg: $r('app.string.waiting_for_long'), time: $r('app.string.yesterday'), icon: $r('app.media.avatar8') },
  { name: $r('app.string.Lily'), msg: $r('app.string.waiting_for_long'), time: $r('app.string.yesterday'), icon: $r('app.media.avatar9') },
  { name: $r('app.string.Jack2'), msg: $r('app.string.waiting_for_long'), time: $r('app.string.yesterday'), icon: $r('app.media.avatar10') },
  { name: $r('app.string.ZhangXT'), msg: $r('app.string.waiting_for_long'), time: $r('app.string.yesterday'), icon: $r('app.media.avatar11') },
  { name: $r('app.string.sport_club'), msg: $r('app.string.waiting_for_long'), time: $r('app.string.yesterday'), icon: $r('app.media.avatar1') },
];

export { ConversationDataInterface, ConversationListData };