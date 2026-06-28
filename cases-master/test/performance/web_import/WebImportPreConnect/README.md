# Web组件开发性能提升指导测试工程——预解析和预连接优化

## 原理介绍

WebView在onAppear阶段进行预连接socket， 当Web内核真正发起请求的时候会直接复用预连接的socket，如果当前预解析还没完成，真正发起网络请求进行DNS解析的时候也会复用当前正在执行的DNS解析任务。同理即使预连接的socket还没有连接成功，Web内核也会复用当前正在连接中的socket，进而优化资源的加载过程。  
@ohos.web.webview提供了prepareForPageLoad方法实现预连接url，在加载url之前调用此API，对url只进行DNS解析、socket建链操作，并不获取主资源子资源。  
参数：

| 参数名            | 类型      | 说明                                                                                        |
|----------------|---------|-------------------------------------------------------------------------------------------|
| url            | string  | 预连接的url。                                                                                  |
| preconnectable | boolean | 是否进行预连接。如果preconnectable为true，则对url进行DNS解析，socket建链预连接；如果preconnectable为false，则对url只进行DNS解析，不做任何预连接操作。 |
| numSockets     | number  | 要预连接的socket数。socket数目连接需要大于0，最多允许6个连接。   |

## 优化步骤

### 预启动WebEngine

```typescript
// EntryAbility.ets
// 开启预连接需要先使用上述方法预加载WebView内核。
webview.WebviewController.initializeWebEngine();
```

### 预连接即将加载的Url

```typescript
// EntryAbility.ets
// 启动预连接，连接地址为即将打开的网址。
webview.WebviewController.prepareForPageLoad("https://www.example.com", true, 2); 
```