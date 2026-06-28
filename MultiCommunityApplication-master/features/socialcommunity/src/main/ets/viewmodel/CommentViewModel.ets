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

import { CommentItemModel } from '../model/CommentModel';

/**
 * Comment ViewModel - handles comment data operations and business logic
 */
@ObservedV2
export class CommentViewModel {
  @Trace public commentList: CommentItemModel[] = [];

  constructor() {
    this.loadComments();
  }

  /**
   * Load all comments
   */
  loadComments(): void {
    this.commentList = this.getCommentList();
  }

  /**
   * Get shuffled comments
   */
  getShuffledComments(): CommentItemModel[] {
    return this.shuffleArray(this.getCommentList());
  }

  /**
   * Get specified number of random comments
   */
  getRandomComments(count: number): CommentItemModel[] {
    const shuffled = this.shuffleArray(this.getCommentList());
    return shuffled.slice(0, Math.min(count, shuffled.length));
  }

  /**
   * Delete a comment by ID
   */
  deleteComment(commentId: string): void {
    const index = this.commentList.findIndex(item => item.id === commentId);
    if (index !== -1) {
      this.commentList.splice(index, 1);
    }
  }

  /**
   * Get comment list data from model
   */
  private getCommentList(): CommentItemModel[] {
    return [
      {
        id: '1',
        userId: 'user1',
        userName: $r('app.string.comment_user_photography_lover'),
        userAvatar: this.getAvatarResource(0),
        content: $r('app.string.comment_content_1'),
        subContent: '',
        likeCount: 128,
        time: '10-23',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_beijing')
      },
      {
        id: '2',
        userId: 'user2',
        userName: $r('app.string.comment_user_travel_expert'),
        userAvatar: this.getAvatarResource(1),
        content: $r('app.string.comment_content_2'),
        subContent: $r('app.string.comment_subcontent_1'),
        likeCount: 86,
        time: '10-23',
        replyCount: 12,
        isLiked: false,
        location: $r('app.string.location_shanghai')
      },
      {
        id: '3',
        userId: 'user3',
        userName: $r('app.string.comment_user_visual_artist'),
        userAvatar: this.getAvatarResource(2),
        content: $r('app.string.comment_content_3'),
        subContent: '',
        likeCount: 245,
        time: '10-22',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_guangzhou')
      },
      {
        id: '4',
        userId: 'user4',
        userName: $r('app.string.comment_user_nature_scenery'),
        userAvatar: this.getAvatarResource(3),
        content: $r('app.string.comment_content_4'),
        subContent: $r('app.string.comment_subcontent_2'),
        likeCount: 167,
        time: '10-22',
        replyCount: 8,
        isLiked: false,
        location: $r('app.string.location_shenzhen')
      },
      {
        id: '5',
        userId: 'user5',
        userName: $r('app.string.comment_user_photo_newbie'),
        userAvatar: this.getAvatarResource(4),
        content: $r('app.string.comment_content_5'),
        subContent: '',
        likeCount: 56,
        time: '10-21',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_hangzhou')
      },
      {
        id: '6',
        userId: 'user6',
        userName: $r('app.string.comment_user_life_recorder'),
        userAvatar: this.getAvatarResource(5),
        content: $r('app.string.comment_content_6'),
        subContent: $r('app.string.comment_subcontent_3'),
        likeCount: 234,
        time: '10-21',
        replyCount: 15,
        isLiked: false,
        location: $r('app.string.location_chengdu')
      },
      {
        id: '7',
        userId: 'user7',
        userName: $r('app.string.comment_user_outdoor_adventurer'),
        userAvatar: this.getAvatarResource(6),
        content: $r('app.string.comment_content_7'),
        subContent: '',
        likeCount: 189,
        time: '10-20',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_xian')
      },
      {
        id: '8',
        userId: 'user8',
        userName: $r('app.string.comment_user_landscape_photographer'),
        userAvatar: this.getAvatarResource(7),
        content: $r('app.string.comment_content_8'),
        subContent: $r('app.string.comment_subcontent_4'),
        likeCount: 312,
        time: '10-20',
        replyCount: 23,
        isLiked: false,
        location: $r('app.string.location_wuhan')
      },
      {
        id: '9',
        userId: 'user9',
        userName: $r('app.string.comment_user_artistic_youth'),
        userAvatar: this.getAvatarResource(8),
        content: $r('app.string.comment_content_9'),
        subContent: '',
        likeCount: 178,
        time: '10-19',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_nanjing')
      },
      {
        id: '10',
        userId: 'user10',
        userName: $r('app.string.comment_user_travel_blogger'),
        userAvatar: this.getAvatarResource(9),
        content: $r('app.string.comment_content_10'),
        subContent: $r('app.string.comment_subcontent_5'),
        likeCount: 445,
        time: '10-19',
        replyCount: 34,
        isLiked: false,
        location: $r('app.string.location_chongqing')
      },
      {
        id: '11',
        userId: 'user11',
        userName: $r('app.string.comment_user_camera_collector'),
        userAvatar: this.getAvatarResource(10),
        content: $r('app.string.comment_content_11'),
        subContent: '',
        likeCount: 267,
        time: '10-18',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_tianjin')
      },
      {
        id: '12',
        userId: 'user12',
        userName: $r('app.string.comment_user_light_chaser'),
        userAvatar: this.getAvatarResource(11),
        content: $r('app.string.comment_content_12'),
        subContent: $r('app.string.comment_subcontent_6'),
        likeCount: 523,
        time: '10-18',
        replyCount: 45,
        isLiked: false,
        location: $r('app.string.location_suzhou')
      },
      {
        id: '13',
        userId: 'user13',
        userName: $r('app.string.comment_user_food_hunter'),
        userAvatar: this.getAvatarResource(12),
        content: $r('app.string.comment_content_13'),
        subContent: '',
        likeCount: 156,
        time: '10-17',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_qingdao')
      },
      {
        id: '14',
        userId: 'user14',
        userName: $r('app.string.comment_user_tech_reviewer'),
        userAvatar: this.getAvatarResource(13),
        content: $r('app.string.comment_content_14'),
        subContent: $r('app.string.comment_subcontent_7'),
        likeCount: 289,
        time: '10-17',
        replyCount: 19,
        isLiked: false,
        location: $r('app.string.location_xiamen')
      },
      {
        id: '15',
        userId: 'user15',
        userName: $r('app.string.comment_user_botanist'),
        userAvatar: this.getAvatarResource(14),
        content: $r('app.string.comment_content_15'),
        subContent: '',
        likeCount: 412,
        time: '10-16',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_kunming')
      },
      {
        id: '16',
        userId: 'user16',
        userName: $r('app.string.comment_user_geography'),
        userAvatar: this.getAvatarResource(15),
        content: $r('app.string.comment_content_16'),
        subContent: $r('app.string.comment_subcontent_8'),
        likeCount: 678,
        time: '10-16',
        replyCount: 56,
        isLiked: false,
        location: $r('app.string.location_changsha')
      },
      {
        id: '17',
        userId: 'user17',
        userName: $r('app.string.comment_user_mountain_climber'),
        userAvatar: this.getAvatarResource(16),
        content: $r('app.string.comment_content_17'),
        subContent: '',
        likeCount: 234,
        time: '10-15',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_zhengzhou')
      },
      {
        id: '18',
        userId: 'user18',
        userName: $r('app.string.comment_user_city_walker'),
        userAvatar: this.getAvatarResource(17),
        content: $r('app.string.comment_content_18'),
        subContent: $r('app.string.comment_subcontent_9'),
        likeCount: 389,
        time: '10-15',
        replyCount: 28,
        isLiked: false,
        location: $r('app.string.location_shenyang')
      },
      {
        id: '19',
        userId: 'user19',
        userName: $r('app.string.comment_user_star_photographer'),
        userAvatar: this.getAvatarResource(18),
        content: $r('app.string.comment_content_19'),
        subContent: '',
        likeCount: 567,
        time: '10-14',
        replyCount: 0,
        isLiked: false,
        location: $r('app.string.location_dalian')
      },
      {
        id: '20',
        userId: 'user20',
        userName: $r('app.string.comment_user_nature_observer'),
        userAvatar: this.getAvatarResource(19),
        content: $r('app.string.comment_content_20'),
        subContent: $r('app.string.comment_subcontent_10'),
        likeCount: 789,
        time: '10-14',
        replyCount: 67,
        isLiked: false,
        location: $r('app.string.location_harbin')
      }
    ];
  }

  /**
   * Get avatar resource (cycle through ic_follow_icon1 - ic_follow_icon6)
   */
  private getAvatarResource(index: number): Resource {
    const iconIndex = (index % 6) + 1
    switch (iconIndex) {
      case 1:
        return $r('app.media.ic_follow_icon1');
      case 2:
        return $r('app.media.ic_follow_icon2');
      case 3:
        return $r('app.media.ic_follow_icon3');
      case 4:
        return $r('app.media.ic_follow_icon4');
      case 5:
        return $r('app.media.ic_follow_icon5');
      case 6:
        return $r('app.media.ic_follow_icon6');
      default:
        return $r('app.media.ic_follow_icon1');
    }
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