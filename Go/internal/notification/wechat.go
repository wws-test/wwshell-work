package notification

import (
	"bytes"
	"cmdmonitor/pkg/utils"
	"encoding/json"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

// WeChatNotifier 企业微信通知器
type WeChatNotifier struct {
	logger         *logrus.Logger
	webhookURL     string
	defaultContact string
	httpClient     *http.Client
	formatter      MessageFormatter
}

// WeChatMessage 企业微信消息结构
type WeChatMessage struct {
	MsgType  string            `json:"msgtype"`
	Text     *WeChatTextMsg    `json:"text,omitempty"`
	Markdown *WeChatMarkdownMsg `json:"markdown,omitempty"`
}

// WeChatTextMsg 文本消息
type WeChatTextMsg struct {
	Content             string   `json:"content"`
	MentionedList       []string `json:"mentioned_list,omitempty"`
	MentionedMobileList []string `json:"mentioned_mobile_list,omitempty"`
}

// WeChatMarkdownMsg Markdown消息
type WeChatMarkdownMsg struct {
	Content string `json:"content"`
}

// WeChatResponse 企业微信响应
type WeChatResponse struct {
	ErrCode int    `json:"errcode"`
	ErrMsg  string `json:"errmsg"`
}

// NewWeChatNotifier 创建新的微信通知器
func NewWeChatNotifier(logger *logrus.Logger, webhookURL, defaultContact string) *WeChatNotifier {
	return &WeChatNotifier{
		logger:         logger,
		webhookURL:     webhookURL,
		defaultContact: defaultContact,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		formatter: &DefaultMessageFormatter{},
	}
}

// SendProcessCompleted 发送进程完成通知
func (w *WeChatNotifier) SendProcessCompleted(process *utils.MonitoredProcess) error {
	w.logger.Infof("发送进程完成通知: %s (PID=%d)", process.Info.Command, process.Info.PID)

	content := w.formatter.FormatProcessCompleted(process)
	
	// 创建消息
	message := &WeChatMessage{
		MsgType: "text",
		Text: &WeChatTextMsg{
			Content: content,
		},
	}

	// 如果有默认联系人，添加@提醒
	if w.defaultContact != "" {
		if w.defaultContact == "@all" {
			message.Text.MentionedList = []string{"@all"}
		} else {
			message.Text.MentionedList = []string{w.defaultContact}
		}
	}

	return w.sendMessage(message)
}

// SendTestMessage 发送测试消息
func (w *WeChatNotifier) SendTestMessage(msg string) error {
	w.logger.Info("发送测试消息")

	content := w.formatter.FormatTestMessage(msg)
	
	message := &WeChatMessage{
		MsgType: "text",
		Text: &WeChatTextMsg{
			Content: content,
		},
	}

	return w.sendMessage(message)
}

// sendMessage 发送消息到企业微信
func (w *WeChatNotifier) sendMessage(message *WeChatMessage) error {
	// 序列化消息
	jsonData, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("序列化消息失败: %v", err)
	}

	w.logger.Debugf("发送微信消息: %s", string(jsonData))

	// 创建HTTP请求
	req, err := http.NewRequest("POST", w.webhookURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("创建HTTP请求失败: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")

	// 发送请求
	resp, err := w.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("发送HTTP请求失败: %v", err)
	}
	defer resp.Body.Close()

	// 解析响应
	var wechatResp WeChatResponse
	if err := json.NewDecoder(resp.Body).Decode(&wechatResp); err != nil {
		return fmt.Errorf("解析响应失败: %v", err)
	}

	// 检查响应状态
	if wechatResp.ErrCode != 0 {
		return fmt.Errorf("微信API错误: code=%d, msg=%s", wechatResp.ErrCode, wechatResp.ErrMsg)
	}

	w.logger.Debug("微信消息发送成功")
	return nil
}

// Close 关闭通知器
func (w *WeChatNotifier) Close() error {
	// HTTP客户端不需要显式关闭
	return nil
}

// DefaultMessageFormatter 默认消息格式化器
type DefaultMessageFormatter struct{}

// FormatProcessCompleted 格式化进程完成消息
func (f *DefaultMessageFormatter) FormatProcessCompleted(process *utils.MonitoredProcess) string {
	var builder strings.Builder

	// 标题
	builder.WriteString("🔔 长命令执行完成通知\n\n")

	// 状态图标
	statusIcon := "✅ 成功"
	if process.ExitCode != nil && *process.ExitCode != 0 {
		statusIcon = "❌ 失败"
	}

	// 基本信息
	commandName := filepath.Base(process.Info.Command)
	builder.WriteString(fmt.Sprintf("%s 命令: %s", statusIcon, commandName))
	
	// 如果有参数，显示部分参数
	if len(process.Info.Args) > 0 {
		argsStr := strings.Join(process.Info.Args, " ")
		if len(argsStr) > 50 {
			argsStr = argsStr[:50] + "..."
		}
		builder.WriteString(fmt.Sprintf(" %s", argsStr))
	}
	builder.WriteString("\n")

	// 执行时长
	builder.WriteString(fmt.Sprintf("⏱️ 执行时长: %s\n", utils.FormatDuration(process.Duration)))

	// 退出码
	exitCode := 0
	if process.ExitCode != nil {
		exitCode = *process.ExitCode
	}
	builder.WriteString(fmt.Sprintf("📊 退出码: %d\n", exitCode))

	// 内存使用
	if process.MemoryUsage > 0 {
		builder.WriteString(fmt.Sprintf("💾 内存使用: %s\n", utils.FormatBytes(process.MemoryUsage*1024)))
	}

	// CPU使用率
	if process.CPUUsage > 0 {
		builder.WriteString(fmt.Sprintf("🖥️ CPU使用: %.1f%%\n", process.CPUUsage))
	}

	// 容器信息
	if process.IsContainer {
		containerName := process.ContainerID
		if len(containerName) > 12 {
			containerName = containerName[:12]
		}
		builder.WriteString(fmt.Sprintf("📍 容器: %s\n", containerName))
	} else {
		builder.WriteString("📍 主机进程\n")
	}

	// 用户信息
	if process.Info.User != "" {
		builder.WriteString(fmt.Sprintf("👤 用户: %s\n", process.Info.User))
	}

	// 工作目录
	if process.Info.WorkingDir != "" {
		workDir := process.Info.WorkingDir
		if len(workDir) > 40 {
			workDir = "..." + workDir[len(workDir)-37:]
		}
		builder.WriteString(fmt.Sprintf("📂 工作目录: %s\n", workDir))
	}

	// 完成时间
	builder.WriteString(fmt.Sprintf("⏰ 完成时间: %s\n", time.Now().Format("2006-01-02 15:04:05")))

	// PID信息
	builder.WriteString(fmt.Sprintf("🔢 进程ID: %d", process.Info.PID))

	return builder.String()
}

// FormatTestMessage 格式化测试消息
func (f *DefaultMessageFormatter) FormatTestMessage(message string) string {
	return fmt.Sprintf("🧪 测试消息\n\n%s\n\n⏰ 发送时间: %s", 
		message, time.Now().Format("2006-01-02 15:04:05"))
}
