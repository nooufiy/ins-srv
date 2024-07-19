#!/bin/bash

sed -i 's/\r//g' /rs/cnf.txt
source "/rs/cnf.txt"
newdtdom="$1"
ndtdom=(${newdtdom//_/ })
newdomain="${ndtdom[0]}"
platform="${ndtdom[1]}"
ip="${ndtdom[2]}"
enkod="${ndtdom[3]}"
userid="${ndtdom[4]}"
status="${ndtdom[5]}"

> "$rundir/active/$newdomain.txt"

elog="$home_lg/$newdomain"_"error.log"
clog="$home_lg/$newdomain"_"access.log combined"

is_root_domain() {
    local domain="$1"
    local tld=$(grep -E '^[^//]' /rs/public_suffix_list.dat | grep -F ".$(echo "$domain" | rev | cut -d. -f1-2 | rev)" || true)
    [ -z "$tld" ] && [ "$(echo "$domain" | awk -F'.' '{print NF}')" -eq 2 ] || [ "$(echo "$domain" | awk -F".$tld" '{print NF-1}')" -eq 1 ]
    return $?
}

generate_vhost() {
    local home_dir="$1" newdomain="$2" elog="$3" clog="$4"
    cat <<EOL
<VirtualHost *:80>
    DocumentRoot $home_dir/$newdomain
    ServerName $newdomain
    $(is_root_domain "$newdomain" || echo "ServerAlias www.$newdomain")
    RewriteEngine on
    ErrorLog $elog
    CustomLog $clog
</VirtualHost>
EOL
}

generate_vhost "$home_dir" "$newdomain" "$elog" "$clog"

mkdir "$home_dir/$newdomain"

timestamp=$(date +%s)
short=$(echo "$newdomain" | sed 's/\.//g' | cut -c 1-5)
rand_chars=$(head /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)
dbuser="${short}_usr_${rand_chars}"
dbname="${short}_nam_${rand_chars}"
dbpass="${short}_pas_${timestamp}"


if ! mysql -u root -p"$pw" -e "SELECT COUNT(*) FROM mysql.user WHERE user = '$dbuser';" | grep -q '1'; then
	mysql -u root -p"$pw" -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
fi

if mysql -u root -p"$pw" -e "USE $dbname;" ; then
	mysql -u root -p"$pw" -e "DROP DATABASE $dbname;"
fi

mysql -u root -p"$pw" -e "CREATE DATABASE IF NOT EXISTS $dbname;"
mysql -u root -p"$pw" -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';"
mysql -u root -p"$pw" -e "FLUSH PRIVILEGES;"

# BUILD WP
if [ "$platform" = "wordpress" ]; then

	wget -P "$home_dir/$newdomain" https://wordpress.org/latest.tar.gz
	tar -zxvf "$home_dir/$newdomain/latest.tar.gz" -C "$home_dir/$newdomain" --strip-components=1
	cp "$home_dir/$newdomain/wp-config-sample.php" "$home_dir/$newdomain/wp-config.php"
	sed -i "s/database_name_here/$dbname/g" "$home_dir/$newdomain/wp-config.php"
	sed -i "s/username_here/$dbuser/g" "$home_dir/$newdomain/wp-config.php"
	sed -i "s/password_here/$dbpass/g" "$home_dir/$newdomain/wp-config.php"

perl -i -pe'
BEGIN {
	@chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
	push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
	sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
}
s/put your unique phrase here/salt()/ge
' "$home_dir/$newdomain/wp-config.php"

	[ ! -d "$home_dir/$newdomain/wp-content/uploads" ] && mkdir "$home_dir/$newdomain/wp-content/uploads"

	cd "$home_dir/$newdomain"

# echo -e "$htawp" > "$home_dir/$newdomain/.htaccess"
cat <<EOF > "$home_dir/$newdomain/.htaccess"
# BEGIN WordPress

<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
    RewriteBase /
    RewriteRule ^index\.php$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [L]
</IfModule>

# END WordPress
EOF

wp core install --url="http://$newdomain/" --title="$newdomain" --admin_user="admin" --admin_password=rahasi4a911* --admin_email="$email" --allow-root
wp option update blogdescription "" --allow-root
wp rewrite structure '/%postname%/' --hard --allow-root

# BUILD NATIVE
else
	urlFileZip=$(echo "$enkod" | base64 -d)
	# Mengunduh file zip dari URL
	if wget -q "$urlFileZip"; then
		unzip -o temp.zip -d "$home_dir/$newdomain" # Mengekstrak isi file zip ke direktori tujuan
		rm temp.zip
	else
		echo "fail download."
	fi

fi

chown -R apache:apache "$home_dir/$newdomain"
# chmod -R 755 "$home_dir/$newdomain"
chcon -R system_u:object_r:httpd_sys_content_t "$home_dir/$newdomain"
chcon -R -u system_u -r object_r -t httpd_sys_rw_content_t "$home_dir/$newdomain"

# SSL

[ ! -f /rs/public_suffix_list.dat ] && curl -s https://publicsuffix.org/list/public_suffix_list.dat -o /rs/public_suffix_list.dat

check_certificate() {
    local domain="$1"
    certbot certificates | grep -qE "Domains:.*\b$domain\b" && {
        certbot certificates | grep -A 1 -E "Domains:.*\b$domain\b" | grep -q "VALID" && return 0
        return 1
    }
    return 2
}

manage_ssl() {
    local action="$1"
    local domain="$2"
    local email="$3"
    if is_root_domain "$domain"; then
        [ "$action" == "add" ] && certbot --apache -d "$domain" -d "www.$domain" --email "$email" --agree-tos -n
        [ "$action" == "renew" ] && certbot renew --cert-name "$domain"
    else
        [ "$action" == "add" ] && certbot --apache -d "$domain" --email "$email" --agree-tos -n
        [ "$action" == "renew" ] && certbot renew --cert-name "$domain"
    fi
}

check_certificate "$newdomain"
status=$?

[ "$status" -eq 0 ] && manage_ssl "renew" "$newdomain" "$email"
[ "$status" -eq 1 ] && manage_ssl "add" "$newdomain" "$email"
[ "$status" -eq 2 ] && manage_ssl "add" "$newdomain" "$email"

cleaned_newdomain=$(echo "$newdomain" | tr -d '\r')
echo "$cleaned_newdomain,$dbuser,$dbname,$dbpass" >> "$processed_file"
dondom=${newdtdom//_setup/_done}
curl -X POST -d "data=$dondom" "$sv71/dom.php"
sed -i "s/$newdtdom/$dondom/g" "$home_dt/domains.txt"
service httpd graceful

rm -rf "$rundir/active/$newdomain.txt"
# sed -i "/$newdomain/d" "$rundir/rundom.txt"
