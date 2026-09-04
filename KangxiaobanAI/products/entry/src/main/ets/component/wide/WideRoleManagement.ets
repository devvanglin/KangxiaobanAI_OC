import ApiClient from '../../network/ApiClient';

interface RolePermission { code: string; name: string; }
interface RoleRecord {
  id: number; code: string; name: string; description: string; created_at?: string;
  display_order?: number; status?: number; permissions?: RolePermission[];
}
interface RolePage { list: RoleRecord[]; total: number; }
interface RoleStatusRequest { status: number; }
interface RoleCreateRequest { name: string; code: string; remark: string; permission_codes: string[]; status: number; }

@ComponentV2
export struct WideRoleManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Local roles: RoleRecord[] = [];
  @Local keyword: string = '';
  @Local permissionKeyword: string = '';
  @Local statusFilter: string = '';
  @Local createdStart: string = '';
  @Local createdEnd: string = '';
  @Local selectedRoleId: number = 0;
  @Local hoveredRoleId: number = 0;
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local showCreate: boolean = false;
  @Local roleName: string = '';
  @Local roleCode: string = '';
  @Local roleRemark: string = '';
  @Local permissionCodes: string = 'elder:read,task:read';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.loadRoles(); }

  private async loadRoles(): Promise<void> {
    this.loading = true; this.error = '';
    try {
      const params: string = `/roles?keyword=${encodeURIComponent(this.keyword.trim())}&status=${encodeURIComponent(this.statusFilter)}&page=1&size=50`;
      const response = await ApiClient.get<RolePage>(params);
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.roles = response.data.list ?? [];
    } catch (_error) { this.error = '角色数据加载失败'; }
    this.loading = false;
  }

  private async toggleStatus(role: RoleRecord): Promise<void> {
    const request: RoleStatusRequest = { status: role.status === 1 ? 0 : 1 };
    try {
      const response = await ApiClient.patch<Object>(`/roles/${role.id}/status`, request);
      if (response.code === 0) await this.loadRoles();
    } catch (_error) { this.error = '角色状态更新失败'; }
  }

  private async createRole(): Promise<void> {
    if (this.roleName.trim() === '' || this.roleCode.trim() === '') { this.error = '角色名称和权限字符不能为空'; return; }
    const codes: string[] = this.permissionCodes.split(',').map((item: string) => item.trim()).filter((item: string) => item.length > 0);
    const request: RoleCreateRequest = { name: this.roleName.trim(), code: this.roleCode.trim(), remark: this.roleRemark.trim(), permission_codes: codes, status: 1 };
    const response = await ApiClient.post<RoleRecord>('/roles', request);
    if (response.code !== 0) { this.error = response.msg || '角色创建失败'; return; }
    this.showCreate = false; this.roleName = ''; this.roleCode = ''; this.roleRemark = ''; await this.loadRoles();
  }

  private hint(action: string): void {
    try { this.getUIContext().getPromptAction().showToast({ message: `${action}功能即将开放` }); } catch (_error) {}
  }

  private formatCreatedAt(value?: string): string {
    if (value === undefined || value.length < 16) return '--';
    return value.slice(0, 19).replace('T', ' ');
  }

  @Builder
  private filterInput(label: string, placeholder: string, value: string, onChange: (value: string) => void, width: number) {
    Row({ space: 8 }) {
      Text(label).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
      TextInput({ placeholder: placeholder, text: value })
        .width(width).height(38).fontSize(13).borderRadius(6)
        .onChange((text: string) => onChange(text))
    }.alignItems(VerticalAlign.Center)
  }

  @Builder
  private roleToolbar() {
    Column({ space: 14 }) {
      Row({ space: 22 }) {
        this.filterInput('角色名称', '请输入角色名称', this.keyword, (value: string) => this.keyword = value, this.compactWidth ? 190 : 230)
        this.filterInput('权限字符', '请输入权限字符', this.permissionKeyword, (value: string) => this.permissionKeyword = value, this.compactWidth ? 190 : 230)
        Row({ space: 8 }) {
          Text('状态').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
          Text(this.statusFilter === '0' ? '停用' : this.statusFilter === '1' ? '正常' : '角色状态')
            .width(120).height(38).padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .fontSize(13).fontColor($r('sys.color.font_secondary')).borderRadius(6)
            .border({ width: 0.5, color: $r('sys.color.comp_divider') })
            .onClick(() => this.statusFilter = this.statusFilter === '' ? '1' : this.statusFilter === '1' ? '0' : '')
        }
        Row({ space: 8 }) {
          Text('创建时间').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
          TextInput({ placeholder: '开始日期', text: $$this.createdStart }).width(110).height(38).fontSize(12).borderRadius(6)
          Text('-').fontSize(12).fontColor($r('sys.color.font_secondary'))
          TextInput({ placeholder: '结束日期', text: $$this.createdEnd }).width(110).height(38).fontSize(12).borderRadius(6)
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 10 }) {
        Button('搜索').height(38).fontSize(13).borderRadius(6)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.loadRoles())
        Button('重置').height(38).fontSize(13).borderRadius(6)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.keyword = ''; this.permissionKeyword = ''; this.statusFilter = ''; this.createdStart = ''; this.createdEnd = ''; this.loadRoles(); })
      }.width('100%')
      Row({ space: 10 }) {
        Button('新增').height(36).fontSize(12).borderRadius(6).fontColor($r('app.color.brand_blue'))
          .backgroundColor($r('sys.color.comp_background_secondary')).onClick(() => this.showCreate = true)
        Button('修改').height(36).fontSize(12).borderRadius(6).enabled(this.selectedRoleId > 0).onClick(() => this.hint('修改角色'))
        Button('删除').height(36).fontSize(12).borderRadius(6).enabled(this.selectedRoleId > 0).onClick(() => this.hint('删除角色'))
        Button('导出').height(36).fontSize(12).borderRadius(6).fontColor($r('sys.color.font_secondary'))
          .backgroundColor($r('sys.color.comp_background_secondary')).onClick(() => this.hint('导出角色'))
      }.width('100%')
    }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(14)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') }).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private tableHeader() {
    Row() {
      Text('角色编号').width(100).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
      Text('角色名称').width(160).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
      Text('权限字符').width(190).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
      Text('显示顺序').width(130).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
      Text('状态').width(110).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      Text('创建时间').width(190).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
      Text('操作').width(220).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
    }.constraintSize({ minWidth: 1100 }).width('100%').height(42).padding({ left: 18, right: 18 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
  }

  @Builder
  private roleRow(role: RoleRecord) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.key_shield_badge_person_crop_circle_fill')).fontSize(22).fontColor([$r('app.color.brand_blue')])
        }.width(42).height(42).justifyContent(FlexAlign.Center).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(12)
        Column({ space: 4 }) {
          Text(role.name || '--').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Text(role.code || '--').fontSize(11).fontColor($r('sys.color.font_secondary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(role.status === 1 ? '正常' : '停用').height(28).fontSize(11).borderRadius(14)
          .fontColor(Color.White).backgroundColor(role.status === 1 ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
          .onClick(() => this.toggleStatus(role))
      }.width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 12 }) {
        Column({ space: 4 }) { Text('角色编号').fontSize(11).fontColor($r('sys.color.font_tertiary')); Text(role.id.toString()).fontSize(13) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 4 }) { Text('显示顺序').fontSize(11).fontColor($r('sys.color.font_tertiary')); Text((role.display_order ?? 0).toString()).fontSize(13) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 4 }) { Text('创建时间').fontSize(11).fontColor($r('sys.color.font_tertiary')); Text(this.formatCreatedAt(role.created_at)).fontSize(12) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Row({ space: 18 }) {
        Text('编辑').fontSize(12).fontColor($r('app.color.brand_blue')).onClick(() => this.hint('编辑角色'))
        Text('分配数据权限').fontSize(12).fontColor($r('app.color.brand_blue')).onClick(() => this.hint('分配数据权限'))
      }.width('100%').justifyContent(FlexAlign.End)
    }.width('100%').padding(16)
      .backgroundColor(this.hoveredRoleId === role.id || this.selectedRoleId === role.id ? $r('sys.color.comp_background_secondary') : $r('sys.color.comp_background_primary'))
      .borderRadius(14).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .onHover((hover: boolean) => this.hoveredRoleId = hover ? role.id : 0)
      .onClick(() => this.selectedRoleId = role.id)
  }

  @Builder
  private createDialog() {
    if (this.showCreate) {
      Column({ space: 12 }) {
        Text('新增角色').fontSize(20).fontWeight(FontWeight.Medium)
        TextInput({ placeholder: '角色名称，例如护士长', text: $$this.roleName }).height(42)
        TextInput({ placeholder: '权限字符，例如 head_nurse', text: $$this.roleCode }).height(42)
        TextInput({ placeholder: '权限字符，逗号分隔', text: $$this.permissionCodes }).height(42)
        TextArea({ placeholder: '备注，可选', text: $$this.roleRemark }).height(80)
        Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => this.showCreate = false); Button('保存').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.createRole()) }.width('100%')
      }.width(this.compactWidth ? '90%' : 460).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
    }
  }

  build() {
    Stack() {
      Scroll(this.scroller) {
      Column({ space: 18 }) {
        this.roleToolbar()
        if (this.error.length > 0) Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
        if (this.loading) {
          LoadingProgress().width(32).height(32)
        } else if (this.roles.length === 0) {
          Text('暂无角色数据').fontSize(13).fontColor($r('sys.color.font_tertiary')).padding({ top: 48, bottom: 48 })
        } else {
          GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
            ForEach(this.roles, (role: RoleRecord) => {
              GridCol({ span: this.compactWidth ? 12 : 6 }) { this.roleRow(role) }
            }, (role: RoleRecord) => `role-${role.id}`)
          }.width('100%')
        }
        Text(`共 ${this.roles.length} 条`).fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%').textAlign(TextAlign.End)
      }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
        top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight }).alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      if (this.showCreate) Row() { this.createDialog() }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%')
  }
}
