# TaskPool使用规范和常见问题测试用例

## 用例表

| 测试功能                        | 预置条件                                        | 输入                          | 预期输出                                           | 是否自动 | 测试结果 |
|-----------------------------|---------------------------------------------|-----------------------------|------------------------------------------------|------|------|
| 避免子线程中直接或间接引入UI【反例】 | 	点击Sample1按钮 | 	点击“Wrong Sample”	 | 打印日志“Bar is not initialized” | 否    | Pass |
| 避免子线程中直接或间接引入UI【正例】                           | 	点击Sample1按钮 | 	点击“Correct Sample”               | 无错误日志打印                                      | 否    | Pass |  
| 避免在非长时任务中使用带有监听性质的接口【反例】 | 	点击Sample2按钮 | 	点击“Wrong Sample”	 | 无日志打印 | 否    | Pass |
| 避免在非长时任务中使用带有监听性质的接口【正例】                           | 	点击Sample2按钮 | 	点击“Correct Sample”               | 有打印日志“receive http msg success”                                      | 否    | Pass |
| 避免在回调函数中使用SendData【反例】 | 	点击Sample3按钮 | 	点击“Wrong Sample”	 | 无日志打印 | 否    | Pass |
| 避免在回调函数中使用SendData【正例】                           | 	点击Sample3按钮 | 	点击“Correct Sample”               | 有打印日志“name is : anonymous”                                      | 否    | Pass |
| 控制并发度 | 	点击Sample4按钮 | 	点击“TaskGroup Sample”	 | 无错误日志打印 | 否    | Pass |    
| 正确处理业务逻辑异常【例1】 | 	点击Sample5按钮 | 	点击“CorrectSample timer”	 | 无错误日志打印 | 否    | Pass |
| 正确处理业务逻辑异常【例2】                           | 	点击Sample5按钮 | 	点击“Correct Sample MainThread Catch”               | 打印错误日志“error info: An exception occurred during serialization, taskpool: failed to serialize arguments”                                      | 否    | Pass |  
| 正确处理业务逻辑异常【例3】                           | 	点击Sample5按钮 | 	点击“Correct Sample TaskPoolThread Catch”               | 打印错误日志“TaskPoolThread error”              | 否    | Pass |  



