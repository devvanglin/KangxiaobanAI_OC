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

import { AppStorageV2, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  SuffixArrow,
  SuffixButton,
  SuffixText
} from '@kit.UIDesignKit';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import { TabPageConfig } from '../model/TabPageModel';
import { BreakpointType } from '../util/BreakpointSystem';

interface MetricTileData {
  label: string;
  value: string;
  note: string;
  toneBackground: ResourceColor;
  toneColor: ResourceColor;
}

interface InsightData {
  title: string;
  tag: string;
  detail: string;
  extra: string;
}

interface ProgressData {
  label: string;
  valueText: string;
  percent: number;
  color: ResourceColor;
}

interface RoomData {
  name: string;
  occupied: string;
  status: string;
  detail: string;
}

interface ResidentData {
  name: string;
  room: string;
  level: string;
  status: string;
  detail: string;
  nextStep: string;
}

interface TaskData {
  time: string;
  title: string;
  detail: string;
  owner: string;
}

interface TaskLaneData {
  title: string;
  badge: string;
  detail: string;
  items: TaskData[];
}

interface SimpleInfoRow {
  label: string;
  value: string;
  note: string;
}

interface PreferenceData {
  title: string;
  value: string;
  detail: string;
}

interface ScheduleData {
  title: string;
  detail: string;
  time: string;
}

interface QuickActionData {
  icon: Resource;
  label: string;
  subLabel?: string;
  badge?: string;
}

interface TaskItemData {
  title: string;
  subtitle: string;
  buttonText: string;
}

interface SettingItemData {
  icon: Resource;
  label: string;
  value?: string;
  showArrow: boolean;
}

interface SettingGroupData {
  title: string;
  items: SettingItemData[];
}

@ComponentV2
export struct TabPageView {
  @Param @Require currentTabIndex: number;
  @Param @Require pageKey: PageKeyEnum;
  @Param @Require config: TabPageConfig;
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();

  private topPadding(): number {
    return this.globalInfoModel.statusBarHeight + 68;
  }

  private currentScroller(): Scroller | undefined {
    return PAGE_SCROLLER_MAP.get(this.pageKey)?.[this.currentTabIndex];
  }

  private isWideLayout(): boolean {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    return widthBreakpoint === WidthBreakpoint.WIDTH_MD ||
      widthBreakpoint === WidthBreakpoint.WIDTH_LG ||
      widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  private isExtraWideLayout(): boolean {
    const widthBreakpoint: WidthBreakpoint = this.globalInfoModel.widthBreakpoint;
    return widthBreakpoint === WidthBreakpoint.WIDTH_LG || widthBreakpoint === WidthBreakpoint.WIDTH_XL;
  }

  private pagePadding(): number {
    return new BreakpointType<number>({
      sm: 16,
      md: 24,
      lg: 28,
      xl: 32
    }).getValue(this.globalInfoModel.widthBreakpoint);
  }

  private bottomPadding(): number {
    return this.isWideLayout() ? 36 : 124;
  }

  private cardRadius(): number {
    return this.isWideLayout() ? 16 : 14;
  }

  private pageBackgroundColor(): ResourceColor {
    return '#EEF2F6';
  }

  private taskLaneSurfaceColor(title: string): ResourceColor {
    if (title === '立即执行') {
      return '#F6F9FF';
    }
    if (title === '今日排程') {
      return '#F8FBFF';
    }
    return '#F4F7FC';
  }

  private taskLaneBorderColor(title: string): ResourceColor {
    if (title === '立即执行') {
      return '#CCD9F5';
    }
    if (title === '今日排程') {
      return '#D7E2F7';
    }
    return '#D4DDEB';
  }

  private taskLaneBadgeBackground(title: string): ResourceColor {
    if (title === '立即执行') {
      return '#E6EEFF';
    }
    if (title === '今日排程') {
      return '#EAF1FD';
    }
    return '#E8EEF8';
  }

  private taskLaneBadgeColor(title: string): ResourceColor {
    if (title === '立即执行') {
      return '#1D63ED';
    }
    if (title === '今日排程') {
      return '#335C88';
    }
    return '#4C6284';
  }

  private dashboardMetrics(): MetricTileData[] {
    return [
      {
        label: '待闭环任务',
        value: '18',
        note: '其中 6 项需 30 分钟内响应',
        toneBackground: '#EAF1FD',
        toneColor: '#1D63ED'
      },
      {
        label: '重点观察长者',
        value: '06',
        note: '涉及情绪、睡眠和离床异常',
        toneBackground: '#FDEFD8',
        toneColor: '#B7791F'
      },
      {
        label: '入住办理',
        value: '03',
        note: '2 位待资料核验，1 位待床位确认',
        toneBackground: '#E9F7F1',
        toneColor: '#0F766E'
      },
      {
        label: '家属回访',
        value: '05',
        note: '今日 17:30 前需完成 3 条反馈',
        toneBackground: '#F9E8EC',
        toneColor: '#B33A5B'
      }
    ];
  }

  private homeInsights(): InsightData[] {
    return [
      {
        title: '情绪主动关怀',
        tag: '高优先',
        detail: '3F-302 肖爷爷今日活动量下降 41%，语音柔性关怀后仍建议人工跟进。',
        extra: '建议由熟悉护工在 15 分钟内二次陪聊，并同步给护理站。'
      },
      {
        title: '夜间安全预警',
        tag: '待复核',
        detail: '2F 东区两位长者近三晚起夜次数增加，床垫与毫米波均提示睡眠片段化。',
        extra: '今晚值班需重点查看离床轨迹与药物服用时间。'
      },
      {
        title: '家属沟通缺口',
        tag: '需联系',
        detail: '今日有 3 位长者家属电话未接通，系统已整理陪伴摘要待回访。',
        extra: '建议晚饭后优先安排视频沟通，降低情绪持续下沉风险。'
      }
    ];
  }

  private homeProgress(): ProgressData[] {
    return [
      {
        label: '班次闭环效率',
        valueText: '92%',
        percent: 92,
        color: '#1D63ED'
      },
      {
        label: '风险提前拦截',
        valueText: '81%',
        percent: 81,
        color: '#0F766E'
      },
      {
        label: '家属反馈完成率',
        valueText: '68%',
        percent: 68,
        color: '#B7791F'
      }
    ];
  }

  private roomCoverage(): RoomData[] {
    return [
      {
        name: '2F 东区',
        occupied: '32 / 36',
        status: '稳定',
        detail: '午间用药已完成，1 位长者待血糖复核。'
      },
      {
        name: '3F 西区',
        occupied: '28 / 32',
        status: '关注',
        detail: '2 位长者需情绪干预，1 位待家属回访。'
      },
      {
        name: '康复单元',
        occupied: '16 / 18',
        status: '排程中',
        detail: '下午两组康复训练与晚餐前复查已排入班次。'
      }
    ];
  }

  private elderResidents(): ResidentData[] {
    return [
      {
        name: '肖爷爷',
        room: '3F-302',
        level: 'A 级关注',
        status: '情绪低落',
        detail: '今日两次联系家属未接通，午后持续静坐，AI 建议人工陪伴接手。',
        nextStep: '15:10 进行二次沟通并记录情绪摘要'
      },
      {
        name: '周奶奶',
        room: '2F-215',
        level: '睡眠观察',
        status: '夜间离床增加',
        detail: '连续三晚起夜增多，深睡时长下降，需确认疼痛与焦虑因素。',
        nextStep: '晚班重点巡房并同步睡眠计划'
      },
      {
        name: '林爷爷',
        room: '3F-306',
        level: '关系风险',
        status: '社交回避',
        detail: '近两日与室友互动减少，语气波动明显，需柔性介入。',
        nextStep: '调整活动搭配并观察晚间情绪波动'
      }
    ];
  }

  private elderGroups(): SimpleInfoRow[] {
    return [
      {
        label: '稳定观察',
        value: '116',
        note: '已完成早巡，可按区域批量复核'
      },
      {
        label: '情绪关怀',
        value: '05',
        note: '包含低落、孤独和家属联络缺口'
      },
      {
        label: '健康风险',
        value: '07',
        note: '主要集中在睡眠、步态和离床异常'
      },
      {
        label: '社交关系',
        value: '03',
        note: '建议关注宿舍匹配和活动参与'
      }
    ];
  }

  private elderActions(): InsightData[] {
    return [
      {
        title: '饮食建议更新',
        tag: '自动生成',
        detail: '根据近期对话和护理记录，4 位长者今日点餐优先推荐低盐高蛋白。',
        extra: '晚餐端提醒已下发到点餐终端。'
      },
      {
        title: '活动陪伴编组',
        tag: '可执行',
        detail: '系统建议将棋牌、书法和花园散步重新编组，提升低社交长者参与度。',
        extra: '建议 16:00 前完成活动确认并安排护工陪同。'
      }
    ];
  }

  private taskLanes(): TaskLaneData[] {
    return [
      {
        title: '立即执行',
        badge: '04',
        detail: '本班次必须立刻接手的任务',
        items: [
          {
            time: '现在',
            title: '进入 3F-302 情绪安抚',
            detail: '阅读 AI 摘要后由熟悉护工接手，避免重复询问。',
            owner: '责任护工 刘婷'
          },
          {
            time: '10 分钟内',
            title: '复核 2F 东区午间用药',
            detail: '6 位长者需统一确认并同步护理站记录。',
            owner: '责任护工 王倩'
          }
        ]
      },
      {
        title: '今日排程',
        badge: '06',
        detail: '围绕入住、活动和回访的时段计划',
        items: [
          {
            time: '14:20',
            title: '完成新入住初评',
            detail: '录入生命体征、陪护需求与房间偏好。',
            owner: '接待护工 陈薇'
          },
          {
            time: '15:40',
            title: '组织小组活动签到',
            detail: '棋牌室和书法角各保留 1 名陪同护工。',
            owner: '活动护工 赵晨'
          }
        ]
      },
      {
        title: '交接闭环',
        badge: '03',
        detail: '班次结束前需要收口的项目',
        items: [
          {
            time: '17:00',
            title: '更新风险预测摘要',
            detail: '沉淀步态、睡眠和情绪异常人群的明日观察名单。',
            owner: '值班组长'
          },
          {
            time: '17:30',
            title: '整理交接班材料',
            detail: '补齐来访、用药与异常情况，形成值班摘要。',
            owner: '全班次协同'
          }
        ]
      }
    ];
  }

  private taskPredictions(): InsightData[] {
    return [
      {
        title: '若肖爷爷今日继续拒绝交流',
        tag: '24h 预测',
        detail: '情绪继续下沉概率升高，建议增加人工陪伴和家属联系频次。',
        extra: '优先安排熟悉护工于晚饭后再次回访。'
      },
      {
        title: '若林爷爷今晚未按时服药',
        tag: '10 天趋势',
        detail: '结合近期步态和心率波动，跌倒风险将明显升高。',
        extra: '需要在今晚交接中单独提醒夜班。'
      }
    ];
  }

  private mineOverview(): PreferenceData[] {
    return [
      {
        title: '当前班次',
        value: '白班中',
        detail: '07:46 已签到，剩余 4 小时 18 分钟，交接状态正常。'
      },
      {
        title: '责任区域',
        value: 'A栋 2F-3F',
        detail: '当前覆盖 28 位长者，其中 6 位为重点关注对象。'
      },
      {
        title: '服务评分',
        value: '4.9 / 5',
        detail: '近 30 天累计收到 18 条正向反馈，回访完成率 96%。'
      }
    ];
  }

  private mineSchedules(): ScheduleData[] {
    return [
      {
        title: '今日交班复核',
        detail: '补齐 3F-302 情绪关怀摘要，并同步夜班重点观察名单。',
        time: '今天 17:20'
      },
      {
        title: '护理培训签到',
        detail: '主题为认知退化早期识别与柔性沟通，需本人签到。',
        time: '周五 15:00'
      },
      {
        title: '家属回访预约',
        detail: '为肖爷爷与家属补充一次视频回访，并更新陪伴记录。',
        time: '周三 19:30'
      }
    ];
  }

  private mineProfiles(): SimpleInfoRow[] {
    return [
      {
        label: '用户身份',
        value: '白班护工',
        note: '责任区 A栋 2F-3F，员工编号 CG-021'
      },
      {
        label: '账号权限',
        value: 'L3 权限',
        note: '可办理入住、维护关怀记录与交接闭环'
      },
      {
        label: '联系与排班',
        value: '内线 8021',
        note: '已绑定护理站、值班组长和紧急联络链路'
      }
    ];
  }

  private minePreferences(): SimpleInfoRow[] {
    return [
      {
        label: '通知策略',
        value: '关键提醒',
        note: '保留一级风险、临近截止与家属回访提醒'
      },
      {
        label: '数字记忆助手',
        value: '已开启',
        note: '优先提示喜好、家属关系和常聊话题'
      },
      {
        label: '登录设备',
        value: '2 台',
        note: '护理站平板与随身终端均已认证登录'
      },
      {
        label: '数据同步',
        value: '正常',
        note: '最近一次同步于 09:42，离线记录会自动补传'
      }
    ];
  }

  @Builder
  private tag(text: string, backgroundColor: ResourceColor, fontColor: ResourceColor = '#305C88') {
    Text(text)
      .fontSize($r('sys.float.Caption_M'))
      .fontColor(fontColor)
      .padding({
        left: $r('sys.float.padding_level3'),
        right: $r('sys.float.padding_level3'),
        top: 4,
        bottom: 4
      })
      .backgroundColor(backgroundColor)
      .borderRadius(10)
  }

  @Builder
  private sectionTitle(eyebrow: string, title: string, detail: string) {
    Column({ space: 4 }) {
      Text(eyebrow)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor('#6B7C93')
      Text(title)
        .fontSize($r('sys.float.Subtitle_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor('#526277')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private metricTile(item: MetricTileData) {
    Column({ space: 10 }) {
      Row() {
        Text(item.label)
          .fontSize($r('sys.float.Body_S'))
          .fontColor('#526277')
        Blank()
        this.tag(item.value, item.toneBackground, item.toneColor)
      }
      Text(item.note)
        .fontSize($r('sys.float.Body_S'))
        .fontColor('#0F172A')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding($r('sys.float.padding_level5'))
    .backgroundColor('#FFFFFF')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#DCE5EF'
    })
  }

  @Builder
  private insightCard(item: InsightData) {
    Column({ space: 12 }) {
      Row() {
        Text(item.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
        this.tag(item.tag, '#EFF4FA', '#45617E')
      }
      Text(item.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor('#1F2937')
      Divider()
        .strokeWidth(1)
        .color('#E4EAF1')
      Text(item.extra)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor('#526277')
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#FFFFFF')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#DCE5EF'
    })
  }

  @Builder
  private progressRow(item: ProgressData) {
    Column({ space: 8 }) {
      Row() {
        Text(item.label)
          .fontSize($r('sys.float.Body_S'))
          .fontColor('#0F172A')
        Blank()
        Text(item.valueText)
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
      }
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor('#E6ECF3')
          .borderRadius(4)
        Row()
          .width(`${item.percent}%`)
          .height(8)
          .backgroundColor(item.color)
          .borderRadius(4)
      }
      .width('100%')
    }
  }

  @Builder
  private roomRow(item: RoomData, isLast: boolean) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(item.name)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
        Text(item.detail)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#526277')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 2 }) {
        Text(item.occupied)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
        Text(item.status)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#6B7C93')
      }
      .alignItems(HorizontalAlign.End)
    }
    .padding({
      top: 12,
      bottom: 12
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E4EAF1'
    })
  }

  @Builder
  private residentCard(item: ResidentData) {
    Column({ space: 12 }) {
      Row() {
        Blank()
          .width(4)
          .height(34)
          .backgroundColor('#1D63ED')
          .borderRadius(2)
          .margin({ right: 10 })
        Column({ space: 4 }) {
          Text(item.name)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Text(`${item.room} · ${item.level}`)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#6B7C93')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        this.tag(item.status, '#EFF4FA', '#45617E')
      }

      Text(item.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor('#1F2937')
      Divider()
        .strokeWidth(1)
        .color('#E4EAF1')
      Text(item.nextStep)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor('#526277')
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#F8FBFF')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#DCE7F7'
    })
  }

  @Builder
  private infoRow(item: SimpleInfoRow, isLast: boolean) {
    Row() {
      Column({ space: 2 }) {
        Text(item.label)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
        Text(item.note)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#6B7C93')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(item.value)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
    }
    .padding({
      top: 12,
      bottom: 12
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E4EAF1'
    })
  }

  @Builder
  private taskRow(item: TaskData, isLast: boolean) {
    Row({ space: 12 }) {
      Text(item.time)
        .width(72)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor('#6B7C93')

      Column({ space: 6 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
        Text(item.detail)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#526277')
        Text(item.owner)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#6B7C93')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .padding({
      top: 12,
      bottom: 12
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E4EAF1'
    })
  }

  @Builder
  private taskLaneCard(item: TaskLaneData) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(item.title)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Text(item.detail)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#6B7C93')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        this.tag(item.badge, this.taskLaneBadgeBackground(item.title), this.taskLaneBadgeColor(item.title))
      }

      Column() {
        Repeat(item.items)
          .each((repeatItem: RepeatItem<TaskData>) => {
            this.taskRow(repeatItem.item, repeatItem.index === item.items.length - 1)
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor(this.taskLaneSurfaceColor(item.title))
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: this.taskLaneBorderColor(item.title)
    })
  }

  @Builder
  private preferenceCard(item: PreferenceData) {
    Column({ space: 10 }) {
      Row() {
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
        Blank()
        Text(item.value)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D63ED')
      }
      Text(item.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor('#526277')
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level5'))
    .backgroundColor('#FFFFFF')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#DCE5EF'
    })
  }

  @Builder
  private scheduleRow(item: ScheduleData, isLast: boolean) {
    Row({ space: 12 }) {
      Text(item.time)
        .width(92)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor('#6B7C93')
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
        Text(item.detail)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor('#526277')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .padding({
      top: 12,
      bottom: 12
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E4EAF1'
    })
  }

  @Builder
  private homeHero() {
    Column({ space: 20 }) {
      Row() {
        Column({ space: 6 }) {
          Text('首页')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#C3D2E2')
          Text('养老院主动服务总览')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FBFF')
          Text('把任务闭环、风险预警、家属沟通和入住办理收拢到同一套值班视图里。')
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#D8E4F0')
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text('96%')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('服务稳定')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D8E4F0')
        }
        .alignItems(HorizontalAlign.End)
      }

      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text('128')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('在院长者')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D8E4F0')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('18')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('待闭环任务')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D8E4F0')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('12')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('可用床位')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D8E4F0')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }

      Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
        this.tag('情绪关注 3', '#20496B', '#E6F1FF')
        this.tag('离床异常 2', '#20496B', '#E6F1FF')
        this.tag('未接来电 5', '#20496B', '#E6F1FF')
        this.tag('今日入住 3', '#20496B', '#E6F1FF')
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#16324A')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#244B70'
    })
  }

  @Builder
  private homeConsole() {
    Column({ space: 14 }) {
      this.sectionTitle('值班指挥台', '任务 SLA', '更偏运营面板的当班视角，适合主管和总值班快速扫读。')

      Column({ space: 12 }) {
        Repeat(this.homeProgress())
          .each((repeatItem: RepeatItem<ProgressData>) => {
            this.progressRow(repeatItem.item)
          })
      }

      Divider()
        .strokeWidth(1)
        .color('#E4EAF1')

      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('17:30')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Text('交接截止')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#6B7C93')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('03')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Text('主管待批')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#6B7C93')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#FFFFFF')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#DCE5EF'
    })
  }

  @Builder
  private homePage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        if (this.isWideLayout()) {
          Row({ space: 16 }) {
            this.homeHero()
            Column() {
              this.homeConsole()
            }
            .width(this.isExtraWideLayout() ? 360 : 320)
          }
        } else {
          Column({ space: 16 }) {
            this.homeHero()
            this.homeConsole()
          }
        }
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        top: this.topPadding()
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('工作总览', '机器负责发现问题', '把情绪、健康、社交与夜间风险整理成护工真正能执行的动作。')

          if (this.isWideLayout()) {
            Row({ space: 12 }) {
              this.metricTile(this.dashboardMetrics()[0])
              this.metricTile(this.dashboardMetrics()[1])
            }
            Row({ space: 12 }) {
              this.metricTile(this.dashboardMetrics()[2])
              this.metricTile(this.dashboardMetrics()[3])
            }
          } else {
            Column({ space: 12 }) {
              Repeat(this.dashboardMetrics())
                .each((repeatItem: RepeatItem<MetricTileData>) => {
                  this.metricTile(repeatItem.item)
                })
            }
          }
        }
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        if (this.isWideLayout()) {
          Row({ space: 16 }) {
            Column({ space: 12 }) {
              this.sectionTitle('重点事项', '优先接管', '先处理那些需要人工温度和快速闭环的事项。')
              Column({ space: 12 }) {
                Repeat(this.homeInsights())
                  .each((repeatItem: RepeatItem<InsightData>) => {
                    this.insightCard(repeatItem.item)
                  })
              }
            }
            .layoutWeight(1)

            Column({ space: 12 }) {
              this.sectionTitle('区域覆盖', '床位与楼层', '看每个区域当前的占用、风险和执行状态。')
              Column() {
                Repeat(this.roomCoverage())
                  .each((repeatItem: RepeatItem<RoomData>) => {
                    this.roomRow(repeatItem.item, repeatItem.index === this.roomCoverage().length - 1)
                  })
              }
              .padding($r('sys.float.padding_level6'))
              .backgroundColor('#FFFFFF')
              .borderRadius(this.cardRadius())
              .border({
                width: 1,
                color: '#DCE5EF'
              })
            }
            .width(this.isExtraWideLayout() ? 360 : 320)
          }
        } else {
          Column({ space: 12 }) {
            this.sectionTitle('重点事项', '优先接管', '先处理那些需要人工温度和快速闭环的事项。')
            Repeat(this.homeInsights())
              .each((repeatItem: RepeatItem<InsightData>) => {
                this.insightCard(repeatItem.item)
              })
            this.sectionTitle('区域覆盖', '床位与楼层', '看每个区域当前的占用、风险和执行状态。')
            Column() {
              Repeat(this.roomCoverage())
                .each((repeatItem: RepeatItem<RoomData>) => {
                  this.roomRow(repeatItem.item, repeatItem.index === this.roomCoverage().length - 1)
                })
            }
            .padding($r('sys.float.padding_level6'))
            .backgroundColor('#FFFFFF')
            .borderRadius(this.cardRadius())
            .border({
              width: 1,
              color: '#DCE5EF'
            })
          }
        }
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        bottom: this.bottomPadding()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private elderHero() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 4 }) {
          Text('长者')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#1D63ED')
          Text('长者画像与风险分层')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Text('更偏“照护判断”的页面，把个体状态、人群分层和下一步建议放在同一块。')
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#526277')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        this.tag('重点关注 06', '#EAF1FD', '#1D63ED')
      }

      Column({ space: 10 }) {
        Row() {
          Text('稳定观察')
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#526277')
          Blank()
          Text('116')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
        }
        Row() {
          Text('风险观察')
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#526277')
          Blank()
          Text('12')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
        }
        Row() {
          Text('社交低活跃')
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#526277')
          Blank()
          Text('08')
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
        }
      }
      .padding($r('sys.float.padding_level5'))
      .backgroundColor('#EAF1FD')
      .borderRadius(14)
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#FFFFFF')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#DCE5EF'
    })
  }

  @Builder
  private elderPage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        this.elderHero()
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        top: this.topPadding()
      })

      ListItem() {
        if (this.isWideLayout()) {
          Row({ space: 16 }) {
            Column({ space: 12 }) {
              this.sectionTitle('重点关怀名单', '个体视角', '左侧专门看重点长者，像护理站的重点对象面板。')
              Column({ space: 12 }) {
                Repeat(this.elderResidents())
                  .each((repeatItem: RepeatItem<ResidentData>) => {
                    this.residentCard(repeatItem.item)
                  })
              }
            }
            .layoutWeight(1)

            Column({ space: 12 }) {
              this.sectionTitle('风险分层矩阵', '人群视图', '右侧更偏院内运营视角，用于看覆盖面和分组变化。')
              Column() {
                Repeat(this.elderGroups())
                  .each((repeatItem: RepeatItem<SimpleInfoRow>) => {
                    this.infoRow(repeatItem.item, repeatItem.index === this.elderGroups().length - 1)
                  })
              }
              .padding($r('sys.float.padding_level6'))
              .backgroundColor('#FFFFFF')
              .borderRadius(this.cardRadius())
              .border({
                width: 1,
                color: '#DCE5EF'
              })

              Column({ space: 12 }) {
                Repeat(this.elderActions())
                  .each((repeatItem: RepeatItem<InsightData>) => {
                    this.insightCard(repeatItem.item)
                  })
              }
            }
            .width(this.isExtraWideLayout() ? 360 : 320)
          }
        } else {
          Column({ space: 12 }) {
            this.sectionTitle('重点关怀名单', '个体视角', '先看具体长者，再看人群分层。')
            Repeat(this.elderResidents())
              .each((repeatItem: RepeatItem<ResidentData>) => {
                this.residentCard(repeatItem.item)
              })
            this.sectionTitle('风险分层矩阵', '人群视图', '更适合主管快速看分组与覆盖情况。')
            Column() {
              Repeat(this.elderGroups())
                .each((repeatItem: RepeatItem<SimpleInfoRow>) => {
                  this.infoRow(repeatItem.item, repeatItem.index === this.elderGroups().length - 1)
                })
            }
            .padding($r('sys.float.padding_level6'))
            .backgroundColor('#FFFFFF')
            .borderRadius(this.cardRadius())
            .border({
              width: 1,
              color: '#DCE5EF'
            })

            this.sectionTitle('个性化建议', '行动建议', '这里不再像首页的警报卡，而更像护理建议单。')
            Repeat(this.elderActions())
              .each((repeatItem: RepeatItem<InsightData>) => {
                this.insightCard(repeatItem.item)
              })
          }
        }
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        bottom: this.bottomPadding()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private taskHero() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 4 }) {
          Text('任务')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#C7D5F8')
          Text('班次执行看板')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('这页不再是信息总览，而是面向执行的工作流看板。')
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#D5E1FF')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        this.tag('SLA 正常', '#213A74', '#D8E5FF')
      }

      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text('4h')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('本班剩余时长')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D5E1FF')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('18')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('待办事项')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D5E1FF')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('03')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('主管确认')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D5E1FF')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#17305E')
    .borderRadius(this.cardRadius())
    .border({
      width: 1,
      color: '#29457A'
    })
  }

  @Builder
  private taskPage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        this.taskHero()
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        top: this.topPadding()
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('班次任务', '按执行链路展开', '这页更像业务看板，而不是单纯的清单。')

          if (this.isExtraWideLayout()) {
            Row({ space: 12 }) {
              Column() {
                this.taskLaneCard(this.taskLanes()[0])
              }
              .layoutWeight(1)
              Column() {
                this.taskLaneCard(this.taskLanes()[1])
              }
              .layoutWeight(1)
              Column() {
                this.taskLaneCard(this.taskLanes()[2])
              }
              .layoutWeight(1)
            }
          } else {
            Column({ space: 12 }) {
              Repeat(this.taskLanes())
                .each((repeatItem: RepeatItem<TaskLaneData>) => {
                  this.taskLaneCard(repeatItem.item)
                })
            }
          }
        }
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('AI 预演', '先看后果再安排动作', '适合值班组长提前判断哪些事情要在今天就处理。')

          if (this.isWideLayout()) {
            Row({ space: 12 }) {
              this.insightCard(this.taskPredictions()[0])
              this.insightCard(this.taskPredictions()[1])
            }
          } else {
            Column({ space: 12 }) {
              Repeat(this.taskPredictions())
                .each((repeatItem: RepeatItem<InsightData>) => {
                  this.insightCard(repeatItem.item)
                })
            }
          }
        }
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        bottom: this.bottomPadding()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  private quickActions(): QuickActionData[] {
    return [
      { icon: $r('sys.symbol.square_and_pencil'), label: '入住登记', subLabel: '3 待处理' },
      { icon: $r('sys.symbol.doc_text'), label: '交接班' },
      { icon: $r('sys.symbol.bell'), label: '消息通知', subLabel: '5 未读' },
      { icon: $r('sys.symbol.paintpalette'), label: '培训学习' },
      { icon: $r('sys.symbol.hand_thumbsup'), label: '我的评价', subLabel: '本月' },
      { icon: $r('sys.symbol.square_and_pencil_fill'), label: '排班表' },
      { icon: $r('sys.symbol.person_2_fill'), label: '紧急联系' },
      { icon: $r('sys.symbol.questionmark_circle'), label: '帮助中心' }
    ];
  }

  private taskItems(): TaskItemData[] {
    return [
      { title: '完成今日入住登记', subtitle: '待处理 3 位', buttonText: '去完成' },
      { title: '提交交接班记录', subtitle: '17:30 截止', buttonText: '去完成' },
      { title: '处理风险观察预警', subtitle: '情绪关注 2 例', buttonText: '去处理' }
    ];
  }

  private settingGroups(): SettingGroupData[] {
    return [
      {
        title: '',
        items: [
          { icon: $r('sys.symbol.lock'), label: '账号安全', value: 'L3 权限', showArrow: true },
          { icon: $r('sys.symbol.bell'), label: '通知提醒', value: '关键提醒', showArrow: true },
          { icon: $r('sys.symbol.share'), label: '登录设备', value: '2 台', showArrow: true },
          { icon: $r('sys.symbol.questionmark_circle'), label: '关于我们', showArrow: true },
          { icon: $r('sys.symbol.gearshape'), label: '通用设置', showArrow: true }
        ]
      }
    ];
  }

  @Builder
  private mineHero() {
    Column({ space: 16 }) {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(64)
            .height(64)
            .backgroundColor('#F2F2F7')
            .borderRadius(32)
          Text('LT')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor('#000000')
        }

        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text('刘婷')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
            Row({ space: 2 }) {
              SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
                .fontSize(11)
                .fontColor(['#8E8E93'])
              Text('L3')
                .fontSize(11)
                .fontColor('#8E8E93')
            }
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .backgroundColor('#F2F2F7')
            .borderRadius(8)
          }
          .alignItems(VerticalAlign.Center)

          Text('阳光护士（2024）')
            .fontSize(14)
            .fontColor('#6B7280')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.square_and_pencil'))
            .fontSize(14)
            .fontColor(['#007DFF'])
          Text('编辑')
            .fontSize(13)
            .fontColor('#007DFF')
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')

      Row({ space: 0 }) {
        this.privilegeItem($r('sys.symbol.person_2_fill'), '我的长者')
        this.privilegeItem($r('sys.symbol.square_and_pencil'), '我的任务')
        this.privilegeItem($r('sys.symbol.hand_thumbsup'), '我的评价')
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .backgroundColor('#F7F8FA')
      .borderRadius(12)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({
      width: 0.5,
      color: '#E5E5EA'
    })
  }

  @Builder
  private privilegeItem(icon: Resource, label: string) {
    Row({ space: 6 }) {
      SymbolGlyph(icon)
        .fontSize(16)
        .fontColor(['#000000'])
        .opacity(0.7)
      Text(label)
        .fontSize(13)
        .fontColor('#000000')
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private mineStatsCard() {
    Row({ space: 0 }) {
      Column({ space: 4 }) {
        Text('28')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
        Text('负责长者')
          .fontSize(12)
          .fontColor('#8E8E93')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('92%')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
        Text('班次完成')
          .fontSize(12)
          .fontColor('#8E8E93')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('4.9')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
        Text('服务评分')
          .fontSize(12)
          .fontColor('#8E8E93')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('12h')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
        Text('培训时长')
          .fontSize(12)
          .fontColor('#8E8E93')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({
      width: 0.5,
      color: '#E5E5EA'
    })
  }

  @Builder
  private quickActionItem(item: QuickActionData) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        SymbolGlyph(item.icon)
          .fontSize(26)
          .fontColor(['#000000'])
          .opacity(0.75)
        if (item.badge) {
          Text(item.badge)
            .fontSize(10)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .backgroundColor('#FF3B30')
            .borderRadius(8)
            .offset({ x: 8, y: -4 })
        }
      }

      Text(item.label)
        .fontSize(13)
        .fontColor('#000000')

      if (item.subLabel) {
        Text(item.subLabel)
          .fontSize(11)
          .fontColor('#8E8E93')
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  private settingItem(item: SettingItemData, isLast: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(item.icon)
            .fontColor(['#000000'])
            .fontSize(22)
        }
      }),
      textItem: {
        primaryText: {
          text: item.label
        }
      },
      suffixItem: item.value ?
        new SuffixText({ text: item.value }) :
        new SuffixArrow({ color: '#C7C7CC' }),
      cardBorderRadius: 0,
      cardBackgroundColor: 'rgba(0,0,0,0)',
      cardHeight: 52,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      onClick: () => {
      }
    })
    .border({
      width: {
        bottom: isLast ? 0 : 0.5
      },
      color: '#E5E5EA'
    })
  }

  @Builder
  private settingGroup(group: SettingGroupData) {
    Column({ space: 0 }) {
      if (group.title !== '') {
        Text(group.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
          .padding({ left: 16, right: 16, top: 14, bottom: 10 })
      }

      Column({ space: 0 }) {
        Repeat(group.items)
          .each((repeatItem: RepeatItem<SettingItemData>) => {
            this.settingItem(repeatItem.item, repeatItem.index === group.items.length - 1)
          })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private mineTaskCard() {
    Column({ space: 0 }) {
      Row({ space: 0 }) {
        Text('我的任务')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
          .layoutWeight(1)

        Row({ space: 2 }) {
          Text('更多')
            .fontSize(14)
            .fontColor('#8E8E93')
          Text('›')
            .fontSize(18)
            .fontColor('#C7C7CC')
        }
        .alignItems(VerticalAlign.Center)
      }
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      Column({ space: 0 }) {
        Repeat(this.taskItems())
          .each((repeatItem: RepeatItem<TaskItemData>) => {
            this.mineTaskRow(repeatItem.item, repeatItem.index === this.taskItems().length - 1)
          })
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({
      width: 0.5,
      color: '#E5E5EA'
    })
  }

  @Builder
  private mineTaskRow(item: TaskItemData, isLast: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(15)
          .fontColor('#000000')
        Text(item.subtitle)
          .fontSize(13)
          .fontColor('#8E8E93')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(item.buttonText)
        .fontSize(13)
        .fontColor('#007DFF')
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .backgroundColor('#F0F7FF')
        .borderRadius(16)
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .border({
      width: {
        bottom: isLast ? 0 : 0.5
      },
      color: '#E5E5EA'
    })
  }

  @Builder
  private minePage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        this.mineHero()
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        top: this.topPadding()
      })

      ListItem() {
        this.mineStatsCard()
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        Column({ space: 0 }) {
          Text('常用功能')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .padding({ left: 16, right: 16, top: 14, bottom: 10 })

          Row({ space: 0 }) {
            this.quickActionItem(this.quickActions()[0])
            this.quickActionItem(this.quickActions()[1])
            this.quickActionItem(this.quickActions()[2])
            this.quickActionItem(this.quickActions()[3])
          }
          .width('100%')

          Row({ space: 0 }) {
            this.quickActionItem(this.quickActions()[4])
            this.quickActionItem(this.quickActions()[5])
            this.quickActionItem(this.quickActions()[6])
            this.quickActionItem(this.quickActions()[7])
          }
          .width('100%')
        }
        .padding({ bottom: 6 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .border({
          width: 0.5,
          color: '#E5E5EA'
        })
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        this.mineTaskCard()
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding()
      })

      ListItem() {
        this.settingGroup(this.settingGroups()[0])
      }
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        bottom: this.bottomPadding()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    if (this.currentTabIndex === 0) {
      this.homePage();
    } else if (this.currentTabIndex === 1) {
      this.elderPage();
    } else if (this.currentTabIndex === 2) {
      this.taskPage();
    } else {
      this.minePage();
    }
  }
}
