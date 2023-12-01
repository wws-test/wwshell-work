#ͳ��apache cookie log�з���Ƶ����ߵ�20��ip�ͷ��ʴ���
cat cookielog | awk '{ a[$1] += 1; } END { for(i in a) printf("%d, %s\n", a[i], i ); }' | sort -n | tail -20

#ͳ��apache cookie log�з���404��url�б�
awk '$11 == 404 {print $8}' access_log | uniq -c | sort -rn | head

#ͳ��һ��ip���ʳ���20�ε�ip�ͷ��ʴ����б�����$1��Ϊurl��Ӧ��$9,�����ͳ��ÿ��url�ķ��ʴ���
cat access_log | awk '{print $1}' | sort | uniq -c | sort -n | awk '{ if ($1 > 20)print $1,$2}'

#ͳ��ÿ��url��ƽ������ʱ��
cat cookielog | awk '{ a[$6] += 1; b[$6] += $11; } END { for(i in a) printf("%d, %d, %s\n", a[i],a[i]/b[i] i ); }' | sort -n | tail -20


#��ӡ����apache����ip�б�
tail -f access.log | awk -W interactive '!x[$1]++ {print $1}'

#ͨ����־�鿴����ָ��ip���ʴ�������url�ͷ��ʴ���:
cat access.log | grep "10.0.21.17" | awk '{print $7}' | sort | uniq -c | sort �Cnr


#ͨ����־�鿴������ʴ�������ʱ���
awk '{print $4}' access.log | grep "26/Mar/2012" |cut -c 20-50|sort|uniq -c|sort -nr|head

#�鿴ĳһ��ķ�����
cat access_log|grep '12/Nov/2012'|grep "******.htm"|wc|awk '{print $1}'|uniq 

#�鿴����ʱ�䳬��30ms��url�б�
cat access_log|awk ��($NF > 30){print $7}��|sort -n|uniq -c|sort -nr|head -20 

#�г���Ӧʱ�䳬��60m��url�б���ͳ�Ƴ��ִ���
cat access_log |awk ��($NF > 60 && $7~/\.php/){print $7}��|sort -n|uniq -c|sort -nr|head -100 

#�ų�����������url���ʴ���
sed "/Baiduspider/d;/Googlebot/d;/Sogou web spider/d;" xxx.log|awk -F' ' '{print $7}'|sort | uniq -c | sort -k1,2 -nr 

#ͳ��/index.htmlҳ��ķ���uv
grep "/index.html" access.log | cut �Cd �� �� �Cf 4| sort | uniq | wc �Cl 