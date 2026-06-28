# Navigation路由拦截案例

### 介绍

本示例介绍在Navigation中如何完成路由拦截：首次登录时记录登录状态，再次登录时可以直接访问主页无需重复登录，当退出登录时，下次需重新登录。

目前，已有三方库[HMRouter](https://ohpm.openharmony.cn/#/cn/detail/@hadss%2Fhmrouter)封装了完整的路由拦截功能，添加了生命周期回调、内置转场动画等功能，如有需要，可直接使用。

### 效果图预览

<img src="../../product/entry/src/main/resources/base/media/navigation_interceptor.gif" width="300">

**使用说明**
1. 点击Navigation路由拦截案例。
2. 在弹出的半模态页面中勾选"阅读并同意协议"，点击按钮"手机号码一键登录"。
3. 进入主页，点击返回上级页面按钮，重新点击Navigation路由拦截案例，即可直接进入主页，不需要重复登录。
4. 点击主页的"退出登录"按钮，退出案例，此时点击Navigation路由拦截案例需重新登录。

### 实现思路
1、在路由模块增加路由拦截器interceptor.ets，定义拦截容器、注册方法和公共拦截逻辑，[interceptor.ets](../routermodule/src/main/ets/interceptor/Interceptor.ets)
```typescript
/**
 * 定义拦截实现接口
 *
 * @param routerInfo 需要拦截的路由名
 * @param param 路由参数
 */
export interface InterceptorExecute {
executeFunction(router: RouterInfo, param?: string): boolean;
}

/**
 * 定义拦截器方法
 */
export class Interceptor {
  // 定义拦截器容器
  private static list: Array<InterceptorExecute> = [];

  /**
   * 注册拦截页面
   *
   * @param interceptorFnc 子模块传过来的自定义拦截函数
   */
  public static registerInterceptorPage(interceptorFnc: InterceptorExecute): void {
    Interceptor.list.push(interceptorFnc);
  }

  /**
   * 公共拦截器逻辑
   *
   * @param routerInfo 接收传过来的路由名
   * @param param 路由参数
   */
  public static interceptor(routerInfo: RouterInfo, param?: string): boolean {
    // 循环拦截器容器中所有的子模块自定义的拦截函数
    for (let i = 0; i < Interceptor.list.length; i++) {
      if (Interceptor.list[i].executeFunction(routerInfo, param))
        return true; // 如果子模块拦截函数返回true，即需要拦截
    }
    // 否则就放行
    return false;
  }
}

```
2、当点击本案例时，触发在路由模块的动态路由.pushUri()中的interceptor的公共拦截方法（此处需动态路由完成加载后执行否则首次路由拦截失败），[DynamcicsRouter.ets](../routermodule/src/main/ets/router/DynamicsRouter.ets)
```typescript
// 通过获取页面栈跳转到指定页面
public static pushUri(name: string, param?: ESObject) {
  // 如果是第一次跳转，则需要动态引入模块
  if (!DynamicsRouter.builderMap.has(name)) {
    // 动态引用模块，如“addressexchange”，和entry/oh-package.json中配置的模块名相同
    import(`${DynamicsRouter.config.libPrefix}/${routerInfo.pageModule}`)
      .then((module: ESObject) => {
        // 通过路由注册方法注册路由
        module[routerInfo.registerFunction!](routerInfo);
        // TODO：知识点：在路由模块的动态路由.pushUri()中调用拦截方法，此处必须等待动态路由加载完成后再进行拦截，否则页面加载不成功，导致无法注册拦截的函数，出现首次拦截失效。
        if (Interceptor.interceptor(name, param)) {
          return;
        }
      })
  } else {
    // TODO：知识点：除首次跳转后，之后的每次跳转都需进行路由拦截。
    if (Interceptor.interceptor(name, param)) {
      return;
    }
  }
}
```
3、子模块中定义业务具体拦截逻辑，做具体的拦截实现：通过routerInfo判断目的地为"我的页面"时判断登录状态是"未登录"，此时执行跳转到登录页并返回true给拦截容器list（告知需拦截），已登录返回false，放行。并且注册到拦截器容器list中，[interceptorPage.ets](../navigationinterceptor/src/main/ets/view/InterceptorPage.ets)。
```typescript
// 子模块实现拦截接口，做具体的拦截实现
export class MyPageInterceptorExecute implements InterceptorExecute {
  executeFunction(routerInfo: RouterInfo, param?: string): boolean {
    // 通过routerInfo判断目的地为"我的页面"时判断登录状态是"未登录"，此时执行跳转到登录页并返回true给拦截容器list（告知需拦截），已登录返回false，放行。
    if (routerInfo !== undefined && routerInfo.pageName === RouterInfo.NAVIGATION_INTERCEPTOR.pageName) {
      // 如果未登录
      if (!AppStorage.get("login")) {
        // 跳转登录页
        DynamicsRouter.push(RouterInfo.MULTI_MODAL_TRANSITION, param);
        return true; // true：路由拦截
      } else {
        return false; // false：否则放行
      }
    }
    // 通过routerInfo判断目的地为"登录页面"时放行。
    if (routerInfo !== undefined && routerInfo.pageName === RouterInfo.MULTI_MODAL_TRANSITION.pageName) {
      return false;
    }
    return false; // false，路由放行
  }
}

// 拦截器注册拦截函数
Interceptor.registerInterceptorPage(new MyPageInterceptorExecute());
```
4、拦截器获取拦截容器list中所有注册过的子模块的拦截函数，如果子模块拦截函数返回true，即需要拦截，否则放行。
```typescript
/**
 * 公共拦截器逻辑
 *
 * @param routerInfo 接收传过来的路由名
 * @param param 路由参数
 */
public static interceptor(routerInfo: RouterInfo, param?: string): boolean {
  // 循环拦截器容器中所有的子模块自定义的拦截函数
  for (let i = 0; i < Interceptor.list.length; i++) {
    if (Interceptor.list[i].executeFunction(routerInfo, param))
      return true; // 如果子模块拦截函数返回true，即需要拦截
  }
  // 否则就放行
  return false;
}
```
5、通过循环拦截容器list得到返回true时通知动态路由不再继续跳转, 否则返回false，通知动态路由继续执行跳转，跳转到我的页面，[DynamcicsRouter.ets](../routermodule/src/main/ets/router/DynamicsRouter.ets)。
```typescript
// 通过获取页面栈跳转到指定页面
public static async push(routerInfo: RouterInfo, param?: string): Promise<void> {
  if (isImportSucceed) {
    // 当返回true时执行拦截，通知动态路由不再继续跳转
    if (Interceptor.interceptor(routerInfo, param)) {
      return;
    }
    ... // 当返回false，通知动态路由继续执行跳转，跳转到我的页面
  }
```
6、在登录页点击：本机号码一键登录后，登陆成功，登陆状态置为true，且跳转到主页，[HalfModalWindow](../multimodaltransion/src/main/ets/view/HalfModalWindow.ets)
```typescript
Button($r('app.string.multimodaltransion_phone_start_login'))
  .onClick(() => {
    if (this.isConfirmed) {
      AppStorage.set("login", true); // 登录状态置为已登录
      DynamicsRouter.pop();
      DynamicsRouter.push(RouterInfo.NAVIGATION_INTERCEPTOR); // 路由跳转
    })
```

7、详情页中点击：注销登录，登录状态置为false，退出登录，[interceptorPage.ets](../navigationinterceptor/src/main/ets/view/InterceptorPage.ets)
```typescript
@StorageLink('login') hasLogin: boolean = true;
        
Button($r('app.string.naviagtion_interceptor_loginout'))
  .onClick(() => {
    this.hasLogin = false; // 注销登录
    DynamicsRouter.pop(); // 退出登录
  })
  .width("100%")
```
### 高性能知识点

不涉及

### 工程结构&模块类型

   ```
   navigationinterceptor                           // har类型
   |---src/main/ets/view
   |   |---interceptorPage.ets                     // 视图层-主页
   |---src/main/ets/model
   |   |---DataModel.ets                           // 模型层-数据模块
   routermodule                                    // har类型
   |---src/main/ets/interceptpr
   |   |---interceptor.ets                         // 模型层-拦截器方法类
   |---src/main/ets/router
   |   |---DynamticRouter.ets                      // 模型层-动态路由方法类
   ```

### 模块依赖

[har包-common库中UX标准](../../common/utils/src/main/resources/base/element)  
[routermodule(动态路由)](../../common/routermodule)

### 参考资料

[Navigation参考文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V2/arkts-navigation-navigation-0000001453365116-V2)