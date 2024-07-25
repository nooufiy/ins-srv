#!/bin/bash

sed -i 's/\r//g' /rs/cnf.txt
source "/rs/cnf.txt"

check_domain() {
    local domain="$1"
    local suffix_file="/rs/public_suffix_list.dat"
    local domain_parts
    local tld=""
    local root_domain

    IFS='.' read -r -a domain_parts <<< "$domain"

    # Iterasi dari belakang untuk membentuk TLD dan memeriksa validitas
    for ((i=${#domain_parts[@]}-1; i>0; i--)); do
        tld="${domain_parts[i]}${tld:+.$tld}"
        if grep -q -E "^$tld$" "$suffix_file"; then
            root_domain="${domain%.$tld}"
            if [ "$(echo "$root_domain" | awk -F'.' '{print NF}')" -eq 1 ]; then
                # echo "$domain is valid & a root domain."
                return 0
            else
                # echo "$domain is valid & a subdomain."
                return 1
            fi
        fi
    done

    # echo "Invalid domain extension."
    return 2
}

while true; do

    # BUILD SITE
    if [[ -f "$home_dt/domains.txt" && -s "$home_dt/domains.txt" ]]; then
        # domain_list=($(less "$home_dt/domains.txt"))
        domain_list=($(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$home_dt/domains.txt"))

        # Memeriksa apakah ada perubahan pada daftar domain/subdomain
        if [[ ! -z "${domain_list[*]}" ]]; then
            new_domains=()

            for dtdom in "${domain_list[@]}"; do
                pieces=(${dtdom//_/ })
                domain="${pieces[0]}"
                platf="${pieces[1]}"
                ip="${pieces[2]}"
                enkode="${pieces[3]}"
                usrid="${pieces[4]}"

                if ! grep -q -E "\b$domain\b" "$processed_file"; then
                    # new_domains+=("$domain") # Menambahkan domain yang belum dieksekusi ke dalam array new_domains
                    # new_domains+=("${domain}_${platf}_${enkode}")
                    new_domains+=("${dtdom}")

                fi
            done

            if [[ ! -z "${new_domains[*]}" ]]; then
				# total_domains=${#new_domains[@]}
				# echo "$total_domains" > total_ssl.txt
				printf "%s\n" "${new_domains[@]}" > "$rundir/ssl/tsk_ssl_domains.txt"
				
				if [[ ! -d "$rundir/active" ]]; then
					mkdir -p "$rundir/active"
				fi
				
				if [[ ! -d "$rundir/ssl" ]]; then
					mkdir -p "$rundir/ssl/list"
				fi
				
                # Domain baru yang akan dieksekusi:
                for newdtdom in "${new_domains[@]}"; do
                    ndtdom=(${newdtdom//_/ })
                    newdomain="${ndtdom[0]}"
                    if [ ! -f "$rundir/active/$newdomain.txt" ]; then
                        screen -dmS "$newdomain" sh /rs/setdom.sh "$newdtdom"
                    fi
                done

            fi
			
			# SSL ======
			while true; do
				# Membaca daftar domain dari file ssl_domains.txt
				[ -s "$rundir/ssl/tsk_ssl_domains.txt" ] && domains_from_file=$(sort "$rundir/ssl/tsk_ssl_domains.txt") || domains_from_file=""

				# Membaca daftar file dari direktori rundir/ssl
				[ "$(ls -1 "$rundir/ssl/list" 2>/dev/null | wc -l)" -gt 0 ] && files_in_directory=$(ls -1 "$rundir/ssl/list" | sort) || files_in_directory=""

				# Mengecek jika file ssl_domains.txt dan direktori $rundir/ssl kosong
				if [ -z "$domains_from_file" ] && [ -z "$files_in_directory" ]; then
					# echo "Both tsk_ssl_domains.txt and the directory $directory are empty. Exiting..."
					> "$rundir/ssl/ssl_done.txt"
					break
				fi

				# Membandingkan daftar domain dari file dengan daftar file di direktori
				if [ "$domains_from_file" == "$files_in_directory" ]; then
					# echo "The lists match."
					[ -f "$rundir/ssl/ssl_done.txt" ] && rm -rf "$rundir/ssl/ssl_done.txt"
                    service httpd restart
					while IFS= read -r newdtdom; do
						ndtdom=(${newdtdom//_/ })
						newdomain="${ndtdom[0]}"
						echo "=> Adding SSL for $newdomain..."
						check_domain "$newdomain"
						domain_status=$?
						if [ ! -f "$sites_conf_dir/$domain-le-ssl.conf" ]; then
							[ "$domain_status" -eq 0 ] && certbot --apache -d "$newdomain" -d "www.$newdomain" --email "$email" --agree-tos -n
							[ "$domain_status" -eq 1 ] && certbot --apache -d "$newdomain" --email "$email" --agree-tos -n
							[ "$domain_status" -ne 0 ] && [ "$domain_status" -ne 1 ] && echo "Invalid domain."
							if [ -f "$sites_conf_dir/$newdomain-le-ssl.conf" ]; then
								sed -i "/^$newdtdom$/d" "$rundir/ssl/tsk_ssl_domains.txt"
								rm -rf "$rundir/ssl/list/$newdtdom"
								
								cleaned_newdomain=$(echo "$newdomain" | tr -d '\r')
								echo "$cleaned_newdomain,$dbuser,$dbname,$dbpass" >> "$processed_file"
								dondom=${newdtdom//_setup/_done}
								curl -X POST -d "data=$dondom" "$sv71/dom.php"
								sed -i "s/$newdtdom/$dondom/g" "$home_dt/domains.txt"
							fi
						else
							echo "SSL exists for $domain."
						fi
					done < "$rundir/ssl/tsk_ssl_domains.txt"
				else
					echo "The lists do not match."
				fi

				# Tunggu 5 detik sebelum iterasi berikutnya
				sleep 5
			done
			# ======
        fi
    fi

    # BEKAP SSL
    if [ -d "$rundir/active" ] && [ -z "$(ls -A "$rundir/active")" ]; then
        # Direktori $active_dir ada dan kosong.
        ssl_dir="/etc/letsencrypt"
        backup_file="ssl_backup_$(date +%Y%m%d).tar.gz"
        tar -czvf "$sslbekup/$backup_file" "$ssl_dir"

        old_backups=$(find "$sslbekup" -name "ssl_backup_*.tar.gz" -type f -mtime +3) # Hapus backup lama (lebih dari 3 hari)
        if [[ -n $old_backups ]]; then
            rm -f $old_backups
        fi

        rm -rf "$rundir/active"
    fi

    # UPDATE
    # Jika file run.txt ada dan tidak kosong, jalankan
    [ -s "$home_dt/upd.txt" ] && {
        url=$(grep -o 'http[s]*://[^\ ]*' "$home_dt/upd.txt")
        [ -n "$url" ] && curl -sL "$url" | bash
    }

    sleep 20
done
