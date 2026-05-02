#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Louisa WiFi Switcher (GUI)
# @raycast.mode compact
# @raycast.packageName Network

# @raycast.argument1 { "type": "text", "placeholder": "輸入門市關鍵字", "optional": false }
# @raycast.icon ☕️
# @raycast.description Search, connect and verify Louisa Wi-Fi connection.

# --- Step 0: Configuration ---
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

JSON_PATH="${HOME}/.louisa_pwd.json"
GITHUB_URL="https://raw.githubusercontent.com/Watermelon-1234/LouisaInternetSwitch/refs/heads/main/louisa_pwd.json"
WIFI_SSID="LouisaCoffee"
WIFI_INTERFACE="en0"
SEARCH_TERM="$1"
QR_TEMP_IMG="/tmp/louisa_qr.png"

# --- Step 1: Sync JSON ---
if [ ! -f "$JSON_PATH" ]; then
    curl -sL "$GITHUB_URL" -o "$JSON_PATH"
fi

# --- Step 2: Filter Logic ---
MAP_RESULTS=$(jq -r --arg kw "$SEARCH_TERM" 'to_entries | .[] | select(.key | contains($kw)) | "\(.key)|\(.value)"' "$JSON_PATH")

if [ -z "$MAP_RESULTS" ]; then
    osascript -e "display alert \"❌ 找不到門市\" message \"找不到包含『$SEARCH_TERM』的門市。\" as critical"
    exit 1
fi

IFS=$'\n' read -rd '' -a MATCH_ARRAY <<< "$MAP_RESULTS"
MATCH_COUNT=${#MATCH_ARRAY[@]}

if [ "$MATCH_COUNT" -eq 1 ]; then
    SELECTED_STORE=$(echo "${MATCH_ARRAY[0]}" | cut -d'|' -f1)
    STORE_PWD=$(echo "${MATCH_ARRAY[0]}" | cut -d'|' -f2)
else
    AS_LIST="{"
    for item in "${MATCH_ARRAY[@]}"; do
        STORE_NAME=$(echo "$item" | cut -d'|' -f1)
        AS_LIST+="\"$STORE_NAME\", "
    done
    AS_LIST="${AS_LIST%, } }"

    SELECTED_STORE=$(osascript -e "
        tell application \"System Events\"
            activate
            set userChoice to choose from list $AS_LIST with prompt \"找到 $MATCH_COUNT 間門市，請選擇：\" with title \"路易莎 Wi-Fi\"
            if userChoice is false then return \"CANCELLED\"
            return item 1 of userChoice
        end tell
    ")
    if [ "$SELECTED_STORE" == "CANCELLED" ]; then exit 0; fi
    STORE_PWD=$(jq -r --arg store "$SELECTED_STORE" '.[$store]' "$JSON_PATH")
fi

# --- 解決問題 1：確保 Wi-Fi 開關是打開的 ---
networksetup -setairportpower "$WIFI_INTERFACE" on

# --- Step 3: QR Generation ---
qrencode -o "$QR_TEMP_IMG" -s 10 "WIFI:S:${WIFI_SSID};T:WPA;P:${STORE_PWD};;"
open -a "Preview" "$QR_TEMP_IMG"

# --- 解決問題 3：顯示等待中的 Alert，並丟到背景執行 ---
osascript -e "tell application \"System Events\" to activate" \
          -e "display alert \"📶 連線中…\" message \"正在嘗試連線至 $SELECTED_STORE...\n(連線成功後此視窗會自動關閉)\" as informational" &
# 記下剛才那個 Alert 的 Process ID (PID)
ALERT_PID=$! 

# 發送連線指令（異步）
networksetup -setairportnetwork "$WIFI_INTERFACE" "$WIFI_SSID" "$STORE_PWD" > /dev/null 2>&1 &

# --- 解決問題 2：改善驗證邏輯 (改用純 Bash 提高抓取精準度) ---
TIMEOUT_SEC=25
IS_CONNECTED=false

for (( i=1; i<=TIMEOUT_SEC; i++ )); do
    # 檢查當前 SSID，使用 grep -q 靜默比對
    if networksetup -getairportnetwork "$WIFI_INTERFACE" | grep -q "$WIFI_SSID"; then
        IS_CONNECTED=true
        break
    fi
    sleep 1
done

# --- 殺掉等待中的 Alert ---
# 不管連線成功或失敗，都把剛剛那個卡在背景的 Alert 關閉 (2>/dev/null 隱藏除錯訊息)
kill $ALERT_PID 2>/dev/null

# --- Step 5: Final UI ---
if [ "$IS_CONNECTED" = true ]; then
    osascript -e "tell application \"System Events\" to activate" \
              -e "display alert \"✅ 連線成功！\" message \"已成功連線至 $SELECTED_STORE。\n手機可直接掃描預覽程式中的 QR Code 分享。\" as informational"
else
    osascript -e "tell application \"System Events\" to activate" \
              -e "display alert \"⚠️ 連線逾時或失敗\" message \"指令已發送但尚未偵測到連線。\n\n1. 請確認是否在門市收訊範圍內。\n2. 密碼為：$STORE_PWD\n3. 建議點擊右上角 Wi-Fi 圖示手動確認。\" as warning"
fi

exit 0