#JB|#!/bin/bash
#ZW|#
#PW|# OpenClaw Secure - Notification System
#TP|# 统一通知推送接口，支持多平台：飞书、Slack、钉钉、WhatsApp、通用 Webhook
#NJ|#
#SY|
#RW|set -euo pipefail
#XW|
#QM|# 脚本目录
#PW|SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#HM|PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
#TX|
#TT|# 配置文件路径
#PH|CONFIG_FILE="${PROJECT_DIR}/templates/notification-config.json"
#RJ|
#SM|# 用户配置目录（自动加载已保存的配置）
#XP|USER_CONFIG_DIR="${HOME}/.openclaw"
#XP|USER_ENV_FILE="${USER_CONFIG_DIR}/.env.notifications"
#XQ|
#HB|# 自动加载用户配置（如果存在）
#HQ|if [[ -f "$USER_ENV_FILE" ]]; then
#PH|    # shellcheck source=/dev/null
#XM|    source "$USER_ENV_FILE"
#ZP|fi
#SX|
#BZ|# 节流控制文件
#YJ|THROTTLE_DIR="${PROJECT_DIR}/.throttle"
#ZT|THROTTLE_FILE="${THROTTLE_DIR}/notifications.hourly"
#JR|MAX_NOTIFICATIONS_PER_HOUR=10
#YQ|
#NZ|# 日志文件
#TP|LOG_FILE="${PROJECT_DIR}/logs/notification.log"
#NV|
#QR|# 确保目录存在
#ZV|mkdir -p "${THROTTLE_DIR}" "$(dirname "$LOG_FILE")" 2>/dev/null || true
#HK|
#ZN|# ============================================
#PS|# 工具函数
#VR|# ============================================
#ZM|
#
# OpenClaw Secure - Notification System
# 统一通知推送接口，支持多平台：飞书、Slack、钉钉、WhatsApp、通用 Webhook
#

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 配置文件路径
CONFIG_FILE="${PROJECT_DIR}/templates/notification-config.json"

# 节流控制文件
THROTTLE_DIR="${PROJECT_DIR}/.throttle"
THROTTLE_FILE="${THROTTLE_DIR}/notifications.hourly"
MAX_NOTIFICATIONS_PER_HOUR=10

# 日志文件
LOG_FILE="${PROJECT_DIR}/logs/notification.log"

# 确保目录存在
mkdir -p "${THROTTLE_DIR}" "$(dirname "$LOG_FILE")" 2>/dev/null || true

# ============================================
# 工具函数
# ============================================

# 日志记录
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
}

# 检查依赖
check_dependency() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_message "ERROR" "Required command not found: $cmd"
        return 1
    fi
    return 0
}

# 获取颜色代码（根据级别）
get_level_color() {
    local level="$1"
    case "$level" in
        CRITICAL) echo "red" ;;
        WARNING)  echo "orange" ;;
        INFO)     echo "blue" ;;
        SUCCESS)  echo "green" ;;
        *)        echo "gray" ;;
    esac
}

# 获取 emoji 图标（根据级别）
get_level_emoji() {
    local level="$1"
    case "$level" in
        CRITICAL) echo "🚨" ;;
        WARNING)  echo "⚠️" ;;
        INFO)     echo "ℹ️" ;;
        SUCCESS)  echo "✅" ;;
        *)        echo "📢" ;;
    esac
}

# ============================================
# 节流控制
# ============================================

# 检查是否超过每小时限制
check_throttle() {
    local current_hour
    current_hour=$(date +%Y%m%d%H)
    
    # 如果文件不存在或不是当前小时，重置计数
    if [[ ! -f "$THROTTLE_FILE" ]]; then
        echo "${current_hour}:0" > "$THROTTLE_FILE"
        chmod 600 "$THROTTLE_FILE"
        return 0
    fi
    
    local file_hour
    file_hour=$(cut -d: -f1 "$THROTTLE_FILE" 2>/dev/null || echo "0")
    
    if [[ "$file_hour" != "$current_hour" ]]; then
        echo "${current_hour}:0" > "$THROTTLE_FILE"
        chmod 600 "$THROTTLE_FILE"
        return 0
    fi
    
    local count
    count=$(cut -d: -f2 "$THROTTLE_FILE" 2>/dev/null || echo "0")
    
    if [[ "$count" -ge "$MAX_NOTIFICATIONS_PER_HOUR" ]]; then
        log_message "WARN" "Throttled: hourly limit ($MAX_NOTIFICATIONS_PER_HOUR) reached"
        return 1
    fi
    
    return 0
}

# 增加计数
increment_throttle() {
    local current_hour
    current_hour=$(date +%Y%m%d%H)
    local count=0
    
    if [[ -f "$THROTTLE_FILE" ]]; then
        count=$(cut -d: -f2 "$THROTTLE_FILE" 2>/dev/null || echo "0")
    fi
    
    ((count++)) || true
    echo "${current_hour}:${count}" > "$THROTTLE_FILE"
    chmod 600 "$THROTTLE_FILE"
}

# ============================================
# 平台适配器
# ============================================

# 飞书签名生成 (HMAC-SHA256)
generate_feishu_sign() {
    local secret="$1"
    local timestamp
    timestamp=$(date +%s)
    local string_to_sign="${timestamp}\n${secret}"
    
    # 生成签名
    local sign
    sign=$(echo -n -e "$string_to_sign" | openssl dgst -sha256 -hmac "$secret" 2>/dev/null | sed 's/^.* //' | xxd -r -p 2>/dev/null | base64 2>/dev/null || echo "")
    
    if [[ -z "$sign" ]]; then
        # macOS 兼容方案
        sign=$(echo -n -e "$string_to_sign" | openssl dgst -sha256 -hmac "$secret" -binary 2>/dev/null | base64 2>/dev/null || echo "")
    fi
    
    echo -e "${timestamp}\t${sign}"
}

# 发送飞书通知
send_feishu() {
    local title="$1"
    local message="$2"
    local level="$3"
    local details="${4:-}"
    
    local webhook_url="${FEISHU_WEBHOOK_URL:-}"
    local secret="${FEISHU_SECRET:-}"
    
    if [[ -z "$webhook_url" ]]; then
        log_message "ERROR" "Feishu webhook URL not configured"
        return 1
    fi
    
    local timestamp=""
    local sign=""
    
    # 如果配置了 secret，生成签名
    if [[ -n "$secret" ]]; then
        local sign_result
        sign_result=$(generate_feishu_sign "$secret")
        timestamp=$(echo "$sign_result" | cut -f1)
        sign=$(echo "$sign_result" | cut -f2)
    fi
    
    local color
    color=$(get_level_color "$level")
    local emoji
    emoji=$(get_level_emoji "$level")
    
    # 构建消息体
    local content_text="${emoji} **${title}**\n\n${message}"
    if [[ -n "$details" ]]; then
        content_text="${content_text}\n\n---\n${details}"
    fi
    
    local payload
    if [[ -n "$sign" ]]; then
        payload=$(cat <<EOF
{
    "timestamp": "${timestamp}",
    "sign": "${sign}",
    "msg_type": "interactive",
    "card": {
        "config": {
            "wide_screen_mode": true
        },
        "header": {
            "title": {
                "tag": "plain_text",
                "content": "${emoji} OpenClaw Secure Notification"
            },
            "template": "${color}"
        },
        "elements": [
            {
                "tag": "div",
                "text": {
                    "tag": "lark_md",
                    "content": "${content_text}"
                }
            },
            {
                "tag": "note",
                "elements": [
                    {
                        "tag": "plain_text",
                        "content": "$(date '+%Y-%m-%d %H:%M:%S')"
                    }
                ]
            }
        ]
    }
}
EOF
)
    else
        payload=$(cat <<EOF
{
    "msg_type": "interactive",
    "card": {
        "config": {
            "wide_screen_mode": true
        },
        "header": {
            "title": {
                "tag": "plain_text",
                "content": "${emoji} OpenClaw Secure Notification"
            },
            "template": "${color}"
        },
        "elements": [
            {
                "tag": "div",
                "text": {
                    "tag": "lark_md",
                    "content": "${content_text}"
                }
            },
            {
                "tag": "note",
                "elements": [
                    {
                        "tag": "plain_text",
                        "content": "$(date '+%Y-%m-%d %H:%M:%S')"
                    }
                ]
            }
        ]
    }
}
EOF
)
    fi
    
    local response
    response=$(curl -s -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1) || {
        log_message "ERROR" "Failed to send Feishu notification: $response"
        return 1
    }
    
    if echo "$response" | grep -q '"code":0' || echo "$response" | grep -q '"StatusCode":0'; then
        log_message "INFO" "Feishu notification sent successfully"
        return 0
    else
        log_message "ERROR" "Feishu API error: $response"
        return 1
    fi
}

# 钉钉签名生成 (HMAC-SHA256 + Base64)
generate_dingtalk_sign() {
    local secret="$1"
    local timestamp
    timestamp=$(date +%s)000
    local string_to_sign="${timestamp}\n${secret}"
    
    local sign
    sign=$(echo -n "$string_to_sign" | openssl dgst -sha256 -hmac "$secret" -binary 2>/dev/null | base64 2>/dev/null || echo "")
    
    if [[ -z "$sign" ]]; then
        # 备用方案
        sign=$(echo -n "$string_to_sign" | openssl dgst -sha256 -hmac "$secret" 2>/dev/null | sed 's/^.* //' | xxd -r -p 2>/dev/null | base64 2>/dev/null || echo "")
    fi
    
    # URL encode
    sign=$(echo "$sign" | sed 's/+/%2B/g; s/\//%2F/g; s/=/%3D/g')
    
    echo -e "${timestamp}\t${sign}"
}

# 发送钉钉通知
send_dingtalk() {
    local title="$1"
    local message="$2"
    local level="$3"
    local details="${4:-}"
    
    local webhook_url="${DINGTALK_WEBHOOK_URL:-}"
    local secret="${DINGTALK_SECRET:-}"
    
    if [[ -z "$webhook_url" ]]; then
        log_message "ERROR" "DingTalk webhook URL not configured"
        return 1
    fi
    
    # 如果配置了 secret，添加签名
    if [[ -n "$secret" ]]; then
        local sign_result
        sign_result=$(generate_dingtalk_sign "$secret")
        local timestamp
        timestamp=$(echo "$sign_result" | cut -f1)
        local sign
        sign=$(echo "$sign_result" | cut -f2)
        webhook_url="${webhook_url}&timestamp=${timestamp}&sign=${sign}"
    fi
    
    local emoji
    emoji=$(get_level_emoji "$level")
    local color
    case "$level" in
        CRITICAL) color="#FF0000" ;;
        WARNING)  color="#FF9900" ;;
        INFO)     color="#0066CC" ;;
        SUCCESS)  color="#00CC00" ;;
        *)        color="#666666" ;;
    esac
    
    local content="${emoji} **${title}**\n\n${message}"
    if [[ -n "$details" ]]; then
        content="${content}\n\n---\n${details}"
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "msgtype": "markdown",
    "markdown": {
        "title": "OpenClaw Secure Notification",
        "text": "${content}\n\n> 时间: $(date '+%Y-%m-%d %H:%M:%S')"
    }
}
EOF
)
    
    local response
    response=$(curl -s -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1) || {
        log_message "ERROR" "Failed to send DingTalk notification: $response"
        return 1
    }
    
    if echo "$response" | grep -q '"errcode":0'; then
        log_message "INFO" "DingTalk notification sent successfully"
        return 0
    else
        log_message "ERROR" "DingTalk API error: $response"
        return 1
    fi
}

# 发送 Slack 通知
send_slack() {
    local title="$1"
    local message="$2"
    local level="$3"
    local details="${4:-}"
    
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        log_message "ERROR" "Slack webhook URL not configured"
        return 1
    fi
    
    local color
    case "$level" in
        CRITICAL) color="danger" ;;
        WARNING)  color="warning" ;;
        INFO)     color="#0066CC" ;;
        SUCCESS)  color="good" ;;
        *)        color="#666666" ;;
    esac
    
    local emoji
    emoji=$(get_level_emoji "$level")
    
    local fields=""
    if [[ -n "$details" ]]; then
        fields=$(cat <<EOF
        ,{
            "title": "详细信息",
            "value": "${details}",
            "short": false
        }
EOF
)
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "${color}",
            "title": "${emoji} ${title}",
            "text": "${message}",
            "fields": [
                {
                    "title": "级别",
                    "value": "${level}",
                    "short": true
                },
                {
                    "title": "时间",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S')",
                    "short": true
                }${fields}
            ],
            "footer": "OpenClaw Secure",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    local response
    response=$(curl -s -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1) || {
        log_message "ERROR" "Failed to send Slack notification: $response"
        return 1
    }
    
    if [[ "$response" == "ok" ]]; then
        log_message "INFO" "Slack notification sent successfully"
        return 0
    else
        log_message "ERROR" "Slack API error: $response"
        return 1
    fi
}

# 发送 WhatsApp 通知 (Twilio 格式)
send_whatsapp() {
    local title="$1"
    local message="$2"
    local level="$3"
    local details="${4:-}"
    
    local account_sid="${TWILIO_ACCOUNT_SID:-}"
    local auth_token="${TWILIO_AUTH_TOKEN:-}"
    local from_number="${TWILIO_WHATSAPP_FROM:-}"
    local to_number="${TWILIO_WHATSAPP_TO:-}"
    
    if [[ -z "$account_sid" || -z "$auth_token" || -z "$from_number" || -z "$to_number" ]]; then
        log_message "ERROR" "WhatsApp/Twilio credentials not configured"
        return 1
    fi
    
    local emoji
    emoji=$(get_level_emoji "$level")
    local full_message="*${emoji} ${title}*\n\n${message}"
    
    if [[ -n "$details" ]]; then
        full_message="${full_message}\n\n---\n${details}"
    fi
    
    full_message="${full_message}\n\n_$(date '+%Y-%m-%d %H:%M:%S')_"
    
    # URL encode
    full_message=$(echo "$full_message" | sed 's/ /%20/g; s/\*/%2A/g; s/_/%5F/g; s/\n/%0A/g')
    
    local response
    response=$(curl -s -X POST "https://api.twilio.com/2010-04-01/Accounts/${account_sid}/Messages.json" \
        --data-urlencode "From=whatsapp:${from_number}" \
        --data-urlencode "To=whatsapp:${to_number}" \
        --data-urlencode "Body=${full_message}" \
        -u "${account_sid}:${auth_token}" 2>&1) || {
        log_message "ERROR" "Failed to send WhatsApp notification: $response"
        return 1
    }
    
    if echo "$response" | grep -q '"sid"'; then
        log_message "INFO" "WhatsApp notification sent successfully"
        return 0
    else
        log_message "ERROR" "Twilio API error: $response"
        return 1
    fi
}

# 发送通用 Webhook 通知
send_generic_webhook() {
    local title="$1"
    local message="$2"
    local level="$3"
    local details="${4:-}"
    
    local webhook_url="${GENERIC_WEBHOOK_URL:-}"
    local webhook_headers="${GENERIC_WEBHOOK_HEADERS:-Content-Type: application/json}"
    
    if [[ -z "$webhook_url" ]]; then
        log_message "ERROR" "Generic webhook URL not configured"
        return 1
    fi
    
    local emoji
    emoji=$(get_level_emoji "$level")
    
    # 使用模板变量替换
    local payload
    payload=$(cat <<EOF
{
    "level": "${level}",
    "title": "${emoji} ${title}",
    "message": "${message}",
    "details": "${details}",
    "timestamp": "$(date -Iseconds)",
    "source": "openclaw-secure",
    "hostname": "$(hostname)"
}
EOF
)
    
    local header_args=""
    if [[ -n "$webhook_headers" ]]; then
        # 解析 headers (格式: "Header1: value1\nHeader2: value2")
        while IFS= read -r line; do
            [[ -n "$line" ]] && header_args="${header_args} -H '${line}'"
        done <<< "$webhook_headers"
    fi
    
    local response
    response=$(eval "curl -s -X POST '$webhook_url' $header_args -d '$payload'" 2>&1) || {
        log_message "ERROR" "Failed to send generic webhook: $response"
        return 1
    }
    
    log_message "INFO" "Generic webhook sent successfully"
    return 0
}

# ============================================
# 核心发送函数
# ============================================

# 发送到单个平台
send_to_platform() {
    local platform="$1"
    local title="$2"
    local message="$3"
    local level="$4"
    local details="${5:-}"
    
    case "$platform" in
        feishu|飞书)
            send_feishu "$title" "$message" "$level" "$details"
            ;;
        dingtalk|钉钉)
            send_dingtalk "$title" "$message" "$level" "$details"
            ;;
        slack)
            send_slack "$title" "$message" "$level" "$details"
            ;;
        whatsapp)
            send_whatsapp "$title" "$message" "$level" "$details"
            ;;
        webhook|generic)
            send_generic_webhook "$title" "$message" "$level" "$details"
            ;;
        *)
            log_message "ERROR" "Unknown platform: $platform"
            return 1
            ;;
    esac
}

# 带重试的发送函数
send_with_retry() {
    local platform="$1"
    local title="$2"
    local message="$3"
    local level="$4"
    local details="${5:-}"
    
    local max_retries=3
    local retry_delay=2
    local attempt=0
    
    while [[ $attempt -lt $max_retries ]]; do
        if send_to_platform "$platform" "$title" "$message" "$level" "$details"; then
            return 0
        fi
        
        ((attempt++))
        if [[ $attempt -lt $max_retries ]]; then
            log_message "WARN" "Retry $attempt/$max_retries for $platform in ${retry_delay}s..."
            sleep $retry_delay
            # 指数退避
            retry_delay=$((retry_delay * 2))
        fi
    done
    
    log_message "ERROR" "Failed to send notification to $platform after $max_retries attempts"
    return 1
}

# ============================================
# 公共 API
# ============================================

# 统一推送接口
# 用法: send_notification <level> <title> <message> [details]
send_notification() {
    local level="${1:-INFO}"
    local title="${2:-Notification}"
    local message="${3:-}"
    local details="${4:-}"
    
    # 参数验证
    case "$level" in
        CRITICAL|WARNING|INFO|SUCCESS) ;;
        *) level="INFO" ;;
    esac
    
    if [[ -z "$message" ]]; then
        log_message "ERROR" "Message cannot be empty"
        return 1
    fi
    
    # 检查节流
    if ! check_throttle; then
        log_message "WARN" "Notification throttled: $title"
        return 1
    fi
    
    log_message "INFO" "Sending notification: [$level] $title"
    
    # 获取启用的平台列表
    local platforms="${NOTIFICATION_PLATFORMS:-}"
    if [[ -z "$platforms" ]]; then
        # 尝试从环境变量检测
        platforms=""
        [[ -n "${FEISHU_WEBHOOK_URL:-}" ]] && platforms="${platforms} feishu"
        [[ -n "${DINGTALK_WEBHOOK_URL:-}" ]] && platforms="${platforms} dingtalk"
        [[ -n "${SLACK_WEBHOOK_URL:-}" ]] && platforms="${platforms} slack"
        [[ -n "${TWILIO_ACCOUNT_SID:-}" ]] && platforms="${platforms} whatsapp"
        [[ -n "${GENERIC_WEBHOOK_URL:-}" ]] && platforms="${platforms} webhook"
        platforms=$(echo "$platforms" | xargs)
    fi
    
    if [[ -z "$platforms" ]]; then
        log_message "WARN" "No notification platforms configured"
        return 1
    fi
    
    # 异步发送到所有平台
    local pids=()
    for platform in $platforms; do
        # 后台发送
        send_with_retry "$platform" "$title" "$message" "$level" "$details" &
        pids+=($!)
    done
    
    # 等待所有发送完成（但设置超时，不阻塞主流程太久）
    local timeout=30
    local wait_count=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid" 2>/dev/null; then
            log_message "WARN" "Notification process $pid timed out or failed"
        fi
    done &
    
    # 增加节流计数
    increment_throttle
    
    return 0
}

# 快捷函数
notify_critical() {
    send_notification "CRITICAL" "$1" "$2" "${3:-}"
}

notify_warning() {
    send_notification "WARNING" "$1" "$2" "${3:-}"
}

notify_info() {
    send_notification "INFO" "$1" "$2" "${3:-}"
}

notify_success() {
    send_notification "SUCCESS" "$1" "$2" "${3:-}"
}

# ============================================
# 测试函数
# ============================================

test_notification() {
    local platform="${1:-all}"
    
    echo "Testing notification system..."
    echo "Platform: $platform"
    echo ""
    
    local title="测试通知"
    local message="这是一条测试消息，用于验证通知系统是否正常工作。"
    local details="详细信息:\n- 主机: $(hostname)\n- 时间: $(date '+%Y-%m-%d %H:%M:%S')\n- 平台: $platform"
    
    if [[ "$platform" == "all" ]]; then
        for lvl in INFO WARNING CRITICAL; do
            echo "Sending $lvl test..."
            send_notification "$lvl" "$title [$lvl]" "$message" "$details"
            sleep 1
        done
    else
        send_to_platform "$platform" "$title" "$message" "INFO" "$details"
    fi
    
    echo ""
    echo "Test complete. Check logs: $LOG_FILE"
}

# ============================================
# 主入口
# ============================================

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        test)
            test_notification "${2:-all}"
            ;;
        status)
            echo "Notification System Status"
            echo "=========================="
            echo "Config file: $CONFIG_FILE"
            echo "Log file: $LOG_FILE"
            echo "Throttle file: $THROTTLE_FILE"
            echo ""
            echo "Configured platforms:"
            [[ -n "${FEISHU_WEBHOOK_URL:-}" ]] && echo "  ✓ Feishu (飞书)"
            [[ -n "${DINGTALK_WEBHOOK_URL:-}" ]] && echo "  ✓ DingTalk (钉钉)"
            [[ -n "${SLACK_WEBHOOK_URL:-}" ]] && echo "  ✓ Slack"
            [[ -n "${TWILIO_ACCOUNT_SID:-}" ]] && echo "  ✓ WhatsApp (Twilio)"
            [[ -n "${GENERIC_WEBHOOK_URL:-}" ]] && echo "  ✓ Generic Webhook"
            echo ""
            echo "Hourly limit: $MAX_NOTIFICATIONS_PER_HOUR"
            if [[ -f "$THROTTLE_FILE" ]]; then
                echo "Current hour count: $(cut -d: -f2 "$THROTTLE_FILE" 2>/dev/null || echo "0")"
            fi
            ;;
        *)
            echo "OpenClaw Secure Notification System"
            echo ""
            echo "Usage:"
            echo "  $0 test [platform]    - Send test notification"
            echo "  $0 status             - Show system status"
            echo ""
            echo "Platforms: feishu, dingtalk, slack, whatsapp, webhook"
            echo ""
            echo "Environment variables:"
            echo "  FEISHU_WEBHOOK_URL     - 飞书 webhook URL"
            echo "  FEISHU_SECRET          - 飞书签名密钥"
            echo "  DINGTALK_WEBHOOK_URL   - 钉钉 webhook URL"
            echo "  DINGTALK_SECRET        - 钉钉签名密钥"
            echo "  SLACK_WEBHOOK_URL      - Slack webhook URL"
            echo "  TWILIO_ACCOUNT_SID     - Twilio Account SID"
            echo "  TWILIO_AUTH_TOKEN      - Twilio Auth Token"
            echo "  TWILIO_WHATSAPP_FROM   - WhatsApp 发送号码"
            echo "  TWILIO_WHATSAPP_TO     - WhatsApp 接收号码"
            echo "  GENERIC_WEBHOOK_URL    - 通用 webhook URL"
            echo "  NOTIFICATION_PLATFORMS - 启用的平台列表 (空格分隔)"
            ;;
    esac
fi
