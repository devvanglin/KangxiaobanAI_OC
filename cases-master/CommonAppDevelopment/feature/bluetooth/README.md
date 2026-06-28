# 蓝牙实现服务端和客户端通讯

### 介绍

本示例分为服务端和客户端两个功能模块。  
服务端创建蓝牙服务实例，添加心率跳动服务。以心率跳动值作为特征值，通过notifyCharacteristicChanged接口将心率跳动特征值广播发送给连接到本服务端并订阅了该特征值变动通知的蓝牙客户端设备。    
客户端以特定服务UUID作为过滤条件扫描服务端，连接到扫描的设备后通过setCharacteristicChangeNotification接口向服务端发送‘通知心率跳动特征值变动’的请求，以便收到服务端该特征值变动的通知消息。  

主要有以下几点功能：  
1. 发现具有特定服务的设备。  
2. 连接到设备。  
3. 发现服务。  
4. 发现服务的特征、读取给定特征的值、为特征设置通知等。  

相关概念：   

1. BLE扫描：通过BLE扫描接口startBLEScan实现对BLE设备的搜索。
2. BLE连接：通过BLE的GattClientDevice实现对BLE设备的连接、断连等操作。
3. 接收数据：通过BLECharacteristicChange接收特征值的改变。

### 效果图预览

![](../../product/entry/src/main/resources/base/media/bluetooth_client.gif) 

**使用说明**

1. 该功能需要两台设备，进入BLE通讯场景页面，选择当前设备是作为BLE服务端还是BLE客户端。
2. 点击“BLE服务端”，进入服务端页面。点击“开启BLE心率广播”，打开蓝牙服务，向订阅了心率跳动值通知的客户端广播发送实时心率值。
3. 点击“BLE客户端”，进入客户端页面。点击“搜索设备”，搜索开启了心率跳动服务的BLE服务端，连接搜索到的蓝牙设备。连接成功后，点击设备右边的“已连接”，进入心率波动图页面查看实时心率。

### 实现思路
#### 服务端
1. 开启或关闭蓝牙广播服务。源码参考[BluetoothAdvertiser.ets](./src/main/ets/pages/BluetoothAdvertiser.ets)及[startAdvertiser](./src/main/ets/viewmodel/AdvertiserBluetoothViewModel.ets)。

   ```typescript
   toggleAdvertiser(): void {
    if (this.startAdvertiserState) {
      //  TODO: 知识点 关闭蓝牙广播服务
      advertiserBluetoothViewModel.stopAdvertiser();
      this.toggleHeartRate(false);
      this.startAdvertiserState = false;
    } else {
      //  TODO: 知识点 开启蓝牙广播服务
      let ret = advertiserBluetoothViewModel.startAdvertiser();
      if (ret) {
        this.localName = advertiserBluetoothViewModel.getLocalName();
        // 模拟心率跳动
        this.toggleHeartRate(true);
        this.startAdvertiserState = true;
      } else {
        Log.showError(TAG, `toggleAdvertiser: ret = ${ret}`);
      }
    }
   }
   ```

   ```typescript
    // TODO: 知识点 创建蓝牙服务实例
    this.mGattServer = ble.createGattServer();

    let descriptors: Array<ble.BLEDescriptor> = [];
    const arrayBuffer = ArrayBufferUtils.byteArray2ArrayBuffer([11]);
    const descriptor: ble.BLEDescriptor = {
      serviceUuid: BleConstants.UUID_SERVICE_HEART_RATE, //  特定服务（service）的 UUID
      characteristicUuid: BleConstants.UUID_CHARACTERISTIC_HEART_RATE_MEASUREMENT, // 特定特征（characteristic）的 UUID
      descriptorUuid: BleConstants.UUID_DESCRIPTOR_HEART_RATE, // 描述符（descriptor）的 UUID
      descriptorValue: arrayBuffer  // 描述符对应的二进制值
    };
    descriptors[0] = descriptor;

    let characteristics: Array<ble.BLECharacteristic> = [];
    const arrayBufferC = ArrayBufferUtils.byteArray2ArrayBuffer([1]);
    const characteristic: ble.BLECharacteristic = {
      serviceUuid: BleConstants.UUID_SERVICE_HEART_RATE, // 特定服务（service）的 UUID
      characteristicUuid: BleConstants.UUID_CHARACTERISTIC_HEART_RATE_MEASUREMENT, // 特定特征（characteristic）的 UUID
      characteristicValue: arrayBufferC, // 特征对应的二进制值
      descriptors: descriptors  // 特定特征的描述符列表
    };
    characteristics[0] = characteristic;
    // 定义心率跳动服务
    const service: ble.GattService = {
      serviceUuid: BleConstants.UUID_SERVICE_HEART_RATE,
      isPrimary: true, // 主服务
      characteristics: characteristics,
      includeServices: []
    };

    try {
      // 添加服务
      this.mGattServer.addService(service);
      Log.showInfo(TAG, `startAdvertiser: addService suc`);
    } catch (err) {
      Log.showError(TAG, `startAdvertiser: addService err = ${err}`);
    }

    try {
      // 订阅连接服务状态
      this.onConnectStateChange();

      // 设置广播发送的参数
      let setting: ble.AdvertiseSetting = {
        interval: DurationConstants.ADVERTISE_INTERVAL, // 广播间隔，最小值设置160个slot表示100ms
        txPower: 1, // 发送功率，最小值设置-127，最大值设置1，默认值设置-7
        connectable: true  // 是否是可连接广播
      };
      // BLE广播包内容
      let advData: ble.AdvertiseData = {
        serviceUuids: [BleConstants.UUID_SERVICE_HEART_RATE], // 要广播的服务 UUID 列表
        manufactureData: [], // 广播的制造商信息列表
        serviceData: [], // 广播的服务数据列表
      };
      // BLE回复扫描请求回复响应
      let advResponse: ble.AdvertiseData = {
        serviceUuids: [BleConstants.UUID_SERVICE_HEART_RATE],
        manufactureData: [],
        serviceData: [],
      };
      // TODO: 知识点 开始广播
      ble.startAdvertising(setting, advData, advResponse);
      Log.showInfo(TAG, `startAdvertiser: startAdvertising success`);
      return true;
    } catch (err) {
      Log.showError(TAG, `startAdvertiser: startAdvertising err = ${err}`);
    }
   ```
2. 服务开启状态下，广播通知特征值变动。源码参考[BluetoothAdvertiser.ets](./src/main/ets/pages/BluetoothAdvertiser.ets)及[notifyCharacteristicChanged](./src/main/ets/viewmodel/AdvertiserBluetoothViewModel.ets)。

   ```typescript
      this.mIntervalId = setInterval(() => {
        this.heartRate = MathUtils.getRandomInt(MIN_HEART_RATE, MAX_HEART_RATE);
        if (this.deviceId) {
          // TODO: 知识点 通知客户端心率特征值变动
          advertiserBluetoothViewModel.notifyCharacteristicChanged(this.deviceId, this.heartRate);
        } else {
          Log.showWarn(TAG, `toggleHeartRate: deviceId is null， heartRate = ${this.heartRate}`);
        }
      }, DurationConstants.NOTIFY_DELAY_TIME)
   ```

   ```typescript
        // 构造BLECharacteristic
        let arrayBufferC = ArrayBufferUtils.byteArray2ArrayBuffer([0x00, heartRate]);
        let characteristic: CharacteristicModel = {
          serviceUuid: BleConstants.UUID_SERVICE_HEART_RATE,
          characteristicUuid: BleConstants.UUID_CHARACTERISTIC_HEART_RATE_MEASUREMENT,
          characteristicValue: arrayBufferC,
          descriptors: descriptors
        };
        // 通知的特征值消息
        let notifyCharacteristic: NotifyCharacteristicModel = {
          serviceUuid: BleConstants.UUID_SERVICE_HEART_RATE,
          characteristicUuid: BleConstants.UUID_CHARACTERISTIC_HEART_RATE_MEASUREMENT,
          characteristicValue: characteristic.characteristicValue,
          confirm: false  // 对端不需要确认
        };
        // TODO: 知识点 server端特征值发生变化时，主动通知已连接的client设备。
        this.mGattServer.notifyCharacteristicChanged(deviceId, notifyCharacteristic, (err: BusinessError) => {
          if (err) {
            Log.showError(TAG, 'notifyCharacteristicChanged callback failed， err.code = ' + err.code + ", err.message =" + err.message);
          } else {
            Log.showInfo(TAG, 'notifyCharacteristicChanged callback success');
          }
        });
   ```

#### 客户端

1. 启动时请求蓝牙权限。源码参考[BluetoothClient.ets](./src/main/ets/pages/BluetoothClient.ets)。

   ```typescript 
   // 所需蓝牙权限
   const PERMISSION_LIST: Array<Permissions> = [
     'ohos.permission.APPROXIMATELY_LOCATION',
     'ohos.permission.LOCATION'
   ];
   
   // TODO 知识点： 获取蓝牙相关权限
   function reqPermissionsFromUser(permissions: Array<Permissions>, context: common.UIAbilityContext): void {
     const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
     atManager.requestPermissionsFromUser(context, permissions).then((data) => {
       const granStatus: Array<number> = data.authResults;
       const length: number = granStatus.length;
       for (let i = 0; i < length; i++) {
         if (granStatus[i] === 0) {
   
         } else {
           return;
         }
       }
     })
   }
   ```

2. 扫描设备。源码参考[BluetoothClientModel.ets](./src/main/ets/viewmodel/BluetoothClientModel.ets)

   ```typescript
   startBLEScan(): boolean {   
     if (!this.isBluetoothEnabled()) {
       Log.showInfo(TAG, `startBLEScan: bluetooth is disable.`);
       // 启动蓝牙服务
       this.enableBluetooth();
       promptAction.showToast({
         message: $r('app.string.ble_toast_enable_bluetooth'),
           duration: DurationConstants.DURATION_TIME
         });
       return false;
     }
     // 订阅搜索蓝牙服务
     this.onBLEDeviceFind(); 
     // 扫描蓝牙设备
     const ret = this.startBLEScanInner();
     return ret;
   }
   ```  

3. 连接设备。源码参考[BluetoothClientModel.ets](./src/main/ets/viewmodel/BluetoothClientModel.ets)及[connectInner](./src/main/ets/viewmodel/BluetoothClientModel.ets)。

   ```typescript
   .onClick(() => {
     if (this.bluetoothDevice.connectionState === ConnectionState.STATE_DISCONNECTED) {
       // 连接蓝牙设备
       bluetoothViewModel.connect(this.bluetoothDevice);
     } else if (this.bluetoothDevice.connectionState === ConnectionState.STATE_CONNECTED) { 
       // 断开与蓝牙设备的连接
       bluetoothViewModel.disconnect();
     }
   })
   ```  

   ```typescript
   private connectInner(gattClientDevice: ble.GattClientDevice): boolean {
     try {
       if (!gattClientDevice) {
         Log.showWarn(TAG, `connectInner: mGattClientDevice is null`);
         return false;
       }
       // 订阅连接状态改变消息
       this.onBLEConnectionStateChange();
       // 订阅特征值改变消息
       this.onBLECharacteristicChange();
       // 开始连接
       gattClientDevice.connect();
       this.mConnectBluetoothDevice.connectionState = ConnectionState.STATE_CONNECTING;
       AppStorage.setOrCreate('connectBluetoothDevice', this.mConnectBluetoothDevice);
       return true;
     } catch (err) {
       Log.showError(TAG, `connectInner: err = ${err}`);
     }
     return false;
   }
   ```  

4. 向服务端发送‘通知心率跳动’特征值请求,侦听特征值变化数据。源码参考[BLECharacteristicChange](./src/main/ets/viewmodel/BluetoothClientModel.ets)。
   ```typescript
   // connect success, Starts discovering services.
   let services: Array<ble.GattService> = await this.mGattClientDevice!.getServices();
   Log.showInfo(TAG, `onBLEConnectionStateChange: services = ${JSON.stringify(services)}`);
   
   // Characteristic enable/disable indicate/notify
   let service: ble.GattService | undefined =
   services.find(item => item.serviceUuid === BleConstants.UUID_SERVICE_HEART_RATE);
   let characteristics: Array<ble.BLECharacteristic> = service!.characteristics;
   let characteristic: ble.BLECharacteristic | undefined =
   characteristics.find(item => item.characteristicUuid ===
   BleConstants.UUID_CHARACTERISTIC_HEART_RATE_MEASUREMENT);
   Log.showInfo(TAG, `onBLEConnectionStateChange: characteristic = ${JSON.stringify(characteristic)}`);
   // TODO 知识点： 向服务端发送设置通知此特征值请求
   this.mGattClientDevice!.setCharacteristicChangeNotification(characteristic, true);
   let descriptors: Array<ble.BLEDescriptor> = characteristic!.descriptors;
   let descriptor: ble.BLEDescriptor | undefined =
   descriptors.find(item => item.descriptorUuid === BleConstants.UUID_DESCRIPTOR_HEART_RATE);
   Log.showInfo(TAG, `onBLEConnectionStateChange: descriptor = ${JSON.stringify(descriptor)}`);
   descriptor!.descriptorValue = ArrayBufferUtils.byteArray2ArrayBuffer([0x01, 0x00]);
   this.mGattClientDevice!.writeDescriptorValue(descriptor);
   ```  

   ```typescript
   // TODO 知识点： 订阅特征值变化事件
   this.mGattClientDevice.on('BLECharacteristicChange', (data: ble.BLECharacteristic) => {
   Log.showInfo(TAG, `onBLECharacteristicChange: data = ${JSON.stringify(data)}`);
   let characteristicValue: ArrayBuffer = data.characteristicValue;
   Log.showInfo(TAG,
   `onBLECharacteristicChange: characteristicValue.length = ${characteristicValue.byteLength}, characteristicValue = ${JSON.stringify(new Uint8Array(characteristicValue))}`);
   let byteArr = ArrayBufferUtils.arrayBuffer2ByteArray(characteristicValue);
   Log.showInfo(TAG, `byteArr = ${byteArr}`);
   let heartRate = byteArr[1];
   AppStorage.setOrCreate('heartRate', heartRate);
   })
   ```  

### 高性能知识点

**不涉及**

### 工程结构&模块类型
   ```
   bluetooth                                  // har类型
   src/main/ets/
   |---constants
   |   |---BleConstants.ts                    // BLE常量
   |   |---StyleConstants.ts                  // Style样式常量
   |   |---DurationConstants.ts.ts            // 定时、延迟类常量
   |---model
   |   |---BluetoothDevice.ets                // 蓝牙设备model
   |---pages
   |   |---BluetoothView.ets                  // 场景首页，可选择进入客户端、服务端
   |   |---BluetoothAdvertiser.ets            // 广播者角色（作为服务端）
   |   |---BluetoothClient.ets                // 客户端连接页面
   |   |---HeartRate.ets                      // 连接成功后，侦听到服务端的心率数据   
   |---uicomponents
   |   |---HeartRateGraph.ets                 // 实时心率图表
   |   |---NavigationBar.ets                  // 顶部导航栏
   |---utils
   |   |---ArrayBufferUtils.ts                // ArrayBuffer工具
   |   |---DateUtils.ts                       // 日期工具
   |   |---Log.ts                             // 日志工具
   |   |---MathUtils.ts                       // Math工具，用于生成随机数
   |---viewmodel
   |   |---BluetoothClientModel.ets           // 开启蓝牙、扫描BLE、连接、断连等BLE接口
   |   |---AdvertiserBluetoothViewModel.ets   // 开启蓝牙、开启蓝牙心率广播等
   ```
   
### 模块依赖

本示例依赖[动态路由模块](../../common/routermodule/src/main/ets/router/DynamicsRouter.ets)来实现页面的动态加载。

### 参考资料

1. [蓝牙示例](https://gitee.com/openharmony/applications_app_samples/tree/master/code/BasicFeature/Connectivity/Bluetooth)
2. [蓝牙服务开发](https://docs.openharmony.cn/pages/v5.0/zh-cn/application-dev/connectivity/bluetooth/bluetooth-overview.md)
3. [蓝牙服务相关API](https://docs.openharmony.cn/pages/v5.0/zh-cn/application-dev/reference/apis-connectivity-kit/js-apis-bluetooth-ble.md)