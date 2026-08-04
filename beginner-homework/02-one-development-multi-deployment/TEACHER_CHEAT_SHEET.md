# 老师一页速记卡

## 本课只讲一句话

> 同一份页面，窗口窄时上下排，窗口宽时左右排。

## 上课前必须改

文件：

```text
entry/src/main/module.json5
```

内容：

```json5
"deviceTypes": [
  "phone",
  "tablet",
  "2in1"
],
```

否则 Tablet 会报：

```text
Required device type: tablet
current module device type: phone
```

## 四个答案

### TODO 1

```typescript
this.currentBreakpoint = breakpoint;
```

### TODO 2

```typescript
span: { xs: 4, sm: 4, md: 3, lg: 4, xl: 4 }
```

### TODO 3

```typescript
span: { xs: 4, sm: 4, md: 5, lg: 8, xl: 8 }
```

### TODO 4

```typescript
return this.isWideLayout() ? 32 : 16;
```

## 验收

窄窗口：

```text
显示“手机单列”
长者卡在上
任务卡在下
```

宽窗口：

```text
显示“宽屏双栏”
长者卡在左
任务卡在右
```

## 卡住怎么办

完整答案文件：

```text
teacher/Index.completed.ets
```

直接整体替换学生的 `Index.ets`。

## 老师最后总结

> 今天没有写手机版和平板版两套页面。我们只改了卡片占几列，所以一份代码可以适配窄窗口和宽窗口。
