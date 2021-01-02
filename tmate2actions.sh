#!/usr/bin/env bash
#
# Copyright (c) 2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/ssh2actions
# File name：tmate2actions.sh
# Description: Connect to Github Actions VM via SSH by using tmate
# Version: 2.0
#

set -e
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
INFO="[${Green_font_prefix}INFO${Font_color_suffix}]"
ERROR="[${Red_font_prefix}ERROR${Font_color_suffix}]"
TMATE_SOCK="/tmp/tmate.sock"
TELEGRAM_LOG="/tmp/telegram.log"

CONTINUE_FILE="/tmp/continue"

KEEPALIVE_FILE="/tmp/keepalive"

# Install tmate on macOS or Ubuntu
echo -e "${INFO} Setting up tmate ..."
if [[ -n "$(uname | grep Linux)" ]]; then
    curl -fsSL git.io/tmate.sh | bash
elif [[ -x "$(command -v brew)" ]]; then
    brew install tmate
else
    echo -e "${ERROR} This system is not supported Tmate!"
    exit 1
fi

# Generate ssh key if needed
[[ -e ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""

# Run deamonized tmate
echo -e "${INFO} Running tmate..."
tmate -S ${TMATE_SOCK} new-session -d
tmate -S ${TMATE_SOCK} wait tmate-ready

# Print connection info
TMATE_SSH=$(tmate -S ${TMATE_SOCK} display -p '#{tmate_ssh}')
TMATE_WEB=$(tmate -S ${TMATE_SOCK} display -p '#{tmate_web}')
MSG="
*GitHub Actions - tmate session info:*

⚡ *CLI:*
\`${TMATE_SSH}\`

🔗 *URL:*
${TMATE_WEB}

🔔 *TIPS:*
Run '\`touch ${CONTINUE_FILE}\`' to continue to the next step.
"

if [[ -n "${TELEGRAM_BOT_TOKEN}" && -n "${TELEGRAM_CHAT_ID}" ]]; then
    echo -e "${INFO} Sending message to Telegram..."
    curl -sSX POST "${TELEGRAM_API_URL:-https://api.telegram.org}/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=Markdown" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MSG}" >${TELEGRAM_LOG}
    TELEGRAM_STATUS=$(cat ${TELEGRAM_LOG} | jq -r .ok)
    if [[ ${TELEGRAM_STATUS} != true ]]; then
        echo -e "${ERROR} Telegram message sending failed: $(cat ${TELEGRAM_LOG})"
    else
        echo -e "${INFO} Telegram message sent successfully!"
    fi
fi

while ((${PRT_COUNT:=1} <= ${PRT_TOTAL:=20})); do
    
    echo "-----------------------------------------------------------------------------------"
    echo "--连接至SSH实例----${PRT_COUNT} / ${PRT_TOTAL:=10} / 15s-----------------------------------"
    echo "-----------------------------------------------------------------------------------"
    echo -e "CLI: ${Green_font_prefix}${TMATE_SSH}${Font_color_suffix}"
    echo -e "URL: ${Green_font_prefix}${TMATE_WEB}${Font_color_suffix}"
    echo "-----------------------------------------------------------------------------------"
    echo -e "TIPS: 执行 'touch ${KEEPALIVE_FILE}' 禁用30分钟会话超时规则."
    echo -e "      执行 'touch ${CONTINUE_FILE}' 进行后续操作."
    echo "-----------------------------------------------------------------------------------"
    echo "-----------------------------------------------------------------------------------"
    echo ""
    echo ""
    PRT_COUNT=$((${PRT_COUNT} + 1))
    sleep 15
done

# 当执行 touch /tmp/continue 后执行后续操作，会话使用ctrl D 结束即可，无超时时间。
# while [[ -S ${TMATE_SOCK} ]]; do
#     sleep 1
#     if [[ -e ${CONTINUE_FILE} ]]; then
#         echo -e "${INFO} Continue to the next step."
#         exit 0
#     fi
# done


# Wait for connection to close or timeout in 30 min 会话超时时间
# 当执行 touch /tmp/keepalive 后会话持续保持。ctrl D手动结束会话
timeout=180
while [ -S ${TMATE_SOCK} ]; do
    sleep 10
    timeout=$(($timeout - 1))
    if [ ! -f ${KEEPALIVE_FILE} ]; then
        if ((timeout < 0)); then
            echo Waiting on tmate connection timed out!
            exit 0
        fi
    fi
    if [[ -e ${CONTINUE_FILE} ]]; then
         echo -e "${INFO} Continue to the next step."
         exit 0
    fi
done

