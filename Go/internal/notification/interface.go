package notification

import "cmdmonitor/pkg/utils"

// Notifier 通知接口
type Notifier interface {
	// SendProcessCompleted 发送进程完成通知
	SendProcessCompleted(process *utils.MonitoredProcess) error
	
	// SendTestMessage 发送测试消息
	SendTestMessage(message string) error
	
	// Close 关闭通知器
	Close() error
}

// NotificationMessage 通知消息结构
type NotificationMessage struct {
	Title     string                   `json:"title"`
	Content   string                   `json:"content"`
	Process   *utils.MonitoredProcess  `json:"process,omitempty"`
	Timestamp int64                    `json:"timestamp"`
	Type      string                   `json:"type"` // "success", "error", "info"
}

// MessageFormatter 消息格式化器接口
type MessageFormatter interface {
	// FormatProcessCompleted 格式化进程完成消息
	FormatProcessCompleted(process *utils.MonitoredProcess) string
	
	// FormatTestMessage 格式化测试消息
	FormatTestMessage(message string) string
}
