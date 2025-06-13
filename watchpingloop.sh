#!/bin/ash
# Alamat host yang ingin Anda ping
HOST="BUG"
# Variabel untuk menghitung berapa kali ping gagal
failed_count=0

# Jumlah maksimum ping fail berturut-turut sebelum mengaktifkan mode pesawat
pingfail=5

# Fungsi untuk mengirim pesan Telegram
kirim_pesan_telegram() {
    local modem="MODEM"
    local bot_token="GANTI TOKENNYA "
    local chat_id="CHAT ID JUGA"

    local message="════ CHANGE IP ════
📱 Modem : $modem
🌐 Old IP : $1
🌐 New IP : $2
════════════════

    # Mengirim pesan menggunakan Bot API Telegram dengan parse_mode Markdown
    curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" -d "chat_id=$chat_id&text=$message&parse_mode=Markdown" > /dev/null
    echo "Pesan Telegram terkirim."
}

# Fungsi untuk mengecek kembali koneksi setelah mengaktifkan mode pesawat
test_ping_after_modpes() {
    local count=0
    local max_attempts=10
    local success_message="Host: $HOST  +++ONLINE+++"

    while [ $count -lt $max_attempts ]; do
        local ping_result=$(ping -c 1 -W 1 $HOST | grep "time=")
        if [ -n "$ping_result" ]; then
            echo "$success_message"
            return 0  # Koneksi berhasil dikembalikan
        fi
        count=$((count + 1))
        sleep 1
    done
    echo "Gagal mengembalikan koneksi setelah $max_attempts percobaan."
    return 1  # Koneksi tidak berhasil dikembalikan
}

# Loop untuk melakukan ping dan mengaktifkan/menonaktifkan mode pesawat
while true; do
    PING_RESULT=$(ping -c 1 -W 1 $HOST 2>&1)
    if echo "$PING_RESULT" | grep "time=" > /dev/null; then
        echo "Host: $HOST  +++ONLINE+++."
        failed_count=0  # Reset hitungan kegagalan jika host berhasil dijangkau
    else
        echo "Host: $HOST  _____---OFFLINE---_____."
        failed_count=$((failed_count + 1))  # Tingkatkan hitungan kegagalan
        if [ $failed_count -ge $pingfail ]; then
            echo "Gagal ping sebanyak $pingfail kali..."

            # Mendapatkan alamat IP modem dari perangkat HP
            ipsekarang1=$(adb shell ip -f inet addr show rmnet0 | awk '/inet / {print $2}' | cut -d'/' -f1)
            ipsekarang2=$(adb shell ip -f inet addr show rmnet_data1 | awk '/inet / {print $2}' | cut -d'/' -f1)
            ipOld="${ipsekarang1}${ipsekarang2}"
            echo "IP Address Modem HP: $ipOld"

            # Toggle Airplane Mode
            adb shell settings put global airplane_mode_on 1
            adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
            sleep 3
            adb shell settings put global airplane_mode_on 0
            adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false
            echo "Mode Pesawat Mati"
            sleep 10

            # Mengirim pesan Telegram setelah mengubah IP
            ipsekarang1=$(adb shell ip -f inet addr show rmnet0 | awk '/inet / {print $2}' | cut -d'/' -f1)
            ipsekarang2=$(adb shell ip -f inet addr show rmnet_data1 | awk '/inet / {print $2}' | cut -d'/' -f1)
            ipNew="${ipsekarang1}${ipsekarang2}"
            echo "IP Baru: $ipNew"
            
            # Coba untuk menguji kembali koneksi setelah mengaktifkan mode pesawat
            test_ping_after_modpes
            if [ $? -eq 0 ]; then
                kirim_pesan_telegram "$ipOld" "$ipNew"
            fi
        fi
    fi
    sleep 1  # Tunggu sebelum memeriksa koneksi lagi 
done
