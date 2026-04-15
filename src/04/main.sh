#!/bin/bash

# ----------------------------------------------------------------------
# Безопасное получение значения ключа из конфигурационного файла.
# Если файл не существует или ключ не найден, возвращает значение по умолчанию.
# ----------------------------------------------------------------------
get_config() {
    local key="$1"
    local default="$2"
    local file="$3"

    if [ -f "$file" ]; then
        # Ищем ключ и сохраняем результат
        local result
        result=$(awk -F= -v k="$key" '$1 == k { print substr($0, index($0,"=")+1); exit }' "$file" 2>/dev/null)
        if [ -n "$result" ]; then
            echo "$result"
        else
            echo "$default"
        fi
    else
        echo "$default"
    fi
}

# ----------------------------------------------------------------------
# Значения по умолчанию и чтение конфигурации
# ----------------------------------------------------------------------


# Цветовая схема по умолчанию (в соответствии с примером задания)
DEFAULT_BG1=6    # чёрный фон для названий
DEFAULT_FG1=1    # белый шрифт для названий
DEFAULT_BG2=2    # красный фон для значений
DEFAULT_FG2=4    # синий шрифт для значений

CONFIG_FILE="./color.config"

# Получаем значения с учётом конфигурационного файла (если он есть)
BG1=$(get_config "column1_background" "$DEFAULT_BG1" "$CONFIG_FILE")
FG1=$(get_config "column1_font_color" "$DEFAULT_FG1" "$CONFIG_FILE")
BG2=$(get_config "column2_background" "$DEFAULT_BG2" "$CONFIG_FILE")
FG2=$(get_config "column2_font_color" "$DEFAULT_FG2" "$CONFIG_FILE")

# Инициализируем флаги значением false
BG1_IS_DEFAULT=false
FG1_IS_DEFAULT=false
BG2_IS_DEFAULT=false
FG2_IS_DEFAULT=false

# --- Фон названий ---
if [ "$BG1" = "$DEFAULT_BG1" ]; then
    if ! grep -q "^column1_background=" "$CONFIG_FILE" 2>/dev/null; then
        BG1_IS_DEFAULT=true
    fi
fi

# --- Шрифт названий ---
if [ "$FG1" = "$DEFAULT_FG1" ]; then
    if ! grep -q "^column1_font_color=" "$CONFIG_FILE" 2>/dev/null; then
        FG1_IS_DEFAULT=true
    fi
fi

# --- Фон значений ---
if [ "$BG2" = "$DEFAULT_BG2" ]; then
    if ! grep -q "^column2_background=" "$CONFIG_FILE" 2>/dev/null; then
        BG2_IS_DEFAULT=true
    fi
fi

# --- Шрифт значений ---
if [ "$FG2" = "$DEFAULT_FG2" ]; then
    if ! grep -q "^column2_font_color=" "$CONFIG_FILE" 2>/dev/null; then
        FG2_IS_DEFAULT=true
    fi
fi

# ----------------------------------------------------------------------
# Проверка корректности цветов
# ----------------------------------------------------------------------


for param in "$BG1" "$FG1" "$BG2" "$FG2"; do
    if ! [[ "$param" =~ ^[1-6]$ ]]; then
        echo "Error: color value '$param' is invalid. Must be 1..6."
        exit 1
    fi
done

if [ "$BG1" -eq "$FG1" ]; then
    echo "Error: Column 1 background and font colors must differ."
    exit 1
fi

if [ "$BG2" -eq "$FG2" ]; then
    echo "Error: Column 2 background and font colors must differ."
    exit 1
fi

# ----------------------------------------------------------------------
# Преобразование номеров цветов в ANSI
# ----------------------------------------------------------------------

# -------- Фон для названий --------
case $BG1 in
    1) ANSI_BG1=47 ;;    # белый
    2) ANSI_BG1=41 ;;    # красный
    3) ANSI_BG1=42 ;;    # зелёный
    4) ANSI_BG1=44 ;;    # синий
    5) ANSI_BG1=45 ;;    # пурпурный
    6) ANSI_BG1=40 ;;    # чёрный
esac

# -------- Шрифт для названий --------
case $FG1 in
    1) ANSI_FG1=37 ;;    # белый
    2) ANSI_FG1=31 ;;    # красный
    3) ANSI_FG1=32 ;;    # зелёный
    4) ANSI_FG1=34 ;;    # синий
    5) ANSI_FG1=35 ;;    # пурпурный
    6) ANSI_FG1=30 ;;    # чёрный
esac

# -------- Фон для значений --------
case $BG2 in
    1) ANSI_BG2=47 ;;    # белый
    2) ANSI_BG2=41 ;;    # красный
    3) ANSI_BG2=42 ;;    # зелёный
    4) ANSI_BG2=44 ;;    # синий
    5) ANSI_BG2=45 ;;    # пурпурный
    6) ANSI_BG2=40 ;;    # чёрный
esac

# -------- Шрифт для значений --------
case $FG2 in
    1) ANSI_FG2=37 ;;    # белый
    2) ANSI_FG2=31 ;;    # красный
    3) ANSI_FG2=32 ;;    # зелёный
    4) ANSI_FG2=34 ;;    # синий
    5) ANSI_FG2=35 ;;    # пурпурный
    6) ANSI_FG2=30 ;;    # чёрный
esac


# ----------------------------------------------------------------------
# Сбор системной информации
# ----------------------------------------------------------------------

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

HOSTNAME=$(hostname)

tz_name=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null)
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

# ----------------------------------------------------------------------
# Формирование вывода
# Используем heredoc паттерн для создания многострочного текста с подстановкой переменных.
# ----------------------------------------------------------------------
print_line() {
    # $1 – название параметра (например, "HOSTNAME")
    # $2 – значение параметра
    printf "\e[${ANSI_BG1};${ANSI_FG1}m%-15s\e[0m = \e[${ANSI_BG2};${ANSI_FG2}m%s\e[0m" "$1" "$2"
}

color_name() {
    case $1 in
        1) echo "white"  ;;
        2) echo "red"    ;;
        3) echo "green"  ;;
        4) echo "blue"   ;;
        5) echo "purple" ;;
        6) echo "black"  ;;
    esac
}

format_scheme_line() {
    local label="$1"
    local value="$2"
    local is_default="$3"
    local color_str=$(color_name "$value")
    if $is_default; then
        printf "%-20s = default (%s)" "$label" "$color_str"
    else
        printf "%-20s = %d (%s)" "$label" "$value" "$color_str"
    fi
}

METRICS=$(cat << EOF
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

COLORS_SCHEME=$(cat << EOF
$(format_scheme_line "Column 1 background" "$BG1" "$BG1_IS_DEFAULT")
$(format_scheme_line "Column 1 font color" "$FG1" "$FG1_IS_DEFAULT")
$(format_scheme_line "Column 2 background" "$BG2" "$BG2_IS_DEFAULT")
$(format_scheme_line "Column 2 font color" "$FG2" "$FG2_IS_DEFAULT")
EOF
)

# OUTPUT
echo "$METRICS"
echo ""
echo "$COLORS_SCHEME"