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

import { hilog } from '@kit.PerformanceAnalysisKit';

const uiContext: UIContext | undefined = AppStorage.get('uiContext');
let context = uiContext!.getHostContext()!;

export class TabDataModel {
  private tabMap: Map<string, string[]>;

  constructor(tabMap: Map<string, string[]>) {
    this.tabMap = tabMap;
  }

  getTabMap(): Map<string, string[]> {
    return this.tabMap;
  }

  getFirstList(): string[] {
    let firstList: string[] = [];
    let index: number = 0;
    this.tabMap.forEach((_value: string[], key: string) => {
      firstList[index] = key;
      index++;
    }, (value: string[], key: string) => JSON.stringify(value) + key);
    return firstList;
  }

  getSecondList(firstTab: string): string[] {
    if (this.tabMap.has(firstTab) && this.tabMap.get(firstTab)) {
      return this.tabMap.get(firstTab)!;
    } else {
      return [];
    }
  }
}

export class FirstTab {
  tabName: string = '';
  tabIcon: Resource;
  tabIconSel: Resource;

  constructor(tabName: Resource, tabIcon: Resource, tabIconSel: Resource) {
    try {
      this.tabName = context.resourceManager.getStringSync(tabName.id);
    } catch (error) {
      hilog.error(0x0000, 'testTag', 'Failed to get string. Cause: %{public}s', JSON.stringify(error) ?? '');
    }
    this.tabIcon = tabIcon;
    this.tabIconSel = tabIconSel;
  }
}

export class TabViewModel {
  private tabMap: TabDataModel;
  firstTabList: FirstTab[] = [
    new FirstTab($r('app.string.tab_home'), $r('app.media.tab_home'), $r('app.media.tab_home_selected')),
    new FirstTab($r('app.string.tab_category'), $r('app.media.tab_category'), $r('app.media.tab_category_selected')),
    new FirstTab($r('app.string.tab_shopping_bag'), $r('app.media.tab_bag'), $r('app.media.tab_bag_selected')),
    new FirstTab($r('app.string.tab_mine'), $r('app.media.tab_mine'), $r('app.media.tab_mine_selected'))
  ]

  constructor() {
    let tabMap: Map<string, string[]> = new Map();
    try {
      tabMap.set(context.resourceManager.getStringSync($r('app.string.tab_home').id), [
        context.resourceManager.getStringSync($r('app.string.selected').id),
        context.resourceManager.getStringSync($r('app.string.video').id),
        context.resourceManager.getStringSync($r('app.string.community').id),
        context.resourceManager.getStringSync($r('app.string.news').id)
      ]);
      tabMap.set(context.resourceManager.getStringSync($r('app.string.tab_category').id), []);
      tabMap.set(context.resourceManager.getStringSync($r('app.string.tab_shopping_bag').id), []);
      tabMap.set(context.resourceManager.getStringSync($r('app.string.tab_mine').id), []);
    } catch (error) {
      hilog.error(0x0000, 'testTag', 'Failed to get string. Cause: %{public}s', JSON.stringify(error) ?? '');
    }
    this.tabMap = new TabDataModel(tabMap);
  }

  getTabMap(): TabDataModel {
    return this.tabMap;
  }

  getTabNameOfFirstLevel(index: number): string {
    return this.tabMap.getFirstList()[index];
  }

  getTabNameOfSecondLevel(firstTab: string, index: number): string {
    return this.tabMap.getSecondList(firstTab)[index];
  }
}

export class VideoDataModel {
  private videoMap: Map<number, Resource>;

  constructor(videoMap: Map<number, Resource>) {
    this.videoMap = videoMap;
  }

  getVideoMap(): Map<number, Resource> {
    return this.videoMap;
  }

  getVideo(index: number): Resource {
    return this.videoMap.get(index)!;
  }
}

export class VideoViewModel {
  private videoMap: VideoDataModel;

  constructor() {
    let videoMap: Map<number, Resource> = new Map();
    videoMap.set(0, $r('app.media.ic_video_1'));
    videoMap.set(1, $r('app.media.ic_video_2'));
    videoMap.set(2, $r('app.media.ic_video_3'));
    videoMap.set(3, $r('app.media.ic_video_4'));
    this.videoMap = new VideoDataModel(videoMap);
  }

  getVideo(index: number): Resource {
    return this.videoMap.getVideo(index);
  }
}