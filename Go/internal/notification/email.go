package notification

import (
	"cmdmonitor/pkg/utils"
	"fmt"
	"net/smtp"
	"path/filepath"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

// EmailNotifier 邮箱通知器
type EmailNotifier struct {
	logger       *logrus.Logger
	smtpHost     string
	smtpPort     string
	username     string
	password     string
	fromEmail    string
	defaultEmail string
	formatter    MessageFormatter
}

// EmailConfig 邮箱配置
type EmailConfig struct {
	SMTPHost     string
	SMTPPort     string
	Username     string
	Password     string
	FromEmail    string
	DefaultEmail string
}

// NewEmailNotifier 创建新的邮箱通知器
func NewEmailNotifier(logger *logrus.Logger, config EmailConfig) *EmailNotifier {
	return &EmailNotifier{
		logger:       logger,
		smtpHost:     config.SMTPHost,
		smtpPort:     config.SMTPPort,
		username:     config.Username,
		password:     config.Password,
		fromEmail:    config.FromEmail,
		defaultEmail: config.DefaultEmail,
		formatter:    &EmailMessageFormatter{},
	}
}

// SendProcessCompleted 发送进程完成通知
func (e *EmailNotifier) SendProcessCompleted(process *utils.MonitoredProcess) error {
	e.logger.Infof("发送进程完成邮件通知: %s (PID=%d)", process.Info.Command, process.Info.PID)

	subject := e.formatSubject(process)
	body := e.formatter.FormatProcessCompleted(process)

	// 详细记录邮件内容到日志
	e.logger.Infof("邮件主题: %s", subject)
	e.logger.Infof("邮件内容:\n%s", body)

	err := e.sendEmail(e.defaultEmail, subject, body)
	if err != nil {
		e.logger.Errorf("邮件发送失败: %v", err)
		e.logger.Warnf("邮件发送失败，但进程监控功能正常工作")
	} else {
		e.logger.Info("邮件发送成功")
	}

	return err
}

// SendTestMessage 发送测试消息
func (e *EmailNotifier) SendTestMessage(msg string) error {
	e.logger.Info("发送测试邮件")

	subject := "Command Monitor 测试邮件"
	body := e.formatter.FormatTestMessage(msg)

	return e.sendEmail(e.defaultEmail, subject, body)
}

// sendEmail 发送邮件
func (e *EmailNotifier) sendEmail(to, subject, body string) error {
	// 构建邮件内容
	message := e.buildEmailMessage(to, subject, body)

	// SMTP认证
	auth := smtp.PlainAuth("", e.username, e.password, e.smtpHost)

	// 发送邮件
	addr := fmt.Sprintf("%s:%s", e.smtpHost, e.smtpPort)
	err := smtp.SendMail(addr, auth, e.fromEmail, []string{to}, []byte(message))
	if err != nil {
		// 检查是否是"short response"错误，这通常表示邮件已发送但服务器响应异常
		if strings.Contains(err.Error(), "short response") {
			e.logger.Warnf("SMTP服务器响应异常，但邮件可能已发送成功: %v", err)
			e.logger.Info("邮件发送可能成功（忽略服务器响应错误）")
			return nil // 忽略这种错误，认为发送成功
		}
		return fmt.Errorf("发送邮件失败: %v", err)
	}

	e.logger.Debug("邮件发送成功")
	return nil
}

// buildEmailMessage 构建邮件消息
func (e *EmailNotifier) buildEmailMessage(to, subject, body string) string {
	var message strings.Builder

	// 邮件头
	message.WriteString(fmt.Sprintf("From: %s\r\n", e.fromEmail))
	message.WriteString(fmt.Sprintf("To: %s\r\n", to))
	message.WriteString(fmt.Sprintf("Subject: %s\r\n", subject))
	message.WriteString("MIME-Version: 1.0\r\n")
	message.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	message.WriteString("\r\n")

	// 邮件正文
	message.WriteString(body)

	return message.String()
}

// formatSubject 格式化邮件主题
func (e *EmailNotifier) formatSubject(process *utils.MonitoredProcess) string {
	commandName := filepath.Base(process.Info.Command)
	status := "成功"
	if process.ExitCode != nil && *process.ExitCode != 0 {
		status = "失败"
	}

	return fmt.Sprintf("[Command Monitor] 长命令执行%s - %s", status, commandName)
}

// Close 关闭通知器
func (e *EmailNotifier) Close() error {
	// 邮件通知器不需要显式关闭
	return nil
}

// EmailMessageFormatter 邮箱消息格式化器
type EmailMessageFormatter struct{}

// FormatProcessCompleted 格式化进程完成消息
func (f *EmailMessageFormatter) FormatProcessCompleted(process *utils.MonitoredProcess) string {
	var builder strings.Builder

	// 标题
	builder.WriteString("长命令执行完成通知\n")
	builder.WriteString("=" + strings.Repeat("=", 30) + "\n\n")

	// 状态
	status := "成功"
	statusIcon := "✅"
	if process.ExitCode != nil && *process.ExitCode != 0 {
		status = "失败"
		statusIcon = "❌"
	}

	// 基本信息
	commandName := filepath.Base(process.Info.Command)
	builder.WriteString(fmt.Sprintf("%s 执行状态: %s\n", statusIcon, status))
	builder.WriteString(fmt.Sprintf("📋 命令名称: %s\n", commandName))

	// 如果有参数，显示部分参数
	if len(process.Info.Args) > 0 {
		argsStr := strings.Join(process.Info.Args, " ")
		if len(argsStr) > 100 {
			argsStr = argsStr[:100] + "..."
		}
		builder.WriteString(fmt.Sprintf("📝 命令参数: %s\n", argsStr))
	}

	builder.WriteString("\n详细信息:\n")
	builder.WriteString("-" + strings.Repeat("-", 20) + "\n")

	// 执行时长
	builder.WriteString(fmt.Sprintf("⏱️  执行时长: %s\n", utils.FormatDuration(process.Duration)))

	// 退出码
	exitCode := 0
	if process.ExitCode != nil {
		exitCode = *process.ExitCode
	}
	builder.WriteString(fmt.Sprintf("📊 退出码: %d\n", exitCode))

	// 进程信息
	builder.WriteString(fmt.Sprintf("🔢 进程ID: %d\n", process.Info.PID))

	// 内存使用
	if process.MemoryUsage > 0 {
		builder.WriteString(fmt.Sprintf("💾 内存使用: %s\n", utils.FormatBytes(process.MemoryUsage*1024)))
	}

	// CPU使用率
	if process.CPUUsage > 0 {
		builder.WriteString(fmt.Sprintf("🖥️  CPU使用: %.1f%%\n", process.CPUUsage))
	}

	// 容器信息
	if process.IsContainer {
		containerName := process.ContainerID
		if len(containerName) > 12 {
			containerName = containerName[:12]
		}
		builder.WriteString(fmt.Sprintf("📍 运行环境: Docker容器 (%s)\n", containerName))
	} else {
		builder.WriteString("📍 运行环境: 主机进程\n")
	}

	// 用户信息
	if process.Info.User != "" {
		builder.WriteString(fmt.Sprintf("👤 执行用户: %s\n", process.Info.User))
	}

	// 工作目录
	if process.Info.WorkingDir != "" {
		workDir := process.Info.WorkingDir
		if len(workDir) > 60 {
			workDir = "..." + workDir[len(workDir)-57:]
		}
		builder.WriteString(fmt.Sprintf("📂 工作目录: %s\n", workDir))
	}

	// 时间信息
	builder.WriteString(fmt.Sprintf("🕐 开始时间: %s\n", process.StartTime.Format("2006-01-02 15:04:05")))
	builder.WriteString(fmt.Sprintf("🕑 完成时间: %s\n", time.Now().Format("2006-01-02 15:04:05")))

	// 分隔线
	builder.WriteString("\n" + strings.Repeat("=", 50) + "\n")
	builder.WriteString("此邮件由 Command Monitor 自动发送\n")
	builder.WriteString("如有问题，请检查服务配置或联系管理员\n")

	return builder.String()
}

// FormatTestMessage 格式化测试消息
func (f *EmailMessageFormatter) FormatTestMessage(message string) string {
	var builder strings.Builder

	builder.WriteString("Command Monitor 测试邮件\n")
	builder.WriteString("=" + strings.Repeat("=", 30) + "\n\n")
	builder.WriteString("🧪 这是一封测试邮件\n\n")
	builder.WriteString(fmt.Sprintf("📝 测试内容: %s\n\n", message))
	builder.WriteString(fmt.Sprintf("⏰ 发送时间: %s\n\n", time.Now().Format("2006-01-02 15:04:05")))
	builder.WriteString("如果您收到这封邮件，说明 Command Monitor 邮件通知功能正常工作。\n\n")
	builder.WriteString(strings.Repeat("=", 50) + "\n")
	builder.WriteString("此邮件由 Command Monitor 自动发送\n")

	return builder.String()
}
