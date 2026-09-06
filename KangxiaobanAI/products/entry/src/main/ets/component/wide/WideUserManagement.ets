import { LengthMetrics } from '@kit.ArkUI';
import ApiClient from '../../network/ApiClient';

interface UserRole { code: string; name: string; }
interface UserRecord { id: number; username: string; real_name: string; phone: string; status: number; created_at?: string; roles?: UserRole[]; }
interface UserPage { list: UserRecord[]; total: number; }
interface CreateUserRequest { username: string; password: string; real_name: string; phone: string; role_code: string; role_codes?: string[]; }
interface RolePage { list: UserRole[]; }
interface UserStatusRequest { status: number; }

const ACTION_BUTTON_BG: string = '#1D63ED';

@ComponentV2
export struct WideUserManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local users: UserRecord[] = [];
  @Local keyword: string = '';
  @Local statusFilter: string = '';
  @Local selectedUserId: number = 0;
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
    this.loading = true;
    this.error = '';
    try {
      const response = await ApiClient.get<UserPage>(`/users?keyword=${encodeURIComponent(this.keyword.trim())}&status=${this.statusFilter}&page=1&size=100`);
      if (response.code !== 0 || response.data === undefined) { throw new Error(response.msg); }
      this.users = response.data.list ?? [];
      if (!this.users.some((user: UserRecord) => user.id === this.selectedUserId)) {
        this.selectedUserId = 0;
      }
    } catch (_error) { this.error = '用户数据加载失败'; }
    this.loading = false;
  }

  private async createUser(): Promise<void> {
    const request: CreateUserRequest = { username: this.username.trim(), password: this.password,
      real_name: this.realName.trim(), phone: this.phone.trim(), role_code: this.roleCode, role_codes: this.selectedRoleCodes };
    if (!request.username || !request.password) { this.error = '用户名和密码不能为空'; return; }
    try {
      const response = await ApiClient.post<UserRecord>('/users', request);
      if (response.code !== 0) { throw new Error(response.msg); }
      this.showCreate = false;
      this.username = '';
      this.password = '';
      this.realName = '';
      this.phone = '';
      this.selectedRoleCodes = ['caregiver'];
      this.roleCode = 'caregiver';
      await this.loadUsers();
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
  private toolbarCard() {
    Row({ space: 14 }) {
      TextInput({ placeholder: '请输入用户名/姓名/手机号', text: $$this.keyword })
        .width(this.compactWidth ? 200 : 300).height(38).borderRadius(6)
      Text('状态').fontSize(12).fontColor($r('sys.color.font_secondary'))
      Text(this.statusFilter === '1' ? '正常' : this.statusFilter === '0' ? '停用' : '用户状态')
        .width(110).height(38).padding(10).borderRadius(6)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        .onClick(() => this.statusFilter = this.statusFilter === '' ? '1' : this.statusFilter === '1' ? '0' : '')
      Button('搜索').height(38).fontSize(13).borderRadius(6)
        .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
        .onClick(() => this.loadUsers())
      Button('重置').height(38).fontSize(13).borderRadius(6)
        .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
        .onClick(() => { this.keyword = ''; this.statusFilter = ''; this.loadUsers(); })
      Blank().layoutWeight(1)
      Button('新增').height(36).fontSize(12).borderRadius(6)
        .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
        .onClick(() => this.showCreate = true)
      Button('修改').height(36).fontSize(12).borderRadius(6).enabled(false)
      Button('删除').height(36).fontSize(12).borderRadius(6).enabled(false)
      Button('导入').height(36).fontSize(12).borderRadius(6).enabled(false)
      Button('导出').height(36).fontSize(12).borderRadius(6).enabled(false)
    }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(VerticalAlign.Center)
  }

  @Builder
  private tableHeaderRow() {
    Row({ space: 10 }) {
      Text('用户').fontSize(12).fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1.4)
      Text('角色').fontSize(12).fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
      Text('手机号').fontSize(12).fontColor($r('sys.color.font_secondary'))
        .width(this.compactWidth ? 100 : 130)
      Text('状态').fontSize(12).fontColor($r('sys.color.font_secondary'))
        .width(this.compactWidth ? 70 : 90)
      Text('创建时间').fontSize(12).fontColor($r('sys.color.font_secondary'))
        .width(this.compactWidth ? 130 : 170)
      Text('操作').fontSize(12).fontColor($r('sys.color.font_secondary'))
        .width(this.compactWidth ? 110 : 130).textAlign(TextAlign.End)
    }.width('100%').height(44).padding({ left: 18, right: 18 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .alignItems(VerticalAlign.Center)
  }

  @Builder
  private statusPill(user: UserRecord) {
    Button(user.status === 1 ? '正常' : '停用').height(26).fontSize(11).borderRadius(13)
      .fontColor(Color.White)
      .backgroundColor(user.status === 1 ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
      .onClick(() => this.toggleStatus(user))
  }

  @Builder
  private userRow(user: UserRecord, isLast: boolean) {
    Column() {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(user.real_name || user.username).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(user.username).fontSize(11).fontColor($r('sys.color.font_tertiary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1.4).alignItems(HorizontalAlign.Start)
        Text(user.roles?.map((role: UserRole) => role.name).join('、') || '--')
          .fontSize(13).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(user.phone || '--').fontSize(13).fontColor($r('sys.color.font_primary'))
          .width(this.compactWidth ? 100 : 130)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Column() {
          this.statusPill(user)
        }.width(this.compactWidth ? 70 : 90).alignItems(HorizontalAlign.Start)
        Text(this.formatTime(user.created_at)).fontSize(11).fontColor($r('sys.color.font_secondary'))
          .width(this.compactWidth ? 130 : 170)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 12 }) {
          Text('修改').fontSize(13).fontColor($r('sys.color.font_tertiary'))
          Text('角色分配').fontSize(13).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.error = '角色分配入口已准备，使用后端多角色接口')
        }.width(this.compactWidth ? 110 : 130).justifyContent(FlexAlign.End)
      }.width('100%').height(64).padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.selectedUserId === user.id ? $r('sys.color.comp_background_secondary') : Color.Transparent)
        .onClick(() => this.selectedUserId = user.id)
      if (!isLast) {
        Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 18, right: 18 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private userTableCard() {
    Column() {
      this.tableHeaderRow()
      if (this.loading) {
        Column() {
          LoadingProgress().width(30).height(30)
        }.width('100%').padding({ top: 44, bottom: 44 })
      } else if (this.users.length === 0) {
        Column() {
          Text(this.error.length > 0 ? this.error : '暂无用户数据').fontSize(13).fontColor($r('sys.color.font_tertiary'))
        }.width('100%').padding({ top: 44, bottom: 44 })
      } else {
        Repeat(this.users)
          .each((ri: RepeatItem<UserRecord>) => {
            this.userRow(ri.item, ri.index === this.users.length - 1)
          })
          .key((user: UserRecord) => `user-${user.id}`)
      }
      Row() {
        Blank()
        Text(`共 ${this.users.length} 条`).fontSize(11).fontColor($r('sys.color.font_tertiary'))
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 12 })
    }.width('100%').backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.compactWidth ? 0 : 420 })
  }

  @Builder
  private createDialog() {
    if (this.showCreate) {
      Column() {
        Text('新增用户').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        TextInput({ placeholder: '用户名', text: $$this.username }).width('100%').height(42).margin({ top: 18 })
        TextInput({ placeholder: '密码', text: $$this.password }).width('100%').height(42).margin({ top: 10 }).type(InputType.Password)
        TextInput({ placeholder: '姓名', text: $$this.realName }).width('100%').height(42).margin({ top: 10 })
        TextInput({ placeholder: '手机号', text: $$this.phone }).width('100%').height(42).margin({ top: 10 })
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.availableRoles, (role: UserRole) => {
            Button(role.name).height(34).fontSize(11).borderRadius(17)
              .backgroundColor(this.selectedRoleCodes.indexOf(role.code) >= 0 ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
              .fontColor(this.selectedRoleCodes.indexOf(role.code) >= 0 ? Color.White : $r('sys.color.font_secondary'))
              .onClick(() => this.toggleRole(role.code))
          }, (role: UserRole) => role.code)
        }.width('100%').margin({ top: 12 })
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(40)
            .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick(() => this.showCreate = false)
          Button('保存').layoutWeight(1).height(40)
            .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
            .onClick(() => this.createUser())
        }.width('100%').margin({ top: 18 })
      }.width(this.compactWidth ? '90%' : 460).padding(24)
        .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
    }
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column({ space: 16 }) {
          this.toolbarCard()
          if (this.error.length > 0 && this.users.length > 0) {
            Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
          }
          this.userTableCard()
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
          top: 88 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
          .constraintSize({ minHeight: '100%', maxWidth: 1280 })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
      if (this.showCreate) {
        Row() { this.createDialog() }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
