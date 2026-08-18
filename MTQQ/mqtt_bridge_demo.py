#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
雷达数据 → 房间 路由 Demo

功能:
    订阅 MQTT Broker 上的雷达消息,从 topic 提取 device_id,
    查绑定表(room_device_map.json)定位房间,解析数值并打印。

用法:
    # 真连 broker
    python mqtt_bridge_demo.py --host 192.168.1.100 --port 1883

    # 无 broker,用模拟消息验证路由逻辑
    python mqtt_bridge_demo.py --mock

依赖:
    pip install paho-mqtt
"""

import argparse
import json
import os
import sys

try:
    import paho.mqtt.client as mqtt
    HAS_MQTT = True
except ImportError:
    HAS_MQTT = False

# 绑定表路径(与脚本同目录)
MAP_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "room_device_map.json")

# 字段中文名(打印用)
FIELD_LABELS = {
    "online": "在线",
    "someoneExists": "有人",
    "motionStatus": "运动状态",
    "movementSigns": "体动幅度",
    "humanDistance": "人体距离",
    "breathValue": "呼吸数值",
    "heartRateValue": "心率",
    "sleepStatus": "睡眠状态",
    "sleepScore": "睡眠评分",
    "awakeDuration": "清醒时长",
    "lightSleepDuration": "浅睡时长",
    "deepSleepDuration": "深睡时长",
    "getIntoBed": "入床",
    "fallStatus": "跌倒报警",
    "fallPosition": "跌倒位置",
    "residentStatus": "静止驻留",
}


def load_map():
    """读绑定表: device_id -> {room, resident, product}"""
    if not os.path.exists(MAP_PATH):
        print(f"错误: 找不到绑定表 {MAP_PATH}", file=sys.stderr)
        sys.exit(1)
    with open(MAP_PATH, encoding="utf-8") as f:
        return json.load(f)


def extract_device_id(topic):
    """topic 形如 /Radar60SP/{device_id}/sys/property/post,取第3段"""
    parts = topic.split("/")
    # ["", "Radar60SP", device_id, "sys", "property", "post"]
    return parts[2] if len(parts) >= 3 else None


def route(device_map, topic, payload):
    """一条雷达消息的路由处理:识别设备 → 定位房间 → 解析数值"""
    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        print(f"[跳过] 非 JSON 消息: {payload[:80]}")
        return

    device_id = extract_device_id(topic)
    if not device_id:
        print(f"[跳过] 无法识别设备ID, topic={topic}")
        return

    binding = device_map.get(device_id)
    if not binding:
        print(f"[未绑定] 设备 {device_id} 未在绑定表中,忽略")
        return

    params = data.get("params", {})
    room = binding["room"]
    resident = binding.get("resident", "")
    product = binding.get("product", "")

    for field, value in params.items():
        label = FIELD_LABELS.get(field, field)
        person = f"({resident})" if resident else ""
        print(f"[{room}] {person} {product} {label} = {value}")

        # ==== 这里就是"推送前端/写库"的接入点 ====
        # 生产环境在此调用:
        #   update_state(room, field, value)      # 写 Redis
        #   push_websocket(room, field, value)    # 推给前端
        # ========================================


# ---------- 真实 MQTT 订阅 ----------
def run_real(host, port):
    if not HAS_MQTT:
        print("错误: 未安装 paho-mqtt,请先执行 pip install paho-mqtt", file=sys.stderr)
        sys.exit(1)

    device_map = load_map()

    def on_connect(client, userdata, flags, rc):
        client.subscribe("/Radar60SP/#")
        client.subscribe("/Radar60FL/#")
        print(f"已连接 {host}:{port},订阅 /Radar60SP/# 和 /Radar60FL/#")

    def on_message(client, userdata, msg):
        route(device_map, msg.topic, msg.payload.decode("utf-8", errors="ignore"))

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(host, port, 60)
    print("等待雷达消息...(Ctrl+C 退出)")
    client.loop_forever()


# ---------- 模拟模式 ----------
def run_mock():
    device_map = load_map()
    samples = [
        ("/Radar60SP/RadarID_ABC123/sys/property/post",
         '{"version":"1.0","method":"post","params":{"someoneExists":"1"}}'),
        ("/Radar60SP/RadarID_ABC123/sys/property/post",
         '{"version":"1.0","method":"post","params":{"breathValue":"18"}}'),
        ("/Radar60SP/RadarID_ABC123/sys/property/post",
         '{"version":"1.0","method":"post","params":{"heartRateValue":"72"}}'),
        ("/Radar60SP/RadarID_ABC123/sys/property/post",
         '{"version":"1.0","method":"post","params":{"sleepStatus":"0"}}'),
        ("/Radar60FL/RadarID_GHI789/sys/property/post",
         '{"version":"1.0","method":"post","params":{"fallStatus":"1"}}'),
        ("/Radar60FL/RadarID_UNKNOWN/sys/property/post",
         '{"version":"1.0","method":"post","params":{"someoneExists":"1"}}'),
    ]
    print("=== 模拟模式:本地生成消息走一遍路由 ===\n")
    for topic, payload in samples:
        route(device_map, topic, payload)
    print("\n=== 路由逻辑演示完毕 ===")


def main():
    parser = argparse.ArgumentParser(description="雷达数据→房间路由 Demo")
    parser.add_argument("--mock", action="store_true", help="模拟模式,不连真实 broker")
    parser.add_argument("--host", default="192.168.1.100", help="MQTT broker 地址")
    parser.add_argument("--port", type=int, default=1883, help="MQTT broker 端口")
    args = parser.parse_args()

    if args.mock:
        run_mock()
    else:
        run_real(args.host, args.port)


if __name__ == "__main__":
    main()
