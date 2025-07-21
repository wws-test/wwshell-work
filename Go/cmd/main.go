package main

import (
	"cmdmonitor/internal/config"
	"cmdmonitor/internal/monitor"
	"cmdmonitor/internal/notification"
	"cmdmonitor/internal/storage"
	"cmdmonitor/pkg/utils"
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/sirupsen/logrus"
)

// Version 版本信息（构建时注入）
var Version = "dev"

// Application 应用程序结构
type Application struct {
	config         *config.Config
	logger         *logrus.Logger
	storage        storage.Storage
	processScanner *monitor.ProcessScanner
	monitorManager *monitor.MonitorManager
	notifier       notification.Notifier
}

func main() {
	// 创建应用实例
	app := &Application{}

	// 初始化应用
	if err := app.initialize(); err != nil {
		fmt.Fprintf(os.Stderr, "初始化应用失败: %v\n", err)
		os.Exit(1)
	}

	// 启动应用
	if err := app.run(); err != nil {
		app.logger.Errorf("运行应用失败: %v", err)
		os.Exit(1)
	}
}

// initialize 初始化应用
func (app *Application) initialize() error {
	// 1. 加载配置
	cfg, err := config.LoadFromEnv()
	if err != nil {
		return fmt.Errorf("加载配置失败: %v", err)
	}

	// 验证配置
	if err := cfg.Validate(); err != nil {
		return fmt.Errorf("配置验证失败: %v", err)
	}

	app.config = cfg

	// 2. 初始化日志
	if err := app.initializeLogger(); err != nil {
		return fmt.Errorf("初始化日志失败: %v", err)
	}

	app.logger.Infof("Command Monitor v%s 启动中...", Version)
	app.logger.Info(cfg.String())

	// 3. 初始化存储
	if err := app.initializeStorage(); err != nil {
		return fmt.Errorf("初始化存储失败: %v", err)
	}

	// 4. 初始化通知器
	if err := app.initializeNotifier(); err != nil {
		return fmt.Errorf("初始化通知器失败: %v", err)
	}

	// 5. 初始化监控组件
	if err := app.initializeMonitoring(); err != nil {
		return fmt.Errorf("初始化监控组件失败: %v", err)
	}

	app.logger.Info("应用初始化完成")
	return nil
}

// initializeLogger 初始化日志
func (app *Application) initializeLogger() error {
	logger := logrus.New()

	// 设置日志级别
	logger.SetLevel(app.config.GetLogLevel())

	// 设置日志格式
	logger.SetFormatter(&logrus.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2006-01-02 15:04:05",
	})

	// 设置日志输出
	if app.config.LogPath != "" && app.config.LogPath != "/dev/stdout" {
		logFile, err := os.OpenFile(app.config.LogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
		if err != nil {
			return fmt.Errorf("打开日志文件失败: %v", err)
		}
		logger.SetOutput(logFile)
	}

	app.logger = logger
	return nil
}

// initializeStorage 初始化存储
func (app *Application) initializeStorage() error {
	jsonStorage := storage.NewJSONStorage(app.logger, app.config.StoragePath)

	if err := jsonStorage.Initialize(); err != nil {
		return err
	}

	app.storage = jsonStorage
	return nil
}

// initializeNotifier 初始化通知器
func (app *Application) initializeNotifier() error {
	emailConfig := notification.EmailConfig{
		SMTPHost:     app.config.EmailSMTPHost,
		SMTPPort:     app.config.EmailSMTPPort,
		Username:     app.config.EmailUsername,
		Password:     app.config.EmailPassword,
		FromEmail:    app.config.EmailFromAddress,
		DefaultEmail: app.config.EmailDefaultTo,
	}

	emailNotifier := notification.NewEmailNotifier(app.logger, emailConfig)

	app.notifier = emailNotifier
	return nil
}

// initializeMonitoring 初始化监控组件
func (app *Application) initializeMonitoring() error {
	// 创建进程扫描器（精准监控模式）
	processScanner := monitor.NewProcessScanner(
		app.logger,
		app.config.MonitorThresholdMinutes,
	)
	app.processScanner = processScanner

	// 创建监控管理器（支持Docker容器监控）
	monitorManager := monitor.NewMonitorManager(
		app.logger,
		processScanner,
		app.config.ScanIntervalSeconds,
		app.config.MaxMonitoredProcesses,
	)

	// 设置进程完成回调
	monitorManager.SetProcessCompletedCallback(app.onProcessCompleted)

	app.monitorManager = monitorManager
	return nil
}

// onProcessCompleted 进程完成回调
func (app *Application) onProcessCompleted(process *utils.MonitoredProcess) {
	app.logger.Infof("进程完成: %s (PID=%d, 时长=%s)",
		process.Info.Command, process.Info.PID, process.Duration)

	// 更新存储
	if err := app.storage.UpdateMonitoredProcess(process); err != nil {
		app.logger.Errorf("更新进程存储失败: %v", err)
	}

	// 发送通知
	if err := app.notifier.SendProcessCompleted(process); err != nil {
		app.logger.Errorf("发送完成通知失败: %v", err)
	}
}

// run 运行应用
func (app *Application) run() error {
	// 创建上下文
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 启动监控管理器
	if err := app.monitorManager.Start(ctx); err != nil {
		return fmt.Errorf("启动监控管理器失败: %v", err)
	}

	// 设置信号处理
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	app.logger.Info("Command Monitor 服务已启动，按 Ctrl+C 停止")

	// 启动定期清理任务
	go app.startCleanupTask(ctx)

	// 等待信号
	<-sigChan
	app.logger.Info("收到停止信号，正在关闭服务...")

	// 优雅关闭
	return app.shutdown()
}

// startCleanupTask 启动定期清理任务
func (app *Application) startCleanupTask(ctx context.Context) {
	ticker := time.NewTicker(24 * time.Hour) // 每天清理一次
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			app.performCleanup()
		}
	}
}

// performCleanup 执行清理任务
func (app *Application) performCleanup() {
	app.logger.Info("开始执行定期清理任务")

	// 清理7天前的已完成进程记录
	cutoffTime := time.Now().Add(-7 * 24 * time.Hour)

	if err := app.storage.CleanupOldRecords(cutoffTime); err != nil {
		app.logger.Errorf("清理旧记录失败: %v", err)
	}

	// 获取统计信息
	if stats, err := app.storage.GetStatistics(); err == nil {
		app.logger.Infof("存储统计: 总计=%d, 运行中=%d, 已完成=%d, 失败=%d",
			stats.TotalProcesses, stats.RunningProcesses,
			stats.CompletedProcesses, stats.FailedProcesses)
	}

	app.logger.Info("定期清理任务完成")
}

// shutdown 优雅关闭
func (app *Application) shutdown() error {
	app.logger.Info("开始优雅关闭...")

	// 停止监控管理器
	if app.monitorManager != nil {
		app.monitorManager.Stop()
	}

	// 关闭通知器
	if app.notifier != nil {
		if err := app.notifier.Close(); err != nil {
			app.logger.Errorf("关闭通知器失败: %v", err)
		}
	}

	// 关闭存储
	if app.storage != nil {
		if err := app.storage.Close(); err != nil {
			app.logger.Errorf("关闭存储失败: %v", err)
		}
	}

	app.logger.Info("服务已关闭")
	return nil
}
