@echo off
:: 构建镜像
docker build -t test .

:: 获取镜像ID
for /f %%i in ('docker images --filter=reference=test --format "{{.ID}}"') do set image_id=%%i

:: 打标签
docker tag %image_id% registry.cn-hangzhou.aliyuncs.com/sww-123/metersphere:testTools

:: 上传镜像
docker push registry.cn-hangzhou.aliyuncs.com/sww-123/metersphere:testTools

:: 链接SSH并执行命令
sshpass -p 'w8$h3@m$JHKv' ssh root@10.50.3.213 "docker pull registry.cn-hangzhou.aliyuncs.com/sww-123/metersphere:testTools && cd /opt && ./reload.sh"