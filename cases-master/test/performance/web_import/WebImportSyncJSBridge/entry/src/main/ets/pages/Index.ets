/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import webview from '@ohos.web.webview';

class TestObj {
  constructor() {
  }

  test(): string {
    let start = Date.now();
    // 模拟耗时操作
    for (let i = 0; i < 500000; i++) {
    }
    let end = Date.now();
    console.log('objName.test start: ' + start);
    return 'objName.test Sync function took ' + (end - start) + 'ms';
  }

  asyncTestBool(): Promise<string> {
    return new Promise((resolve, reject) => {
      let start = Date.now();
      // 模拟耗时操作（异步）
      setTimeout(() => {
        for (let i = 0; i < 500000; i++) {
        }
        let end = Date.now();
        console.log('objAsyncName.asyncTestBool start: ' + start);
        resolve('objName.asyncTestBool Async function took ' + (end - start) + 'ms');
      }, 0); // 使用0毫秒延迟来模拟立即开始的异步操作
    });
  }
}

class WebObj {
  constructor() {
  }

  webTest(): string {
    let start = Date.now();
    // 模拟耗时操作
    for (let i = 0; i < 500000; i++) {
    }
    let end = Date.now();
    console.log('objTestName.webTest start: ' + start);
    return 'objTestName.webTest Sync function took ' + (end - start) + 'ms';
  }

  webString(): string {
    let start = Date.now();
    // 模拟耗时操作
    for (let i = 0; i < 500000; i++) {
    }
    let end = Date.now();
    console.log('objTestName.webString start: ' + start);
    return 'objTestName.webString Sync function took ' + (end - start) + 'ms'
  }
}

class AsyncObj {
  constructor() {
  }

  asyncTest(): Promise<string> {
    return new Promise((resolve, reject) => {
      let start = Date.now();
      // 模拟耗时操作（异步）
      setTimeout(() => {
        for (let i = 0; i < 500000; i++) {
        }
        let end = Date.now();
        console.log('objAsyncName.asyncTest start: ' + start);
        resolve('objAsyncName.asyncTest Async function took ' + (end - start) + 'ms');
      }, 0); // 使用0毫秒延迟来模拟立即开始的异步操作
    });
  }

  asyncString(testStr: string): Promise<string> {
    return new Promise((resolve, reject) => {
      let start = Date.now();
      // 模拟耗时操作（异步）
      setTimeout(() => {
        for (let i = 0; i < 500000; i++) {
        }
        let end = Date.now();
        console.log('objAsyncName.asyncString start: ' + start);
        resolve('objAsyncName.asyncString Async function took ' + (end - start) + 'ms');
      }, 0); // 使用0毫秒延迟来模拟立即开始的异步操作
    });
  }
}

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  @State testObjTest: TestObj = new TestObj();
  @State webTestObj: WebObj = new WebObj();
  @State asyncTestObj: AsyncObj = new AsyncObj();

  build() {

    Column() {
      Button('refresh')
        .onClick(() => {
          try {
            this.controller.refresh();
          } catch (error) {
            console.error(`ErrorCode:${(error.code)},Message:${(error.message)}`)
          }
        })

      Button('Register JavaScript To Window')
        .onClick(() => {
          try {
            //TODO:知识点 调用注册接口对象及成员函数，其中同步函数列表必填，空白则需要用[]占位；异步函数列表非必填
            //同步、异步函数都注册
            this.controller.registerJavaScriptProxy(
              this.testObjTest,
              "objName",
              ["test"],
              ["asyncTestBool"]
            );
            //只注册同步函数
            this.controller.registerJavaScriptProxy(
              this.webTestObj,
              "objTestName",
              ["webTest", "webString"]
            );
            //只注册异步函数，同步函数列表处留空
            this.controller.registerJavaScriptProxy(
              this.asyncTestObj,
              "objAsyncName",
              [],
              ["asyncTest", "asyncString"]
            );
          } catch (error) {
            console.error(`ErrorCode:${(error.code)},Message:${(error.message)}`)
          }
        })

      Web({
        src: $rawfile('demo.html'),
        controller: this.controller
      }).javaScriptAccess(true)
    }
  }
}