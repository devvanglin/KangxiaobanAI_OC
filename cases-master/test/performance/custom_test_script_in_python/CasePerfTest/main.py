import time
from xdevice.__main__ import main_process

try:
    pass_dict = dict()
    pass_dict['task_id'] = time.strftime('%Y%m%d%H%M%S', time.localtime())

    cmd = 'run -l CASE_ColdStartPerfTest -ta pass_through:' + str(pass_dict)

    main_process(cmd)
    time.sleep(10)
except Exception as e:
    print(e)
finally:
    print("Task is End")
