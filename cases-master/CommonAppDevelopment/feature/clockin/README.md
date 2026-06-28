# 地图定位打卡案例

### 介绍

本示例使用[geoLocationManager](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-geolocationmanager-V5)进行地理位置定位和地理信息获取，并利用[MapComponent](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/map-mapcomponent-V5)组件展示地图，添加用户位置和打卡范围，通过计算用户位置和打卡中心点的距离判断用户是否处于打卡区域，实现了打卡功能。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/clock_in.gif)

**使用说明**

1. 首次启动应用时，授权获取定位权限，地图会移动到用户的当前位置，并在用户位置显示标记和打卡区域。
2. 点击右下角定位按钮，地图会移动到用户当前位置。
3. 点击上班打卡，如果用户处于打卡范围内，界面显示上班打卡信息，否则提示“打卡范围外，请先前往打卡范围打卡”。
4. 点击下班打卡，如果用户处于打卡范围内，界面显示下班打卡信息，否则提示“打卡范围外，请先前往打卡范围打卡”。
5. 点击更新打卡，如果用户处于打卡范围内，界面更新下班打卡信息，否则提示“打卡范围外，请先前往打卡范围打卡”。

> 注意：本示例需要打开位置定位和联网使用。

### 开发准备

使用本示例前，需要先完成以下准备工作。
   
1. 在华为开发者联盟网站上，[注册成为开发者](https://developer.huawei.com/consumer/cn/doc/start/registration-and-verification-0000001053628148)，并完成[实名认证](https://developer.huawei.com/consumer/cn/doc/start/rna-0000001062530373)，从而享受联盟开放的各类能力和服务。
2. 在[AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)（简称AGC）上，参考[创建项目](https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-createproject-0000001100334664)和[创建应用](https://developer.huawei.com/consumer/cn/doc/app/agc-help-createharmonyapp-0000001945392297)完成HarmonyOS应用的创建，从而使用各类服务。
3. 登录[AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)平台，在“我的项目”中选择目标应用，参考[配置Client ID](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/map-config-agc-V5)将应用的Client ID配置到工程中entry模块的module.json5文件中，然后在AGC平台[开通地图服务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/map-config-agc-V5#section16133115441516)。 
4. 连接设备后，工程使用[自动签名](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-signing-V5#section151231211105010)生成数字证书（.cer），在AGC网站的“证书、APP ID和Profile”页签中可以查看生成的调试证书。
5. 在[AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)（简称AGC）上，参考[添加公钥指纹（HarmonyOS API 9及以上）](https://developer.huawei.com/consumer/cn/doc/app/agc-help-signature-info-0000001628566748#section5181019153511)为应用添加公钥指纹，指纹配置成功后大约10分钟左右，设备联网即可使用地图服务。

### 实现思路

ClockInComponent是一个用于显示地图、获取用户位置、判断用户是否在打卡范围内的自定义功能组件。它使用了MapComponent组件来显示地图，geoLocationManager接口来获取用户位置，并通过计算用户位置与打卡圆心之间的距离来判断用户是否在打卡范围内。源码参考[ClockInComponent.ets](./src/main/ets/components/ClockInComponent.ets)。

1. 使用MapComponent组件初始化地图，设置地图初始位置和缩放级别。
  ```ts
  // 地图初始化参数，设置地图中心点坐标及层级
  mapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: 39.9,
        longitude: 116.4
      },
      zoom: 14
    }
  };

  MapComponent({
    mapOptions: this.mapOptions,
    mapCallback: this.mapCallback,
    customInfoWindow: (markerDelegate: map.MarkerDelegate) => {
      this.customInfoWindowBuilder(markerDelegate);
    }
  })
  ```
2. 在地图上绘制打卡范围和位置标记。
   
   - 在地图初始化回调函数中获取地图控制器和地图监听事件管理器，隐藏缩放控件和设置地图和边界的距离
    ```ts
    initMap() {
      // 地图初始化的回调
      this.mapCallback = async (err, mapController) => {
        if (!err) {
          // 获取地图控制器，用来操作地图
          this.mapController = mapController;
          if (this.getMapController) {
            this.getMapController(this.mapController);
          }
          // 获取地图监听事件管理器
          this.mapEventManager = this.mapController.getEventManager();
          // 隐藏缩放控件
          this.mapController.setZoomControlsEnabled(false);
          // 设置地图和边界的距离
          this.mapController.setPadding(this.mapPadding);
          // ...
        } else {
          logger.error(TAG, `mapcomponent init failed, error message: ${err.message}, error code: ${err.code}`);
        }
      };
    }
    ```
   - 监听地图加载完成事件，地图加载完成回调中验证应用是否拥有定位权限，无权限则弹窗向用户申请授权
    ```ts
    initMap() {
      // 地图初始化的回调
      this.mapCallback = async (err, mapController) => {
        if (!err) {
          // ...
          let callback = () => {
            // 验证用户是否授予定位权限，无权限则在首次启动时弹出权限申请对话框
            this.reqPermissionFromUser().then(async (grantStatus) => {
              // ...
            }).catch((err: BusinessError) => {
              logger.error(TAG, `permission request failed, error message: ${err.message}, error code: ${err.code}`);
            });
          }
          // 监听地图加载完成事件
          this.mapEventManager.on('mapLoad', callback);
        } else {
          logger.error(TAG, `mapcomponent init failed, error message: ${err.message}, error code: ${err.code}`);
        }
      };
    }          
    ```
   - 权限验证通过后获取用户当前位置，并移动相机使当前位置处在地图可见区域中心，然后在地图上绘制打卡范围和位置标记。
    ```ts
    if (grantStatus) {
      // 获取用户位置
      await this.getUserCurrentLocation();
      // 动画方式移动相机到用户位置，动画过程中设置显示标记信息窗会失效，需要等待动画结束
      await this.animateMoveCamera(this.myPositionGCJ02, this.duration);
      // 添加圆形打卡区域
      await this.addCircle();
      // 添加用户位置标记
      this.marker = await this.mapController?.addMarker({
        icon: this.markerIcon,
        position: this.myPositionGCJ02,
        draggable: false,
        visible: true,
        clickable: true, // 要显示信息窗口必须为true
        zIndex: 15,
        alpha: 1,
        anchorU: 0.5,
        anchorV: 1,
        rotation: 0
      });
      // ...
    }
    ```
   - 用户当前位置使用getCurrentLocation接口获取，获取的结果是WGS84坐标系经纬度，地图使用的是GCJ02坐标系，需要使用convertCoordinateSync接口进行转换。
    ```ts
    /**
     * 获取用户当前位置。
     */
    async getUserCurrentLocation() {
      this.myPositionWGS84 = await geoLocationManager.getCurrentLocation();
      this.myPositionGCJ02 =
        map.convertCoordinateSync(mapCommon.CoordinateType.WGS84, mapCommon.CoordinateType.GCJ02, this.myPositionWGS84);
    }
    ```
3. 使用calculateDistance接口计算用户位置和打卡中心点的距离，判断用户是否在打卡范围内，并保存结果。
  ```ts
  /**
   * 判断用户是否在圆圈内。
   * @param {LatLng} pos1 - 用户位置。
   * @param {LatLng} pos2 - 圆心位置。
   * @param {number} radius - 圆半径，单位为米。
   */
  isUserInCircle(pos1: mapCommon.LatLng, pos2: mapCommon.LatLng, radius: number) {
    const distance = map.calculateDistance(pos1, pos2);
    this.isInArea = distance <= radius;
  }
  ```

4. 使用getAddressesFromLocation接口根据WGS84坐标系经纬度获取用户的地理位置信息，设置为marker标题并显示marker信息窗口。
  ```ts
  /**
   * 设置标记信息。
   */
  setMarkerInfo() {
    if (this.myPositionWGS84) {
      let reverseGeocodeRequest: geoLocationManager.ReverseGeoCodeRequest = {
        latitude: this.myPositionWGS84.latitude,
        longitude: this.myPositionWGS84.longitude,
        maxItems: 1 // 获取最近的一个地址
      };
      // 将坐标转换为地理描述
      geoLocationManager.getAddressesFromLocation(reverseGeocodeRequest).then((data) => {
        if (this.marker && data[0].placeName) {
          // 显示marker信息窗
          this.marker.setTitle(data[0].placeName);
          this.marker.setInfoWindowVisible(true);
        }
      }).catch((err: BusinessError) => {
        logger.error(TAG, `addresser get failed, error message: ${err.message}, error code: ${err.code}`);
      });
    }
  }
  ```
5. 当变量isAddLocationListener值为true时添加位置监听，用户位置发生变动时，更新用户位置和地图标记，并重新判断用户是否在打卡范围内。

  ```ts
  /**
   * 添加用户位置监听。
   */
  addLocationListener() {
    let requestInfo: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.ACCURACY,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      timeInterval: this.locationTimeInterval,
      distanceInterval: 0,
      maxAccuracy: 0
    };
    let locationChange = (location: geoLocationManager.Location): void => {
      this.myPositionWGS84 = location;
      this.myPositionGCJ02 =
        map.convertCoordinateSync(mapCommon.CoordinateType.WGS84, mapCommon.CoordinateType.GCJ02, location);
      if (this.marker) {
        this.animateMoveMarker(this.marker, this.myPositionGCJ02, this.duration);
      }
      // 位置变动时再次判断用户是否在打卡范围内
      if (this.mapCircleOptions) {
        this.isUserInCircle(this.myPositionGCJ02, this.mapCircleOptions.center, this.mapCircleOptions.radius);
      }
    };
    geoLocationManager.on('locationChange', requestInfo, locationChange);
  }
  ```
6. 定义[ClockInController](./src/main/ets/model/ClockInModel.ets)类，当接收到父组件传入的实例clockInController给属性getAddress赋值，父组件即可通过clockInController实例调用ClockInComponent中的getAddress箭头函数动态获取当前用户打卡所处地址。
  ```ts
  // ClockInModel.ets
  /**
   * ClockInController 类用于处理打卡相关的逻辑。
   * 该控制器负责获取当前位置地址等功能。
   */
  export class ClockInController {
    /**
     * 获取当前位置地址的方法。
     * @returns {string} 当前位置的地址字符串。
     */
    getAddress: () => string = () => '';
  }
  ```

  ```ts
  // ClockInComponent.ets
  /**
   * 获取当前位置地址。
   * @returns {string} 当前位置的地址字符串。
   */
  private getAddress = () => {
    if (this.marker) {
      return this.marker.getTitle();
    }
    return '';
  }
  ```

ClockInSamplePage基于ClockInComponent实现了完整的打卡场景，可通过传入参数控制打卡区域的位置和样式、定位按钮的显示隐藏、是否开启位置监听、用户位置信息窗口的内容和样式等，并且根据ClockInComponent中用户位置是否处于打卡范围的判断结果进行打卡操作及反馈。源码参考[ClockInSamplePage.ets](./src/main/ets/views/ClockInSamplePage.ets)。

1. 引入功能组件ClockInComponent，并初始化相关属性，其中isInArea为必填参数，用于同步用户位置是否处于打卡范围的判断结果。
   
  ```ts
  ClockInComponent({
    clockInController: this.clockInController,
    isInArea: this.isInArea,
    isLocationButtonVisible: this.isLocationButtonVisible,
    locationButtonPosition: this.locationButtonPosition,
    mapOptions: this.mapOptions,
    getMapController: this.getController,
    customInfoWindowSlotParam: this.customInfoWindowSlot
  })
  ```

2. 处理打卡逻辑。当用户处于打卡范围内时，提供打卡功能，并记录打卡信息，否则打卡失败，提示用户进入打卡范围后打卡。其中地址信息可通过传入ClockInComponent的实例clockInController调用getAddress获取。

  ```ts
  // 打卡按钮
  Text(this.clockInButtonText)
    .onClick(() => {
      // 如果在打卡范围内，进行打卡操作，否则显示提示信息
      if (this.isInArea) {
        // 如果已有上班打卡信息，则进行下班打卡，否则新增上班打卡信息
        if (this.clockInInfo) {
          // 如果已有下班打卡信息，则更新下班打卡信息，否则新增下班打卡信息
          this.clockOutInfo = {
            time: this.timeFormat.format(new Date()),
            address: this.clockInController.getAddress()
          };
          this.clockInButtonText = this.clockOutInfo !== null ? $r('app.string.clock_in_button_text_update') :
          $r('app.string.clock_in_button_text_clock_out');
        } else {
          this.clockInInfo = {
            time: this.timeFormat.format(new Date()),
            address: this.clockInController.getAddress()
          };
          this.clockInButtonText = $r('app.string.clock_in_button_text_clock_out');
        }
      } else {
        promptAction.showToast({
          message: $r('app.string.clock_in_toast_message_out_of_range')
        });
      }
    })
    // ...
  ```


### 高性能知识点

不涉及

### 工程结构&模块类型

   ```
   clockin                                  // har类型
   |---/src/main/ets/components                       
   |   |---ClockInComponent.ets             // 封装的打卡功能组件
   |---/src/main/ets/model                        
   |   |---ClockInModel.ets                 // 数据模型层-打卡功能组件控制器与打卡信息数据模型 
   |---/src/main/ets/utils                        
   |   |---Constants.ets                    // 常量数据
   |   |---Logger.ets                       // 日志打印工具
   |---/src/main/ets/views                        
   |   |---ClockInSamplePage.ets            // 视图层-打卡场景主页面
   ```

### 模块依赖

1. 本示例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

[MapComponent（地图组件）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/map-mapcomponent-V5)

[@ohos.geoLocationManager (位置服务)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-geolocationmanager-V5)

[map（地图显示功能）](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/map-map-V5)

[应用开发准备](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/application-dev-overview-V5)

[配置应用签名证书指纹](https://developer.huawei.com/consumer/cn/doc/app/agc-help-signature-info-0000001628566748)