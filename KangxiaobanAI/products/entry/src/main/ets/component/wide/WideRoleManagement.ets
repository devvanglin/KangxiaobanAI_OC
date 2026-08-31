import ApiClient from '../../network/ApiClient';

interface RolePermission { code: string; name: string; }
interface RoleRecord { id: number; code: string; name: string; description: string; created_at?: string; permissions?: RolePermission[]; }
interface RolePage { list: RoleRecord[]; total: number; }

@ComponentV2
export struct WideRoleManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Local roles: RoleRecord[] = [];
  @Local keyword: string = '';
  @Local selectedRoleId: number = 0;
  @Local hoveredRoleId: number = 0;
  @Local loading: boolean = false;
  @Local error: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.loadRoles(); }

  private async loadRoles(): Promise<void> {
    this.loading = true; this.error = '';
    try {
      const response = await ApiClient.get<RolePage>(`/roles?keyword=${encodeURIComponent(this.keyword)}&page=1&size=50`);
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.roles = response.data.list ?? [];
    } catch (_error) { this.error = '角色数据加载失败'; }
    this.loading = false;
  }

  private actionHint(action: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: `${action}接口尚未开放` });
    } catch (_error) {
    }
  }

  private formatCreatedAt(value?: string): string {
    if (value === undefined || value.length < 16) return '--';
    return value.slice(0, 19).replace('T', ' ');
  }

  @Builder
  private roleToolbar() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text('角色名称').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
        TextInput({ placeholder: '请输入角色名称或权限字符', text: $$this.keyword })
          .width(this.compactWidth ? 220 : 280).height(38).fontSize(13).borderRadius(6)
        Text('状态').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
        Text('全部').width(110).height(38).padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .fontSize(13).fontColor($r('sys.color.font_secondary'))
          .borderRadius(6).border({ width: 0.5, color: $r('sys.color.comp_divider') })
        Button('搜索').height(38).fontSize(13).borderRadius(6)
        .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
        .onClick(() => this.loadRoles())
        Button('重置').height(38).fontSize(13).borderRadius(6)
        .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
        .onClick(() => { this.keyword = ''; this.loadRoles(); })
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 10 }) {
        Button('新增').height(36).fontSize(12).borderRadius(6)
          .fontColor($r('app.color.brand_blue')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.actionHint('新增角色'))
        Button('修改').height(36).fontSize(12).borderRadius(6).enabled(this.selectedRoleId > 0)
          .onClick(() => this.actionHint('修改角色'))
        Button('删除').height(36).fontSize(12).borderRadius(6).enabled(this.selectedRoleId > 0)
          .onClick(() => this.actionHint('删除角色'))
        Button('导出').height(36).fontSize(12).borderRadius(6)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.actionHint('导出角色'))
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private roleRow(role: RoleRecord, index: number) {
    Row({ space: 12 }) {
      Text(role.id.toString()).width(86).fontSize(13).fontColor($r('sys.color.font_secondary'))
      Text(role.name || '--').width(150).fontSize(13).fontColor($r('sys.color.font_primary'))
      Text(role.code || '--').width(170).fontSize(13).fontColor($r('sys.color.font_secondary'))
      Text(role.permissions?.map((item: RolePermission) => item.code).join('、') || '暂无权限')
        .width(290).fontSize(12).fontColor($r('sys.color.font_secondary')).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Button('启用').width(62).height(28).fontSize(11).borderRadius(14)
        .fontColor(Color.White).backgroundColor($r('app.color.doctor_workspace_success'))
        .onClick(() => this.actionHint('状态切换'))
      Text(this.formatCreatedAt(role.created_at)).width(160).fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 10 }) {
        Text('编辑').fontSize(12).fontColor($r('app.color.brand_blue')).onClick(() => this.actionHint('编辑角色'))
        Text('分配数据权限').fontSize(12).fontColor($r('app.color.brand_blue')).onClick(() => this.actionHint('分配数据权限'))
      }.width(150)
    }.constraintSize({ minWidth: 1120 }).width('100%').height(54).padding({ left: 12, right: 12 })
      .backgroundColor(this.selectedRoleId === role.id ? $r('sys.color.comp_background_secondary') :
        this.hoveredRoleId === role.id ? $r('sys.color.comp_background_secondary') : Color.Transparent)
      .onHover((hover: boolean) => this.hoveredRoleId = hover ? role.id : 0)
      .onClick(() => this.selectedRoleId = role.id)
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 18 }) {
        this.roleToolbar()
        if (this.error.length > 0) Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
        Row() {
          Text('角色编号').width(86).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
          Text('角色名称').width(150).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
          Text('权限字符').width(170).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
          Text('权限范围').width(290).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
          Text('状态').width(72).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
          Text('创建时间').width(160).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
          Text('操作').width(150).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
        }.constraintSize({ minWidth: 1120 }).width('100%').height(42).padding({ left: 12, right: 12 }).backgroundColor($r('sys.color.comp_background_secondary'))
        if (this.loading) {
          LoadingProgress().width(32).height(32)
        } else if (this.roles.length === 0) {
          Text('暂无角色数据').fontSize(13).fontColor($r('sys.color.font_tertiary')).padding({ top: 48, bottom: 48 })
        } else {
          ForEach(this.roles, (role: RoleRecord, index: number) => this.roleRow(role, index), (role: RoleRecord) => `role-${role.id}`)
        }
        Text(`共 ${this.roles.length} 个角色`).fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%')
          .textAlign(TextAlign.End)
      }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
        top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
  }
}
