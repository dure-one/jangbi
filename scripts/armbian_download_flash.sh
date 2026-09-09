#!/usr/bin/env bash
# armbian_download_flash.sh - Download and flash Armbian/DietPi images to SD cards or USB devices
# Usage: ./armbian_download_flash.sh [--armbian|--dietpi]

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JANGBI_ROOT="$(dirname "${SCRIPT_DIR}")"
DOWNLOAD_DIR="${JANGBI_ROOT}/imgs"
# Use user-specific temp directory to avoid permission issues
TEMP_DIR="/tmp/armbian_flash_$$"  # $$ is the process ID, making it unique

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${CYAN}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_fatal() {
    echo -e "${RED}[FATAL]${NC} $*" >&2
    exit 1
}

# Cleanup on exit
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# Initialize
mkdir -p "${DOWNLOAD_DIR}" "${TEMP_DIR}"

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        OS_TYPE="linux"
    elif [[ "$(uname -s)" == "OpenBSD" ]]; then
        OS_TYPE="openbsd"
    else
        OS_TYPE="unknown"
    fi
    echo "$OS_TYPE"
}

# Check root privileges early
check_root_privileges() {
    local os_type=$(detect_os)

    if [[ $EUID -eq 0 ]]; then
        log_success "Running as root - full privileges available"
        return 0
    fi

    # Not root - check if we can elevate
    log_warning "Not running as root. Checking privilege escalation..."

    if [[ "$os_type" == "openbsd" ]]; then
        # Check if doas is available and configured
        if ! command -v doas &> /dev/null; then
            log_fatal "doas not found. Please run script as root: doas $0"
        fi

        # Test if doas works (will prompt for password if needed)
        if ! doas true 2>/dev/null; then
            log_fatal "doas authentication failed. Please configure /etc/doas.conf or run as root"
        fi

        log_success "doas available and configured"
    else
        # Linux - check for sudo
        if ! command -v sudo &> /dev/null; then
            log_fatal "sudo not found. Please run script as root"
        fi

        # Test if sudo works
        if ! sudo -n true 2>/dev/null; then
            log_warning "sudo requires password. You'll be prompted when needed."
            # Test with password prompt
            if ! sudo true; then
                log_fatal "sudo authentication failed"
            fi
        fi

        log_success "sudo available and configured"
    fi

    return 0
}

# Check required tools
check_dependencies() {
    local missing_tools=()
    local os_type=$(detect_os)

    # Common tools
    for tool in curl jq wget dd; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    # OS-specific tools
    if [[ "$os_type" == "linux" ]]; then
        if ! command -v lsblk &> /dev/null; then
            missing_tools+=("lsblk")
        fi
    elif [[ "$os_type" == "openbsd" ]]; then
        if ! command -v sysctl &> /dev/null; then
            missing_tools+=("sysctl")
        fi
        if ! command -v disklabel &> /dev/null; then
            missing_tools+=("disklabel")
        fi
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_fatal "Missing required tools: ${missing_tools[*]}"
    fi
}

# Get Armbian official releases (filter "trunk" releases from armbian/os)
get_armbian_official_releases() {
    # All log output to stderr to avoid polluting return value
    log_info "Fetching Armbian official releases from GitHub..." >&2

    local api_url="https://api.github.com/repos/armbian/os/releases"
    local curl_cmd="curl -sSL"

    # Use GitHub token if available to avoid rate limiting
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl_cmd="curl -sSL -H \"Authorization: Bearer ${GITHUB_TOKEN}\""
        log_info "Using GitHub token for API request" >&2
    fi

    # Get all releases and filter for "trunk" in the name
    # Use compact output (no -r flag) to get valid JSON objects per line
    local releases=$(eval ${curl_cmd} "${api_url}" | jq -c '.[] | select(.name | contains("trunk")) | {name: .name, assets: [.assets[] | {name: .name, url: .browser_download_url, size: .size}]}')

    if [[ -z "$releases" ]]; then
        log_error "No trunk releases found" >&2
        return 1
    fi

    # Return only the JSON data to stdout
    echo "$releases"
}

# Get Armbian community releases (filter "trunk" releases from armbian/community)
get_armbian_community_releases() {
    # All log output to stderr to avoid polluting return value
    log_info "Fetching Armbian community releases from GitHub..." >&2

    local api_url="https://api.github.com/repos/armbian/community/releases"
    local curl_cmd="curl -sSL"

    # Use GitHub token if available to avoid rate limiting
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl_cmd="curl -sSL -H \"Authorization: Bearer ${GITHUB_TOKEN}\""
        log_info "Using GitHub token for API request" >&2
    fi

    # Get all releases and filter for "trunk" in the name
    local releases=$(eval ${curl_cmd} "${api_url}" | jq -c '.[] | select(.name | contains("trunk")) | {name: .name, assets: [.assets[] | {name: .name, url: .browser_download_url, size: .size}]}')

    if [[ -z "$releases" ]]; then
        log_error "No trunk releases found in community repo" >&2
        return 1
    fi

    # Return only the JSON data to stdout
    echo "$releases"
}

# Get DietPi images - scrape from downloads page
get_dietpi_images() {
    # Log to stderr to avoid polluting return value
    log_info "Fetching DietPi images from downloads page..." >&2

    local downloads_page="https://dietpi.com/downloads/images/"

    # Fetch page and extract .img.xz links
    local images=$(curl -sSL "${downloads_page}" | \
        grep -o 'DietPi_[^"]*\.img\.xz' | \
        sort -u)

    if [[ -z "$images" ]]; then
        log_error "Failed to fetch DietPi images from downloads page" >&2
        return 1
    fi

    # Convert to JSON array
    local json_array="["
    local first=1
    while IFS= read -r img; do
        if [[ -n "$img" ]]; then
            [[ $first -eq 0 ]] && json_array+=","
            first=0
            json_array+="{\"name\":\"$img\",\"url\":\"${downloads_page}${img}\"}"
        fi
    done <<< "$images"
    json_array+="]"

    echo "$json_array" | jq '.'
}

# Parse DietPi filename - Format: DietPi_DEVICE-ARCH-VERSION.img.xz
parse_dietpi_name() {
    local name="$1"
    # Remove DietPi_ prefix and .img.xz suffix
    local core=$(echo "$name" | sed 's/^DietPi_//; s/\.img\.xz$//')

    # Split by last two hyphens: DEVICE-ARCH-VERSION
    # Example: NanoPiR5-ARMv8-Bookworm
    local device=$(echo "$core" | rev | cut -d'-' -f3- | rev)
    local arch=$(echo "$core" | rev | cut -d'-' -f2 | rev)
    local version=$(echo "$core" | rev | cut -d'-' -f1 | rev)

    echo "${device}|${arch}|${version}"
}

# Parse Armbian assets and show device list
# Parse Armbian filename - handles both official and community formats
# Official format: Armbian_VERSION_DEVICE_DISTRO_KERNEL_TYPE.img.xz
# Community format: Armbian-community_VERSION_DEVICE_DISTRO_KERNEL_TYPE.img.xz (or similar)
parse_armbian_name() {
    local name="$1"

    # Detect format by checking prefix
    if [[ "$name" =~ ^Armbian-community_ ]] || [[ "$name" =~ ^Armbian_community_ ]]; then
        # Community format: prefix is "Armbian-community" or "Armbian_community"
        # Remove prefix to normalize: Armbian-community_VERSION_DEVICE... -> VERSION_DEVICE...
        local normalized=$(echo "$name" | sed 's/^Armbian-community_//; s/^Armbian_community_//')

        # Now split by underscore
        # Field 1: VERSION (skip)
        # Field 2: DEVICE
        # Field 3+: DISTRO, KERNEL, TYPE
        local device=$(echo "$normalized" | cut -d'_' -f2)
        local kernel=$(echo "$normalized" | cut -d'_' -f3-4)
        local type=$(echo "$normalized" | sed 's/.*_\([^_]*\)\.img.*/\1/')
    else
        # Official format: Armbian_VERSION_DEVICE_DISTRO_KERNEL_TYPE.img.xz
        # Field 1: Armbian (prefix)
        # Field 2: VERSION (skip)
        # Field 3: DEVICE
        # Field 4+: DISTRO, KERNEL, TYPE
        local device=$(echo "$name" | cut -d'_' -f3)
        local kernel=$(echo "$name" | cut -d'_' -f4-5)
        local type=$(echo "$name" | sed 's/.*_\([^_]*\)\.img.*/\1/')
    fi

    echo "${device}|${kernel}|${type}"
}

show_armbian_devices() {
    local releases="$1"
    local source="${2:-Official}"  # Default to "Official" if not specified
    local release_count=$(($(echo "$releases" | wc -l)))

    log_info "Found $release_count Armbian $source trunk release(s)" >&2
    echo "" >&2

    # Create combined list of all assets
    local all_assets="${TEMP_DIR}/armbian_assets.json"
    echo "$releases" | jq -s '[.[] | .assets[]] | unique_by(.name)' > "$all_assets"

    local asset_count=$(jq length "$all_assets")
    if [[ $asset_count -eq 0 ]]; then
        log_error "No assets found in trunk releases" >&2
        return 1
    fi

    log_info "Total: $asset_count images available" >&2

    # STEP 2: Extract unique devices (Step 1 is now release type selection)
    declare -A device_counts
    for ((i=0; i<asset_count; i++)); do
        local name=$(jq -r ".[$i].name" "$all_assets")
        local parsed=$(parse_armbian_name "$name")
        local device=$(echo "$parsed" | cut -d'|' -f1)
        # Handle first occurrence of device
        if [[ -z "${device_counts[$device]:-}" ]]; then
            device_counts[$device]=1
        else
            ((device_counts[$device]++))
        fi
    done

    local devices=($(printf '%s\n' "${!device_counts[@]}" | sort))

    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  STEP 2: Select Device (${#devices[@]} available in $source)" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    for ((i=0; i<${#devices[@]}; i++)); do
        printf "%3d) %-35s (%2d images)\n" "$((i+1))" "${devices[$i]}" "${device_counts[${devices[$i]}]}" >&2
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    local dev_sel=0
    get_user_selection "${#devices[@]}" dev_sel
    local selected_device="${devices[$dev_sel]}"
    log_info "Selected: $selected_device" >&2

    # STEP 3: Extract unique kernels for selected device
    declare -A kernel_counts
    for ((i=0; i<asset_count; i++)); do
        local name=$(jq -r ".[$i].name" "$all_assets")
        if [[ "$name" == *"_${selected_device}_"* ]]; then
            local parsed=$(parse_armbian_name "$name")
            local kernel=$(echo "$parsed" | cut -d'|' -f2)
            # Handle first occurrence
            if [[ -z "${kernel_counts[$kernel]:-}" ]]; then
                kernel_counts[$kernel]=1
            else
                ((kernel_counts[$kernel]++))
            fi
        fi
    done

    local kernels=($(printf '%s\n' "${!kernel_counts[@]}" | sort))

    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  STEP 3: Select Kernel (${#kernels[@]} available for $selected_device)" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    for ((i=0; i<${#kernels[@]}; i++)); do
        printf "%3d) %-35s (%2d images)\n" "$((i+1))" "${kernels[$i]}" "${kernel_counts[${kernels[$i]}]}" >&2
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    local ker_sel=0
    get_user_selection "${#kernels[@]}" ker_sel
    local selected_kernel="${kernels[$ker_sel]}"
    log_info "Selected: $selected_kernel" >&2

    # STEP 4: Extract unique types for device+kernel
    declare -A type_info
    for ((i=0; i<asset_count; i++)); do
        local name=$(jq -r ".[$i].name" "$all_assets")
        if [[ "$name" == *"_${selected_device}_"*"${selected_kernel}"* ]]; then
            local parsed=$(parse_armbian_name "$name")
            local type=$(echo "$parsed" | cut -d'|' -f3)
            local size=$(jq -r ".[$i].size" "$all_assets")
            local size_mb=$((size / 1024 / 1024))
            type_info[$type]="$size_mb|$i"
        fi
    done

    local types=($(printf '%s\n' "${!type_info[@]}" | sort))

    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  STEP 4: Select Build Type (${#types[@]} available)" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    for ((i=0; i<${#types[@]}; i++)); do
        local size_mb=$(echo "${type_info[${types[$i]}]}" | cut -d'|' -f1)
        printf "%3d) %-35s (%4d MB)\n" "$((i+1))" "${types[$i]}" "$size_mb" >&2
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    local type_sel=0
    get_user_selection "${#types[@]}" type_sel
    local selected_type="${types[$type_sel]}"
    local selected_index=$(echo "${type_info[$selected_type]}" | cut -d'|' -f2)

    log_info "Selected: $selected_type" >&2

    # Save selected index for process_armbian
    echo "$selected_index" > "${TEMP_DIR}/selected_index.txt"

    echo "$all_assets"
}

# Show DietPi device list with 2-step selection (device+arch, then version)
show_dietpi_devices() {
    local images="$1"
    local count=$(echo "$images" | jq length)

    log_info "Found $count DietPi images" >&2
    echo "" >&2

    # STEP 1: Extract unique device+arch combinations
    declare -A devicearch_counts
    for ((i=0; i<count; i++)); do
        local name=$(echo "$images" | jq -r ".[$i].name")
        local parsed=$(parse_dietpi_name "$name")
        local device=$(echo "$parsed" | cut -d'|' -f1)
        local arch=$(echo "$parsed" | cut -d'|' -f2)
        local devicearch="${device}-${arch}"

        if [[ -z "${devicearch_counts[$devicearch]:-}" ]]; then
            devicearch_counts[$devicearch]=1
        else
            ((devicearch_counts[$devicearch]++))
        fi
    done

    local devicearchs=($(printf '%s\n' "${!devicearch_counts[@]}" | sort))

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  STEP 1: Select Device + Architecture (${#devicearchs[@]} available)" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    for ((i=0; i<${#devicearchs[@]}; i++)); do
        printf "%3d) %-35s (%2d images)\n" "$((i+1))" "${devicearchs[$i]}" "${devicearch_counts[${devicearchs[$i]}]}" >&2
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    local dev_sel=0
    get_user_selection "${#devicearchs[@]}" dev_sel
    local selected_devicearch="${devicearchs[$dev_sel]}"
    log_info "Selected: $selected_devicearch" >&2

    # Extract device and arch from selection
    local selected_device=$(echo "$selected_devicearch" | rev | cut -d'-' -f2- | rev)
    local selected_arch=$(echo "$selected_devicearch" | rev | cut -d'-' -f1 | rev)

    # STEP 2: Extract unique versions for selected device+arch
    declare -A version_info
    for ((i=0; i<count; i++)); do
        local name=$(echo "$images" | jq -r ".[$i].name")
        local parsed=$(parse_dietpi_name "$name")
        local device=$(echo "$parsed" | cut -d'|' -f1)
        local arch=$(echo "$parsed" | cut -d'|' -f2)
        local version=$(echo "$parsed" | cut -d'|' -f3)

        if [[ "$device" == "$selected_device" && "$arch" == "$selected_arch" ]]; then
            local url=$(echo "$images" | jq -r ".[$i].url")
            version_info[$version]="$url|$name"
        fi
    done

    local versions=($(printf '%s\n' "${!version_info[@]}" | sort))

    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  STEP 2: Select OS Version (${#versions[@]} available for $selected_devicearch)" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    for ((i=0; i<${#versions[@]}; i++)); do
        printf "%3d) %s\n" "$((i+1))" "${versions[$i]}" >&2
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    local ver_sel=0
    get_user_selection "${#versions[@]}" ver_sel
    local selected_version="${versions[$ver_sel]}"
    log_info "Selected: $selected_version" >&2

    # Extract URL and name from version_info
    local selected_url=$(echo "${version_info[$selected_version]}" | cut -d'|' -f1)
    local selected_name=$(echo "${version_info[$selected_version]}" | cut -d'|' -f2)

    # Return JSON with selected image
    cat <<EOF
{
    "url": "$selected_url",
    "name": "$selected_name",
    "device": "$selected_device",
    "arch": "$selected_arch",
    "version": "$selected_version"
}
EOF
}

# Get user selection - stores result in variable passed by name
# Usage: get_user_selection MAX_NUM RESULT_VAR
#   get_user_selection 10 my_selection
#   echo "Selected: $my_selection"
get_user_selection() {
    local max_selection=$1
    local result_var=$2
    local selection

    while true; do
        read -p "Enter selection number (1-${max_selection}) or 'q' to quit: " selection

        if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
            log_info "Exiting..."
            exit 0
        fi

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $max_selection ]]; then
            local zero_based=$((selection - 1))
            eval "$result_var=$zero_based"  # Store 0-based index
            # Debug output (can be removed later)
            # log_info "DEBUG: Set $result_var to $zero_based" >&2
            return 0
        else
            log_error "Invalid selection. Please enter a number between 1 and ${max_selection}" >&2
        fi
    done
}

# Download image file
download_image() {
    local url="$1"
    local filename="$2"
    local output_path="${DOWNLOAD_DIR}/${filename}"

    # Check if file already exists
    if [[ -f "$output_path" ]]; then
        log_warning "File already exists: $output_path"
        read -p "Re-download? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Using existing file"
            echo "$output_path"
            return 0
        fi
        rm -f "$output_path"
    fi

    log_info "Downloading $filename..."
    log_info "URL: $url"
    log_info "Destination: $output_path"

    if wget --continue --progress=bar:force --directory-prefix="${DOWNLOAD_DIR}" "${url}"; then
        log_success "Download completed: $output_path"
        echo "$output_path"
        return 0
    else
        log_error "Download failed"
        return 1
    fi
}

# Get list of SD/USB devices (exclude HDD/NVMe)
get_flash_devices() {
    # Log to stderr to avoid polluting return value
    log_info "Scanning for SD cards and USB storage devices..." >&2

    local os_type=$(detect_os)
    local devices=""

    if [[ "$os_type" == "linux" ]]; then
        # Linux: use lsblk
        devices=$(lsblk -d -n -o NAME,SIZE,TYPE,TRAN,MODEL,HOTPLUG | \
            awk '$3=="disk" && ($4=="usb" || $6=="1") {print $0}')
    elif [[ "$os_type" == "openbsd" ]]; then
        # OpenBSD: detect removable storage devices from dmesg
        local temp_file="${TEMP_DIR}/devices.txt"
        > "$temp_file"

        # Get all disk names from sysctl
        local all_disks=$(sysctl -n hw.disknames | tr ',' '\n' | grep -o '^sd[0-9]*' | sort -u)

        for disk in $all_disks; do
            # Check if it's removable by looking in dmesg
            local is_removable=$(dmesg | grep "^${disk}.*removable" | head -1)

            if [[ -n "$is_removable" ]]; then
                # Get disk size using disklabel
                local size_sectors=$(disklabel "$disk" 2>/dev/null | awk '/^total sectors:/ {print $3}')
                if [[ -n "$size_sectors" ]]; then
                    # Convert sectors to GB (assuming 512 bytes per sector)
                    local size_gb=$(echo "scale=1; $size_sectors * 512 / 1024 / 1024 / 1024" | bc)

                    # Get device description from dmesg
                    local model=$(dmesg | grep "^${disk}.*<" | tail -1 | sed -n 's/.*<\(.*\)>.*/\1/p')
                    [[ -z "$model" ]] && model="Unknown"

                    echo "${disk} ${size_gb}G disk removable ${model} 1" >> "$temp_file"
                fi
            fi
        done

        devices=$(cat "$temp_file")
    else
        log_error "Unsupported operating system: $os_type" >&2
        return 1
    fi

    if [[ -z "$devices" ]]; then
        log_warning "No removable storage devices found" >&2
        log_info "Note: On OpenBSD, only USB storage devices are listed" >&2
        return 1
    fi

    # Return device list to stdout
    echo "$devices"
}

# Show device list for flashing
show_flash_devices() {
    local devices="$1"
    local count=$(($(echo "$devices" | wc -l)))

    # All display output to stderr
    echo "" >&2
    echo "Available storage devices:" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    printf "%-5s %-10s %-10s %-10s %-30s\n" "No." "Device" "Size" "Type" "Model" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

    local idx=1
    while IFS= read -r line; do
        local name=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local type=$(echo "$line" | awk '{print $4}')
        local model=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=""; print $0}' | sed 's/^[[:space:]]*//')

        printf "%3d) /dev/%-6s %-10s %-10s %s\n" "$idx" "$name" "$size" "$type" "$model" >&2
        idx=$((idx + 1))
    done <<< "$devices"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
}

# Get device path from selection
get_device_path() {
    local devices="$1"
    local selection=$2
    local line=$(echo "$devices" | sed -n "$((selection + 1))p")
    local name=$(echo "$line" | awk '{print $1}')
    echo "/dev/$name"
}

# Confirm device selection
confirm_flash() {
    local device="$1"
    local image="$2"
    local os_type=$(detect_os)

    echo ""
    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_warning "WARNING: This will completely erase all data on $device"
    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Image file: $image"
    log_info "Target device: $device"
    echo ""

    # Show current partitions on device
    log_info "Current partitions/info on $device:"
    if [[ "$os_type" == "linux" ]]; then
        lsblk "$device" 2>/dev/null || true
    elif [[ "$os_type" == "openbsd" ]]; then
        # Extract device name without /dev/
        local diskname=$(basename "$device")
        disklabel "$diskname" 2>/dev/null | head -20 || echo "Unable to read disk label"
    fi
    echo ""

    read -p "Type 'YES' (in capitals) to confirm: " confirm

    if [[ "$confirm" != "YES" ]]; then
        log_info "Flash cancelled by user"
        return 1
    fi

    return 0
}

# Flash image to device
flash_image() {
    local image="$1"
    local device="$2"
    local os_type=$(detect_os)

    # Check if image needs decompression
    local work_image="$image"
    if [[ "$image" =~ \.(xz|gz|bz2)$ ]]; then
        log_info "Image is compressed, will decompress during write..."
    fi

    # Unmount any mounted partitions on the device
    log_info "Unmounting any mounted partitions on $device..."
    if [[ "$os_type" == "linux" ]]; then
        for part in ${device}*; do
            if mountpoint -q "$part" 2>/dev/null; then
                log_info "Unmounting $part..."
                umount "$part" 2>/dev/null || true
            fi
        done
    elif [[ "$os_type" == "openbsd" ]]; then
        # On OpenBSD, check mount output and unmount any partitions
        local diskname=$(basename "$device")
        local mounted_parts=$(mount | grep "^/dev/${diskname}" | awk '{print $1}')
        if [[ -n "$mounted_parts" ]]; then
            echo "$mounted_parts" | while read part; do
                log_info "Unmounting $part..."
                umount "$part" 2>/dev/null || true
            done
        fi
        log_info "Unmount complete"
    fi

    # Flash the image
    log_info "Flashing image to $device..."
    log_warning "This may take several minutes. Do not remove the device!"

    # On OpenBSD, use raw device (r prefix) for better performance
    local target_device="$device"
    if [[ "$os_type" == "openbsd" ]]; then
        local diskname=$(basename "$device")
        target_device="/dev/r${diskname}c"  # Use raw device, partition 'c' is whole disk
        log_info "Using raw device: $target_device"

        # Verify device is accessible
        if ! dd if="$target_device" of=/dev/null bs=512 count=1 2>/dev/null; then
            log_error "Cannot read from $target_device - device may be busy or have errors"
            log_info "Try: doas disklabel -d $diskname | doas disklabel -R $diskname /dev/stdin"
            return 1
        fi
    fi

    if [[ "$image" =~ \.xz$ ]]; then
        # Decompress xz on the fly
        log_info "Writing image... (decompressing and writing in progress)"
        if command -v pv >/dev/null 2>&1; then
            # Get compressed file size for progress bar
            local size=$(stat -f%z "$image" 2>/dev/null || stat -c%s "$image" 2>/dev/null)
            if xz -dc "$image" | pv -s "$size" -pterb | dd of="$target_device" bs=4m conv=fsync 2>&1; then
                log_success "Image successfully flashed to $device"
                return 0
            fi
        else
            log_warning "Install 'pv' package for better progress indication: pkg_add pv"
            # Fallback: OpenBSD dd doesn't support status=progress, use dots
            if [[ "$os_type" == "openbsd" ]]; then
                # Show periodic dots for progress indication
                log_info "Writing in progress (dots = 5 seconds each):"
                xz -dc "$image" | dd of="$target_device" bs=4m conv=fsync 2>&1 &
                local dd_pid=$!
                while kill -0 $dd_pid 2>/dev/null; do
                    echo -n "." >&2
                    sleep 5
                done
                wait $dd_pid
                local result=$?
                echo "" >&2
                if [[ $result -eq 0 ]]; then
                    log_success "Image successfully flashed to $device"
                    return 0
                else
                    log_error "Write failed with exit code $result"
                    return 1
                fi
            else
                # On Linux, try status=progress
                if xz -dc "$image" | dd of="$target_device" bs=4m conv=fsync status=progress 2>&1; then
                    log_success "Image successfully flashed to $device"
                    return 0
                fi
            fi
        fi
    elif [[ "$image" =~ \.gz$ ]]; then
        # Decompress gz on the fly
        log_info "Writing image... (decompressing and writing in progress)"
        if command -v pv >/dev/null 2>&1; then
            # Get compressed file size for progress bar
            local size=$(stat -f%z "$image" 2>/dev/null || stat -c%s "$image" 2>/dev/null)
            if gunzip -c "$image" | pv -s "$size" -pterb | dd of="$target_device" bs=4m conv=fsync 2>&1; then
                log_success "Image successfully flashed to $device"
                return 0
            fi
        else
            # Fallback: OpenBSD dd doesn't support status=progress, use dots
            if [[ "$os_type" == "openbsd" ]]; then
                # Show periodic dots for progress indication
                gunzip -c "$image" | dd of="$target_device" bs=4m conv=fsync 2>&1 &
                local dd_pid=$!
                while kill -0 $dd_pid 2>/dev/null; do
                    echo -n "." >&2
                    sleep 5
                done
                wait $dd_pid
                local result=$?
                echo "" >&2
                if [[ $result -eq 0 ]]; then
                    log_success "Image successfully flashed to $device"
                    return 0
                else
                    log_error "Write failed with exit code $result"
                    return 1
                fi
            else
                # On Linux, try status=progress
                if gunzip -c "$image" | dd of="$target_device" bs=4m conv=fsync status=progress 2>&1; then
                    log_success "Image successfully flashed to $device"
                    return 0
                fi
            fi
        fi
    elif [[ "$image" =~ \.bz2$ ]]; then
        # Decompress bz2 on the fly
        log_info "Writing image... (decompressing and writing in progress)"
        if command -v pv >/dev/null 2>&1; then
            local size=$(stat -f%z "$image" 2>/dev/null || stat -c%s "$image" 2>/dev/null)
            if bunzip2 -c "$image" | pv -s "$size" -pterb | dd of="$target_device" bs=4m conv=fsync 2>&1; then
                log_success "Image successfully flashed to $device"
                return 0
            fi
        else
            if bunzip2 -c "$image" | dd of="$target_device" bs=4m conv=fsync 2>&1; then
                log_success "Image successfully flashed to $device"
                return 0
            fi
        fi
    else
        # Direct copy for uncompressed images
        log_info "Writing image... (writing in progress)"
        if command -v pv >/dev/null 2>&1; then
            local size=$(stat -f%z "$image" 2>/dev/null || stat -c%s "$image" 2>/dev/null)
            if pv -s "$size" -pterb "$image" | dd of="$target_device" bs=4m conv=fsync 2>&1; then
                log_success "Image successfully flashed to $device"
                return 0
            fi
        else
            # Fallback: OpenBSD dd doesn't support status=progress, use dots
            if [[ "$os_type" == "openbsd" ]]; then
                dd if="$image" of="$target_device" bs=4m conv=fsync 2>&1 &
                local dd_pid=$!
                while kill -0 $dd_pid 2>/dev/null; do
                    echo -n "." >&2
                    sleep 5
                done
                wait $dd_pid
                local result=$?
                echo "" >&2
                if [[ $result -eq 0 ]]; then
                    log_success "Image successfully flashed to $device"
                    return 0
                else
                    log_error "Write failed with exit code $result"
                    return 1
                fi
            else
                # On Linux, try status=progress
                if dd if="$image" of="$target_device" bs=4m conv=fsync status=progress 2>&1; then
                    log_success "Image successfully flashed to $device"
                    return 0
                fi
            fi
        fi
    fi

    log_error "Failed to flash image"
    return 1
}

# Sync and eject device
finalize_flash() {
    local device="$1"

    log_info "Syncing filesystem changes..."
    sync

    log_info "Flash complete! You can now safely remove $device"
    log_info "To eject the device, run: eject $device"
}

# Main menu
main_menu() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Armbian/DietPi Image Download and Flash Tool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1) Download and flash Armbian (Official/Community trunk releases)"
    echo "2) Download and flash DietPi (device+arch, then version)"
    echo "3) Flash existing image"
    echo "q) Quit"
    echo ""

    read -p "Select option: " option

    case "$option" in
        1)
            process_armbian
            ;;
        2)
            process_dietpi
            ;;
        3)
            process_existing_image
            ;;
        q|Q)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid option"
            main_menu
            ;;
    esac
}

# Process Armbian workflow
process_armbian() {
    # STEP 1: Select release type
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  STEP 1: Select Armbian Release Type"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1) Official releases (armbian/os)"
    echo "  2) Community releases (armbian/community)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local release_type_sel=0
    get_user_selection 2 release_type_sel

    local releases
    local source_name
    if [[ $release_type_sel -eq 0 ]]; then
        source_name="Official"
        releases=$(get_armbian_official_releases)
    else
        source_name="Community"
        releases=$(get_armbian_community_releases)
    fi

    if [[ -z "$releases" ]]; then
        log_error "Failed to fetch Armbian $source_name releases"
        return 1
    fi

    # show_armbian_devices does 3-step filtering (device, kernel, build type) and saves index
    local assets_file=$(show_armbian_devices "$releases" "$source_name")

    if [[ ! -f "${TEMP_DIR}/selected_index.txt" ]]; then
        log_error "Selection cancelled or failed"
        return 1
    fi

    local selection=$(cat "${TEMP_DIR}/selected_index.txt")
    local url=$(jq -r ".[$selection].url" "$assets_file")
    local name=$(jq -r ".[$selection].name" "$assets_file")

    echo ""
    log_info "Final selection: $name (from $source_name)"

    local image_path=$(download_image "$url" "$name")
    if [[ $? -ne 0 ]]; then
        log_error "Download failed"
        return 1
    fi

    flash_to_device "$image_path"
}

# Process DietPi workflow
process_dietpi() {
    local images=$(get_dietpi_images)
    if [[ -z "$images" ]]; then
        log_error "Failed to fetch DietPi images"
        return 1
    fi

    # show_dietpi_devices does 2-step filtering and returns selected image JSON
    local selected=$(show_dietpi_devices "$images")

    local url=$(echo "$selected" | jq -r ".url")
    local name=$(echo "$selected" | jq -r ".name")
    local device=$(echo "$selected" | jq -r ".device")
    local arch=$(echo "$selected" | jq -r ".arch")
    local version=$(echo "$selected" | jq -r ".version")

    echo ""
    log_info "Final selection: $device-$arch-$version ($name)"

    local image_path=$(download_image "$url" "$name")
    if [[ $? -ne 0 ]]; then
        log_error "Download failed"
        return 1
    fi

    flash_to_device "$image_path"
}

# Process existing image
process_existing_image() {
    echo ""
    log_info "Images in ${DOWNLOAD_DIR}:"

    local images=($(find "${DOWNLOAD_DIR}" -type f \( -name "*.img" -o -name "*.img.xz" -o -name "*.img.gz" \) 2>/dev/null))

    if [[ ${#images[@]} -eq 0 ]]; then
        log_error "No images found in ${DOWNLOAD_DIR}"
        return 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for ((i=0; i<${#images[@]}; i++)); do
        local basename=$(basename "${images[$i]}")
        local size=$(du -h "${images[$i]}" | cut -f1)
        printf "%3d) %-50s (%s)\n" "$((i+1))" "$basename" "$size"
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo ""
    local selection=0
    get_user_selection "${#images[@]}" selection
    local image_path="${images[$selection]}"

    log_info "Selected: $(basename "$image_path")"

    flash_to_device "$image_path"
}

# Flash to device (common workflow)
flash_to_device() {
    local image="$1"

    # Retry loop for device detection
    local devices=""
    while true; do
        devices=$(get_flash_devices)
        if [[ -n "$devices" ]]; then
            break
        fi

        echo ""
        log_error "No suitable devices found for flashing"
        log_info "Possible issues:"
        log_info "  - SD card not fully inserted"
        log_info "  - USB adapter not connected or initialized"
        log_info "  - Device permissions (try running as root)"
        echo ""
        echo "Options:"
        echo "  r) Retry detection"
        echo "  q) Quit"
        echo ""
        read -p "Select option: " retry_option

        case "$retry_option" in
            r|R)
                log_info "Retrying device detection..."
                continue
                ;;
            q|Q)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please enter 'r' or 'q'"
                continue
                ;;
        esac
    done

    show_flash_devices "$devices"

    local count=$(($(echo "$devices" | wc -l)))
    echo ""
    local selection=0
    get_user_selection "$count" selection

    # Verify selection was set
    if [[ -z "${selection:-}" ]]; then
        log_error "Selection failed - variable not set"
        return 1
    fi

    local device=$(get_device_path "$devices" "$selection")

    # Verify device path was extracted
    if [[ -z "$device" ]]; then
        log_error "Failed to extract device path from selection $selection"
        return 1
    fi

    log_info "Selected device: $device"

    # Confirm before flashing
    if ! confirm_flash "$device" "$image"; then
        log_warning "Flash operation cancelled"
        return 1
    fi

    # Check if running as root
    local os_type=$(detect_os)
    if [[ $EUID -ne 0 ]]; then
        if [[ "$os_type" == "openbsd" ]]; then
            log_info "Requesting doas privileges for flashing..."
            doas sh -c "$(declare -f flash_image finalize_flash log_info log_success log_error log_warning detect_os); flash_image '$image' '$device' && finalize_flash '$device'"
        else
            log_info "Requesting sudo privileges for flashing..."
            sudo bash -c "$(declare -f flash_image finalize_flash log_info log_success log_error log_warning detect_os); flash_image '$image' '$device' && finalize_flash '$device'"
        fi
    else
        flash_image "$image" "$device"
        finalize_flash "$device"
    fi
}

# Download only (no root needed)
download_only_armbian() {
    # STEP 1: Select release type
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  STEP 1: Select Armbian Release Type"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1) Official releases (armbian/os)"
    echo "  2) Community releases (armbian/community)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local release_type_sel=0
    get_user_selection 2 release_type_sel

    local releases
    local source_name
    if [[ $release_type_sel -eq 0 ]]; then
        source_name="Official"
        releases=$(get_armbian_official_releases)
    else
        source_name="Community"
        releases=$(get_armbian_community_releases)
    fi

    if [[ -z "$releases" ]]; then
        log_error "Failed to fetch Armbian $source_name releases"
        return 1
    fi

    # show_armbian_devices does 3-step filtering (device, kernel, build type) and saves index
    local assets_file=$(show_armbian_devices "$releases" "$source_name")

    if [[ ! -f "${TEMP_DIR}/selected_index.txt" ]]; then
        log_error "Selection cancelled or failed"
        return 1
    fi

    local selection=$(cat "${TEMP_DIR}/selected_index.txt")
    local url=$(jq -r ".[$selection].url" "$assets_file")
    local name=$(jq -r ".[$selection].name" "$assets_file")

    echo ""
    log_info "Final selection: $name (from $source_name)"

    local image_path=$(download_image "$url" "$name")
    if [[ $? -ne 0 ]]; then
        log_error "Download failed"
        return 1
    fi

    log_success "Downloaded to: $image_path"
    log_info "To flash this image, run: doas $0 --flash"
}

download_only_dietpi() {
    local images=$(get_dietpi_images)
    if [[ -z "$images" ]]; then
        log_error "Failed to fetch DietPi images"
        return 1
    fi

    # show_dietpi_devices does 2-step filtering and returns selected image JSON
    local selected=$(show_dietpi_devices "$images")

    local url=$(echo "$selected" | jq -r ".url")
    local name=$(echo "$selected" | jq -r ".name")
    local device=$(echo "$selected" | jq -r ".device")
    local arch=$(echo "$selected" | jq -r ".arch")
    local version=$(echo "$selected" | jq -r ".version")

    echo ""
    log_info "Final selection: $device-$arch-$version ($name)"

    local image_path=$(download_image "$url" "$name")
    if [[ $? -ne 0 ]]; then
        log_error "Download failed"
        return 1
    fi

    log_success "Downloaded to: $image_path"
    log_info "To flash this image, run: doas $0 --flash"
}

# Main entry point
main() {
    log_info "Armbian/DietPi Download and Flash Tool"

    check_dependencies

    # Parse arguments - check for download-only modes first (no root needed)
    case "${1:-}" in
        --download-armbian)
            download_only_armbian
            exit 0
            ;;
        --download-dietpi)
            download_only_dietpi
            exit 0
            ;;
        --test-armbian)
            log_info "Testing Armbian API fetch (no root needed)..."
            echo "Select source:"
            echo "1) Official (armbian/os)"
            echo "2) Community (armbian/community)"
            read -p "Choice: " test_choice

            local releases
            if [[ "$test_choice" == "2" ]]; then
                log_info "Testing Community releases..."
                releases=$(get_armbian_community_releases)
            else
                log_info "Testing Official releases..."
                releases=$(get_armbian_official_releases)
            fi

            if [[ -z "$releases" ]]; then
                log_error "Failed to fetch releases"
                exit 1
            fi
            log_success "Successfully fetched releases"
            echo "Line count: $(echo "$releases" | wc -l)"
            echo ""

            # Test parsing into assets
            local all_assets="${TEMP_DIR}/armbian_assets.json"
            echo "$releases" | jq -s '[.[] | .assets[]] | unique_by(.name)' > "$all_assets"
            local asset_count=$(jq length "$all_assets")

            if [[ $asset_count -gt 0 ]]; then
                log_success "Successfully parsed $asset_count assets"
                echo ""
                echo "First 10 asset names:"
                jq -r '.[0:10] | .[] | .name' "$all_assets"
                echo ""
                echo "First 5 assets with size:"
                jq -r '.[0:5] | .[] | "\(.name) (\(.size / 1024 / 1024 | floor)MB)"' "$all_assets"
                echo ""
                echo "Testing parse_armbian_name on first asset:"
                local first_name=$(jq -r '.[0].name' "$all_assets")
                echo "Filename: $first_name"
                local parsed=$(parse_armbian_name "$first_name")
                echo "Parsed: $parsed"
                echo "Device: $(echo "$parsed" | cut -d'|' -f1)"
                echo "Kernel: $(echo "$parsed" | cut -d'|' -f2)"
                echo "Type: $(echo "$parsed" | cut -d'|' -f3)"
            else
                log_error "No assets found after parsing"
            fi
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --armbian            Download and flash Armbian (4-step: release type, device, kernel, build)"
            echo "  --dietpi             Download and flash DietPi (2-step: device+arch, version)"
            echo "  --flash              Flash existing image from imgs/ directory (needs root)"
            echo "  --download-armbian   Download Armbian image only (no root needed)"
            echo "  --download-dietpi    Download DietPi image only (no root needed)"
            echo "  --test-armbian       Test Armbian API fetch (debug, no root needed)"
            echo "  --help               Show this help message"
            echo ""
            echo "Armbian sources:"
            echo "  - Official: github.com/armbian/os (stable releases)"
            echo "  - Community: github.com/armbian/community (community builds)"
            echo ""
            echo "Without arguments, shows interactive menu (needs root)."
            echo ""
            echo "On OpenBSD: Use 'doas' instead of 'sudo'"
            exit 0
            ;;
    esac

    # All other modes need root - check now
    check_root_privileges

    case "${1:-}" in
        --armbian)
            process_armbian
            ;;
        --dietpi)
            process_dietpi
            ;;
        --flash)
            process_existing_image
            ;;
        "")
            main_menu
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main
main "$@"
