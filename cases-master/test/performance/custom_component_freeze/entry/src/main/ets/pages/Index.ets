/*
 * “合理使用自定义组件冻结功能”正反例
 */

// 图片类
@Observed
class ImageInfo {
  id: number; // 图片id
  icon: ResourceStr; // 图片
  isSelected: boolean; // 是否选中图片

  constructor(id: number = 0, icon: ResourceStr = '', isSelected: boolean = false) {
    this.id = id;
    this.icon = icon;
    this.isSelected = isSelected;
  }
}

// MyDataSource类实现IDataSource接口
class MyDataSource implements IDataSource {
  private dataArray: ImageInfo[] = [];

  public pushData(data: ImageInfo): void {
    this.dataArray.push(data);
  }

  // 数据源的数据总量
  public totalCount(): number {
    return this.dataArray.length;
  }

  // 返回指定索引位置的数据
  public getData(index: number): ImageInfo {
    return this.dataArray[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
  }
}

// 预加载的GridItem的数量
const CACHED_COUNT: number = 200;

@Entry
@Component
struct ImitationGallery {
  // 数据源
  @State data: MyDataSource = new MyDataSource();
  // 选择模式标志位
  @State isSelectedMode: boolean = false;
  // 全选标志位。
  @State isSelectedAll: boolean = false;
  // 选择模式下选中的图片个数
  @State selectCount: number = 0;
  // 图片选中列表。存放选中后的图片id。
  @State @Watch('onSelectChange') selectedList: number[] = [];
  // 是否启用组件冻结功能
  @State isUseFreezeWhenInactive: boolean = false;

  // 监听选中图片的数量
  private onSelectChange() {
    this.selectCount = this.selectedList.length;
  }

  aboutToAppear() {
    // 添加图片数据源
    for (let i = 0; i < 2000; i++) {
      this.data.pushData(new ImageInfo(i, $r('app.media.custom_component_freeze_photo'), false));
    }
  }

  build() {
    Column() {
      Row() {
        if (!this.isSelectedMode) {
          Text("所有照片").fontSize(25).padding({ left: 15 }).fontWeight(FontWeight.Medium)
          Blank()
          Text("是否开启组件冻结").fontSize(15)
          Toggle({ type: ToggleType.Switch, isOn: this.isUseFreezeWhenInactive })
            .margin({ right: 20 })
            .onChange((isOn: boolean) => {
              this.isUseFreezeWhenInactive = isOn ? true : false;
            })
        } else {
          Row() {
            Image($r('app.media.custom_component_freeze_cancel'))
              .margin({ left: 15, right: 15 })
              .width(25)
              .onClick((): void => {
                if (this.isSelectedMode) {
                  // 取消选择模式
                  this.isSelectedMode = false;
                  // 取消所有选中状态
                  for (let i = 0; i < this.selectedList.length; i++) {
                    this.data.getData(this.selectedList[i]).isSelected = false;
                  }
                  // 取消全选
                  this.isSelectedAll = false;
                  this.selectedList = [];
                }
              })
            Text(`已选择${this.selectCount}项`).fontSize(20)
            Blank()
            Image(this.isSelectedAll ? $r('app.media.custom_component_freeze_select_all') :
            $r('app.media.custom_component_freeze_no_select_all'))
              .width(30)
              .height(30)
              .margin({ right: 20 })
              .onClick(() => {
                if (!this.isSelectedMode) {
                  return;
                }
                // 全选
                if (this.isSelectedAll) {
                  this.isSelectedAll = false;
                  // 取消全选，修改选中状态
                  for (let i = 0; i < this.selectedList.length; i++) {
                    this.data.getData(this.selectedList[i]).isSelected = false;
                  }
                  this.selectedList = [];
                } else {
                  // 全选，添加到图片选中列表
                  this.isSelectedAll = true;
                  this.selectedList = [];
                  for (let i = 0; i < this.data.totalCount(); i++) {
                    this.data.getData(i).isSelected = true;
                    this.selectedList.push(i);
                  }
                }
              })
          }.width('100%')
        }
      }.width('100%').height(48)

      if (this.isUseFreezeWhenInactive) {
        Grid() {
          LazyForEach(this.data, (imageItem: ImageInfo) => {
            GridItem() {
              UseFreezeItem({
                imageItem: imageItem,
                isSelectedMode: this.isSelectedMode,
                selectedList: this.selectedList
              })
            }
          }, (item: string) => item)
        }
        .cachedCount(CACHED_COUNT) // 设置GridItem的缓存数量
        .columnsTemplate('1fr 1fr 1fr 1fr')
        .columnsGap(2)
        .rowsGap(2)
      } else {
        Grid() {
          LazyForEach(this.data, (imageItem: ImageInfo) => {
            GridItem() {
              NotUseFreezeItem({
                imageItem: imageItem,
                isSelectedMode: this.isSelectedMode,
                selectedList: this.selectedList
              })
            }
          }, (item: string) => item)
        }
        .cachedCount(CACHED_COUNT) // 设置GridItem的缓存数量
        .columnsTemplate('1fr 1fr 1fr 1fr')
        .columnsGap(2)
        .rowsGap(2)
      }
    }
  }
}

// 使用组件冻结
@Component({ freezeWhenInactive: true })
struct UseFreezeItem {
  @ObjectLink imageItem: ImageInfo; // 图片信息对象
  @Link isSelectedMode: boolean; // 是否选择模式
  @Link selectedList: number[]; // 图片选中列表。存放选中后的图片id。

  build() {
    Stack() {
      Image(this.imageItem.icon).aspectRatio(1).draggable(false)
      if (this.isSelectedMode) {
        Image(this.imageItem.isSelected ? $r('app.media.custom_component_freeze_checkbox_on') :
        $r('app.media.custom_component_freeze_checkbox_off'))
          .height(24)
          .width(24)
          .position({ x: '100%', y: '100%' })
          .markAnchor({
            x: 28,
            y: 28
          })
      }
    }
    .width('100%')
    .aspectRatio(1)
    .gesture(LongPressGesture().onAction((event: GestureEvent): void => {
      // 长按进入选择模式。同时选中当前长按的图片
      if (!this.isSelectedMode) {
        this.isSelectedMode = true;
        this.imageItem.isSelected = true;
        this.selectedList.push(this.imageItem.id);
      }
    }))
    .onClick((): void => {
      if (!this.isSelectedMode) {
        return;
      }
      if (this.imageItem.isSelected) {
        // 取消选中，从图片选中列表中删除
        this.imageItem.isSelected = false;
        this.selectedList = this.selectedList.filter(num => num !== this.imageItem.id);
      } else {
        // 选中图片，添加到图片选中列表
        this.imageItem.isSelected = true;
        this.selectedList.push(this.imageItem.id);
      }
    })
  }
}

// 不使用组件冻结
@Component
struct NotUseFreezeItem {
  @ObjectLink imageItem: ImageInfo; // 图片信息对象
  @Link isSelectedMode: boolean; // 是否选择模式
  @Link selectedList: number[]; // 图片选中列表。存放选中后的图片id。

  build() {
    Stack() {
      Image(this.imageItem.icon).aspectRatio(1).draggable(false)
      if (this.isSelectedMode) {
        Image(this.imageItem.isSelected ? $r('app.media.custom_component_freeze_checkbox_on') :
        $r('app.media.custom_component_freeze_checkbox_off'))
          .height(24)
          .width(24)
          .position({ x: '100%', y: '100%' })
          .markAnchor({
            x: 28,
            y: 28
          })
      }
    }
    .width('100%')
    .aspectRatio(1)
    .gesture(LongPressGesture().onAction((event: GestureEvent): void => {
      // 长按进入选择模式。同时选中当前长按的图片
      if (!this.isSelectedMode) {
        this.isSelectedMode = true;
        this.imageItem.isSelected = true;
        this.selectedList.push(this.imageItem.id);
      }
    }))
    .onClick((): void => {
      if (!this.isSelectedMode) {
        return;
      }
      if (this.imageItem.isSelected) {
        // 取消选中，从图片选中列表中删除
        this.imageItem.isSelected = false;
        this.selectedList = this.selectedList.filter(num => num !== this.imageItem.id);
      } else {
        // 选中图片，添加到图片选中列表
        this.imageItem.isSelected = true;
        this.selectedList.push(this.imageItem.id);
      }
    })
  }
}
