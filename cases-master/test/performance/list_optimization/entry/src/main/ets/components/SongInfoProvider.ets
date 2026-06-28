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

import { SongInfoItem } from '../model/LearningResource';

export class SongInfoProvider {
  private readonly _size: number;
  private readonly _data: SongInfoItem[] = []

  constructor(size: number) {
    if (size < 0 || size > 10000) {
      throw RangeError('size must be in range[0,10000]')
    }
    this._size = size
    for (let song_id = 0; song_id < size; song_id++) {
      // 数据库中图片相关地址
      const album_url: string = `XXX`;
      this._data.push(new SongInfoItem(song_id, `Song ${song_id}`, 0, album_url))
    }
  }

  get size(): number {
    return this._size
  }

  get(id: number): SongInfoItem {
    return this._data[id]
  }

  getItems(): Array<SongInfoItem> {
    return this._data
  }

  private getRandomString(length: number): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    const charsLength = chars.length
    let result = ''
    let counter = 0
    while (counter < length) {
      result += chars.charAt(Math.floor((Math.random() * charsLength)))
      counter++
    }
    return result
  }
}