# 第 2 份作业：长者关怀看板——一次开发，多端部署

这是一份面向 HarmonyOS / ArkTS 初学者的独立练习。学生使用同一份 `Index.ets`，让页面根据窗口宽度自动切换布局：

- 手机窄窗口：长者信息和今日任务上下排列；
- 平板、折叠屏展开态或 2-in-1 宽窗口：长者信息和今日任务左右排列；
- 窗口变宽时增加页面留白，但正文不会无限拉伸。

本作业不修改 `KangxiaobanAI` 正式产品，也不连接网络、数据库、AI 或真实养老服务。

## 文件说明

- `STUDENT_ASSIGNMENT.md`：发给学生的任务书；
- `TEACHER_SCRIPT_SIMPLE.md`：老师优先使用的 60 分钟简明逐字稿；
- `TEACHER_CHEAT_SHEET.md`：一页速记卡，包含四个答案和排错方法；
- `TEACHER_SCRIPT.md`：详细参考资料，不要求老师上课全部讲解；
- `SUBMISSION.md`：学生提交单；
- `starter/Index.ets`：学生起始代码，包含 4 个 TODO；
- `teacher/Index.completed.ets`：教师完成版和课堂兜底代码；
- `teacher/ANSWER_KEY.md`：答案、验收口径和评分建议。

## 本课核心口诀

> 不是判断设备叫什么，而是判断当前窗口有多宽；同一份数据，同一份代码，按断点重新排版。

老师如果第一次讲本课，只需要打开 `TEACHER_SCRIPT_SIMPLE.md` 和 `TEACHER_CHEAT_SHEET.md`，不用先读详细参考资料。

## 课前建议

1. 先完成第 1 份作业，至少认识 `@ComponentV2`、`@Local`、`Column` 和 `Row`；
2. 新建独立 ArkTS Empty Ability 工程，Stage 模型，SDK/API 优先选择 API 24；
3. 在模块 `module.json5` 中确认 `deviceTypes` 包含 `phone`、`tablet` 和 `2in1`；
4. 用 `starter/Index.ets` 整体替换练习工程入口页面；
5. 至少准备两种窗口宽度进行验证。没有平板或 2-in-1 真机时，可使用 Previewer 或可调整窗口大小的模拟器。

## 实现边界

本课只练习响应式布局和窗口断点：

- 使用 ArkUI V2；
- 使用 `GridRow`、`GridCol` 和 `onBreakpointChange`；
- 不使用 `deviceInfo.deviceType` 决定布局；
- 不增加网络、权限、持久化、导航或第三方依赖；
- 预览器验证只能称为“预览验证”，不能称为“真机验证”。
