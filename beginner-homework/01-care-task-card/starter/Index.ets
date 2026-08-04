interface CareTaskInfo {
  residentName: string;
  roomBed: string;
  taskTitle: string;
  scheduledTime: string;
}

@ComponentV2
struct CareTaskCard {
  @Param @Require task: CareTaskInfo;
  @Param @Require waterCups: number;
  @Param @Require isDone: boolean;
  @Event onAddWater: () => void = () => {};
  @Event onToggleDone: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.task.residentName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Text(this.task.roomBed)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(this.isDone ? '已完成' : '待完成')
          .fontSize(14)
          .fontColor(this.isDone ? Color.Green : Color.Orange)
      }
      .width('100%')

      Divider()

      Text(this.task.taskTitle)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      Text(`计划时间：${this.task.scheduledTime}`)
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')

      Text(`今日饮水记录：${this.waterCups} 杯`)
        .fontSize(16)
        .width('100%')

      Row({ space: 12 }) {
        Button('记录饮水')
          .layoutWeight(1)
          .onClick(() => {
            this.onAddWater();
          })

        Button(this.isDone ? '恢复待办' : '完成任务')
          .layoutWeight(1)
          .onClick(() => {
            this.onToggleDone();
          })
      }
      .width('100%')
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
  @Local waterCups: number = 0;
  @Local isDone: boolean = false;

  private readonly task: CareTaskInfo = {
    residentName: '李奶奶',
    roomBed: '阳光区 203室 · 1床',
    taskTitle: '午后饮水提醒',
    scheduledTime: '15:00'
  };

  build() {
    Column({ space: 20 }) {
      Text('康小伴 · 新手作业')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Text('用 V2 状态完成第一张可交互的照护任务卡')
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')

      CareTaskCard({
        task: this.task,
        waterCups: this.waterCups,
        isDone: this.isDone,
        onAddWater: () => {
          // TODO 1：让饮水杯数加 1。
        },
        onToggleDone: () => {
          // TODO 2：在“待完成”和“已完成”之间切换。
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .backgroundColor($r('sys.color.background_primary'))
    .alignItems(HorizontalAlign.Start)
  }
}
