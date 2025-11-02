#!/bin/bash

set -euo pipefail

# =================== TimeZone Setup ===================
export TZ="Asia/Yangon"
START_EPOCH="$(date +%s)"
END_EPOCH="$(( START_EPOCH + 5*3600 ))"
fmt_dt() { date -d @"$1" "+%d.%m.%Y %I:%M %p"; }
START_LOCAL="$(fmt_dt "$START_EPOCH")"
END_LOCAL="$(fmt_dt "$END_EPOCH")"

# =================== GLOBAL VARIABLES INITIALIZATION ===================
# --- global variables ---
global_variables() {
    cpu="2"
    host_domain="m.googleapis.com"
    memory="2Gi"
    project_id=$(gcloud config get-value project 2>/dev/null || echo "")
    protocol=""
    region="us-central1"
    service_name="gcp-ahlflk"
    telegram_bot_token=""
    telegram_channel_id=""
    telegram_chat_id=""
    telegram_destination="none"
    telegram_group_id=""
    trojan_password="ahlflk"
    uuid="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
    vless_grpc_service_name="ahlflk"
    vless_path="/ahlflk"
}

# =================== VISUAL ELEMENTS SETUP ===================
# --- colors ---
colors() {
    red='\033[0;31m'
    green='\033[1;32m'
    yellow='\033[1;33m'
    blue='\033[1;34m'
    cyan='\033[1;36m'
    white='\033[1;37m'
    bold='\033[1m'
    nc='\033[0m'
}

# --- emojis ---
emojis() {
    success="✅"
    warning="⚠️"
    error_emoji="❌"
    info_emoji="ℹ️"
    protocol_icon="🌐"
    cpu_icon="🖥️"
    memory_icon="💾"
    region_icon="🌍"
    telegram_icon="📱"
    config_icon="⚙️"
    summary_icon="📋"
    deploy_icon="🚀"
    link_icon="🔗"
    time_icon="⏰"
}

# =================== DISPLAY UTILITIES ===================
# --- banner ---
banner() {
    header "$1"
}

# --- kv (key-value print helper) ---
kv() {
    printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "$1" "$2"
}

# =================== CLEANUP AND ERROR HANDLING ===================
# --- cleanup temporary files ---
cleanup() {
    log "cleaning up temporary files..."
    [[ -d "GCP-XRAY-Cloud-Run" ]] && rm -rf GCP-XRAY-Cloud-Run
    [[ -f "cloudbuild.yaml" ]] && rm -f cloudbuild.yaml
}

# --- error handler ---
error() {
    echo -e "${red}${error_emoji} [ERROR]${nc} ${white}$1${nc}"
    exit 1
}

# =================== LINK GENERATION ===================
# --- create share link for the selected protocol ---
create_share_link() {
    local service_name="$1"
    local service_domain="$2"
    local uuid_or_password="$3"
    local protocol_type="$4"
    local link=""
    case $protocol_type in
        "VLESS-WS")
            local path_encoded=$(echo "$vless_path" | sed 's/\//%2F/g')
            link="vless://${uuid_or_password}@${host_domain}:443?path=${path_encoded}&security=tls&encryption=none&host=${service_domain}&fp=randomized&type=ws&sni=${service_domain}#${service_name}_VLESS-WS"
            ;;
        "VLESS-gRPC")
            local service_name_encoded=$(echo "$vless_grpc_service_name" | sed 's/\//%2F/g')
            link="vless://${uuid_or_password}@${host_domain}:443?security=tls&encryption=none&host=${service_domain}&type=grpc&serviceName=${service_name_encoded}&sni=${service_domain}#${service_name}_VLESS-gRPC"
            ;;
        "Trojan-WS")
            local path_encoded=$(echo "$vless_path" | sed 's/\//%2F/g')
            link="trojan://${uuid_or_password}@${host_domain}:443?path=${path_encoded}&security=tls&host=${service_domain}&type=ws&sni=${service_domain}#${service_name}_Trojan-WS"
            ;;
        *)
            link="Error: Unsupported Protocol"
            ;;
    esac
    echo "$link"
}

# =================== UI AND LOGGING FUNCTIONS ===================
# --- header with fancy border ---
header() {
    local title="$1"
    local title_length=${#title}
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local box_width=$((title_length + 4))  # 2 spaces on each side
    local box_width_clamped=$((box_width < term_width ? box_width : term_width - 2))
    # Alternating border: =×=×=... starting with =
    local border=""
    for ((i=1; i<=box_width_clamped; i++)); do
        if (( i % 2 == 1 )); then
            border+="═"
        else
            border+="×"
        fi
    done
    local border_side="║"
    local padding_left=$(( (box_width_clamped - title_length) / 2 ))
    local padding_right=$((box_width_clamped - title_length - padding_left ))
    local spaces_left=$(printf ' %.0s' $(seq 1 $padding_left))
    local spaces_right=$(printf ' %.0s' $(seq 1 $padding_right))

    echo -e "\n${cyan}${bold}${border}${nc}"
    printf "${cyan}${bold}${border_side}${nc}${yellow}${bold}%s%s%s%s${cyan}${bold}${border_side}${nc}\n" "$spaces_left" "$title" "$spaces_right" ""
    echo -e "${cyan}${bold}${border}${nc}\n"
}

# --- info message ---
info() {
    echo -e "${blue}${bold}${info_emoji} [INFO]${nc} ${white}$1${nc}"
}

# --- log message with timestamp ---
log() {
    echo -e "${green}${success} [$(date +'%Y-%m-%d %H:%M:%S')]${nc} ${white}$1${nc}"
}

# --- warn message ---
warn() {
    echo -e "${yellow}${warning} [WARNING]${nc} ${white}$1${nc}"
}

# --- selected info message ---
selected_info() {
    echo -e "${green}${bold}${success} Selected: ${cyan}${1}${nc}\n"
}

# =================== CONFIG PREPARATION ===================
# --- prepare Xray config files based on protocol ---
prepare_config_files() {
    log "preparing Xray config files for $protocol..."
    [[ ! -f "config.json" ]] && error "config.json not found in GCP-XRAY-Cloud-Run directory."
    case $protocol in
        "VLESS-WS")
            sed -i "s/PLACEHOLDER_UUID/$uuid/g" config.json
            sed -i "s|/vless|$vless_path|g" config.json
            log "VLESS-WS config prepared with UUID and Path"
            ;;
        "VLESS-gRPC")
            sed -i "s/PLACEHOLDER_UUID/$uuid/g" config.json
            sed -i 's|"network": "ws"|"network": "grpc"|g' config.json
            sed -i "s|\"wsSettings\": { \"path\": \"/vless\" }|\"grpcSettings\": { \"serviceName\": \"$vless_grpc_service_name\" }|g" config.json
            log "VLESS-gRPC config prepared with UUID and ServiceName"
            ;;
        "Trojan-WS")
            sed -i 's|"protocol": "vless"|"protocol": "trojan"|g' config.json
            sed -i "s|\"clients\": \[ { \"id\": \"PLACEHOLDER_UUID\" } ]|\"users\": \[ { \"password\": \"$trojan_password\" } ]|g" config.json
            sed -i "s|\"path\": \"/vless\"|\"path\": \"$vless_path\"|g" config.json
            log "Trojan-WS config prepared with Password and Path"
            ;;
        *)
            error "unknown protocol: $protocol."
            ;;
    esac
}

# =================== USER INPUT SELECTION FUNCTIONS (IN EXECUTION ORDER) ===================
# --- Step 1: Telegram Destination ---
select_telegram_destination() {
    header "${telegram_icon} Telegram Destination"
    echo -e "${cyan}Available Options:${nc}"
    echo -e "${bold}1.${nc} Don't send to Telegram ${green}➡️ [DEFAULT]${nc}"
    echo -e "${bold}2.${nc} Send to Channel Only"
    echo -e "${bold}3.${nc} Send to Group Only"
    echo -e "${bold}4.${nc} Send to Both Channel and Bot"
    echo -e "${bold}5.${nc} Send to Bot Private Message"
    echo
    while true; do
        read -p "Select destination (1): " telegram_choice
        telegram_choice=${telegram_choice:-1}
        case $telegram_choice in
            1) 
                telegram_destination="none"
                break 
                ;;
            2) 
                telegram_destination="channel"
                while true; do
                    read -p "Enter Telegram Channel ID: " telegram_channel_id
                    validate_channel_id "$telegram_channel_id" && break
                done
                break 
                ;;
            3) 
                telegram_destination="group"
                while true; do
                    read -p "Enter Telegram Group ID: " telegram_group_id
                    validate_channel_id "$telegram_group_id" && break
                done
                break 
                ;;
            4) 
                telegram_destination="both"
                while true; do
                    read -p "Enter Telegram Channel ID: " telegram_channel_id
                    validate_channel_id "$telegram_channel_id" && break
                done
                while true; do
                    read -p "Enter your Chat ID (for bot private message): " telegram_chat_id
                    validate_chat_id "$telegram_chat_id" && break
                done
                break 
                ;;
            5) 
                telegram_destination="bot"
                while true; do
                    read -p "Enter your Chat ID (for bot private message): " telegram_chat_id
                    validate_chat_id "$telegram_chat_id" && break
                done
                break 
                ;;
            *) echo -e "${red}Invalid selection. Please enter a number between 1-5.${nc}" ;;
        esac
    done

    if [[ "$telegram_destination" != "none" ]]; then
        echo -e "${cyan}Bot Token Options:${nc}"
        echo -e "${bold}1.${nc} Enter bot token ${green}[REQUIRED]${nc}"
        echo
        
        while true; do
            read -p "Enter Telegram Bot Token: " telegram_bot_token
            if validate_bot_token "$telegram_bot_token"; then
                break
            else
                warn "Invalid Telegram Bot Token format. Please try again."
            fi
        done
        
        selected_info "Bot Token: ${telegram_bot_token:0:8}..."
    fi
    selected_info "Telegram Destination: $telegram_destination"
}

# --- Step 2: V2Ray Protocol Selection ---
select_protocol() {
    header "${protocol_icon} V2Ray Protocol Selection"
    echo -e "${cyan}Available Options:${nc}"
    echo -e "${bold}1.${nc} VLESS-WS (VLESS + WebSocket + TLS) ${green}➡️ [DEFAULT]${nc}"
    echo -e "${bold}2.${nc} VLESS-gRPC (VLESS + gRPC + TLS)"
    echo -e "${bold}3.${nc} Trojan-WS (Trojan + WebSocket + TLS)"
    echo
    while true; do
        read -p "Select V2Ray Protocol (1): " protocol_choice
        protocol_choice=${protocol_choice:-1}
        case $protocol_choice in
            1) 
                protocol="VLESS-WS"
                vless_path="/ahlflk"
                break 
                ;;
            2) 
                protocol="VLESS-gRPC"
                vless_grpc_service_name="ahlflk"
                break 
                ;;
            3) 
                protocol="Trojan-WS"
                vless_path="/ahlflk"
                trojan_password="ahlflk"
                break 
                ;;
            *) echo -e "${red}Invalid selection. Please enter a number between 1-3.${nc}" ;;
        esac
    done
    selected_info "Protocol: $protocol"
}

# --- Step 3: Region Selection ---
select_region() {
    header "${region_icon} Region Selection"
    echo -e "${cyan}Available Regions:${nc}"
    echo -e "${bold}1.${nc}  🇺🇸 us-central1 (Iowa, USA) ${green}➡️ [DEFAULT]${nc}"
    echo -e "${bold}2.${nc}  🇺🇸 us-east1 (South Carolina, USA)"
    echo -e "${bold}3.${nc}  🇺🇸 us-south1 (Texas, USA)"
    echo -e "${bold}4.${nc}  🇺🇸 us-west1 (Oregon, USA)"
    echo -e "${bold}5.${nc}  🇺🇸 us-west2 (California, USA)"
    echo -e "${bold}6.${nc}  🇨🇦 northamerica-northeast2 (Toronto, Canada)"
    echo -e "${bold}7.${nc}  🇸🇬 asia-southeast1 (Singapore)"
    echo -e "${bold}8.${nc}  🇯🇵 asia-northeast1 (Tokyo, Japan)"
    echo -e "${bold}9.${nc}  🇹🇼 asia-east1 (Taiwan)"
    echo -e "${bold}10.${nc} 🇭🇰 asia-east2 (Hong Kong)"
    echo -e "${bold}11.${nc} 🇮🇳 asia-south1 (Mumbai, India)"
    echo -e "${bold}12.${nc} 🇮🇩 asia-southeast2 (Jakarta, Indonesia)"
    echo
    while true; do
        read -p "Select region (1): " region_choice
        region_choice=${region_choice:-1}
        case $region_choice in
            1) region="us-central1"; break ;;
            2) region="us-east1"; break ;;
            3) region="us-south1"; break ;;
            4) region="us-west1"; break ;;
            5) region="us-west2"; break ;;
            6) region="northamerica-northeast2"; break ;;
            7) region="asia-southeast1"; break ;;
            8) region="asia-northeast1"; break ;;
            9) region="asia-east1"; break ;;
            10) region="asia-east2"; break ;;
            11) region="asia-south1"; break ;;
            12) region="asia-southeast2"; break ;;
            *) echo -e "${red}Invalid selection. Please enter a number between 1-12.${nc}" ;;
        esac
    done
    selected_info "Region: $region"
}

# --- Step 4: CPU Configuration ---
select_cpu() {
    header "${cpu_icon} CPU Configuration"
    echo -e "${cyan}Available Options:${nc}"
    echo -e "${bold}1.${nc}  1 CPU Core (Lightweight)"
    echo -e "${bold}2.${nc}  2 CPU Cores (Balanced) ${green}➡️ [DEFAULT]${nc}"
    echo -e "${bold}3.${nc}  4 CPU Cores (Performance)"
    echo -e "${bold}4.${nc}  8 CPU Cores (High Performance)"
    echo -e "${bold}5.${nc} 16 CPU Cores (Advanced - Requires Dedicated Machine Type)"
    echo
    while true; do
        read -p "Select CPU cores (2): " cpu_choice
        cpu_choice=${cpu_choice:-2}
        case $cpu_choice in
            1) cpu="1"; break ;;
            2) cpu="2"; break ;;
            3) cpu="4"; break ;;
            4) cpu="8"; break ;;
            5) cpu="16"; warn "16 cores requires --machine-type for Cloud Run v2."; break ;;
            *) echo -e "${red}Invalid selection. Please enter a number between 1-5.${nc}" ;;
        esac
    done
    selected_info "CPU: $cpu core(s)"
}

# --- Step 5: Memory Configuration ---
select_memory() {
    header "${memory_icon} Memory Configuration"
    echo -e "${cyan}Available Options:${nc}"
    echo -e "${bold}1.${nc} 512Mi (Lightweight)"
    echo -e "${bold}2.${nc} 1Gi (Basic)"
    echo -e "${bold}3.${nc} 2Gi (Balanced) ${green}➡️ [DEFAULT]${nc}"
    echo -e "${bold}4.${nc} 4Gi (Performance)"
    echo -e "${bold}5.${nc} 8Gi (High Performance)"
    echo -e "${bold}6.${nc} 16Gi (Advanced)"
    echo -e "${bold}7.${nc} 32Gi (Maximum)"
    echo
    while true; do
        read -p "Select memory (3): " memory_choice
        memory_choice=${memory_choice:-3}
        case $memory_choice in
            1) memory="512Mi"; break ;;
            2) memory="1Gi"; break ;;
            3) memory="2Gi"; break ;;
            4) memory="4Gi"; break ;;
            5) memory="8Gi"; break ;;
            6) memory="16Gi"; break ;;
            7) memory="32Gi"; break ;;
            *) echo -e "${red}Invalid selection. Please enter a number between 1-7.${nc}" ;;
        esac
    done
    validate_memory_config
    selected_info "Memory: $memory"
}

# --- Step 6: Service Name Configuration ---
select_service_name() {
    header "${config_icon} Service Name Configuration"
    echo -e "${cyan}Available Options:${nc}"
    echo -e "${bold}1.${nc} Use default (gcp-ahlflk) ${green}➡️ [DEFAULT]${nc}"
    echo -e "${bold}2.${nc} Enter custom service name"
    echo
    read -p "Select (1) or enter custom name: " input
    case $input in
        1|"" ) service_name="gcp-ahlflk" ;;
        2 ) 
            read -p "Enter custom service name: " custom_service
            service_name=${custom_service:-"gcp-ahlflk"}
            [[ -z "$service_name" ]] && error "Service name cannot be empty."
            ;;
        * ) service_name="$input" ; [[ -z "$service_name" ]] && error "Service name cannot be empty." ;;
    esac
    selected_info "Service Name: $service_name"
}

# --- Step 7: Host Domain Configuration ---
select_host_domain() {
    header "${config_icon} Host Domain Configuration"
    echo -e "${cyan}Available Options:${nc}"
    echo -e "${bold}1.${nc} Use default (m.googleapis.com) ${green}➡️ [DEFAULT]${nc}"
    echo -e "${bold}2.${nc} Enter custom host domain"
    echo
    read -p "Select (1) or enter custom domain: " input
    case $input in
        1|"" ) host_domain="m.googleapis.com" ;;
        2 ) 
            read -p "Enter custom host domain: " custom_domain
            host_domain=${custom_domain:-"m.googleapis.com"}
            ;;
        * ) host_domain="$input" ;;
    esac
    selected_info "Host Domain: $host_domain"
}

# --- Step 8: UUID/Password Configuration ---
select_uuid() {
    header "${config_icon} UUID/Password Configuration"
    
    if [[ "$protocol" == "Trojan-WS" ]]; then
        # Trojan Password
        echo -e "${cyan}Trojan Password Options:${nc}"
        echo -e "${bold}1.${nc} Use default password (ahlflk) ${green}➡️ [DEFAULT]${nc}"
        echo -e "${bold}2.${nc} Enter custom password"
        echo
        
        while true; do
            read -p "Select Password option (1): " trojan_pw_choice
            trojan_pw_choice=${trojan_pw_choice:-1}
            case $trojan_pw_choice in
                1)
                    trojan_password="ahlflk"
                    log "Using default Trojan Password"
                    break
                    ;;
                2)
                    while true; do
                        read -p "Enter custom Trojan Password: " TROJAN_PASSWORD
                        if [[ -n "$TROJAN_PASSWORD" ]]; then
                            trojan_password="$TROJAN_PASSWORD"
                            log "Using custom Trojan Password"
                            break
                        fi
                    done
                    break
                    ;;
                *) echo -e "${red}Invalid selection. Please enter 1 or 2.${nc}" ;;
            esac
        done
        selected_info "Trojan Password: ${trojan_password:0:8}..."
    else
        # VLESS UUID
        echo -e "${cyan}UUID Options:${nc}"
        echo -e "${bold}1.${nc} Use default UUID (3675119c-14fc-46a4-b5f3-9a2c91a7d802) ${green}➡️ [DEFAULT]${nc}"
        echo -e "${bold}2.${nc} Generate new UUID"
        echo
        
        while true; do
            read -p "Select UUID option (1): " uuid_choice
            uuid_choice=${uuid_choice:-1}
            case $uuid_choice in
                1)
                    uuid="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
                    echo -e "${green}Using default UUID: $uuid${nc}"
                    break
                    ;;
                2)
                    if command -v uuidgen &>/dev/null; then
                        uuid=$(uuidgen)
                    else
                        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuid="3675119c-14fc-46a4-b5f3-9a2c91a7d802")
                    fi
                    echo -e "${green}Generated UUID: $uuid${nc}"
                    break
                    ;;
                *) echo -e "${red}Invalid selection. Please enter 1 or 2.${nc}" ;;
            esac
        done
        selected_info "UUID: ${uuid:0:8}..."
    fi
    echo
    
    if [[ "$protocol" == "VLESS-gRPC" ]]; then
        read -p "Enter VLESS-gRPC ServiceName [default: ahlflk]: " custom_service_name
        vless_grpc_service_name=${custom_service_name:-"ahlflk"}
        selected_info "gRPC ServiceName: $vless_grpc_service_name"
    fi
}

# =================== SUMMARY AND CONFIRMATION ===================
# --- Configuration Summary and Confirmation ---
show_config_summary() {
    header "${summary_icon} Configuration Summary"
    echo -e "${cyan}${bold}┌──────────────────┬──────────────────────────┐${nc}"
    echo -e "${cyan}${bold}│ Parameter        │ Value                    │${nc}"
    echo -e "${cyan}${bold}├──────────────────┼──────────────────────────┤${nc}"
    printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Protocol" "$protocol"
    printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Project ID" "$project_id"
    printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Region" "$region"
    printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Service Name" "$service_name"
    printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Host Domain" "$host_domain"
    
    if [[ "$protocol" == "Trojan-WS" ]]; then
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Password" "${trojan_password:0:8}..."
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Path" "$vless_path"
    elif [[ "$protocol" == "VLESS-gRPC" ]]; then
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "UUID" "${uuid:0:8}..."
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "ServiceName" "$vless_grpc_service_name"
    else
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "UUID" "${uuid:0:8}..."
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Path" "$vless_path"
    fi
    
    printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "CPU" "$cpu core(s)"
    printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Memory" "$memory"
    
    if [[ "$telegram_destination" != "none" ]]; then
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Bot Token" "${telegram_bot_token:0:8}..."
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Destination" "$telegram_destination"
        if [[ "$telegram_destination" == "channel" || "$telegram_destination" == "both" ]]; then
            printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Channel ID" "$telegram_channel_id"
        fi
        if [[ "$telegram_destination" == "bot" || "$telegram_destination" == "both" ]]; then
            printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Chat ID" "$telegram_chat_id"
        fi
        if [[ "$telegram_destination" == "group" ]]; then
            printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Group ID" "$telegram_group_id"
        fi
    else
        printf "${cyan}${bold}│ %-16s │ %-24s │${nc}\n" "Telegram" "Not configured"
    fi
    echo -e "${cyan}${bold}└──────────────────┴──────────────────────────┘${nc}\n"
    
    # Deployment Time banner and kv after summary table
    banner "${time_icon} Deployment Time"
    kv "Start:" "${START_LOCAL}"
    kv "End:"   "${END_LOCAL}"
    
    echo
    
    while true; do
        read -p "Proceed with deployment? (y/n): " confirm
        case $confirm in
            [Yy]* ) break;;
            [Nn]* ) 
                info "Deployment cancelled by user"
                exit 0
                ;;
            * ) echo -e "${red}Please answer yes (y) or no (n).${nc}";;
        esac
    done
}

# =================== VALIDATION FUNCTIONS ===================
# --- validate bot token ---
validate_bot_token() {
    local token_pattern='^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$'
    if [[ ! $1 =~ $token_pattern ]]; then
        return 1
    fi
    return 0
}

# --- validate channel id ---
validate_channel_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# --- validate chat id ---
validate_chat_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# --- validate uuid ---
validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! $1 =~ $uuid_pattern ]]; then
        warn "Invalid UUID format. Please try again."
        return 1
    fi
    return 0
}

# --- validate memory config ---
validate_memory_config() {
    local cpu_num=$cpu
    local memory_num=$(echo $memory | sed 's/[^0-9]*//g' | tr -d ' ')
    local memory_unit=$(echo $memory | sed 's/[0-9]*//g' | tr -d ' ')
    
    # Convert everything to Mi for comparison
    if [[ "$memory_unit" == "Gi" ]]; then
        memory_num=$((memory_num * 1024))
    fi
    
    local min_memory=0 max_memory=0
    
    case $cpu_num in
        1) 
            min_memory=512
            max_memory=2048
            ;;
        2) 
            min_memory=1024
            max_memory=4096
            ;;
        4) 
            min_memory=2048
            max_memory=8192
            ;;
        8) 
            min_memory=4096
            max_memory=16384
            ;;
        16) 
            min_memory=8192
            max_memory=32768  # Up to 32Gi
            ;;
    esac
    
    if [[ $memory_num -lt $min_memory ]]; then
        warn "Memory ($memory) might be too low for $cpu CPU core(s). Min: $((min_memory / 1024))Gi"
        read -p "Continue? (y/n): " confirm
        if [[ ! $confirm =~ [Yy] ]]; then
            select_memory
        fi
    elif [[ $memory_num -gt $max_memory ]]; then
        warn "Memory ($memory) might be too high for $cpu CPU core(s). Max: $((max_memory / 1024))Gi"
        read -p "Continue? (y/n): " confirm
        if [[ ! $confirm =~ [Yy] ]]; then
            select_memory
        fi
    fi
}

# --- validate prerequisites ---
validate_prerequisites() {
    log "Validating prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI is not installed. Please install Google Cloud SDK."
    fi
    
    if ! command -v git &> /dev/null; then
        error "git is not installed. Please install git."
    fi
    
    local PROJECT_ID=$(gcloud config get-value project)
    if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
        error "No project configured. Run: gcloud config set project PROJECT_ID"
    fi
}

# =================== TELEGRAM INTEGRATION ===================
# --- send message to Telegram ---
send_to_telegram() {
    local chat_id="$1"
    local message="$2"
    # Escape special Markdown chars
    message=$(echo "$message" | sed 's/\*/\\*/g; s/_/\\_/g; s/`/\\`/g; s/\[/\\[/g')
    local response
    
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${chat_id}\",
            \"text\": \"$message\",
            \"parse_mode\": \"MARKDOWN\",
            \"disable_web_page_preview\": true,
            \"reply_markup\": {
                \"inline_keyboard\": [
                    [
                        {\"text\": \"🔗 Open URL\", \"url\": \"$service_url\"},
                        {\"text\": \"📋 Copy Xray Link\", \"callback_data\": \"copy_xray_link\"}
                    ]
                ]
            }
        }" \
        https://api.telegram.org/bot${telegram_bot_token}/sendMessage)
    
    local http_code="${response: -3}"
    local content="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        warn "Failed to send to Telegram (HTTP $http_code): $content"
        return 1
    fi
}

# --- send deployment notification to selected destinations ---
send_deployment_notification() {
    local message="$1"
    local success_count=0
    
    case $telegram_destination in
        "channel")
            log "Sending to Telegram Channel..."
            if send_to_telegram "$telegram_channel_id" "$message"; then
                log "✅ Successfully sent to Telegram Channel"
                success_count=$((success_count + 1))
            else
                warn "Failed to send to Telegram Channel"
            fi
            ;;
            
        "bot")
            log "Sending to Bot private message..."
            if send_to_telegram "$telegram_chat_id" "$message"; then
                log "✅ Successfully sent to Bot private message"
                success_count=$((success_count + 1))
            else
                warn "Failed to send to Bot private message"
            fi
            ;;
            
        "both")
            log "Sending to both Channel and Bot..."
            if send_to_telegram "$telegram_channel_id" "$message"; then
                success_count=$((success_count + 1))
            fi
            if send_to_telegram "$telegram_chat_id" "$message"; then
                success_count=$((success_count + 1))
            fi
            ;;
            
        "group")
            log "Sending to Telegram Group..."
            if send_to_telegram "$telegram_group_id" "$message"; then
                log "✅ Successfully sent to Telegram Group"
                success_count=$((success_count + 1))
            else
                warn "Failed to send to Telegram Group"
            fi
            ;;
            
        "none")
            log "Skipping Telegram notification as configured"
            return 0
            ;;
    esac
    
    if [[ $success_count -gt 0 ]]; then
        log "Telegram notification completed ($success_count successful)"
        return 0
    else
        warn "All Telegram notifications failed, but deployment was successful"
        return 1
    fi
}

# =================== UTILITIES ===================
# --- spinner for long-running tasks ---
spinner() {
    local pid=$1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local delay=0.1
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# =================== MAIN FLOW ===================
# Initialize globals and setup
colors
emojis
global_variables
trap cleanup EXIT

# Display main header
header "${deploy_icon} GCP Cloud Run VLESS/Trojan Deployment"

# User input sequence: Gather configurations step-by-step (in order)
select_telegram_destination
select_protocol
select_region
select_cpu
select_memory
select_service_name
select_host_domain
select_uuid

# Show summary and confirm (includes Deployment Time banner after summary table)
show_config_summary

# Validate prerequisites before deployment
validate_prerequisites

# Deployment steps
log "Starting Cloud Run deployment..."
log "Protocol: $protocol | Project: $project_id | Region: $region | Service: $service_name | CPU: $cpu | Memory: $memory"

# Enable required APIs
log "Enabling required APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    iam.googleapis.com \
    --quiet

# Cleanup any previous attempts
cleanup

# Clone repository
log "Cloning repository..."
if ! git clone https://github.com/ahlflk/GCP-XRAY-Cloud-Run.git; then
    warn "Failed to clone repository - using local files if available"
fi

if [[ ! -d "GCP-XRAY-Cloud-Run" ]]; then
    error "GCP-XRAY-Cloud-Run directory not found. Please create it with Dockerfile and config.json."
fi

cd GCP-XRAY-Cloud-Run

# Prepare config
prepare_config_files

# Quiet the Dockerfile for cleaner logs
if [[ -f "Dockerfile" ]]; then
    sed -i 's/unzip Xray-linux-64.zip/unzip -q Xray-linux-64.zip/g' Dockerfile
    sed -i 's/apt-get update -y/apt-get update -qq -y/g' Dockerfile
    sed -i 's/apt-get install -y/apt-get install -qq -y/g' Dockerfile
    log "Quietened Dockerfile (unzip -q and apt -qq added to reduce logs)"
fi

# Create cloudbuild.yaml for quiet build
cat > cloudbuild.yaml << EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$project_id/gcp-v2ray-image', '.']
  env:
  - 'NO_COLOR=1'
  - 'DOCKER_BUILDKIT=1'  # Use BuildKit for quieter progress
- name: 'gcr.io/cloud-builders/docker'
  args: ['push', 'gcr.io/$project_id/gcp-v2ray-image']
  env:
  - 'NO_COLOR=1'
images:
- 'gcr.io/$project_id/gcp-v2ray-image'
EOF
log "Created cloudbuild.yaml for clean, quiet build logs"

# Build image
log "Building container image (quiet mode)..."
if ! gcloud builds submit --config cloudbuild.yaml --quiet > /dev/null 2>&1; then
    error "Build failed. Check Dockerfile for issues with geo files download."
fi

# Deploy to Cloud Run
log "Deploying to Cloud Run..."
deploy_cmd="gcloud run deploy ${service_name} \
    --image gcr.io/${project_id}/gcp-v2ray-image \
    --platform managed \
    --region ${region} \
    --allow-unauthenticated \
    --cpu ${cpu} \
    --memory ${memory} \
    --quiet"
if [[ $cpu == "16" ]]; then
    deploy_cmd="$deploy_cmd --machine-type e2-standard-16"  # Example for dedicated
fi
if ! eval "$deploy_cmd"; then
    error "Deployment failed"
    exit 1
fi

# Get service details
service_url=$(gcloud run services describe ${service_name} \
    --region ${region} \
    --format 'value(status.url)' \
    --quiet)

service_domain=$(echo $service_url | sed 's|https://||')

# Create share link
link_user_id=""
if [[ "$protocol" == "Trojan-WS" ]]; then
    link_user_id="$trojan_password"
else
    link_user_id="$uuid"
fi

share_link=$(create_share_link "$service_name" "$service_domain" "$link_user_id" "$protocol")

# Prepare messages
MESSAGE="*🚀 Cloud Run ${protocol} Deploy → Successful ✅*
━━━━━━━━━━━━━━━━━━━━
*Project:* \`${project_id}\`
*Service:* \`${service_name}\`
*Region:* \`${region}\`
*CPU:* \`${cpu} core(s)\`
*Memory:* \`${memory}\`
*URL:* \`${service_url}\`
*Start Time:* \`${START_LOCAL}\`
*End Time:* \`${END_LOCAL}\`

🔗 **Xray Link (Copy & Import):**
\`\`\`
${share_link}
\`\`\`
*Usage:* Long-press the link above to copy and import to your V2Ray/Xray client.
━━━━━━━━━━━━━━━━━━━━"

CONSOLE_MESSAGE="🚀 Cloud Run ${protocol} Deploy Success ✅
━━━━━━━━━━━━━━━━━━━━
Project: ${project_id}
Service: ${service_name}
Region: ${region}
CPU: ${cpu} core(s)
Memory: ${memory}
URL: ${service_url}
Start Time: ${START_LOCAL}
End Time: ${END_LOCAL}

${share_link}

Usage: Copy the above link and import to your V2Ray/Xray client.
━━━━━━━━━━━━━━━━━━━━"

# Save and display
echo "$CONSOLE_MESSAGE" > deployment-info.txt
log "Deployment info saved to deployment-info.txt"

echo
info "=== Deployment Information ==="
echo "$CONSOLE_MESSAGE"
echo

# Send to Telegram if configured
if [[ "$telegram_destination" != "none" ]]; then
    log "Sending deployment info to Telegram..."
    send_deployment_notification "$MESSAGE"
else
    log "Skipping Telegram notification as per user selection"
fi

log "Deployment completed successfully! 🎉"
log "Service URL: $service_url"
log "Configuration saved to: deployment-info.txt"