import ApiClient from '../../network/ApiClient';

interface UserRole { code: string; name: string; }
interface UserRecord { id: number; username: string; real_name: string; phone: string; status: number; created_at?: string; roles?: UserRole[]; }
interface UserPage { list: UserRecord[]; total: number; }
interface CreateUserRequest { username: string; password: string; real_name: string; phone: string; role_code: string; role_codes?: string[]; }
interface RolePage { list: UserRole[]; }
interface UserStatusRequest { status: number; }

@ComponentV2
export struct WideUserManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Local users: UserRecord[] = [];
  @Local keyword: string = '';
  @Local statusFilter: string = '';
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local showCreate: boolean = false;
  @Local username: string = '';
  @Local password: string = '';
  @Local realName: string = '';
  @Local phone: string = '';
  @Local roleCode: string = 'caregiver';
  @Local selectedRoleCodes: string[] = ['caregiver'];
  @Local availableRoles: UserRole[] = [];
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.loadUsers(); this.loadRoles(); }

  private async loadRoles(): Promise<void> {
    try {
      const response = await ApiClient.get<RolePage>('/roles?page=1&size=100');
      if (response.code === 0 && response.data !== undefined) { this.availableRoles = response.data.list ?? []; }
    } catch (_error) { /* the user list remains usable even if role metadata is unavailable */ }
  }

  private toggleRole(code: string): void {
    const next: string[] = this.selectedRoleCodes.indexOf(code) >= 0 ? this.selectedRoleCodes.filter((item: string) => item !== code) : this.selectedRoleCodes.concat([code]);
    if (next.length > 0) { this.selectedRoleCodes = next; this.roleCode = next[0]; }
  }

  private async loadUsers(): Promise<void> {
    this.loading = true; this.error = '';
    try {
      const response = await ApiClient.get<UserPage>(`/users?keyword=${encodeURIComponent(this.keyword.trim())}&status=${this.statusFilter}&page=1&size=100`);
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.users = response.data.list ?? [];
    } catch (_error) { this.error = '用户数据加载失败'; }
    this.loading = false;
  }

  private async createUser(): Promise<void> {
    const request: CreateUserRequest = { username: this.username.trim(), password: this.password,
      real_name: this.realName.trim(), phone: this.phone.trim(), role_code: this.roleCode, role_codes: this.selectedRoleCodes };
    if (!request.username || !request.password) { this.error = '用户名和密码不能为空'; return; }
    try {
      const response = await ApiClient.post<UserRecord>('/users', request);
      if (response.code !== 0) throw new Error(response.msg);
      this.showCreate = false; this.username = ''; this.password = ''; this.realName = ''; this.phone = ''; this.selectedRoleCodes = ['caregiver']; this.roleCode = 'caregiver'; await this.loadUsers();
    } catch (_error) { this.error = '创建用户失败'; }
  }

  private async toggleStatus(user: UserRecord): Promise<void> {
    try {
      const request: UserStatusRequest = { status: user.status === 1 ? 0 : 1 };
      const response = await ApiClient.patch<Object>(`/users/${user.id}/status`, request);
      if (response.code === 0) await this.loadUsers();
    } catch (_error) { this.error = '用户状态更新失败'; }
  }

  private formatTime(value?: string): string { return value === undefined || value.length < 16 ? '--' : value.slice(0, 19).replace('T', ' '); }

  @Builder
  private createDialog() {
    if (this.showCreate) {
      Column() {
        Text('新增用户').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        TextInput({ placeholder: '用户名', text: $$this.username }).width('100%').height(42).margin({ top: 18 })
        TextInput({ placeholder: '密码', text: $$this.password }).width('100%').height(42).margin({ top: 10 }).type(InputType.Password)
        TextInput({ placeholder: '姓名', text: $$this.realName }).width('100%').height(42).margin({ top: 10 })
        TextInput({ placeholder: '手机号', text: $$this.phone }).width('100%').height(42).margin({ top: 10 })
        Row({ space: 10 }) {
          ForEach(this.availableRoles, (role: UserRole) => {
            Button(role.name).height(34).fontSize(11).borderRadius(17).backgroundColor(this.selectedRoleCodes.indexOf(role.code) >= 0 ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).fontColor(this.selectedRoleCodes.indexOf(role.code) >= 0 ? Color.White : $r('sys.color.font_secondary')).onClick(() => this.toggleRole(role.code))
          }, (role: UserRole) => role.code)
        }.width('100%').margin({ top: 12 })
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(40).onClick(() => this.showCreate = false)
          Button('保存').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.createUser())
        }.width('100%').margin({ top: 18 })
      }.width(this.compactWidth ? '90%' : 460).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
    }
  }

  build() {
    Stack() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Row({ space: 22 }) {
            TextInput({ placeholder: '请输入用户名/姓名/手机号', text: $$this.keyword }).width(this.compactWidth ? 220 : 300).height(38).borderRadius(6)
            Text('状态').fontSize(12).fontColor($r('sys.color.font_secondary'))
            Text(this.statusFilter === '1' ? '正常' : this.statusFilter === '0' ? '停用' : '用户状态').width(110).height(38).padding(10).borderRadius(6).border({ width: 0.5, color: $r('sys.color.comp_divider') }).onClick(() => this.statusFilter = this.statusFilter === '' ? '1' : this.statusFilter === '1' ? '0' : '')
            Button('搜索').height(38).fontSize(13).borderRadius(6).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.loadUsers())
            Button('重置').height(38).fontSize(13).borderRadius(6).onClick(() => { this.keyword = ''; this.statusFilter = ''; this.loadUsers(); })
          }.width('100%')
          Row({ space: 10 }) {
            Button('新增').height(36).fontSize(12).borderRadius(6).fontColor($r('app.color.brand_blue')).onClick(() => this.showCreate = true)
            Button('修改').height(36).fontSize(12).borderRadius(6).enabled(false)
            Button('删除').height(36).fontSize(12).borderRadius(6).enabled(false)
            Button('导入').height(36).fontSize(12).borderRadius(6).enabled(false)
            Button('导出').height(36).fontSize(12).borderRadius(6).enabled(false)
          }.width('100%')
          Row() {
            Text('用户编号').width(100).fontSize(12).fontWeight(FontWeight.Medium)
            Text('用户名称').width(160).fontSize(12).fontWeight(FontWeight.Medium)
            Text('用户昵称').width(150).fontSize(12).fontWeight(FontWeight.Medium)
            Text('角色').width(120).fontSize(12).fontWeight(FontWeight.Medium)
            Text('手机号').width(170).fontSize(12).fontWeight(FontWeight.Medium)
            Text('状态').width(100).fontSize(12).fontWeight(FontWeight.Medium).textAlign(TextAlign.Center)
            Text('创建时间').width(190).fontSize(12).fontWeight(FontWeight.Medium)
          }.constraintSize({ minWidth: 990 }).width('100%').height(42).padding({ left: 18, right: 18 }).backgroundColor($r('sys.color.comp_background_secondary'))
          if (this.loading) { LoadingProgress().width(32).height(32) }
          ForEach(this.users, (user: UserRecord) => {
            Row() {
              Text(user.id.toString()).width(100).fontSize(13)
              Text(user.username).width(160).fontSize(13)
              Text(user.real_name || '--').width(150).fontSize(13)
              Text(user.roles?.map((role: UserRole) => role.name).join('、') || '--').width(120).fontSize(13)
              Text(user.phone || '--').width(170).fontSize(13)
              Button(user.status === 1 ? '正常' : '停用').width(62).height(28).fontSize(11).borderRadius(14).fontColor(Color.White).backgroundColor(user.status === 1 ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary')).onClick(() => this.toggleStatus(user))
              Text(this.formatTime(user.created_at)).width(190).fontSize(12)
            }.constraintSize({ minWidth: 990 }).width('100%').height(54).padding({ left: 18, right: 18 }).border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
          }, (user: UserRecord) => `user-${user.id}`)
          Text(`共 ${this.users.length} 条`).fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%').textAlign(TextAlign.End)
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
      }.width('100%').height('100%')
      if (this.showCreate) {
        Row() { this.createDialog() }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
