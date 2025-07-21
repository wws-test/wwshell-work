package monitor

import (
	"cmdmonitor/pkg/utils"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

// ProcessScanner 精准监控进程扫描器
type ProcessScanner struct {
	logger            *logrus.Logger
	thresholdDuration time.Duration
}

// NewProcessScanner 创建新的精准监控进程扫描器
func NewProcessScanner(logger *logrus.Logger, thresholdMinutes int) *ProcessScanner {
	return &ProcessScanner{
		logger:            logger,
		thresholdDuration: time.Duration(thresholdMinutes) * time.Minute,
	}
}

// ScanProcesses 扫描所有符合条件的进程
func (ps *ProcessScanner) ScanProcesses() ([]utils.ProcessInfo, error) {
	ps.logger.Debug("开始扫描进程...")

	var processes []utils.ProcessInfo

	// 遍历/proc目录
	err := filepath.WalkDir("/proc", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // 忽略错误，继续扫描
		}

		// 只处理数字目录（PID目录）
		if !d.IsDir() || !isPIDDir(d.Name()) {
			return nil
		}

		pid, err := strconv.Atoi(d.Name())
		if err != nil {
			return nil
		}

		// 获取进程信息
		procInfo, err := ps.getProcessInfo(pid)
		if err != nil {
			ps.logger.Debugf("获取进程信息失败 PID=%d: %v", pid, err)
			return nil
		}

		// 检查是否符合监控条件
		if ps.shouldMonitor(procInfo) {
			processes = append(processes, *procInfo)
		}

		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("扫描/proc目录失败: %v", err)
	}

	ps.logger.Infof("扫描完成，发现 %d 个符合条件的进程", len(processes))
	return processes, nil
}

// getProcessInfo 获取指定PID的进程信息
func (ps *ProcessScanner) getProcessInfo(pid int) (*utils.ProcessInfo, error) {
	// 检查进程是否存在
	if !utils.IsProcessRunning(pid) {
		return nil, fmt.Errorf("进程 %d 不存在", pid)
	}

	// 获取命令行
	command, args, err := utils.GetProcessCmdline(pid)
	if err != nil {
		return nil, fmt.Errorf("获取命令行失败: %v", err)
	}

	// 获取进程状态和用户
	status, user, err := utils.GetProcessStatus(pid)
	if err != nil {
		return nil, fmt.Errorf("获取进程状态失败: %v", err)
	}

	// 获取启动时间
	startTime, err := utils.GetProcessStartTime(pid)
	if err != nil {
		return nil, fmt.Errorf("获取启动时间失败: %v", err)
	}

	// 获取内存使用
	memoryUsage, err := utils.GetProcessMemoryUsage(pid)
	if err != nil {
		ps.logger.Debugf("获取内存使用失败 PID=%d: %v", pid, err)
		memoryUsage = 0
	}

	// 获取CPU时间
	cpuTime, err := utils.GetProcessCPUTime(pid)
	if err != nil {
		ps.logger.Debugf("获取CPU时间失败 PID=%d: %v", pid, err)
		cpuTime = 0
	}

	// 获取工作目录
	workingDir := ps.getWorkingDirectory(pid)

	// 获取父进程ID
	ppid := ps.getParentPID(pid)

	// 构建完整的命令行用于显示名称提取
	fullCommand := command
	if len(args) > 0 {
		fullCommand = command + " " + strings.Join(args, " ")
	}

	return &utils.ProcessInfo{
		PID:         pid,
		PPID:        ppid,
		Command:     ps.extractDisplayName(fullCommand), // 提取更友好的显示名称
		Args:        args,
		StartTime:   startTime,
		User:        user,
		WorkingDir:  workingDir,
		Status:      status,
		CPUTime:     cpuTime,
		MemoryUsage: memoryUsage,
	}, nil
}

// shouldMonitor 判断是否应该监控该进程
func (ps *ProcessScanner) shouldMonitor(procInfo *utils.ProcessInfo) bool {
	return ps.shouldMonitorWithContext(procInfo, false)
}

// shouldMonitorWithContext 判断是否应该监控该进程（带上下文）
func (ps *ProcessScanner) shouldMonitorWithContext(procInfo *utils.ProcessInfo, isContainer bool) bool {
	return ps.shouldMonitorWithContextAndContainer(procInfo, isContainer, "")
}

// shouldMonitorWithContextAndContainer 判断是否应该监控该进程（带容器上下文）
func (ps *ProcessScanner) shouldMonitorWithContextAndContainer(procInfo *utils.ProcessInfo, isContainer bool, containerID string) bool {
	runningTime := time.Since(procInfo.StartTime)
	commandName := filepath.Base(procInfo.Command)
	fullCommand := procInfo.Command
	if len(procInfo.Args) > 0 {
		fullCommand = procInfo.Command + " " + strings.Join(procInfo.Args, " ")
	}

	// 精准监控：检查是否有监控标记
	var hasTag bool
	if isContainer && containerID != "" {
		// 容器内进程使用增强的检测逻辑
		hasTag = ps.shouldMonitorByPreciseRulesInContainer(containerID, fullCommand, procInfo.PID)
	} else {
		// 主机进程使用标准检测逻辑
		hasTag = ps.shouldMonitorByPreciseRules(fullCommand, procInfo.PID)
	}

	if !hasTag {
		ps.logger.Debugf("进程不匹配精准监控规则: %s (PID=%d)", fullCommand, procInfo.PID)
		return false
	}

	// 精准监控模式：不检查运行时间阈值，只要有标记就监控
	// 注释掉运行时间检查，因为精准监控应该立即监控有标记的进程
	/*
		if runningTime < ps.thresholdDuration {
			ps.logger.Debugf("进程运行时间不足: %s (PID=%d, 运行时间=%s)",
				commandName, procInfo.PID, utils.FormatDuration(runningTime))
			return false
		}
	*/

	// 过滤掉自身进程（cmdmonitor）
	if strings.Contains(commandName, "cmdmonitor") {
		ps.logger.Debugf("忽略自身进程: %s (PID=%d)", commandName, procInfo.PID)
		return false
	}

	ps.logger.Debugf("发现符合精准监控条件的进程: %s (PID=%d, 运行时间=%s)",
		commandName, procInfo.PID, utils.FormatDuration(runningTime))

	return true
}

// isSystemProcess 判断是否为系统进程
func (ps *ProcessScanner) isSystemProcess(commandName string) bool {
	systemProcesses := []string{
		"systemd", "kthreadd", "ksoftirqd", "migration", "rcu_gp", "rcu_par_gp",
		"kworker", "mm_percpu_wq", "ksoftirqd", "migration", "rcu_", "watchdog",
		"systemd-", "dbus", "NetworkManager", "sshd", "chronyd", "rsyslog",
		"kernel", "init", "swapper", "idle", "irq", "softirq",
	}

	for _, sysProc := range systemProcesses {
		if strings.Contains(commandName, sysProc) {
			return true
		}
	}

	return false
}

// isLongRunningService 判断是否为长期运行的服务进程
func (ps *ProcessScanner) isLongRunningService(commandName string) bool {
	longRunningServices := []string{
		// 数据库服务
		"mysqld", "postgres", "mongod", "redis-server", "memcached",
		// Web服务器
		"nginx", "apache2", "httpd", "lighttpd",
		// 应用服务器
		"java", "node", "python", "python3", "gunicorn", "uwsgi",
		// 系统服务
		"cron", "crond", "atd", "ntpd", "chronyd",
		// 网络服务
		"sshd", "vsftpd", "proftpd", "named", "bind9",
		// 监控和日志
		"rsyslog", "syslog-ng", "collectd", "telegraf", "prometheus",
		// 容器和虚拟化
		"dockerd", "containerd", "kubelet", "kvm", "qemu",
		// 文件系统和存储
		"nfsd", "rpc.mountd", "rpc.statd", "smbd", "nmbd",
		// 其他常见服务
		"postfix", "sendmail", "dovecot", "cups", "avahi-daemon",
	}

	for _, service := range longRunningServices {
		if strings.Contains(commandName, service) {
			return true
		}
	}

	return false
}

// isLongRunningServiceForContext 根据上下文判断是否为长期运行的服务进程
func (ps *ProcessScanner) isLongRunningServiceForContext(commandName string, isContainer bool) bool {
	// 对于容器内的进程，使用更宽松的策略
	if isContainer {
		// 容器内只过滤明显的系统服务，允许应用程序运行
		containerSystemServices := []string{
			// 只过滤明显的系统服务
			"systemd", "init", "dbus", "cron", "crond",
			// 网络服务
			"sshd", "vsftpd", "proftpd", "named", "bind9",
			// 日志服务
			"rsyslog", "syslog-ng",
		}

		for _, service := range containerSystemServices {
			if strings.Contains(commandName, service) {
				return true
			}
		}
		return false
	}

	// 主机进程使用原来的严格策略
	return ps.isLongRunningService(commandName)
}

// isInteractiveOrMeaninglessCommand 判断是否为交互式或无意义的命令
func (ps *ProcessScanner) isInteractiveOrMeaninglessCommand(fullCommand, commandName string) bool {
	// 交互式shell命令
	interactiveCommands := []string{
		"bash", "sh", "zsh", "fish", "csh", "tcsh", "ksh",
		"-bash", "-sh", "-zsh", "-fish", "-csh", "-tcsh", "-ksh",
	}

	// 检查是否为纯shell命令
	for _, cmd := range interactiveCommands {
		if commandName == cmd {
			return true
		}
	}

	// Docker相关的交互式命令
	if strings.Contains(fullCommand, "docker exec") && strings.Contains(fullCommand, "-it") {
		return true
	}

	// 其他容器相关的交互式命令
	if strings.Contains(fullCommand, "kubectl exec") && strings.Contains(fullCommand, "-it") {
		return true
	}

	// SSH相关的交互式命令
	if strings.Contains(fullCommand, "ssh") && !strings.Contains(fullCommand, "sshd") {
		return true
	}

	// 编辑器命令（通常是交互式的）
	editors := []string{"vim", "vi", "nano", "emacs", "gedit", "code"}
	for _, editor := range editors {
		if commandName == editor {
			return true
		}
	}

	// 其他交互式工具
	interactiveTools := []string{
		"top", "htop", "less", "more", "tail", "watch",
		"tmux", "screen", "mc", "ranger",
	}
	for _, tool := range interactiveTools {
		if commandName == tool {
			return true
		}
	}

	return false
}

// getWorkingDirectory 获取进程工作目录
func (ps *ProcessScanner) getWorkingDirectory(pid int) string {
	cwdPath := fmt.Sprintf("/proc/%d/cwd", pid)
	workingDir, err := os.Readlink(cwdPath)
	if err != nil {
		ps.logger.Debugf("获取工作目录失败 PID=%d: %v", pid, err)
		return ""
	}
	return workingDir
}

// getParentPID 获取父进程ID
func (ps *ProcessScanner) getParentPID(pid int) int {
	statPath := fmt.Sprintf("/proc/%d/stat", pid)
	data, err := os.ReadFile(statPath)
	if err != nil {
		return 0
	}

	fields := strings.Fields(string(data))
	if len(fields) < 4 {
		return 0
	}

	ppid, err := strconv.Atoi(fields[3])
	if err != nil {
		return 0
	}

	return ppid
}

// isPIDDir 判断目录名是否为PID（纯数字）
func isPIDDir(name string) bool {
	_, err := strconv.Atoi(name)
	return err == nil
}

// GetRunningTime 获取进程运行时间
func (ps *ProcessScanner) GetRunningTime(procInfo *utils.ProcessInfo) time.Duration {
	return time.Since(procInfo.StartTime)
}

// RefreshProcessInfo 刷新进程信息
func (ps *ProcessScanner) RefreshProcessInfo(pid int) (*utils.ProcessInfo, error) {
	return ps.getProcessInfo(pid)
}

// ScanDockerContainerProcesses 扫描Docker容器内的进程
func (ps *ProcessScanner) ScanDockerContainerProcesses(containerID string) ([]utils.ProcessInfo, error) {
	ps.logger.Debugf("开始扫描容器 %s 内的进程...", containerID)

	var processes []utils.ProcessInfo

	// 获取容器内的进程列表
	containerProcesses, err := ps.getContainerProcesses(containerID)
	if err != nil {
		return nil, fmt.Errorf("获取容器进程失败: %v", err)
	}

	for _, procInfo := range containerProcesses {
		// 检查是否符合监控条件（容器内进程使用增强检测）
		if ps.shouldMonitorWithContextAndContainer(&procInfo, true, containerID) {
			processes = append(processes, procInfo)
		}
	}

	// 额外检查动态标记的进程（即使不在容器进程列表中）
	ps.checkDynamicTaggedProcessesInContainer(containerID, &processes)

	ps.logger.Infof("容器 %s 扫描完成，发现 %d 个符合条件的进程", containerID, len(processes))
	return processes, nil
}

// getContainerProcesses 获取容器内的进程信息
func (ps *ProcessScanner) getContainerProcesses(containerID string) ([]utils.ProcessInfo, error) {
	// 使用docker exec获取容器内进程信息
	// 这里我们通过查找容器的PID namespace来获取进程

	// 首先获取容器的主进程PID
	containerPID, err := ps.getContainerMainPID(containerID)
	if err != nil {
		return nil, fmt.Errorf("获取容器主进程PID失败: %v", err)
	}

	// 获取容器的PID namespace
	containerNS, err := ps.getProcessNamespace(containerPID, "pid")
	if err != nil {
		return nil, fmt.Errorf("获取容器PID namespace失败: %v", err)
	}

	var processes []utils.ProcessInfo

	// 遍历/proc目录，查找属于同一PID namespace的进程
	err = filepath.WalkDir("/proc", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // 忽略错误，继续扫描
		}

		// 只处理数字目录（PID目录）
		if !d.IsDir() || !isPIDDir(d.Name()) {
			return nil
		}

		pid, err := strconv.Atoi(d.Name())
		if err != nil {
			return nil
		}

		// 检查进程的PID namespace是否与容器相同
		procNS, err := ps.getProcessNamespace(pid, "pid")
		if err != nil {
			return nil // 忽略错误
		}

		if procNS == containerNS {
			// 获取进程信息
			procInfo, err := ps.getProcessInfo(pid)
			if err != nil {
				ps.logger.Debugf("获取容器进程信息失败 PID=%d: %v", pid, err)
				return nil
			}

			processes = append(processes, *procInfo)
		}

		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("扫描容器进程失败: %v", err)
	}

	return processes, nil
}

// getContainerMainPID 获取容器的主进程PID
func (ps *ProcessScanner) getContainerMainPID(containerID string) (int, error) {
	// 使用docker inspect获取容器的主进程PID
	cmd := fmt.Sprintf("docker inspect -f '{{.State.Pid}}' %s", containerID)
	output, err := ps.executeCommand(cmd)
	if err != nil {
		return 0, fmt.Errorf("执行docker inspect失败: %v", err)
	}

	pidStr := strings.TrimSpace(output)
	// 移除可能的单引号
	pidStr = strings.Trim(pidStr, "'\"")

	pid, err := strconv.Atoi(pidStr)
	if err != nil {
		return 0, fmt.Errorf("解析PID失败: %v (原始输出: %s)", err, output)
	}

	return pid, nil
}

// getProcessNamespace 获取进程的指定namespace
func (ps *ProcessScanner) getProcessNamespace(pid int, nsType string) (string, error) {
	nsPath := fmt.Sprintf("/proc/%d/ns/%s", pid, nsType)
	nsLink, err := os.Readlink(nsPath)
	if err != nil {
		return "", fmt.Errorf("读取namespace链接失败: %v", err)
	}
	return nsLink, nil
}

// executeCommand 执行系统命令
func (ps *ProcessScanner) executeCommand(cmd string) (string, error) {
	parts := strings.Fields(cmd)
	if len(parts) == 0 {
		return "", fmt.Errorf("空命令")
	}

	var execCmd *exec.Cmd
	if len(parts) == 1 {
		execCmd = exec.Command(parts[0])
	} else {
		execCmd = exec.Command(parts[0], parts[1:]...)
	}

	output, err := execCmd.Output()
	if err != nil {
		return "", fmt.Errorf("命令执行失败: %v", err)
	}

	return string(output), nil
}

// shouldMonitorByPreciseRules 检查是否符合精准监控规则
func (ps *ProcessScanner) shouldMonitorByPreciseRules(fullCommand string, pid int) bool {
	// 检查注释标记
	if ps.hasCommentTag(fullCommand) {
		ps.logger.Debugf("发现注释标记: %s (PID=%d)", fullCommand, pid)
		return true
	}

	// 检查动态标记文件
	if ps.hasDynamicTag(pid) {
		ps.logger.Debugf("发现动态标记: %s (PID=%d)", fullCommand, pid)
		return true
	}

	return false
}

// shouldMonitorByPreciseRulesInContainer 检查容器内进程是否符合精准监控规则
func (ps *ProcessScanner) shouldMonitorByPreciseRulesInContainer(containerID string, fullCommand string, pid int) bool {
	// 检查动态标记文件
	if ps.hasDynamicTag(pid) {
		ps.logger.Debugf("发现动态标记: %s (PID=%d)", fullCommand, pid)
		return true
	}

	// 检查注释标记（包括父进程和完整命令行）
	if ps.hasCommentTagInContainer(containerID, pid, fullCommand) {
		ps.logger.Debugf("发现注释标记: %s (PID=%d)", fullCommand, pid)
		return true
	}

	return false
}

// hasCommentTag 检查命令是否有监控注释标记
func (ps *ProcessScanner) hasCommentTag(fullCommand string) bool {
	// 支持多种注释标记格式：
	// # MONITOR:tag
	// # CMDMONITOR:tag
	// # TRACK:tag
	commentPatterns := []string{
		`#\s*MONITOR:`,
		`#\s*CMDMONITOR:`,
		`#\s*TRACK:`,
	}

	for _, pattern := range commentPatterns {
		if matched, _ := regexp.MatchString(pattern, fullCommand); matched {
			return true
		}
	}

	return false
}

// hasCommentTagInContainer 检查容器内进程是否有注释标记（包括检查父进程和脚本文件）
func (ps *ProcessScanner) hasCommentTagInContainer(containerID string, pid int, fullCommand string) bool {
	// 首先检查当前进程命令
	if ps.hasCommentTag(fullCommand) {
		return true
	}

	// 检查进程的完整命令行参数（使用增强的获取方法）
	fullCmdline := ps.getProcessCmdline(containerID, pid)
	if fullCmdline != "" && ps.hasCommentTag(fullCmdline) {
		ps.logger.Debugf("在完整命令行中发现注释标记: %s (PID=%d)", fullCmdline, pid)
		return true
	}

	// 检查父进程的命令行（可能包含完整的命令和注释）
	parentCmd := ps.getParentProcessCommand(containerID, pid)
	if parentCmd != "" && ps.hasCommentTag(parentCmd) {
		ps.logger.Debugf("在父进程中发现注释标记: %s (PID=%d)", parentCmd, pid)
		return true
	}

	// 检查父进程的完整命令行（递归检查）
	parentPID := ps.getContainerParentPID(containerID, pid)
	if parentPID > 1 {
		parentFullCmdline := ps.getProcessCmdline(containerID, parentPID)
		if parentFullCmdline != "" && ps.hasCommentTag(parentFullCmdline) {
			ps.logger.Debugf("在父进程完整命令行中发现注释标记: %s (PID=%d, ParentPID=%d)", parentFullCmdline, pid, parentPID)
			return true
		}
	}

	// 检查脚本文件内容（如果进程是通过脚本启动的）
	if ps.checkScriptFileForCommentTag(containerID, pid, fullCommand) {
		ps.logger.Debugf("在脚本文件中发现注释标记: %s (PID=%d)", fullCommand, pid)
		return true
	}

	// 检查父进程的脚本文件内容
	if parentCmd != "" && ps.checkScriptFileForCommentTag(containerID, pid, parentCmd) {
		ps.logger.Debugf("在父进程脚本文件中发现注释标记: %s (PID=%d)", parentCmd, pid)
		return true
	}

	return false
}

// checkScriptFileForCommentTag 检查脚本文件是否包含注释标记
func (ps *ProcessScanner) checkScriptFileForCommentTag(containerID string, pid int, command string) bool {
	// 检查命令是否指向脚本文件
	scriptPath := ps.extractScriptPath(command)
	if scriptPath == "" {
		return false
	}

	// 读取脚本文件内容
	scriptContent := ps.getScriptFileContent(containerID, scriptPath)
	if scriptContent == "" {
		return false
	}

	// 检查脚本内容是否包含注释标记
	return ps.hasCommentTag(scriptContent)
}

// extractScriptPath 从命令中提取脚本文件路径
func (ps *ProcessScanner) extractScriptPath(command string) string {
	// 处理常见的脚本执行模式
	patterns := []string{
		// bash script.sh, sh script.sh, /bin/bash script.sh
		`(?:^|.*\s)(?:/bin/)?(?:bash|sh)\s+([^\s]+\.sh)(?:\s|$)`,
		// python script.py, /usr/bin/python script.py
		`(?:^|.*\s)(?:/usr/bin/)?python[0-9]*\s+([^\s]+\.py)(?:\s|$)`,
		// 直接执行的脚本文件 ./script.sh, /path/to/script.sh
		`(?:^|.*\s)(\./[^\s]+\.sh|/[^\s]+\.sh)(?:\s|$)`,
	}

	for _, pattern := range patterns {
		if matched, _ := regexp.MatchString(pattern, command); matched {
			re := regexp.MustCompile(pattern)
			matches := re.FindStringSubmatch(command)
			if len(matches) > 1 {
				return matches[1]
			}
		}
	}

	return ""
}

// getScriptFileContent 获取容器内脚本文件的内容
func (ps *ProcessScanner) getScriptFileContent(containerID string, scriptPath string) string {
	// 使用docker exec读取文件内容，避免shell重定向问题
	cmd := fmt.Sprintf("docker exec %s cat %s", containerID, scriptPath)
	output, err := ps.executeCommand(cmd)
	if err != nil {
		ps.logger.Debugf("无法读取脚本文件 %s: %v", scriptPath, err)
		return ""
	}

	return strings.TrimSpace(output)
}

// getParentProcessCommand 获取父进程的命令
func (ps *ProcessScanner) getParentProcessCommand(containerID string, pid int) string {
	// 获取父进程PID
	cmd := fmt.Sprintf("docker exec %s ps -p %d -o ppid --no-headers", containerID, pid)
	output, err := ps.executeCommand(cmd)
	if err != nil {
		return ""
	}

	ppidStr := strings.TrimSpace(output)
	ppid, err := strconv.Atoi(ppidStr)
	if err != nil || ppid <= 1 {
		return ""
	}

	// 获取父进程的命令
	parentCmd := fmt.Sprintf("docker exec %s ps -p %d -o cmd --no-headers", containerID, ppid)
	parentOutput, err := ps.executeCommand(parentCmd)
	if err != nil {
		return ""
	}

	return strings.TrimSpace(parentOutput)
}

// getProcessCmdline 获取进程的完整命令行
func (ps *ProcessScanner) getProcessCmdline(containerID string, pid int) string {
	// 方法1: 尝试从 /proc/PID/cmdline 读取完整命令行
	cmd := fmt.Sprintf("docker exec %s cat /proc/%d/cmdline", containerID, pid)
	output, err := ps.executeCommand(cmd)
	if err == nil && strings.TrimSpace(output) != "" {
		// 将null字符替换为空格
		cmdline := strings.ReplaceAll(strings.TrimSpace(output), "\x00", " ")
		if cmdline != "" {
			return cmdline
		}
	}

	// 方法2: 使用ps命令获取更完整的命令行信息
	psCmd := fmt.Sprintf("docker exec %s ps -p %d -o args --no-headers", containerID, pid)
	psOutput, err := ps.executeCommand(psCmd)
	if err == nil && strings.TrimSpace(psOutput) != "" {
		return strings.TrimSpace(psOutput)
	}

	return ""
}

// getContainerParentPID 获取容器内进程的父进程PID
func (ps *ProcessScanner) getContainerParentPID(containerID string, pid int) int {
	// 使用ps命令获取父进程PID
	cmd := fmt.Sprintf("docker exec %s ps -p %d -o ppid --no-headers", containerID, pid)
	output, err := ps.executeCommand(cmd)
	if err != nil {
		return 0
	}

	ppidStr := strings.TrimSpace(output)
	ppid, err := strconv.Atoi(ppidStr)
	if err != nil {
		return 0
	}

	return ppid
}

// hasDynamicTag 检查进程是否有动态标记
func (ps *ProcessScanner) hasDynamicTag(pid int) bool {
	dynamicTagFile := "/etc/cmdmonitor/dynamic_tags.txt"

	// 检查文件是否存在
	if _, err := os.Stat(dynamicTagFile); os.IsNotExist(err) {
		return false
	}

	// 读取文件内容
	content, err := os.ReadFile(dynamicTagFile)
	if err != nil {
		ps.logger.Debugf("无法读取动态标记文件: %v", err)
		return false
	}

	// 逐行扫描查找PID或脚本名
	lines := strings.Split(string(content), "\n")
	targetPID := fmt.Sprintf("%d", pid)

	for _, line := range lines {
		line = strings.TrimSpace(line)
		// 跳过空行和注释行
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// 格式1：直接匹配PID数字
		if line == targetPID {
			ps.logger.Debugf("找到动态标记: PID=%d", pid)

			// 验证PID是否真实存在（优先检查Docker容器）
			if ps.verifyPIDExists(pid) {
				return true
			} else {
				ps.logger.Debugf("动态标记的PID %d 不存在，跳过", pid)
			}
		} else {
			// 格式2：脚本名格式，需要检查当前PID是否匹配该脚本
			if _, err := strconv.Atoi(line); err != nil {
				// 这是一个脚本名，检查当前PID是否运行该脚本
				if ps.pidMatchesScriptName(pid, line) {
					ps.logger.Debugf("找到动态标记脚本: PID=%d, 脚本=%s", pid, line)
					return true
				}
			}
		}
	}

	return false
}

// pidMatchesScriptName 检查指定PID是否运行指定的脚本
func (ps *ProcessScanner) pidMatchesScriptName(pid int, scriptName string) bool {
	// 1. 先检查Docker容器中的进程
	containers, err := ps.getRunningContainers()
	if err == nil {
		for _, containerID := range containers {
			if ps.pidExistsInContainer(containerID, pid) {
				// 获取容器中该PID的命令
				if command := ps.getContainerProcessCommand(containerID, pid); command != "" {
					if ps.commandMatchesScriptName(command, scriptName) {
						ps.logger.Debugf("容器中PID %d 匹配脚本 %s: %s", pid, scriptName, command)
						return true
					}
				}
				return false // 找到PID但不匹配脚本
			}
		}
	}

	// 2. 检查主机上的进程
	if ps.pidExistsOnHost(pid) {
		// 获取主机上该PID的命令
		if command := ps.getHostProcessCommand(pid); command != "" {
			if ps.commandMatchesScriptName(command, scriptName) {
				ps.logger.Debugf("主机上PID %d 匹配脚本 %s: %s", pid, scriptName, command)
				return true
			}
		}
	}

	return false
}

// getContainerProcessCommand 获取容器中指定PID的命令
func (ps *ProcessScanner) getContainerProcessCommand(containerID string, pid int) string {
	cmd := fmt.Sprintf("docker exec %s ps -p %d -o cmd --no-headers", containerID, pid)
	output, err := ps.executeCommand(cmd)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(output)
}

// getHostProcessCommand 获取主机上指定PID的命令
func (ps *ProcessScanner) getHostProcessCommand(pid int) string {
	// 尝试从 /proc/PID/cmdline 读取
	cmdlinePath := fmt.Sprintf("/proc/%d/cmdline", pid)
	if content, err := os.ReadFile(cmdlinePath); err == nil {
		// 将null字符替换为空格
		command := strings.ReplaceAll(string(content), "\x00", " ")
		return strings.TrimSpace(command)
	}

	// 备用方法：使用ps命令
	cmd := fmt.Sprintf("ps -p %d -o cmd --no-headers", pid)
	output, err := ps.executeCommand(cmd)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(output)
}

// verifyPIDExists 验证PID是否存在（优先Docker容器，然后本地）
func (ps *ProcessScanner) verifyPIDExists(pid int) bool {
	// 1. 优先检查Docker容器中的PID
	containers, err := ps.getRunningContainers()
	if err == nil {
		for _, containerID := range containers {
			if ps.pidExistsInContainer(containerID, pid) {
				ps.logger.Debugf("PID %d 存在于容器 %s 中", pid, containerID)
				return true
			}
		}
	}

	// 2. 检查本地主机PID
	if ps.pidExistsOnHost(pid) {
		ps.logger.Debugf("PID %d 存在于主机上", pid)
		return true
	}

	return false
}

// pidExistsInContainer 检查PID是否存在于指定容器中
func (ps *ProcessScanner) pidExistsInContainer(containerID string, pid int) bool {
	cmd := fmt.Sprintf("docker exec %s ps -p %d -o pid", containerID, pid)
	output, err := ps.executeCommand(cmd)
	if err != nil {
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

// pidExistsOnHost 检查PID是否存在于主机上
func (ps *ProcessScanner) pidExistsOnHost(pid int) bool {
	_, err := os.Stat(fmt.Sprintf("/proc/%d", pid))
	return err == nil
}

// getRunningContainers 获取运行中的容器列表
func (ps *ProcessScanner) getRunningContainers() ([]string, error) {
	cmd := "docker ps -q"
	output, err := ps.executeCommand(cmd)
	if err != nil {
		return nil, fmt.Errorf("执行docker ps失败: %v", err)
	}

	containerIDs := strings.Fields(strings.TrimSpace(output))
	return containerIDs, nil
}

// checkDynamicTaggedProcessesInContainer 检查容器中动态标记的进程
func (ps *ProcessScanner) checkDynamicTaggedProcessesInContainer(containerID string, processes *[]utils.ProcessInfo) {
	dynamicTagFile := "/etc/cmdmonitor/dynamic_tags.txt"

	// 检查文件是否存在
	if _, err := os.Stat(dynamicTagFile); os.IsNotExist(err) {
		return
	}

	// 读取文件内容
	content, err := os.ReadFile(dynamicTagFile)
	if err != nil {
		ps.logger.Debugf("无法读取动态标记文件: %v", err)
		return
	}

	// 逐行扫描查找PID
	lines := strings.Split(string(content), "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		// 跳过空行和注释行
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// 尝试解析为PID数字
		if pid, err := strconv.Atoi(line); err == nil {
			// PID格式：直接检查PID
			if ps.pidExistsInContainer(containerID, pid) {
				ps.logger.Debugf("在容器 %s 中找到动态标记进程: PID=%d", containerID, pid)

				// 检查是否已经在列表中（避免重复添加）
				found := false
				for _, existing := range *processes {
					if existing.PID == pid {
						found = true
						ps.logger.Debugf("动态标记进程 PID=%d 已在扫描列表中", pid)
						break
					}
				}

				if !found {
					// 获取进程信息并添加到监控列表
					if procInfo := ps.getContainerProcessInfo(containerID, pid); procInfo != nil {
						*processes = append(*processes, *procInfo)
						ps.logger.Infof("发现动态标记进程: %s (PID=%d)", procInfo.Command, pid)
					}
				}
			}
		} else {
			// 脚本名格式：根据名字搜索进程
			ps.logger.Debugf("搜索容器 %s 中的脚本: %s", containerID, line)
			matchedPIDs := ps.findProcessesByScriptName(containerID, line)

			for _, pid := range matchedPIDs {
				// 检查是否已经在列表中（避免重复添加）
				found := false
				for _, existing := range *processes {
					if existing.PID == pid {
						found = true
						ps.logger.Debugf("脚本进程 PID=%d 已在扫描列表中", pid)
						break
					}
				}

				if !found {
					// 获取进程信息并添加到监控列表
					if procInfo := ps.getContainerProcessInfo(containerID, pid); procInfo != nil {
						*processes = append(*processes, *procInfo)
						ps.logger.Infof("发现动态标记脚本进程: %s (PID=%d, 脚本=%s)", procInfo.Command, pid, line)
					}
				}
			}
		}
	}
}

// findProcessesByScriptName 根据脚本名在容器中查找匹配的进程PID
func (ps *ProcessScanner) findProcessesByScriptName(containerID string, scriptName string) []int {
	var matchedPIDs []int

	// 使用docker exec获取容器内所有进程
	cmd := fmt.Sprintf("docker exec %s ps aux", containerID)
	output, err := ps.executeCommand(cmd)
	if err != nil {
		ps.logger.Debugf("获取容器进程列表失败: %v", err)
		return matchedPIDs
	}

	lines := strings.Split(output, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "USER") {
			continue // 跳过空行和标题行
		}

		// 解析进程行：USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
		fields := strings.Fields(line)
		if len(fields) < 11 {
			continue
		}

		pidStr := fields[1]
		pid, err := strconv.Atoi(pidStr)
		if err != nil {
			continue
		}

		// 获取完整的命令行（从第11个字段开始）
		command := strings.Join(fields[10:], " ")

		// 检查命令是否包含脚本名
		if ps.commandMatchesScriptName(command, scriptName) {
			ps.logger.Debugf("找到匹配脚本 %s 的进程: PID=%d, Command=%s", scriptName, pid, command)
			matchedPIDs = append(matchedPIDs, pid)
		}
	}

	return matchedPIDs
}

// commandMatchesScriptName 检查命令是否匹配脚本名
func (ps *ProcessScanner) commandMatchesScriptName(command string, scriptName string) bool {
	// 1. 直接包含脚本名
	if strings.Contains(command, scriptName) {
		return true
	}

	// 2. 检查路径中的脚本名（如 /path/to/script.sh）
	if strings.Contains(command, "/"+scriptName) {
		return true
	}

	// 3. 检查以脚本名开头的情况
	if strings.HasPrefix(command, scriptName+" ") || command == scriptName {
		return true
	}

	// 4. 检查常见的脚本执行模式
	patterns := []string{
		"bash " + scriptName,
		"sh " + scriptName,
		"/bin/bash " + scriptName,
		"/bin/sh " + scriptName,
		"python " + scriptName,
		"python3 " + scriptName,
		"/usr/bin/python " + scriptName,
		"/usr/bin/python3 " + scriptName,
	}

	for _, pattern := range patterns {
		if strings.Contains(command, pattern) {
			return true
		}
	}

	return false
}

// getContainerProcessInfo 获取容器中指定PID的进程信息
func (ps *ProcessScanner) getContainerProcessInfo(containerID string, pid int) *utils.ProcessInfo {
	// 使用docker exec获取进程信息，包括etime字段
	cmd := fmt.Sprintf("docker exec %s ps -p %d -o pid,cmd,etime,user --no-headers", containerID, pid)
	output, err := ps.executeCommand(cmd)
	if err != nil {
		ps.logger.Debugf("获取容器进程信息失败 PID=%d: %v", pid, err)
		return nil
	}

	// 解析输出
	lines := strings.Split(strings.TrimSpace(output), "\n")
	if len(lines) == 0 {
		return nil
	}

	// 解析进程信息行
	line := strings.TrimSpace(lines[0])
	fields := strings.Fields(line)
	if len(fields) < 4 {
		ps.logger.Debugf("进程信息字段不足: %s", line)
		return nil
	}

	// 提取字段
	pidStr := fields[0]
	user := fields[len(fields)-1]  // 最后一个字段是用户
	etime := fields[len(fields)-2] // 倒数第二个字段是etime

	// 命令可能包含空格，需要重新组合
	// 格式: PID CMD... ETIME USER
	// 我们需要提取中间的CMD部分
	cmdStart := len(pidStr) + 1                      // PID后面的空格
	cmdEnd := len(line) - len(user) - len(etime) - 2 // 减去两个空格
	if cmdEnd <= cmdStart {
		ps.logger.Debugf("无法解析命令: %s", line)
		return nil
	}

	command := strings.TrimSpace(line[cmdStart:cmdEnd])

	// 解析etime为启动时间
	startTime, err := ps.parseEtimeToStartTime(etime)
	if err != nil {
		ps.logger.Debugf("解析etime失败 %s: %v", etime, err)
		startTime = time.Now().Add(-time.Hour) // fallback
	}

	// 构造进程信息
	procInfo := &utils.ProcessInfo{
		PID:       pid,
		Command:   ps.extractDisplayName(command), // 提取更友好的显示名称
		User:      user,
		StartTime: startTime,
	}

	ps.logger.Debugf("解析容器进程信息: PID=%d, Command=%s, User=%s, StartTime=%s",
		pid, procInfo.Command, user, startTime.Format("2006-01-02 15:04:05"))
	return procInfo
}

// extractDisplayName 从完整命令中提取更友好的显示名称
func (ps *ProcessScanner) extractDisplayName(fullCommand string) string {
	// 如果命令为空，返回原值
	if fullCommand == "" {
		return fullCommand
	}

	// 常见的脚本执行模式，提取脚本名
	patterns := []struct {
		prefix  string
		extract func(string) string
	}{
		// bash /path/to/script.sh -> script.sh
		{"bash ", func(cmd string) string {
			parts := strings.Fields(cmd)
			if len(parts) >= 2 {
				scriptPath := parts[1]
				return filepath.Base(scriptPath)
			}
			return cmd
		}},
		// /bin/bash /path/to/script.sh -> script.sh
		{"/bin/bash ", func(cmd string) string {
			parts := strings.Fields(cmd)
			if len(parts) >= 2 {
				scriptPath := parts[1]
				return filepath.Base(scriptPath)
			}
			return cmd
		}},
		// sh /path/to/script.sh -> script.sh
		{"sh ", func(cmd string) string {
			parts := strings.Fields(cmd)
			if len(parts) >= 2 {
				scriptPath := parts[1]
				return filepath.Base(scriptPath)
			}
			return cmd
		}},
		// /bin/sh /path/to/script.sh -> script.sh
		{"/bin/sh ", func(cmd string) string {
			parts := strings.Fields(cmd)
			if len(parts) >= 2 {
				scriptPath := parts[1]
				return filepath.Base(scriptPath)
			}
			return cmd
		}},
		// python /path/to/script.py -> script.py
		{"python ", func(cmd string) string {
			parts := strings.Fields(cmd)
			if len(parts) >= 2 {
				scriptPath := parts[1]
				return filepath.Base(scriptPath)
			}
			return cmd
		}},
		// python3 /path/to/script.py -> script.py
		{"python3 ", func(cmd string) string {
			parts := strings.Fields(cmd)
			if len(parts) >= 2 {
				scriptPath := parts[1]
				return filepath.Base(scriptPath)
			}
			return cmd
		}},
		// /usr/bin/python /path/to/script.py -> script.py
		{"/usr/bin/python ", func(cmd string) string {
			parts := strings.Fields(cmd)
			if len(parts) >= 2 {
				scriptPath := parts[1]
				return filepath.Base(scriptPath)
			}
			return cmd
		}},
		// /usr/bin/python3 /path/to/script.py -> script.py
		{"/usr/bin/python3 ", func(cmd string) string {
			parts := strings.Fields(cmd)
			if len(parts) >= 2 {
				scriptPath := parts[1]
				return filepath.Base(scriptPath)
			}
			return cmd
		}},
	}

	// 检查是否匹配任何模式
	for _, pattern := range patterns {
		if strings.HasPrefix(fullCommand, pattern.prefix) {
			return pattern.extract(fullCommand)
		}
	}

	// 如果没有匹配的模式，返回第一个单词（程序名）
	parts := strings.Fields(fullCommand)
	if len(parts) > 0 {
		return filepath.Base(parts[0])
	}

	return fullCommand
}

// parseEtimeToStartTime 将etime格式转换为启动时间
func (ps *ProcessScanner) parseEtimeToStartTime(etime string) (time.Time, error) {
	now := time.Now()

	// etime格式可能是：
	// 12:34 (分钟:秒)
	// 1:23:45 (小时:分钟:秒)
	// 2-12:34:56 (天-小时:分钟:秒)

	var duration time.Duration
	var err error

	if strings.Contains(etime, "-") {
		// 包含天数: 2-12:34:56
		parts := strings.Split(etime, "-")
		if len(parts) != 2 {
			return time.Time{}, fmt.Errorf("无效的etime格式: %s", etime)
		}

		days, err := strconv.Atoi(parts[0])
		if err != nil {
			return time.Time{}, fmt.Errorf("解析天数失败: %s", parts[0])
		}

		timePart := parts[1]
		timeDuration, err := ps.parseTimeString(timePart)
		if err != nil {
			return time.Time{}, err
		}

		duration = time.Duration(days)*24*time.Hour + timeDuration

	} else {
		// 不包含天数
		duration, err = ps.parseTimeString(etime)
		if err != nil {
			return time.Time{}, err
		}
	}

	return now.Add(-duration), nil
}

// parseTimeString 解析时间字符串 (HH:MM:SS 或 MM:SS)
func (ps *ProcessScanner) parseTimeString(timeStr string) (time.Duration, error) {
	parts := strings.Split(timeStr, ":")

	if len(parts) == 2 {
		// MM:SS 格式
		minutes, err := strconv.Atoi(parts[0])
		if err != nil {
			return 0, fmt.Errorf("解析分钟失败: %s", parts[0])
		}
		seconds, err := strconv.Atoi(parts[1])
		if err != nil {
			return 0, fmt.Errorf("解析秒失败: %s", parts[1])
		}
		return time.Duration(minutes)*time.Minute + time.Duration(seconds)*time.Second, nil

	} else if len(parts) == 3 {
		// HH:MM:SS 格式
		hours, err := strconv.Atoi(parts[0])
		if err != nil {
			return 0, fmt.Errorf("解析小时失败: %s", parts[0])
		}
		minutes, err := strconv.Atoi(parts[1])
		if err != nil {
			return 0, fmt.Errorf("解析分钟失败: %s", parts[1])
		}
		seconds, err := strconv.Atoi(parts[2])
		if err != nil {
			return 0, fmt.Errorf("解析秒失败: %s", parts[2])
		}
		return time.Duration(hours)*time.Hour + time.Duration(minutes)*time.Minute + time.Duration(seconds)*time.Second, nil

	} else {
		return 0, fmt.Errorf("无效的时间格式: %s", timeStr)
	}
}
