/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

export class Constants {
  /**
   * Surface width in xComponent.
   */
  static readonly X_COMPONENT_SURFACE_WIDTH = 1080; // 1080*1080 stride->1088
  /**
   * Surface height in xComponent.
   */
  static readonly X_COMPONENT_SURFACE_HEIGHT = 1080;
  /**
   * Maximum width.
   */
  public static readonly LAYOUT_MAX: string = '100%';
  /**
   * NavDestination item2.
   */
  public static readonly NAV_DESTINATION_ITEM_2: string = 'NavDestination_item_2';
  /**
   * NavDestination item3.
   */
  public static readonly NAV_DESTINATION_ITEM_3: string = 'NavDestination_item_3';
  // 用于列表中图片总数
  public static readonly IMAGE_TOTAL_NUM: number = 100;
  // 用于Flex中Text总数
  public static readonly TEXT_TOTAL_NUM: number = 200;
  // 用于text数字循环取模
  public static readonly TEXT_CONTENT_DIVIDER: number = 10;
  public static readonly IMAGE_LIST: Resource[] =
    [$r('app.media.ic_comm_pic1'), $r('app.media.ic_comm_pic2'), $r('app.media.ic_comm_pic3'),
      $r('app.media.ic_comm_pic4'), $r('app.media.ic_comm_pic5'), $r('app.media.ic_comm_pic6'),
      $r('app.media.ic_comm_pic7'), $r('app.media.ic_comm_pic8'), $r('app.media.ic_comm_pic9'),
      $r('app.media.ic_comm_pic10'), $r('app.media.ic_comm_pic11')];
  public static readonly SKELETON_IMAGE_LIST: Resource[] = [
    $r('app.media.skeleton_diagram_picture0'), $r('app.media.skeleton_diagram_picture1'),
    $r('app.media.skeleton_diagram_picture2'),
    $r('app.media.skeleton_diagram_picture3'), $r('app.media.skeleton_diagram_picture4'),
    $r('app.media.skeleton_diagram_picture5'),
    $r('app.media.skeleton_diagram_picture6'), $r('app.media.skeleton_diagram_picture7'),
    $r('app.media.skeleton_diagram_picture8'),
    $r('app.media.skeleton_diagram_picture9'), $r('app.media.skeleton_diagram_picture10'),
    $r('app.media.skeleton_diagram_picture11'),
    $r('app.media.skeleton_diagram_picture12'), $r('app.media.skeleton_diagram_picture13')];
  public static readonly SAMPLE_HTML: string = 'https://gitee.com/openharmony/applications_app_samples';
}