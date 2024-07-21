#!/bin/bash

start_time=$(date +%s)

echo "-"
echo "-"
echo "============================="
echo "Alma 8 LAMP & DB Installation"
echo "============================="
echo "-"
echo "-"

rpas="S3cr3tt9II*"
email="nooufiy@outlook.com"
nuser="admin"
aport=7771
dpub="/sites"
ds="/rs"
cs_sh="$ds/cs.sh"
vh_sh="$ds/vh.sh"
ssl_sh="$ds/ssl.sh"
mkdir -p "$dpub"/{w,l,d}
mkdir -p "$ds/ssl"
mkdir -p "$ds/r"

>"$dpub"/w/index.html
>"$dpub"/d/index.html

# SET HOST
# =========
# hostnamectl set-hostname dc-001.justinn.ga
# systemctl restart systemd-hostnamed
# hostnamectl status


# GET DATA
# =========
yusr=$(cat /root/u.txt)
trimmed=$(echo "$yusr" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/"//g')
IFS="_" read -r ip user userid status url rurl phpv oslinux webserver <<<"$trimmed"


# USER LNX
# =========
userpas="rhasi4A911*"
adduser "$nuser"
usermod -a -G apache "$nuser"
chown -R apache:apache "$dpub"/{w,d,l}
chmod -R 770 "$dpub"/w
echo "cd $dpub/w" >>/home/"$nuser"/.bashrc
chown "$nuser:$nuser" /home/"$nuser"/.bashrc
echo "$nuser:$userpas" | chpasswd


# UTILITY
# =========
dnf clean all
dnf makecache

curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

dnf update -y
dnf install epel-release -y
dnf install dnf-utils -y
dnf install expect htop screen dos2unix wget nano zip unzip git -y


# HTTPD
# =========
diridx="DirectoryIndex index.html"
dnf install httpd -y
sed -i "s/$diridx/$diridx index.php/g" /etc/httpd/conf/httpd.conf
sed -i "s|DocumentRoot \"/var/www/html\"|DocumentRoot \"$dpub\/w\"|" /etc/httpd/conf/httpd.conf
sed -i "s|<Directory \"/var/www/html\"|<Directory \"$dpub\/w\"|" /etc/httpd/conf/httpd.conf
sed -i '155s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
sed -i "97i ServerName localhost" /etc/httpd/conf/httpd.conf
cat <<EOF | sudo tee -a /etc/httpd/conf/httpd.conf >/dev/null
ServerTokens Prod
ServerSignature Off
Header set X-Frame-Options "SAMEORIGIN"
Header set X-Content-Type-Options "nosniff"
<FilesMatch \.php$>
	SetHandler "proxy:fcgi://127.0.0.1:9000"
</FilesMatch>
EOF
dnf install certbot python3-certbot-apache -y


# MARIADB
# =========
# dnf install mariadb-server -y
# Tambahkan repositori MariaDB 10 ke sistem
echo "[mariadb]" | tee /etc/yum.repos.d/MariaDB.repo
echo "name = MariaDB" | tee -a /etc/yum.repos.d/MariaDB.repo
echo "baseurl = http://yum.mariadb.org/10.6/centos8-amd64" | tee -a /etc/yum.repos.d/MariaDB.repo
echo "gpgkey = https://yum.mariadb.org/RPM-GPG-KEY-MariaDB" | tee -a /etc/yum.repos.d/MariaDB.repo
echo "gpgcheck = 1" | tee -a /etc/yum.repos.d/MariaDB.repo
# dnf clean all
# dnf makecache
dnf config-manager --set-enabled powertools
dnf install rsync libaio lsof tar perl-DBI -y
dnf install boost-program-options socat -y
dnf install MariaDB-server MariaDB-client -y --disablerepo='*' --enablerepo='mariadb'
# dnf install MariaDB-server MariaDB-client -y

systemctl start mariadb
systemctl enable mariadb

[ -f "sets.txt" ] || wget https://github.com/nooufiy/ins-srv/raw/main/sets.txt
[ -f "sets.txt" ] || { exit 1; }
rpas="$(sed -n '1p' sets.txt)*"
mail="$(sed -n '2p' sets.txt)@outlook.com"

# Run mariadb-secure-installation
expect <<EOF
spawn mariadb-secure-installation
expect "Enter current password for root (enter for none):"
send "\r"
expect "Switch to unix_socket authentication"
send "Y\r"
expect "Change the root password?"
send "Y\r"
expect "New password:"
send "$rpas\r"
expect "Re-enter new password:"
send "$rpas\r"
expect "Remove anonymous users?"
send "Y\r"
expect "Disallow root login remotely?"
send "n\r"
expect "Remove test database and access to it?"
send "Y\r"
expect "Reload privilege tables now?"
send "Y\r"
expect eof
EOF

# mysql -u root <<EOF
# ALTER USER 'root'@'localhost' IDENTIFIED BY '${rpas}';
# DELETE FROM mysql.user WHERE User='';
# DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
# DROP DATABASE IF EXISTS test;
# DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
# FLUSH PRIVILEGES;
# EOF


# PHP
# =========
install_php() {
    # dnf install https://rpms.remirepo.net/enterprise/remi-release-8.7.rpm -y
    dnf install https://rpms.remirepo.net/enterprise/remi-release-8.rpm -y
    dnf -y module reset php

    if [[ "$phpv" == "php74" ]]; then
        dnf -y module enable php:remi-7.4
    elif [[ "$phpv" == "php81" ]]; then
        dnf -y module enable php:remi-8.1
    elif [[ "$phpv" == "php82" ]]; then
        dnf -y module enable php:remi-8.2
    elif [[ "$phpv" == "php83" ]]; then
        dnf -y module enable php:remi-8.3
    else
        echo "Versi PHP tidak valid. Gunakan 7.4, 8.1, 8.2, 8.3."
        exit 1
    fi

    dnf install php-fpm php-common php-mysqlnd php-xml php-gd php-opcache php-mbstring php-json php-cli php-geos php-mcrypt php-xmlrpc -y

    systemctl start php-fpm
    systemctl enable php-fpm
    systemctl status php-fpm
}
install_php
# php ini
sed -i 's/max_execution_time = 30/max_execution_time = 1500/g' /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 300M/g' /etc/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 300M/g' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php.ini
sed -i 's/expose_php = On/expose_php = Off/g' /etc/php.ini



# IMAGICK
# =========
dnf install -y gcc php-devel php-pear
dnf install -y ImageMagick ImageMagick-devel
yes | pecl install imagick
echo "extension=imagick.so" >/etc/php.d/imagick.ini
convert -version
dnf -y install libtool httpd-devel


# PHPMYADMIN
# =========
# dnf install -y phpmyadmin
dnf --enablerepo=epel,remi install phpmyadmin -y
ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin
wget https://github.com/nooufiy/ins-srv/raw/main/pmin.txt
mv /etc/httpd/conf.d/phpMyAdmin.conf /etc/httpd/conf.d/phpMyAdmin_bak
mv pmin.txt /etc/httpd/conf.d/phpMyAdmin.conf
chcon -u system_u -r object_r -t httpd_config_t /etc/httpd/conf.d/phpMyAdmin.conf


# WP
# =========
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
# wp --info


# FM
# =========
dirFM="_fm"
wget -O "$dpub"/w/"$dirFM".zip https://github.com/nooufiy/"$dirFM"/archive/main.zip && unzip "$dpub"/w/"$dirFM".zip -d "$dpub"/w && rm "$dpub"/w/"$dirFM".zip && mv "$dpub"/w/"$dirFM"-main "$dpub"/w/"$dirFM"
chown -R admin:admin "$dpub"/w/"$dirFM"
mv -f "$dpub"/w/"$dirFM"/getData.php "$dpub"/w/index.php
mv -f "$dpub"/w/"$dirFM"/.htaccess "$dpub"/w


# HTACCESS
# =========
httpaut="RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]"
sed -i "2i $httpaut" "$dpub"/w/.htaccess


# CLOUDFLARE
# =========
cd /tmp
wget https://github.com/nooufiy/ins-srv/raw/main/mod_cloudflare.so
mv mod_cloudflare.so /usr/lib64/httpd/modules/
chmod 755 /usr/lib64/httpd/modules/mod_cloudflare.so
# echo "LoadModule cloudflare_module /usr/lib64/httpd/modules/mod_cloudflare.so" >> /etc/httpd/conf.d/cloudflare.conf
chcon -t httpd_modules_t /usr/lib64/httpd/modules/mod_cloudflare.so


# LOGROTATE
# =========
dnf -y install logrotate
mv /etc/logrotate.d/httpd /etc/logrotate.d/httpd.bak
echo "$dpub/l/*log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root adm
    sharedscripts
    dateext
    dateformat -%Y-%m-%d
    postrotate
        /bin/systemctl reload httpd >/dev/null 2>&1 || true
    endscript
}" >/etc/logrotate.d/httpd
logrotate -f /etc/logrotate.d/httpd


# VH
# =========
vhs="manual" #dinamis/manual
if [ "$vhs" == "manual" ]; then
  # Vhost manual
  echo "IncludeOptional conf.s/*.conf" >>/etc/httpd/conf/httpd.conf
  wget https://github.com/nooufiy/ins-srv/raw/main/vh.sh
  mv vh.sh "$ds"
  chmod +x "$vh_sh"
  wget https://github.com/nooufiy/ins-srv/raw/main/setdom.sh
  mv setdom.sh "$ds"
  chmod +x "$ds/setdom.sh"
  wget https://github.com/nooufiy/ins-srv/raw/main/upd.sh
  mv upd.sh "$ds"
  chmod +x "$ds/upd.sh"

  confsdir="/etc/httpd/conf.s"
  confsfil="$confsdir/sites.conf"

  cat <<EOF | sudo tee -a "$ds/cnf.txt" >/dev/null
email=$mail
sites_conf_dir=$confsdir
sites_conf=$confsfil
home_dir=$dpub/w
home_dt=$dpub/d
home_lg=$dpub/l
processed_file=$ds/processed_domains.txt
sslbekup=$ds/ssl
pw=$rpas
rundir=$ds/r
EOF

  if [[ ! -d "/etc/httpd/conf.s" ]]; then
    mkdir -p "/etc/httpd/conf.s"
  fi
  if [[ ! -f "$ds/processed_domains.txt" ]]; then
    >"$ds/processed_domains.txt"
  fi
  script_path="/bin/bash $ds/vh.sh"
  service_mysts="/etc/systemd/system/mysts.service"

  cat <<EOF >"$service_mysts"
[Unit]
Description=mysts
After=network.target

[Service]
ExecStart=$script_path
Type=simple
Restart=always
StandardOutput=null
StandardError=null

[Install]
WantedBy=default.target
EOF

  systemctl daemon-reload
  systemctl enable mysts.service
  systemctl start mysts.service

else

  # Vhost dinamis
  sites_dir="$dpub/w"
  apache_conf="/etc/httpd/conf/httpd.conf"
  # Mengecek apakah modul vhost_alias sudah diaktifkan
  if ! grep -q "LoadModule vhost_alias_module" "$apache_conf"; then
    echo "LoadModule vhost_alias_module modules/mod_vhost_alias.so" | sudo tee -a "$apache_conf" >/dev/null
  fi
  # Mengaktifkan pengaturan VirtualDocumentRoot
  if ! grep -q "VirtualDocumentRoot" "$apache_conf"; then
    echo "VirtualDocumentRoot $sites_dir/%0" | sudo tee -a "$apache_conf" >/dev/null
  fi

  # Ssl

  wget https://github.com/nooufiy/ins-srv/raw/main/ssl.sh
  mv ssl.sh "$ds"

  sed -i "3i email=\"$mail\"" "$ssl_sh"
  sed -i "4i home_dir=\"$dpub/w\"" "$ssl_sh"
  chmod +x "$ssl_sh"

  script_path="/bin/bash $ds/ssl.sh"
  service_myssl="/etc/systemd/system/myssl.service"

  cat <<EOF >"$service_myssl"
[Unit]
Description=myssl
After=network.target

[Service]
ExecStart=$script_path
Type=simple
Restart=always
StandardOutput=null
StandardError=null

[Install]
WantedBy=default.target
EOF

  systemctl daemon-reload
  systemctl enable myssl.service
  systemctl start myssl.service
  systemctl status myssl.service

fi

elog="$dpub/l/${ip}_error.log"
clog="$dpub/l/${ip}_access.log"
cat <<EOF | sudo tee -a /etc/httpd/conf.s/sites.conf >/dev/null
<VirtualHost *:80>
    DocumentRoot $dpub/w
    ServerName $ip
    RewriteEngine on
    ErrorLog $elog
    CustomLog $clog combined
</VirtualHost>
EOF


# SSH2
# =====
dnf install libssh2 libssh2-devel make -y
# pecl install ssh2
dnf install php-ssh2 -y
# pecl install ssh2-1.3.1
# echo "extension=ssh2.so" | sudo tee /etc/php.d/ssh2.ini
# echo "extension=ssh2.so" >> /etc/php.d/ssh2.ini
echo "extension=ssh2.so" | tee /etc/php.d/20-ssh2.ini


# PERMISSION
# ===========
chown -R apache:apache "$dpub"
chcon -R system_u:object_r:httpd_sys_content_t "$dpub"/{w,l,d}
chcon -R -u system_u -r object_r -t httpd_sys_rw_content_t "$dpub"/{w,l,d}
# semanage boolean --modify --on httpd_can_network_connect
# /usr/sbin/setsebool -P httpd_can_network_connect 1
setsebool -P httpd_can_network_connect 1
systemctl enable httpd.service
systemctl restart httpd.service

sed -i "4i alias ceklog='sudo tail -f /var/log/httpd/error_log'" ~/.bashrc
source ~/.bashrc


# SELINUX
# ========
sestatus | grep -q 'disabled' && sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config && sudo setenforce 1


# IONCUBE
# =======
phpVersion=$(echo "$phpv" | sed -r 's/php([0-9])([0-9]+)/\1.\2/')
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
tar xzf ioncube_loaders_lin_x86-64.tar.gz
sudo mv ioncube/ioncube_loader_lin_"$phpVersion".so /usr/lib64/php/modules/
sudo tee /etc/php.d/00-ioncube.ini >/dev/null <<EOF
zend_extension = /usr/lib64/php/modules/ioncube_loader_lin_$phpVersion.so
EOF

chown -R apache:apache /usr/lib64/php/modules/ioncube_loader_lin_"$phpVersion".so
chcon -R -u system_u -r object_r -t httpd_sys_rw_content_t /usr/lib64/php/modules/ioncube_loader_lin_"$phpVersion".so
sudo chcon -t textrel_shlib_t /usr/lib64/php/modules/ioncube_loader_lin_"$phpVersion".so


# NODEJS
# =======
curl -sL https://rpm.nodesource.com/setup_current.x | sudo bash -
dnf install nodejs -y


# FIREWALLD
# ==========
dnf -y install firewalld
sed -i 's/^AllowZoneDrifting=.*/AllowZoneDrifting=no/' /etc/firewalld/firewalld.conf
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --zone=public --add-port=80/tcp
firewall-cmd --permanent --zone=public --add-port=443/tcp
firewall-cmd --permanent --zone=public --add-port=3306/tcp
firewall-cmd --permanent --zone=public --add-port=25/tcp
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-service=mysql
firewall-cmd --permanent --zone=public --add-service=smtp
firewall-cmd --permanent --add-port=9000/tcp
firewall-cmd --reload
# firewall-cmd --permanent --add-rich-rule='rule service name=ssh limit value="3/m" drop'


# SSH
# ====
sed -i "s/#Port 22/Port $aport/" /etc/ssh/sshd_config
firewall-cmd --permanent --zone=public --add-port="$aport"/tcp
firewall-cmd --zone=public --add-port="$aport"/tcp
firewall-cmd --reload
# firewall-cmd --zone=public --list-ports

dnf install policycoreutils -y
dnf whatprovides semanage
dnf provides *bin/semanage
dnf -y install policycoreutils-python
semanage port -a -t ssh_port_t -p tcp "$aport"
systemctl restart sshd
systemctl restart firewalld


# FINISH
# =======
curl -X POST -d "data=$trimmed" "$url/srv/"
echo "sv71=$url" >>"$ds/cnf.txt"
sed -i '/^$/d' "$ds/cnf.txt"
sed -i "s/dbmin/$rurl/g" /etc/httpd/conf.d/phpMyAdmin.conf
mv "$dpub/w/$dirFM" "$dpub/w/_$rurl"


# SERVICE RESTART
# ==============
service httpd restart
service php-fpm restart


# REMOVE
# ===========
rm -rf /root/sets.txt
rm -rf /root/u.txt


# SERVICE STATUS
# ==============
service httpd status
service mariadb status
service firewalld status
service sshd status
service mysts status


# DONE ===
# ===========
echo ""
echo "== [DONE] =="
echo ""

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo "in $execution_time seconds"
echo "done in $execution_time seconds" >/root/done.txt
