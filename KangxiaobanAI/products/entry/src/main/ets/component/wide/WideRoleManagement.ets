import { HdsSnackBar } from '@kit.UIDesignKit';
import { AppStorageV2, LengthMetrics } from '@kit.ArkUI';
import ApiClient from '../../network/ApiClient';
import { GlobalInfoModel } from '../../model/GlobalInfoModel';
import { StorageKey } from '../../common/CommonConstants';

interface RolePermission { code: string; name: string; }
interface RoleRecord {
  id: number; code: string; name: string; description: string; created_at?: string;
  display_order?: number; status?: number; remark?: string; permissions?: RolePermission[];
}
interface RolePage { list: RoleRecord[]; total: number; }
interface UserRoleRef { code: string; name: string; }
interface CountableUser { roles?: UserRoleRef[]; }
interface UserPage { list: CountableUser[]; total: number; }
interface RoleSaveRequest { name: string; code: string; remark: string; permission_codes: string[]; status: number; }
interface PermissionGroup { title: string; items: RolePermission[]; }
interface PermissionPage { list: RolePermission[]; }

const ACTION_BUTTON_BG: string = '#1D63ED';
const GROUP_TITLES: string[] = ['长者与健康', '照护任务', '告警处置', '系统管理', '其他权限'];

function groupTitleOf(code: string): string {
  if (code.startsWith('elder:') || code.startsWith('health:') || code.startsWith('admission:')) { return '长者与健康'; }
  if (code.startsWith('task:') || code.startsWith('care:') || code.startsWith('plan:')) { return '照护任务'; }
  if (code.startsWith('alert:')) { return '告警处置'; }
  if (code.startsWith('dash:') || code.startsWith('admin:')) { return '系统管理'; }
  return '其他权限';
}

@ComponentV2
export struct WideRoleManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local roles: RoleRecord[] = [];
  @Local userCounts: Record<string, number> = {};
  @Local allPermissions: RolePermission[] = [];
  @Local selectedPermissionCodes: string[] = [];
  @Local selectedRoleId: number = 0;
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local showDialog: boolean = false;
  @Local editingRoleId: number = 0;
  @Local roleName: string = '';
  @Local roleCode: string = '';
  @Local roleRemark: string = '';
  @Local editStatusOn: boolean = true;
  @Local globalInfo: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel()) ?? new GlobalInfoModel();

  aboutToAppear(): void { this.loadRoles(); this.loadUserCounts(); this.loadPermissions(); }

  private selectedRole(): RoleRecord | undefined {
    return this.roles.find((role: RoleRecord) => role.id === this.selectedRoleId);
  }

  private selectedPermissionCount(): number {
    const role: RoleRecord | undefined = this.selectedRole();
    return role === undefined ? 0 : this.permissionCountOf(role);
  }

  private selectedUserCountValue(): number {
    const role: RoleRecord | undefined = this.selectedRole();
    return role === undefined ? 0 : this.userCount(role);
  }

  private selectedPermissionGroups(): PermissionGroup[] {
    const role: RoleRecord | undefined = this.selectedRole();
    return role === undefined ? [] : this.permissionGroups(role);
  }

  /** 两张卡片的稳定高度：视口减去页边距与页脚，加载前后不跳变。 */
  private roleCardMinHeight(): number {
    const viewport: number = this.globalInfo.deviceHeight > 0 ? this.globalInfo.deviceHeight : 800;
    return Math.max(480, viewport - (88 + this.statusBarHeight) - (24 + this.naviIndicatorHeight) - 44);
  }

  private async loadRoles(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const response = await ApiClient.get<RolePage>('/roles?page=1&size=50');
      if (response.code !== 0 || response.data === undefined) { throw new Error(response.msg); }
      this.roles = response.data.list ?? [];
      if (!this.roles.some((role: RoleRecord) => role.id === this.selectedRoleId)) {
        this.selectedRoleId = this.roles.length > 0 ? this.roles[0].id : 0;
      }
    } catch (_error) { this.error = '角色数据加载失败，请稍后重试'; }
    this.loading = false;
  }

  private async loadUserCounts(): Promise<void> {
    try {
      const response = await ApiClient.get<UserPage>('/users?page=1&size=200');
      if (response.code !== 0 || response.data === undefined) { return; }
      const counts: Record<string, number> = {};
      (response.data.list ?? []).forEach((user: CountableUser) => {
        (user.roles ?? []).forEach((role: UserRoleRef) => {
          counts[role.code] = (counts[role.code] ?? 0) + 1;
        });
      });
      this.userCounts = counts;
    } catch (_error) { /* user counts are supplementary; the role list stays usable without them */ }
  }

  private userCount(role: RoleRecord): number {
    return this.userCounts[role.code] ?? 0;
  }

  private permissionGroups(role: RoleRecord): PermissionGroup[] {
    return this.buildGroups(role.permissions ?? []);
  }

  private allPermissionGroups(): PermissionGroup[] {
    return this.buildGroups(this.allPermissions);
  }

  private buildGroups(permissions: RolePermission[]): PermissionGroup[] {
    const grouped: Record<string, RolePermission[]> = {};
    permissions.forEach((permission: RolePermission) => {
      const title: string = groupTitleOf(permission.code);
      const bucket: RolePermission[] = grouped[title] ?? [];
      bucket.push(permission);
      grouped[title] = bucket;
    });
    const groups: PermissionGroup[] = [];
    GROUP_TITLES.forEach((title: string) => {
      const items: RolePermission[] = grouped[title];
      if (items !== undefined && items.length > 0) { groups.push({ title: title, items: items }); }
    });
    return groups;
  }

  private isPermissionSelected(code: string): boolean {
    return this.selectedPermissionCodes.indexOf(code) >= 0;
  }

  private togglePermission(code: string): void {
    if (this.isPermissionSelected(code)) {
      this.selectedPermissionCodes = this.selectedPermissionCodes.filter((item: string) => item !== code);
    } else {
      this.selectedPermissionCodes = this.selectedPermissionCodes.concat([code]);
    }
  }

  private async loadPermissions(): Promise<void> {
    try {
      const response = await ApiClient.get<PermissionPage>('/permissions');
      if (response.code !== 0 || response.data === undefined) { return; }
      this.allPermissions = response.data.list ?? [];
    } catch (_error) { /* the dialog stays usable; permissions simply cannot be changed without the catalog */ }
  }

  private openCreate(): void {
    this.editingRoleId = 0;
    this.roleName = '';
    this.roleCode = '';
    this.roleRemark = '';
    this.selectedPermissionCodes = [];
    this.editStatusOn = true;
    this.showDialog = true;
  }

  private openEdit(role: RoleRecord): void {
    this.editingRoleId = role.id;
    this.roleName = role.name;
    this.roleCode = role.code;
    this.roleRemark = role.remark ?? '';
    this.selectedPermissionCodes = (role.permissions ?? []).map((item: RolePermission) => item.code);
    this.editStatusOn = role.status !== 0;
    this.showDialog = true;
  }

  private async saveRole(): Promise<void> {
    if (this.roleName.trim() === '' || this.roleCode.trim() === '') { this.error = '角色名称和角色编码不能为空'; return; }
    const request: RoleSaveRequest = {
      name: this.roleName.trim(), code: this.roleCode.trim(), remark: this.roleRemark.trim(),
      permission_codes: this.selectedPermissionCodes.slice(), status: this.editStatusOn ? 1 : 0
    };
    try {
      const response = this.editingRoleId > 0
        ? await ApiClient.put<RoleRecord>(`/roles/${this.editingRoleId}`, request)
        : await ApiClient.post<RoleRecord>('/roles', request);
      if (response.code !== 0) { this.error = response.msg || '角色保存失败'; return; }
      this.showDialog = false;
      this.selectedRoleId = this.editingRoleId > 0 ? this.editingRoleId : (response.data?.id ?? 0);
      await this.loadRoles();
      await this.loadUserCounts();
      this.error = '';
      this.showSavedSnackBar();
    } catch (_error) { this.error = '角色保存失败，请稍后重试'; }
  }

  private showSavedSnackBar(): void {
    try {
      new HdsSnackBar(this.getUIContext()).show({}, { title: '角色已保存' }, {});
    } catch (_error) { /* snackbar is non-critical feedback */ }
  }

  @Builder
  private roleListHeader() {
    Row() {
      Text('角色列表').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Blank()
      Button('新增角色').height(34).fontSize(14).borderRadius(8)
        .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
        .padding({ left: 16, right: 16 })
        .onClick(() => this.openCreate())
    }.width('100%').height(52).padding({ left: 18, right: 18 })
      .alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }

  @Builder
  private cardHeader(title: string) {
    Row() {
      Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
    }.width('100%').height(52).padding({ left: 18, right: 18 })
      .alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }

  @Builder
  private listStat(count: number, label: string) {
    Column({ space: 5 }) {
      Text(count.toString()).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text(label).fontSize(13).fontColor($r('sys.color.font_secondary'))
    }.alignItems(HorizontalAlign.Center).width(62)
  }

  @Builder
  private roleRowSuffix(role: RoleRecord) {
    Row({ space: 16 }) {
      this.listStat(this.permissionCountOf(role), '权限数')
      this.listStat(this.userCount(role), '用户数')
      Text('编辑').fontSize(15).fontColor($r('sys.color.font_primary'))
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .onClick(() => { this.selectedRoleId = role.id; this.openEdit(role); })
    }
  }

  @Builder
  private roleRow(role: RoleRecord, isLast: boolean) {
    Column() {
      Row({ space: 14 }) {
        Column().width(3).height(52)
          .borderRadius(2)
          .backgroundColor(this.selectedRoleId === role.id ? ACTION_BUTTON_BG : Color.Transparent)
        Column({ space: 5 }) {
          Text(role.name || '--').fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(role.description || '暂无描述').fontSize(14).fontColor($r('sys.color.font_secondary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        this.roleRowSuffix(role)
      }.width('100%').height(96).padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center)
        .hoverEffect(HoverEffect.None)
        .backgroundColor(this.selectedRoleId === role.id ? $r('sys.color.comp_background_secondary') : Color.Transparent)
        .onClick(() => { this.selectedRoleId = role.id; })
      if (!isLast) {
        Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 18, right: 18 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  private permissionCountOf(role: RoleRecord): number {
    return role.permissions?.length ?? 0;
  }

  @Builder
  private roleListCard() {
    Column() {
      this.roleListHeader()
      if (this.loading) {
        Column() {
          ForEach([1, 2, 3], (_: number) => {
            Row({ space: 14 }) {
              Row().width(3).height(52).borderRadius(2)
                .backgroundColor($r('sys.color.comp_background_tertiary'))
              Column({ space: 8 }) {
                Row().height(14).width('40%').borderRadius(7)
                  .backgroundColor($r('sys.color.comp_background_tertiary'))
                Row().height(12).width('62%').borderRadius(6)
                  .backgroundColor($r('sys.color.comp_background_tertiary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.width('100%').height(96).padding({ left: 18, right: 18 })
              .alignItems(VerticalAlign.Center)
          }, (item: number) => `role-skeleton-${item}`)
        }.width('100%')
      } else if (this.roles.length === 0) {
        Column() {
          Text(this.error.length > 0 ? this.error : '暂无角色数据').fontSize(14).fontColor($r('sys.color.font_tertiary'))
        }.width('100%').padding({ top: 44, bottom: 44 })
      } else {
        Repeat(this.roles)
          .each((ri: RepeatItem<RoleRecord>) => {
            this.roleRow(ri.item, ri.index === this.roles.length - 1)
          })
          .key((role: RoleRecord) => `role-${role.id}`)
      }
    }.width('100%').backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.compactWidth ? 0 : this.roleCardMinHeight() })
  }

  @Builder
  private detailStat(count: number, label: string) {
    Column({ space: 6 }) {
      Text(count.toString()).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text(label).fontSize(13).fontColor($r('sys.color.font_secondary'))
    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  }

  @Builder
  private permissionChip(label: string) {
    Text(label).fontSize(14).fontColor($r('sys.color.font_primary'))
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(6)
  }

  @Builder
  private permissionGroupBlock(group: PermissionGroup) {
    Column({ space: 10 }) {
      Text(group.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach(group.items, (item: RolePermission) => {
          this.permissionChip(item.name || item.code)
        }, (item: RolePermission) => `${group.title}-${item.code}`)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private roleDetailContent() {
    if (this.selectedRole() === undefined) {
      Column() {
        Text('请选择左侧角色查看详情').fontSize(14).fontColor($r('sys.color.font_tertiary'))
      }.width('100%').padding({ top: 44, bottom: 44 })
    } else {
      Column({ space: 14 }) {
        Text(this.selectedRole()?.name ?? '--').fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(this.selectedRole()?.description ?? '暂无描述').fontSize(14).fontColor($r('sys.color.font_secondary'))
        Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
        Row() {
          this.detailStat(this.selectedPermissionCount(), '权限数量')
          this.detailStat(this.selectedUserCountValue(), '用户数量')
        }.width('100%')
        ForEach(this.selectedPermissionGroups(), (group: PermissionGroup) => {
          this.permissionGroupBlock(group)
        }, (group: PermissionGroup) => `group-${group.title}-${group.items.map((item: RolePermission): string => item.code).join(',')}`)
      }.width('100%').padding(18).alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private roleDetailCard() {
    Column() {
      this.cardHeader('角色详情')
      this.roleDetailContent()
    }.width('100%').backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.compactWidth ? 0 : this.roleCardMinHeight() })
  }

  @Builder
  private saveDialog() {
    Column({ space: 12 }) {
      Text(this.editingRoleId > 0 ? '编辑角色' : '新增角色').fontSize(20).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      TextInput({ placeholder: '角色名称，例如护理组长', text: $$this.roleName }).height(42)
      TextInput({ placeholder: '角色编码，例如 head_nurse', text: $$this.roleCode }).height(42)
      Column({ space: 10 }) {
        Text('权限选择').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        Scroll() {
          Column({ space: 12 }) {
            Repeat(this.allPermissionGroups())
              .each((ri: RepeatItem<PermissionGroup>) => {
                Column({ space: 8 }) {
                  Text(ri.item.title).fontSize(13).fontColor($r('sys.color.font_secondary'))
                  Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
                    Repeat(ri.item.items)
                      .each((chip: RepeatItem<RolePermission>) => {
                        Text(chip.item.name || chip.item.code)
                          .fontSize(14)
                          .fontColor(this.isPermissionSelected(chip.item.code) ? Color.White : $r('sys.color.font_primary'))
                          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                          .borderRadius(6)
                          .backgroundColor(this.isPermissionSelected(chip.item.code) ?
                            $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
                          .onClick(() => this.togglePermission(chip.item.code))
                      })
                      .key((item: RolePermission) => `pick-${item.code}`)
                  }.width('100%')
                }.width('100%').alignItems(HorizontalAlign.Start)
              })
              .key((group: PermissionGroup) => `pick-group-${group.title}`)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').constraintSize({ maxHeight: 300 })
          .scrollBar(BarState.Off).align(Alignment.TopStart)
      }.width('100%').alignItems(HorizontalAlign.Start)
      TextArea({ placeholder: '备注，可选', text: $$this.roleRemark }).height(76)
      Row({ space: 10 }) {
        Text('状态').fontSize(15).fontColor($r('sys.color.font_primary'))
        Toggle({ type: ToggleType.Switch, isOn: $$this.editStatusOn })
        Text(this.editStatusOn ? '正常' : '停用').fontSize(14).fontColor($r('sys.color.font_secondary'))
      }.width('100%')
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40).fontSize(15)
          .fontColor($r('sys.color.font_secondary'))
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.showDialog = false)
        Button('保存').layoutWeight(1).height(40).fontSize(15)
          .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
          .onClick(() => this.saveRole())
      }.width('100%')
    }.width(this.compactWidth ? '90%' : 460).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column({ space: 16 }) {
          if (this.error.length > 0) {
            Text(this.error).fontSize(13).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
          }
          GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
            GridCol({ span: this.compactWidth ? 12 : 8 }) {
              this.roleListCard()
            }
            GridCol({ span: this.compactWidth ? 12 : 4 }) {
              this.roleDetailCard()
            }
          }.width('100%')
          Text(`共 ${this.roles.length} 个角色`).fontSize(12).fontColor($r('sys.color.font_tertiary')).width('100%')
            .textAlign(TextAlign.End)
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
          top: 88 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
          .constraintSize({ minHeight: '100%', maxWidth: 1280 })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
      if (this.showDialog) {
        Row() { this.saveDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
