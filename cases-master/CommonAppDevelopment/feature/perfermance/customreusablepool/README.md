# 全局自定义组件复用实现案例

### 介绍

本示例是[全局自定义组件复用实现](../../../../docs/performance/node_custom_component_reusable_pool.md)的示例代码，主要讲解如何通过BuilderNode创建全局的自定义组件复用池，实现跨页面的组件复用。

### 效果图预览

![](../../../product/entry/src/main/resources/base/media/custom_reusable_pool.gif)

**使用说明**

1. 继承NodeController，实现可复用的NodeItem组件。
2. 使用单例模式创建NodePool组件复用池，根据传入的type类型查找复用池中是否存在可复用的组件，如果有则直接使用，如果没有则重新创建。
3. 使用NodeContainer组件占位，从复用池NodePool中获取组件加载到页面中。

### 实现思路

1. 使用List+Swiper实现Tabs页面切换，详细代码请参考[BuilderNodePoolDemo.ets](src/main/ets/pages/BuilderNodePoolDemo.ets)。

     ```typescript
     ...
     Swiper(this.swiperController) {
       LazyForEach(this.array, () => {
         TabNode()
       }, (title: string) => title)
     }
     ...
     ```

2. 继承NodeController，实现makeNode，用于组件的创建或刷新，并在组件隐藏时（aboutToDisappear）回收组件，详细代码请参考[BuilderNodePool.ets](src/main/ets/utils/BuilderNodePool.ets)中的NodeItem实现。

   ```typescript
   export class NodeItem extends NodeController {
     private callback: UpdaterCallback | null = null;
     ...
     // 父类方法，用于创建子组件
     makeNode(uiContext: UIContext): FrameNode | null {
       if (!this.node) {
         this.node = new BuilderNode(uiContext);
         this.node.build(this.builder, this.data);
       } else {
         this.node.update(this.data);
         this.update(this.data);
       }
       return this.node.getFrameNode();
     }
     // 组件隐藏时回收组件
     aboutToDisappear(): void {
       NodePool.getInstance().recycleNode(this.type, this);
     }
     ...
   }
   ```
   
3. 使用单例模式实现复用池，应用内统一管理组件复用。添加getNode方法，根据传入的type参数，获取对应的Node组件，如果未找到，则重新创建，实现recycleNode方法，回收Node组件，详细代码请参考[BuilderNodePool.ets](src/main/ets/utils/BuilderNodePool.ets)中的NodePool实现。

   ```typescript
   ...
   export class NodePool {
     private static instance: NodePool;
     ...
   
     private constructor() {
       this.nodePool = new HashMap();
       this.nodeHook = new HashSet();
       this.idGen = 0;
     }
     // 单例模式，可以全局统一管理
     public static getInstance() {
       if (!NodePool.instance) {
         NodePool.instance = new NodePool();
       }
       return NodePool.instance;
     }
     ...
     public getNode(type: string, data: ESObject, builder: WrappedBuilder<ESObject>): NodeItem | undefined {
       let node: NodeItem | undefined = this.nodePool.get(type)?.pop();
       if (!node) {
         node = new NodeItem(builder, data, type);
         this.nodeHook.add(node);
       } else {
         node.data = data;
       }
       node.data.callback = (callback: UpdaterCallback) => {
         if (node) {
           node.registerUpdater(callback);
         }
       }
       return node;
     }
     // 回收Node组件，提供给下次复用
     public recycleNode(type: string, node: NodeItem) {
       let nodeArray: Array<NodeItem> = this.nodePool.get(type);
       if (!nodeArray) {
         nodeArray = new Array();
         this.nodePool.set(type, nodeArray);
       }
       nodeArray.push(node);
     }
   }
   ...
   ```
   
4. 使用NodeContainer占位轮播图组件和瀑布流子组件的位置，并通过NodePool获取组件加载到页面中，详细代码请参考[TabNode.ets](src/main/ets/view/TabNode.ets)。

   ```typescript
   ...
   FlowItem() {
     NodeContainer(NodePool.getInstance().getNode('reuse_type_', {
       item: item,
       itemHeight: this.itemHeightArray[index % 100],
       itemColor: this.colors[index % 5],
       updater: (item: ViewItem) => {
         this.fillNewData(item);
       },
       callback: null
     }, flowItemWrapper))
   }
   ...
   ```

### 高性能知识点

通过BuilderNode实现全局自定义组件复用池，解决常规复用中只能在父组件中复用的问题，实现组件的跨父组件、跨页面复用，减少页面的创建耗时，优化应用性能。

### 工程结构&模块类型
   ```
   customreusablepool                                 // har类型
   |---constants                                      // 常量
   |---|---Constants.ets                              // 常量类
   |---data                                           // 数据类型
   |---|---MockData.ets                               // 模拟数据
   |---|---TitleBean.ets                              // 标题类
   |---|---TitleDataSource.ets                        // 标题懒加载数据类   
   |---|---ViewItem.ets                               // 瀑布流子组件数据类
   |---|---WaterFlowDataSource.ets                    // 瀑布流子组件懒加载数据类
   |---pages                                          // 页面   
   |---|---BuilderNodePoolDemo.ets                    // 全局自定义组件复用池页面               
   |---utils                                          // 工具类
   |---|---BuilderNodePool.ets                        // 自定义组件复用池
   |---view                                           // 组件   
   |---|---FlowItemNode.ets                           // 自定义组件复用池的瀑布流子组件
   |---|---TabNode.ets                                // 自定义组件复用池的Swiper页面   
   |---|---TitleView.ets                              // 标题View   
   |---|---SwiperView.ets                             // 瀑布流中的轮播图
   ```

### 参考资料

[BuilderNode](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/js-apis-arkui-builderNode.md#buildernode)

[NodeContainer](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-nodecontainer.md#nodecontainer)

[NodeController](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/js-apis-arkui-nodeController.md)

