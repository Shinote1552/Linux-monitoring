#!/bin/bash

# ----------------------------------------------------------------------
# Скрипт принимает один параметр - путь к директории, заканчивающийся '/'.
# Выводит статистику: количество папок/файлов, топ папок/файлов по размеру,
# распределение файлов по типам и время выполнения.
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# Проверка входных параметров
# ----------------------------------------------------------------------
if [ $# -ne 1 ]; then
    echo "Error: Expected exactly one argument — a directory path ending with '/'."
    echo "Usage: $0 /path/to/directory/"
    exit 1
fi

TARGET_DIR="$1"

# Путь должен заканчиваться на '/'
if [[ "${TARGET_DIR: -1}" != "/" ]]; then
    echo "Error: Directory path must end with '/'."
    exit 1
fi

# Проверяем, что директория существует и доступна для чтения
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: '$TARGET_DIR' is not a directory or does not exist."
    exit 1
fi
if [ ! -r "$TARGET_DIR" ] || [ ! -x "$TARGET_DIR" ]; then
    echo "Error: No read permission for '$TARGET_DIR'."
    exit 1
fi

# Удобный конвертор вместо отдельных преобразований(KB, MB, GB и т.д., по деволту значение MB(Mi))
format_size() {
    numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1 B"
}

# Краткое описание типа файла (до первой запятой)
get_file_type() {
    file -b "$1" 2>/dev/null | cut -d',' -f1
}

# Подсчёт строк (если команда ничего не вывела, вернёт 0)
count_lines() {
    wc -l 2>/dev/null | tr -d ' '
}

START_TIME=$(date +%s.%N)

echo "Analyzing '$TARGET_DIR' ..."

# --- Общее количество папок (включая корневую и все вложенные) ---
TOTAL_FOLDERS=$(find "$TARGET_DIR" -type d 2>/dev/null | count_lines)

# --- Топ-5 папок по размеру (сортируем по убыванию числового значения) ---
# du -h выдаёт "размер\tпуть", sort -h сортирует по человекочитаемым числам
TOP5_FOLDERS=$(du -h --max-depth=1 "$TARGET_DIR" 2>/dev/null \
    | sort -hr \
    | head -5 \
    | awk '{ printf "%d - %s, %s\n", NR, $2, $1 }')

if [ -z "$TOP5_FOLDERS" ]; then
    TOP5_FOLDERS="(no subfolders)"
fi

TOTAL_FILES=$(find "$TARGET_DIR" -type f 2>/dev/null | count_lines)
CONF_FILES=$(find "$TARGET_DIR" -type f -name "*.conf" 2>/dev/null | count_lines)
LOG_FILES=$(find "$TARGET_DIR" -type f -name "*.log" 2>/dev/null | count_lines)
EXEC_FILES=$(find "$TARGET_DIR" -type f -executable 2>/dev/null | count_lines)
SYMLINKS=$(find "$TARGET_DIR" -type l 2>/dev/null | count_lines)
ARCHIVE_FILES=$(find "$TARGET_DIR" -type f \( \
    -name "*.zip" -o -name "*.tar" -o -name "*.gz" -o -name "*.bz2" \
    -o -name "*.7z" -o -name "*.rar" -o -name "*.xz" -o -name "*.tgz" \
    \) 2>/dev/null | count_lines)

# --- Текстовые файлы через анализ MIME-типа --- 
TEXT_FILES=$(find "$TARGET_DIR" -type f -exec file {} \; 2>/dev/null \
    | grep -c 'ASCII text\|UTF-8 text' || echo 0)

# --- Топ-10 самых больших файлов с указанием типа --- 
TOP10_FILES=$(find "$TARGET_DIR" -type f -printf "%s\t%p\n" 2>/dev/null \
    | sort -nr \
    | head -10 \
    | while IFS=$'\t' read -r size path; do
        type_info=$(get_file_type "$path")
        human_size=$(format_size "$size")
        echo "$path, $human_size, $type_info"
    done \
    | awk '{ print NR " - " $0 }')

if [ -z "$TOP10_FILES" ]; then
    TOP10_FILES="(no files found)"
fi

#  --- Топ‑10 исполняемых файлов (path, size and MD5 hash of file)--- 
TOP10_EXEC=$(find "$TARGET_DIR" -type f -executable -printf "%s\t%p\n" 2>/dev/null \
    | sort -nr \
    | head -10 \
    | while IFS=$'\t' read -r size path; do
        hash=$(md5sum "$path" 2>/dev/null | cut -d' ' -f1)
        human_size=$(format_size "$size")
        echo "$path, $human_size, $hash"
    done \
    | awk '{ print NR " - " $0 }')

if [ -z "$TOP10_EXEC" ]; then
    TOP10_EXEC="(no executable files found)"
fi

END_TIME=$(date +%s.%N)
EXEC_TIME=$(echo "$END_TIME - $START_TIME" | bc -l | awk '{ printf "%.1f", $0 }')

OUTPUT=$(cat << EOF
Total number of folders (including all nested ones) = $TOTAL_FOLDERS
TOP 5 folders of maximum size arranged in descending order (path and size):
$TOP5_FOLDERS
Total number of files = $TOTAL_FILES
Number of:
Configuration files (with the .conf extension) = $CONF_FILES
Text files = $TEXT_FILES
Executable files = $EXEC_FILES
Log files (with the extension .log) = $LOG_FILES
Archive files = $ARCHIVE_FILES
Symbolic links = $SYMLINKS
TOP 10 files of maximum size arranged in descending order (path, size and type):
$TOP10_FILES
TOP 10 executable files of the maximum size arranged in descending order (path, size and MD5 hash of file):
$TOP10_EXEC
Script execution time (in seconds) = $EXEC_TIME
EOF
)

# OUTPUT
echo "$OUTPUT"