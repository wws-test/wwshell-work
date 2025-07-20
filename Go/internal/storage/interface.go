package storage

import (
	"cmdmonitor/pkg/utils"
	"time"
)

// Storage 存储接口
type Storage interface {
	// 初始化存储
	Initialize() error
	
	// 保存监控进程
	SaveMonitoredProcess(process *utils.MonitoredProcess) error
	
	// 更新监控进程
	UpdateMonitoredProcess(process *utils.MonitoredProcess) error
	
	// 获取监控进程
	GetMonitoredProcess(pid int) (*utils.MonitoredProcess, error)
	
	// 获取所有监控进程
	GetAllMonitoredProcesses() ([]*utils.MonitoredProcess, error)
	
	// 获取指定时间范围内的进程
	GetProcessesByTimeRange(startTime, endTime time.Time) ([]*utils.MonitoredProcess, error)
	
	// 获取已完成的进程
	GetCompletedProcesses(limit int) ([]*utils.MonitoredProcess, error)
	
	// 删除进程记录
	DeleteProcess(pid int) error
	
	// 清理旧记录
	CleanupOldRecords(olderThan time.Time) error
	
	// 获取统计信息
	GetStatistics() (*StorageStatistics, error)
	
	// 关闭存储
	Close() error
}

// StorageStatistics 存储统计信息
type StorageStatistics struct {
	TotalProcesses     int `json:"total_processes"`
	RunningProcesses   int `json:"running_processes"`
	CompletedProcesses int `json:"completed_processes"`
	FailedProcesses    int `json:"failed_processes"`
	ContainerProcesses int `json:"container_processes"`
	HostProcesses      int `json:"host_processes"`
}

// ProcessQuery 进程查询条件
type ProcessQuery struct {
	Status      string    `json:"status,omitempty"`      // "running", "completed", "failed"
	IsContainer *bool     `json:"is_container,omitempty"`
	StartTime   time.Time `json:"start_time,omitempty"`
	EndTime     time.Time `json:"end_time,omitempty"`
	Command     string    `json:"command,omitempty"`
	User        string    `json:"user,omitempty"`
	Limit       int       `json:"limit,omitempty"`
	Offset      int       `json:"offset,omitempty"`
}
