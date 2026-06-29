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

import { AppStorageV2 } from '@kit.ArkUI';
import { StorageKey } from '../common/CommonConstants';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PageKeyEnum, PAGE_SCROLLER_MAP } from '../model/TabsBarModel';
import { TabPageConfig } from '../model/TabPageModel';

interface DashboardMetric {
  title: string;
  value: string;
  detail: string;
  accentColor: ResourceColor;
}

interface AttentionCard {
  title: string;
  tag: string;
  detail: string;
  summary: string;
}

interface GaugeRow {
  label: string;
  valueText: string;
  percent: number;
  accentColor: ResourceColor;
}

interface ElderFocusCard {
  name: string;
  room: string;
  status: string;
  detail: string;
  action: string;
  backgroundColor: ResourceColor;
}

interface InsightCard {
  title: string;
  tag: string;
  detail: string;
  suggestion: string;
}

interface SuggestionCard {
  title: string;
  detail: string;
}

interface TaskGroup {
  title: string;
  count: string;
  detail: string;
  items: TaskItem[];
}

interface TaskItem {
  time: string;
  title: string;
  detail: string;
  tag: string;
}

interface SimulationCard {
  title: string;
  detail: string;
  result: string;
}

interface MineCard {
  title: string;
  value: string;
  detail: string;
}

interface MemoryCue {
  elderName: string;
  detail: string;
}

interface PreferenceRow {
  label: string;
  value: string;
}

@ComponentV2
export struct TabPageView {
  @Param @Require currentTabIndex: number;
  @Param @Require pageKey: PageKeyEnum;
  @Param @Require config: TabPageConfig;
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO) ?? new GlobalInfoModel();

  private topPadding(): number {
    return this.globalInfoModel.statusBarHeight + 84;
  }

  private currentScroller(): Scroller | undefined {
    return PAGE_SCROLLER_MAP.get(this.pageKey)?.[this.currentTabIndex];
  }

  private pageBackgroundColor(): ResourceColor {
    switch (this.currentTabIndex) {
      case 0:
        return '#F3F6F8';
      case 1:
        return '#F7F7F4';
      case 2:
        return '#F6F4F1';
      default:
        return '#F5F6F7';
    }
  }

  private homeMetrics(): DashboardMetric[] {
    return [
      {
        title: '待处理任务',
        value: '18',
        detail: '6 项需要 30 分钟内响应',
        accentColor: '#1F8EFA'
      },
      {
        title: '主动关怀触达',
        value: '14',
        detail: 'AI 已完成首轮柔性问询',
        accentColor: '#17B26A'
      },
      {
        title: '夜间高危线索',
        value: '02',
        detail: '离床异常与呼吸波动待复核',
        accentColor: '#F79009'
      },
      {
        title: '家属未接通',
        value: '03',
        detail: '建议转人工安抚与二次回访',
        accentColor: '#EF5B72'
      }
    ];
  }

  private homeAttentionCards(): AttentionCard[] {
    return [
      {
        title: '情绪主动关怀',
        tag: '优先处理',
        detail: '肖爷爷上午持续低头发呆，活动量比近 7 日均值下降 42%。系统已完成语音关怀，仍建议人工进入房间。',
        summary: '结合心率、呼吸和家属联系记录，倾向情绪低落而非急性身体不适。'
      },
      {
        title: '宿舍关系风险',
        tag: '建议关注',
        detail: '3F 西区 306 房近 48 小时出现回避互动和高频短促争执，关系风险等级上升。',
        summary: '建议护理员陪同沟通，并在晚间活动中重新安排同伴互动。'
      },
      {
        title: '夜间主动安全',
        tag: '值班同步',
        detail: '2 位长者夜间离床次数增加，毫米波检测显示睡眠断续与呼吸节律波动。',
        summary: '系统已降噪处理误报，建议值班组重点巡房并确认夜间用药。'
      }
    ];
  }

  private homeGaugeRows(): GaugeRow[] {
    return [
      {
        label: '风险提前拦截率',
        valueText: '82%',
        percent: 82,
        accentColor: '#17B26A'
      },
      {
        label: '护理班次负载',
        valueText: '74%',
        percent: 74,
        accentColor: '#1F8EFA'
      },
      {
        label: '情绪关怀覆盖',
        valueText: '68%',
        percent: 68,
        accentColor: '#F79009'
      }
    ];
  }

  private elderFocusCards(): ElderFocusCard[] {
    return [
      {
        name: '肖爷爷',
        room: '3F-302',
        status: '情绪低落',
        detail: '今天两次呼叫家属均无人接听，午后长时间静坐，系统建议先由熟悉的护工陪聊。',
        action: '安排人工关怀',
        backgroundColor: '#FFFFFF'
      },
      {
        name: '周奶奶',
        room: '2F-215',
        status: '睡眠波动',
        detail: '近三晚起夜次数增加，床垫与毫米波均提示深睡时长下降，需关注是否存在焦虑与疼痛。',
        action: '补做晚间评估',
        backgroundColor: '#F9FBFD'
      },
      {
        name: '林爷爷',
        room: '3F-306',
        status: '关系风险',
        detail: '同宿舍互动明显减少，语气波动上升。建议通过活动场景重建社交连接，避免持续压抑。',
        action: '调整活动搭配',
        backgroundColor: '#FCFAF6'
      }
    ];
  }

  private elderInsightCards(): InsightCard[] {
    return [
      {
        title: '社交孤立线索',
        tag: '08 人',
        detail: '系统识别到 8 位长者本周与他人主动交流次数明显低于个人基线。',
        suggestion: '优先安排棋牌、书法和花园散步等低门槛结伴活动。'
      },
      {
        title: '关系匹配建议',
        tag: '03 条',
        detail: '根据语气、作息、冲突频率与兴趣偏好，当前有 3 组宿舍组合需要重新关注。',
        suggestion: '建议院方先做柔性干预，再决定是否调整宿舍匹配。'
      }
    ];
  }

  private elderSuggestions(): SuggestionCard[] {
    return [
      {
        title: '饮食提醒',
        detail: '肖爷爷近期多次提到想吃清淡少油，点餐终端应优先推荐低盐高蛋白套餐。'
      },
      {
        title: '家属联络',
        detail: '周奶奶今天适合安排一次视频联系，系统建议在晚饭后 19:30 发起预约。'
      },
      {
        title: '活动规划',
        detail: '林爷爷连续三天活动量偏低，天气良好，建议下午 16:00 安排庭院散步。'
      }
    ];
  }

  private taskGroups(): TaskGroup[] {
    return [
      {
        title: '立即执行',
        count: '04 项',
        detail: '需要本轮班次立刻接手的事项',
        items: [
          {
            time: '现在',
            title: '进入 3F-302 情绪安抚',
            detail: '读取 AI 关怀摘要后由熟悉护工接管，避免机械重复问询。',
            tag: '高优'
          },
          {
            time: '10 分钟内',
            title: '确认 2F 东区午间用药',
            detail: '6 位长者待二次确认，药物与血糖记录需同步回护理站。',
            tag: '复核'
          }
        ]
      },
      {
        title: '14:00 - 16:00',
        count: '06 项',
        detail: '围绕评估、活动与回访的中段工作',
        items: [
          {
            time: '14:20',
            title: '完成新入住初评',
            detail: '补录生命体征、陪护需求与房间偏好，交接给值班护士。',
            tag: '入住'
          },
          {
            time: '15:00',
            title: '家属回访与视频预约',
            detail: '重点联系今天未接通家属的 3 个家庭，避免长者情绪继续下沉。',
            tag: '回访'
          },
          {
            time: '15:40',
            title: '组织小组活动签到',
            detail: '棋牌室与书法角各预留 1 位陪同护工，观察社交回避情况。',
            tag: '活动'
          }
        ]
      },
      {
        title: '交接前',
        count: '03 项',
        detail: '班次结束前必须闭环的工作',
        items: [
          {
            time: '17:00',
            title: '更新风险预测摘要',
            detail: '对步态放缓、睡眠断续、情绪低落的长者生成明日重点观察名单。',
            tag: '预测'
          },
          {
            time: '17:30',
            title: '整理交接班材料',
            detail: '补齐用药、来访、冲突和夜间注意事项，形成值班摘要。',
            tag: '交接'
          }
        ]
      }
    ];
  }

  private taskSimulationCards(): SimulationCard[] {
    return [
      {
        title: '如果肖爷爷今天继续拒绝交流',
        detail: '系统预测未来 24 小时内情绪继续下沉的概率升高，建议增加人工陪伴频次。',
        result: '优先安排熟悉护工晚间再次回访。'
      },
      {
        title: '如果林爷爷今晚未按时服药',
        detail: '结合近期步态与心率波动，跌倒风险会在未来 10 天显著上升。',
        result: '需要在今晚交接中单独提醒值班组。'
      }
    ];
  }

  private mineCards(): MineCard[] {
    return [
      {
        title: '今日交接摘要',
        value: '7 条',
        detail: '其中 3 条与情绪关怀相关，2 条与夜间安全相关。'
      },
      {
        title: '我的关怀触达',
        value: '12 次',
        detail: '本班你接手了 5 位重点长者的人工安抚与家属回访。'
      },
      {
        title: '本周培训',
        value: '周五 15:00',
        detail: '主题为认知退化早期识别与关系冲突柔性处理。'
      }
    ];
  }

  private memoryCues(): MemoryCue[] {
    return [
      {
        elderName: '肖爷爷',
        detail: '可以从“孙子最近考试怎么样了”这个话题切入，老人更容易打开交流。'
      },
      {
        elderName: '周奶奶',
        detail: '最近主动提出少油少盐，点餐时优先提醒清淡饮食与高蛋白补充。'
      },
      {
        elderName: '林爷爷',
        detail: '今天和室友出现口角，建议先分开活动，再在晚间安排缓和沟通。'
      }
    ];
  }

  private preferenceRows(): PreferenceRow[] {
    return [
      {
        label: '通知策略',
        value: '仅接收一级与二级提醒'
      },
      {
        label: '数字记忆助手',
        value: '已开启重要话题优先提示'
      },
      {
        label: '值班交接方式',
        value: '班末自动生成摘要并人工补充'
      }
    ];
  }

  @Builder
  private sectionTitle(eyebrow: string, title: string, description: string) {
    Column({ space: 4 }) {
      Text(eyebrow)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text(title)
        .fontSize($r('sys.float.Subtitle_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(description)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private pill(text: string, backgroundColor: ResourceColor, fontColor: ResourceColor = '#F5F7FA') {
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
      .borderRadius($r('sys.float.corner_radius_level8'))
  }

  @Builder
  private metricCard(item: DashboardMetric) {
    Column({ space: 10 }) {
      Row() {
        Text(item.title)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Circle()
          .width(8)
          .height(8)
          .fill(item.accentColor)
      }
      Text(item.value)
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(item.detail)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level5'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level16'))
    .layoutWeight(1)
  }

  @Builder
  private attentionCard(card: AttentionCard) {
    Column({ space: 14 }) {
      Row() {
        Text(card.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        this.pill(card.tag, '#EEF4FF', '#245BDB')
      }
      Text(card.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
      Text(card.summary)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level16'))
  }

  @Builder
  private gaugeRow(item: GaugeRow) {
    Column({ space: 8 }) {
      Row() {
        Text(item.label)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(item.valueText)
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor('#E5E8EC')
          .borderRadius(4)
        Row()
          .width(`${item.percent}%`)
          .height(8)
          .backgroundColor(item.accentColor)
          .borderRadius(4)
      }
      .width('100%')
    }
  }

  @Builder
  private elderFocusCard(card: ElderFocusCard) {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text(card.name)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(card.room)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        this.pill(card.status, '#FFFFFF', '#111827')
      }
      Text(card.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
      Divider()
        .strokeWidth(1)
        .color('#E6E8EB')
      Text(card.action)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor(card.backgroundColor)
    .borderRadius($r('sys.float.corner_radius_level16'))
  }

  @Builder
  private insightCard(card: InsightCard) {
    Column({ space: 12 }) {
      Row() {
        Text(card.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        this.pill(card.tag, '#F3F4F6', '#344054')
      }
      Text(card.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
      Text(card.suggestion)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level16'))
  }

  @Builder
  private suggestionCard(card: SuggestionCard) {
    Column({ space: 8 }) {
      Text(card.title)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(card.detail)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level5'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level12'))
  }

  @Builder
  private taskGroupCard(group: TaskGroup) {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text(group.title)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(group.detail)
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        this.pill(group.count, '#F3EFE8', '#7A4A17')
      }

      Column({ space: 12 }) {
        Repeat(group.items)
          .each((repeatItem: RepeatItem<TaskItem>) => {
            Row({ space: $r('sys.float.padding_level4') }) {
              Text(repeatItem.item.time)
                .width(72)
                .fontSize($r('sys.float.Caption_M'))
                .fontColor($r('sys.color.font_secondary'))
              Column({ space: 6 }) {
                Row() {
                  Text(repeatItem.item.title)
                    .fontSize($r('sys.float.Body_M'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                    .layoutWeight(1)
                  this.pill(repeatItem.item.tag, '#F7F7F8', '#475467')
                }
                Text(repeatItem.item.detail)
                  .fontSize($r('sys.float.Caption_M'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .padding($r('sys.float.padding_level4'))
              .backgroundColor('#FFFFFF')
              .borderRadius($r('sys.float.corner_radius_level10'))
              .layoutWeight(1)
            }
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level16'))
  }

  @Builder
  private simulationCard(card: SimulationCard) {
    Column({ space: 12 }) {
      Text(card.title)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(card.detail)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
      Divider()
        .strokeWidth(1)
        .color('#E7E5E4')
      Text(card.result)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level5'))
    .backgroundColor('#FFFDFC')
    .borderRadius($r('sys.float.corner_radius_level12'))
  }

  @Builder
  private mineCard(item: MineCard) {
    Column({ space: 10 }) {
      Text(item.title)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
      Text(item.value)
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(item.detail)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level5'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level16'))
  }

  @Builder
  private memoryCueRow(cue: MemoryCue, isLast: boolean) {
    Row({ space: $r('sys.float.padding_level4') }) {
      Text(cue.elderName)
        .width(64)
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(cue.detail)
        .layoutWeight(1)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(VerticalAlign.Top)
    .padding({
      top: $r('sys.float.padding_level4'),
      bottom: $r('sys.float.padding_level4')
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E8EAED'
    })
  }

  @Builder
  private preferenceRow(row: PreferenceRow, isLast: boolean) {
    Row() {
      Text(row.label)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
      Blank()
      Text(row.value)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .padding({
      top: $r('sys.float.padding_level4'),
      bottom: $r('sys.float.padding_level4')
    })
    .border({
      width: {
        bottom: isLast ? 0 : 1
      },
      color: '#E8EAED'
    })
  }

  @Builder
  private homePage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        Column({ space: 16 }) {
          this.homeHero()

          Row({ space: $r('sys.float.padding_level4') }) {
            this.metricCard(this.homeMetrics()[0])
            this.metricCard(this.homeMetrics()[1])
          }

          Row({ space: $r('sys.float.padding_level4') }) {
            this.metricCard(this.homeMetrics()[2])
            this.metricCard(this.homeMetrics()[3])
          }
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        top: this.topPadding()
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('全院实时态势', '机器负责发现问题', '把情绪、关系、生命体征和夜间安全集中呈现给当班护工。')
          Column({ space: 12 }) {
            Repeat(this.homeAttentionCards())
              .each((repeatItem: RepeatItem<AttentionCard>) => {
                this.attentionCard(repeatItem.item)
              })
          }
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8')
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('运营看板', '从被动处理到主动预防', '把护理班次的压力、覆盖度和风险拦截效果放在同一张屏里。')
          Column({ space: 16 }) {
            Repeat(this.homeGaugeRows())
              .each((repeatItem: RepeatItem<GaugeRow>) => {
                this.gaugeRow(repeatItem.item)
              })
          }
          .padding($r('sys.float.padding_level6'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius($r('sys.float.corner_radius_level16'))
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        bottom: 120
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private homeHero() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 6 }) {
          Text('首页')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#C9D5DC')
          Text('养老院主动服务大屏')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FBFD')
          Text('面向当班护工，把情绪、健康、社交和夜间风险集中到一个行动视图。')
            .fontSize($r('sys.float.Body_S'))
            .fontColor('#D7E2E8')
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text('96%')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FBFD')
          Text('状态稳定')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D7E2E8')
        }
        .alignItems(HorizontalAlign.End)
      }

      Row({ space: $r('sys.float.padding_level5') }) {
        Column({ space: 2 }) {
          Text('128')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FBFD')
          Text('在院长者')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D7E2E8')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 2 }) {
          Text('06')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FBFD')
          Text('重点预警')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D7E2E8')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 2 }) {
          Text('03')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FBFD')
          Text('家属未接通')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor('#D7E2E8')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }

      Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
        this.pill('情绪低落 3', '#244A5B')
        this.pill('关系风险 1', '#244A5B')
        this.pill('夜间异常 2', '#244A5B')
        this.pill('今日入住 3', '#244A5B')
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor('#173847')
    .borderRadius(24)
  }

  @Builder
  private elderPage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        Column({ space: 16 }) {
          this.elderHero()
          Column({ space: 12 }) {
            Repeat(this.elderFocusCards())
              .each((repeatItem: RepeatItem<ElderFocusCard>) => {
                this.elderFocusCard(repeatItem.item)
              })
          }
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        top: this.topPadding()
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('社交与关系', '院内关系风险分析', '不是监控，而是通过长期语气、互动和回避行为识别可能被忽视的压力。')
          Row({ space: $r('sys.float.padding_level4') }) {
            this.insightCard(this.elderInsightCards()[0])
            this.insightCard(this.elderInsightCards()[1])
          }
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8')
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('个性化建议', '理解老人，而不是只看告警', '结合生活习惯、家属联系和近期数据，为护理员提供更有人情味的下一步。')
          Column({ space: 12 }) {
            Repeat(this.elderSuggestions())
              .each((repeatItem: RepeatItem<SuggestionCard>) => {
                this.suggestionCard(repeatItem.item)
              })
          }
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        bottom: 120
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
    Column({ space: 16 }) {
      this.sectionTitle('长者', '动态生活画像', '多模态融合行为、睡眠、呼吸、社交和饮食信息，让护工看到一位“人”的连续状态。')
      Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
        this.pill('情绪波动 2', '#ECE9F8', '#5B3FB4')
        this.pill('睡眠断续 5', '#E9F6EF', '#18794E')
        this.pill('家属联系稀疏 8', '#FFF1E7', '#B54708')
        this.pill('关系冲突 1', '#FDEBEC', '#B42318')
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
  }

  @Builder
  private taskPage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        Column({ space: 16 }) {
          this.taskHero()
          Column({ space: 12 }) {
            Repeat(this.taskGroups())
              .each((repeatItem: RepeatItem<TaskGroup>) => {
                this.taskGroupCard(repeatItem.item)
              })
          }
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        top: this.topPadding()
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('AI 预演', '把未来十天提前放到眼前', '系统围绕步态、心率、用药、冲突与睡眠做短期演化预测，辅助交接决策。')
          Column({ space: 12 }) {
            Repeat(this.taskSimulationCards())
              .each((repeatItem: RepeatItem<SimulationCard>) => {
                this.simulationCard(repeatItem.item)
              })
          }
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        bottom: 120
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
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('任务')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
          Text('当班执行面板')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('把情绪关怀、风险复核、入住登记和交接闭环统一编排。')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        this.pill('AI 已编排 6 条建议', '#EEE8DD', '#7A4A17')
      }

      Row({ space: $r('sys.float.padding_level5') }) {
        Column({ space: 2 }) {
          Text('4h')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('本班剩余时长')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('18')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('待办事项')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('03')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('需班长确认')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
  }

  @Builder
  private minePage() {
    List({
      scroller: this.currentScroller(),
      space: 16
    }) {
      ListItem() {
        Column({ space: 16 }) {
          this.mineHero()
          Column({ space: 12 }) {
            Repeat(this.mineCards())
              .each((repeatItem: RepeatItem<MineCard>) => {
                this.mineCard(repeatItem.item)
              })
          }
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        top: this.topPadding()
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('数字记忆助手', '帮助你更有温度地接近老人', '不是替代护理员，而是在关键时刻提醒你该说什么、该联系谁、该先照顾谁。')
          Column() {
            Repeat(this.memoryCues())
              .each((repeatItem: RepeatItem<MemoryCue>) => {
                this.memoryCueRow(repeatItem.item, repeatItem.index === this.memoryCues().length - 1)
              })
          }
          .padding($r('sys.float.padding_level6'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius($r('sys.float.corner_radius_level16'))
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8')
      })

      ListItem() {
        Column({ space: 12 }) {
          this.sectionTitle('我的工作方式', '把重要提醒留给真正重要的事', '保持轻量、清楚、可交接，是护工端最重要的秩序感。')
          Column() {
            Repeat(this.preferenceRows())
              .each((repeatItem: RepeatItem<PreferenceRow>) => {
                this.preferenceRow(repeatItem.item, repeatItem.index === this.preferenceRows().length - 1)
              })
          }
          .padding($r('sys.float.padding_level6'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius($r('sys.float.corner_radius_level16'))
        }
      }
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        bottom: 120
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private mineHero() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('我的')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
          Text('护工工作台')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('今天你的重点是稳定情绪、做好交接，并让每一次人工接手都更有温度。')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        this.pill('白班 08:00-18:00', '#EEF2F6', '#344054')
      }

      Row({ space: $r('sys.float.padding_level5') }) {
        Column({ space: 2 }) {
          Text('07:46')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('签到时间')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('92')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('班次完成度')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('高')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('情绪陪伴贡献')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level6'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
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
