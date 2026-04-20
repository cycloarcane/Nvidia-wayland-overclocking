#!/usr/bin/bash
#
# NVIDIA GPU Overclock / Power Limit Script (Wayland-compatible)
#
# Fixes 3090 stuck in low power state (210MHz) due to phantom 150W power draw.
# Run as root.
#
# Credit: https://forums.developer.nvidia.com/t/nvidia-gpu-overclocking-under-wayland-guide/290381

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="nvgpu-overclock"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

GPU_INDEX=0

# --- Safety limits (RTX 3090) ---
MAX_CORE_OFFSET=150     # MHz - conservative cap for daily use
MAX_MEM_OFFSET=1000     # NVML value (= 500 MHz in GWE terms)
MIN_POWER_W=200
MAX_POWER_W=400

# --- Defaults ---
POWER_LIMIT_W=400
CORE_OFFSET=0           # MHz
MEM_OFFSET=0            # NVML value (2x GWE value)

# --- Presets ---
# Values: POWER_W CORE_MHZ MEM_NVML
PRESET_CONSERVATIVE="390 50 400"    # Core +50, Mem +200 GWE
PRESET_MODERATE="400 80 600"        # Core +80, Mem +300 GWE
PRESET_AGGRESSIVE="400 105 800"     # Core +105, Mem +400 GWE
PRESET_POWER_ONLY="400 0 0"        # Just power limit, no clocks

check_nvidia_ml_py() {
    python3 -c "import pynvml" 2>/dev/null
}

apply_overclock() {
    local power="$1" core="$2" mem="$3"

    echo ""
    if nvidia-smi -i "$GPU_INDEX" -pl "$power"; then
        echo "  Power limit: ${power}W"
    else
        echo "  WARNING: Failed to set power limit to ${power}W"
    fi

    if [[ "$core" -ne 0 || "$mem" -ne 0 ]]; then
        if ! check_nvidia_ml_py; then
            echo "ERROR: python-nvidia-ml-py not installed. Install with:"
            echo "  sudo pacman -S python-nvidia-ml-py"
            echo "Clock offsets were NOT applied."
            return 1
        fi
        python3 -c "
from pynvml import *
nvmlInit()
gpu = nvmlDeviceGetHandleByIndex($GPU_INDEX)
if $core != 0:
    nvmlDeviceSetGpcClkVfOffset(gpu, $core)
if $mem != 0:
    nvmlDeviceSetMemClkVfOffset(gpu, $mem)
nvmlShutdown()
"
        [[ "$core" -ne 0 ]] && echo "  Core offset: +${core} MHz"
        [[ "$mem" -ne 0 ]] && echo "  Mem offset:  +${mem} NVML (+$((mem / 2)) MHz GWE)"
    fi

    echo ""
    echo "Done. Applied to GPU $GPU_INDEX."
}

clamp() {
    local val="$1" min="$2" max="$3"
    (( val < min )) && val=$min
    (( val > max )) && val=$max
    echo "$val"
}

read_custom_values() {
    echo ""
    read -rp "Power limit in watts [$MIN_POWER_W-$MAX_POWER_W] (default $POWER_LIMIT_W): " input
    POWER_LIMIT_W=$(clamp "${input:-$POWER_LIMIT_W}" $MIN_POWER_W $MAX_POWER_W)

    read -rp "Core clock offset in MHz [0-$MAX_CORE_OFFSET] (default 0): " input
    CORE_OFFSET=$(clamp "${input:-0}" 0 $MAX_CORE_OFFSET)

    read -rp "Memory offset in GWE MHz [0-$((MAX_MEM_OFFSET / 2))] (default 0): " input
    local gwe_val
    gwe_val=$(clamp "${input:-0}" 0 $((MAX_MEM_OFFSET / 2)))
    MEM_OFFSET=$((gwe_val * 2))

    echo ""
    echo "Settings: power=${POWER_LIMIT_W}W, core=+${CORE_OFFSET}MHz, mem=+${gwe_val}MHz GWE"
}

select_preset() {
    echo ""
    echo "Presets (RTX 3090 safe ranges):"
    echo "  1) Power only   — 400W, no clock offsets"
    echo "  2) Conservative  — 390W, core +50,  mem +200 GWE"
    echo "  3) Moderate      — 400W, core +80,  mem +300 GWE"
    echo "  4) Aggressive    — 420W, core +105, mem +400 GWE"
    echo "  5) Custom"
    echo ""
    read -rp "Choose [1-5] (default 1): " choice

    local preset
    case "${choice:-1}" in
        1) preset=$PRESET_POWER_ONLY ;;
        2) preset=$PRESET_CONSERVATIVE ;;
        3) preset=$PRESET_MODERATE ;;
        4) preset=$PRESET_AGGRESSIVE ;;
        5) read_custom_values; return ;;
        *) echo "Invalid choice, using power only."; preset=$PRESET_POWER_ONLY ;;
    esac

    read -r POWER_LIMIT_W CORE_OFFSET MEM_OFFSET <<< "$preset"
}

install_service() {
    local power="$1" core="$2" mem="$3"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=NVIDIA GPU Overclocking Service
After=nvidia-persistenced.service
Requires=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 15
ExecStart=${SCRIPT_DIR}/nvgpu-overclock.sh --apply $power $core $mem
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    echo "Service installed and enabled with: power=${power}W core=+${core}MHz mem=+${mem}NVML"
}

uninstall_service() {
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    echo "Service removed. Overclock will no longer apply on boot."
}

# --- Non-interactive mode for systemd ---
if [[ "${1:-}" == "--apply" ]]; then
    power="${2:-$POWER_LIMIT_W}"
    core="${3:-0}"
    mem="${4:-0}"
    apply_overclock "$power" "$core" "$mem"
    exit 0
fi

# --- Interactive mode ---
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "=== NVIDIA GPU Overclock (RTX 3090) ==="
echo ""
echo "Safety limits: core 0-${MAX_CORE_OFFSET}MHz, mem 0-$((MAX_MEM_OFFSET/2))MHz GWE, power ${MIN_POWER_W}-${MAX_POWER_W}W"

select_preset

echo ""
read -rp "Apply these settings now? [Y/n] " answer
case "${answer,,}" in
    n|no) echo "Skipped." ;;
    *)    apply_overclock "$POWER_LIMIT_W" "$CORE_OFFSET" "$MEM_OFFSET" ;;
esac

echo ""
if systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
    echo "Automatic overclock on boot is currently ENABLED."
    read -rp "Disable it? [y/N] " answer
    case "${answer,,}" in
        y|yes) uninstall_service ;;
        *)     echo "Kept enabled." ;;
    esac
else
    echo "Automatic overclock on boot is currently DISABLED."
    read -rp "Enable with these settings on boot? [Y/n] " answer
    case "${answer,,}" in
        n|no) echo "Skipped." ;;
        *)    install_service "$POWER_LIMIT_W" "$CORE_OFFSET" "$MEM_OFFSET" ;;
    esac
fi
