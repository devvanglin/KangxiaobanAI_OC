# 第 01 章 · ArkTS 语言完全指南

> 本章分三部分：
> - **A 部分**：从零讲 TypeScript 基础（已经会 TS 的可以跳到 B）
> - **B 部分**：ArkTS 砍掉了什么、为什么砍、报错怎么改 ← **最重要**
> - **C 部分**：ArkTS 独有的东西（装饰器、`$$`、`$r`、`ESObject`）

---

# A 部分 · 从零学 TypeScript 基础

## A.1 变量

```typescript
// ArkTS 只有两种声明方式
let name: string = '张三';       // 可以改
const age: number = 18;          // 不可以改（常量）

// ❌ 禁止 var
var x = 1;                       // arkts-no-var 报错
```

**为什么禁 `var`**：`var` 有变量提升和函数作用域的怪异行为，容易写出 bug。`let`/`const` 是块作用域，行为可预测。

## A.2 基本类型

```typescript
let s: string = '文字';
let n: number = 3.14;            // 没有 int/float 之分，统一是 number
let b: boolean = true;
let arr: number[] = [1, 2, 3];   // 数组
let arr2: Array<number> = [1, 2, 3];  // 等价写法

// 联合类型：可以是这个，也可以是那个
let level: 'normal' | 'warning' | 'danger' = 'normal';

// 可选（可能是 undefined）
let maybe: string | undefined = undefined;

// null
let nothing: string | null = null;
```

**本项目的真实例子**（`model/DetailTypes.ets`）：

```typescript
export type StatusLevel = 'normal' | 'warning' | 'danger';
```

这叫**字面量联合类型**，比 `enum` 更轻量。用它的好处是：编译器会强制你只能写这三个值之一，写错了立刻报错。

## A.3 函数

```typescript
// 基本写法：参数类型 + 返回值类型，都必须写
function add(a: number, b: number): number {
  return a + b;
}

// 没有返回值用 void
function log(msg: string): void {
  console.log(msg);
}

// 箭头函数
const multiply = (a: number, b: number): number => a * b;

// 默认参数
function greet(name: string, greeting: string = '你好'): string {
  return `${greeting}, ${name}`;
}

// 可选参数（必须放在最后）
function find(id: string, deep?: boolean): void { }
```

**ArkTS 强制要求写返回值类型**（linter 会警告），养成习惯。

## A.4 接口（interface）

接口 = 描述一个对象「长什么样」。

```typescript
interface Person {
  name: string;        // 必须有
  age: number;         // 必须有
  email?: string;      // 可选（加问号）
}

const p: Person = { name: '张三', age: 18 };  // ✅ email 可以不给
const q: Person = { name: '李四' };            // ❌ 缺 age，报错
```

**本项目的真实例子**（`util/BreakpointSystem.ets`）：

```typescript
export interface BreakpointTypeOptions<T> {
  xs?: T;   // 可选
  sm: T;    // 必填
  md: T;    // 必填
  lg: T;    // 必填
  xl?: T;   // 可选
}
```

`<T>` 是**泛型**（下面讲）。

## A.5 泛型（Generic）

泛型 = 「类型占位符」。让一个函数/类可以处理多种类型，但仍然类型安全。

```typescript
// 不用泛型：只能处理 number
function firstNumber(arr: number[]): number { return arr[0]; }

// 用泛型：什么类型都能处理，且返回类型自动对应
function first<T>(arr: T[]): T { return arr[0]; }

const a: number = first<number>([1, 2, 3]);      // T = number
const b: string = first<string>(['x', 'y']);      // T = string
```

**本项目的真实例子**（`util/BreakpointSystem.ets` 的 `BreakpointType<T>`）：

```typescript
export class BreakpointType<T> {
  private xs: T;
  private sm: T;
  private md: T;
  private lg: T;
  private xl: T;

  public constructor(param: BreakpointTypeOptions<T>) {
    this.xs = param.xs ?? param.sm;   // ?? 是「空值合并」：左边是 null/undefined 就用右边
    this.sm = param.sm;
    this.md = param.md;
    this.lg = param.lg;
    this.xl = param.xl ?? param.lg;
  }

  public getValue(currentBreakpoint: WidthBreakpoint): T {
    if (currentBreakpoint === WidthBreakpoint.WIDTH_XS) return this.xs;
    if (currentBreakpoint === WidthBreakpoint.WIDTH_SM) return this.sm;
    if (currentBreakpoint === WidthBreakpoint.WIDTH_MD) return this.md;
    if (currentBreakpoint === WidthBreakpoint.WIDTH_XL) return this.xl;
    return this.lg;
  }
}
```

**怎么用**（`component/TabPageView.ets`）：

```typescript
// T = number：不同屏幕宽度用不同的边距数值
private pagePadding(): number {
  return new BreakpointType<number>({
    sm: 16, md: 24, lg: 28, xl: 32
  }).getValue(this.globalInfoModel.widthBreakpoint);
}
```

```typescript
// T = Resource：不同屏幕宽度用不同的资源
const horizontalMargin = new BreakpointType({
  sm: $r('sys.float.padding_level8'),
  md: $r('sys.float.padding_level12'),
  lg: $r('sys.float.padding_level16'),
}).getValue(this.globalInfoModel.widthBreakpoint);
```

**泛型的作用**：`BreakpointType<T>` 是一个「按屏幕宽度选值」的容器，传入什么类型，返回的就是什么类型。

## A.6 类（class）

```typescript
class Dog {
  // 字段（必须先声明，不能动态加）
  private name: string;
  public age: number;
  protected owner: string = '';

  // 构造函数
  constructor(name: string, age: number) {
    this.name = name;
    this.age = age;
  }

  // 方法
  public bark(): string {
    return `${this.name} 汪汪`;
  }

  // 静态方法（不用 new 就能调）
  public static create(name: string): Dog {
    return new Dog(name, 0);
  }
}

const d = new Dog('旺财', 3);
const d2 = Dog.create('小黑');    // 静态方法直接用类名调
```

三个访问修饰符：

| 修饰符 | 谁能访问 |
|---|---|
| `public`（默认） | 所有人 |
| `private` | 只有类内部 |
| `protected` | 类内部 + 子类 |

**本项目的真实例子**（`util/WindowUtil.ets` 全是静态方法的工具类）：

```typescript
export class WindowUtil {
  private static windowClass?: window.Window;    // 静态私有字段
  private static uiContext: UIContext;

  public static initialize(windowStage: window.WindowStage) { /* ... */ }
  public static setImmersiveMode(enable: boolean): void { /* ... */ }
  private static getDeviceSize(): void { /* ... */ }
}

// 用法：不 new，直接类名调用
WindowUtil.initialize(windowStage);
```

**单例模式的真实例子**（`util/PreferenceManager.ets`）：

```typescript
export class PreferenceManager {
  private preferences?: preferences.Preferences;
  private static instance: PreferenceManager;   // ① 静态字段存唯一实例

  private constructor() {                       // ② 构造函数设为 private，外部不能 new
    this.initPreference(PREFERENCES_NAME);
  }

  public static getInstance(): PreferenceManager {   // ③ 只能通过这个方法拿实例
    if (!PreferenceManager.instance) {
      PreferenceManager.instance = new PreferenceManager();
    }
    return PreferenceManager.instance;
  }
}

// 用法
const pm = PreferenceManager.getInstance();   // 全 App 只有一个
```

## A.7 枚举（enum）

```typescript
// 字符串枚举（推荐）
export enum StorageKey {
  UI_CONTEXT = 'kanxiaoban_UIContext',
  GLOBAL_INFO = 'kanxiaoban_GlobalInfoModel',
  MATERIAL_LEVEL = 'kanxiaoban_CustomMaterialLevel',
}

// 用法
AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel());
```

**为什么用枚举而不是裸字符串**：写错了编译器会报错。`StorageKey.GLOBAL_INFOO` 会立刻报错，`'kanxiaoban_GlobalInfoModell'` 不会。

**ArkTS 限制**：枚举成员的值必须是**编译期常量**，不能是运行时计算的：

```typescript
enum Bad {
  A = someFunction(),   // ❌ arkts-no-enum-mixed-types
}
```

## A.8 类型别名（type）

```typescript
type ChatRole = 'ai' | 'user';                    // 联合类型别名
type OnClickCallback = () => void;                // 函数类型别名
type IconType = ResourceStr | SymbolGlyphModifier | PixelMap;  // SDK 里的真例子
```

**`interface` vs `type` 什么时候用哪个**：

| 场景 | 用哪个 |
|---|---|
| 描述一个对象的形状 | `interface` |
| 联合类型 / 函数类型 / 元组 | `type` |
| 需要被 class 实现 | `interface` |

## A.9 空值处理（`?.` `??` `!`）

这三个符号在鸿蒙代码里到处都是，必须搞清楚：

```typescript
// ①  ?.  可选链：左边是 null/undefined 就整体返回 undefined，不报错
const h = properties?.windowRect?.height;
// 等价于：properties && properties.windowRect ? properties.windowRect.height : undefined

// ②  ??  空值合并：左边是 null/undefined 就用右边
const height = someValue ?? 0;
// 注意和 || 的区别：0 || 5 得到 5（因为 0 是假值）；0 ?? 5 得到 0（因为 0 不是 null/undefined）

// ③  !  非空断言：告诉编译器「我保证这里不是 null」
const value = map.get(key)!;
// ⚠️ 危险：如果实际是 undefined，运行时会崩。只在你 100% 确定时用
```

**本项目的组合用法**（`util/WindowUtil.ets`）：

```typescript
globalInfoModel.statusBarHeight =
  WindowUtil.uiContext.px2vp(systemAvoidArea?.topRect?.height ?? 0);
//                            ↑ 可选链，避免空指针      ↑ 兜底值 0
```

```typescript
const globalInfoModel: GlobalInfoModel =
  AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel())
  ?? new GlobalInfoModel();
//  ↑ connect 返回 T | undefined，所以必须兜底
```

**本项目的 `!` 用法**（`pages/HealthExpandPage.ets`）：

```typescript
if (!floorMap.has(floor)) {
  floorMap.set(floor, []);
}
floorMap.get(floor)!.push(item);   // 上面刚 set 过，这里 100% 有值，所以用 !
```

## A.10 数组常用方法

```typescript
const arr: number[] = [3, 1, 4, 1, 5];

arr.map(x => x * 2);              // [6,2,8,2,10]  变换每个元素
arr.filter(x => x > 2);           // [3,4,5]       过滤
arr.find(x => x > 2);             // 3             找第一个符合的
arr.findIndex(x => x > 2);        // 0             找第一个符合的下标
arr.some(x => x > 4);             // true          有没有符合的
arr.every(x => x > 0);            // true          是不是都符合
arr.forEach(x => console.log(x)); // 遍历
arr.slice(0, 2);                  // [3,1]         截取（不改原数组）
arr.splice(0, 2);                 // 删除（会改原数组！）
arr.sort((a, b) => a - b);        // 排序（会改原数组！）
[...arr, 6];                      // [3,1,4,1,5,6] 展开运算符，创建新数组
```

**本项目的真实例子**（`pages/AiChatPage.ets`）：

```typescript
// 把当前会话移到最前面，其余保持顺序，最多保留 50 条
this.historyStore.sessions = [updated, ...remaining].slice(0, MAX_CHAT_SESSIONS);
```

**⚠️ 状态更新的重要陷阱**：

```typescript
// ❌ 错误：直接改数组内容，V2 可能检测不到
this.messages.push(newMessage);

// ✅ 正确：创建新数组赋值，一定能触发更新
this.messages = [...this.messages, newMessage];
```

（V2 的 `@Local` 对数组的 `push` 其实**是**能感知的，但对数组里对象的属性改动不行。
最稳的做法永远是「整体替换」。第 05 章详述。）

## A.11 Map 和 Set

```typescript
// Map：键值对
const map: Map<string, number> = new Map();
map.set('a', 1);
map.get('a');        // 1
map.has('a');        // true
map.delete('a');
map.size;            // 数量
Array.from(map.keys());    // 所有的键（数组）
Array.from(map.values());  // 所有的值

// Set：不重复集合
const set: Set<string> = new Set();
set.add('x');
set.has('x');        // true
```

**本项目的真实例子**（`model/TabsBarModel.ets`，用 Map 做缓存）：

```typescript
export class TabsBarModel {
  private static pageTabBarStyleMap: Map<PageKeyEnum, BottomTabBarStyle[]> = new Map();

  public static getTabBarByPage(pageKey: PageKeyEnum): BottomTabBarStyle[] {
    if (!TabsBarModel.pageTabBarStyleMap.has(pageKey)) {
      // 第一次调用：构造并存进 Map
      const tabBarStyleList: BottomTabBarStyle[] = [];
      /* ...构造过程... */
      TabsBarModel.pageTabBarStyleMap.set(pageKey, tabBarStyleList);
    }
    // 之后每次调用：直接从 Map 拿，不重复构造
    return TabsBarModel.pageTabBarStyleMap.get(pageKey) ?? [];
  }
}
```

这是**缓存模式**：构造 TabBar 样式有成本，缓存起来避免每次渲染都重建。

## A.12 异步：Promise 和 async/await

```typescript
// Promise：一个「将来会有结果」的东西
function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// async/await：让异步代码看起来像同步
async function doSomething(): Promise<void> {
  await delay(1000);          // 等 1 秒
  console.log('过了 1 秒');
}

// 错误处理
async function safe(): Promise<void> {
  try {
    await mightFail();
  } catch (err) {
    console.error(err);
  }
}
```

**本项目的真实例子**（`pages/MainPage.ets`）：

```typescript
private async handleLogout(): Promise<void> {
  try {
    await router.replaceUrl({ url: 'pages/LoginPage' });
  } catch (error) {
    Logger.error(TAG, `logout failed: ${JSON.stringify(error)}`);
  }
}
```

**回调式 API 的处理**（`util/WindowUtil.ets`）：

```typescript
WindowUtil.windowClass.setWindowLayoutFullScreen(enable)
  .catch((err: BusinessError) => {     // 返回 Promise，用 .catch 兜错
    Logger.error(TAG, `failed. code: ${err.code}, message: ${err.message}`);
  });
```

**定时器**：

```typescript
const timerId: number = setTimeout(() => { /* ... */ }, 800);   // 一次性
clearTimeout(timerId);

const intervalId: number = setInterval(() => { /* ... */ }, 1000); // 循环
clearInterval(intervalId);
```

**本项目的真实例子**（`component/TabPageView.ets`，每秒刷新时钟）：

```typescript
private timerId: number = -1;

aboutToAppear(): void {
  this.timerId = setInterval(() => {
    this.currentTime = new Date();
  }, 1000);
}

aboutToDisappear(): void {
  if (this.timerId !== -1) {       // ← 必须清理！否则组件销毁后定时器还在跑，内存泄漏
    clearInterval(this.timerId);
    this.timerId = -1;
  }
}
```

**铁律：凡是 `setInterval` / `setTimeout` / 事件监听，都必须在 `aboutToDisappear` 里清理。**

---

# B 部分 · ArkTS 相对 TypeScript 的语法约束

## B.1 语法约束的设计动因

TypeScript 编译后是 JavaScript，JS 是动态语言，运行时才知道对象有什么属性。这导致：
- 每次访问属性要查哈希表（慢）
- 无法做深度优化（编译器不知道类型）
- 内存布局不固定（占内存）

ArkTS 的做法是：**在编译期把所有类型和对象布局全部确定下来**，这样运行时可以像 C++ 一样直接按偏移量访问，快很多。

**代价是：所有会导致对象结构在编译期无法确定的语法，均被禁用。**

理解了这一点，你就能预测哪些语法会被禁：凡是导致编译器无法确定类型或对象结构的写法，均不被支持。

## B.1.5 两种校验模式

ArkTS 的语法检查从 **API 10** 开始正式生效，分两种模式，由 `compatibleSdkVersion` 决定：

| 模式 | 条件 | 违规后果 |
|---|---|---|
| **标准模式** | `compatibleSdkVersion >= 10` | 🔴 **编译直接失败** |
| **兼容模式** | `compatibleSdkVersion < 10` | 🟡 只报 warning，仍能编译 |

**本项目 `compatibleSdkVersion = 6.1.1(24)`，是标准模式 —— 任何违规都编译不过。**

另外还有一类「警告级」约束：现在违反不影响编译，但未来版本可能变成错误。看到就顺手改掉。

**官方对适配工作量的估计**：对于已经遵循 TypeScript 最佳实践的项目，
**90%~97% 的代码可以原封不动**。真正需要改的主要是 `any`、`var`、结构化类型这几类。

按改造成本，TS 特性在 ArkTS 里分三档：

| 档位 | 含义 | 例子 |
|---|---|---|
| 完全支持 | 不用改 | 绝大多数语法 |
| 部分支持 | 小改 | `var` → `let` |
| 不支持 | 大改 | `any` → 显式类型 |

**重要**：按 ArkTS 约束重构后的代码，**仍然是合法的 TypeScript 代码**。
也就是说 ArkTS 是 TS 的**子集**，不是方言。

---

## B.2 受限特性清单与替代写法

> **权威提示**：以下列出的是常见受限项。ArkTS 的规则会随版本演进（有些早期禁的后来放开了）。
> **最终以 DevEco Studio 的 linter / 编译报错为准**。报错码通常形如 `arkts-no-xxx`。
>
> 官方完整清单在《从 TypeScript 到 ArkTS 的适配规则》文档里，按规则编号逐条列出。
> 常见编号还包括：`arkts-identifiers-as-prop-names`、`arkts-no-call-signatures`、
> `arkts-no-ctor-signatures-type`、`arkts-no-indexed-access-type`、`arkts-no-typing-with-this`、
> `arkts-no-ctor-prop-decls`、`arkts-no-is`、`arkts-no-destruct-decls`、`arkts-no-types-in-catch`、
> `arkts-no-for-in`、`arkts-no-mapped-types`、`arkts-limited-stdlib`、`arkts-strict-typing`、
> `arkts-no-implicit-return-types`、`arkts-no-polymorphic-unops`。

### ① 禁用 `var`

```typescript
var x = 1;          // ❌ arkts-no-var
let x = 1;          // ✅
```

### ② 禁用 `any` 和 `unknown`

```typescript
let a: any = 1;         // ❌ arkts-no-any-unknown
let b: unknown = 1;     // ❌

// ✅ 替代方案 1：写明确类型
let a: number = 1;

// ✅ 替代方案 2：联合类型
let c: string | number = 1;

// ✅ 替代方案 3：跟系统交互确实不知道类型时，用 ESObject
@Builder
private destinationBuilder(name: string, param?: ESObject) { /* ... */ }
```

`ESObject` 是 ArkTS 提供的「与动态对象交互」的逃生舱，**只在必须的边界处使用**（比如接收路由参数）。

**本项目的真实用法**（`pages/MainPage.ets`）：

```typescript
@Builder
private destinationBuilder(name: string, param?: ESObject) {
  if (name === 'AboutPage') {
    MineDetailPage({ pageType: 'about' })
  } else if (name === 'GeneralSettingsPage') {
    MineDetailPage({ pageType: 'general' })
  }
}
```

### ③ 禁用结构化类型（Structural Typing）

TypeScript 里，只要「长得像」就算同一个类型：

```typescript
// TypeScript：✅ 可以
interface Point { x: number; y: number; }
class MyPoint { x: number = 0; y: number = 0; }
const p: Point = new MyPoint();   // TS 允许，因为形状一样
```

ArkTS 要求**显式声明实现关系**：

```typescript
// ArkTS：必须写 implements
interface Point { x: number; y: number; }
class MyPoint implements Point {
  x: number = 0;
  y: number = 0;
}
const p: Point = new MyPoint();   // ✅
```

### ④ 禁用索引签名和索引访问

```typescript
// ❌ 索引签名
interface Bad { [key: string]: number; }     // arkts-no-indexed-signatures

// ❌ 用字符串下标访问对象属性
const obj = { name: 'a' };
console.log(obj['name']);                    // arkts-no-props-by-index

// ✅ 替代方案 1：用 Map
const map: Map<string, number> = new Map();
map.set('key', 1);

// ✅ 替代方案 2：用 Record（有限支持）
const rec: Record<string, Object> = {};

// ✅ 替代方案 3：用点号访问
console.log(obj.name);
```

**注意例外**：数组的下标访问 `arr[0]` 是**允许**的。禁的是「用下标访问对象的具名属性」。

### ⑤ 禁用 `delete`

```typescript
delete obj.name;     // ❌ arkts-no-delete

// ✅ 替代：用 Map
map.delete('name');

// ✅ 替代：置为 undefined（如果类型允许）
obj.name = undefined;
```

### ⑥ 禁用 `in` 运算符

```typescript
if ('name' in obj) { }      // ❌ arkts-no-in

// ✅ 替代
if (obj.name !== undefined) { }
if (map.has('name')) { }
```

### ⑦ 禁用函数重载实现

```typescript
// ❌ TypeScript 风格的重载
function f(a: number): void;
function f(a: string): void;
function f(a: number | string): void { }

// ✅ 替代：联合类型 + 类型判断
function f(a: number | string): void {
  if (typeof a === 'number') { /* ... */ }
  else { /* ... */ }
}

// ✅ 替代：改名
function fNumber(a: number): void { }
function fString(a: string): void { }
```

（注意：**类的方法重载在某些版本是支持的**，但函数重载不支持。以 linter 为准。）

### ⑧ 禁用 `apply` / `call` / `bind`

```typescript
fn.apply(ctx, args);    // ❌ arkts-no-func-apply-bind-call
fn.call(ctx, a, b);     // ❌
const bound = fn.bind(ctx);  // ❌

// ✅ 替代：用箭头函数（自动捕获 this）
const bound = (a: number) => this.fn(a);
```

### ⑨ 禁用运行时代码生成

```typescript
eval('1+1');                    // ❌ arkts-no-runtime-code-gen
new Function('return 1');       // ❌
```

### ⑩ 禁用 `Symbol`

```typescript
const s = Symbol('x');          // ❌ arkts-no-symbol
```

### ⑪ 禁用原型操作

```typescript
Foo.prototype.bar = function() {};   // ❌ arkts-no-prototype-assignment
Object.setPrototypeOf(a, b);         // ❌
obj.__proto__;                       // ❌
```

### ⑫ 禁用 `globalThis`

```typescript
globalThis.myVar = 1;           // ❌ arkts-no-globalthis

// ✅ 替代：用 AppStorageV2 做全局状态
AppStorageV2.connect(MyModel, 'key', () => new MyModel());
```

### ⑬ 禁用 `with`

```typescript
with (obj) { }                  // ❌ arkts-no-with
```

### ⑭ 禁用 CommonJS

```typescript
const x = require('module');    // ❌ arkts-no-require
module.exports = { };           // ❌

// ✅ 只能用 ES Module
import { x } from 'module';
export { y };
export default z;
```

### ⑮ 独立函数里不能用 `this`

```typescript
function bad(): void {
  console.log(this.x);          // ❌ arkts-no-standalone-this
}

// ✅ this 只能出现在类的方法 / struct 的方法 / 箭头函数里
class Good {
  x: number = 1;
  method(): void {
    console.log(this.x);        // ✅
  }
}
```

该规则对 `@Builder` 的写法有直接影响，详见第 02 章。

### ⑯ 对象字面量必须能推断出具体类型

```typescript
// ❌ 无法推断类型
let obj = { a: 1, b: 2 };                 // arkts-no-untyped-obj-literals（在某些上下文）

// ✅ 显式类型标注
interface MyType { a: number; b: number; }
let obj: MyType = { a: 1, b: 2 };

// ✅ 或者用 as
let obj2 = { a: 1, b: 2 } as MyType;
```

**本项目的真实例子**（`model/TabsBarModel.ets`）：

```typescript
const PAGE_BAR_MAP: Map<PageKeyEnum, BarItem[]> = new Map([
  [PageKeyEnum.ADAPTIVE_TAB, [
    {
      label: '',
      normalColor: $r('sys.color.icon_primary'),
      normalSymbolResource: $r('sys.symbol.house_fill'),
      selectedColor: $r('app.color.brand_blue'),
      selectedSymbolResource: $r('sys.symbol.house_fill'),
    } as BarItem,        // ← 注意这个 as BarItem，帮编译器确定类型
    // 后面的元素因为数组类型已确定，可以省略 as
    { /* ... */ },
  ]],
]);
```

### ⑰ 数值类型不区分整数/浮点

```typescript
let i: int = 1;         // ❌ 没有 int 类型
let i: number = 1;      // ✅
```

### ⑱ 枚举成员必须是常量且类型统一

```typescript
enum Bad {
  A = 1,
  B = 'x',              // ❌ arkts-no-enum-mixed-types（混合类型）
}

enum Bad2 {
  A = compute(),        // ❌ 运行时计算
}
```

### ⑲ 解构（历史上受限，现已部分放开）

```typescript
// 早期版本禁止解构声明（arkts-no-destruct-decls）
const { a, b } = obj;         // 视版本而定
const [x, y] = arr;           // 视版本而定

// 最保险的写法：
const a = obj.a;
const b = obj.b;
```

**本项目的做法**：全部用点号访问，不用解构。跟着项目风格走最安全。

### ⑳ 不支持 `for...in`

```typescript
for (const key in obj) { }      // ❌ arkts-no-for-in

// ✅ 替代
for (const item of arr) { }              // 数组用 for...of
map.forEach((v, k) => { });              // Map 用 forEach
Array.from(map.keys()).forEach(k => { }); // 或转成数组
```

### ㉑ 函数返回类型推断受限

```typescript
// ❌ 返回值是「未标注返回类型的函数调用」时，必须自己标注
function a() { return b(); }             // arkts-no-implicit-return-types

// ✅
function a(): number { return b(); }
```

**实践建议：所有函数都显式写返回类型。** 本项目全部这么做。

### ㉒ 一元运算符只能用于数值，不支持隐式字符串转数字

```typescript
const s = '5';
const n = +s;          // ❌ arkts-no-polymorphic-unops（一元 + 只能用于 number）
const n2 = s * 2;      // ❌ 不支持隐式转换

// ✅ 显式转换
const n = Number.parseInt(s);
const n2 = Number.parseFloat(s) * 2;
```

**本项目的真实例子**（`component/wide/WideSlidingCapsule.ets`）：

```typescript
private updateMeasuredWidth(width: Length): void {
  let nextWidth: number = 0;
  if (typeof width === 'number') {
    nextWidth = width;
  } else if (typeof width === 'string') {
    nextWidth = parseFloat(width);        // ★显式转换
  }
  if (nextWidth > 0 && Math.abs(nextWidth - this.measuredWidth) > 0.5) {
    this.measuredWidth = nextWidth;
  }
}
```

### ㉓ 标准库能力受限（`arkts-limited-stdlib`）

TS/JS 标准库里有些 API 在 ArkTS 里不可用（主要是那些依赖动态特性的）：

```typescript
Object.assign(a, b);          // ⚠️ 可能受限
Object.keys(obj);             // ⚠️ 可能受限（对象不能动态枚举）
Reflect.xxx                   // ❌
Proxy                         // ❌
```

**替代**：数据用 `Map`、显式写字段赋值。

### ㉔ 类型断言 `as` 的限制

```typescript
// ✅ 允许：类型收窄 / 兼容类型之间
const x = someValue as BarItem;

// ❌ 不允许：完全不相关的类型之间强转
const y = 'string' as number;
```

## B.3 编码前快速自查表

| 我想写 | 能不能 | 替代 |
|---|---|---|
| `var` | ❌ | `let` / `const` |
| `any` / `unknown` | ❌ | 具体类型 / 联合类型 / `ESObject` |
| `obj['key']` | ❌ | `obj.key` 或 `Map` |
| `delete obj.k` | ❌ | `Map.delete` |
| `'k' in obj` | ❌ | `obj.k !== undefined` |
| 函数重载 | ❌ | 联合类型参数 |
| `fn.bind(this)` | ❌ | 箭头函数 |
| `eval` | ❌ | 无 |
| `Symbol` | ❌ | 无 |
| `globalThis` | ❌ | `AppStorageV2` |
| `require` | ❌ | `import` |
| 独立函数里 `this` | ❌ | 类方法 / 箭头函数 |
| 无类型对象字面量 | ⚠️ | 加 `interface` 或 `as` |
| `for...in` | ❌ | `for...of` / `Map.forEach` |
| `+str` 转数字 | ❌ | `Number.parseInt/parseFloat` |
| 省略函数返回类型 | ⚠️ | 全部显式标注 |
| `Proxy` / `Reflect` | ❌ | 无 |
| `Object.keys` / `Object.assign` | ⚠️ | `Map` / 显式赋值 |
| `arr[0]` | ✅ | — |
| 解构 | ⚠️ | 点号访问最保险 |

---

# C 部分 · ArkTS 独有的东西

## C.1 装饰器（Decorator）

装饰器是写在声明前面的 `@xxx`，用来给编译器额外信息。

```typescript
@Entry              // ← 这是装饰器
@ComponentV2        // ← 这也是
struct MyPage {
  @Local x: number = 0;   // ← 这也是
}
```

装饰器分四类：

| 类型 | 加在哪 | 例子 |
|---|---|---|
| 类装饰器 | `struct` / `class` 前 | `@Entry` `@ComponentV2` `@ObservedV2` `@Preview` `@ReusableV2` |
| 属性装饰器 | 字段前 | `@Local` `@Param` `@Once` `@Event` `@Require` `@Trace` `@Provider()` `@Consumer()` |
| 方法装饰器 | 方法前 | `@Builder` `@Monitor()` `@Computed` `@LocalBuilder` |
| 自定义样式 | 方法前 | `@Styles` `@Extend(组件名)` |

第 05 章会把每个装饰器讲透。

## C.2 `struct` vs `class`

| | `struct` | `class` |
|---|---|---|
| 用来做什么 | UI 组件 | 数据模型 / 工具类 |
| 能不能 `new` | ❌ 不能 | ✅ 能 |
| 怎么使用 | 在 `build()` 里像函数一样调用：`MyComp({ a: 1 })` | `new MyClass()` |
| 必须有什么 | `build()` 方法 | 无要求 |
| 装饰器 | `@ComponentV2` / `@Component` | `@ObservedV2` / `@Observed` / 无 |

```typescript
// struct：UI 组件
@ComponentV2
export struct HealthListCard {
  @Param @Require cardData: HealthListCardData;
  build() { /* ... */ }
}

// 使用（在别的组件的 build 里）
HealthListCard({ cardData: this.healthCardData(), widthBreakpoint: this.bp })

// class：数据模型
@ObservedV2
export class GlobalInfoModel {
  @Trace public role: string = '护工';
}

// 使用
const model = new GlobalInfoModel();
```

## C.3 `$r()` 资源引用

`$r()` 是编译期宏，用来引用 `resources/` 目录里的资源。

```typescript
$r('app.string.tab_home')       // 引用本模块 resources 里的字符串
$r('app.color.brand_blue')      // 引用本模块的颜色
$r('app.media.ic_logo')         // 引用本模块的图片
$r('sys.color.font_primary')    // 引用系统颜色
$r('sys.float.Title_M')         // 引用系统字号
$r('sys.symbol.house_fill')     // 引用系统图标
```

命名规则：`$r('<来源>.<类型>.<名字>')`

- 来源：`app`（你自己的） / `sys`（系统的）
- 类型：`string` / `color` / `float` / `media` / `symbol` / `plural` 等

还有个 `$rawfile()`，用来引用 `resources/rawfile/` 下的原始文件（不参与编译处理）：

```typescript
Image($rawfile('images/photo.png'))
```

**类型**：`$r()` 返回 `Resource` 类型。很多属性接受 `ResourceStr = string | Resource`，
意思是「你可以给字符串，也可以给资源引用」。

第 10 章详讲。

## C.4 `$$` 双向绑定

`$$` 让组件的值和你的状态变量双向同步。

```typescript
// 单向：用户输入不会自动写回 this.residentSearch，需要手动 onChange
TextInput({ placeholder: '搜索', text: this.residentSearch })
  .onChange((val: string) => { this.residentSearch = val; })

// 双向：用户输入自动写回 this.residentSearch
TextInput({ placeholder: '搜索', text: $$this.residentSearch })
```

**本项目的真实例子**（`component/TabPageView.ets` 第 1506 行）：

```typescript
TextInput({ placeholder: '搜索姓名或房间号', text: $$this.residentSearch })
  .placeholderColor($r('sys.color.font_tertiary'))
  .fontSize($r('sys.float.Body_M'))
```

对比同项目 `pages/LoginPage.ets` 的手动写法：

```typescript
TextInput({ placeholder: '手机号 / 工号', text: this.account })
  .onChange((val: string) => { this.account = val; })   // 手动同步
```

两种都对。`$$` 更简洁，手动 `onChange` 更可控（可以在同步前做校验/格式化）。

## C.5 尾随闭包语法

容器组件后面跟一个 `{ }` 来放子组件，这在 ArkTS 里是特殊语法：

```typescript
Column() {           // ← 这个 { } 不是对象字面量，是子组件容器
  Text('a')
  Text('b')
}
.width('100%')       // ← 属性接在闭包后面
```

带构造参数时：

```typescript
Column({ space: 20 }) {    // ← 前面的 ( ) 是构造参数，后面的 { } 是子组件
  Text('a')
}
```

## C.6 `ESObject`

跟「类型不确定的外部数据」交互时的逃生舱：

```typescript
@Builder
private destinationBuilder(name: string, param?: ESObject) { }
```

**只在边界使用**，拿到后立刻转成具体类型。

## C.7 `Object` 类型

ArkTS 里 `Object` 是所有对象的基类（注意是大写 O）：

```typescript
public debug(...args: Object[]): void {     // Logger.ets 的真实签名
  hilog.debug(this.domain, this.prefix, this.format, args);
}
```

---

## C.8 本项目的 Linter 配置

`KangxiaobanAI/code-linter.json5`：

```json5
{
  "files": ["**/*.ets"],
  "ignore": [
    "**/src/ohosTest/**/*",   // 测试代码不检查
    "**/src/test/**/*",
    "**/src/mock/**/*",
    "**/node_modules/**/*",
    "**/oh_modules/**/*",
    "**/build/**/*",
    "**/.preview/**/*"
  ],
  "ruleSet": [
    "plugin:@performance/recommended",       // 性能规则集
    "plugin:@typescript-eslint/recommended"  // TS 规范集
  ],
  "rules": {
    // ⚠️ 以下全部是 error 级别，会让构建失败
    "@security/no-unsafe-aes": "error",
    "@security/no-unsafe-hash": "error",
    "@security/no-unsafe-mac": "warn",
    "@security/no-unsafe-dh": "error",
    "@security/no-unsafe-dsa": "error",
    "@security/no-unsafe-ecdsa": "error",
    "@security/no-unsafe-rsa-encrypt": "error",
    "@security/no-unsafe-rsa-sign": "error",
    "@security/no-unsafe-rsa-key": "error",
    "@security/no-unsafe-dsa-key": "error",
    "@security/no-unsafe-dh-key": "error",
    "@security/no-unsafe-3des": "error"
  }
}
```

**结论**：

1. **绝对不要引入弱加密算法**（MD5、SHA1、DES、3DES、ECB 模式的 AES、短密钥的 RSA/DSA/DH）。
   这些规则是 `error`，一旦触发**构建直接失败**。
2. `@performance/recommended` 会检查性能问题，比如在 `build()` 里创建对象、用了低效的循环等。
3. 测试和 mock 目录不检查，所以那里的代码风格不代表项目规范。

---

## C.9 常见编译错误与修改方式

| 报错关键词 | 原因 | 改法 |
|---|---|---|
| `arkts-no-any-unknown` | 用了 `any`/`unknown` | 写具体类型，或用 `ESObject` |
| `arkts-no-var` | 用了 `var` | 改 `let`/`const` |
| `arkts-no-props-by-index` | `obj['k']` | 改 `obj.k` 或用 `Map` |
| `arkts-no-untyped-obj-literals` | 对象字面量类型不明 | 加 `interface` 或 `as XXX` |
| `arkts-no-standalone-this` | 独立函数里用 `this` | 改成类方法或箭头函数 |
| `arkts-no-structural-typing` | 缺少 `implements` | 显式写 `implements Xxx` |
| `arkts-no-func-apply-bind-call` | 用了 `bind`/`call`/`apply` | 改箭头函数 |
| `Property 'x' does not exist on type 'Y'` | 类型里没这个字段 | 检查 interface 定义 |
| `Type 'A' is not assignable to type 'B'` | 类型不匹配 | 检查类型，或加 `as`（谨慎） |
| `Object is possibly 'undefined'` | 可能是空 | 加 `?.` 或 `??` 或 `!`（谨慎） |

---

下一章 → [02-声明式UI原理.md](./02-声明式UI原理.md)
