# 桌面卡片实现案例

### 介绍

桌面卡片是比较常见的功能，本案例详细列举了卡片开发的大部分功能，如使用postCardAction接口快速拉起卡片提供方应用的指定UIAbility，通过message事件刷新卡片内容等，为开发者提供了卡片功能的展示。

### 效果图预览

![](../product/entry/src/main/resources/base/media/cases_card.gif)

### 使用说明

1. 长按应用，添加卡片到桌面。
2. 卡片内可滑动选择案例，点击可进入案例详情。
3. 部分案例无详情页时，点击跳转到首页瀑布流。

### 实现思路

1. 新建卡片
2. 配置formconfig
3. 编写卡片UI代码
4. 触发刷新事件
5. 触发点击事件

### 实现步骤

本例涉及的关键特性和实现方案如下：

1. 新建卡片。右键点击entry目录，选择新建->Service Widget->Dynamic Widget，其中Dynamic Widget为动态卡片，Static Widget为静态卡片。此时会生成几个文件：配置文件[```form_config.json```](../product/entry/src/main/resources/base/profile/form_config.json)；卡片Ability[```EntryFormAbility.ets```](../product/entry/src/main/ets/entryformability/EntryFormAbility.ets)；卡片组件[```WidgetCard.ets```](../product/entry/src/main/ets/widget/pages/WidgetCard.ets)。
2. 新建卡片后，根据需要（如卡片大小，刷新时间，动态静态卡片设置）配置```form_config.json```。
```json5
{
  "forms": [
    {
      "name": "widget", // 卡片的名称。
      "displayName": "$string:widget_display_name", // 卡片的显示名称。
      "description": "$string:widget_desc", // 卡片的描述。 
      "src": "./ets/widget/pages/WidgetCard.ets", // 卡片对应的UI代码的完整路径。
      "uiSyntax": "arkts", // 卡片的类型
      "window": { // 用于定义与显示窗口相关的配置。
        "designWidth": 720,
        "autoDesignWidth": true
      },
      "colorMode": "auto", // 卡片的主题样式。
      "isDynamic": true, // 卡片是否为动态卡片。
      "isDefault": true, // 卡片是否为默认卡片。
      "updateEnabled": true, // 卡片是否支持周期性刷新。
      "scheduledUpdateTime": "10:30", // 卡片的定点刷新的时刻。
      "updateDuration": 1, // 卡片定时刷新的更新周期，单位为30分钟，取值为自然数。
      "defaultDimension": "6*4", // 卡片的默认外观规格。
      "supportDimensions": [ // 卡片支持的外观规格，取值范围。
        "6*4"
      ]
    }
  ]
}
```
3. 编写卡片UI代码。在主文件```WidgetCard.ets```中添加UI组件，需要注意的是：ArkTS卡片存在较多约束（如不支持导入共享包），较多逻辑不可在卡片中使用，在使用时需要根据文档进行操作。
4. 编写跳转事件：当应用未被拉起时，点击某个卡片时跳转到具体的案例页面。在```EntryAbility.ets```中补充逻辑：onCreate生命周期内获取want.parameters.params判断卡片内容的跳转。
```typescript
// EntryAbility.ets
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // ...
    // 桌面卡片判断跳转内容
    if (want?.parameters?.params) {
      // want.parameters.params 对应 postCardAction() 中 params 内容
      let params: Record<string, Object> = JSON.parse(want.parameters.params as string);
      this.selectPage = params.targetPage as string;
    }
    // ...
  }
}
```
5. 编写跳转事件：当应用在后台时，点击某个卡片时跳转到具体的案例页面。可从onNewWant生命周期获取want.parameters.params判断卡片内容的跳转。
```typescript
// EntryAbility.ets
export default class EntryAbility extends UIAbility {
  // 如果UIAbility已在后台运行，在收到Router事件后会触发onNewWant生命周期回调
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (want?.parameters?.params) {
      // want.parameters.params 对应 postCardAction() 中 params 内容
      let params: Record<string, Object> = JSON.parse(want.parameters.params as string);
      this.selectPage = params.targetPage as string;
    } else {
      this.selectPage = '';
    }
    if (this.currentWindowStage !== null) {
      //  存在窗口时点击卡片后进行页面跳转
      if (this.selectPage) {
        waterFlowData.forEach((item: SceneModuleInfo) => {
          let index = item.appUri.indexOf(this.selectPage);
          if (index > -1) {
            if (DynamicsRouter.appRouterStack.slice(-1)[0].name !== item.appUri) {
              DynamicsRouter.clear();
              DynamicsRouter.pushUri(item.appUri);
            }
            return;
          }
        })
        this.selectPage = '';
      }
    }
  }
}
```
6. 具体跳转逻辑编写。在onWindowStageCreate生命周期内进行具体的跳转逻辑。
```typescript
// EntryAbility.ets
export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 判断是否存在窗口可进行页面跳转
    if (this.currentWindowStage === null) {
       this.currentWindowStage = windowStage;
    }
    //  点击卡片后进行页面跳转
    if (this.selectPage) {
      this.storage.setOrCreate('formNavigationRouter', this.selectPage);
      windowStage.loadContent('pages/EntryView', this.storage, (err, data) => {
        if (err.code) {
          logger.error(DOMAIN_NUMBER.toString(), TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
          return;
        }
        logger.info(DOMAIN_NUMBER.toString(), TAG, 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data) ?? '');
      });
    }
    // ...
   }
}
```
7. 编写跳转事件：在```EntryAbility.ets```编写事件后，同时在接收案例参数的```EntryView.ets```内处理页面跳转逻辑。通过和DynamicsRouter内的数据对比，判断通过storage传入的页面是哪一个，然后执行pushUri跳转。
```ets
@Entry(storage)
@Component
struct EntryView {
  onPageShow(): void {
  // 从卡片进入页面时判断具体跳转页面
  if (this.formRouter) {
    waterFlowData.forEach((item: SceneModuleInfo) => {
      let index = item.appUri.indexOf(this.formRouter);
      if (index > -1) {
        if (DynamicsRouter.appRouterStack.slice(-1)[0].name !== item.appUri) {
          DynamicsRouter.clear();
          DynamicsRouter.pushUri(item.appUri);
        }
        return;
      }
    })
    this.formRouter = '';
  }
}
}
```
8. 判断卡片大小：获取卡片详情，根据宽高比获取卡片的规格，不同规格显示内容不同。在```EntryFormAbility.ets```中补充点击卡片进入时查找对应案例的逻辑。在onAddForm生命周期内做卡片生成时，createFormBindingData方法传递属性。
```typescript
// EntryFormAbility.ets
export default class EntryFormAbility extends FormExtensionAbility {
   // 卡片对象集合
  onAddForm(want: Want): formBindingData.FormBindingData {
    let isLongCard: boolean = true;
    if ((want.parameters?.[formInfo.FormParam.WIDTH_KEY] as number) /
      (want.parameters?.[formInfo.FormParam.HEIGHT_KEY] as number) > 0.666) {
      isLongCard = false;
    }
    // 使用方创建卡片时触发，提供方需要返回卡片数据绑定类
    let obj: Record<string, string | boolean> = {
      'title': 'titleOnAddForm',
      'isLongCard': isLongCard
    };
    let formData: formBindingData.FormBindingData = formBindingData.createFormBindingData(obj);
    return formData;
  }
}
```
9. 编写刷新事件：当定时更新或定点更新触发时，需要更新卡片内容。onUpdateForm生命周期发生在定时更新/定点更新/卡片使用方主动请求更新时，在方法内增加获取案例数据的功能。
```typescript
// EntryFormAbility.ets
export default class EntryFormAbility extends FormExtensionAbility {
   // 网络获取README数据并利用formProvider.updateForm更新到卡片
   async getData(formId: string) {
      let detail: CASES[] = [];
      let httpRequest = http.createHttp();
      let webData: http.HttpResponse = await httpRequest.request(URL);
      if (webData?.responseCode == http.ResponseCode.OK) {
         try {
            detail = this.formatData(webData.result.toString());
            hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] onFormEvent' + 'webData.result:' + webData.result);

            class FormDataClass {
               detail: CASES[] = detail;
            }

            let formData = new FormDataClass();
            let formInfo = formBindingData.createFormBindingData(formData);
            await formProvider.updateForm(formId, formInfo);
            hilog.info(DOMAIN_NUMBER, TAG, '%{public}s', 'FormAbility updateForm success.');
         } catch (error) {
            hilog.error(DOMAIN_NUMBER, TAG, `FormAbility updateForm failed: ${JSON.stringify(error)}`);
         }
      } else {
         hilog.error(DOMAIN_NUMBER, TAG, `ArkTSCard download task failed`);
         let param: Record<string, string> = {
            'text': '刷新失败'
         };
         let formInfo: formBindingData.FormBindingData = formBindingData.createFormBindingData(param);
         formProvider.updateForm(formId, formInfo);
      }
      httpRequest.destroy();
   }

   async onUpdateForm(formId: string): Promise<void> {
      // 若卡片支持定时更新/定点更新/卡片使用方主动请求更新功能，则提供方需要重写该方法以支持数据更新
      hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] onUpdateForm');
      this.getData(formId);
   }
}
```
10. 编写刷新事件：手动刷新内容时，需要更新卡片内容。onFormEvent生命周期发生在卡片主动通过postCardAction接口触发message事件。
```typescript
// EntryFormAbility.ets
export default class EntryFormAbility extends FormExtensionAbility {
   // 网络获取README数据并利用formProvider.updateForm更新到卡片
   async getData(formId: string) {
      let detail: CASES[] = [];
      let httpRequest = http.createHttp();
      let webData: http.HttpResponse = await httpRequest.request(URL);
      if (webData?.responseCode == http.ResponseCode.OK) {
         try {
            detail = this.formatData(webData.result.toString());
            hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] onFormEvent' + 'webData.result:' + webData.result);

            class FormDataClass {
               detail: CASES[] = detail;
            }

            let formData = new FormDataClass();
            let formInfo = formBindingData.createFormBindingData(formData);
            await formProvider.updateForm(formId, formInfo);
            hilog.info(DOMAIN_NUMBER, TAG, '%{public}s', 'FormAbility updateForm success.');
         } catch (error) {
            hilog.error(DOMAIN_NUMBER, TAG, `FormAbility updateForm failed: ${JSON.stringify(error)}`);
         }
      } else {
         hilog.error(DOMAIN_NUMBER, TAG, `ArkTSCard download task failed`);
         let param: Record<string, string> = {
            'text': '刷新失败'
         };
         let formInfo: formBindingData.FormBindingData = formBindingData.createFormBindingData(param);
         formProvider.updateForm(formId, formInfo);
      }
      httpRequest.destroy();
   }

   async onFormEvent(formId: string, message: string): Promise<void> {
      this.getData(formId);
   }
}
```
11. 编写刷新事件：参数传到卡片组件内，组件接收参数。处理```WidgetCard.ets```卡片内逻辑。卡片页面中使用LocalStorageProp装饰需要刷新的卡片数据。
```ts
let casesCardInfo = new LocalStorage();
@Entry(casesCardInfo)
@Component
struct Widget_DynamicCard {
  @LocalStorageProp('detail') detail: CASES[] = []; // 卡片对象集合
  private swiperController: SwiperController = new SwiperController();
  @LocalStorageProp('isLongCard') isLongCard: boolean = false;

  build() {
    // ...
  }
}
```

### 高性能知识点

**不涉及**

### 参考资料

[创建一个ArkTS卡片](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-ui-widget-creation-V5)

[配置卡片的配置文件](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-ui-widget-configuration-V5)

[使用router事件跳转到指定UIAbility](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-ui-widget-event-router-V5)

[通过message事件刷新卡片内容](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-ui-widget-event-formextensionability-V5)
