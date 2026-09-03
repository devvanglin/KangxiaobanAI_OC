import { BusinessStore } from '../../network/BusinessStore';
import { Alert, Bill, CareTask, Schedule, Room, Bed, Assessment } from '../../network/Dto';

@ComponentV2
export struct WideDoctorQuickPanel {
  @Param kind: string = '';
  @Param compactWidth: boolean = false;
  @Event onBack: () => void = () => {};
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  private scroller: Scroller = new Scroller();

  private title(): string {
    switch (this.kind) { case 'beds': return '床位预览'; case 'tasks': return '护理任务'; case 'alerts': return '告警处理'; case 'assessment': return '健康评估'; case 'billing': return '账单管理'; case 'schedule': return '日常总览'; default: return '医师工作模块'; }
  }

  private roomLabel(room: Room): string { return `${room.building}${room.floor}F-${room.room_no}`; }

  @Builder
  private content() {
    if (this.kind === 'beds') {
      ForEach(this.businessStore.rooms, (room: Room) => {
        Column({ space: 8 }) { Row() { Text(this.roomLabel(room)).fontSize(15).fontWeight(FontWeight.Medium); Blank().layoutWeight(1); Text(`${this.businessStore.beds.filter((bed: Bed) => bed.room_id === room.id).length} 个床位`).fontSize(11).fontColor($r('sys.color.font_secondary')) }.width('100%'); ForEach(this.businessStore.beds.filter((bed: Bed) => bed.room_id === room.id), (bed: Bed) => Row() { Text(`床位 ${bed.bed_no}`).layoutWeight(1).fontSize(12); Text(bed.status === 'occupied' ? '已入住' : bed.status === 'maintenance' ? '维护中' : '空闲').fontSize(12).fontColor(bed.status === 'occupied' ? $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_success')) }.width('100%').height(32), (bed: Bed) => `quick-bed-${bed.id}`) }.width('100%').padding(14).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8)
      }, (room: Room) => `quick-room-${room.id}`)
    } else if (this.kind === 'tasks') {
      ForEach(this.businessStore.tasks, (task: CareTask) => Row() { Text(task.title).layoutWeight(1).fontSize(13); Text(task.status).fontSize(12).fontColor($r('sys.color.font_secondary')) }.width('100%').height(46).padding({ left: 12, right: 12 }).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8), (task: CareTask) => `quick-task-${task.id}`)
    } else if (this.kind === 'alerts') {
      ForEach(this.businessStore.alerts, (alert: Alert) => Row() { Column({ space: 4 }) { Text(alert.type || '风险告警').fontSize(13).fontWeight(FontWeight.Medium); Text(alert.content).fontSize(11).fontColor($r('sys.color.font_secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }.layoutWeight(1).alignItems(HorizontalAlign.Start); Text(alert.status).fontSize(12).fontColor(alert.status === 'closed' ? $r('app.color.doctor_workspace_success') : $r('app.color.doctor_workspace_warning')) }.width('100%').padding(12).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8), (alert: Alert) => `quick-alert-${alert.id}`)
    } else if (this.kind === 'assessment') {
      ForEach(this.businessStore.assessments, (item: Assessment) => Row() { Text(`长者 ${item.elder_id}`).width(100).fontSize(12); Text(item.assessment_type).layoutWeight(1).fontSize(12); Text(item.risk_level || '--').fontSize(12).fontColor($r('sys.color.font_secondary')) }.width('100%').height(44).padding({ left: 12, right: 12 }).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8), (item: Assessment) => `quick-assessment-${item.id}`)
    } else if (this.kind === 'billing') {
      ForEach(this.businessStore.bills, (bill: Bill) => Row() { Text(`长者 ${bill.elder_id}`).width(100).fontSize(12); Text(bill.bill_month).width(100).fontSize(12); Text(`¥${bill.amount.toFixed(2)}`).layoutWeight(1).fontSize(13); Text(bill.status === 'paid' ? '已支付' : '待支付').fontSize(12).fontColor(bill.status === 'paid' ? $r('app.color.doctor_workspace_success') : $r('app.color.doctor_workspace_warning')) }.width('100%').height(44).padding({ left: 12, right: 12 }).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8), (bill: Bill) => `quick-bill-${bill.id}`)
    } else {
      ForEach(this.businessStore.schedules, (item: Schedule) => Row() { Text(item.work_date).width(100).fontSize(12); Text(item.shift).width(80).fontSize(12); Text(item.room_scope || '范围未登记').layoutWeight(1).fontSize(13); Text(item.staff).fontSize(12).fontColor($r('sys.color.font_secondary')) }.width('100%').height(44).padding({ left: 12, right: 12 }).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8), (item: Schedule) => `quick-schedule-${item.id}`)
    }
  }

  build() {
    Scroll(this.scroller) { Column({ space: 14 }) { Row() { Button('返回').height(34).fontSize(12).onClick(() => this.onBack()); Text(this.title()).fontSize(24).fontWeight(FontWeight.Bold).margin({ left: 12 }); Blank().layoutWeight(1) }.width('100%'); Text('以下数据来自服务器当前快照，空数据不会生成本地演示记录。').fontSize(11).fontColor($r('sys.color.font_secondary')); this.content() }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56, bottom: 24 }) }.width('100%').height('100%').scrollBar(BarState.Off)
  }
}
