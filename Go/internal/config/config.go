package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

// Config 精准监控应用配置
type Config struct {
	// 邮箱通知配置
	EmailSMTPHost    string `json:"email_smtp_host"`
	EmailSMTPPort    string `json:"email_smtp_port"`
	EmailUsername    string `json:"email_username"`
	EmailPassword    string `json:"email_password"`
	EmailFromAddress string `json:"email_from_address"`
	EmailDefaultTo   string `json:"email_default_to"`

	// 核心监控配置
	MonitorThresholdMinutes int `json:"monitor_threshold_minutes"`
	ScanIntervalSeconds     int `json:"scan_interval_seconds"`
	MaxMonitoredProcesses   int `json:"max_monitored_processes"`

	// Docker配置
	DockerSocket         string `json:"docker_socket"`
	MonitorDockerEnabled bool   `json:"monitor_docker_enabled"`

	// 存储配置
	StoragePath string `json:"storage_path"`

	// 精准监控配置
	DynamicTagsFile string `json:"dynamic_tags_file"`

	// 日志配置
	LogLevel string `json:"log_level"`
	LogPath  string `json:"log_path"`
}

// DefaultConfig 精准监控默认配置
func DefaultConfig() *Config {
	return &Config{
		EmailSMTPHost:           "smtp.qq.com",
		EmailSMTPPort:           "587",
		EmailUsername:           "",
		EmailPassword:           "",
		EmailFromAddress:        "",
		EmailDefaultTo:          "1092587222@qq.com",
		MonitorThresholdMinutes: 5,
		ScanIntervalSeconds:     30,
		MaxMonitoredProcesses:   20, // 精准监控下减少默认值
		DockerSocket:            "/var/run/docker.sock",
		MonitorDockerEnabled:    true, // 默认启用Docker监控
		StoragePath:             "/var/lib/cmdmonitor/data.json",
		DynamicTagsFile:         "/etc/cmdmonitor/dynamic_tags.txt",
		LogLevel:                "info",
		LogPath:                 "/var/log/cmdmonitor.log",
	}
}

// LoadFromEnv 从环境变量加载配置
func LoadFromEnv() (*Config, error) {
	config := DefaultConfig()

	// 邮箱配置
	if smtpHost := os.Getenv("EMAIL_SMTP_HOST"); smtpHost != "" {
		config.EmailSMTPHost = smtpHost
	}

	if smtpPort := os.Getenv("EMAIL_SMTP_PORT"); smtpPort != "" {
		config.EmailSMTPPort = smtpPort
	}

	if username := os.Getenv("EMAIL_USERNAME"); username != "" {
		config.EmailUsername = username
	}

	if password := os.Getenv("EMAIL_PASSWORD"); password != "" {
		config.EmailPassword = password
	}

	if fromAddr := os.Getenv("EMAIL_FROM_ADDRESS"); fromAddr != "" {
		config.EmailFromAddress = fromAddr
	}

	if defaultTo := os.Getenv("EMAIL_DEFAULT_TO"); defaultTo != "" {
		config.EmailDefaultTo = defaultTo
	}

	// 监控配置
	if threshold := os.Getenv("MONITOR_THRESHOLD_MINUTES"); threshold != "" {
		if val, err := strconv.Atoi(threshold); err == nil && val > 0 {
			config.MonitorThresholdMinutes = val
		}
	}

	if interval := os.Getenv("SCAN_INTERVAL_SECONDS"); interval != "" {
		if val, err := strconv.Atoi(interval); err == nil && val > 0 {
			config.ScanIntervalSeconds = val
		}
	}

	if maxProc := os.Getenv("MAX_MONITORED_PROCESSES"); maxProc != "" {
		if val, err := strconv.Atoi(maxProc); err == nil && val > 0 {
			config.MaxMonitoredProcesses = val
		}
	}

	// Docker配置
	if socket := os.Getenv("DOCKER_SOCKET"); socket != "" {
		config.DockerSocket = socket
	}

	if dockerEnabled := os.Getenv("MONITOR_DOCKER_ENABLED"); dockerEnabled != "" {
		config.MonitorDockerEnabled = strings.ToLower(dockerEnabled) == "true"
	}

	// 存储配置
	if storagePath := os.Getenv("STORAGE_PATH"); storagePath != "" {
		config.StoragePath = storagePath
	}

	// 日志配置
	if logLevel := os.Getenv("LOG_LEVEL"); logLevel != "" {
		config.LogLevel = strings.ToLower(logLevel)
	}

	if logPath := os.Getenv("LOG_PATH"); logPath != "" {
		config.LogPath = logPath
	}

	// 精准监控配置
	if dynamicFile := os.Getenv("DYNAMIC_TAGS_FILE"); dynamicFile != "" {
		config.DynamicTagsFile = dynamicFile
	}

	return config, nil
}

// Validate 验证配置
func (c *Config) Validate() error {
	// 必需的邮箱配置检查
	if c.EmailUsername == "" {
		return fmt.Errorf("EMAIL_USERNAME 是必需的配置")
	}

	if c.EmailPassword == "" {
		return fmt.Errorf("EMAIL_PASSWORD 是必需的配置")
	}

	if c.EmailFromAddress == "" {
		return fmt.Errorf("EMAIL_FROM_ADDRESS 是必需的配置")
	}

	if c.EmailDefaultTo == "" {
		return fmt.Errorf("EMAIL_DEFAULT_TO 是必需的配置")
	}

	// 验证数值范围
	if c.MonitorThresholdMinutes < 1 {
		return fmt.Errorf("MONITOR_THRESHOLD_MINUTES 必须大于0")
	}

	if c.ScanIntervalSeconds < 10 {
		return fmt.Errorf("SCAN_INTERVAL_SECONDS 必须大于等于10秒")
	}

	if c.MaxMonitoredProcesses < 1 {
		return fmt.Errorf("MAX_MONITORED_PROCESSES 必须大于0")
	}

	// 验证日志级别
	validLogLevels := []string{"trace", "debug", "info", "warn", "error", "fatal", "panic"}
	isValidLogLevel := false
	for _, level := range validLogLevels {
		if c.LogLevel == level {
			isValidLogLevel = true
			break
		}
	}
	if !isValidLogLevel {
		return fmt.Errorf("LOG_LEVEL 必须是以下值之一: %s", strings.Join(validLogLevels, ", "))
	}

	return nil
}

// GetLogLevel 获取日志级别
func (c *Config) GetLogLevel() logrus.Level {
	switch strings.ToLower(c.LogLevel) {
	case "trace":
		return logrus.TraceLevel
	case "debug":
		return logrus.DebugLevel
	case "info":
		return logrus.InfoLevel
	case "warn", "warning":
		return logrus.WarnLevel
	case "error":
		return logrus.ErrorLevel
	case "fatal":
		return logrus.FatalLevel
	case "panic":
		return logrus.PanicLevel
	default:
		return logrus.InfoLevel
	}
}

// String 返回配置的字符串表示（隐藏敏感信息）
func (c *Config) String() string {
	// 隐藏敏感的邮箱密码
	maskedPassword := c.EmailPassword
	if len(maskedPassword) > 3 {
		maskedPassword = maskedPassword[:3] + "***"
	}

	return fmt.Sprintf(`精准监控配置信息:
  邮箱SMTP: %s:%s
  邮箱用户: %s
  邮箱密码: %s
  发件地址: %s
  默认收件人: %s
  监控阈值: %d分钟
  扫描间隔: %d秒
  最大监控进程数: %d
  Docker监控: %t
  Docker Socket: %s
  存储路径: %s
  动态标记文件: %s
  日志级别: %s
  日志路径: %s`,
		c.EmailSMTPHost,
		c.EmailSMTPPort,
		c.EmailUsername,
		maskedPassword,
		c.EmailFromAddress,
		c.EmailDefaultTo,
		c.MonitorThresholdMinutes,
		c.ScanIntervalSeconds,
		c.MaxMonitoredProcesses,
		c.MonitorDockerEnabled,
		c.DockerSocket,
		c.StoragePath,
		c.DynamicTagsFile,
		c.LogLevel,
		c.LogPath,
	)
}

// GetThresholdDuration 获取监控阈值时间间隔
func (c *Config) GetThresholdDuration() time.Duration {
	return time.Duration(c.MonitorThresholdMinutes) * time.Minute
}

// GetScanInterval 获取扫描间隔时间间隔
func (c *Config) GetScanInterval() time.Duration {
	return time.Duration(c.ScanIntervalSeconds) * time.Second
}
