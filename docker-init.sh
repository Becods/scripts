#!/bin/bash -e
Error="\033[31m[Error]\033[0m "
Info="\033[32m[Info]\033[0m "
dPASSWORD=`openssl rand -base64 9`
ips=$(ip addr show |grep "inet "|grep -v docker|grep -v 127.0.0. |head -1|cut -d" " -f6|cut -d/ -f1)
ARGS=`getopt -a -o P:p:d:l:H:hq -l password:,country:,state:,city:,organization:,organization_unit:,common_name:,email:,days:,length:,port:,ip:,quiet,help -- "$@"`

Input(){
	[ ! $PASSWORD ]&&echo -e "${Info}请输入证书PASSWORD，回车跳过（默认${dPASSWORD}）"&&read PASSWORD
	[ ! $COUNTRY ]&&echo -e "${Info}请输入证书COUNTRY，回车跳过（默认CN）"&&read COUNTRY
	[ ! $STATE ]&&echo -e "${Info}请输入证书STATE，回车跳过（默认GD）"&&read STATE
	[ ! $CITY ]&&echo -e "${Info}请输入证书CITY，回车跳过（默认GD）"&&read CITY
	[ ! $ORGANIZATION ]&&echo -e "${Info}请输入证书ORGANIZATION，回车跳过（默认Dev）"&&read ORGANIZATION
	[ ! $ORGANIZATIONAL_UNIT ]&&echo -e "${Info}请输入证书ORGANIZATIONAL_UNIT，回车跳过（默认Dev）"&&read ORGANIZATIONAL_UNIT
	[ ! $COMMON_NAME ]&&echo -e "${Info}请输入证书COMMON_NAME，回车跳过（默认$IP）"&&read COMMON_NAME
	[ ! $EMAIL ]&&echo -e "${Info}请输入证书EMAIL，回车跳过（默认docker@dev.com）"&&read EMAIL
	[ ! $DAYS ]&&echo -e "${Info}请输入证书有效天数，回车跳过（默认3650）"&&read DAYS
	[ ! $LENGTH ]&&echo -e "${Info}请输入证书密钥长度，回车跳过（默认2048）"&&read LENGTH
	[ ! $PORT ]&&echo -e "${Info}请输入对外端口，回车跳过（默认2375）"&&read PORT
}

checkip(){
echo -e "${Info}这些是你将要允许远程管理的IP吗，请注意，不在此列表内的IP将无法进行远程管理（不是客户端，是docker端绑定的IP） Y/n"
echo -e "$ips"
read ips
case "$ips" in
	Y)echo -e "${Info}请输入你的IP，使用空格作为分隔符" && read ips;;
	y)echo -e "${Info}请输入你的IP，使用空格作为分隔符" && read ips;;
	yes)echo -e "${Info}请输入你的IP，使用空格作为分隔符" && read ips;;
	*)Input;;
esac
}

usage(){
echo -e "使用帮助
 -h|--help 使用帮助
 -P|--password 证书密码
 -d|--days 证书有效天数
 -l|--length 证书密钥长度
 -p|--port 对外端口
 -H|--ip 允许远程管理的IP
 -q|--quiet 安静模式/默认模式
 --country 证书国家
 --state 证书省份
 --city 证书城市
 --organization 证书组织名
 --organization_unit 证书组织单位
 --common_name 证书使用的IP
 --email 证书邮箱"
}

eval set -- "${ARGS}"
while true;do
	case "$1" in
		-P|--password)database="$2"&&shift;;
		--country)="$2"&&shift;;
		--state)="$2"&&shift;;
		--city)="$2"&&shift;;
		--organization)="$2"&&shift;;
		--organization_unit)="$2"&&shift;;
		--common_name)="$2"&&shift;;
		--email)="$2"&&shift;;
		-d|--days)DAYS="$2"&&shift;;
		-l|--length)LENGTH="$2"&&shift;;
		-p|--port)PORT="$2"&&shift;;
		-H|--ip)ips="$2"&&shift;;
		-q|--quiet)exec 3>/dev/null&&quiet="yes";;
		-h|--help)usage&&exit;;
        --)shift&&break;;
	esac
	shift
done

[ ! $quiet ]&&exec 3>&1&&checkip&&Input
[ ! $PASSWORD ]&&PASSWORD=$dPASSWORD
[ ! $COUNTRY ]&&COUNTRY="CN"
[ ! $STATE ]&&STATE="GD"
[ ! $CITY ]&&CITY="GD"
[ ! $ORGANIZATION ]&&ORGANIZATION="Dev"
[ ! $ORGANIZATIONAL_UNIT ]&&ORGANIZATIONAL_UNIT="Dev"
[ ! $COMMON_NAME ]&&COMMON_NAME="$IP"
[ ! $EMAIL ]&&EMAIL="docker@dev.com"
[ ! $DAYS ]&&DAYS="3650"
[ ! $LENGTH ]&&LENGTH="2048"
[ ! $PORT ]&&PORT="2375"

for i in $ips;do IP="IP:"$i",";done
mkdir -p /etc/docker/cert
cd /etc/docker/cert
echo -e "${Info}正在安装运行环境"
apt-get install curl -y -qqq
echo -e >&3 "${Info}正在确认服务器位置"
if [[ -n `curl -s http://www.geoplugin.net/json.gp|grep Asia` ]]; then 
	UseMirror="yes"
fi

if [ -f "/etc/docker/daemon.json" ]; then
	mv -f /etc/docker/daemon.json /etc/docker/daemon.json.bak
	echo -e "${Info}daemon.json备份成功"
fi
if [[ "$UseMirror" = "yes"  ]];then
	echo -e "${Info}服务器位于亚洲，已为您自动配置就近镜像"
	cat << EOF > /etc/docker/daemon.json
{
	"registry-mirrors": [
		"https://docker.mirrors.ustc.edu.cn",
		"https://hub-mirror.c.163.com"
	],
	"tlsverify": true,
	"tlscacert": "/etc/docker/cert/ca.pem",
	"tlscert": "/etc/docker/cert/server-cert.pem",
	"tlskey": "/etc/docker/cert/server-key.pem",
	"hosts": ["tcp://0.0.0.0:$PORT","unix:///var/run/docker.sock"]
}
EOF
else
	cat << EOF > /etc/docker/daemon.json
{
	"tlsverify": true,
	"tlscacert": "/etc/docker/cert/ca.pem",
	"tlscert": "/etc/docker/cert/server-cert.pem",
	"tlskey": "/etc/docker/cert/server-key.pem",
	"hosts": ["tcp://0.0.0.0:$PORT","unix:///var/run/docker.sock"]
}
EOF
fi

sed -i "s# -H fd://##g" /lib/systemd/system/docker.service

echo -e "${Info}正在为您生成证书"

openssl genrsa -aes256 -passout "pass:$PASSWORD" -out "ca-key.pem" $LENGTH &>/dev/null

openssl req -new -x509 -days $DAYS -key "ca-key.pem" -sha256 -out "ca.pem" -passin "pass:$PASSWORD" -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL" &>/dev/null

openssl genrsa -out "server-key.pem" $LENGTH &>/dev/null

openssl req -subj "/CN=$COMMON_NAME" -sha256 -new -key "server-key.pem" -out server.csr &>/dev/null

echo "subjectAltName = ${IP}IP:127.0.0.1" >> extfile.cnf
echo "extendedKeyUsage = serverAuth" >> extfile.cnf

openssl x509 -req -days $DAYS -sha256 -in server.csr -passin "pass:$PASSWORD" -CA "ca.pem" -CAkey "ca-key.pem" -CAcreateserial -out "server-cert.pem" -extfile extfile.cnf &>/dev/null

rm -f extfile.cnf

openssl genrsa -out "key.pem" $LENGTH &>/dev/null
openssl req -subj '/CN=client' -new -key "key.pem" -out client.csr &>/dev/null
echo extendedKeyUsage = clientAuth >> extfile.cnf
openssl x509 -req -days $DAYS -sha256 -in client.csr -passin "pass:$PASSWORD" -CA "ca.pem" -CAkey "ca-key.pem" -CAcreateserial -out "cert.pem" -extfile extfile.cnf &>/dev/null

rm -vf client.csr server.csr 2>&1 >&3

chmod -v 0400 "ca-key.pem" "key.pem" "server-key.pem" 2>&1 >&3
chmod -v 0444 "ca.pem" "server-cert.pem" "cert.pem" 2>&1 >&3

mkdir -p "tls-client-certs" 2>&1 >&3
cp -f "ca.pem" "cert.pem" "key.pem" "tls-client-certs/" 2>&1 >&3
cd "tls-client-certs" 2>&1 >&3
tar zcf "tls-client-certs.tar.gz" * 2>&1 >&3
mv "tls-client-certs.tar.gz" ../ 2>&1 >&3
cd ..
rm -rf "tls-client-certs" 2>&1 >&3

echo -e "${Info}证书生成完毕，客户端验证文件位于/etc/docker/cert/tls-client-certs.tar.gz"

echo -e "${Info}正在重启Docker"
systemctl daemon-reload
sleep 1s
systemctl restart docker
echo -e "${Info}安装成功，服务端口"$PORT
