from hypium import BY
from hypium.advance.perf.application_model.model_base import ModelBase
from hypium.advance.perf.driver_perf.idriver_perf import IDriverPerf
from hypium.advance.perf.driver_perf.tag import SceneType
from hypium.model import UiParam

'''
@原子用例
主界面浏览
@预置条件
无
@用例步骤
1.冷启动通用开发范例
2.上滑19次浏览界面
3.下滑20次浏览界面
4.滑动左滑3次动轮播图
5.滑动右滑3次动轮播图
6.点击轮播图进入案例
7.侧滑返回
8.依次点击Tab栏中按钮（从UI布局 到 其他）
9.左滑Tab栏
10.击点击Tab栏中的全部按钮
11.依次点击瀑布流中(1-10)的案例
12.上滑返回桌面
'''
APP_NAME = "通用开发范例"
CASE_LIST_ARRAY = ['MpChart图表实现', '地址交换动画', '自定义TabBar页签', '列表二级联动', '预加载so并读取RawFile文件',
                   '阻塞事件冒泡', '图片缩放功能实现', '列表编辑', '增删tab页签', '全屏登录页面']

class CaseMainPageBrowering(ModelBase):  # 原子用例统一继承ModelBase

    def __init__(self, uidriver: IDriverPerf, case_id):  # 进行初始化操作
        ModelBase.__init__(self, uidriver, case_id)  # 调用父类初始化方法
        self.scene_no = "case_main_page_browsing"  # 原子用例id
        self.scene_name = "通用开发范例界面浏览"  # 原子用例名字
        self.scene_type = "通用开发范例主页场景"  # 原子用例类型
        self.scene_path = "日常高频操作-基础操作场景-范例通用操作场景-范例主页场景"  # 原子用例所属路径
        self.driver = uidriver

    def setup(self):  # 原子用例预置动作
        # 停止指定的应用
        self.driver.stop_app('com.north.commonappdevelopment')
        # 返回手机桌面主页
        self.driver.go_home()

    @ModelBase.scene_recover
    def execute(self):
        # 1.冷启动设置
        # find_app_in_launcher 从主页开始滑动查找对应APP名的应用，应用需要在桌面上可见，返回的是（x，y）坐标值元组
        icon_pos = self.driver.find_app_in_launcher("通用开发范例")

        # 创建性能场景Tag, 使用继承ModelBase的方法create_tag，设置step_name步骤描述，step_type对应性能tag类型
        Tag = self.create_tag(step_name="冷启动范例", scene_type=SceneType.COLD_START)

        # touch_perf 模拟手指点击
        self.driver.touch_perf(icon_pos, tag=Tag)

        # 等待指定时间，等待界面稳定，再进行下一步操作
        self.driver.wait(1)

        # 2.上滑19次浏览界面
        # swipe_perf 在屏幕上或者指定区域area中执行朝向指定方向direction的滑动操作
        for i in range(19):
            self.driver.swipe_perf(UiParam.UP,
                                   tag=self.create_tag("上滑浏览界面", SceneType.NO_PAGE_SWITCH))

        # 3.下滑20次浏览界面
        for i in range(20):
            self.driver.swipe_perf(UiParam.DOWN,
                                   tag=self.create_tag("下滑浏览界面", SceneType.NO_PAGE_SWITCH))

        # 4.左滑轮播图三次
        for i in range(2):
            self.driver.swipe_perf(UiParam.LEFT, area=BY.id("MainSwiper"),
                                   tag=self.create_tag("左滑轮播图", SceneType.NO_PAGE_SWITCH))

        # 5.右滑轮播图三次
        for i in range(2):
            self.driver.swipe_perf(UiParam.RIGHT, area=BY.id("MainSwiper"),
                                   tag=self.create_tag("右滑轮播图", SceneType.NO_PAGE_SWITCH))

        # 6.点击轮播图进入案例
        self.driver.touch_perf(BY.id("MainSwiper"),
                               tag=self.create_tag("点击轮播图进入案例", SceneType.WITH_PAGE_SWITCH))

        # 7.侧滑返回
        # swipe_to_back_perf 滑动屏幕右侧返回
        self.driver.swipe_to_back_perf(tag=self.create_tag("侧滑返回", SceneType.WITH_PAGE_SWITCH))

        # 8.依次点击Tab栏中按钮（从UI布局 到 其他）
        self.driver.touch_perf(BY.text("UI布局"),
                               tag=self.create_tag("点击UI布局按钮", SceneType.NO_PAGE_SWITCH))

        self.driver.touch_perf(BY.text("动效"),
                               tag=self.create_tag("点击动效按钮", SceneType.NO_PAGE_SWITCH))

        self.driver.touch_perf(BY.text("三方库"),
                               tag=self.create_tag("点击三方库按钮", SceneType.NO_PAGE_SWITCH))

        self.driver.touch_perf(BY.text("Native"),
                               tag=self.create_tag("点击Native按钮", SceneType.NO_PAGE_SWITCH))

        self.driver.touch_perf(BY.text("性能示例"),
                               tag=self.create_tag("点击性能示例按钮", SceneType.NO_PAGE_SWITCH))

        self.driver.touch_perf(BY.text("其他"),
                               tag=self.create_tag("点击其他按钮", SceneType.NO_PAGE_SWITCH))

        # 9.左滑Tab栏
        self.driver.swipe_perf(UiParam.RIGHT, area=BY.id("MainList"),
                               tag=self.create_tag("左滑轮播图", SceneType.NO_PAGE_SWITCH))

        # 10.击点击Tab栏中的全部按钮
        self.driver.touch_perf(BY.text("全部"),
                               tag=self.create_tag("点击全部按钮", SceneType.NO_PAGE_SWITCH))

        # 11.依次点击瀑布流中的案例
        for i in range(len(CASE_LIST_ARRAY)):
            self.driver.touch_perf(BY.text(CASE_LIST_ARRAY[i]), scroll_target=BY.type("WaterFlow"),
                                   tag=self.create_tag("点击" + CASE_LIST_ARRAY[i], SceneType.WITH_PAGE_SWITCH))
            self.driver.swipe_to_back_perf(tag=self.create_tag("侧滑返回", SceneType.WITH_PAGE_SWITCH))

        # 12.上滑返回桌面
        # swipe_to_home_perf 从屏幕底部上滑返回桌面
        self.driver.swipe_to_home_perf(tag=self.create_tag("上滑返回桌面", SceneType.WITH_PAGE_SWITCH))


def teardown(self):
    # 原子用例结束清理步骤
    # 停止指定的应用
    self.driver.stop_app('com.north.commonappdevelopment')
