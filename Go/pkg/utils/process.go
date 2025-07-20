package utils

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// ProcessInfo 进程信息结构
type ProcessInfo struct {
	PID         int       `json:"pid"`
	PPID        int       `json:"ppid"`
	Command     string    `json:"command"`
	Args        []string  `json:"args"`
	StartTime   time.Time `json:"start_time"`
	User        string    `json:"user"`
	WorkingDir  string    `json:"working_dir"`
	Status      string    `json:"status"`
	CPUTime     int64     `json:"cpu_time"`     // CPU时间（jiffies）
	MemoryUsage int64     `json:"memory_usage"` // 内存使用（KB）
}

// MonitoredProcess 被监控的进程
type MonitoredProcess struct {
	Info        ProcessInfo `json:"info"`
	StartTime   time.Time   `json:"start_time"`
	IsContainer bool        `json:"is_container"`
	ContainerID string      `json:"container_id,omitempty"`
	Status      string      `json:"status"` // "running", "completed", "failed"
	ExitCode    *int        `json:"exit_code,omitempty"`
	Duration    time.Duration `json:"duration"`
	CPUUsage    float64     `json:"cpu_usage"`
	MemoryUsage int64       `json:"memory_usage"`
	LastSeen    time.Time   `json:"last_seen"`
}

// ContainerProcess Docker容器进程
type ContainerProcess struct {
	ContainerID   string      `json:"container_id"`
	ContainerName string      `json:"container_name"`
	ProcessInfo   ProcessInfo `json:"process_info"`
}

// GetProcessStartTime 从/proc/PID/stat获取进程启动时间
func GetProcessStartTime(pid int) (time.Time, error) {
	statPath := fmt.Sprintf("/proc/%d/stat", pid)
	data, err := os.ReadFile(statPath)
	if err != nil {
		return time.Time{}, err
	}

	fields := strings.Fields(string(data))
	if len(fields) < 22 {
		return time.Time{}, fmt.Errorf("invalid stat format for PID %d", pid)
	}

	// 第22个字段是starttime（以jiffies为单位）
	startTimeJiffies, err := strconv.ParseInt(fields[21], 10, 64)
	if err != nil {
		return time.Time{}, err
	}

	// 获取系统启动时间
	bootTime, err := getSystemBootTime()
	if err != nil {
		return time.Time{}, err
	}

	// 获取时钟频率
	clockTicks := getClockTicks()

	// 计算进程启动时间
	startTime := bootTime.Add(time.Duration(startTimeJiffies/clockTicks) * time.Second)
	return startTime, nil
}

// GetProcessCmdline 从/proc/PID/cmdline获取命令行
func GetProcessCmdline(pid int) (string, []string, error) {
	cmdlinePath := fmt.Sprintf("/proc/%d/cmdline", pid)
	data, err := os.ReadFile(cmdlinePath)
	if err != nil {
		return "", nil, err
	}

	// cmdline以null字符分隔
	cmdline := string(data)
	if len(cmdline) == 0 {
		return "", nil, fmt.Errorf("empty cmdline for PID %d", pid)
	}

	// 移除末尾的null字符并分割
	cmdline = strings.TrimRight(cmdline, "\x00")
	parts := strings.Split(cmdline, "\x00")
	
	if len(parts) == 0 {
		return "", nil, fmt.Errorf("no command found for PID %d", pid)
	}

	command := parts[0]
	args := parts[1:]
	
	return command, args, nil
}

// GetProcessStatus 从/proc/PID/status获取进程状态信息
func GetProcessStatus(pid int) (string, string, error) {
	statusPath := fmt.Sprintf("/proc/%d/status", pid)
	data, err := os.ReadFile(statusPath)
	if err != nil {
		return "", "", err
	}

	lines := strings.Split(string(data), "\n")
	var status, user string

	for _, line := range lines {
		if strings.HasPrefix(line, "State:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				status = parts[1]
			}
		} else if strings.HasPrefix(line, "Uid:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				uid, err := strconv.Atoi(parts[1])
				if err == nil {
					user = getUserName(uid)
				}
			}
		}
	}

	return status, user, nil
}

// GetProcessMemoryUsage 从/proc/PID/status获取内存使用情况
func GetProcessMemoryUsage(pid int) (int64, error) {
	statusPath := fmt.Sprintf("/proc/%d/status", pid)
	data, err := os.ReadFile(statusPath)
	if err != nil {
		return 0, err
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "VmRSS:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				memory, err := strconv.ParseInt(parts[1], 10, 64)
				if err == nil {
					return memory, nil // 返回KB
				}
			}
		}
	}

	return 0, fmt.Errorf("VmRSS not found for PID %d", pid)
}

// GetProcessCPUTime 从/proc/PID/stat获取CPU时间
func GetProcessCPUTime(pid int) (int64, error) {
	statPath := fmt.Sprintf("/proc/%d/stat", pid)
	data, err := os.ReadFile(statPath)
	if err != nil {
		return 0, err
	}

	fields := strings.Fields(string(data))
	if len(fields) < 15 {
		return 0, fmt.Errorf("invalid stat format for PID %d", pid)
	}

	// utime (第14个字段) + stime (第15个字段)
	utime, err := strconv.ParseInt(fields[13], 10, 64)
	if err != nil {
		return 0, err
	}

	stime, err := strconv.ParseInt(fields[14], 10, 64)
	if err != nil {
		return 0, err
	}

	return utime + stime, nil
}

// IsProcessRunning 检查进程是否还在运行
func IsProcessRunning(pid int) bool {
	_, err := os.Stat(fmt.Sprintf("/proc/%d", pid))
	return err == nil
}

// FormatBytes 格式化字节数为人类可读格式
func FormatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

// FormatDuration 格式化时间间隔为人类可读格式
func FormatDuration(d time.Duration) string {
	if d < time.Minute {
		return fmt.Sprintf("%.0f秒", d.Seconds())
	} else if d < time.Hour {
		return fmt.Sprintf("%.0f分钟", d.Minutes())
	} else if d < 24*time.Hour {
		hours := int(d.Hours())
		minutes := int(d.Minutes()) % 60
		return fmt.Sprintf("%d小时%d分钟", hours, minutes)
	} else {
		days := int(d.Hours()) / 24
		hours := int(d.Hours()) % 24
		return fmt.Sprintf("%d天%d小时", days, hours)
	}
}

// 辅助函数

// getSystemBootTime 获取系统启动时间
func getSystemBootTime() (time.Time, error) {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return time.Time{}, err
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "btime ") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				bootTime, err := strconv.ParseInt(parts[1], 10, 64)
				if err == nil {
					return time.Unix(bootTime, 0), nil
				}
			}
		}
	}

	return time.Time{}, fmt.Errorf("boot time not found in /proc/stat")
}

// getClockTicks 获取系统时钟频率
func getClockTicks() int64 {
	// 大多数Linux系统的时钟频率是100Hz
	return 100
}

// getUserName 根据UID获取用户名（简化版本）
func getUserName(uid int) string {
	// 这里可以通过读取/etc/passwd或使用user包来获取用户名
	// 为了简化，直接返回UID字符串
	return strconv.Itoa(uid)
}
