#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cur_dir=$(pwd)

#设置网站名称

DOMAIN=""
VHOSTDIR=""
WPVERSION=""
DBNAME=""                               #要创建的数据库的库名称
PASSWORD=""                             #MYSQL数据库ROOT密码
HOSTNAME="localhost"                #数据库Server信息
PORT="3306"
USERNAME="root"

echo "请输入网站名称， 例 test.com"
read -p "网站名称:" DOMAIN

echo "请输入网站目录，例 test_com"
read -p "网站目录:" VHOSTDIR

echo "请输入wordpress版本，例 3.8.3"
read -p "wordpress版本:" WPVERSION

echo "请输入数据库名称，例 dtb_domaincom"
read -p "数据库名称:" DBNAME

echo "请输入本服务器的Myslq密码"
read -p "Myslq密码:" PASSWORD

if [ "$DOMAIN" = "" ]; then
echo "网站名称不能为空！"
exit 1
fi

if [ "$VHOSTDIR" = "" ]; then
echo "网站目录不能为空！"
exit 1
fi

if [ "$WPVERSION" = "" ]; then
echo "wordpress版本无效！"
exit 1
fi

if [ "$DBNAME" = "" ]; then
echo "数据库名不能为空！"
exit 1
fi

if [ "$PASSWORD" = "" ]; then
echo "密码不能为空！"
exit 1
fi

echo "==========================="
echo DOMAIN="$DOMAIN"
echo VHOSTDIR="$VHOSTDIR"
echo WPVERSION="$WPVERSION"
echo DBNAME="$DBNAME"
echo PASSWORD="$PASSWORD"
echo "==========================="

mkdir -p /www/web/$VHOSTDIR
tar zxvf wordpress-$WPVERSION-zh_CN.tar.gz
cd wordpress
mv wp-config-sample.php wp-config.php

sed -i 's/database_name_here/'$DBNAME'/g' wp-config.php
sed -i 's/username_here/'$USERNAME'/g' wp-config.php
sed -i 's/password_here/'$PASSWORD'/g' wp-config.php
sed -i '/table_prefix/s/wp_/dtwp_/g' wp-config.php
sed -i '/SECURE_AUTH_KEY/s/put your unique phrase here/fdEe6c4ef9D54F93115d17CE8E718da992e6188DF9766C117EDf34dD13523AD4/g' ./wp-config.php
sed -i '/SECURE_AUTH_SALT/s/put your unique phrase here/9C8325e440D97AB69C6371E5b81f92e0A26Dc31Fb718e09D72b9733B9Bf72C0C/g' ./wp-config.php
 
sed -i '/AUTH_KEY/s/put your unique phrase here/9eE87858Ef6EbF839dF0f24e12366826bEBAfF33280034aD194b8d4c83a14A0B/g' wp-config.php
sed -i '/AUTH_SALT/s/put your unique phrase here/d94e4d8a8f7B9286C3B46A4eDE420025eC26e796BeA6645134b1193DBe134D07/g' wp-config.php
sed -i '/LOGGED_IN_KEY/s/put your unique phrase here/c019Ff1D6FA683defEB279516DF1835E37657C49cEbDCD9B7b3E30A2A057F482/g' wp-config.php
sed -i '/NONCE_KEY/s/put your unique phrase here/506E4A23A18F3a2c3Fc444698e89C9343e57717a161f42a84a9d5dc633e26d22/g' wp-config.php
sed -i '/LOGGED_IN_SALT/s/put your unique phrase here/10bF48E95dE5682a0E695bf8E179f05B3871EC1027a1367414e6DcCfbCA16C3d/g' wp-config.php
sed -i '/NONCE_SALT/s/put your unique phrase here/32Bb93f43c567856181Ef96F90a71C62aF18B21D47eCD78131d058b8F58e894b/g' wp-config.php

cat << EOF >> wp-config.php

\$home = 'http://'.\$_SERVER['HTTP_HOST'];
\$siteurl = 'http://'.\$_SERVER['HTTP_HOST'];
define('WP_HOME', \$home);
define('WP_SITEURL', \$siteurl);

EOF

rm -f readme.html license.txt
rm -rf ./wp-content/themes/twentytwelve ./wp-content/themes/twentythirteen
mv ./* /www/web/$VHOSTDIR
cd ..
rm -rf wordpress

find /www/web/$VHOSTDIR/ -type f -exec chmod 644 {} \;
find /www/web/$VHOSTDIR/ -type d -exec chmod 755 {} \;
find /www/web/$VHOSTDIR/wp-content/ -type f -exec chmod 664 {} \;
chown -R www:www /www/web/$VHOSTDIR


MYSQL_CMD="mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD}"
echo ${MYSQL_CMD}

echo "create database ${DBNAME}"

create_db_sql="create database IF NOT EXISTS ${DBNAME}"

echo ${create_db_sql}  | ${MYSQL_CMD}           #创建数据库                    
if [ $? -ne 0 ]                                 #判断是否创建成功
then
 echo "create databases ${DBNAME} failed ..."
 exit 1
fi


mkdir -p /www/logs/nginx
mkdir -p /usr/local/nginx/conf/vhost
cat > /usr/local/nginx/conf/vhost/$VHOSTDIR.conf <<eof

log_format  www.$DOMAIN  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
            '\$status \$body_bytes_sent "\$http_referer" '
            '"\$http_user_agent" \$http_x_forwarded_for';
server
{
    listen 80;
    server_name www.$DOMAIN $DOMAIN;
    root   /www/web/$VHOSTDIR;
    index  index.html index.php;
    try_files \$uri \$uri/ /index.php?\$args;

    location ~ .*\.(php|php5)?$
    {   
    	fastcgi_pass  unix:/tmp/php-cgi.sock;
    	fastcgi_index index.php;
        fastcgi_param PHP_ADMIN_VALUE "open_basedir=\$document_root:/tmp/"; 
    	include fcgi.conf;
    }
    location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|txt|ico|eot|svg|ttf|woff|mp3|m4a)$
    {
        expires 30d;
        valid_referers none blocked *.$DOMAIN $DOMAIN;
        if (\$invalid_referer) {
            return 502;
        }
    }
    location ~ .*\.(js|css)$
    {
        expires 7d;
        valid_referers none blocked *.$DOMAIN $DOMAIN;
        if (\$invalid_referer) {
            return 502;
        }
    }
    # access_log  /www/logs/nginx/access.$VHOSTDIR.log;
    # error_log /www/logs/nginx/error.$VHOSTDIR.log;
}
eof

/etc/init.d/php-fpm restart

echo "Test Nginx configure file......"
/usr/local/nginx/sbin/nginx -t
echo ""
echo "Restart Nginx......"
/usr/local/nginx/sbin/nginx -s reload
