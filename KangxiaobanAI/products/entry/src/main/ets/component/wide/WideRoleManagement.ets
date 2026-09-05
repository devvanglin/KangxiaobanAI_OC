import { LengthMetrics } from '@kit.ArkUI';
import ApiClient from '../../network/ApiClient';

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

const ACTION_BUTTON_BG: string = '#1F1F1F';
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
  @Local roles: RoleRecord[] = [];
  @Local userCounts: Record<string, number> = {};
  @Local selectedRoleId: number = 0;
  @Local hoveredRoleId: number = 0;
  @Local cardMinHeight: number = 0;
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local showDialog: boolean = false;
  @Local editingRoleId: number = 0;
  @Local roleName: string = '';
  @Local roleCode: string = '';
  @Local roleRemark: string = '';
  @Local permissionCodes: string = '';
  @Local editStatusOn: boolean = true;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.loadRoles(); this.loadUserCounts(); }

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

  private selectedRoleList(): RoleRecord[] {
    const selected: RoleRecord | undefined = this.roles.find((role: RoleRecord) => role.id === this.selectedRoleId);
    return selected === undefined ? [] : [selected];
  }

  private userCount(role: RoleRecord): number {
    return this.userCounts[role.code] ?? 0;
  }

  private permissionGroups(role: RoleRecord): PermissionGroup[] {
    const grouped: Record<string, RolePermission[]> = {};
    (role.permissions ?? []).forEach((permission: RolePermission) => {
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

  private openCreate(): void {
    this.editingRoleId = 0;
    this.roleName = '';
    this.roleCode = '';
    this.roleRemark = '';
    this.permissionCodes = '';
    this.editStatusOn = true;
    this.showDialog = true;
  }

  private openEdit(role: RoleRecord): void {
    this.editingRoleId = role.id;
    this.roleName = role.name;
    this.roleCode = role.code;
    this.roleRemark = role.remark ?? '';
    this.permissionCodes = (role.permissions ?? []).map((item: RolePermission) => item.code).join(',');
    this.editStatusOn = role.status !== 0;
    this.showDialog = true;
  }

  private async saveRole(): Promise<void> {
    if (this.roleName.trim() === '' || this.roleCode.trim() === '') { this.error = '角色名称和权限字符不能为空'; return; }
    const codes: string[] = this.permissionCodes.split(',').map((item: string) => item.trim())
      .filter((item: string) => item.length > 0);
    const request: RoleSaveRequest = {
      name: this.roleName.trim(), code: this.roleCode.trim(), remark: this.roleRemark.trim(),
      permission_codes: codes, status: this.editStatusOn ? 1 : 0
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
    } catch (_error) { this.error = '角色保存失败，请稍后重试'; }
  }

  @Builder
  private pageHeader() {
    Row() {
      Text('角色管理').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Blank()
      Button('新增角色').height(40).fontSize(14).borderRadius(8)
        .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
        .padding({ left: 20, right: 20 })
        .onClick(() => this.openCreate())
    }.width('100%').alignItems(VerticalAlign.Center)
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
      Text(label).fontSize(12).fontColor($r('sys.color.font_secondary'))
    }.alignItems(HorizontalAlign.Center).width(62)
  }

  @Builder
  private roleRow(role: RoleRecord, isLast: boolean) {
    Column() {
      Row() {
        Column().width(3).alignSelf(ItemAlign.Stretch)
          .backgroundColor(this.selectedRoleId === role.id ? ACTION_BUTTON_BG : Color.Transparent)
        Row({ space: 14 }) {
          Column({ space: 6 }) {
            Text(role.name || '--').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(role.description || '暂无描述').fontSize(13).fontColor($r('sys.color.font_secondary'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          this.listStat(this.permissionCountOf(role), '权限数')
          this.listStat(this.userCount(role), '用户数')
          Text('编辑').fontSize(14).fontColor($r('sys.color.font_primary'))
            .padding({ left: 10, top: 8, bottom: 8 })
            .onClick(() => { this.selectedRoleId = role.id; this.openEdit(role); })
        }.layoutWeight(1).height(96).padding({ left: 16, right: 12 })
          .alignItems(VerticalAlign.Center)
      }.width('100%')
        .backgroundColor(this.selectedRoleId === role.id || this.hoveredRoleId === role.id ?
          $r('sys.color.comp_background_secondary') : Color.Transparent)
        .onClick(() => this.selectedRoleId = role.id)
        .onHover((hover: boolean) => this.hoveredRoleId = hover ? role.id : 0)
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
      this.cardHeader('角色列表')
      if (this.loading) {
        Column() {
          LoadingProgress().width(30).height(30)
        }.width('100%').padding({ top: 44, bottom: 44 })
      } else if (this.roles.length === 0) {
        Column() {
          Text(this.error.length > 0 ? this.error : '暂无角色数据').fontSize(13).fontColor($r('sys.color.font_tertiary'))
        }.width('100%').padding({ top: 44, bottom: 44 })
      } else {
        ForEach(this.roles, (role: RoleRecord, index: number) => {
          this.roleRow(role, index === this.roles.length - 1)
        }, (role: RoleRecord) => `role-${role.id}`)
      }
    }.width('100%').backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.compactWidth ? 0 : this.cardMinHeight })
  }

  @Builder
  private detailStat(count: number, label: string) {
    Column({ space: 6 }) {
      Text(count.toString()).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text(label).fontSize(12).fontColor($r('sys.color.font_secondary'))
    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  }

  @Builder
  private permissionChip(label: string) {
    Text(label).fontSize(13).fontColor($r('sys.color.font_primary'))
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(6)
  }

  @Builder
  private permissionGroupBlock(group: PermissionGroup) {
    Column({ space: 10 }) {
      Text(group.title).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach(group.items, (item: RolePermission) => {
          this.permissionChip(item.name || item.code)
        }, (item: RolePermission) => `${group.title}-${item.code}`)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private roleDetailContent(role: RoleRecord) {
    Column({ space: 14 }) {
      Text(role.name || '--').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text(role.description || '暂无描述').fontSize(13).fontColor($r('sys.color.font_secondary'))
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row() {
        this.detailStat(this.permissionCountOf(role), '权限数量')
        this.detailStat(this.userCount(role), '用户数量')
      }.width('100%')
      ForEach(this.permissionGroups(role), (group: PermissionGroup) => {
        this.permissionGroupBlock(group)
      }, (group: PermissionGroup) => `group-${group.title}`)
    }.width('100%').padding(18).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private roleDetailCard() {
    Column() {
      this.cardHeader('角色详情')
      if (this.selectedRoleList().length === 0) {
        Column() {
          Text('请选择左侧角色查看详情').fontSize(13).fontColor($r('sys.color.font_tertiary'))
        }.width('100%').padding({ top: 44, bottom: 44 })
      } else {
        ForEach(this.selectedRoleList(), (role: RoleRecord) => {
          this.roleDetailContent(role)
        }, (role: RoleRecord) => `detail-${role.id}`)
      }
    }.width('100%').backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.compactWidth ? 0 : this.cardMinHeight })
  }

  @Builder
  private saveDialog() {
    Column({ space: 12 }) {
      Text(this.editingRoleId > 0 ? '编辑角色' : '新增角色').fontSize(20).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      TextInput({ placeholder: '角色名称，例如护理组长', text: $$this.roleName }).height(42)
      TextInput({ placeholder: '权限字符，例如 head_nurse', text: $$this.roleCode }).height(42)
      TextInput({ placeholder: '权限字符，逗号分隔，如 elder:read,task:read', text: $$this.permissionCodes }).height(42)
      TextArea({ placeholder: '备注，可选', text: $$this.roleRemark }).height(76)
      Row({ space: 10 }) {
        Text('状态').fontSize(14).fontColor($r('sys.color.font_primary'))
        Toggle({ type: ToggleType.Switch, isOn: $$this.editStatusOn })
        Text(this.editStatusOn ? '正常' : '停用').fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%')
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40).fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.showDialog = false)
        Button('保存').layoutWeight(1).height(40).fontSize(14)
          .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
          .onClick(() => this.saveRole())
      }.width('100%')
    }.width(this.compactWidth ? '90%' : 460).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  build() {
    Stack() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          this.pageHeader()
          if (this.error.length > 0) {
            Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
          }
          GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
            GridCol({ span: this.compactWidth ? 12 : 8 }) {
              this.roleListCard()
            }
            GridCol({ span: this.compactWidth ? 12 : 4 }) {
              this.roleDetailCard()
            }
          }.width('100%')
            .onAreaChange((_oldArea: Area, newArea: Area) => {
              this.cardMinHeight = Number(newArea.height);
            })
          Text(`共 ${this.roles.length} 个角色`).fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%')
            .textAlign(TextAlign.End)
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
          top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      if (this.showDialog) {
        Row() { this.saveDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
