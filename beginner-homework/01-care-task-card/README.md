# 第 1 份作业：今日照护任务卡

这是一份面向 HarmonyOS / ArkTS 零基础学习者的独立练习。它不会修改 `KangxiaobanAI` 产品源码，也不需要连接网络、数据库或真实养老服务。

## 你要做什么

完成一个“今日照护任务卡”页面：

1. 点击“记录饮水”，饮水杯数加 1；
2. 点击“完成任务”，状态变成“已完成”；
3. 再次点击可以恢复“待完成”；
4. 状态由父组件管理，子组件只通过事件通知父组件。

预计用时：60～90 分钟。

## 开始前先读

1. `docs/HarmonyOS完全指南/00-零基础世界观.md`
2. `docs/HarmonyOS完全指南/02-声明式UI原理.md`
3. `docs/HarmonyOS完全指南/04-布局系统.md` 中的 `Column` 和 `Row`
4. `docs/HarmonyOS完全指南/05-状态管理V2.md` 中的 `@Local`、`@Param`、`@Require` 和 `@Event`

## 准备工程

1. 在 DevEco Studio 新建独立的 ArkTS Empty Ability 工程；
2. 使用 Stage 模型，SDK/API 优先选择 API 24；
3. 找到练习工程的入口页面 `Index.ets`；
4. 用本目录的 `starter/Index.ets` 整体替换其内容；
5. 运行 Previewer、模拟器或真机预览。

如果模板使用 V1 的 `@State`，请整体替换，不要把 V1 和 V2 代码拼在一起。

## 基础任务

完成起始代码中的两个 TODO：

- `TODO 1`：让 `waterCups` 加 1；
- `TODO 2`：让 `isDone` 在 `true` 和 `false` 之间切换。

数据流如下：

```text
Index 的 @Local 状态
  -> 通过 @Param 传给 CareTaskCard
  -> 用户点击按钮
  -> CareTaskCard 通过 @Event 通知 Index
  -> Index 修改 @Local
  -> 界面自动刷新
```

## 验收标准

- [ ] 初始显示“0 杯”和“待完成”；
- [ ] 连续点击三次后显示“3 杯”；
- [ ] 点击完成后显示“已完成”和“恢复待办”；
- [ ] 再次点击可以回到“待完成”；
- [ ] 使用 `@Entry`、`@ComponentV2`、`@Local`、`@Param` 和 `@Event`；
- [ ] 没有使用 `@State`、`@Prop`、`@Link` 或 `@Watch`；
- [ ] 没有修改正式产品或参考示例。

## 加分题

任选一项：

1. 饮水最多记录 8 杯；
2. 增加重置功能；
3. 增加无障碍说明；
4. 把文字迁移到字符串资源；
5. 使用系统资源适配深色模式和大字体。

## 提交内容

1. 完成后的 `Index.ets`；
2. 初始状态截图；
3. “3 杯、已完成”截图；
4. 填写 `SUBMISSION.md`。

## 教师资料

- `TEACHING_PLAN.md`：常规 90 分钟教案；
- `BABYSITTER_GUIDE.md`：老师半懂也能照着上的逐步手册；
- `teacher/Index.completed.ets`：教师完成版代码。
