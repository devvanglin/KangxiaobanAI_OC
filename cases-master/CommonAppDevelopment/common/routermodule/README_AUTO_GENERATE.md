# 自动生成动态路由

### 介绍

本示例将介绍如何使用装饰器和插件，自动生成动态路由表，并通过动态路由跳转到模块中的页面，以及如何使用动态import的方式加载模块。

目前，已有三方库[HMRouter](https://ohpm.openharmony.cn/#/cn/detail/@hadss%2Fhmrouter)封装了完整的动态路由功能，添加了生命周期回调、内置转场动画等功能，如有需要，可直接使用。

**使用说明**

1. 自定义装饰器。
2. 添加装饰器和插件配置文件，编译时自动生成动态路由表。
3. 配置动态路由，通过WrapBuilder接口，动态创建页面并跳转。
4. 动态import变量表达式，需要DevEco Studio NEXT Developer Preview1 （4.1.3.500）版本IDE，配合hvigor 4.0.2版本使用。
5. 支持自定义路由栈管理，相关内容请参考[路由来源页的相关说明](README_ROUTER_REFERRER.md)。

### 实现思路

#### [动态路由的实现](src/main/ets/router/DynamicsRouter.ets)

1. 初始化动态路由。

    ```ts
     public static routerInit(config: RouterConfig, context: Context) {
       DynamicsRouter.config = config;
       DynamicsRouter.appRouterStack.push(HOME_PAGE);
       RouterLoader.load(config.mapPath, DynamicsRouter.routerMap, context);
     }
    ```

2. 获取路由。

    ```ts
    private static getNavPathStack(): NavPathStack {
      return DynamicsRouter.navPathStack;
    }
    ```

3. 通过builderName，注册WrappedBuilder对象，用于动态创建页面。

    ```ts
    private static registerBuilder(builderName: string, builder: WrappedBuilder<[object]>): void {
      DynamicsRouter.builderMap.set(builderName, builder);
    }
    ```
   
4. 通过builderName，获取注册的WrappedBuilder对象。

    ```ts
    public static getBuilder(builderName: string): WrappedBuilder<[object]> {
      let builder = DynamicsRouter.builderMap.get(builderName);
      if (!builder) {
        let msg = "not found builder";
        console.info(msg + builderName);
      }
      return builder as WrappedBuilder<[object]>;
    }
    ```

5. 通过页面栈跳转到指定页面。

    ```ts
    public static pushUri(name: string, param?: Object) {
      if (!DynamicsRouter.routerMap.has(name)) {
        return;
      }
      let routerInfo: AppRouterInfo = DynamicsRouter.routerMap.get(name)!;
      if (!DynamicsRouter.builderMap.has(name)) {
        import(`${DynamicsRouter.config.libPrefix}/${routerInfo.pageModule}`)
          .then((module: ESObject) => {
            module[routerInfo.registerFunction!](routerInfo);
            DynamicsRouter.navPathStack.pushPath({ name: name, param: param });
        })
          .catch((error: BusinessError) => {
            logger.error(`promise import module failed, error code:${error.code}, message:${error.message}`);
        });
      } else {
        DynamicsRouter.navPathStack.pushPath({ name: name, param: param });
        DynamicsRouter.pushRouterStack(routerInfo);
      }
    }
    ```

6. 注册动态路由跳转的页面信息。

    ```ts
    public static registerAppRouterPage(routerInfo: AppRouterInfo, wrapBuilder: WrappedBuilder<[object]>): void {
      const builderName: string = routerInfo.name;
      if (!DynamicsRouter.builderMap.has(builderName)) {
        DynamicsRouter.registerBuilder(builderName, wrapBuilder);
      }
    }
    ```

#### 动态路由的使用

1. 在工程的hvigor/hvigor-config.json5中配置插件。

   ```json
   {
       ...
       "dependencies": {
           ...
           "@app/ets-generator": "file:../plugin/AutoBuildRouter"
       }
   }
   ```

2. 在工程的根目录的build-profile.json5中添加动态路由模块和需要加载的子模块的依赖，详细代码参考[build-profile.json5](../../build-profile.json5)。

    ```
    {
      "app":{
        ...
      }
      "modules":{
        ...
        {
          "name": "eventpropagation",
          "srcPath": "./feature/eventpropagation"
        },
        {
          "name": "routermodule",
          "srcPath": "./common/routermodule"
        }
        ...
      }
    }
    ```

3. 在主模块中添加动态路由和需要加载的子模块的依赖，详细代码请参考[oh-package.json](../../product/entry/oh-package.json5)。

    ```
    "dependencies": {
      "routermodule": "file:../../common/routermodule",    
      "event-propagation": "file:../../feature/eventpropagation",
      ...
    }
    ```

4. 在主模块中添加动态import变量表达式需要的参数，此处在packages中配置的模块名必须和[oh-package.json](../../product/entry/oh-package.json5)中配置的名称相同，详细代码请参考[build-profile.json5](../../product/entry/build-profile.json5)。

    ```
    ...
    "buildOption": {
      "arkOptions": {
        "runtimeOnly": {
          "packages": [
            "event-propagation",
            ...
          ]
        }
      }
    }
    ```

5. 在主模块EntryAbility的onCreate接口初始化动态路由，详细代码请参考[EntryAbility.ets](../../product/entry/src/main/ets/entryability/EntryAbility.ets)。

    ```ts
    ...
    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
      DynamicsRouter.routerInit({
        libPrefix: "@ohos", mapPath: "routerMap"
      }, this.context);
      ...
    }
    ...
    ```

6. 在主模块的WaterFlowData.ets中，将子模块要加载的页面，添加到列表中，详细代码请参考[WaterFlowData.ets](../../product/entry/src/main/ets/data/WaterFlowData.ets)和[SceneModuleInfo](../../feature/functionalscenes/src/main/ets/model/SceneModuleInfo.ets)。

    ```ts
    export const waterFlowData: SceneModuleInfo[] = [
      ...
      new SceneModuleInfo($r('app.media.address_exchange'), '地址交换动画', new RouterInfo("", ""), '动效', 2, "addressexchange/AddressExchangeView"),
      ...
    }
    ```

7. 在需要加载时将页面放入路由栈，详细代码请参考[FunctionalScenes.ets](../../feature/functionalscenes/src/main/ets/FunctionalScenes.ets)。

    ```ts
    @Builder
    methodPoints(listData: ListData) {
      Column() {
      ...
        .onClick(() => {
          ...
          DynamicsRouter.pushUri(this.listData.appUri);
          ...
        })
    }
    
    ```

8. 在子模块中添加动态路由的依赖，详细代码可参考[oh-package.json](../../feature/eventpropagation/oh-package.json5)。

    ```
    ...
    "dependencies": {
      ...
      "routermodule": "file:../../common/routermodule"
    }
    ```

**以上是需要在主模块中添加的配置，如果已经添加过相关代码，则可以直接略过，按照下面的步骤在子模块中添加相关即可自动生成动态路由相关文件。**

1. 在子模块的oh-package.json5中添加路由模块依赖，可参考[oh-package.json5](../../feature/addressexchange/oh-package.json5)。

   ```typescript
   {
     ...
     "dependencies": {
       ...
       // 动态路由模块，用于配置动态路由
       "routermodule": "file:../../common/routermodule"
     }
   }
   ```

2. 在子模块的hvigorfile.ts文件中添加插件配置，可参考[hvigorfile.ts](../../feature/addressexchange/hvigorfile.ts)。

   ```typescript
   ...
   import { PluginConfig, etsGeneratorPlugin } from '@app/ets-generator';
   // 配置路由信息
   const config: PluginConfig = {
     // 需要扫描的文件的路径，即配置自定义装饰AppRouter的文件路径
     scanFiles: ["src/main/ets/view/AddressExchangeView"]
   }
   
   export default {
     ...
     plugins: [etsGeneratorPlugin(config)]         /* Custom plugin to extend the functionality of Hvigor. */
   }
   ```
3. 在需要跳转的页面的自定义组件上添加装饰器，可参考[AddressExchangeView.ets](../../feature/addressexchange/src/main/ets/view/AddressExchangeView.ets)，如果需要通过路由传递参数，则需要设置hasParam为true，可参考[NavigationParameterTransferView.ets](../../feature/navigationparametertransfer/src/main/ets/view/NavigationParameterTransferView.ets)。
   
   ```typescript
   // 自定义装饰器，用于自动生成动态路由代码及页面的跳转。命名规则：模块名/自定义组件名
   @AppRouter({ name: "addressexchange/AddressExchangeView" })
   @Component
   export struct AddressExchangeView {
     ...
   }
   ```

## 自定义装饰器入参支撑常量写法

### 介绍

开发者在har包中使用原有的装饰器+路由路径实现动态路由之外，还可将路由路径存入常量文件内，通过在装饰器中输入文件路径和常量名，实现固定文件管理路由路径常量。

**使用说明**

1. 新增自定义装饰器参数。
2. 新增路由常量文件，在入口页面路由装饰器内传入常量文件相对路径和路由常量名。
3. 修改动态路由插件内解析装饰器方法，解析传入的字符串，通过相对路径实现在编译时获取对应常量文件，并根据常量名获取对应路由路径。
4. 编译修改后的路由插件，重新部署到工程内。

### 实现思路

1. 新增自定义装饰器参数，用于在页面装饰器内传入文件路径和路由常量名。[自定义装饰器AppRouter](./src/main/ets/annotation/AppRouter.ets)。

   ```typescript
   // 装饰器参数
   export interface AppRouterParam {
     // 跳转的路由名
     name?: string;
     // 是否需要传递参数，需要的话设置为true，否则可不需要设置。
     hasParam?: boolean;
     // 新增路由参数
     routeLocation?: string;
   }
   ```

2. 修改前，需向装饰器的name参数中传入 **feature包名/入口文件名** 字符串，示例如下（以feature包[citysearch](../../feature/citysearch/src/main/ets/view/CitySearch.ets)为例）：

   ```javascript
   @AppRouter({ name: "citysearch/CitySearch" })
   ```

   修改后，新增常量文件A。常量文件A的写法如下：

   ```typescript
   // ../../A.ets
   // ROUTE_LOCATION为路由常量，存入原有的路由（包名/入口文件名）
   const ROUTE_LOCATION: string = 'citysearch/CitySearch';
   ```

   将常量文件对于入口页面的相对路径和路由常量名以 **相对路径,常量名** 的格式传入装饰器中。示例如下：

   **"../../A.ets,ROUTE_LOCATION"**

   在[citysearch](../../feature/citysearch/src/main/ets/view/CitySearch.ets)页面的路由装饰器中向新增的routeLocation参数传入字符串。示例如下：

   ```typescript
   // 以（相对路径,常量名）格式将字符串传入新增路由参数routeLocation
   @AppRouter({ routeLocation: "../../A.ets,ROUTE_LOCATION" })
   ```
   
   * 修改前的路由参数写在应用页面里，不方便维护。本案例实现在固定文件内以常量形式保存路由路径，方便统一管理和后续维护。
   * 开发者可根据自身需要自定义传参的字符串格式，然后在第3步修改解析字符串的方法即可。

3. 修改工程中plugin/AutoBuildRouter插件，新增编译器对新增路由参数的解析。

   首先找到[index.ts](../../plugin/AutoBuildRouter/src/index.ts)文件中解析装饰器方法`resolveDecoration`，在遍历装饰器中的所有参数时添加对路由参数`routeLocation`的解析。 由于本案例使用`字符串,字符串`的格式传参，故选择用split方法分隔字符串。开发者若使用自定义格式传参，可根据分隔符自定义分隔方法。

   ```typescript
   import ts from "typescript";
   // 解析装饰器
   resolveDecoration(node: ts.Node) {
     // ...
     // 遍历装饰器中的所有参数
     properties.forEach((propertie) => {
       if (propertie.kind === ts.SyntaxKind.PropertyAssignment) {
         // 参数是否是自定义装饰器中的变量名
         if ((propertie.name as ts.Identifier).escapedText === "name") {
           // ...
         } else if ((propertie.name as ts.Identifier).escapedText === "hasParam") {
           // ...
         } else if ((propertie.name as ts.Identifier).escapedText === "routeLocation") {
           //TODO:知识点： 新增routeLocation参数解析方法
           // 解析参数内容
           const routeLocationStr = (propertie.initializer as ts.StringLiteral).text;
           // 分隔字符串
           const routeLocationArray = routeLocationStr.split(",");
           // 使用path.resolve方法将参数中相对路径和当前入口文件绝对路径组合，获取常量文件的绝对路径
           const locationSrc = path.resolve(this.sourcePath, routeLocationArray[0]);
           // 读取文件，生成文件字符串
           const locationCode = readFileSync(locationSrc, "utf-8");
           // 解析文件，生成节点树信息
           const locationFile = ts.createSourceFile(locationSrc, locationCode, ts.ScriptTarget.ES2021, false);
           // 遍历节点信息
           ts.forEachChild(locationFile, (node: ts.Node) => {
             // 解析节点，通过node节点的kind属性对应常量文件表达式的方法获取常量名和值
             if(node.kind === ts.SyntaxKind.VariableStatement) {
               const locationDecorator = node as ts.VariableStatement;
               const variableStatement = locationDecorator.declarationList as ts.VariableDeclarationList
                 // 遍历文件中的所有常量
                 variableStatement.declarations.forEach((value,index) => {
                   const identifier = value.name as ts.Identifier
                   // 判断循环中当前常量名是否等于传参内常量名
                   if(identifier.escapedText === routeLocationArray[1]) {
                     const routeName = value.initializer as StringLiteral
                     // 将对应常量名的路由值传出
                     this.analyzeResult.name = routeName.text
                   }
                 })
             }
           });
         }
       }
     })
   }
   ```
   * 注：在遍历节点信息时，可使用JSON.stringify方法打印节点树，根据json对象的kind值对照ts.SyntaxKind枚举值判断节点属性。

4. 修改插件后，需将[package.json](../../plugin/AutoBuildRouter/package.json)内版本号提升，打包后替换到[libs](../../libs)文件内。

   ```json5
   {
      "name": "autobuildrouter",
      "version": "1.0.2",
      // ...
   }
   ```

   修改[hvigor-config.json5](../../hvigor/hvigor-config.json5)内插件路径。

   ```json5
   {
     "modelVersion": "5.0.0",
     "dependencies": {
       // 修改插件版本号
       "@app/ets-generator": "file:../libs/autobuildrouter-1.0.2.tgz",
       "@app/ets-decoration-generator": "file:../libs/autobuilddecoration-1.0.2.tgz"
     }
   }
   ```

### 高性能知识点

本示例使用动态import的方式加载模块，只有需要进入页面时才加载对应的模块，减少主页面启动时间和初始化效率，减少内存的占用。

### 工程结构&模块类型

   ```
   routermodule                                  // har类型
   |---annotation
   |---|---AppRouter.ets                         // 自定义装饰器
   |---constants
   |   |---RouterInfo.ets                        // 路由信息类，用于配置动态路由跳转页面的名称和模块名（后续会删除）
   |---model
   |   |---AppRouterInfo.ets                     // 路由信息类
   |   |---RouterParam.ets                       // 路由参数
   |---router
   |   |---DynamicsRouter.ets                    // 动态路由实现类
   |---util
   |   |---RouterLoader.ets                      // 路由表加载类
   ```

### 模块依赖

**不涉及**

### 参考资料

[动态路由Sample](../../../test/performance/dynamicRouter/)

### FAQ

Q：动态路由用起来比较麻烦，为什么不直接使用系统提供的页面路由，而是要重写一套路由栈管理？

A：系统层面现在提供了两种方式进行页面跳转，分别是[页面路由 (@ohos.router)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-routing-V5)和[组件导航 (Navigation)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-navigation-navigation-V5)。这两种方式用起来都比较简单，但是Router相较于Navigation缺少很多能力（具体可参考[Router和Navigation能力对标](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-router-to-navigation-V5#能力对标)），所以目前应用开发中推荐使用Navigation进行页面跳转。

而使用Navigation时存在一个问题，需要将跳转的子页面组件通过import的方式引入，即不论子页面是否被跳转，都会使子页面引用的部分组件被初始化。例如页面A使用Navigation跳转到页面B，页面B中有用到Web组件加载一个H5页面。那么当进入页面A时，就会初始化Web组件相关的so库。即使用户只是在页面A停留，并没有进入页面B，也会在进入页面A时多出一部分初始化so库的时间和内存。这是因为在页面A中会直接import页面B的自定义组件，导致so库提前初始化。这样就会导致主页面启动耗时延长，以及不必要的内存消耗。

由于动态路由使用了动态import实现，可以很好的避免这种情况的发生。只有在进入子页面时，才会去初始化子页面的相关组件，减少主页面的启动时间和内存占用，提升性能。而且由于使用了自定义路由栈，可以定制业务上的需求，更好的进行管理。

当主页面中需要跳转的子页面较少时，使用Navigation更加方便。反之，则更推荐使用动态路由进行跳转。