#/bin/sh

#���mysql server�Ƿ������ṩ����
mysqladmin -u sky -ppwd -h localhost ping

#��ȡmysql��ǰ�ļ���״ֵ̬
mysqladmin -u sky -ppwd -h localhost status

#��ȡ���ݿ⵱ǰ��������Ϣ
mysqladmin -u sky -ppwd -h localhost processlist

#��ȡ��ǰ���ݿ��������
mysql -u root -p123456 -BNe "select host,count(host) from processlist group by host;" information_schema

#��ʾmysql��uptime
mysql -e"SHOW STATUS LIKE '%uptime%'"|awk '/ptime/{ calc = $NF / 3600;print $(NF-1), calc"Hour" }'

#�鿴���ݿ�Ĵ�С
mysql -u root -p123456-e 'select table_schema,round(sum(data_length+index_length)/1024/1024,4) from information_schema.tables group by table_schema;'

#�鿴ĳ����������Ϣ
mysql -u <user> --password=<password> -e "SHOW COLUMNS FROM <table>" <database> | awk '{print $1}' | tr "\n" "," | sed 's/,$//g'

#ִ��mysql�ű�
mysql -u user-name -p password < script.sql

#mysql dump���ݵ���
mysqldump -uroot -T/tmp/mysqldump test test_outfile --fields-enclosed-by=\" --fields-terminated-by=,

#mysql���ݵ���
mysqlimport --user=name --password=pwd test --fields-enclosed-by=\" --fields-terminated-by=, /tmp/test_outfile.txt
LOAD DATA INFILE '/tmp/test_outfile.txt' INTO TABLE test_outfile FIELDS TERMINATED BY '"' ENCLOSED BY ',';

#mysql���̼��
ps -ef | grep "mysqld_safe" | grep -v "grep"
ps -ef | grep "mysqld" | grep -v "mysqld_safe"| grep -v "grep"


#�鿴��ǰ���ݿ��״̬
mysql -u root -p123456 -e 'show status'


#mysqlcheck ���߳�����Լ��(check),�� ��( repair),�� ��( analyze)���Ż�(optimize)MySQL Server �еı�
mysqlcheck -u root -p123456 --all-databases

#mysql qps��ѯ  QPS = Questions(or Queries) / Seconds
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Questions"'
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Queries"'

#mysql Key Buffer ������  key_buffer_read_hits = (1 - Key_reads / Key_read_requests) * 100%  key_buffer_write_hits= (1 - Key_writes / Key_write_requests) * 100%
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Key%"'

#mysql Innodb Buffer ������  innodb_buffer_read_hits=(1-Innodb_buffer_pool_reads/Innodb_buffer_pool_read_requests) * 100%
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Innodb_buffer_pool_read%"'

#mysql Query Cache ������ Query_cache_hits= (Qcache_hits / (Qcache_hits + Qcache_inserts)) * 100%
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Qcache%"'

#mysql Table Cache ״̬��
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Open%"'

#mysql Thread Cache ������  Thread_cache_hits = (1 - Threads_created / Connections) * 100%  ������˵,Thread Cache ������Ҫ�� 90% ���ϲ���ȽϺ�����
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Thread%"'

#mysql ����״̬:����״̬������������������,���ǿ���ͨ��ϵͳ״̬������������ܴ���,������������̵߳ȴ��Ĵ���,�Լ������ȴ�ʱ����Ϣ
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "%lock%"'

#mysql ������ʱ�� ��slave�ڵ�ִ��
mysql -u root -p123456 -e 'SHOW SLAVE STATUS'

#mysql Tmp table ״�� Tmp Table ��״����Ҫ�����ڼ�� MySQL ʹ����ʱ�������Ƿ����,�Ƿ�����ʱ����������ò����ڴ��л����������ļ���
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Created_tmp%"'

#mysql Binlog Cache ʹ��״��:Binlog Cache ���ڴ�Ż�δд����̵� Binlog �� Ϣ ��
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Binlog_cache%"'

#mysql nnodb_log_waits ��:Innodb_log_waits ״̬����ֱ�ӷ�Ӧ�� Innodb Log Buffer �ռ䲻����ɵȴ��Ĵ���
mysql -u root -p123456 -e 'SHOW /*!50000 GLOBAL */ STATUS LIKE "Innodb_log_waits'

