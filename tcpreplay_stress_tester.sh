#!/bin/bash

# 脚本名称：tcpreplay_stress_tester.sh
# 脚本功能：提供多种加压模式，使用 Tcpreplay 对网络进行压力测试，并解析输出结果。
# 作者：Bard

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：显示脚本使用方法
show_usage() {
  echo "使用方法: $0 -i <interface> -f <pcap_file> [-m <mode>]"
  echo "选项:"
  echo "  -i <interface>   指定网络接口 (必填)"
  echo "  -f <pcap_file>   指定 PCAP 文件 (必填)"
  echo "  -m <mode>        选择加压模式 (可选，默认为 1):"
  echo "    1: 固定速率 (Mbps)"
  echo "    2: 固定速率 (pps)"
  echo "    3: 倍速回放"
  echo "    4: 最大速率"
  echo "    5: 指定循环次数"
  echo "    6: 指定发送数据包数量"
  echo "  -h               显示帮助信息"
}

# 函数：检查 Tcpreplay 是否已安装
check_tcpreplay() {
  if ! command -v tcpreplay &> /dev/null; then
    echo -e "${RED}错误: Tcpreplay 未安装。请先安装 Tcpreplay。${NC}"
    exit 1
  fi
}

# 函数：解析 Tcpreplay 的输出
parse_tcpreplay_output() {
  # 官方输出示例：
  # Actual: 4478944 packets (6718416000 bytes) sent in 60.03 seconds
  # Rated: 111920000.0 Bps, 895.36 Mbps, 149223.28 pps
  # Flows: 149 flows, 2.48 fps, 4478804 flow packets, 140 non-flow packets
  # Statistics for network device: eth0
  #     Successful packets:        4478944
  #     Failed packets:              0
  #     Truncated packets:           0
  #     Retried packets:             0
  #     Retries:                     0

  # 使用 awk 提取关键信息
  actual_packets=$(echo "$output" | awk '/Actual:/ {print $2}')
  actual_bytes=$(echo "$output" | awk '/Actual:/ {print $4}')
  actual_time=$(echo "$output" | awk '/Actual:/ {print $8}')
  rated_bps=$(echo "$output" | awk '/Rated:/ {print $2}')
  rated_mbps=$(echo "$output" | awk '/Rated:/ {print $4}')
  rated_pps=$(echo "$output" | awk '/Rated:/ {print $6}')
  flows=$(echo "$output" | awk '/Flows:/ {print $2}')
  fps=$(echo "$output" | awk '/Flows:/ {print $6}')

  # 将字节数转换为更易读的单位
  actual_bytes_human=$(numfmt --to=iec --suffix=B $actual_bytes)
  rated_bps_human=$(numfmt --to=iec --suffix=B/s $rated_bps)

  # 输出解析后的结果
  echo -e "${BLUE}-------------------- Tcpreplay 测试结果 --------------------${NC}"
  echo -e "${GREEN}发送数据包:${NC} ${actual_packets} 个"
  echo -e "${GREEN}发送数据量:${NC} ${actual_bytes_human} (${actual_bytes} 字节)"
  echo -e "${GREEN}发送时长:${NC} ${actual_time} 秒"
  echo -e "${GREEN}标称速率:${NC} ${rated_bps_human}, ${rated_mbps}, ${rated_pps}"
  echo -e "${GREEN}流数量:${NC} ${flows} 个"
  echo -e "${GREEN}流速率:${NC} ${fps} fps"
  echo -e "${BLUE}-----------------------------------------------------------${NC}"
  echo ""

  # 输出指标说明
  echo -e "${YELLOW}指标说明:${NC}"
  echo "  * ${GREEN}发送数据包:${NC} 实际发送的数据包数量。"
  echo "  * ${GREEN}发送数据量:${NC} 实际发送的数据总量，以易读的单位 (如 GB) 显示。"
  echo "  * ${GREEN}发送时长:${NC} 发送数据包所花费的时间。"
  echo "  * ${GREEN}标称速率:${NC} Tcpreplay 报告的发送速率，包括每秒字节数 (Bps)、每秒兆比特数 (Mbps) 和每秒数据包数 (pps)。"
  echo "  * ${GREEN}流数量:${NC}  pcap文件里被识别出来的不同网络流的数量。通常, 一个流由一个五元组定义(源IP, 目标IP, 源端口, 目标端口, 协议) "
  echo "  * ${GREEN}流速率:${NC} 每秒认出的网络流的数量."
  echo ""
}

# 检查 Tcpreplay 是否已安装
check_tcpreplay

# 初始化变量
interface=""
pcap_file=""
mode=1
rate_mbps=100 # 默认速率 (Mbps)
rate_pps=1000  # 默认速率 (pps)
multiplier=2    # 默认倍数
loop_count=1    # 默认循环次数
packet_count=1000 # 默认发包数量

# 解析命令行参数
while getopts "i:f:m:r:p:x:l:c:h" opt; do
  case $opt in
    i)
      interface="$OPTARG"
      ;;
    f)
      pcap_file="$OPTARG"
      ;;
    m)
      mode="$OPTARG"
      ;;
    r)
      rate_mbps="$OPTARG"
      ;;
    p)
      rate_pps="$OPTARG"
      ;;
    x)
      multiplier="$OPTARG"
    ;;
    l)
        loop_count="$OPTARG"
        ;;
    c)
        packet_count="$OPTARG"
        ;;
    h)
      show_usage
      exit 0
      ;;
    \?)
      echo -e "${RED}无效的选项: -$OPTARG${NC}" >&2
      show_usage
      exit 1
      ;;
    :)
      echo -e "${RED}选项 -$OPTARG 需要一个参数。${NC}" >&2
      show_usage
      exit 1
      ;;
  esac
done

# 检查必填参数
if [ -z "$interface" ] || [ -z "$pcap_file" ]; then
  echo -e "${RED}错误: 缺少必要的参数。${NC}"
  show_usage
  exit 1
fi

# 提示用户选择加压模式（如果未指定）
if [ -z "$mode" ]; then
  echo "请选择加压模式:"
  echo "  1: 固定速率 (Mbps)"
  echo "  2: 固定速率 (pps)"
  echo "  3: 倍速回放"
  echo "  4: 最大速率"
  echo "  5: 指定循环次数"
  echo "  6: 指定发送数据包数量"
  read -p "请输入模式编号 (1-6): " mode
fi

# 构建 Tcpreplay 命令
tcpreplay_cmd="tcpreplay -i $interface $pcap_file"

case $mode in
  1)
    read -p "请输入速率 (Mbps, 默认 100): " input_rate_mbps
    rate_mbps=${input_rate_mbps:-$rate_mbps} # 如果用户直接回车，使用默认值
    tcpreplay_cmd+=" --mbps=$rate_mbps"
    echo -e "${GREEN}您选择了：固定速率 (Mbps) 模式，速率为 ${rate_mbps} Mbps${NC}"
    ;;
  2)
    read -p "请输入速率 (pps, 默认 1000): " input_rate_pps
    rate_pps=${input_rate_pps:-$rate_pps}
    tcpreplay_cmd+=" --pps=$rate_pps"
    echo -e "${GREEN}您选择了：固定速率 (pps) 模式，速率为 ${rate_pps} pps${NC}"
    ;;
  3)
    read -p "请输入倍数 (默认 2): " input_multiplier
    multiplier=${input_multiplier:-$multiplier}
    tcpreplay_cmd+=" --multiplier=$multiplier"
    echo -e "${GREEN}您选择了：倍速回放模式，倍数为 ${multiplier}${NC}"
    ;;
  4)
    tcpreplay_cmd+=" -t"
    echo -e "${GREEN}您选择了：最大速率模式${NC}"
    ;;
  5)
    read -p "请输入循环次数 (默认 1): " input_loop_count
    loop_count=${input_loop_count:-$loop_count}
    tcpreplay_cmd+=" -l $loop_count"
    echo -e "${GREEN}您选择了：指定循环次数模式, 循环 ${loop_count} 次${NC}"
    ;;
  6)
    read -p "请输入要发送的数据包数量 (默认 1000): " input_packet_count
    packet_count=${input_packet_count:-$packet_count}
    tcpreplay_cmd+=" -c $packet_count"
    echo -e "${GREEN}您选择了：指定发送数据包数量模式, 发送 ${packet_count} 个包${NC}"
    ;;
  *)
    echo -e "${RED}错误: 无效的模式编号。${NC}"
    exit 1
    ;;
esac

# 执行 Tcpreplay 命令并将输出保存到变量
echo -e "${BLUE}正在执行 Tcpreplay 命令...${NC}"
output=$(eval "$tcpreplay_cmd" 2>&1) #捕获标准输出和标准错误

# 检查 Tcpreplay 是否成功执行
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Tcpreplay 执行成功。${NC}"
  # 解析 Tcpreplay 的输出
  parse_tcpreplay_output "$output"
else
  echo -e "${RED}Tcpreplay 执行失败。${NC}"
  echo "$output"
fi
