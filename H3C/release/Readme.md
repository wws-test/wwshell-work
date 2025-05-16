H3C Release 工具集说明
本目录包含一组用于自动化管理、备份、校验和 SVN 操作的 Bash 脚本，适用于 H3C 相关项目的日常维护和交付流程。每个脚本均配有详细注释，便于二次开发和定制。

脚本一览
1. manager.sh
功能：统一入口脚本，汇总调用本目录下所有工具。
用法：

支持命令：

check ：后台运行 MD5 校验工具（check_md5.sh），校验结果请查看日志文件。
compass ：运行文件夹压缩备份工具（compass_folder.sh），自动备份未被 SVN 管理的文件夹。
prepare ：运行 SVN 提交准备工具（svn_prepare.sh），自动校验备份并准备 SVN 提交。
status ：运行 SVN 状态检查工具（svn_status_checker.sh），检查指定目录的 SVN 状态。
help ：显示详细使用说明。
示例：

2. check_md5.sh
功能：递归检查 Model 和 Vendor 目录下所有 md5sums.txt 文件，自动校验文件完整性，并统计缺失 md5 文件的目录数。
特点：

分类统计 Model/Vendor 下 md5 文件数量及缺失情况
校验结果自动写入日志文件（日志路径见脚本内说明）
支持后台运行（通过 manager.sh check）
3. compass_folder.sh
功能：自动识别当前目录下未被 SVN 管理的文件夹，为每个文件夹创建 _bk 备份文件夹，压缩源文件夹并生成 MD5 校验文件。
特点：

跳过空文件夹、大于 300GB 的文件夹、已存在的 tar.gz 文件和 _bk 文件夹
自动清理不完整或失败的备份
备份完成后生成 md5sums.txt 文件
4. svn_prepare.sh
功能：查找所有 _bk 结尾的备份文件夹，校验其 md5 文件，校验通过后删除源文件夹并将备份文件夹重命名，最后自动添加到 SVN 并记录日志。
特点：

检查每个备份文件夹的 md5sums.txt
校验失败或缺失 md5 文件会有详细提示
所有操作均记录到 logs/svn_operations.log
5. svn_status_checker.sh
功能：检查指定厂商目录（Vendor 下的各主流厂商）SVN 状态，显示未提交的文件和目录结构，并高亮大文件夹。
特点：

智能判断 SVN 工作区位置
支持大文件夹（>300GB）高亮显示
输出美观的表格结构
常见问题
日志文件在哪里？
各脚本会在 logs 目录下自动生成日志文件，详细路径和文件名请参考各脚本注释或运行结果提示。

如何后台运行？
通过 manager.sh check` 启动 MD5 校验任务，脚本会自动在后台运行，无需手动加 &。

需要哪些依赖？
需预装 bash、svn、tar、md5sum、awk、grep 等常用命令行工具。

如需进一步定制或遇到问题，请查阅脚本内注释或联系维护者。