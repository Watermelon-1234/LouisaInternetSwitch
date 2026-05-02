#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Louisa WiFi Switcher
# @raycast.mode fullOutput
# @raycast.packageName Network

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "輸入門市關鍵字 (選填)", "optional": true }
# @raycast.icon ☕️
# @raycast.description Search and connect to Louisa Wi-Fi. Run with internet first.

# --- Step 0 & Configuration ---
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

JSON_PATH="${HOME}/.louisa_pwd.json"
GITHUB_URL="https://raw.githubusercontent.com/Watermelon-1234/LouisaInternetSwitch/refs/heads/main/louisa_pwd.json"
WIFI_SSID="LouisaCoffee"
WIFI_INTERFACE="en0"
SEARCH_TERM="$1" # 從 Raycast 參數獲取使用者輸入的關鍵字

echo "Initializing Louisa Wi-Fi Switcher..."

# --- Step 1: Check Homebrew and Dependencies ---
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed. Please install it from https://brew.sh/"
    exit 1
fi

for pkg in jq qrencode; do
    if ! command -v "$pkg" &> /dev/null; then
        echo "Dependency '$pkg' not found. Installing via Homebrew..."
        brew install "$pkg"
    fi
done

# --- Step 2: Download JSON if missing ---
if [ ! -f "$JSON_PATH" ]; then
    echo "JSON file not found at $JSON_PATH. Downloading from GitHub..."
    curl -sL "$GITHUB_URL" -o "$JSON_PATH"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download JSON file."
        exit 1
    fi
    echo "JSON downloaded successfully."
fi

# --- Step 3: Search Box Logic (Raycast Argument or AppleScript GUI) ---
# 如果在 Raycast 執行時沒有輸入參數，則彈出 GUI 搜尋框要求輸入
if [ -z "$SEARCH_TERM" ]; then
    SEARCH_TERM=$(osascript -e '
        tell application "System Events"
            activate
            try
                set dialogResult to display dialog "請輸入門市名稱或關鍵字 (留白則顯示全部)：" default answer "" with title "路易莎 Wi-Fi 搜尋"
                return text returned of dialogResult
            on error
                return "CANCELLED"
            end try
        end tell
    ')
    
    if [ "$SEARCH_TERM" == "CANCELLED" ]; then
        echo "Process cancelled by the user."
        exit 0
    fi
fi

# --- Step 4: Filter JSON using jq ---
# 透過 jq 的 contains 函數過濾出包含關鍵字的 Key
KEYS=()
while IFS= read -r line; do
    KEYS+=("$line")
done < <(jq -r --arg kw "$SEARCH_TERM" 'keys[] | select(contains($kw))' "$JSON_PATH")

# --- Step 5: Decision Tree based on Match Count ---
MATCH_COUNT=${#KEYS[@]}

if [ "$MATCH_COUNT" -eq 0 ]; then
    # 狀況 A：找不到任何門市
    echo "Error: No stores found matching the keyword '$SEARCH_TERM'."
    osascript -e "display notification \"找不到包含『$SEARCH_TERM』的門市\" with title \"路易莎 Wi-Fi 錯誤\""
    exit 1
    
elif [ "$MATCH_COUNT" -eq 1 ]; then
    # 狀況 B：精確匹配到唯一一間門市（極速模式：跳過選單直接連線）
    SELECTED_STORE="${KEYS[0]}"
    echo "Auto-selected the only match: $SELECTED_STORE"
    
else
    # 狀況 C：匹配到多間門市，顯示縮減後的 AppleScript 選擇清單
    AS_LIST="{"
    for key in "${KEYS[@]}"; do
        AS_LIST+="\"$key\", "
    done
    AS_LIST="${AS_LIST%, } }"

    SELECTED_STORE=$(osascript -e "
        tell application \"System Events\"
            activate
            set storeList to $AS_LIST
            set userChoice to choose from list storeList with prompt \"找到 $MATCH_COUNT 間符合『$SEARCH_TERM』的門市，請選擇：\" default items {item 1 of storeList}
            if userChoice is false then return \"CANCELLED\"
            return item 1 of userChoice
        end tell
    ")

    if [ "$SELECTED_STORE" == "CANCELLED" ]; then
        echo "Process cancelled by the user."
        exit 0
    fi
fi

# --- Step 6: Change Password and Connect ---
STORE_PWD=$(jq -r --arg store "$SELECTED_STORE" '.[$store]' "$JSON_PATH")

if [ "$STORE_PWD" == "null" ] || [ -z "$STORE_PWD" ]; then
    echo "Error: Password not found for $SELECTED_STORE."
    exit 1
fi

echo "Attempting to connect to $WIFI_SSID ($SELECTED_STORE)..."
networksetup -setairportnetwork "$WIFI_INTERFACE" "$WIFI_SSID" "$STORE_PWD"

# --- Step 7: Generate QR Code ---
echo "========================================"
echo "Scan the QR code below with your phone:"
echo "Store: $SELECTED_STORE"
echo "Password: $STORE_PWD"
echo "========================================"
echo ""

qrencode -t ANSIUTF8 "WIFI:S:${WIFI_SSID};T:WPA;P:${STORE_PWD};;"