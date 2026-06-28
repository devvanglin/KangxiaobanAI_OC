import os

from hypium.advance.perf.application_model.perf_basecase import PerfBaseCase

from models.case_main_page_browsing import CaseMainPageBrowering


# 场景用例名，和py文件名一致，可以自定义，但有推荐命名格式，需同步生成同名的json文件
# 测试用例继承PerfBaseCase
class CASE_ColdStartPerfTest(PerfBaseCase):

    def __init__(self, controllers):  # 初始化操作，这里一般情况下不作变动
        self.TAG = self.__class__.__name__
        self.tests = [  # 指定场景用例执行入口
            "test_step"
        ]
        self.case_id = os.path.splitext(os.path.basename(__file__))[0]  # 文件名, 类名, case_id 三者保持一致
        case_pkg = 'com.north.commonappdevelopment' # 指定被测试应用，用于采集应用资源使用信息，默认不采
        PerfBaseCase.__init__(self, controllers, case_pkg)  # 调用父类初始化方法
        self.log.info("Case id is %s" % self.case_id)

    def setup(self):
        # 场景用例前置化操作，在test_step前执行的一些操作
        self.log.info("预置工作:初始化设备开始................." + self.devices[0].device_sn)

    def test_step(self):
        # 组装需要调用的原子用例，使用原子化用例构建场景步骤，可以一个场景用例添加多个相关的原子用例
        steps = [
            # 原子用例需要传入driver，case_id
            CaseMainPageBrowering(self.driver, self.case_id)
        ]
        # 按顺序执行原子用例
        for item in steps:
            item.execute()

    def teardown(self):
        # 获取用例测试结果
        result = self.get_case_result()

        # 场景用例结束后执行该teardown操作
        self.log.info("收尾工作................., result is {}".format(result))

        # 此处为用例结尾时执行的PerfBaseCase的teardown方法，处理一些结束操作
        PerfBaseCase.teardown(self)
