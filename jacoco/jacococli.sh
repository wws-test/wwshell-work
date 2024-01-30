#!/bin/bash

# 寻找ailpha-qu-xxx-dist.jar文件
jar_file=$(ls /usr/hdp/2.5.3.0-37/bigdata/mirror-web-api/lib/ailpha-qu-*-dist.jar)

# 检查是否找到了文件
if [ -z "$jar_file" ]; then
  echo "未找到ailpha-qu-xxx-dist.jar文件"
  exit 1
fi

# 执行jacoco命令生成exec文件
java -jar /home/org.jacoco.cli-0.8.7-SNAPSHOT-nodeps.jar dump --address 127.0.0.1 --port 18513 --destfile ./jacoco.exec

# 执行jacoco命令生成xml文件
java -jar org.jacoco.cli-0.8.7-SNAPSHOT-nodeps.jar report jacoco.exec \
--classfiles "$jar_file" \
--sourcefiles /home/logsaas/ailpha_code/bigdata-web-backend/bdweb-mirror/src/main/java/com/dbapp \
--xml ./report.xml   #--html ./report

# 最终生成报告html
reportgenerator "-reports:./report.xml" "-targetdir:coveragereport" -reporttypes:HtmlSummary