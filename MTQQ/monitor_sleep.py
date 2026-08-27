#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
呼吸心率睡眠雷达(R60ASM1/R60ABD1)实时监控脚本

功能:订阅睡眠雷达的上报主题,实时打印呼吸、心率、睡眠状态、入离床等数据。

依赖:
    pip install paho-mqtt

用法:
    python monitor_sleep.py
"""

import paho.mqtt.client as mqtt
import json
import time

BROKER = "192.168.100.110"      # MQTT 服务器
DEVICE = "E438192584F5"          # 设备 ID(呼吸心率雷达)

FIELD_LABELS = {
    "online": "在线",
    "someoneExists": "有人",
    "movementSigns": "体动幅度",
    "breathValue": "呼吸数值",
    "breathInform": "呼吸信息",
    "heartRateValue": "心率",
    "heartRateInform": "心率信息",
    "sleepStatus": "睡眠状态",
    "getIntoBed": "入离床",
    "sleepScore": "睡眠评分",
    "awakeDuration": "清醒时长",
    "lightSleepDuration": "浅睡时长",
    "deepSleepDuration": "深睡时长",
    "breathWave": "呼吸波形",
    "heartRateWave": "心率波形",
}

# 枚举字段的中文解释
SLEEP_STATE = {"0": "深睡", "1": "浅睡", "2": "清醒", "3": "无/离床"}
BED_STATE = {"0": "离床", "1": "入床", "2": "无"}
EXISTS = {"0": "无人", "1": "有人"}


def fmt(field, value):
    """给枚举字段加上中文解释"""
    v = str(value)
    if field == "sleepStatus":
        return f"{v}({SLEEP_STATE.get(v, '?')})"
    if field == "getIntoBed":
        return f"{v}({BED_STATE.get(v, '?')})"
    if field == "someoneExists":
        return f"{v}({EXISTS.get(v, '?')})"
    return v


def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload)
    except Exception:
        return
    params = data.get("params", {})
    ts = time.strftime("%H:%M:%S")
    for k, v in params.items():
        label = FIELD_LABELS.get(k, k)
        print(f"[{ts}] {label} = {fmt(k, v)}")


def main():
    topic = f"/Radar60SP/{DEVICE}/sys/property/post"
    client = mqtt.Client(client_id="sleep_monitor")
    client.on_message = on_message
    client.connect(BROKER, 1883, 60)
    client.subscribe(topic)
    print(f"正在监控: {topic}")
    print("人躺到床上保持静止,就会看到呼吸/心率数值持续上报\n")
    client.loop_forever()


if __name__ == "__main__":
    main()
