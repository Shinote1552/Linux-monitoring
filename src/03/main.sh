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

# ----------------------------------------------------------------------
# Проверка аргументов
# ----------------------------------------------------------------------

# Проверка: скрипт должен получить ровно 4 аргумента
if [ $# -ne 4 ]; then
    echo "Error: Need 4 arguments: <bg1> <fg1> <bg2> <fg2>"
    echo "Colors: 1-white 2-red 3-green 4-blue 5-purple 6-black"
    echo "Example: $0 1 2 4 6"
    exit 1
fi

# Проверка: каждый параметр должен быть числом от 1 до 6
for arg in "$@"; do
    if ! [[ "$arg" =~ ^[1-6]$ ]]; then
        echo "Error: '$arg' is not a valid color (must be 1..6)."
        exit 1
    fi
done

# Проверка: в каждой колонке цвет фона и цвет шрифта должны различаться
if [ "$1" -eq "$2" ]; then
    echo "Error: Label colors (bg=$1, fg=$2) must differ."
    exit 1
fi

if [ "$3" -eq "$4" ]; then
    echo "Error: Value colors (bg=$3, fg=$4) must differ."
    exit 1
fi

# ----------------------------------------------------------------------
# Преобразование номеров цветов в ANSI
# ----------------------------------------------------------------------

# -------- Фон для названий (параметр 1) --------
case $1 in
    1) bg1=47 ;;    # белый
    2) bg1=41 ;;    # красный
    3) bg1=42 ;;    # зелёный
    4) bg1=44 ;;    # синий
    5) bg1=45 ;;    # пурпурный
    6) bg1=40 ;;    # чёрный
esac

# -------- Шрифт для названий (параметр 2) --------
case $2 in
    1) fg1=37 ;;    # белый
    2) fg1=31 ;;    # красный
    3) fg1=32 ;;    # зелёный
    4) fg1=34 ;;    # синий
    5) fg1=35 ;;    # пурпурный
    6) fg1=30 ;;    # чёрный
esac

# -------- Фон для значений (параметр 3) --------
case $3 in
    1) bg2=47 ;;    # белый
    2) bg2=41 ;;    # красный
    3) bg2=42 ;;    # зелёный
    4) bg2=44 ;;    # синий
    5) bg2=45 ;;    # пурпурный
    6) bg2=40 ;;    # чёрный
esac

# -------- Шрифт для значений (параметр 4) --------
case $4 in
    1) fg2=37 ;;    # белый
    2) fg2=31 ;;    # красный
    3) fg2=32 ;;    # зелёный
    4) fg2=34 ;;    # синий
    5) fg2=35 ;;    # пурпурный
    6) fg2=30 ;;    # чёрный
esac

# ----------------------------------------------------------------------
# Функция: print_line
# Помогает в цветном форматировании строки
# ----------------------------------------------------------------------
print_line() {
    # $1 - название параметра (например, "HOSTNAME")
    # $2 - значение параметра (например, "edmurepi")
    #
    # \e[${bg1};${fg1}m - включить цвет фона bg1 и цвет шрифта fg1
    # \e[0m - сбросить все атрибуты цвета
    # %-15s - выровнять название по левому краю с шириной 15 символов
    printf "\e[${bg1};${fg1}m%-15s\e[0m = \e[${bg2};${fg2}m%s\e[0m" "$1" "$2"
}

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
$(print_line "HOSTNAME" "$HOSTNAME")
$(print_line "TIMEZONE" "$TIMEZONE")
$(print_line "USER" "$USER")
$(print_line "OS" "$OS")
$(print_line "DATE" "$DATE")
$(print_line "UPTIME" "$UPTIME")
$(print_line "UPTIME_SEC" "$UPTIME_SEC")
$(print_line "IP" "$IP")
$(print_line "MASK" "$MASK")
$(print_line "GATEWAY" "$GATEWAY")
$(print_line "RAM_TOTAL" "$RAM_TOTAL")
$(print_line "RAM_USED" "$RAM_USED")
$(print_line "RAM_FREE" "$RAM_FREE")
$(print_line "SPACE_ROOT" "$SPACE_ROOT")
$(print_line "SPACE_ROOT_USED" "$SPACE_ROOT_USED")
$(print_line "SPACE_ROOT_FREE" "$SPACE_ROOT_FREE")
EOF
)

echo "$OUTPUT"
