#!/usr/bin/env bash
#===============================================================================
# hitrace-menu — 交互式 trace 场景选择器
#
# 基于 hitrace-collect skill，通过多级菜单帮助开发者选择场景，
# 自动生成正确的 hitrace 命令并支持一键执行。
#
# 用法:
#   ./hitrace-menu.sh          # 交互式菜单
#   ./hitrace-menu.sh --json   # 输出场景定义 JSON（供 Agent/工具使用）
#   ./hitrace-menu.sh --list   # 列出所有场景及对应命令
#
# 前置条件: hdc 已连接设备
#===============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color
DIM='\033[2m'

# 自动检测 hdc 路径
detect_hdc() {
  local candidates=(
    "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
    "/Applications/DevEco-Studio-alpha.app/Contents/sdk/default/openharmony/toolchains/hdc"
    "$HOME/Library/Huawei/Sdk/HarmonyOS-NEXT-DP2/base/toolchains/hdc"
    "$HOME/Library/Huawei/Sdk/openharmony/11/toolchains/hdc"
    "$HOME/Library/Huawei/Sdk/openharmony/10/toolchains/hdc"
    "/usr/local/bin/hdc"
  )

  for c in "${candidates[@]}"; do
    if [ -x "$c" ]; then
      echo "$c"
      return 0
    fi
  done

  # fallback: which
  if command -v hdc &>/dev/null; then
    echo "hdc"
    return 0
  fi

  return 1
}

# 场景定义数据库
# 格式: 场景名|tag组合|缓冲区KB|时长秒|格式|描述
declare -a SCENES=(
  # === 应用性能 ===
  "应用冷启动|app ace ability ark graphic|51200|10|text|覆盖应用生命周期+UI帧率"
  "页面跳转/导航|app ace ability window|51200|10|text|能力管理+窗口+UI"
  "触控响应|app ace graphic multimodalinput sched|102400|10|text|触控事件+UI+渲染"
  "动画与渲染|ace animation graphic window|51200|10|text|动画帧密集期分析"
  "IPC/Binder通信|binder zbinder app|51200|10|text|binder延迟+IPC调用链"
  "内存分析|memory memreclaim pagecache app|102400|10|text|内存分配+回收+页面缓存"
  "综合应用分析|app ace graphic window sched freq disk|204800|10|text|最全面的日常场景"
  "FFRT任务调度|ffrt sched app|51200|10|text|并发任务调度分析"

  # === 系统性能 ===
  "CPU调度分析|sched freq idle load|51200|10|text|纯内核调度+频率+负载"
  "IRQ中断分析|irq irqoff preemptoff|51200|5|text|中断+抢占关闭追踪"
  "磁盘I/O分析|disk sync ufs|51200|10|text|磁盘读写+同步延迟"
  "电源管理|power freq idle ipa|51200|10|text|功耗+频率+热管理"
  "内核全面分析|sched freq idle disk binder memory workq load ipa|204800|15|text|全面系统级trace"
  "内存总线分析|membus memory memreclaim|102400|10|text|内存总线利用率+回收"

  # === 网络与通信 ===
  "网络请求|app net|51200|10|text|网络模块打点"
  "蓝牙通信|bluetooth|51200|10|text|蓝牙协议栈"
  "分布式协同|dsoftbus dsched dscreen daudio|102400|15|text|分布式场景全链路"

  # === 多媒体 ===
  "音频播放/录制|zaudio app|51200|10|text|音频管线+应用"
  "视频/相机|zmedia zcamera zimage app|102400|15|text|多媒体全链路"
  "图形渲染管线|graphic ace window|102400|10|text|RS渲染+UI合成"

  # === 系统服务 ===
  "通知服务|notification app|51200|10|text|通知子系统"
  "传感器|sensors|51200|10|text|传感器事件"
  "多模态输入|multimodalinput app|51200|10|text|输入事件分发链路"
  "安全/密钥|security huks useriam|51200|10|text|安全子系统+密钥管理"
  "文件/存储|filemanagement disk|51200|10|text|文件系统+存储"

  # === 快照模式 ===
  "快照(文本)-自定义tag|--snapshot-text|102400|0|text|手动控制开始/停止,按需dump"
  "快照(二进制)-默认tag|--snapshot-raw|102400|0|raw|后台trace_service,使用默认34个tag"

  # === 录制模式 ===
  "长时间录制(二进制)|--record|204800|0|raw|长时间跑测,自动分片落盘"
)

# 菜单层级定义
print_header() {
  clear 2>/dev/null || true
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║          📊 Hitrace 场景选择器 v1.0                  ║"
  echo "║          based on hitrace-collect skill              ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

print_scene_info() {
  local scene_name="$1"
  local tags="$2"
  local buf="$3"
  local dur="$4"
  local fmt="$5"
  local desc="$6"

  echo -e "\n${YELLOW}══════════ 场景信息 ══════════${NC}"
  echo -e "  ${BOLD}场景:${NC}    ${GREEN}${scene_name}${NC}"
  echo -e "  ${BOLD}描述:${NC}    ${desc}"
  echo -e "  ${BOLD}Tag:${NC}     ${CYAN}${tags}${NC}"
  echo -e "  ${BOLD}缓冲区:${NC}  ${buf}KB ($((buf/1024))MB)"
  echo -e "  ${BOLD}时长:${NC}    ${dur}s"
  echo -e "  ${BOLD}格式:${NC}    ${fmt}"
}

confirm() {
  local prompt="${1:-确认?}"
  echo ""
  read -r -p "  $prompt [Y/n]: " answer
  case "${answer:-y}" in
    [Yy]*|[Yy][Ee][Ss]*) return 0 ;;
    *) return 1 ;;
  esac
}

# 检查设备连接
check_device() {
  local hdc="$1"
  local devices
  devices=$("$hdc" list targets 2>/dev/null || true)
  if [ -z "$devices" ]; then
    echo -e "${RED}❌ 未检测到设备连接${NC}"
    echo -e "   请确保设备通过 USB 连接且 hdc 可访问"
    echo -e "   hdc 路径: ${hdc}"
    return 1
  fi
  echo -e "${GREEN}✅ 已连接设备: ${devices}${NC}"
  return 0
}

# 执行 trace 采集
execute_trace() {
  local hdc="$1"
  local scene_name="$2"
  local tags="$3"
  local buf="$4"
  local dur="$5"
  local fmt="$6"

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local local_dir="${HOME}/Documents"
  local output_name="${scene_name//\//_}_${timestamp}"

  case "$tags" in
    "--snapshot-text")
      # 快照模式-文本
      echo -e "\n${CYAN}📸 快照模式 (文本)${NC}"
      echo -e "   执行: hitrace --trace_begin -b ${buf} app ace graphic window sched freq disk"
      echo -e "   ${YELLOW}ℹ️  快照模式需要手动控制:${NC}"
      echo -e "   ${YELLOW}   先执行 --trace_begin 开启采集${NC}"
      echo -e "   ${YELLOW}   问题复现后执行 --trace_dump -o 导出${NC}"
      echo -e "   ${YELLOW}   最后执行 --trace_finish 或 --trace_finish_nodump 结束${NC}"
      echo ""

      if confirm "是否开始快照采集?"; then
        echo -e "\n${GREEN}▶ 开始快照采集...${NC}"
        "$hdc" shell "hitrace --trace_begin -b ${buf} app ace graphic window sched freq disk"

        echo ""
        echo -e "${YELLOW}┌─────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│  📌 快照模式已启动,请:                  │${NC}"
        echo -e "${YELLOW}│     1. 在设备上复现问题                 │${NC}"
        echo -e "${YELLOW}│     2. 回到此处按任意键导出trace        │${NC}"
        echo -e "${YELLOW}└─────────────────────────────────────────┘${NC}"
        read -r -p ""

        local device_path="/data/local/tmp/${output_name}.ftrace"
        "$hdc" shell "hitrace --trace_dump -o ${device_path}"
        "$hdc" file recv "${device_path}" "${local_dir}/${output_name}.ftrace"
        echo -e "${GREEN}✅ Trace 已导出到: ${local_dir}/${output_name}.ftrace${NC}"

        if confirm "是否停止快照采集?"; then
          "$hdc" shell "hitrace --trace_finish_nodump"
          echo -e "${GREEN}✅ 快照采集已停止${NC}"
        fi
      fi
      ;;

    "--snapshot-raw")
      # 快照模式-二进制(bgsrv)
      echo -e "\n${CYAN}📸 快照模式 (二进制/bgsrv)${NC}"
      echo -e "   执行: hitrace --start_bgsrv"
      echo -e "   ${YELLOW}ℹ️  使用系统默认 34 个 tag,输出二进制 .sys 格式${NC}"
      echo ""

      if confirm "是否启动 bgsrv 快照采集?"; then
        echo -e "\n${GREEN}▶ 启动 trace_service...${NC}"
        "$hdc" shell "hitrace --start_bgsrv"

        echo ""
        echo -e "${YELLOW}┌─────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│  📌 trace_service 已启动,请:            │${NC}"
        echo -e "${YELLOW}│     1. 在设备上复现问题                 │${NC}"
        echo -e "${YELLOW}│     2. 回到此处按任意键导出trace        │${NC}"
        echo -e "${YELLOW}└─────────────────────────────────────────┘${NC}"
        read -r -p ""

        echo -e "\n${GREEN}▶ 导出 trace...${NC}"
        local dump_output
        dump_output=$("$hdc" shell "hitrace --dump_bgsrv" 2>&1)
        echo "   ${dump_output}"

        # 提取输出文件路径,拉取到本地
        local device_path
        device_path=$(echo "$dump_output" | grep -o '/data/log/hitrace/[^ ]*\.sys' | tail -1)
        if [ -n "${device_path}" ]; then
          "$hdc" file recv "${device_path}" "${local_dir}/${output_name}.sys"
          echo -e "${GREEN}✅ Trace 已导出到: ${local_dir}/${output_name}.sys${NC}"
          echo -e "${CYAN}💡 使用 SmartPerf Host 打开 .sys 文件进行可视化分析${NC}"
        else
          echo -e "${YELLOW}⚠️  无法解析输出路径,请手动检查 /data/log/hitrace/ 目录${NC}"
        fi

        if confirm "是否停止 trace_service?"; then
          "$hdc" shell "hitrace --stop_bgsrv"
          echo -e "${GREEN}✅ trace_service 已停止${NC}"
        fi
      fi
      ;;

    "--record")
      # 录制模式
      echo -e "\n${CYAN}📼 录制模式 (二进制,自动分片)${NC}"
      echo -e "   执行: hitrace --trace_begin --record -b ${buf} --file_size 102400 app ace graphic sched freq"
      echo -e "   ${YELLOW}ℹ️  长时间录制,文件达到100MB自动分片${NC}"
      echo ""

      if confirm "是否开始长时间录制?"; then
        echo -e "\n${GREEN}▶ 开始录制...${NC}"
        "$hdc" shell "hitrace --trace_begin --record -b ${buf} --file_size 102400 app ace graphic sched freq" &

        echo -e "${YELLOW}按 Enter 停止录制...${NC}"
        read -r

        echo -e "\n${GREEN}▶ 停止录制并导出...${NC}"
        local finish_output
        finish_output=$("$hdc" shell "hitrace --trace_finish --record" 2>&1)
        echo "   ${finish_output}"

        # 提取所有输出文件路径,拉取到本地
        local file_count=0
        while IFS= read -r line; do
          local f
          f=$(echo "$line" | grep -o '/data/log/hitrace/[^ ]*\.sys' || true)
          if [ -n "${f}" ]; then
            local local_name="${output_name}_$(printf '%02d' $file_count).sys"
            "$hdc" file recv "${f}" "${local_dir}/${local_name}"
            echo -e "${GREEN}✅ 文件 ${file_count}: ${local_dir}/${local_name}${NC}"
            file_count=$((file_count + 1))
          fi
        done <<< "${finish_output}"

        echo -e "${GREEN}✅ 共导出 ${file_count} 个文件到 ${local_dir}/${NC}"
      fi
      ;;

    *)
      # 标准定时采集
      local device_path="/data/local/tmp/${output_name}.ftrace"

      local cmd="hitrace -t ${dur} -b ${buf}"
      if [ "$fmt" = "raw" ]; then
        cmd="${cmd} --raw ${tags}"
      else
        cmd="${cmd} ${tags} -o ${device_path}"
      fi

      echo -e "\n${CYAN}⚡ 定时采集 (${dur}s)${NC}"
      echo -e "   命令: ${cmd}"
      echo ""

      if confirm "是否立即执行采集?"; then
        echo -e "\n${GREEN}▶ 开始采集 ${dur}s...${NC}"
        "$hdc" shell "${cmd}"

        if [ "$fmt" = "raw" ]; then
          echo -e "${YELLOW}⚠️  二进制格式输出到 /data/log/hitrace/,需手动拉取${NC}"
          echo -e "${CYAN}💡 拉取命令: hdc file recv /data/log/hitrace/<文件名> ${local_dir}/${NC}"
        else
          "$hdc" file recv "${device_path}" "${local_dir}/${output_name}.ftrace"
          echo -e "${GREEN}✅ Trace 已保存到: ${local_dir}/${output_name}.ftrace${NC}"
          local filesize
          filesize=$(ls -lh "${local_dir}/${output_name}.ftrace" 2>/dev/null | awk '{print $5}')
          echo -e "   文件大小: ${filesize}"
        fi
      else
        echo -e "${CYAN}📋 手动执行命令:${NC}"
        echo -e "   ${GREEN}${cmd}${NC}"
        if [ "$fmt" != "raw" ]; then
          echo ""
          echo -e "${CYAN}📥 拉取文件:${NC}"
          echo -e "   ${GREEN}hdc file recv ${device_path} ${local_dir}/${NC}"
        fi
      fi
      ;;
  esac
}

# 列出所有场景定义（供 Agent 使用）
list_all_scenes() {
  echo "场景名 | Tag组合 | 缓冲区KB | 时长秒 | 格式 | 命令模板"
  echo "-------|---------|---------|--------|------|---------"
  for scene in "${SCENES[@]}"; do
    IFS='|' read -r name tags buf dur fmt desc <<< "${scene}"
    local cmd
    if [[ "$tags" == "--snapshot-text" ]]; then
      cmd="--trace_begin ... --trace_dump -o ... --trace_finish_nodump"
    elif [[ "$tags" == "--snapshot-raw" ]]; then
      cmd="--start_bgsrv ... --dump_bgsrv ... --stop_bgsrv"
    elif [[ "$tags" == "--record" ]]; then
      cmd="--trace_begin --record ... --trace_finish --record"
    else
      cmd="hitrace -t ${dur} -b ${buf} ${tags} -o /data/local/tmp/<name>.ftrace"
    fi
    echo "${name} | ${tags} | ${buf} | ${dur} | ${fmt} | ${cmd}"
  done
}

# 从场景数据库获取某一项
get_scene_by_name() {
  local target="$1"
  for scene in "${SCENES[@]}"; do
    IFS='|' read -r name tags buf dur fmt desc <<< "${scene}"
    if [ "$name" = "$target" ]; then
      echo "${name}|${tags}|${buf}|${dur}|${fmt}|${desc}"
      return 0
    fi
  done
  return 1
}

# 交互式菜单
interactive_menu() {
  print_header

  # 检测 hdc
  local HDC
  HDC=$(detect_hdc) || {
    echo -e "${RED}❌ 未找到 hdc,请确保 DevEco Studio 已安装${NC}"
    exit 1
  }
  echo -e "${DIM}hdc 路径: ${HDC}${NC}"

  # 检查设备
  if ! check_device "$HDC"; then
    exit 1
  fi

  echo ""
  echo -e "${BOLD}请选择场景分类:${NC}"
  echo ""
  echo "  1  📱 应用性能 (冷启动/页面/触控/动画/内存/IPC/综合)"
  echo "  2  🖥️ 系统性能 (CPU/中断/磁盘/电源/内核/内存总线)"
  echo "  3  🌐 网络与通信 (网络/蓝牙/分布式)"
  echo "  4  🎬 多媒体 (音频/视频/图形渲染)"
  echo "  5  🔧 系统服务 (通知/传感器/输入/安全/文件)"
  echo "  6  📸 快照模式 (按需dump)"
  echo "  7  📼 录制模式 (长时间采集)"
  echo "  8  📋 列出所有场景 (供参考)"
  echo "  0  ❌ 退出"
  echo ""

  read -r -p "  请输入 [0-8]: " choice

  case "$choice" in
    1) menu_app_perf "$HDC" ;;
    2) menu_sys_perf "$HDC" ;;
    3) menu_network "$HDC" ;;
    4) menu_media "$HDC" ;;
    5) menu_services "$HDC" ;;
    6) menu_snapshot "$HDC" ;;
    7) menu_record "$HDC" ;;
    8) list_scenes_interactive ;;
    0) echo -e "\n${GREEN}👋 再见${NC}"; exit 0 ;;
    *) echo -e "${RED}无效选择${NC}"; sleep 1; interactive_menu ;;
  esac
}

menu_app_perf() {
  local HDC="$1"
  print_header
  echo -e "${BOLD}📱 应用性能场景:${NC}"
  echo ""
  for i in {0..7}; do
    IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$i]}"
    printf "  %d  %-25s %s\n" "$((i+1))" "${name}" "${DIM}${desc}${NC}"
  done
  echo "  0  🔙 返回"
  echo ""
  read -r -p "  请输入 [0-8]: " choice

  case "$choice" in
    [1-8])
      IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$((choice-1))]}"
      print_scene_info "$name" "$tags" "$buf" "$dur" "$fmt" "$desc"
      execute_trace "$HDC" "$name" "$tags" "$buf" "$dur" "$fmt"
      ;;
    0) interactive_menu ;;
    *) menu_app_perf "$HDC" ;;
  esac
}

menu_sys_perf() {
  local HDC="$1"
  local offset=8
  print_header
  echo -e "${BOLD}🖥️ 系统性能场景:${NC}"
  echo ""
  for i in {0..5}; do
    local idx=$((offset + i))
    IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
    printf "  %d  %-25s %s\n" "$((i+1))" "${name}" "${DIM}${desc}${NC}"
  done
  echo "  0  🔙 返回"
  echo ""
  read -r -p "  请输入 [0-6]: " choice

  case "$choice" in
    [1-6])
      local idx=$((offset + choice - 1))
      IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
      print_scene_info "$name" "$tags" "$buf" "$dur" "$fmt" "$desc"
      execute_trace "$HDC" "$name" "$tags" "$buf" "$dur" "$fmt"
      ;;
    0) interactive_menu ;;
    *) menu_sys_perf "$HDC" ;;
  esac
}

menu_network() {
  local HDC="$1"
  local offset=14
  print_header
  echo -e "${BOLD}🌐 网络与通信场景:${NC}"
  echo ""
  for i in {0..2}; do
    local idx=$((offset + i))
    IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
    printf "  %d  %-25s %s\n" "$((i+1))" "${name}" "${DIM}${desc}${NC}"
  done
  echo "  0  🔙 返回"
  echo ""
  read -r -p "  请输入 [0-3]: " choice

  case "$choice" in
    [1-3])
      local idx=$((offset + choice - 1))
      IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
      print_scene_info "$name" "$tags" "$buf" "$dur" "$fmt" "$desc"
      execute_trace "$HDC" "$name" "$tags" "$buf" "$dur" "$fmt"
      ;;
    0) interactive_menu ;;
    *) menu_network "$HDC" ;;
  esac
}

menu_media() {
  local HDC="$1"
  local offset=17
  print_header
  echo -e "${BOLD}🎬 多媒体场景:${NC}"
  echo ""
  for i in {0..2}; do
    local idx=$((offset + i))
    IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
    printf "  %d  %-25s %s\n" "$((i+1))" "${name}" "${DIM}${desc}${NC}"
  done
  echo "  0  🔙 返回"
  echo ""
  read -r -p "  请输入 [0-3]: " choice

  case "$choice" in
    [1-3])
      local idx=$((offset + choice - 1))
      IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
      print_scene_info "$name" "$tags" "$buf" "$dur" "$fmt" "$desc"
      execute_trace "$HDC" "$name" "$tags" "$buf" "$dur" "$fmt"
      ;;
    0) interactive_menu ;;
    *) menu_media "$HDC" ;;
  esac
}

menu_services() {
  local HDC="$1"
  local offset=20
  print_header
  echo -e "${BOLD}🔧 系统服务场景:${NC}"
  echo ""
  for i in {0..4}; do
    local idx=$((offset + i))
    IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
    printf "  %d  %-25s %s\n" "$((i+1))" "${name}" "${DIM}${desc}${NC}"
  done
  echo "  0  🔙 返回"
  echo ""
  read -r -p "  请输入 [0-5]: " choice

  case "$choice" in
    [1-5])
      local idx=$((offset + choice - 1))
      IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
      print_scene_info "$name" "$tags" "$buf" "$dur" "$fmt" "$desc"
      execute_trace "$HDC" "$name" "$tags" "$buf" "$dur" "$fmt"
      ;;
    0) interactive_menu ;;
    *) menu_services "$HDC" ;;
  esac
}

menu_snapshot() {
  local HDC="$1"
  local offset=25
  print_header
  echo -e "${BOLD}📸 快照模式:${NC}"
  echo ""
  for i in {0..1}; do
    local idx=$((offset + i))
    IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
    printf "  %d  %-35s %s\n" "$((i+1))" "${name}" "${DIM}${desc}${NC}"
  done
  echo "  0  🔙 返回"
  echo ""
  read -r -p "  请输入 [0-2]: " choice

  case "$choice" in
    [1-2])
      local idx=$((offset + choice - 1))
      IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
      print_scene_info "$name" "$tags" "$buf" "$dur" "$fmt" "$desc"
      execute_trace "$HDC" "$name" "$tags" "$buf" "$dur" "$fmt"
      ;;
    0) interactive_menu ;;
    *) menu_snapshot "$HDC" ;;
  esac
}

menu_record() {
  local HDC="$1"
  local offset=27
  print_header
  echo -e "${BOLD}📼 录制模式:${NC}"
  echo ""
  local idx=$offset
  IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$idx]}"
  printf "  1  %-35s %s\n" "${name}" "${DIM}${desc}${NC}"
  echo "  0  🔙 返回"
  echo ""
  read -r -p "  请输入 [0-1]: " choice

  case "$choice" in
    1)
      IFS='|' read -r name tags buf dur fmt desc <<< "${SCENES[$offset]}"
      print_scene_info "$name" "$tags" "$buf" "$dur" "$fmt" "$desc"
      execute_trace "$HDC" "$name" "$tags" "$buf" "$dur" "$fmt"
      ;;
    0) interactive_menu ;;
    *) menu_record "$HDC" ;;
  esac
}

list_scenes_interactive() {
  echo ""
  echo -e "${CYAN}${BOLD}═══════════ 所有场景列表 ═══════════${NC}"
  echo ""
  local idx=1
  for scene in "${SCENES[@]}"; do
    IFS='|' read -r name tags buf dur fmt desc <<< "${scene}"
    local type="定时采集"
    local cmd
    if [[ "$tags" == "--snapshot-text" ]] || [[ "$tags" == "--snapshot-raw" ]]; then
      type="快照模式"
      cmd="(交互式)"
    elif [[ "$tags" == "--record" ]]; then
      type="录制模式"
      cmd="(交互式)"
    else
      cmd="hitrace -t ${dur} -b ${buf} ${tags} -o /data/local/tmp/<name>.ftrace"
    fi
    printf "  ${GREEN}%2d${NC}  ${BOLD}%-28s${NC} ${YELLOW}[%s]${NC}\n" "$idx" "$name" "$type"
    echo -e "      ${DIM}${desc}${NC}"
    echo -e "      ${DIM}${cmd}${NC}"
    echo ""
    idx=$((idx + 1))
  done
  read -r -p "按 Enter 返回..."
  interactive_menu
}

# ============================================================
# 入口
# ============================================================

case "${1:-}" in
  --json)
    # 输出场景定义 JSON (供 Agent/工具程序化使用)
    # 分类索引: start_index count category_name
    declare -a JSON_CATEGORIES=("0 8 应用性能" "8 6 系统性能" "14 3 网络与通信" "17 3 多媒体" "20 5 系统服务" "25 2 快照模式" "27 1 录制模式")

    # 辅助函数: 获取某 index 的分类名
    get_category() {
      local idx="$1"
      local cat_start cat_count cat_name
      for entry in "${JSON_CATEGORIES[@]}"; do
        read -r cat_start cat_count cat_name <<< "$entry"
        if [ "$idx" -ge "$cat_start" ] && [ "$idx" -lt $((cat_start + cat_count)) ]; then
          echo "$cat_name"
          return
        fi
      done
      echo "其他"
    }

    echo '['
    first=true
    json_idx=0
    for scene in "${SCENES[@]}"; do
      IFS='|' read -r name tags buf dur fmt desc <<< "${scene}"
      json_cat=$(get_category $json_idx)
      $first || echo ','
      first=false
      json_cmd=""
      json_tags="$tags"
      if [[ "$tags" == "--snapshot-text" ]]; then
        json_cmd="hitrace --trace_begin -b ${buf} <tags>; hitrace --trace_dump -o /data/local/tmp/<name>.ftrace; hitrace --trace_finish_nodump"
        json_tags="app ace graphic window sched freq disk"
      elif [[ "$tags" == "--snapshot-raw" ]]; then
        json_cmd="hitrace --start_bgsrv; hitrace --dump_bgsrv; hitrace --stop_bgsrv"
        json_tags="(系统默认34个tag)"
      elif [[ "$tags" == "--record" ]]; then
        json_cmd="hitrace --trace_begin --record -b ${buf} --file_size 102400 <tags>; hitrace --trace_finish --record"
        json_tags="app ace graphic sched freq"
      else
        json_cmd="hitrace -t ${dur} -b ${buf} ${tags} -o /data/local/tmp/<name>.ftrace"
      fi
      echo -n "  {\"index\":${json_idx},\"category\":\"${json_cat}\",\"name\":\"${name}\",\"tags\":\"${json_tags}\",\"bufferKB\":${buf},\"durationS\":${dur},\"format\":\"${fmt}\",\"description\":\"${desc}\",\"command\":\"${json_cmd}\"}"
      json_idx=$((json_idx + 1))
    done
    echo ''
    echo ']'
    ;;
  --list)
    list_all_scenes
    ;;
  *)
    interactive_menu
    ;;
esac
