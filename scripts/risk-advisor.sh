#!/bin/bash
#
# OpenClaw Risk Advisor
# Command risk analysis tool - analyzes command risk levels and provides warnings
# Core principle: NEVER BLOCK execution, only WARN and LOG
#
# Usage:
#   bash risk-advisor.sh analyze "rm -rf /"
#   bash risk-advisor.sh check "sudo apt update"
#   bash risk-advisor.sh log-only "docker run hello-world"
#

set -euo pipefail

# Configuration
OC_DIR="${HOME}/.openclaw"
LOG_DIR="${OC_DIR}/logs"
LOG_FILE="${LOG_DIR}/risk-advisor.log"
CONFIG_FILE="${OC_DIR}/risk-messages.json"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFICATION_SCRIPT="${SCRIPT_DIR}/notification.sh"

# 通知功能集成
# 加载通知模块
load_notification_module() {
    if [[ -f "$NOTIFICATION_SCRIPT" ]]; then
        # shellcheck source=/dev/null
        source "$NOTIFICATION_SCRIPT"
        return 0
    fi
    return 1
}

# 发送风险通知
send_risk_notification() {
    local level="$1"
    local command="$2"
    local reason="$3"
    
    # 只发送高危和严重风险通知
    if [[ "$level" != "$LEVEL_CRITICAL" && "$level" != "$LEVEL_WARNING" ]]; then
        return 0
    fi
    
    if load_notification_module; then
        local title="检测到风险命令"
        local message="发现${level}级别风险命令，请谨慎操作。"
        local details="命令: ${command}\n原因: ${reason}\n时间: $(date '+%Y-%m-%d %H:%M:%S')\n主机: $(hostname)"
        
        send_notification "$level" "$title" "$message" "$details" 2>/dev/null || true
    fi
}
OC_DIR="${HOME}/.openclaw"
LOG_DIR="${OC_DIR}/logs"
LOG_FILE="${LOG_DIR}/risk-advisor.log"
CONFIG_FILE="${OC_DIR}/risk-messages.json"

# Colors (ANSI)
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[31m'
readonly COLOR_YELLOW='\033[33m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_CYAN='\033[36m'
readonly COLOR_BOLD='\033[1m'

# Risk levels
readonly LEVEL_CRITICAL="CRITICAL"
readonly LEVEL_WARNING="WARNING"
readonly LEVEL_INFO="INFO"
readonly LEVEL_SAFE="SAFE"

# Language setting (default: zh)
LANGUAGE="${OPENC_LAW_LANG:-zh}"

# ============================================================================
# Utility Functions
# ============================================================================

# Print error message and exit
error_exit() {
    echo -e "${COLOR_RED}❌ Error: $1${COLOR_RESET}" >&2
    exit 1
}

# Print warning message
warn_msg() {
    echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}" >&2
}

# Print info message
info_msg() {
    echo -e "${COLOR_CYAN}ℹ️  $1${COLOR_RESET}"
}

# Print success message
success_msg() {
    echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"
}

# Print header
print_header() {
    echo ""
    echo -e "${COLOR_BOLD}========================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}    🔐 OpenClaw Risk Advisor${COLOR_RESET}"
    echo -e "${COLOR_BOLD}========================================${COLOR_RESET}"
    echo ""
}

# Initialize log directory
init_log() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            # Fallback: use temp directory
            LOG_FILE="/tmp/openclaw-risk-advisor.log"
            return 0
        }
    fi
    
    # Ensure log file exists with correct permissions
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE" 2>/dev/null || {
            LOG_FILE="/tmp/openclaw-risk-advisor.log"
            touch "$LOG_FILE" 2>/dev/null || return 0
        }
        chmod 600 "$LOG_FILE" 2>/dev/null || true
    fi
}

# Log to file
log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    # Write to log file (ignore errors)
    echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
}

# Get risk level color
color_for_level() {
    local level="$1"
    case "$level" in
        "$LEVEL_CRITICAL")
            echo "$COLOR_RED"
            ;;
        "$LEVEL_WARNING")
            echo "$COLOR_YELLOW"
            ;;
        "$LEVEL_INFO")
            echo "$COLOR_CYAN"
            ;;
        "$LEVEL_SAFE")
            echo "$COLOR_GREEN"
            ;;
        *)
            echo "$COLOR_RESET"
            ;;
    esac
}

# ============================================================================
# Risk Analysis Functions
# ============================================================================

# Extract message from JSON (basic parsing, no external dependencies)
# This is a simple implementation that works for our JSON format
extract_message() {
    local json_file="$1"
    local key_path="$2"
    local lang="$3"
    
    # Check if file exists
    if [[ ! -f "$json_file" ]]; then
        echo ""
        return 1
    fi
    
    # Read the JSON file
    local json_content
    json_content=$(cat "$json_file" 2>/dev/null) || {
        echo ""
        return 1
    }
    
    # Extract the message using pattern matching
    # Format: "key": { ... "lang": "value" ... }
    local pattern="\"$key_path\"[^{]*{[^}]*\"$lang\"[:[[:space:]]]*\"([^\"]+)\""
    
    if [[ "$json_content" =~ $pattern ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Fallback: try English
    if [[ "$lang" != "en" ]]; then
        pattern="\"$key_path\"[^{]*{[^}]*\"en\"[:[[:space:]]]*\"([^\"]+)\""
        if [[ "$json_content" =~ $pattern ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
    fi
    
    echo ""
    return 1
}

# Check if a pattern matches the command
pattern_matches() {
    local cmd="$1"
    local pattern="$2"
    
    # Use extended regex matching
    if [[ "$cmd" =~ $pattern ]]; then
        return 0
    fi
    return 1
}

# Analyze command and return risk assessment
analyze_command() {
    local cmd="$1"
    local highest_level="$LEVEL_SAFE"
    local matched_patterns=()
    local messages=()
    local consequences=()
    
    # Define risk patterns with levels (order matters: check CRITICAL first)
    # Format: "LEVEL|pattern|message_key|consequence_key"
    
    # CRITICAL patterns
    local -a critical_patterns=(
        "CRITICAL#^rm[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*[[:space:]]+.*[/~]#rm_rf_root#destructive_rm_rf_root_consequences"
        "CRITICAL#^rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+/#rm_rf_root#destructive_rm_rf_root_consequences"
        "CRITICAL#^rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+~#rm_rf_home#destructive_rm_rf_home_consequences"
        "CRITICAL#^rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+\\\$HOME#rm_rf_home#destructive_rm_rf_home_consequences"
        "CRITICAL#^rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+\\\*#rm_rf_wildcard#destructive_rm_rf_wildcard_consequences"
        "CRITICAL#^mkfs\.#mkfs#destructive_mkfs_consequences"
        "CRITICAL#^mkfs[[:space:]]#mkfs#destructive_mkfs_consequences"
        "CRITICAL#^dd[[:space:]]+if=#dd#destructive_dd_consequences"
        "CRITICAL#^wipefs#wipefs#destructive_wipefs_consequences"
        "CRITICAL#^shred[[:space:]]+-#shred#destructive_shred_consequences"
        "CRITICAL#openclaw\.json#modify_openclaw_config#auth_tampering_modify_openclaw_config_consequences"
        "CRITICAL#paired\.json#modify_openclaw_config#auth_tampering_modify_openclaw_config_consequences"
        "CRITICAL#sshd_config#modify_ssh_config#auth_tampering_modify_ssh_config_consequences"
        "CRITICAL#authorized_keys#modify_ssh_config#auth_tampering_modify_ssh_config_consequences"
        "CRITICAL#ssh/config#modify_ssh_config#auth_tampering_modify_ssh_config_consequences"
        "CRITICAL#^passwd[[:space:]]#modify_passwd#auth_tampering_modify_passwd_consequences"
        "CRITICAL#^usermod[[:space:]]#modify_passwd#auth_tampering_modify_passwd_consequences"
        "CRITICAL#^useradd[[:space:]]#modify_passwd#auth_tampering_modify_passwd_consequences"
        "CRITICAL#curl.*-H.*[Aa]uthorization#curl_with_token#data_exfiltration_curl_with_token_consequences"
        "CRITICAL#curl.*-H.*[Tt]oken#curl_with_token#data_exfiltration_curl_with_token_consequences"
        "CRITICAL#curl.*\\\$[A-Z_]*(TOKEN|KEY|SECRET|PWD|PASS)#curl_with_token#data_exfiltration_curl_with_token_consequences"
        "CRITICAL#wget.*--user=#wget_with_auth#data_exfiltration_wget_with_auth_consequences"
        "CRITICAL#wget.*--password=#wget_with_auth#data_exfiltration_wget_with_auth_consequences"
        "CRITICAL#wget.*\\\$[A-Z_]*(TOKEN|KEY|SECRET|PWD|PASS)#wget_with_auth#data_exfiltration_wget_with_auth_consequences"
        "CRITICAL#bash[[:space:]]+-i[[:space:]]+>&#reverse_shell#data_exfiltration_reverse_shell_consequences"
        "CRITICAL#bash.*/dev/tcp/#reverse_shell#data_exfiltration_reverse_shell_consequences"
        "CRITICAL#nc[[:space:]]+-e[[:space:]]+#reverse_shell#data_exfiltration_reverse_shell_consequences"
        "CRITICAL#ncat[[:space:]]+-e[[:space:]]+#reverse_shell#data_exfiltration_reverse_shell_consequences"
        "CRITICAL#docker.*--privileged#docker_privileged#container_ops_docker_privileged_consequences"
        "CRITICAL#docker.*-v[[:space:]]+/:/#docker_privileged#container_ops_docker_privileged_consequences"
        "CRITICAL#echo.*>>[[:space:]]*/etc/cron#cron_system#persistence_cron_system_consequences"
        "CRITICAL#curl.*\|[[:space:]]*bash#pipe_to_bash#code_injection_pipe_to_bash_consequences"
        "CRITICAL#curl.*\|[[:space:]]*sh#pipe_to_bash#code_injection_pipe_to_bash_consequences"
        "CRITICAL#wget.*\|[[:space:]]*bash#pipe_to_bash#code_injection_pipe_to_bash_consequences"
        "CRITICAL#wget.*\|[[:space:]]*sh#pipe_to_bash#code_injection_pipe_to_bash_consequences"
        "CRITICAL#base64.*-d.*\|[[:space:]]*bash#base64_decode#code_injection_base64_decode_consequences"
        "CRITICAL#base64.*--decode.*\|#base64_decode#code_injection_base64_decode_consequences"
        "CRITICAL#eval.*curl#eval_curl#code_injection_eval_curl_consequences"
        "CRITICAL#eval.*wget#eval_curl#code_injection_eval_curl_consequences"
    )
    
    # WARNING patterns
    local -a warning_patterns=(
        "WARNING#^sudo[[:space:]]#sudo#privilege_escalation_sudo_consequences"
        "WARNING#^sudoedit[[:space:]]#sudo#privilege_escalation_sudo_consequences"
        "WARNING#^su[[:space:]]+-#su#privilege_escalation_su_consequences"
        "WARNING#^su[[:space:]]+\\\$#su#privilege_escalation_su_consequences"
        "WARNING#^docker[[:space:]]+run#docker_run#container_ops_docker_run_consequences"
        "WARNING#^docker[[:space:]]+create#docker_run#container_ops_docker_run_consequences"
        "WARNING#^docker[[:space:]]+exec#docker_exec#container_ops_docker_exec_consequences"
        "WARNING#^docker[[:space:]]+attach#docker_exec#container_ops_docker_exec_consequences"
        "WARNING#^iptables[[:space:]]#iptables#network_config_iptables_consequences"
        "WARNING#^ip6tables[[:space:]]#iptables#network_config_iptables_consequences"
        "WARNING#^ufw[[:space:]]#ufw#network_config_ufw_consequences"
        "WARNING#^ifconfig[[:space:]]#network_interface#network_config_network_interface_consequences"
        "WARNING#^ip[[:space:]]+link#network_interface#network_config_network_interface_consequences"
        "WARNING#^ip[[:space:]]+addr#network_interface#network_config_network_interface_consequences"
        "WARNING#^systemctl[[:space:]]+(start|stop|restart|enable|disable)#systemctl#system_services_systemctl_consequences"
        "WARNING#^service[[:space:]]+\w+[[:space:]]+(start|stop|restart)#service#system_services_service_consequences"
        "WARNING#^crontab[[:space:]]+-e#crontab_edit#persistence_crontab_edit_consequences"
        "WARNING#^crontab[[:space:]]+[^-]#crontab_edit#persistence_crontab_edit_consequences"
        "WARNING#^scp[[:space:]]+.*:[[:space:]]*/#scp_to_remote#data_exfiltration_scp_to_remote_consequences"
        "WARNING#rsync.*@.*:#scp_to_remote#data_exfiltration_scp_to_remote_consequences"
        "WARNING#chmod[[:space:]]+.*\+x#chmod_exec#file_operations_chmod_exec_consequences"
        "WARNING#chmod[[:space:]]+7[0-7][0-7]#chmod_exec#file_operations_chmod_exec_consequences"
        "WARNING#chown[[:space:]]+-R#chown_recursive#file_operations_chown_recursive_consequences"
        "WARNING#chown[[:space:]]+--recursive#chown_recursive#file_operations_chown_recursive_consequences"
    )
    
    # INFO patterns (for common read-only commands)
    local -a info_patterns=(
        "INFO#^ls[[:space:]]#ls#info_commands_ls_consequences"
        "INFO#^ll[[:space:]]#ls#info_commands_ls_consequences"
        "INFO#^la[[:space:]]#ls#info_commands_ls_consequences"
        "INFO#^cat[[:space:]]#cat#info_commands_cat_consequences"
        "INFO#^less[[:space:]]#cat#info_commands_cat_consequences"
        "INFO#^more[[:space:]]#cat#info_commands_cat_consequences"
        "INFO#^grep[[:space:]]#grep#info_commands_grep_consequences"
        "INFO#^egrep[[:space:]]#grep#info_commands_grep_consequences"
        "INFO#^fgrep[[:space:]]#grep#info_commands_grep_consequences"
        "INFO#^find[[:space:]]#find#info_commands_find_consequences"
        "INFO#^pwd$#ls#info_commands_ls_consequences"
        "INFO#^echo[[:space:]]#ls#info_commands_ls_consequences"
        "INFO#^which[[:space:]]#ls#info_commands_ls_consequences"
        "INFO#^whereis[[:space:]]#ls#info_commands_ls_consequences"
    )
    
    # Check CRITICAL patterns first
    for entry in "${critical_patterns[@]}"; do
        IFS='#' read -r level pattern msg_key cons_key <<< "$entry"
        if pattern_matches "$cmd" "$pattern"; then
            highest_level="$LEVEL_CRITICAL"
            matched_patterns+=("$pattern")
            messages+=("$msg_key")
            consequences+=("$cons_key")
            break  # Found critical, no need to check others
        fi
    done
    
    # If not critical, check WARNING patterns
    if [[ "$highest_level" != "$LEVEL_CRITICAL" ]]; then
        for entry in "${warning_patterns[@]}"; do
            IFS='#' read -r level pattern msg_key cons_key <<< "$entry"
            if pattern_matches "$cmd" "$pattern"; then
                highest_level="$LEVEL_WARNING"
                matched_patterns+=("$pattern")
                messages+=("$msg_key")
                consequences+=("$cons_key")
            fi
        done
    fi
    
    # If not critical or warning, check INFO patterns
    if [[ "$highest_level" == "$LEVEL_SAFE" ]]; then
        for entry in "${info_patterns[@]}"; do
            IFS='#' read -r level pattern msg_key cons_key <<< "$entry"
            if pattern_matches "$cmd" "$pattern"; then
                highest_level="$LEVEL_INFO"
                matched_patterns+=("$pattern")
                messages+=("$msg_key")
                consequences+=("$cons_key")
            fi
        done
    fi
    
    # Output the result
    echo "LEVEL:$highest_level"
    echo "COMMAND:$cmd"
    
    if [[ ${#matched_patterns[@]} -gt 0 ]]; then
        echo "PATTERNS:${matched_patterns[*]}"
        
        # Output messages and consequences
        for i in "${!messages[@]}"; do
            local msg=""
            local cons=""
            
            # Try to get from JSON first
            if [[ -f "$CONFIG_FILE" ]]; then
                msg=$(extract_message "$CONFIG_FILE" "${messages[$i]}" "$LANGUAGE")
                cons=$(extract_message "$CONFIG_FILE" "${consequences[$i]}" "$LANGUAGE")
            fi
            
            # Fallback to built-in messages
            if [[ -z "$msg" ]]; then
                msg=$(get_builtin_message "${messages[$i]}")
            fi
            if [[ -z "$cons" ]]; then
                cons=$(get_builtin_consequence "${consequences[$i]}")
            fi
            
            echo "MESSAGE:$msg"
            echo "CONSEQUENCE:$cons"
        done
    fi
}

# Get built-in message (fallback)
get_builtin_message() {
    local key="$1"
    case "$key" in
        "rm_rf_root")
            [[ "$LANGUAGE" == "zh" ]] && echo "这将删除系统所有文件，导致数据完全丢失" || echo "This will delete all files on the system, causing complete data loss"
            ;;
        "rm_rf_home")
            [[ "$LANGUAGE" == "zh" ]] && echo "这将删除整个用户主目录和所有个人文件" || echo "This will delete your entire home directory and all personal files"
            ;;
        "rm_rf_wildcard")
            [[ "$LANGUAGE" == "zh" ]] && echo "通配符删除可能意外删除包括系统文件在内的文件" || echo "Wildcard deletion may remove unexpected files including system files"
            ;;
        "mkfs")
            [[ "$LANGUAGE" == "zh" ]] && echo "这将格式化文件系统，销毁设备上的所有数据" || echo "This will format the filesystem, destroying all data on the device"
            ;;
        "dd")
            [[ "$LANGUAGE" == "zh" ]] && echo "磁盘转储操作可能覆盖关键系统数据或破坏分区" || echo "Disk dump operation can overwrite critical system data or destroy partitions"
            ;;
        "wipefs")
            [[ "$LANGUAGE" == "zh" ]] && echo "这将清除文件系统签名，使数据恢复变得困难" || echo "This will wipe filesystem signatures, making data recovery difficult"
            ;;
        "shred")
            [[ "$LANGUAGE" == "zh" ]] && echo "安全文件删除，将永久覆盖文件内容" || echo "Secure file deletion that permanently overwrites file contents"
            ;;
        "modify_openclaw_config")
            [[ "$LANGUAGE" == "zh" ]] && echo "修改 OpenClaw 认证配置可能危及安全" || echo "Modifying OpenClaw authentication configuration may compromise security"
            ;;
        "modify_ssh_config")
            [[ "$LANGUAGE" == "zh" ]] && echo "修改 SSH 配置可能允许未授权的远程访问" || echo "Modifying SSH configuration may allow unauthorized remote access"
            ;;
        "modify_passwd")
            [[ "$LANGUAGE" == "zh" ]] && echo "用户账户修改影响系统认证" || echo "User account modification affects system authentication"
            ;;
        "curl_with_token")
            [[ "$LANGUAGE" == "zh" ]] && echo "cURL 请求包含认证令牌，可能泄露敏感数据" || echo "cURL request contains authentication tokens that may leak sensitive data"
            ;;
        "wget_with_auth")
            [[ "$LANGUAGE" == "zh" ]] && echo "Wget 请求包含认证信息" || echo "Wget request contains authentication information"
            ;;
        "reverse_shell")
            [[ "$LANGUAGE" == "zh" ]] && echo "检测到反向 Shell - 这会创建远程控制通道" || echo "Reverse shell detected - this creates a remote control channel"
            ;;
        "scp_to_remote")
            [[ "$LANGUAGE" == "zh" ]] && echo "数据正被传输到远程主机" || echo "Data is being transferred to a remote host"
            ;;
        "sudo")
            [[ "$LANGUAGE" == "zh" ]] && echo "命令将以提升的权限（root/管理员）执行" || echo "Command will execute with elevated privileges (root/admin)"
            ;;
        "su")
            [[ "$LANGUAGE" == "zh" ]] && echo "正在切换到另一个用户账户" || echo "Switching to another user account"
            ;;
        "docker_run")
            [[ "$LANGUAGE" == "zh" ]] && echo "容器执行，可能访问文件系统和网络" || echo "Container execution with potential filesystem and network access"
            ;;
        "docker_privileged")
            [[ "$LANGUAGE" == "zh" ]] && echo "特权容器或根文件系统挂载 - 完全访问主机" || echo "Privileged container or root filesystem mount - complete host access"
            ;;
        "docker_exec")
            [[ "$LANGUAGE" == "zh" ]] && echo "在运行中的容器内执行命令" || echo "Executing commands inside running container"
            ;;
        "iptables"|"ufw")
            [[ "$LANGUAGE" == "zh" ]] && echo "修改防火墙规则影响网络连接和安全性" || echo "Modifying firewall rules affects network connectivity and security"
            ;;
        "network_interface")
            [[ "$LANGUAGE" == "zh" ]] && echo "网络接口配置更改" || echo "Network interface configuration changes"
            ;;
        "systemctl")
            [[ "$LANGUAGE" == "zh" ]] && echo "系统服务修改影响系统运行" || echo "System service modification affects system operation"
            ;;
        "service")
            [[ "$LANGUAGE" == "zh" ]] && echo "服务控制命令执行" || echo "Service control command execution"
            ;;
        "crontab_edit")
            [[ "$LANGUAGE" == "zh" ]] && echo "Cron 任务修改 - 持久化定时任务" || echo "Cron job modification - persistent scheduled task"
            ;;
        "cron_system")
            [[ "$LANGUAGE" == "zh" ]] && echo "系统级 Cron 修改需要谨慎" || echo "System-level cron modification requires caution"
            ;;
        "pipe_to_bash")
            [[ "$LANGUAGE" == "zh" ]] && echo "下载并立即执行远程脚本极其危险" || echo "Downloading and immediately executing remote script is extremely dangerous"
            ;;
        "base64_decode")
            [[ "$LANGUAGE" == "zh" ]] && echo "Base64 解码后执行可能隐藏恶意命令" || echo "Base64 decoding followed by execution hides malicious commands"
            ;;
        "eval_curl")
            [[ "$LANGUAGE" == "zh" ]] && echo "执行从网络源动态构建的命令" || echo "Evaluating dynamically constructed commands from network sources"
            ;;
        "chmod_exec")
            [[ "$LANGUAGE" == "zh" ]] && echo "为文件添加执行权限" || echo "Adding execute permission to files"
            ;;
        "chown_recursive")
            [[ "$LANGUAGE" == "zh" ]] && echo "递归所有权更改影响目录中的所有文件" || echo "Recursive ownership change affects all files in directory"
            ;;
        "ls"|"cat"|"grep"|"find")
            [[ "$LANGUAGE" == "zh" ]] && echo "只读操作 - 不修改数据" || echo "Read-only operation - no data modification"
            ;;
        *)
            [[ "$LANGUAGE" == "zh" ]] && echo "检测到潜在风险" || echo "Potential risk detected"
            ;;
    esac
}

# Get built-in consequence (fallback)
get_builtin_consequence() {
    local key="$1"
    case "$key" in
        *"destructive"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "数据将被永久删除，无法恢复" || echo "Data will be permanently deleted and cannot be recovered"
            ;;
        *"auth_tampering"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "可能允许未授权访问或创建后门账户" || echo "May allow unauthorized access or create backdoor accounts"
            ;;
        *"data_exfiltration"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "敏感数据可能泄露到外部" || echo "Sensitive data may be leaked to external parties"
            ;;
        *"privilege_escalation"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "错误或恶意命令将影响整个系统" || echo "Errors or malicious commands will affect the entire system"
            ;;
        *"container_ops"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "容器可能访问主机资源或存在逃逸风险" || echo "Container may access host resources or have escape vulnerabilities"
            ;;
        *"network_config"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "网络连接可能中断或安全策略被绕过" || echo "Network connectivity may be disrupted or security policies bypassed"
            ;;
        *"system_services"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "服务可能变得不可用或系统不稳定" || echo "Services may become unavailable or system unstable"
            ;;
        *"persistence"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "可能创建持久化后门或定时任务" || echo "May create persistent backdoors or scheduled tasks"
            ;;
        *"code_injection"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "恶意代码可能被执行，系统完全受控" || echo "Malicious code may be executed, system fully compromised"
            ;;
        *"file_operations"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "文件权限改变可能影响系统安全" || echo "File permission changes may affect system security"
            ;;
        *"info_commands"*)
            [[ "$LANGUAGE" == "zh" ]] && echo "无风险 - 仅查看信息" || echo "No risk - information viewing only"
            ;;
        *)
            [[ "$LANGUAGE" == "zh" ]] && echo "请谨慎评估此操作" || echo "Please evaluate this operation carefully"
            ;;
    esac
}

# ============================================================================
# Display Functions
# ============================================================================

# Display risk assessment result
display_result() {
    local level="$1"
    shift
    local messages=("$@")
    
    local level_color
    level_color=$(color_for_level "$level")
    
    echo ""
    echo -e "${COLOR_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_BOLD}  📊 风险评估结果 (Risk Assessment)${COLOR_RESET}"
    echo -e "${COLOR_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
    
    # Risk level with color
    echo -e "  ${COLOR_BOLD}风险等级 (Risk Level):${COLOR_RESET} ${level_color}${COLOR_BOLD}${level}${COLOR_RESET}"
    echo ""
    
    # Messages
    if [[ ${#messages[@]} -gt 0 ]]; then
        echo -e "  ${COLOR_BOLD}⚠️  风险说明 (Description):${COLOR_RESET}"
        for msg in "${messages[@]}"; do
            if [[ "$msg" == MESSAGE:* ]]; then
                echo -e "     • ${msg#MESSAGE:}"
            fi
        done
        echo ""
        
        echo -e "  ${COLOR_BOLD}💥 可能后果 (Consequences):${COLOR_RESET}"
        for msg in "${messages[@]}"; do
            if [[ "$msg" == CONSEQUENCE:* ]]; then
                echo -e "     • ${msg#CONSEQUENCE:}"
            fi
        done
        echo ""
    fi
    
    # Important notice
    echo -e "  ${COLOR_YELLOW}${COLOR_BOLD}⚡ 重要提示:${COLOR_RESET}"
    if [[ "$LANGUAGE" == "zh" ]]; then
        echo -e "     本工具${COLOR_BOLD}仅提供警告${COLOR_RESET}，不会阻止命令执行。"
        echo -e "     请确认您了解此操作的风险后再继续。"
    else
        echo -e "     This tool ${COLOR_BOLD}only provides warnings${COLOR_RESET}, it does NOT block execution."
        echo -e "     Please confirm you understand the risks before proceeding."
    fi
    
    echo ""
    echo -e "${COLOR_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
}

# Display simple result (for non-interactive use)
display_simple() {
    local level="$1"
    local cmd="$2"
    
    echo "RISK_LEVEL: $level"
    echo "COMMAND: $cmd"
    echo "TIMESTAMP: $(date '+%Y-%m-%d %H:%M:%S')"
}

# ============================================================================
# Command Handlers
# ============================================================================

# Analyze command and display result
cmd_analyze() {
    local cmd="$1"
    
    print_header
    
    # Initialize logging
    init_log
    
    # Analyze the command
    local result
    result=$(analyze_command "$cmd")
    
    # Parse result
    local level=""
    local -a messages=()
    
    while IFS= read -r line; do
        case "$line" in
            LEVEL:*)
                level="${line#LEVEL:}"
                ;;
            MESSAGE:*|CONSEQUENCE:*)
                messages+=("$line")
                ;;
        esac
    done <<< "$result"
    
    # Display result
    if [[ ${#messages[@]} -gt 0 ]]; then
        display_result "$level" "${messages[@]}"
    else
        display_result "$level"
    fi
    
    # Log to file (if level is WARNING or higher)
    if [[ "$level" == "$LEVEL_WARNING" || "$level" == "$LEVEL_CRITICAL" ]]; then
        log_to_file "$level" "Analyzed: $cmd | Risk: $level"
        # 发送通知
        send_risk_notification "$level" "$cmd" "$(IFS=', '; echo "${messages[*]}")"
    fi
    if [[ "$level" == "$LEVEL_WARNING" || "$level" == "$LEVEL_CRITICAL" ]]; then
        log_to_file "$level" "Analyzed: $cmd | Risk: $level"
    fi
}

# Check command and output simple format (for scripting)
cmd_check() {
    local cmd="$1"
    
    # Initialize logging
    init_log
    
    # Analyze the command
    local result
    result=$(analyze_command "$cmd")
    
    # Parse result
    local level=""
    while IFS= read -r line; do
        case "$line" in
            LEVEL:*)
                level="${line#LEVEL:}"
                break
                ;;
        esac
    done <<< "$result"
    
    # Output simple format
    display_simple "$level" "$cmd"
    
    # Log if needed
    if [[ "$level" == "$LEVEL_WARNING" || "$level" == "$LEVEL_CRITICAL" ]]; then
        log_to_file "$level" "Checked: $cmd | Risk: $level"
        # 发送通知
        send_risk_notification "$level" "$cmd" "Risk detected in check mode"
    fi
}
# Log-only mode (no display, just log)
cmd_log_only() {
    local cmd="$1"
    
    # Initialize logging
    init_log
    
    # Analyze the command

# Log-only mode (no display, just log)
cmd_log_only() {
    local cmd="$1"
    
    # Initialize logging
    init_log
    
    # Analyze the command
    local result
    result=$(analyze_command "$cmd")
    
    # Parse result
    local level=""
    while IFS= read -r line; do
        case "$line" in
            LEVEL:*)
                level="${line#LEVEL:}"
                break
                ;;
        esac
    done <<< "$result"
    
    # Log the analysis
    log_to_file "$level" "Logged: $cmd | Risk: $level"
    # 发送通知
    if [[ "$level" == "$LEVEL_WARNING" || "$level" == "$LEVEL_CRITICAL" ]]; then
        send_risk_notification "$level" "$cmd" "Risk detected in log-only mode"
    fi
}

# Display help message
    cat << 'EOF'
OpenClaw Risk Advisor - Command Risk Analysis Tool

USAGE:
    bash risk-advisor.sh <command> [options] "<shell-command>"

COMMANDS:
    analyze <command>      Full analysis with detailed output
    check <command>        Simple output format (for scripting)
    log-only <command>     Log only, no output display
    help                   Show this help message
    version                Show version information

EXAMPLES:
    bash risk-advisor.sh analyze "rm -rf /"
    bash risk-advisor.sh check "sudo apt update"
    bash risk-advisor.sh analyze "docker run --privileged ubuntu"
    bash risk-advisor.sh log-only "ls -la"

ENVIRONMENT VARIABLES:
    OPENC_LAW_LANG         Set language (zh/en), default: zh
    
RISK LEVELS:
    CRITICAL    - Immediate data loss or system compromise
    WARNING     - Potential system impact
    INFO        - Standard operation
    SAFE        - No risk detected

IMPORTANT:
    This tool NEVER blocks command execution.
    It only provides warnings and logs them.
    Always review the risk assessment before executing commands.

EOF
}

# Display version
show_version() {
    echo "OpenClaw Risk Advisor v1.0.0"
    echo "Part of OpenClaw Secure Toolkit"
    echo "License: MIT"
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        show_help
        exit 1
    fi
    
    local subcommand="$1"
    shift
    
    case "$subcommand" in
        analyze)
            if [[ $# -lt 1 ]]; then
                error_exit "Missing command argument. Usage: risk-advisor.sh analyze '<command>'"
            fi
            cmd_analyze "$*"
            ;;
        check)
            if [[ $# -lt 1 ]]; then
                error_exit "Missing command argument. Usage: risk-advisor.sh check '<command>'"
            fi
            cmd_check "$*"
            ;;
        log-only|log_only)
            if [[ $# -lt 1 ]]; then
                error_exit "Missing command argument. Usage: risk-advisor.sh log-only '<command>'"
            fi
            cmd_log_only "$*"
            ;;
        help|-h|--help)
            show_help
            ;;
        version|-v|--version)
            show_version
            ;;
        *)
            error_exit "Unknown command: $subcommand. Use 'help' for usage information."
            ;;
    esac
}

# Run main function
main "$@"
