#!/bin/bash

dmdir="/sites/d"
stdir="/sites/w"
rsdir="/rs"
vhfl="$rsdir/vh.sh"
setdomfl="$rsdir/setdom.sh"
cnffl="$rsdir/cnf.txt"

service mysts stop

download_and_move() {
    local file="$1"
    local url="https://github.com/nooufiy/ilamp74/raw/main/$file"

    if [[ -f "$file" ]]; then
        rm -rf "$file"
    fi

    wget -O "$rsdir/$file" "$url"
    dos2unix "$rsdir/$file"
    chmod +x "$rsdir/$file"
}

download_and_move "vh.sh"
download_and_move "setdom.sh"
download_and_move "cnf.txt"

if [ ! -d "$dmdir" ]; then
    mkdir -p "$dmdir"
fi

if [ -f "$stdir/domains.txt" ] && [ ! -f "$dmdir/domains.txt" ]; then
    mv "$stdir/domains.txt" "$dmdir"
fi

if [ -f "$stdir/.htaccess" ]; then
    rm -rf "$stdir/.htaccess"
fi

wget -O "$stdir/.htaccess" https://github.com/nooufiy/_fm/raw/main/.htaccess
chown -R apache:apache "$stdir/.htaccess"

if [ -f "$stdir/getData.php" ]; then
    rm -rf "$stdir/getData.php"
fi

if [ -f "$stdir/index.php" ]; then
    rm -rf "$stdir/index.php"
fi

wget -O "$stdir/index.php" https://github.com/nooufiy/_fm/raw/main/getData.php
chown -R apache:apache "$stdir/index.php"

service mysts start
rm -rf "$dmdir/upd.txt"
