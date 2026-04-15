#!/bin/bash

# ----------------------------------------------------------------------
# Функция: cidr_to_mask
# Преобразует CIDR (например, 20) в маску подсети (255.255.240.0)
# ----------------------------------------------------------------------
cidr_to_mask() {
    local cidr=$1
    local host_bits=$((32 - cidr))
    local host_mask=$(( (1 << host_bits) - 1 ))
    # 0xFFFFFFFF = 4294967295 (32 бита единиц) или же 255.255.255.255
    local net_mask=$(( 0xFFFFFFFF ^ host_mask ))
    printf "%d.%d.%d.%d" \
        $(( (net_mask >> 24) & 255 )) \
        $(( (net_mask >> 16) & 255 )) \
        $(( (net_mask >> 8) & 255 )) \
        $(( net_mask & 255 ))
}

#
#
#

HOSTNAME=$(hostname)

tz_name=$(timedatectl show -p Timezone --value)
# Я решил просто оставить первые три символа от +HHMM
tz_offset=$(date +%z | cut -c1-3)

TIMEZONE="$tz_name UTC $tz_offset"
USER=$(whoami)
OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
DATE=$(date "+%d %b %Y %H:%M:%S")
UPTIME=$(uptime -p | cut -d' ' -f2-)
UPTIME_SEC=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
IP=$(hostname -I | cut -d' ' -f1)

if [ -n "$IP" ]; then
    cidr=$(ip -4 -o addr show | grep " $IP/" | awk '{print $4}' | cut -d/ -f2)
fi

if [ -n "$cidr" ]; then
    case "$cidr" in
        8)  MASK="255.0.0.0" ;;
        16) MASK="255.255.0.0" ;;
        24) MASK="255.255.255.0" ;;
        32) MASK="255.255.255.255" ;;
        *)  MASK=$(cidr_to_mask "$cidr") ;;
    esac
fi

GATEWAY=$(ip route show default | awk '/default/ {print $3; exit}')


mem_total_kb=$(grep MemTotal /proc/meminfo | tr -s ' ' | cut -d' ' -f2)
mem_avail_kb=$(grep MemAvailable /proc/meminfo | tr -s ' ' | cut -d' ' -f2)
mem_used_kb=$((mem_total_kb - mem_avail_kb))

# Переводим килобайты в гигабайты.
# 1 ГБ = 1024 * 1024 = 1048576 КБ.
RAM_TOTAL=$(awk "BEGIN {printf \"%.3f GB\", $mem_total_kb/1048576}")
RAM_USED=$(awk  "BEGIN {printf \"%.3f GB\", $mem_used_kb/1048576}")
RAM_FREE=$(awk  "BEGIN {printf \"%.3f GB\", $mem_avail_kb/1048576}")

# 1 МБ = 1024 КБ.
SPACE_ROOT=$(df -k / | tail -1 | awk '{printf "%.2f MB", $2/1024}')
SPACE_ROOT_USED=$(df -k / | tail -1 | awk '{printf "%.2f MB", $3/1024}')
SPACE_ROOT_FREE=$(df -k / | tail -1 | awk '{printf "%.2f MB", $4/1024}')

# Используем heredoc паттерн для создания многострочного текста с подстановкой переменных.
OUTPUT=$(cat << EOF
HOSTNAME = $HOSTNAME
TIMEZONE = $TIMEZONE
USER = $USER
OS = $OS
DATE = $DATE
UPTIME = $UPTIME
UPTIME_SEC = $UPTIME_SEC
IP = $IP
MASK = $MASK
GATEWAY = $GATEWAY
RAM_TOTAL = $RAM_TOTAL
RAM_USED = $RAM_USED
RAM_FREE = $RAM_FREE
SPACE_ROOT = $SPACE_ROOT
SPACE_ROOT_USED = $SPACE_ROOT_USED
SPACE_ROOT_FREE = $SPACE_ROOT_FREE
EOF
)

# Выводим информацию на экран
echo "$OUTPUT"

# ----------------------------------------------------------------------
# СОХРАНЕНИЕ В ФАЙЛ
# ----------------------------------------------------------------------
read -p "Save data to file? (Y/N) " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    # Имя файла: DD_MM_YY_HH_MM_SS.status
    filename="$(date '+%d_%m_%y_%H_%M_%S').status"
    echo "$OUTPUT" > "$filename"
    echo "Data saved to $filename"
else
    echo "Save cancelled."
fi
