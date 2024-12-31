shell-work
==========

shell常用分析命令和脚本
  
##mysql监控脚本

##cookielog分析脚本

##线上java进程信息dump和机器信息dump脚本

##cpu监控相关

##dish 磁盘管理
 
运行脚本： ./tcpreplay_stress_tester.sh -i <interface> -f <pcap_file> [-m <mode>]

-i <interface>：指定网络接口，例如 eth0。

-f <pcap_file>：指定 PCAP 文件，例如 sample.pcap。

-m <mode>：可选参数，选择加压模式，可以是以下值：

1：固定速率 (Mbps)

2：固定速率 (pps)

3：倍速回放

4：最大速率

5: 指定循环次数

6: 指定数据包数量

-r <rate_mbps>: 当选择模式1时, 可以用这个参数指定速率

-p <rate_pps>: 当选择模式2时, 可以用这个参数指定速率

-x <multiplier>: 当选择模式3时, 可以用这个参数指定倍数

-l <loop_count>: 当选择模式5时, 可以用这个参数指定循环次数

-c <packet_count>: 当选择模式6时, 可以用这个参数指定数据包数量

示例：

使用 eth0 网卡，以 100 Mbps 的固定速率发送 sample.pcap 文件中的数据包：
./tcpreplay_stress_tester.sh -i eth0 -f sample.pcap -m 1 -r 100

使用 eth0 网卡，以最大速率发送 sample.pcap 文件中的数据包：
./tcpreplay_stress_tester.sh -i eth0 -f sample.pcap -m 4

使用 eth0 网卡，以 2 倍速率发送 sample.pcap 文件中的数据包：
./tcpreplay_stress_tester.sh -i eth0 -f sample.pcap -m 3 -x 2

使用 eth0 网卡，循环播放 sample.pcap 文件中的数据包 10 次：
./tcpreplay_stress_tester.sh -i eth0 -f sample.pcap -m 5 -l 10
