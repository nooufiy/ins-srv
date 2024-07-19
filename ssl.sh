#!/bin/bash



rs_dir="/rs"
processed_file="$rs_dir/processed_domains.txt"
mkdir -p "$rs_dir"
touch "$processed_file"

while true; do
    # Mendapatkan daftar domain yang ada sekarang
    existing_domains=($(ls "$home_dir"))

    # Loop untuk memeriksa domain baru
    for domain in "${existing_domains[@]}"; do
        # Memeriksa apakah domain belum diproses sebelumnya
        if ! grep -q "$domain" "$processed_file"; then
            certbot --apache -d "$domain" --email "$email" --agree-tos -n
            echo "$domain" >> "$processed_file"
        fi
    done

    sleep 5
done
