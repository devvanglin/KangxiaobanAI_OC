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
 * Follower data
 */
export class FollowerListModel {
  loadFollowerList(): FollowerModel[] {
    const followerList: FollowerModel[] = [
      {
        id: 1,
        name: $r('app.string.photographic_vision'),
        avatar: $r('app.media.ic_follow_icon1'),
        isOnline: true,
        bio: $r('app.string.follower_bio_photography')
      },
      {
        id: 2,
        name: $r('app.string.follower_nature_style'),
        avatar: $r('app.media.ic_follow_icon2'),
        isOnline: true,
        bio: $r('app.string.follower_bio_guide')
      },
      {
        id: 3,
        name: $r('app.string.follower_landscape'),
        avatar: $r('app.media.ic_follow_icon3'),
        isOnline: false,
        bio: $r('app.string.follower_bio_200k')
      },
      {
        id: 4,
        name: $r('app.string.follower_tech_review'),
        avatar: $r('app.media.ic_follow_icon4'),
        isOnline: true,
        bio: $r('app.string.follower_bio_fastest_review')
      },
      {
        id: 5,
        name: $r('app.string.follower_famous_painter'),
        avatar: $r('app.media.ic_follow_icon5'),
        isOnline: false,
        bio: $r('app.string.follower_bio_official')
      },
      {
        id: 6,
        name: $r('app.string.follower_traveler'),
        avatar: $r('app.media.ic_follow_icon6'),
        isOnline: true,
        bio: $r('app.string.follower_bio_travel')
      },
      {
        id: 7,
        name: $r('app.string.follower_food_explorer'),
        avatar: $r('app.media.ic_follow_icon1'),
        isOnline: true,
        bio: $r('app.string.follower_bio_food')
      },
      {
        id: 8,
        name: $r('app.string.follower_fitness_expert'),
        avatar: $r('app.media.ic_follow_icon2'),
        isOnline: false,
        bio: $r('app.string.follower_bio_fitness')
      },
      {
        id: 9,
        name: $r('app.string.follower_book_sharing'),
        avatar: $r('app.media.ic_follow_icon3'),
        isOnline: true,
        bio: $r('app.string.follower_bio_reading')
      },
      {
        id: 10,
        name: $r('app.string.follower_music_world'),
        avatar: $r('app.media.ic_follow_icon4'),
        isOnline: false,
        bio: $r('app.string.follower_bio_music')
      },
      {
        id: 11,
        name: $r('app.string.follower_movie_review'),
        avatar: $r('app.media.ic_follow_icon5'),
        isOnline: true,
        bio: $r('app.string.follower_bio_movie')
      },
      {
        id: 12,
        name: $r('app.string.follower_game_guide'),
        avatar: $r('app.media.ic_follow_icon6'),
        isOnline: true,
        bio: $r('app.string.follower_bio_game')
      },
      {
        id: 13,
        name: $r('app.string.follower_fashion_trend'),
        avatar: $r('app.media.ic_follow_icon1'),
        isOnline: false,
        bio: $r('app.string.follower_bio_fashion')
      },
      {
        id: 14,
        name: $r('app.string.follower_pet_daily'),
        avatar: $r('app.media.ic_follow_icon2'),
        isOnline: true,
        bio: $r('app.string.follower_bio_pet')
      },
      {
        id: 15,
        name: $r('app.string.follower_handmade_diy'),
        avatar: $r('app.media.ic_follow_icon3'),
        isOnline: false,
        bio: $r('app.string.follower_bio_handmade')
      },
      {
        id: 16,
        name: $r('app.string.follower_car_review'),
        avatar: $r('app.media.ic_follow_icon4'),
        isOnline: true,
        bio: $r('app.string.follower_bio_car')
      },
      {
        id: 17,
        name: $r('app.string.follower_home_life'),
        avatar: $r('app.media.ic_follow_icon5'),
        isOnline: false,
        bio: $r('app.string.follower_bio_home')
      },
      {
        id: 18,
        name: $r('app.string.follower_parenting'),
        avatar: $r('app.media.ic_follow_icon6'),
        isOnline: true,
        bio: $r('app.string.follower_bio_parenting')
      },
      {
        id: 19,
        name: $r('app.string.follower_tech_frontier'),
        avatar: $r('app.media.ic_follow_icon1'),
        isOnline: true,
        bio: $r('app.string.follower_bio_tech')
      },
      {
        id: 20,
        name: $r('app.string.follower_history_humanities'),
        avatar: $r('app.media.ic_follow_icon2'),
        isOnline: false,
        bio: $r('app.string.follower_bio_history')
      },
      {
        id: 21,
        name: $r('app.string.follower_anime'),
        avatar: $r('app.media.ic_follow_icon3'),
        isOnline: true,
        bio: $r('app.string.follower_bio_anime')
      }
    ];
    return followerList;
  };
}

export interface FollowerModel {
  id: number;
  name: ResourceStr;
  avatar: Resource;
  isOnline: boolean;
  bio: ResourceStr;
}
