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
import { PostModel } from '../model/PostModel';

/**
 * Post ViewModel - handles post data operations and business logic
 */
@ObservedV2
export class PostViewModel {
  @Trace public postList: PostModel[] = [];

  constructor() {
    this.loadPosts();
  }

  /**
   * Load all posts
   */
  loadPosts(): void {
    this.postList = this.getPostList();
  }

  /**
   * Get all 9 picture resources
   */
  private getAllPictures(): Resource[] {
    return [
      $r('app.media.ic_follow_picture1'),
      $r('app.media.ic_follow_picture2'),
      $r('app.media.ic_follow_picture3'),
      $r('app.media.ic_follow_picture4'),
      $r('app.media.ic_follow_picture5'),
      $r('app.media.ic_follow_picture6'),
      $r('app.media.ic_follow_picture7'),
      $r('app.media.ic_follow_picture8'),
      $r('app.media.ic_follow_picture9')
    ];
  }

  /**
   * Get shuffled pictures for a post
   */
  private getShuffledPictures(): Resource[] {
    return this.shuffleArray(this.getAllPictures());
  }

  /**
   * Get post list data
   */
  private getPostList(): PostModel[] {
    return [
      {
        id: '1',
        authorId: '1',
        authorName: $r('app.string.photographic_vision'),
        authorAvatar: $r('app.media.ic_follow_icon1'),
        authorTagInfo: $r('app.string.author_photography'),
        publishTime: $r('app.string.publish_time_2h'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_hiking'), $r('app.string.tag_travel')],
        content: $r('app.string.content_sanjiangyuan'),
        shareCount: 1557,
        commentCount: 57,
        likeCount: 1557,
        isLiked: false
      },
      {
        id: '2',
        authorId: '2',
        authorName: $r('app.string.nature_style'),
        authorAvatar: $r('app.media.ic_follow_icon2'),
        authorTagInfo: $r('app.string.author_nature'),
        publishTime: $r('app.string.publish_time_3h'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_scenery'), $r('app.string.tag_nature')],
        content: $r('app.string.content_nature'),
        shareCount: 892,
        commentCount: 34,
        likeCount: 1203,
        isLiked: false
      },
      {
        id: '3',
        authorId: '3',
        authorName: $r('app.string.landscape'),
        authorAvatar: $r('app.media.ic_follow_icon3'),
        authorTagInfo: $r('app.string.author_landscape'),
        publishTime: $r('app.string.publish_time_5h'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_mountain'), $r('app.string.tag_landscape')],
        content: $r('app.string.content_landscape'),
        shareCount: 567,
        commentCount: 23,
        likeCount: 890,
        isLiked: false
      },
      {
        id: '4',
        authorId: '4',
        authorName: $r('app.string.tech_review'),
        authorAvatar: $r('app.media.ic_follow_icon4'),
        authorTagInfo: $r('app.string.author_tech'),
        publishTime: $r('app.string.publish_time_yesterday'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_tech'), $r('app.string.tag_review')],
        content: $r('app.string.content_tech'),
        shareCount: 2341,
        commentCount: 156,
        likeCount: 3421,
        isLiked: false
      },
      {
        id: '5',
        authorId: '5',
        authorName: $r('app.string.food_explorer'),
        authorAvatar: $r('app.media.ic_follow_icon5'),
        authorTagInfo: $r('app.string.author_food'),
        publishTime: $r('app.string.publish_time_yesterday'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_food'), $r('app.string.tag_explore')],
        content: $r('app.string.content_food'),
        shareCount: 1892,
        commentCount: 89,
        likeCount: 2156,
        isLiked: false
      },
      {
        id: '6',
        authorId: '6',
        authorName: $r('app.string.travel_diary'),
        authorAvatar: $r('app.media.ic_follow_icon6'),
        authorTagInfo: $r('app.string.author_travel'),
        publishTime: $r('app.string.publish_time_2d'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_travel'), $r('app.string.tag_photography')],
        content: $r('app.string.content_travel'),
        shareCount: 1234,
        commentCount: 67,
        likeCount: 1789,
        isLiked: false
      },
      {
        id: '7',
        authorId: '1',
        authorName: $r('app.string.photographic_vision'),
        authorAvatar: $r('app.media.ic_follow_icon1'),
        authorTagInfo: $r('app.string.author_photography'),
        publishTime: $r('app.string.publish_time_2d'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_photography'), $r('app.string.tag_landscape')],
        content: $r('app.string.content_sunrise'),
        shareCount: 2156,
        commentCount: 98,
        likeCount: 2890,
        isLiked: false
      },
      {
        id: '8',
        authorId: '2',
        authorName: $r('app.string.nature_style'),
        authorAvatar: $r('app.media.ic_follow_icon2'),
        authorTagInfo: $r('app.string.author_nature'),
        publishTime: $r('app.string.publish_time_3d'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_nature'), $r('app.string.tag_ecology')],
        content: $r('app.string.content_forest'),
        shareCount: 1567,
        commentCount: 76,
        likeCount: 1987,
        isLiked: false
      },
      {
        id: '9',
        authorId: '3',
        authorName: $r('app.string.landscape'),
        authorAvatar: $r('app.media.ic_follow_icon3'),
        authorTagInfo: $r('app.string.author_landscape'),
        publishTime: $r('app.string.publish_time_3d'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_scenery'), $r('app.string.tag_mountain')],
        content: $r('app.string.content_lake'),
        shareCount: 987,
        commentCount: 45,
        likeCount: 1456,
        isLiked: false
      },
      {
        id: '10',
        authorId: '4',
        authorName: $r('app.string.tech_review'),
        authorAvatar: $r('app.media.ic_follow_icon4'),
        authorTagInfo: $r('app.string.author_tech'),
        publishTime: $r('app.string.publish_time_4d'),
        images: this.getShuffledPictures(),
        tags: [$r('app.string.tag_digital'), $r('app.string.tag_unboxing')],
        content: $r('app.string.content_unboxing'),
        shareCount: 3421,
        commentCount: 234,
        likeCount: 4567,
        isLiked: false
      }
    ];
  }

  /**
   * Fisher-Yates shuffle algorithm
   */
  private shuffleArray<T>(array: T[]): T[] {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    return shuffled;
  }
}
