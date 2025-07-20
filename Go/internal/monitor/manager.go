package monitor

import (
	"cmdmonitor/pkg/utils"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
)

// MonitorManager 监控管理器
type MonitorManager struct {
	logger         *logrus.Logger
	processScanner *ProcessScanner
	processes      map[int]*utils.MonitoredProcess
	mutex          sync.RWMutex
	scanInterval   time.Duration
	maxProcesses   int

	// 回调函数
	onProcessCompleted func(*utils.MonitoredProcess)

	// 控制通道
	stopChan chan struct{}
	doneChan chan struct{}
}

// NewMonitorManager 创建新的监控管理器
func NewMonitorManager(
	logger *logrus.Logger,
	processScanner *ProcessScanner,
	scanIntervalSeconds int,
	maxProcesses int,
) *MonitorManager {
	return &MonitorManager{
		logger:         logger,
		processScanner: processScanner,
		processes:      make(map[int]*utils.MonitoredProcess),
		scanInterval:   time.Duration(scanIntervalSeconds) * time.Second,
		maxProcesses:   maxProcesses,
		stopChan:       make(chan struct{}),
		doneChan:       make(chan struct{}),
	}
}

// SetProcessCompletedCallback 设置进程完成回调
func (mm *MonitorManager) SetProcessCompletedCallback(callback func(*utils.MonitoredProcess)) {
	mm.onProcessCompleted = callback
}

// Start 启动监控管理器
func (mm *MonitorManager) Start(ctx context.Context) error {
	mm.logger.Info("启动监控管理器...")

	go mm.monitorLoop(ctx)

	mm.logger.Info("监控管理器已启动")
	return nil
}

// Stop 停止监控管理器
func (mm *MonitorManager) Stop() {
	mm.logger.Info("停止监控管理器...")
	close(mm.stopChan)
	<-mm.doneChan
	mm.logger.Info("监控管理器已停止")
}

// monitorLoop 主监控循环
func (mm *MonitorManager) monitorLoop(ctx context.Context) {
	defer close(mm.doneChan)

	ticker := time.NewTicker(mm.scanInterval)
	defer ticker.Stop()

	// 立即执行一次扫描
	mm.scanAndUpdate()

	for {
		select {
		case <-ctx.Done():
			mm.logger.Info("收到上下文取消信号，停止监控")
			return
		case <-mm.stopChan:
			mm.logger.Info("收到停止信号，停止监控")
			return
		case <-ticker.C:
			mm.scanAndUpdate()
		}
	}
}

// scanAndUpdate 扫描并更新进程状态
func (mm *MonitorManager) scanAndUpdate() {
	mm.logger.Debug("开始扫描和更新进程状态...")

	// 1. 检查现有监控进程的状态
	mm.checkExistingProcesses()

	// 2. 扫描新的长时间运行进程
	mm.scanNewProcesses()

	// 3. 清理已完成的进程
	mm.cleanupCompletedProcesses()

	mm.mutex.RLock()
	activeCount := len(mm.processes)
	mm.mutex.RUnlock()

	mm.logger.Debugf("当前监控 %d 个进程", activeCount)
}

// checkExistingProcesses 检查现有监控进程的状态
func (mm *MonitorManager) checkExistingProcesses() {
	mm.mutex.Lock()
	defer mm.mutex.Unlock()

	for pid, monitoredProc := range mm.processes {
		if monitoredProc.Status != "running" {
			continue
		}

		// 检查进程是否还在运行（区分容器内外进程）
		isRunning := false
		if monitoredProc.IsContainer {
			// 容器内进程，使用docker exec检查
			isRunning = mm.isContainerProcessRunning(monitoredProc.ContainerID, pid)
		} else {
			// 主机进程，使用标准方法检查
			isRunning = utils.IsProcessRunning(pid)
		}

		if !isRunning {
			mm.logger.Infof("进程 %d (%s) 已结束", pid, monitoredProc.Info.Command)

			// 更新进程状态
			monitoredProc.Status = "completed"
			monitoredProc.Duration = time.Since(monitoredProc.StartTime)

			// 尝试获取退出码（在某些情况下可能无法获取）
			exitCode := 0 // 默认成功
			monitoredProc.ExitCode = &exitCode

			// 触发完成回调
			if mm.onProcessCompleted != nil {
				go mm.onProcessCompleted(monitoredProc)
			}
		} else {
			// 更新进程信息
			mm.updateProcessInfo(monitoredProc)
		}
	}
}

// updateProcessInfo 更新进程信息
func (mm *MonitorManager) updateProcessInfo(monitoredProc *utils.MonitoredProcess) {
	// 刷新进程信息
	if refreshedInfo, err := mm.processScanner.RefreshProcessInfo(monitoredProc.Info.PID); err == nil {
		// 更新内存和CPU使用情况
		monitoredProc.Info.MemoryUsage = refreshedInfo.MemoryUsage
		monitoredProc.Info.CPUTime = refreshedInfo.CPUTime
		monitoredProc.MemoryUsage = refreshedInfo.MemoryUsage

		// 计算CPU使用率（简化版本）
		monitoredProc.CPUUsage = mm.calculateCPUUsage(refreshedInfo.CPUTime, monitoredProc.StartTime)

		monitoredProc.LastSeen = time.Now()
	}
}

// calculateCPUUsage 计算CPU使用率
func (mm *MonitorManager) calculateCPUUsage(cpuTime int64, startTime time.Time) float64 {
	// 简化的CPU使用率计算
	// 实际实现可能需要更复杂的逻辑
	runningTime := time.Since(startTime).Seconds()
	if runningTime == 0 {
		return 0
	}

	// 假设时钟频率为100Hz
	cpuSeconds := float64(cpuTime) / 100.0
	return (cpuSeconds / runningTime) * 100.0
}

// scanNewProcesses 扫描新的长时间运行进程
func (mm *MonitorManager) scanNewProcesses() {
	// 检查是否已达到最大监控数量
	mm.mutex.RLock()
	currentCount := len(mm.processes)
	mm.mutex.RUnlock()

	if currentCount >= mm.maxProcesses {
		mm.logger.Debugf("已达到最大监控进程数 (%d)，跳过新进程扫描", mm.maxProcesses)
		return
	}

	// 扫描主机进程
	hostProcesses, err := mm.processScanner.ScanProcesses()
	if err != nil {
		mm.logger.Errorf("扫描主机进程失败: %v", err)
	} else {
		newCount := mm.addNewProcesses(hostProcesses, false, "")
		mm.logScanResults("主机", "", len(hostProcesses), newCount)
	}

	// 扫描Docker容器进程
	mm.scanDockerContainerProcesses()
}

// scanDockerContainerProcesses 扫描Docker容器内的进程
func (mm *MonitorManager) scanDockerContainerProcesses() {
	// 获取运行中的容器列表
	containers, err := mm.getRunningContainers()
	if err != nil {
		mm.logger.Errorf("获取运行中的容器失败: %v", err)
		return
	}

	for _, containerID := range containers {
		// 检查是否已达到最大监控数量
		mm.mutex.RLock()
		currentCount := len(mm.processes)
		mm.mutex.RUnlock()

		if currentCount >= mm.maxProcesses {
			mm.logger.Debugf("已达到最大监控进程数 (%d)，停止扫描容器", mm.maxProcesses)
			break
		}

		// 扫描容器内进程
		containerProcesses, err := mm.processScanner.ScanDockerContainerProcesses(containerID)
		if err != nil {
			mm.logger.Errorf("扫描容器 %s 进程失败: %v", containerID, err)
			continue
		}

		// 添加容器进程到监控列表
		newCount := mm.addNewProcesses(containerProcesses, true, containerID)
		mm.logScanResults("容器", containerID, len(containerProcesses), newCount)
	}
}

// addNewProcesses 添加新发现的进程到监控列表
func (mm *MonitorManager) addNewProcesses(processes []utils.ProcessInfo, isContainer bool, containerID string) int {
	mm.mutex.Lock()
	defer mm.mutex.Unlock()

	newCount := 0
	for _, procInfo := range processes {
		// 检查是否已经在监控中
		if existingProc, exists := mm.processes[procInfo.PID]; exists {
			// 如果进程仍在运行，跳过（避免重复监控）
			if existingProc.Status == "running" {
				mm.logger.Debugf("进程 PID=%d 已在监控中，跳过", procInfo.PID)
				continue
			}

			// 如果进程已完成但PID被重用，需要特别处理
			if existingProc.Status == "completed" {
				// 检查启动时间是否不同，如果不同说明是新进程
				if !existingProc.StartTime.Equal(procInfo.StartTime) {
					mm.logger.Debugf("PID %d 被重用，移除旧记录", procInfo.PID)
					delete(mm.processes, procInfo.PID)
				} else {
					// 同一个进程，跳过
					mm.logger.Debugf("进程 PID=%d 已完成，跳过重复添加", procInfo.PID)
					continue
				}
			}
		}

		// 检查是否已达到最大监控数量
		if len(mm.processes) >= mm.maxProcesses {
			mm.logger.Warnf("已达到最大监控进程数 (%d)，停止添加新进程", mm.maxProcesses)
			break
		}

		// 创建监控进程
		monitoredProc := &utils.MonitoredProcess{
			Info:        procInfo,
			StartTime:   procInfo.StartTime,
			IsContainer: isContainer,
			ContainerID: containerID,
			Status:      "running",
			Duration:    time.Since(procInfo.StartTime),
			CPUUsage:    mm.calculateCPUUsage(procInfo.CPUTime, procInfo.StartTime),
			MemoryUsage: procInfo.MemoryUsage,
			LastSeen:    time.Now(),
		}

		mm.processes[procInfo.PID] = monitoredProc
		newCount++

		mm.logger.Infof("开始监控进程: %s (PID=%d, 运行时间=%s)",
			procInfo.Command, procInfo.PID, utils.FormatDuration(time.Since(procInfo.StartTime)))
	}

	return newCount
}

// logScanResults 记录扫描结果日志
func (mm *MonitorManager) logScanResults(scanType, containerID string, foundCount, newCount int) {
	mm.mutex.RLock()
	totalMonitored := len(mm.processes)
	runningCount := 0

	// 统计当前运行中的进程
	for _, proc := range mm.processes {
		if proc.Status == "running" {
			runningCount++
		}
	}
	mm.mutex.RUnlock()

	// 构建日志消息
	var logMsg string
	if containerID != "" {
		logMsg = fmt.Sprintf("%s %s 扫描完成", scanType, containerID)
	} else {
		logMsg = fmt.Sprintf("%s扫描完成", scanType)
	}

	if foundCount > 0 {
		logMsg += fmt.Sprintf("，发现 %d 个符合条件的进程", foundCount)
	} else {
		logMsg += "，未发现符合条件的进程"
	}

	if newCount > 0 {
		logMsg += fmt.Sprintf("，新增监控 %d 个", newCount)
	}

	logMsg += fmt.Sprintf("。当前监控总数: %d (运行中: %d)", totalMonitored, runningCount)

	// 如果有正在监控的进程，显示详细信息
	if runningCount > 0 {
		mm.mutex.RLock()
		for _, proc := range mm.processes {
			if proc.Status == "running" {
				runningTime := time.Since(proc.StartTime)
				environment := "主机"
				if proc.IsContainer {
					environment = fmt.Sprintf("容器 %s", proc.ContainerID)
				}
				mm.logger.Infof("监控中: %s (PID=%d, 运行时长=%s, 环境=%s)",
					proc.Info.Command, proc.Info.PID, utils.FormatDuration(runningTime), environment)
			}
		}
		mm.mutex.RUnlock()
	}

	mm.logger.Info(logMsg)
}

// isContainerProcessRunning 检查容器内进程是否还在运行
func (mm *MonitorManager) isContainerProcessRunning(containerID string, pid int) bool {
	cmd := fmt.Sprintf("docker exec %s ps -p %d -o pid --no-headers", containerID, pid)
	output, err := mm.executeCommand(cmd)
	if err != nil {
		mm.logger.Debugf("检查容器进程失败 PID=%d: %v", pid, err)
		return false
	}

	// 检查输出是否包含PID
	lines := strings.Split(strings.TrimSpace(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == fmt.Sprintf("%d", pid) {
			return true
		}
	}

	return false
}

// executeCommand 执行系统命令
func (mm *MonitorManager) executeCommand(cmd string) (string, error) {
	parts := strings.Fields(cmd)
	if len(parts) == 0 {
		return "", fmt.Errorf("空命令")
	}

	command := exec.Command(parts[0], parts[1:]...)
	output, err := command.Output()
	if err != nil {
		return "", fmt.Errorf("命令执行失败: %v", err)
	}

	return string(output), nil
}

// cleanupCompletedProcesses 清理已完成的进程
func (mm *MonitorManager) cleanupCompletedProcesses() {
	mm.mutex.Lock()
	defer mm.mutex.Unlock()

	// 清理已完成且超过保留时间的进程
	retentionTime := 10 * time.Minute // 减少保留时间到10分钟
	now := time.Now()

	for pid, proc := range mm.processes {
		if proc.Status == "completed" {
			// 如果完成时间超过保留时间，则删除
			if now.Sub(proc.LastSeen) > retentionTime {
				mm.logger.Debugf("清理已完成进程: %s (PID=%d)", proc.Info.Command, pid)
				delete(mm.processes, pid)
			}
		}
	}
}

// GetAllProcesses 获取所有监控的进程
func (mm *MonitorManager) GetAllProcesses() []*utils.MonitoredProcess {
	mm.mutex.RLock()
	defer mm.mutex.RUnlock()

	processes := make([]*utils.MonitoredProcess, 0, len(mm.processes))
	for _, proc := range mm.processes {
		processes = append(processes, proc)
	}

	return processes
}

// GetProcess 获取指定PID的进程
func (mm *MonitorManager) GetProcess(pid int) (*utils.MonitoredProcess, error) {
	mm.mutex.RLock()
	defer mm.mutex.RUnlock()

	if proc, exists := mm.processes[pid]; exists {
		return proc, nil
	}

	return nil, fmt.Errorf("进程 %d 未被监控", pid)
}

// GetActiveProcessCount 获取活跃进程数量
func (mm *MonitorManager) GetActiveProcessCount() int {
	mm.mutex.RLock()
	defer mm.mutex.RUnlock()

	count := 0
	for _, proc := range mm.processes {
		if proc.Status == "running" {
			count++
		}
	}

	return count
}

// GetCompletedProcessCount 获取已完成进程数量
func (mm *MonitorManager) GetCompletedProcessCount() int {
	mm.mutex.RLock()
	defer mm.mutex.RUnlock()

	count := 0
	for _, proc := range mm.processes {
		if proc.Status == "completed" {
			count++
		}
	}

	return count
}

// getRunningContainers 获取运行中的Docker容器ID列表
func (mm *MonitorManager) getRunningContainers() ([]string, error) {
	cmd := exec.Command("docker", "ps", "-q")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("执行docker ps失败: %v", err)
	}

	containerIDs := strings.Fields(strings.TrimSpace(string(output)))
	return containerIDs, nil
}
