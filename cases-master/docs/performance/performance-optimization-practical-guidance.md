# 性能优化实操宝典

## 概述

本文总结了实际开发应用时常见的性能优化规范，配合举例实际开发中常见的正反例代码，帮助开发者解决大部分性能问题。

### 性能规范总览目录
| &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;  &emsp;&emsp;  &emsp;&emsp; <br />分类<br />&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp; &emsp;&emsp;&emsp;&emsp;  &emsp;&emsp;   |<br />高频程度 (5满分)<br />&emsp;&emsp;&emsp;&emsp;   | 规范（检查项）       | 实操方法                |            <br />代码示例<br />&emsp;&emsp;&emsp;&emsp;                 |
|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------:|:---------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------------------------------:|
| 响应时延&nbsp;/&nbsp;完成时延                                                                                                                                                    |                          5                          | 不建议在aboutToAppear(),aboutToDisappear()等生命周期中执行耗时操作 | 排查所有的aboutToAppear和aboutToDisappear函数(或者通过Trace查看)，查看是否有耗时操作，改为setTimeOut或者在TaskPool中执行。                                          |       [代码示例](#不建议在abouttoappearabouttodisappear等生命周期中执行耗时操作)        |
| 响应时延&nbsp;/&nbsp;完成时延                                                                                                                                                    |                          5                          | 不要在回调函数中执行耗时操作(ArkUI接口回调、网络访问回调、await等)            | 排查所有的回调函数(或者通过Trace查看)，尤其是ArkUI接口，网络回调函数，查看是否有耗时操作，是否使用了await操作，改为setTimeOut或者在TaskPool中执行。                      |            [代码示例](#不要在回调函数中执行耗时操作arkui接口回调网络访问回调await等)             |
| 响应时延&nbsp;/&nbsp;完成时延&nbsp;/&nbsp;帧率                                                                                                                                     |                          5                          | 列表场景未使用LazyForEach+组件复用+缓存列表项            | 排查使用LazyForEach的代码，确认是否有使用组件复用(@Reusable)+缓存列表项(cachedCount)。                                                                                                           |                [代码示例](#列表场景未使用lazyforeach组件复用缓存列表项)                 |
| 完成时延                                                                                                                                                                     |                          5                          | Web未使用预连接，未提前初始化引擎    | 在应用创建Ability的时候，在OnCreate阶段预先初始化内核，建议把引擎的初始化放在setTimeOut中。                                                                                                              |                     [代码示例](#web未使用预连接未提前初始化引擎)                      |
| 响应时延&nbsp;/&nbsp;完成时延                                                                                                                                                    |                          5                          | 高频接口中不要打印Trace和日志    | 排查接口onTouch、onItemDragMove、onDragMove、onDidScroll、onMouse、onVisibleAreaChange、OnAreaChange、onActionUpdate、animator的onFrame、组件复用场景下的aboutToReuse，不建议在里面打印trace和日志。          |                     [代码示例](#高频接口中不要打印trace和日志)                      |
| 完成时延&nbsp;/&nbsp;帧率                                                                                                                                                      |                          4                          | 组件复用里面有if语句，但是未使用reuseId            | 排查使用了@Reusable的自定义组件，查看build中给是否使用了if/else或ForEach等条件渲染语句，如果使用了，需要配合reuseId一起使用。                                                                                        |                  [代码示例](#组件复用里面有if语句但是未使用reuseid)                   |
| 响应时延&nbsp;/&nbsp;完成时延                                                                                                                                                    |                          4                          | 不建议使用@Prop装饰器           | 全局搜索@Prop并且替换                                                                                                                                           |                        [代码示例](#不建议使用prop装饰器)                        |
| 响应时延&nbsp;/&nbsp;完成时延                                                                                                                                                    |                          3                          | 避免在ResourceManager的getXXXSync接口入参中直接使用资源信息           | 排查ResourceManager.getXXXSync接口，查看入参时需要使用getStringSync($r('app.media.icon').id)的形式，如果未使用需要整改。                                                 | [代码示例](#避免在resourcemanager的getxxxsync接口入参中直接使用资源信息) |
| 响应时延&nbsp;/&nbsp;完成时延                                                                                                                                                    |                          3                          | 展示用的自定义组件（数据从父组件中获取，无独立数据处理）使用@Builder替换           | 审视@Component标记的自定义组件，如果里面没有独立的生命周期处理逻辑，数据由父组件传递，建议@Builder替代。                                                           |            [代码示例](#展示用的自定义组件数据从父组件中获取无独立数据处理使用builder替换)            |
| 响应时延&nbsp;/&nbsp;完成时延&nbsp;/&nbsp;帧率                                                                                                                                     |                          3                          | 删除无具体逻辑的生命周期，ArkUI的函数回调等，删除冗余堵塞日志打印           | 排查所有的aboutToAppear、aboutToDisappear等生命周期函数，排查ArkUI的回调函数，如果函数中无具体业务逻辑，例如只打印了日志，删除函数回调。                                        |             [代码示例](#删除无具体逻辑的生命周期arkui的函数回调等删除冗余堵塞日志打印)              |
| 响应时延&nbsp;/&nbsp;完成时延                                                                                                                                                    |                          3                          | 删除未关联组件的状态变量装饰器           | 排查全局的状态变量装饰器，如果变量未关联组件，删除装饰器。             |                      [代码示例](#删除未关联组件的状态变量装饰器)                       |
| 帧率                                                                                                                                                                       |                          2                          | 	crypto-js性能差           | 排查buffer.from关键字，加密建议使用原生的cryptoFramework，然后将buffer替换为base64helper，性能提升，且数据量越大越明显。 |                        [代码示例](#crypto-js性能差)                        |
| 响应时延&nbsp;/&nbsp;完成时延                                                                                                                                                    |                          1                          | 	不建议使用Marquee组件           | 排查Marquee关键字，使用Text的跑马灯模式(TextOverflow.MARQUEE)替代。             |                       [代码示例](#不建议使用marquee组件)                       |
| 完成时延                                                                                                                                                                     |                          1                          | 	不能使用函数作为ArkUI组件的属性和组件复用的自定义组件的入参           | 查看属性是否有xx()函数写法，确认函数/方法中是否有耗时操作，替换成变量。            |              [代码示例](#不能使用函数作为arkui组件的属性和组件复用的自定义组件的入参)              |
| 完成时延                                                                                                                                                                     |                          1                          | 	不建议使用.linearGradient颜色渐变属性           | 排查linearGradient关键字，可以使用图片代替。            |                 [代码示例](#不建议使用lineargradient颜色渐变属性)                  |
| 完成时延&nbsp;/&nbsp;帧率                                                                                                                                                      |                          1                          | 	不要在for/while循环中执行耗时操作           | 排查for/while循环，查看里面是否有打印日志或者Trace。            |                    [代码示例](#不要在forwhile循环中执行耗时操作)                    |
| 完成时延&nbsp;/&nbsp;帧率                                                                                                                                                      |                          1                          | 	变量初值不建议设置为undefined，需进行默认初始化           | 例如number设置为0，string设置为空字符串等，这样在使用过程中更不需要增加额外判空。排查类中的变量，看看是否有初始化为undefined。            |                [代码示例](#变量初值不建议设置为undefined需进行默认初始化)                 |

## 性能优化规范

>说明：本文中所有的性能收益都仅作参考，具体数据需开发者根据不同的工程项目进行测量对比。

### 不建议在aboutToAppear()、aboutToDisappear()等生命周期中执行耗时操作

#### 类型
响应时延/完成时延
#### 解决方法
排查所有的aboutToAppear和aboutToDisappear函数(或者通过Trace查看)，查看是否有耗时操作，改为setTimeOut或者在TaskPool中执行。

#### 反例
```typescript
@Entry
@Component
struct ViewA {
  @State private text: string = "";
  private count: number = 0;
  // 反例：在aboutToAppear接口中执行耗时操作，阻塞页面绘制。
  aboutToAppear() {
    // 耗时操作
    this.computeTask(); // 同步任务
    let context = getContext(this) as Context;
    this.text = context.resourceManager.getStringSync($r('app.string.startup_text'));
  }

  computeTask(): void {
    this.count = 0;
    while (this.count < LARGE_NUMBER) {
      this.count++;
    }
    let context = getContext(this) as Context;
    this.text = context.resourceManager.getStringSync($r('app.string.task_text'));
  }
}
```
#### 正例
```typescript
@Entry
@Component
struct ViewB {
  @State private text: string = "";
  private count: number = 0;
  private readonly DELAYED_TIME: number = 100; // 定时器设置延时

  // 正例：在aboutToAppear接口中对耗时间的计算任务进行了异步处理。
  aboutToAppear() {
    // 耗时操作
    this.computeTaskAsync(); // 异步任务
    let context = getContext(this) as Context;
    this.text = context.resourceManager.getStringSync($r('app.string.startup_text'));
  }

  computeTask(): void {
    this.count = 0;
    while (this.count < LARGE_NUMBER) {
      this.count++;
    }
    let context = getContext(this) as Context;
    this.text = context.resourceManager.getStringSync($r('app.string.task_text'));
  }

  // 运算任务异步处理
  private computeTaskAsync(): void {
    setTimeout(() => {
    // 这里使用setTimeout来实现异步延迟运行
    this.computeTask();
    }, DELAYED_TIME)
  }
}
```
#### 性能收益

|              | 在aboutToAppear执行耗时操作 | 将aboutToAppear中的耗时操作进行异步处理 |
| ------------ | --------------------------- | --------------------------------------- |
| **响应时延** | 1.5s                        | 27.2ms                                  |

#### 高频程度&收益（5满分）
5

### 不要在回调函数中执行耗时操作（ArkUI接口回调、网络访问回调、await等）
#### 类型
响应时延/完成时延
#### 解决方法
排查所有的回调函数(或者通过Trace查看)，尤其是ArkUI接口，网络回调函数，查看是否有耗时操作，是否使用了await操作，改为setTimeOut或者在TaskPool中执行。
#### 反例
```typescript
@Entry
@Component
struct ViewA {
    loadPicture(count: number): IconItemSource[] {
    let iconItemSourceList: IconItemSource[] = [];
      // 遍历添加6*count个IconItem的数据
      for (let index = 0; index < count; index++) {
        const numStart: number = index * 6;
        // 此处循环使用6张图片资源
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 1}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 2}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 3}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 4}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 5}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 6}`));
      }
      return iconItemSourceList;
  }
      build() {
        Column() {
          Text("点击加载资源")
            .fontSize(50)
            .fontWeight(FontWeight.Bold)
            .onClick(() => {
              // 反例：耗时任务,常规同步执行
              this.loadPicture(100000)
              promptAction.showToast({ message: "加载完成" })
            })
        }
        .justifyContent(FlexAlign.Center)
        .height('90%')
        .width('100%')
    }
}
```
#### 正例
```typescript
@Entry
@Component
struct ViewA {
    loadPicture(count: number): IconItemSource[] {
    let iconItemSourceList: IconItemSource[] = [];
      // 遍历添加6*count个IconItem的数据
      for (let index = 0; index < count; index++) {
        const numStart: number = index * 6;
        // 此处循环使用6张图片资源
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 1}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 2}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 3}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 4}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 5}`));
        iconItemSourceList.push(new IconItemSource($r('app.media.bigphoto'), `item${numStart + 6}`));
      }
      return iconItemSourceList;
  }
      build() {
        Column() {
          Text("点击加载资源")
            .fontSize(50)
            .fontWeight(FontWeight.Bold)
            .onClick(() => {
              // 正例：耗时任务,TaskPool执行
              let iconItemSourceList: IconItemSource[] = [];
              // 创建Task
              let lodePictureTask: taskpool.Task = new taskpool.Task(loadPicture, 100000);
              // 执行Task，并返回结果
              taskpool.execute(lodePictureTask).then((res: object) => {
                iconItemSourceList = res as IconItemSource[];
                iconItemSourceList = [];
                // loadPicture方法的执行结果
              })
              promptAction.showToast({ message: "加载完成" })
            })
        }
        .justifyContent(FlexAlign.Center)
        .height('90%')
        .width('100%')
    }
}
```
#### 性能收益
|              | 回调函数执行耗时操作 | 将回调函数中的耗时操作在TaskPool执行 |
| ------------ | -------------------- | ------------------------------------ |
| **响应时延** | 2s                   | 10.5ms                               |

#### 高频程度&收益（5满分）
5

### 列表场景未使用LazyForEach+组件复用+缓存列表项
#### 类型
响应时延/完成时延/帧率
#### 解决方法
排查使用LazyForEach的代码，确认是否有使用组件复用(@Reusable)+缓存列表项(cachedCount)。
#### 反例
```typescript
import { promptAction } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { FriendMoment } from '../model/BasicDataSource';
import { FriendMomentsData } from '../model/FriendMomentData';
import { util } from '@kit.ArkTS';

@Entry
@Component
struct GoodView {
  private momentData: FriendMomentsData = new FriendMomentsData();
  @State momentDataArray:Array<FriendMoment> = []
  private readonly LIST_SPACE: number = 18;
    
  aboutToAppear(): void {
    this.momentData.getFriendMomentFromRawFile();
  }
    
  build() {
     Column() {
        List({ space: this.LIST_SPACE }) {
          // 反例：使用LazyForEach但并未使用组件复用和缓存列表项
          LazyForEach(this.momentData, (moment: FriendMoment) => {
            ListItem() {
              OneMoment({ moment: moment })// ReusId is used to control component reuse
                .reuseId((moment.image !== '') ? 'withImage_id' : 'noImage_id')
            }
          }, (moment: FriendMoment) => moment.id)
        }
        .margin({ top: 8 })
        .width(Constants.LAYOUT_MAX)
        .height(Constants.LAYOUT_MAX)
      }
      .justifyContent(FlexAlign.Center)
      .height('90%')
      .width('100%')
  }

@Component
export struct OneMoment {
  @Prop moment: FriendMoment;

  build() {
    Column() {
      Text(this.moment.text)
        .width(Constants.LAYOUT_MAX)
        .fontSize(18)
        .fontWeight(500)
        .lineHeight(24)
        .opacity(0.6)

      if (this.moment.image !== '') {
        Flex({ wrap: FlexWrap.Wrap }) {
          Image($r(this.moment.image))
            .width(Constants.LAYOUT_MAX)
            .height('27.5%')
            .borderRadius(16)
          Image($r(this.moment.image))
            .width(Constants.LAYOUT_MAX)
            .height('27.5%')
            .borderRadius(16)
            .margin({ top: 10 })
        }
        .width(Constants.LAYOUT_MAX)
        .margin({ top: 14 })
      }
    }
    .justifyContent(FlexAlign.Start)
    .margin({
      left: 16,
      right: 16
    })
  }
}
```
#### 正例
```typescript
import { promptAction } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { FriendMoment } from '../model/BasicDataSource';
import { FriendMomentsData } from '../model/FriendMomentData';
import { util } from '@kit.ArkTS';

@Entry
@Component
struct GoodView {
  private momentData: FriendMomentsData = new FriendMomentsData();
  @State momentDataArray:Array<FriendMoment> = []
  private readonly LIST_SPACE: number = 18;
    
  aboutToAppear(): void {
    this.momentData.getFriendMomentFromRawFile();
  }
    
  build() {
     Column() {
        List({ space: this.LIST_SPACE }) {
          // 正例：使用LazyForEach+组件复用+缓存列表项
          LazyForEach(this.momentData, (moment: FriendMoment) => {
            ListItem() {
              OneMoment({ moment: moment })// ReusId is used to control component reuse
                .reuseId((moment.image !== '') ? 'withImage_id' : 'noImage_id')
            }
          }, (moment: FriendMoment) => moment.id)
        }
         // 缓存列表项
        .cachedCount(this.LIST_CACHE_COUNT)
        .margin({ top: 8 })
        .width(Constants.LAYOUT_MAX)
        .height(Constants.LAYOUT_MAX)
      }
      .justifyContent(FlexAlign.Center)
      .height('90%')
      .width('100%')
  }
// 组件复用    
@Reusable
@Component
export struct OneMoment {
  @Prop moment: FriendMoment;

  build() {
    Column() {
      Text(this.moment.text)
        .width(Constants.LAYOUT_MAX)
        .fontSize(18)
        .fontWeight(500)
        .lineHeight(24)
        .opacity(0.6)

      if (this.moment.image !== '') {
        Flex({ wrap: FlexWrap.Wrap }) {
          Image($r(this.moment.image))
            .width(Constants.LAYOUT_MAX)
            .height('27.5%')
            .borderRadius(16)
          Image($r(this.moment.image))
            .width(Constants.LAYOUT_MAX)
            .height('27.5%')
            .borderRadius(16)
            .margin({ top: 10 })
        }
        .width(Constants.LAYOUT_MAX)
        .margin({ top: 14 })
      }
    }
    .justifyContent(FlexAlign.Start)
    .margin({
      left: 16,
      right: 16
    })
  }
}
```
#### 性能收益
|          | 使用LazyForEach+未使用组件复用+未使用缓存列表项 | 使用LazyForEach+组件复用+缓存列表项 |
| -------- | ---- | ------ |
| **列表渲染时间** | 31.6ms | 23.4ms |

#### 高频程度&收益（5满分）
5

### Web未使用预连接，未提前初始化引擎
#### 类型
完成时延
#### 解决方法
在应用创建Ability的时候，在OnCreate阶段预先初始化内核，建议把引擎的初始化放在setTimeOut中。
#### 反例
```typescript
// Web组件引擎没有初始化，且沒有使用预连接
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
  }
}
controller: webview.WebviewController = new webview.WebviewController();
// ...
Web({ src: 'https://www.example.com', controller: this.controller })

```
#### 正例
```typescript
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info("EntryAbility onCreate")
    // 在 Web 组件初始化之前，通过此接口加载 Web 引擎的动态库文件，以提高启动性能。
    setTimeout(() => {
      // 这里使用setTimeout来实现延迟运行
      webview.WebviewController.initializeWebEngine()
    }, 200)
    console.info("EntryAbility onCreate done");
  }
}

controller: webview.WebviewController = new webview.WebviewController();
// ...
Web({ src: 'https://www.example.com', controller: this.controller })

```
#### 性能收益
（注意：开发者反例验证时需要将EntryAbility.ets文件中，onCreate里面的接口加载 Web 引擎的动态库文件注释。）
|          | 未提前初始化引擎 | 提前初始化引擎 |
| -------- | ---- | ------ |
| **响应时延** | 116.5ms | 29.4ms |

#### 高频程度&收益（5满分）
5

### 高频接口中不要打印Trace和日志
#### 类型
响应时延/完成时延
#### 解决方法
排查接口onTouch、onItemDragMove、onDragMove、onDidScroll、onMouse、onVisibleAreaChange、OnAreaChange、
onActionUpdate、animator的onFrame、组件复用场景下的aboutToReuse，不建议在里面打印trace和日志。
#### 反例
```typescript
import { hilog, hiTraceMeter } from '@kit.PerformanceAnalysisKit';

@Component
struct CounterOfOnDidScroll {
  private arr: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  build() {
    Scroll() {
      ForEach(this.arr, (item: number) => {
        Text("ListItem" + item)
          .width("100%")
          .height("100%")
      }, (item: number) => item.toString())
    }
    .width('100%')
    .height('100%')
    .onDidScroll(() => {
      hiTraceMeter.startTrace("ScrollSlide", 1002);
      hilog.info(0x0000, 'TAG', '%{public}s', this.message);
      // 业务逻辑
      // ...
      // 反例：在高频接口中打印Trace和日志
      hilog.info(0x0000, 'TAG', '%{public}s', this.message);
      hiTraceMeter.finishTrace("ScrollSlide", 1002);
    })
  }
}
```
#### 正例
```typescript
@Component
struct PositiveOfOnDidScroll {
  private arr: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  build() {
    Scroll() {
      List() {
        ForEach(this.arr, (item: number) => {
          ListItem() {
            Text("TextItem" + item)
          }.width("100%")
           .height(100)
        }, (item: number) => item.toString())
      }
      .divider({ strokeWidth: 3, color: Color.Gray })
    }
    .width('100%')
    .height('100%')
    .onDidScroll(() => {
      // 正例：未在高频接口中打印Trace和日志
      // 业务逻辑
      // ...
    })
  }
}
```
#### 性能收益
|          | 在高频接口中打印Trace和日志 | 未在高频接口中打印Trace和日志 |
| -------- | ---- | ------ |
| **响应时延** | 40ms | 8.1ms |

#### 高频程度&收益（5满分）
4

### 组件复用里面有if语句，但是未使用reuseId
#### 类型
完成时延/帧率
#### 解决方法
排查使用了@Reusable的自定义组件，查看build中给是否使用了if/else或ForEach等条件渲染语句，如果使用了，需要配合reuseId一起使用。
#### 反例
```typescript
@Entry
@Component
struct withoutReuseId {
  private momentData: FriendMomentsData = new FriendMomentsData();
  private readonly LIST_SPACE: number = 18;
  aboutToAppear(): void {
    this.momentData.getFriendMomentFromRawFile();
  }

  build() {
    Column() {
      List({ space: this.LIST_SPACE }) {
        LazyForEach(this.momentData, (moment: FriendMoment) => {
          ListItem() {
            // 反例：未使用reuseId
            OneMoment({ moment: moment })
          }
        }, (moment: FriendMoment) => moment.id)
      }
    }
  }
}

@Reusable
@Component
export struct OneMoment {
  @Prop moment: FriendMoment;

  build() {
    Column() {
      Text(this.moment.text)
        ...
        
      if (this.moment.image !== '') {
        Flex({ wrap: FlexWrap.Wrap }) {
          Image($r(this.moment.image))
            .width(Constants.LAYOUT_MAX)
            .height('27.5%')
            .borderRadius(16)
          Image($r(this.moment.image))
            .width(Constants.LAYOUT_MAX)
            .height('27.5%')
            .borderRadius(16)
            .margin({ top: 10 })
        }
        .width(Constants.LAYOUT_MAX)
        .margin({ top: 14 })
      }
      ...
    }
  }
}
```
#### 正例
```typescript
@Entry
@Component
struct withoutReuseId {
  private momentData: FriendMomentsData = new FriendMomentsData();
  private readonly LIST_SPACE: number = 18;
  aboutToAppear(): void {
    this.momentData.getFriendMomentFromRawFile();
  }

  build() {
    Column() {
      List({ space: this.LIST_SPACE }) {
        LazyForEach(this.momentData, (moment: FriendMoment) => {
          ListItem() {
            OneMoment({ moment: moment })
              // 正例：使用reuseId
              .reuseId((moment.image !== '') ? 'withImage_id' : 'noImage_id')
          }
        }, (moment: FriendMoment) => moment.id)
      }
    }
  }
}

@Reusable
@Component
export struct OneMoment {
  @Prop moment: FriendMoment;

  build() {
    Column() {
      Text(this.moment.text)
        ...
        
      if (this.moment.image !== '') {
        Flex({ wrap: FlexWrap.Wrap }) {
          Image($r(this.moment.image))
            .width(Constants.LAYOUT_MAX)
            .height('27.5%')
            .borderRadius(16)
          Image($r(this.moment.image))
            .width(Constants.LAYOUT_MAX)
            .height('27.5%')
            .borderRadius(16)
            .margin({ top: 10 })
        }
        .width(Constants.LAYOUT_MAX)
        .margin({ top: 14 })
      }
      ...
    }
  }
}
```
#### 性能收益
在一段匀速滑动过程中，加载五条数据，未使用reuseId需要新建五次相关组件，使用reuseId只需要新建一次。
|              | 未使用reuseId | 使用reuseId |
| ------------ | ---- | ------ |
| **完成时延** | 254ms88μs   | 241ms911μs |

#### 高频程度&收益（5满分）
4

### 不建议使用@Prop装饰器
#### 类型
响应时延/完成时延
#### 解决方法
全局搜索@Prop并且替换
#### 反例
```typescript
@Observed
class Book {
  public c: number = 0;

  constructor(c: number) {
    this.c = c;
  }
}

@Component
struct PropChild {
  @Prop testNum: Book; // @Prop装饰状态变量会深拷贝

  build() {
    Text(`PropChild testNum ${this.testNum.c}`)
  }
}

@Entry
@Component
struct Parent1 {
  @State testNum: Book[] = [new Book(1)];

  build() {
    Column() {
      Text(`Parent testNum ${this.testNum[0].c}`)
        .onClick(() => {
          this.testNum[0].c += 1;
        })
      // PropChild没有改变@Prop testNum: Book的值，所以这时最优的选择是使用@ObjectLink
      PropChild({ testNum: this.testNum[0] })
    }
  }
}
```
#### 正例
```typescript
@Observed
class Book {
  public c: number = 0;

  constructor(c: number) {
    this.c = c;
  }
}

@Component
struct PropChild {
  @ObjectLink testNum: Book; // @ObjectLink装饰状态变量不会深拷贝

  build() {
    Text(`PropChild testNum ${this.testNum.c}`)
  }
}

@Entry
@Component
struct Parent2 {
  @State testNum: Book[] = [new Book(1)];

  build() {
    Column() {
      Text(`Parent testNum ${this.testNum[0].c}`)
        .onClick(() => {
          this.testNum[0].c += 1;
        })
      // 当子组件不需要发生本地改变时，优先使用 @ObjectLink，因为@Prop是会深拷贝数据，具有拷贝的性能开销，所以这个时候@ObjectLink是比@Link和 @Prop更优的选择
      PropChild({ testNum: this.testNum[0] })
    }
  }
}
```
#### 性能收益
|              | 使用@Prop装饰器 | 使用@ObjectLink装饰器 |
| ------------ | ---- | ------ |
| **完成时延** | 9.1ms   | 8.7ms |

#### 高频程度&收益（5满分）
4

### 避免在ResourceManager的getXXXSync接口入参中直接使用资源信息
#### 类型
响应时延/完成时延
#### 解决方法
排查ResourceManager.getXXXSync接口，查看入参时需要使用getStringSync($r('app.media.icon').id)的形式，
如果未使用需要整改。

#### 反例
```typescript
this.context.resourceManager.getStringSync($r('app.string.test'));
```
#### 正例
```typescript
this.context.resourceManager.getStringSync($r('app.string.test').id);
```
#### 性能收益
|              | 直接使用资源信息 | 未直接使用资源信息 |
| ------------ | ---- | ------ |
| **完成时延** | 12.1ms   | 9.7ms |

#### 高频程度&收益（5满分）
3

### 展示用的自定义组件（数据从父组件中获取，无独立数据处理）使用@Builder替换
#### 类型
响应时延/完成时延
#### 解决方法
审视@Component标记的自定义组件，如果里面没有独立的生命周期处理逻辑，数据由父组件传递，建议@Builder替代。
#### 反例
```typescript
@Entry
@Component
struct CEMineButtomView {
  build() {
    Column() {
       List({ space: 8 }) {
         ForEach(this.users, (item: User) => {
           ListItem() {
             UserCard({ name: item.name, age: item.age, avatarImage: item.avatarImage })
           }
         }, (item: User) => item.id)
       }.alignListItem(ListItemAlign.Center)
     }.width('100%')
      .height('100%')
  }
}

// 用户卡片自定义组件
@Component
struct UserCard {
  @Prop avatarImage: ResourceStr;
  @Prop name: string;
  @Prop age: number;

  build() {
    Row() {
      Row() {
        Image(this.avatarImage)
          .size({ width: 50, height: 50 })
          .borderRadius(25)
          .margin(8)
        Text(this.name)
          .fontSize(30)
      }

      Text(`年龄：${this.age.toString()}`)
        .fontSize(20)
    }
    ...
  }
}
```
#### 正例
```typescript
@Entry
@Component
struct CEMineButtomView {
  build() {
    Column() {
       List({ space: 8 }) {
         ForEach(this.users, (item: User) => {
           ListItem() {
             // 在build函数中使用@Builder函数  
             UserCardBuilder(item.name,item.age,item.avatarImage)
           }
         }, (item: User) => item.id)
       }.alignListItem(ListItemAlign.Center)
     }.width('100%')
      .height('100%')
  }
}

// 自定义@Builder函数组件
@Builder
function UserCardBuilder(name: string, age?: number, avatarImage?: ResourceStr) {
  Row() {
    Row(){
      Image(avatarImage)
        .size({width: 50, height: 50})
        .borderRadius(25)
        .margin(8)
      Text(name)
        .fontSize(30)
    }
    Text(`年龄：${age?.toString()}`)
      .fontSize(20)
  }
  ...
}
```
#### 性能收益
|              | 使用@Component | 使用@Builder |
| ------------ | ---- | ------ |
| **点击进入列表响应时延** | 410.1ms   | 394.9ms |
| **滑动列表响应时延** | 26ms   | 24.3ms |

#### 高频程度&收益（5满分）
3

### 删除无具体逻辑的生命周期，ArkUI的函数回调等，删除冗余堵塞日志打印
#### 类型
响应时延/完成时延/帧率
#### 解决方法
排查所有的aboutToAppear、aboutToDisappear等生命周期函数，排查ArkUI的回调函数，如果函数中无具体业务逻辑，
例如只打印了日志，删除函数回调。
#### 反例
```typescript
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct ViewA {
@State message: string = 'Hello World';
  aboutToAppear(): void {
    // 业务逻辑
    // ...
    for (let index = 0; index < 17; index++) {
      // 无具体业务逻辑的日志
      hilog.info(0x0000, 'TAG', '%{public}s', this.message);
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          ForEach(this.arr, (item: number) => {
            Text("ListItem" + item)
              .width("100%")
              .height(100)
          }, (item: number) => item.toString())
        }
      }
      ...
    }.width('100%')
    .height('100%')
  }
}
```
#### 正例
```typescript
@Entry
@Component
struct ViewA {
  // 仅剩下业务逻辑
  aboutToAppear(): void {
    // 业务逻辑
    // ...
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          ForEach(this.arr, (item: number) => {
            Text("ListItem" + item)
              .width("100%")
              .height(100)
          }, (item: number) => item.toString())
        }
      }
      ...
    }.width('100%')
    .height('100%')
  }
}
```
#### 性能收益
|              | 在aboutToAppear中打印18次无具体业务逻辑的日志 | 在aboutToAppear删除所有日志 |
| ------------ | ---- | ------ |
| **响应时延** | 48.9ms   | 39.2ms |

#### 高频程度&收益（5满分）
3

### 删除未关联组件的状态变量装饰器
#### 类型
响应时延/完成时延
#### 解决方法
排查全局的状态变量装饰器，如果变量未关联组件，删除装饰器。
#### 反例
```typescript
@Component
struct ComponentA {
  @State message: string = 'Hello World';
  @State realState1: Array<number> = [4, 1, 3, 2]; // 使用状态变量装饰器，未关联组件
  @State realStateColor: Color = Color.Yellow; // 使用状态变量装饰器，关联组件

  build() {
    Column(){
      Button(this.message)
        .fontSize(50)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textColor)
        .onClick(() => {
            // 改变realState1不会触发UI视图更新
            this.realState1.push(this.realState1[this.realState1.length-1] + 1);
            // 改变realStateColor触发UI视图更新
            this.realStateColor = this.realStateColor == Color.Yellow ? Color.Red : Color.Yellow;
          })
    }
  }
  .backgroundColor(this.realStateColor)
}
```
#### 正例
```typescript
@Component
struct ComponentA {
  @State message: string = 'Hello World';
  realState1: Array<number> = [4, 1, 3, 2]; // 未使用状态变量装饰器，未关联组件
  @State realStateColor: Color = Color.Yellow; // 使用状态变量装饰器，关联组件

  build() {
    Column(){
      Button(this.message)
        .fontSize(50)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textColor)
        .onClick(() => {
            // 改变realState1不会触发UI视图更新
            this.realState1.push(this.realState1[this.realState1.length-1] + 1);
            // 改变realStateColor触发UI视图更新
            this.realStateColor = this.realStateColor == Color.Yellow ? Color.Red : Color.Yellow;
          })
    }
  }
  .backgroundColor(this.realStateColor)
}
```
#### 性能收益

构造十个相关相关变量且都不关联组件。

|          | 使用状态变量装饰器，未关联组件 | 未使用状态变量装饰器，未关联组件 |
| :------- | :----------------------------- | :------------------------------- |
| **耗时** | 6ms722μs                       | 42μs708ns                        |

#### 高频程度&收益（5满分）

2

### crypto-js性能差
#### 类型
帧率
#### 解决方法
排查buffer.from关键字，加密建议使用原生的cryptoFramework，然后将buffer替换为base64helper，性能提升，且数据量越大越明显。

#### 反例
```typescript
new Uint8Array(buffer.from(str,'base64').buffer);
```
#### 正例
```typescript
let that = new util.Base64Helper();
let result = that.decodeSync(str);
```
#### 性能收益

|          | 使用buffer.from关键字 | 使用Base64Helper |
| :------- | :-------------------- | :--------------- |
| **耗时** | 85ms442μs             | 24ms144μs        |

#### 频程度&收益（5满分）

2

### 不建议使用Marquee组件
#### 类型
响应时延/完成时延
#### 解决方法
排查Marquee关键字，使用Text的跑马灯模式(TextOverflow.MARQUEE)替代。
#### 反例
```typescript
struct ViewA {
  build() {
    Column() {
      Marquee({
        start: this.start,
        step: this.step,
        loop: this.loop,
        fromStart: this.fromStart,
        src: this.src
      })
        .width(360)
        .height(80)
        .fontColor('#FFFFFF')
        .fontSize(48)
        .fontWeight(700)
        .backgroundColor('#182431')
        .margin({ bottom: 40 })
        .onStart(() => {
          console.info('Marquee animation complete onStart')
        })
        .onBounce(() => {
          console.info('Marquee animation complete onBounce')
        })
        .onFinish(() => {
          console.info('Marquee animation complete onFinish')
        })
    }.width("100%")
  }
}
```
#### 正例
```typescript
struct ViewB {
  build(){
    Column(){
      Text(reply.user)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE }) // 跑马灯模式
        .width("30%")
    }.width("100%")
  }
}
```
#### 性能收益

|                    | 使用Marquee | 未使用Marquee |
| :----------------- | :---------- | :------------ |
| **整页面渲染耗时** | 12ms473μs   | 7ms986μs      |

#### 高频程度&收益（5满分）

1

### 不能使用函数作为ArkUI组件的属性和组件复用的自定义组件的入参
#### 类型
完成时延
#### 解决方法
查看属性是否有xx()函数写法，确认函数/方法中是否有耗时操作，替换成变量。
#### 反例
```typescript
struct ViewA {
    
  // 真实场景的函数中可能存在未知的耗时操作逻辑，此处用循环函数模拟耗时操作
  countAndReturn(): number {
    let temp: number = 0;
    for (let index = 0; index < 100000; index++) {
      temp += index;
    }
    return temp;
  }
    
  build() {
    Column() {
      List() {
        LazyForEach(this.data, (item: string) => {
          ListItem() {
            // 此处sum参数是函数获取的，每次组件复用都会重复触发此函数的调用
            ChildComponent({ desc: item, sum: this.countAndReturn() })
          }.width('100%').height(100)
        }, (item: string) => item)
      }
    }
  }
}
```
#### 正例
```typescript
struct ViewB {
  @State sum: number = 0;

  aboutToAppear(): void {
    this.sum = this.count();
  }

  build() {
    Column() {
      List() {
        LazyForEach(this.data, (item: string) => {
          ListItem() {
            ChildComponent({ desc: item, sum: this.sum })
          }.width('100%').height(100)
        }, (item: string) => item)
      }
    }
  }
}
```
#### 性能收益

|                                | 使用函数            | 未使用函数          |
| :----------------------------- | :------------------ | :------------------ |
| **创建组件时长和构建组件时长** | 7μs291ns+599μs479ns | 5μs729ns+548μs958ns |

#### 高频程度&收益（5满分）

1

### 不建议使用.linearGradient颜色渐变属性
#### 类型
完成时延
#### 解决方法
排查linearGradient关键字，可以使用图片代替。
#### 反例
```typescript
Row()
  .linearGradient({
    angle: 90,
    colors: [[0xff0000, 0.0], [0x0000ff, 0.3], [0xffff00, 1.0]]
  })
```
#### 正例
```typescript
Image($r('app.media.gradient_color'))
```
#### 性能收益

|              | 使用linearGradient | 未使用linearGradient |
| :----------- | :----------------- | :------------------- |
| **完成时延** | 31.8ms             | 28.3ms               |

#### 高频程度&收益（5满分）

1

### 不要在for/while循环中执行耗时操作
#### 类型
完成时延/帧率
#### 解决方法
排查for/while循环，查看里面是否有打印日志或者Trace。
#### 反例
```typescript
@Component
struct ViewA {
  @State message: string = "";

  build() {
    Column() {
      Button('点击打印日志').onClick(() => {
        for (let i = 0; i < 10; i++) {
          // 逻辑操作
            ...
          console.info(this.message);
        }
      })
    }
  }
}
```
#### 正例
```typescript
@Component
struct ViewB {
  @State message: string = "";

  build() {
    Column() {
      Button('点击打印日志').onClick(() => {
        for (let i = 0; i < 10; i++) {
          // 逻辑操作
            ...
        }
      })
    }
  }
}
```
#### 性能收益

|          | 在for中打印日志 | 未在for中打印日志 |
| :------- | :-------------- | :---------------- |
| **耗时** | 32ms614μs       | 120μs312ns        |

#### 高频程度&收益（5满分）

1

### 变量初值不建议设置为undefined，需进行默认初始化
#### 类型
完成时延
#### 解决方法
例如number设置为0，string设置为空字符串等，这样在使用过程中更不需要增加额外判空。
排查类中的变量，看看是否有初始化为undefined。
#### 反例
```typescript
@State channels?: Channels[] = undefined;
```
#### 正例
```typescript
@State channels?: Channels[] = [];
```
#### 性能收益

|              | 设置为undefined | 未设置为undefined |
| :----------- | :-------------- | :---------------- |
| **完成时延** | 72.2ms          | 63.9ms            |

#### 高频程度&收益（5满分）

1


