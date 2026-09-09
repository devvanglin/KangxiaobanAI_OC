import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import ApiClient from '../../network/ApiClient';
import { BusinessStore } from '../../network/BusinessStore';
import { Assessment, Elder } from '../../network/Dto';
import { quickElderName } from './WideDoctorQuickPageKit';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

interface EmptyBody {
}

interface TypeFilter {
  key: string;
  label: string;
}

interface TypeStyle {
  text: ResourceColor;
  background: ResourceColor;
}

interface LevelStyle {
  label: string;
  text: ResourceColor;
  background: ResourceColor;
}

interface ElderOption {
  value: string;
}

interface CreateAssessmentRequest {
  elder_id: number;
  assessment_type: string;
  notes: string;
  assessed_at: string;
}

const TYPE_FILTERS: TypeFilter[] = [
  { key: 'all', label: '全部' },
  { key: 'adl', label: 'ADL 评估' },
  { key: 'fall', label: '跌倒评估' },
  { key: 'cognition', label: '认知评估' },
  { key: 'nutrition', label: '营养评估' }
];

const PAGE_SIZE: number = 10;

/** 医师端「长者评估」：类型筛选 + 搜索 + 评估台账表格 + 新建评估。 */
@ComponentV2
export struct WideDoctorAssessmentsPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};
  @Event onOpenReport: (assessmentId: number) => void = (_assessmentId: number) => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local typeFilter: string = 'all';
  @Local search: string = '';
  @Local selectedElderId: number = 0;
  @Local selectedType: string = 'adl';
  @Local notes: string = '';
  @Local creating: boolean = false;
  @Local formVisible: boolean = false;
  @Local page: number = 1;
  @Local expandedId: number = -1;
  @Local hoveredId: number = -1;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    void this.businessStore.load();
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
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

  // ==================== 数据映射 ====================

  private typeItems(): WideSlidingCapsuleItem[] {
    return TYPE_FILTERS.map((item: TypeFilter, index: number): WideSlidingCapsuleItem => {
      return { title: item.label, index: index };
    });
  }

  private typeIndex(): number {
    const idx: number = TYPE_FILTERS.findIndex((item: TypeFilter): boolean => item.key === this.typeFilter);
    return idx < 0 ? 0 : idx;
  }

  private typeLabel(type: string): string {
    return type === 'adl' ? 'ADL 评估' :
      type === 'fall' ? '跌倒评估' :
      type === 'cognition' ? '认知评估' :
      type === 'nutrition' ? '营养评估' :
        type === 'comprehensive_agent' ? 'AI 综合评估' : (type.length > 0 ? type : '综合评估');
  }

  private typeStyle(type: string): TypeStyle {
    if (type === 'comprehensive_agent') {
      return { text: '#534AB7', background: 'rgba(127,119,221,0.14)' };
    }
    if (type === 'adl') {
      return { text: $r('app.color.brand_blue'), background: 'rgba(29,99,237,0.10)' };
    }
    if (type === 'fall') {
      return { text: $r('app.color.doctor_workspace_warning'), background: 'rgba(239,159,39,0.16)' };
    }
    if (type === 'cognition') {
      return { text: '#534AB7', background: 'rgba(127,119,221,0.14)' };
    }
    return { text: $r('app.color.doctor_workspace_success'), background: 'rgba(99,153,34,0.12)' };
  }

  private levelStyle(careLevel: number): LevelStyle {
    if (careLevel <= 1) {
      return { label: '自理级', text: $r('app.color.doctor_workspace_success'), background: 'rgba(99,153,34,0.12)' };
    }
    if (careLevel === 2) {
      return { label: '半自理级', text: $r('app.color.brand_blue'), background: 'rgba(29,99,237,0.10)' };
    }
    if (careLevel === 3) {
      return { label: '失能级', text: $r('app.color.doctor_workspace_warning'), background: 'rgba(239,159,39,0.16)' };
    }
    return { label: '特护级', text: $r('app.color.doctor_workspace_danger'), background: 'rgba(163,45,45,0.10)' };
  }

  private ageOf(elder: Elder | undefined): string {
    if (elder === undefined || elder.birth_date === undefined || elder.birth_date.length < 4) {
      return '--';
    }
    const age: number = new Date().getFullYear() - Number(elder.birth_date.slice(0, 4));
    return `${age}岁`;
  }

  private careLevelOf(elderId: number): number {
    return this.businessStore.elders.find((item: Elder): boolean => item.id === elderId)?.care_level ?? 0;
  }

  private assessmentNo(item: Assessment): string {
    return `A${item.assessed_at.slice(0, 10).split('-').join('')}${item.id.toString().padStart(3, '0')}`;
  }

  private filteredAssessments(): Assessment[] {
    const keyword: string = this.search.trim();
    return this.businessStore.assessments.filter((item: Assessment): boolean => {
      if (this.typeFilter !== 'all' && item.assessment_type !== this.typeFilter) {
        return false;
      }
      if (keyword.length === 0) {
        return true;
      }
      const haystack: string =
        `${this.assessmentNo(item)}${quickElderName(this.businessStore, item.elder_id)}`;
      return haystack.includes(keyword);
    });
  }

  private pagedAssessments(): Assessment[] {
    const list: Assessment[] = this.filteredAssessments();
    const start: number = (this.page - 1) * PAGE_SIZE;
    return list.slice(start, start + PAGE_SIZE);
  }

  private totalPages(): number {
    return Math.max(1, Math.ceil(this.filteredAssessments().length / PAGE_SIZE));
  }

  private elderOptions(): ElderOption[] {
    const options: ElderOption[] = [];
    this.businessStore.elders.forEach((elder: Elder): void => {
      const option: ElderOption = { value: elder.name };
      options.push(option);
    });
    return options;
  }

  // ==================== 交互 ====================

  private submitAssessment(): void {
    if (this.creating) {
      return;
    }
    if (this.selectedElderId === 0) {
      this.showToast('请选择要评估的长者');
      return;
    }
    this.creating = true;
    const now: Date = new Date();
    const assessedAt: string =
      `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-` +
      `${now.getDate().toString().padStart(2, '0')} ${now.getHours().toString().padStart(2, '0')}:` +
      `${now.getMinutes().toString().padStart(2, '0')}:00`;
    const request: CreateAssessmentRequest = {
      elder_id: this.selectedElderId,
      assessment_type: this.selectedType,
      notes: this.notes,
      assessed_at: assessedAt
    };
    ApiClient.post<Assessment>('/assessments', request)
      .then((response): void => {
        this.creating = false;
        if (response.code !== 0) {
          this.showToast(response.msg.length > 0 ? response.msg : '创建评估失败');
          return;
        }
        this.showToast('评估已创建');
        this.formVisible = false;
        this.notes = '';
        this.selectedElderId = 0;
        this.page = 1;
        void this.businessStore.load();
      })
      .catch((_error: Object): void => {
        this.creating = false;
        this.showToast('创建评估失败，请检查网络');
      });
  }

  // ==================== UI ====================

  @Builder
  private typePill(type: string) {
    Text(this.typeLabel(type))
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.typeStyle(type).text)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(6)
      .backgroundColor(this.typeStyle(type).background)
  }

  @Builder
  private levelPill(careLevel: number) {
    if (careLevel > 0) {
      Text(this.levelStyle(careLevel).label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.levelStyle(careLevel).text)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(6)
        .backgroundColor(this.levelStyle(careLevel).background)
    } else {
      Text('--').fontSize(12).fontColor($r('sys.color.font_tertiary'))
    }
  }

  @Builder
  private statusPill() {
    Text('已完成')
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.doctor_workspace_success'))
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(6)
      .backgroundColor('rgba(99,153,34,0.12)')
  }

  @Builder
  private headerCell(title: string, weight: number) {
    Text(title)
      .layoutWeight(weight)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .maxLines(1)
  }

  @Builder
  private tableHeader() {
    Row({ space: 12 }) {
      this.headerCell('评估编号', 3)
      this.headerCell('老人姓名', 2)
      this.headerCell('年龄', 1)
      this.headerCell('评估类型', 2)
      this.headerCell('护理等级', 2)
      this.headerCell('评估医师', 2)
      this.headerCell('评估日期', 2)
      this.headerCell('状态', 2)
      this.headerCell('操作', 2)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private assessmentRow(item: Assessment) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(this.assessmentNo(item))
          .layoutWeight(3)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
        Text(quickElderName(this.businessStore, item.elder_id))
          .layoutWeight(2)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
        Text(this.ageOf(this.businessStore.elders.find(
          (elder: Elder): boolean => elder.id === item.elder_id)))
          .layoutWeight(1)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
        Row() {
          this.typePill(item.assessment_type)
        }
        .layoutWeight(2)
        Row() {
          this.levelPill(this.careLevelOf(item.elder_id))
        }
        .layoutWeight(2)
        Text(`医师${item.assessor_id}`)
          .layoutWeight(2)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
        Text(item.assessed_at.slice(0, 10))
          .layoutWeight(2)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
        Row() {
          this.statusPill()
        }
        .layoutWeight(2)

        Row({ space: 10 }) {
          Text(item.report !== undefined && item.report.trim().length > 0 ? '查看报告' :
            (this.expandedId === item.id ? '收起' : '查看'))
            .fontSize(13)
            .fontColor($r('app.color.brand_blue'))
            .onClick(() => {
              if (item.report !== undefined && item.report.trim().length > 0) {
                this.onOpenReport(item.id);
              } else {
                this.expandedId = this.expandedId === item.id ? -1 : item.id;
              }
            })
        }
        .layoutWeight(2)
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.hoveredId === item.id ? $r('sys.color.interactive_hover') : Color.Transparent)
      .alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
      .onHover((isHover: boolean) => {
        this.hoveredId = isHover ? item.id : -1;
      })
      .onClick(() => {
        if (item.report !== undefined && item.report.trim().length > 0) {
          this.onOpenReport(item.id);
        } else {
          this.expandedId = this.expandedId === item.id ? -1 : item.id;
        }
      })

      if (this.expandedId === item.id) {
        Column({ space: 6 }) {
          Text(`评分：${item.score !== undefined && item.score !== null ? `${item.score} 分` : '未评分'}`)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
          Text(`风险等级：${item.risk_level.length > 0 ? item.risk_level : '未评估'}`)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
          Text(`备注：${item.notes.length > 0 ? item.notes : '无'}`)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
          if (item.report !== undefined && item.report.length > 0) {
            Text(item.report).fontSize(12).fontColor($r('sys.color.font_primary')).width('100%')
              .padding(12).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(10)
          }
        }
        .width('100%')
        .padding({ left: 26, right: 16, bottom: 12 })
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('sys.color.comp_background_secondary'))
      }
    }
    .width('100%')
  }

  @Builder
  private rowTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font_primary'))
  }

  @Builder
  private createFormCard() {
    Column({ space: 12 }) {
      this.rowTitle('新建评估')
      Row({ space: 10 }) {
        Text('长者').fontSize(13).fontColor($r('sys.color.font_secondary')).width(56)
        Select(this.elderOptions())
          .selected(this.selectedElderId === 0 ? 0 :
            Math.max(0, this.businessStore.elders.findIndex(
              (elder: Elder): boolean => elder.id === this.selectedElderId)))
          .value(this.selectedElderId === 0 ? '选择长者' :
            quickElderName(this.businessStore, this.selectedElderId))
          .fontColor($r('sys.color.font_primary'))
          .height(36)
          .layoutWeight(1)
          .onSelect((index: number): void => {
            const elder: Elder | undefined = this.businessStore.elders[index];
            this.selectedElderId = elder !== undefined ? elder.id : 0;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        Text('类型').fontSize(13).fontColor($r('sys.color.font_secondary')).width(56)
        Select(this.typeSelectOptions())
          .selected(Math.max(0, TYPE_FILTERS.findIndex(
            (item: TypeFilter): boolean => item.key === this.selectedType) - 1))
          .value(this.typeLabel(this.selectedType))
          .fontColor($r('sys.color.font_primary'))
          .height(36)
          .layoutWeight(1)
          .onSelect((index: number): void => {
            const keys: string[] = ['adl', 'fall', 'cognition', 'nutrition'];
            this.selectedType = index >= 0 && index < keys.length ? keys[index] : 'adl';
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        Text('备注').fontSize(13).fontColor($r('sys.color.font_secondary')).width(56)
        TextInput({ placeholder: '评估备注（可选）', text: this.notes })
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onChange((value: string) => {
            this.notes = value;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 12 }) {
        Blank()
        Button('取消')
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(10)
          .height(38)
          .padding({ left: 18, right: 18 })
          .enabled(!this.creating)
          .onClick(() => {
            this.formVisible = false;
          })
        Button(this.creating ? '提交中…' : '提交评估')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('sys.color.font_primary'))
          .borderRadius(10)
          .height(38)
          .padding({ left: 22, right: 22 })
          .enabled(!this.creating)
          .onClick(() => {
            this.submitAssessment();
          })
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 14 })
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  private typeSelectOptions(): ElderOption[] {
    const options: ElderOption[] = [];
    const labels: string[] = ['ADL 评估', '跌倒评估', '认知评估', '营养评估'];
    labels.forEach((label: string): void => {
      const option: ElderOption = { value: label };
      options.push(option);
    });
    return options;
  }

  @Builder
  private pager() {
    Row({ space: 8 }) {
      Text(`共 ${this.filteredAssessments().length} 条记录`)
        .fontSize(12)
        .fontColor($r('sys.color.font_tertiary'))
      Blank()
      ForEach(this.pageNumbers(), (pageNo: number) => {
        Text(pageNo.toString())
          .fontSize(13)
          .fontWeight(this.page === pageNo ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(this.page === pageNo ? Color.White : $r('sys.color.font_primary'))
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.page === pageNo ? $r('sys.color.font_primary') :
            $r('sys.color.comp_background_secondary'))
          .onClick(() => {
            this.page = pageNo;
          })
      }, (pageNo: number) => `page-${pageNo}`)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  private pageNumbers(): number[] {
    const pages: number[] = [];
    const total: number = this.totalPages();
    for (let i = 1; i <= total; i++) {
      pages.push(i);
    }
    return pages;
  }

  build() {
    HdsNavDestination() {
      Row() {
        Column() {
        Row({ space: 12 }) {
          WideSlidingCapsule({
            items: this.typeItems(),
            selectedIndex: this.typeIndex(),
            itemWidth: 96,
            onSelect: (index: number) => {
              if (index >= 0 && index < TYPE_FILTERS.length) {
                this.typeFilter = TYPE_FILTERS[index].key;
                this.page = 1;
              }
            }
          })
          Blank()
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(14)
              .fontColor([$r('sys.color.font_tertiary')])
            TextInput({ placeholder: '搜索老人姓名…', text: this.search })
              .layoutWeight(1)
              .height(32)
              .fontSize(13)
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 0 })
              .onChange((value: string) => {
                this.search = value;
                this.page = 1;
              })
          }
          .width(220)
          .height(38)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(19)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          Button(this.formVisible ? '收起表单' : '新建评估')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('sys.color.font_primary'))
            .borderRadius(10)
            .height(38)
            .padding({ left: 18, right: 18 })
            .onClick(() => {
              this.formVisible = !this.formVisible;
            })
        }
        .width('100%')
        .padding({ top: 88 + this.statusBarHeight })
        .margin({ bottom: 16 })

        if (this.formVisible) {
          this.createFormCard()
        }

        Column() {
          this.tableHeader()
          Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          Scroll(this.scroller) {
            Column() {
              if (this.pagedAssessments().length === 0) {
                Column({ space: 8 }) {
                  SymbolGlyph($r('sys.symbol.heart_fill'))
                    .fontSize(36)
                    .fontColor([$r('sys.color.font_tertiary')])
                  Text(this.businessStore.loading && !this.businessStore.loaded ? '正在加载评估记录…' : '暂无评估记录')
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('sys.color.font_secondary'))
                  Text('点击右上角「新建评估」为长者创建评估')
                    .fontSize($r('sys.float.Body_S'))
                    .fontColor($r('sys.color.font_tertiary'))
                }
                .width('100%')
                .padding({ top: 48, bottom: 48 })
                .alignItems(HorizontalAlign.Center)
              } else {
                ForEach(this.pagedAssessments(), (item: Assessment) => {
                  this.assessmentRow(item)
                }, (item: Assessment) => `assess-${item.id}`)
              }
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          if (this.filteredAssessments().length > 0) {
            Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
            this.pager()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ bottom: 24 + this.naviIndicatorHeight })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: 1280 })
        .padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .onBackPressed((): boolean => {
      this.onClose();
      return true;
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '长者评估' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
