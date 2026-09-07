import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { BusinessStore } from '../../network/BusinessStore';
import { CareTask } from '../../network/Dto';
import {
  QuickEmptyHint,
  QuickFilterChips,
  QuickMetricStrip,
  quickElderLocation,
  quickElderName,
  quickTaskStatusText,
  quickTaskStatusTone
} from './WideDoctorQuickPageKit';

/** 医师端「护理任务」：沉浸式只读路由页，支持按任务状态筛选。 */
@ComponentV2
export struct WideDoctorTasksPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local taskFilter: string = 'all';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    void this.businessStore.load();
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  private taskCount(status: string): number {
    return this.businessStore.tasks.filter((item: CareTask) => item.status === status).length;
  }

  private filteredTasks(): CareTask[] {
    if (this.taskFilter === 'all') {
      return this.businessStore.tasks;
    }
    return this.businessStore.tasks.filter((item: CareTask) => item.status === this.taskFilter);
  }

  @Builder
  private taskRows() {
    ForEach(this.filteredTasks(), (task: CareTask) => {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            if (task.priority === 'danger') {
              Text('紧急')
                .fontSize(10)
                .fontColor(Color.White)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(6)
                .backgroundColor($r('app.color.doctor_workspace_danger'))
            }
            Text(task.title)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.alignItems(VerticalAlign.Center)
          Text(`${quickElderName(this.businessStore, task.elder_id)} · ${quickElderLocation(this.businessStore, task.elder_id)}`)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(quickTaskStatusText(task.status))
          .fontSize(12)
          .fontColor(quickTaskStatusTone(task.status))
      }
      .width('100%')
      .padding({ top: 13, bottom: 13 })
      .borderWidth({ bottom: 0.5 })
      .borderColor({ bottom: $r('sys.color.comp_divider') })
      .alignItems(VerticalAlign.Center)
    }, (task: CareTask) => `quick-task-${task.id}-${task.status}`)
  }

  @Builder
  private tasksCard() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text('任务列表')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank().layoutWeight(1)
        Text(`${this.filteredTasks().length} 项`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })

      Column({ space: 0 }) {
        if (this.filteredTasks().length === 0) {
          QuickEmptyHint({ text: '当前筛选下暂无任务', loading: this.businessStore.loading })
        } else {
          this.taskRows()
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 10 })
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Row() {
          Column({ space: 16 }) {
            QuickMetricStrip({
              metrics: [
                {
                  label: '全部任务',
                  value: `${this.businessStore.tasks.length}`,
                  tone: $r('sys.color.font_secondary')
                },
                { label: '待处理', value: `${this.taskCount('todo')}`, tone: $r('app.color.doctor_workspace_danger') },
                { label: '进行中', value: `${this.taskCount('doing')}`, tone: $r('app.color.doctor_workspace_warning') },
                { label: '已完成', value: `${this.taskCount('done')}`, tone: $r('app.color.doctor_workspace_success') }
              ]
            })

            QuickFilterChips({
              options: [
                { key: 'all', label: '全部' },
                { key: 'todo', label: '待处理' },
                { key: 'doing', label: '进行中' },
                { key: 'done', label: '已完成' }
              ],
              current: this.taskFilter,
              onSelect: (key: string) => {
                this.taskFilter = key;
              }
            })

            this.tasksCard()
          }
          .width('100%')
          .constraintSize({ maxWidth: this.compactWidth ? 1040 : 1320 })
          .padding({
            left: this.compactWidth ? 16 : 24,
            right: this.compactWidth ? 16 : 24,
            top: this.statusBarHeight + 56,
            bottom: 20 + this.naviIndicatorHeight
          })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .onBackPressed((): boolean => {
      this.onClose();
      return true;
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '护理任务' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
