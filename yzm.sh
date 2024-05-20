#!/bin/bash

# 数据库连接信息
DB_USER="root"
DB_PASSWORD="unAiost2099@#"
DB_NAME="AHUser"

# SQL查询语句
SQL_QUERY="SELECT value FROM sys_config WHERE id = 11;"
# 获取容器ID
CONTAINER_ID=$(docker ps --filter "ancestor=anheng_aisort_mysql:5.6" --format "{{.ID}}")

if [ -z "$CONTAINER_ID" ]; then
    echo "No running container found for image anheng_aisort_mysql:5.6."
    exit 1
fi

# 进入Docker容器并执行SQL查询
VALUE=$(docker exec $CONTAINER_ID mysql -u $DB_USER -p$DB_PASSWORD -D $DB_NAME -se "$SQL_QUERY")

# 检查查询结果
if [ "$VALUE" == "true" ]; then
    echo "Value is already true. No need to update and restart services."
else
    # SQL更新语句
    SQL_UPDATE="UPDATE sys_config SET value = 'true' WHERE id = 11;"

    # 执行SQL更新
    docker exec $CONTAINER_ID mysql -u $DB_USER -p$DB_PASSWORD -D $DB_NAME -e "$SQL_UPDATE"

    # 重启用户服务
    sh /home/init/status.sh user restart

    # 重启Nginx服务
    sh /home/init/status.sh nginx restart

    echo "SQL update and services restart completed."
fi