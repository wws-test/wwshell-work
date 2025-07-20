# Makefile for cmdmonitor - 精准监控版本

# 变量定义
BINARY_NAME=cmdmonitor
MAIN_PATH=cmd/main.go
BUILD_DIR=build
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "v1.0.0")
LDFLAGS=-ldflags "-X main.Version=$(VERSION) -s -w"

# 默认目标 - 只构建Linux版本（生产环境）
.PHONY: all
all: clean build-linux

# 清理构建文件
.PHONY: clean
clean:
	@echo "清理构建文件..."
	@rm -rf $(BUILD_DIR)
	@rm -f $(BINARY_NAME)

# 创建构建目录
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Linux构建（主要目标）
.PHONY: build-linux
build-linux: $(BUILD_DIR)
	@echo "构建 $(BINARY_NAME) for linux/amd64..."
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 $(MAIN_PATH)
	@echo "✅ Linux版本构建完成: $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64"



# 创建部署包
.PHONY: package
package: build-linux
	@echo "创建部署包..."
	@mkdir -p $(BUILD_DIR)/deploy
	@cp $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 $(BUILD_DIR)/deploy/$(BINARY_NAME)
	@cp configs/config.env $(BUILD_DIR)/deploy/
	@cp configs/cmdmonitor.service $(BUILD_DIR)/deploy/
	@cp scripts/install.sh $(BUILD_DIR)/deploy/
	@cp DEPLOYMENT.md $(BUILD_DIR)/deploy/
	@cd $(BUILD_DIR) && tar -czf cmdmonitor-$(VERSION)-deploy.tar.gz deploy/
	@echo "✅ 部署包已创建: $(BUILD_DIR)/cmdmonitor-$(VERSION)-deploy.tar.gz"

# 运行测试
.PHONY: test
test:
	@echo "运行测试..."
	@go test -v ./...

# 代码格式化
.PHONY: fmt
fmt:
	@echo "格式化代码..."
	@go fmt ./...

# 代码检查
.PHONY: vet
vet:
	@echo "代码检查..."
	@go vet ./...

# 本地运行
.PHONY: run
run:
	@echo "本地运行..."
	@go run $(MAIN_PATH)

# 安装依赖
.PHONY: deps
deps:
	@echo "安装依赖..."
	@go mod download
	@go mod tidy

# 显示帮助
.PHONY: help
help:
	@echo "Command Monitor - 精准监控构建工具"
	@echo ""
	@echo "可用的命令:"
	@echo "  all          - 清理并构建Linux版本（默认）"
	@echo "  build-linux  - 构建Linux生产版本"
	@echo "  package      - 创建完整部署包"
	@echo "  test         - 运行测试"
	@echo "  clean        - 清理构建文件"
	@echo "  fmt          - 格式化代码"
	@echo "  vet          - 代码检查"
	@echo "  run          - 本地运行（仅用于开发调试）"
	@echo "  deps         - 安装依赖"
	@echo ""
	@echo "示例:"
	@echo "  make           # 构建Linux版本"
	@echo "  make package   # 创建部署包"
	@echo "  make run       # 本地调试运行"
