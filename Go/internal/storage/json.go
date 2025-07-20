package storage

import (
	"cmdmonitor/pkg/utils"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
)

// JSONStorage JSON文件存储实现
type JSONStorage struct {
	logger    *logrus.Logger
	filePath  string
	processes map[int]*utils.MonitoredProcess
	mutex     sync.RWMutex
}

// StorageData 存储数据结构
type StorageData struct {
	Processes map[int]*utils.MonitoredProcess `json:"processes"`
	UpdatedAt time.Time                       `json:"updated_at"`
}

// NewJSONStorage 创建新的JSON存储
func NewJSONStorage(logger *logrus.Logger, filePath string) *JSONStorage {
	return &JSONStorage{
		logger:    logger,
		filePath:  filePath,
		processes: make(map[int]*utils.MonitoredProcess),
	}
}

// Initialize 初始化存储
func (s *JSONStorage) Initialize() error {
	s.logger.Infof("初始化JSON存储: %s", s.filePath)

	// 确保目录存在
	dir := filepath.Dir(s.filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("创建存储目录失败: %v", err)
	}

	// 尝试加载现有数据
	if err := s.loadFromFile(); err != nil {
		s.logger.Warnf("加载现有数据失败，将创建新文件: %v", err)
		// 创建空的存储文件
		if err := s.saveToFile(); err != nil {
			return fmt.Errorf("创建存储文件失败: %v", err)
		}
	}

	s.logger.Info("JSON存储初始化完成")
	return nil
}

// SaveMonitoredProcess 保存监控进程
func (s *JSONStorage) SaveMonitoredProcess(process *utils.MonitoredProcess) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	s.logger.Debugf("保存监控进程: PID=%d, Command=%s", process.Info.PID, process.Info.Command)
	
	s.processes[process.Info.PID] = process
	return s.saveToFile()
}

// UpdateMonitoredProcess 更新监控进程
func (s *JSONStorage) UpdateMonitoredProcess(process *utils.MonitoredProcess) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	s.logger.Debugf("更新监控进程: PID=%d, Status=%s", process.Info.PID, process.Status)
	
	if _, exists := s.processes[process.Info.PID]; !exists {
		return fmt.Errorf("进程 %d 不存在", process.Info.PID)
	}

	s.processes[process.Info.PID] = process
	return s.saveToFile()
}

// GetMonitoredProcess 获取监控进程
func (s *JSONStorage) GetMonitoredProcess(pid int) (*utils.MonitoredProcess, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	if process, exists := s.processes[pid]; exists {
		return process, nil
	}

	return nil, fmt.Errorf("进程 %d 未找到", pid)
}

// GetAllMonitoredProcesses 获取所有监控进程
func (s *JSONStorage) GetAllMonitoredProcesses() ([]*utils.MonitoredProcess, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	processes := make([]*utils.MonitoredProcess, 0, len(s.processes))
	for _, process := range s.processes {
		processes = append(processes, process)
	}

	return processes, nil
}

// GetProcessesByTimeRange 获取指定时间范围内的进程
func (s *JSONStorage) GetProcessesByTimeRange(startTime, endTime time.Time) ([]*utils.MonitoredProcess, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	var processes []*utils.MonitoredProcess
	for _, process := range s.processes {
		if process.StartTime.After(startTime) && process.StartTime.Before(endTime) {
			processes = append(processes, process)
		}
	}

	return processes, nil
}

// GetCompletedProcesses 获取已完成的进程
func (s *JSONStorage) GetCompletedProcesses(limit int) ([]*utils.MonitoredProcess, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	var processes []*utils.MonitoredProcess
	count := 0
	
	for _, process := range s.processes {
		if process.Status == "completed" {
			processes = append(processes, process)
			count++
			if limit > 0 && count >= limit {
				break
			}
		}
	}

	return processes, nil
}

// DeleteProcess 删除进程记录
func (s *JSONStorage) DeleteProcess(pid int) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	s.logger.Debugf("删除进程记录: PID=%d", pid)

	if _, exists := s.processes[pid]; !exists {
		return fmt.Errorf("进程 %d 未找到", pid)
	}

	delete(s.processes, pid)
	return s.saveToFile()
}

// CleanupOldRecords 清理旧记录
func (s *JSONStorage) CleanupOldRecords(olderThan time.Time) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	s.logger.Infof("清理早于 %s 的记录", olderThan.Format("2006-01-02 15:04:05"))

	deletedCount := 0
	for pid, process := range s.processes {
		if process.Status == "completed" && process.LastSeen.Before(olderThan) {
			delete(s.processes, pid)
			deletedCount++
		}
	}

	s.logger.Infof("清理了 %d 条旧记录", deletedCount)
	
	if deletedCount > 0 {
		return s.saveToFile()
	}
	
	return nil
}

// GetStatistics 获取统计信息
func (s *JSONStorage) GetStatistics() (*StorageStatistics, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	stats := &StorageStatistics{}

	for _, process := range s.processes {
		stats.TotalProcesses++
		
		switch process.Status {
		case "running":
			stats.RunningProcesses++
		case "completed":
			stats.CompletedProcesses++
			if process.ExitCode != nil && *process.ExitCode != 0 {
				stats.FailedProcesses++
			}
		}

		if process.IsContainer {
			stats.ContainerProcesses++
		} else {
			stats.HostProcesses++
		}
	}

	return stats, nil
}

// Close 关闭存储
func (s *JSONStorage) Close() error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	s.logger.Info("关闭JSON存储")
	
	// 最后保存一次数据
	return s.saveToFile()
}

// loadFromFile 从文件加载数据
func (s *JSONStorage) loadFromFile() error {
	if _, err := os.Stat(s.filePath); os.IsNotExist(err) {
		// 文件不存在，初始化空数据
		s.processes = make(map[int]*utils.MonitoredProcess)
		return nil
	}

	data, err := os.ReadFile(s.filePath)
	if err != nil {
		return fmt.Errorf("读取存储文件失败: %v", err)
	}

	if len(data) == 0 {
		// 空文件，初始化空数据
		s.processes = make(map[int]*utils.MonitoredProcess)
		return nil
	}

	var storageData StorageData
	if err := json.Unmarshal(data, &storageData); err != nil {
		return fmt.Errorf("解析存储文件失败: %v", err)
	}

	if storageData.Processes == nil {
		s.processes = make(map[int]*utils.MonitoredProcess)
	} else {
		s.processes = storageData.Processes
	}

	s.logger.Infof("从文件加载了 %d 个进程记录", len(s.processes))
	return nil
}

// saveToFile 保存数据到文件
func (s *JSONStorage) saveToFile() error {
	storageData := StorageData{
		Processes: s.processes,
		UpdatedAt: time.Now(),
	}

	data, err := json.MarshalIndent(storageData, "", "  ")
	if err != nil {
		return fmt.Errorf("序列化数据失败: %v", err)
	}

	// 写入临时文件，然后原子性重命名
	tempFile := s.filePath + ".tmp"
	if err := os.WriteFile(tempFile, data, 0644); err != nil {
		return fmt.Errorf("写入临时文件失败: %v", err)
	}

	if err := os.Rename(tempFile, s.filePath); err != nil {
		os.Remove(tempFile) // 清理临时文件
		return fmt.Errorf("重命名文件失败: %v", err)
	}

	return nil
}
