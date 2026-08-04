interface CareTaskInfo {
  id: number;
  title: string;
  time: string;
  owner: string;
  status: string;
}

@ComponentV2
struct ResidentPanel {
  build() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Text('李')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width(52)
          .height(52)
          .textAlign(TextAlign.Center)
          .backgroundColor('#317AF7')
          .borderRadius(26)

        Column({ space: 4 }) {
          Text('李奶奶')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text('阳光区 203 室 · 1 床')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Divider()

      Text('重点关注')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Text('今日饮水偏少，午后需要再次提醒。行走时请注意防跌倒。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(24)
        .width('100%')

      Row() {
        Text('护理等级：二级')
          .fontSize(14)
        Blank()
        Text('房间状态：正常')
          .fontSize(14)
          .fontColor(Color.Green)
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
  }
}

@ComponentV2
struct TaskPanel {
  @Param @Require tasks: CareTaskInfo[];

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('今日任务')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(`${this.tasks.length} 项`)
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')

      ForEach(this.tasks, (task: CareTaskInfo) => {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(task.title)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            Text(`${task.time} · ${task.owner}`)
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(task.status)
            .fontSize(13)
            .fontColor(task.status === '已完成' ? Color.Green : Color.Orange)
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('sys.color.background_primary'))
        .borderRadius(14)
      }, (task: CareTaskInfo) => task.id.toString())
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
  }
}

@Entry
@ComponentV2
struct Index {
  @Local currentBreakpoint: string = 'sm';

  private readonly tasks: CareTaskInfo[] = [
    { id: 1, title: '午后饮水提醒', time: '15:00', owner: '王护工', status: '待处理' },
    { id: 2, title: '血压复测', time: '16:00', owner: '赵医生', status: '待处理' },
    { id: 3, title: '晚餐前用药核对', time: '17:20', owner: '王护工', status: '已完成' }
  ];

  private isWideLayout(): boolean {
    return this.currentBreakpoint === 'md' ||
      this.currentBreakpoint === 'lg' ||
      this.currentBreakpoint === 'xl';
  }

  private pagePadding(): number {
    // TODO 4：xs/sm 返回 16，md/lg/xl 返回 32。
    return 16;
  }

  build() {
    Scroll() {
      Row() {
        Column({ space: 20 }) {
          Column({ space: 10 }) {
            Column({ space: 6 }) {
              Text('姓名：')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
              Text('完成时间：')
                .fontSize(15)
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)

            Text(this.isWideLayout() ? '当前布局：宽屏双栏' : '当前布局：手机单列')
              .fontSize(14)
              .fontColor('#317AF7')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          GridRow({
            columns: { xs: 4, sm: 4, md: 8, lg: 12, xl: 12 },
            gutter: { x: 16, y: 16 },
            breakpoints: {
              value: ['320vp', '600vp', '840vp', '1440vp'],
              reference: BreakpointsReference.WindowSize
            }
          }) {
            GridCol({
              // TODO 2：xs/sm 占 4 列、md 占 3 列、lg/xl 占 4 列。
              span: { xs: 4, sm: 4, md: 8, lg: 12, xl: 12 }
            }) {
              ResidentPanel()
            }

            GridCol({
              // TODO 3：xs/sm 占 4 列、md 占 5 列、lg/xl 占 8 列。
              span: { xs: 4, sm: 4, md: 8, lg: 12, xl: 12 }
            }) {
              TaskPanel({ tasks: this.tasks })
            }
          }
          .width('100%')
          .onBreakpointChange((breakpoint: string) => {
            // TODO 1：把 breakpoint 保存到 currentBreakpoint。
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: 1200 })
        .padding(this.pagePadding())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
