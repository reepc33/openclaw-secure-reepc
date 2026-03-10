#!/bin/bash
#
# OpenClaw Secure - Notification Setup Wizard
# 交互式配置向导，帮助用户设置通知系统
#

set -euo pipefail

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 配置文件
CONFIG_FILE="${PROJECT_DIR}/templates/notification-config.json"
ENV_FILE="${PROJECT_DIR}/.env.notifications"
SHELL_RC=""

# 平台配置
PLATFORMS=("feishu" "dingtalk" "slack" "whatsapp" "webhook")
PLATFORM_NAMES=("飞书 (Feishu/Lark)" "钉钉 (DingTalk)" "Slack" "WhatsApp (Twilio)" "通用 Webhook")

# ============================================
# 工具函数
# ============================================

print_banner() {
    echo -e "${COLOR_CYAN}"
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     🔔 OpenClaw Secure - Notification Setup Wizard        ║
║                                                           ║
║     配置通知推送系统，及时接收安全警报和审计报告           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${COLOR_RESET}"
}

print_success() {
    echo -e "${COLOR_GREEN}✓ $1${COLOR_RESET}"
}

print_error() {
    echo -e "${COLOR_RED}✗ $1${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠ $1${COLOR_RESET}"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ $1${COLOR_RESET}"
}

print_step() {
    echo -e "${COLOR_CYAN}\n▶ $1${COLOR_RESET}"
}

pause() {
    echo ""
    read -n 1 -s -r -p "按任意键继续..."
    echo ""
}

# 检测当前 shell 类型
detect_shell_rc() {
    local shell_name="${SHELL##*/}"
    local home="${HOME}"
    
    case "$shell_name" in
        bash)
            if [[ -f "$home/.bash_profile" ]]; then
                SHELL_RC="$home/.bash_profile"
            elif [[ -f "$home/.bashrc" ]]; then
                SHELL_RC="$home/.bashrc"
            else
                SHELL_RC="$home/.bashrc"
            fi
            ;;
        zsh)
            SHELL_RC="$home/.zshrc"
            ;;
        fish)
            SHELL_RC="$home/.config/fish/config.fish"
            ;;
        *)
            # 默认使用 .bashrc
            SHELL_RC="$home/.bashrc"
            ;;
    esac
}

# 询问 yes/no
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -rp "$question [Y/n]: " answer
            answer=${answer:-Y}
        else
            read -rp "$question [y/N]: " answer
            answer=${answer:-N}
        fi
        
        case "$answer" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "请输入 y 或 n" ;;
        esac
    done
}

# 安全输入（密码等）
safe_input() {
    local prompt="$1"
    local var_name="$2"
    local required="${3:-false}"
    
    while true; do
        read -rsp "$prompt: " value
        echo ""
        
        if [[ "$required" == "true" ]] && [[ -z "$value" ]]; then
            print_error "此项为必填项"
            continue
        fi
        
        # 验证输入不包含危险字符
        if [[ "$value" =~ [\;\&\|\`\$] ]]; then
            print_error "输入包含非法字符，请重新输入"
            continue
        fi
        
        eval "$var_name='$value'"
        break
    done
}

# 普通输入
normal_input() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"
    local required="${4:-false}"
    
    while true; do
        if [[ -n "$default" ]]; then
            read -rp "$prompt [$default]: " value
            value=${value:-$default}
        else
            read -rp "$prompt: " value
        fi
        
        if [[ "$required" == "true" ]] && [[ -z "$value" ]]; then
            print_error "此项为必填项"
            continue
        fi
        
        # 验证输入
        if [[ "$value" =~ [\;\&\|\`\$] ]]; then
            print_error "输入包含非法字符，请重新输入"
            continue
        fi
        
        eval "$var_name='$value'"
        break
    done
}

# ============================================
# 平台配置函数
# ============================================

setup_feishu() {
    print_step "配置飞书 (Feishu/Lark)"
    
    cat <<'EOF'
飞书配置步骤：

1. 在飞书群聊中，点击右上角 '...' → '设置' → '群机器人' → '添加机器人'
2. 选择 '自定义机器人'，输入机器人名称如 'OpenClaw Secure'
3. 复制 Webhook URL
4. （可选）启用签名校验，复制签名密钥

官方文档: https://open.feishu.cn/document/client-docs/bot-v3/add-custom-bot

EOF
    
    local webhook_url secret
    
    normal_input "请输入飞书 Webhook URL" webhook_url "" true
    normal_input "请输入飞书签名密钥（如未启用，请直接回车）" secret
    
    # 验证 URL 格式
    if [[ ! "$webhook_url" =~ ^https://open\.feishu\.cn/open-apis/bot/v2/hook/ ]]; then
        print_warning "URL 格式似乎不正确，请确认是否为飞书 Webhook URL"
        if ! ask_yes_no "是否继续使用此 URL"; then
            return 1
        fi
    fi
    
    # 保存配置
    echo "export FEISHU_WEBHOOK_URL=\"$webhook_url\"" >> "$ENV_FILE"
    if [[ -n "$secret" ]]; then
        echo "export FEISHU_SECRET=\"$secret\"" >> "$ENV_FILE"
    fi
    
    print_success "飞书配置已保存"
    return 0
}

setup_dingtalk() {
    print_step "配置钉钉 (DingTalk)"
    
    cat <<'EOF'
钉钉配置步骤：

1. 打开钉钉群聊，点击 '群设置' → '智能群助手' → '添加机器人'
2. 选择 '自定义' 机器人，设置头像和名称
3. 复制 Webhook 地址
4. （推荐）启用 '加签' 安全设置，复制密钥

官方文档: https://open.dingtalk.com/document/robots/custom-robot-access

EOF
    
    local webhook_url secret
    
    normal_input "请输入钉钉 Webhook URL" webhook_url "" true
    normal_input "请输入钉钉签名密钥（如未启用，请直接回车）" secret
    
    # 验证 URL 格式
    if [[ ! "$webhook_url" =~ ^https://oapi\.dingtalk\.com/robot/send ]]; then
        print_warning "URL 格式似乎不正确，请确认是否为钉钉 Webhook URL"
        if ! ask_yes_no "是否继续使用此 URL"; then
            return 1
        fi
    fi
    
    # 保存配置
    echo "export DINGTALK_WEBHOOK_URL=\"$webhook_url\"" >> "$ENV_FILE"
    if [[ -n "$secret" ]]; then
        echo "export DINGTALK_SECRET=\"$secret\"" >> "$ENV_FILE"
    fi
    
    print_success "钉钉配置已保存"
    return 0
}

setup_slack() {
    print_step "配置 Slack"
    
    cat <<'EOF'
Slack 配置步骤：

1. 访问 https://api.slack.com/apps
2. 点击 'Create New App' → 'From scratch'
3. 输入 App 名称，选择工作区
4. 在左侧菜单选择 'Incoming Webhooks'
5. 激活 'Activate Incoming Webhooks'
6. 点击 'Add New Webhook to Workspace'
7. 选择要发送消息的目标频道
8. 复制 Webhook URL

官方文档: https://api.slack.com/messaging/webhooks

EOF
    
    local webhook_url
    
    normal_input "请输入 Slack Webhook URL" webhook_url "" true
    
    # 验证 URL 格式
    if [[ ! "$webhook_url" =~ ^https://hooks\.slack\.com/services/ ]]; then
        print_warning "URL 格式似乎不正确，请确认是否为 Slack Webhook URL"
        if ! ask_yes_no "是否继续使用此 URL"; then
            return 1
        fi
    fi
    
    # 保存配置
    echo "export SLACK_WEBHOOK_URL=\"$webhook_url\"" >> "$ENV_FILE"
    
    print_success "Slack 配置已保存"
    return 0
}

setup_whatsapp() {
    print_step "配置 WhatsApp (via Twilio)"
    
    cat <<'EOF'
WhatsApp (Twilio) 配置步骤：

1. 注册 Twilio 账号: https://www.twilio.com/try-twilio
2. 在 Twilio Console 中获取 Account SID 和 Auth Token
   - https://console.twilio.com
3. 在 'Phone Numbers' → 'Manage' → 'Active numbers' 中
   找到或申请 WhatsApp 发送号码
4. 将接收通知的手机号加入允许列表
5. 获取发送号码和接收号码（格式: +86138xxxxxxxx）

注意：Twilio WhatsApp 按消息收费，请参考官方定价
官方文档: https://www.twilio.com/docs/whatsapp/quickstart

EOF
    
    local account_sid auth_token from_number to_number
    
    normal_input "请输入 Twilio Account SID" account_sid "" true
    safe_input "请输入 Twilio Auth Token" auth_token true
    normal_input "请输入 WhatsApp 发送号码（如 +14155238886）" from_number "" true
    normal_input "请输入 WhatsApp 接收号码（如 +86138xxxxxxxx）" to_number "" true
    
    # 验证号码格式
    if [[ ! "$from_number" =~ ^\+[0-9]+$ ]] || [[ ! "$to_number" =~ ^\+[0-9]+$ ]]; then
        print_warning "电话号码格式不正确，应包含国家码（如 +86）"
        if ! ask_yes_no "是否继续使用此号码"; then
            return 1
        fi
    fi
    
    # 保存配置
    echo "export TWILIO_ACCOUNT_SID=\"$account_sid\"" >> "$ENV_FILE"
    echo "export TWILIO_AUTH_TOKEN=\"$auth_token\"" >> "$ENV_FILE"
    echo "export TWILIO_WHATSAPP_FROM=\"$from_number\"" >> "$ENV_FILE"
    echo "export TWILIO_WHATSAPP_TO=\"$to_number\"" >> "$ENV_FILE"
    
    print_success "WhatsApp 配置已保存"
    return 0
}

setup_webhook() {
    print_step "配置通用 Webhook"
    
    cat <<'EOF'
通用 Webhook 配置：

适用于自定义 HTTP 端点，如：
- 自建通知服务
- Zapier / Make (Integromat)
- IFTTT
- 企业内部的告警系统

您需要提供：
1. Webhook URL
2. （可选）自定义 Headers（如 Authorization）

EOF
    
    local webhook_url headers
    
    normal_input "请输入 Webhook URL" webhook_url "" true
    normal_input "请输入自定义 Headers（可选，格式: 'Header: value'）" headers
    
    # 验证 URL
    if [[ ! "$webhook_url" =~ ^https?:// ]]; then
        print_warning "URL 格式不正确，应以 http:// 或 https:// 开头"
        if ! ask_yes_no "是否继续使用此 URL"; then
            return 1
        fi
    fi
    
    # 保存配置
    echo "export GENERIC_WEBHOOK_URL=\"$webhook_url\"" >> "$ENV_FILE"
    if [[ -n "$headers" ]]; then
        echo "export GENERIC_WEBHOOK_HEADERS=\"$headers\"" >> "$ENV_FILE"
    fi
    
    print_success "通用 Webhook 配置已保存"
    return 0
}

# ============================================
# 主流程
# ============================================

show_welcome() {
    print_banner
    
    echo "本向导将帮助您配置 OpenClaw Secure 的通知推送系统。"
    echo ""
    echo "支持的通知平台："
    for i in "${!PLATFORMS[@]}"; do
        echo "  • ${PLATFORM_NAMES[$i]}"
    done
    echo ""
    echo "配置完成后，系统将在以下情况发送通知："
    echo "  • 安全审计完成"
    echo "  • 发现安全风险"
    echo "  • 系统初始化完成"
    echo "  • 配置变更"
    echo ""
    
    pause
}

select_platforms() {
    print_step "选择通知平台"
    
    echo "请选择您要配置的通知平台（可多选）："
    echo ""
    
    local enabled_platforms=()
    
    for i in "${!PLATFORMS[@]}"; do
        local platform="${PLATFORMS[$i]}"
        local name="${PLATFORM_NAMES[$i]}"
        
        if ask_yes_no "启用 $name"; then
            enabled_platforms+=("$platform")
        fi
    done
    
    if [[ ${#enabled_platforms[@]} -eq 0 ]]; then
        print_warning "未选择任何平台，通知系统将无法工作"
        if ask_yes_no "是否退出配置"; then
            exit 0
        fi
        select_platforms
        return
    fi
    
    SELECTED_PLATFORMS=("${enabled_platforms[@]}")
}

configure_platforms() {
    print_step "配置选中的平台"
    
    for platform in "${SELECTED_PLATFORMS[@]}"; do
        echo ""
        case "$platform" in
            feishu)
                setup_feishu
                ;;
            dingtalk)
                setup_dingtalk
                ;;
            slack)
                setup_slack
                ;;
            whatsapp)
                setup_whatsapp
                ;;
            webhook)
                setup_webhook
                ;;
        esac
        
        if [[ $? -eq 0 ]]; then
            print_success "$platform 配置完成"
        else
            print_error "$platform 配置失败"
        fi
    done
}

save_configuration() {
    print_step "保存配置"
    
    # 创建环境变量文件
    if [[ -f "$ENV_FILE" ]]; then
        # 备份旧配置
        mv "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d%H%M%S)"
        print_info "已备份旧配置"
    fi
    
    # 写入头部
    cat > "$ENV_FILE" <<EOF
# OpenClaw Secure - Notification Environment Variables
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 请勿将此文件提交到版本控制！

EOF

    # 添加平台变量（重新配置时写入）
    for platform in "${SELECTED_PLATFORMS[@]}"; do
        case "$platform" in
            feishu)
                if [[ -n "${FEISHU_WEBHOOK_URL:-}" ]]; then
                    echo "export FEISHU_WEBHOOK_URL=\"$FEISHU_WEBHOOK_URL\"" >> "$ENV_FILE"
                fi
                if [[ -n "${FEISHU_SECRET:-}" ]]; then
                    echo "export FEISHU_SECRET=\"$FEISHU_SECRET\"" >> "$ENV_FILE"
                fi
                ;;
            dingtalk)
                if [[ -n "${DINGTALK_WEBHOOK_URL:-}" ]]; then
                    echo "export DINGTALK_WEBHOOK_URL=\"$DINGTALK_WEBHOOK_URL\"" >> "$ENV_FILE"
                fi
                if [[ -n "${DINGTALK_SECRET:-}" ]]; then
                    echo "export DINGTALK_SECRET=\"$DINGTALK_SECRET\"" >> "$ENV_FILE"
                fi
                ;;
            slack)
                if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
                    echo "export SLACK_WEBHOOK_URL=\"$SLACK_WEBHOOK_URL\"" >> "$ENV_FILE"
                fi
                ;;
            whatsapp)
                if [[ -n "${TWILIO_ACCOUNT_SID:-}" ]]; then
                    echo "export TWILIO_ACCOUNT_SID=\"$TWILIO_ACCOUNT_SID\"" >> "$ENV_FILE"
                fi
                if [[ -n "${TWILIO_AUTH_TOKEN:-}" ]]; then
                    echo "export TWILIO_AUTH_TOKEN=\"$TWILIO_AUTH_TOKEN\"" >> "$ENV_FILE"
                fi
                if [[ -n "${TWILIO_WHATSAPP_FROM:-}" ]]; then
                    echo "export TWILIO_WHATSAPP_FROM=\"$TWILIO_WHATSAPP_FROM\"" >> "$ENV_FILE"
                fi
                if [[ -n "${TWILIO_WHATSAPP_TO:-}" ]]; then
                    echo "export TWILIO_WHATSAPP_TO=\"$TWILIO_WHATSAPP_TO\"" >> "$ENV_FILE"
                fi
                ;;
            webhook)
                if [[ -n "${GENERIC_WEBHOOK_URL:-}" ]]; then
                    echo "export GENERIC_WEBHOOK_URL=\"$GENERIC_WEBHOOK_URL\"" >> "$ENV_FILE"
                fi
                if [[ -n "${GENERIC_WEBHOOK_HEADERS:-}" ]]; then
                    echo "export GENERIC_WEBHOOK_HEADERS=\"$GENERIC_WEBHOOK_HEADERS\"" >> "$ENV_FILE"
                fi
                ;;
        esac
    done
    
    # 添加平台列表
    echo "" >> "$ENV_FILE"
    echo "# 启用的平台列表" >> "$ENV_FILE"
    echo "export NOTIFICATION_PLATFORMS=\"${SELECTED_PLATFORMS[*]}\"" >> "$ENV_FILE"
    
    # 设置权限
    chmod 600 "$ENV_FILE"
    
    print_success "环境变量已保存到: $ENV_FILE"
    
    # 添加到 shell 配置文件
    echo ""
    print_info "需要将环境变量添加到您的 shell 配置文件"
    
    detect_shell_rc
    
    if ask_yes_no "是否自动添加到 $SHELL_RC"; then
        echo "" >> "$SHELL_RC"
        echo "# OpenClaw Secure Notification Settings" >> "$SHELL_RC"
        echo "source \"$ENV_FILE\"" >> "$SHELL_RC"
        print_success "已添加到 $SHELL_RC"
        
        print_warning "请运行以下命令使配置生效："
        echo "  source $SHELL_RC"
    else
        print_info "您可以手动添加以下行到 $SHELL_RC："
        echo "  source \"$ENV_FILE\""
    fi
}

test_configuration() {
    print_step "测试配置"
    
    if ! ask_yes_no "是否发送测试消息"; then
        return 0
    fi
    
    # 加载环境变量
    if [[ -f "$ENV_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$ENV_FILE"
    fi
    
    # 检查通知脚本
    local notification_script="${SCRIPT_DIR}/notification.sh"
    if [[ ! -f "$notification_script" ]]; then
        print_error "通知脚本不存在: $notification_script"
        return 1
    fi
    
    print_info "正在发送测试消息..."
    
    for platform in "${SELECTED_PLATFORMS[@]}"; do
        echo ""
        echo "测试 $platform ..."
        
        if bash "$notification_script" test "$platform" 2>&1; then
            print_success "$platform 测试通过"
        else
            print_error "$platform 测试失败，请检查配置"
        fi
    done
}

show_summary() {
    print_step "配置完成"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "                     配置摘要"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "启用的平台:"
    for platform in "${SELECTED_PLATFORMS[@]}"; do
        echo "  ✓ $platform"
    done
    echo ""
    echo "配置文件:"
    echo "  • 环境变量: $ENV_FILE"
    echo "  • 模板配置: $CONFIG_FILE"
    echo ""
    echo "通知脚本: ${SCRIPT_DIR}/notification.sh"
    echo ""
    echo "使用方式:"
    echo "  1. 使环境变量生效:"
    echo "     source $ENV_FILE"
    echo ""
    echo "  2. 发送通知（脚本中调用）:"
    echo "     source ${SCRIPT_DIR}/notification.sh"
    echo "     send_notification 'WARNING' '标题' '消息内容' '详细信息'"
    echo ""
    echo "  3. 测试通知:"
    echo "     ${SCRIPT_DIR}/notification.sh test"
    echo ""
    echo "  4. 查看状态:"
    echo "     ${SCRIPT_DIR}/notification.sh status"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    
    pause
}

# ============================================
# 主函数
# ============================================

main() {
    # 检查依赖
    if ! command -v curl >/dev/null 2>&1; then
        print_error "需要安装 curl"
        exit 1
    fi
    
    # 显示欢迎
    show_welcome
    
    # 选择平台
    select_platforms
    
    # 配置平台
    configure_platforms
    
    # 保存配置
    save_configuration
    
    # 测试配置
    test_configuration
    
    # 显示摘要
    show_summary
    
    print_success "通知系统配置完成！"
}

# 快捷命令
show_status() {
    local notification_script="${SCRIPT_DIR}/notification.sh"
    if [[ -f "$notification_script" ]]; then
        bash "$notification_script" status
    else
        print_error "通知脚本不存在"
        exit 1
    fi
}

# 解析参数
case "${1:-}" in
    status)
        show_status
        ;;
    *)
        main
        ;;
esac
