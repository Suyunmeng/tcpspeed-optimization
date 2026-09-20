#!/usr/bin/env bash
set -euo pipefail

# Speed Slayer
# Native Speed Slayer installer.
# - TCP optimize: uses the preserved TCP menu-66 entry.
# - Argo VMess+WS: native cloudflared + Xray + Nginx implementation, no ArgoX install chain.

REPO_RAW_BASE="https://raw.githubusercontent.com/Suyunmeng/tcpspeed-optimization/main"
SPEED_SLAYER_VERSION="v2.0.8"
PROJECT_URL="https://github.com/Suyunmeng/tcpspeed-optimization"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo .)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd 2>/dev/null || echo .)"

TCP_SCRIPT_LOCAL="${SCRIPT_DIR}/tcp-one-click-optimize.sh"
TCP_CORE_LIB_LOCAL="${SCRIPT_DIR}/lib/tcp-core.sh"

WORK_DIR="/etc/vps-argo-vmess"
CONFIG_FILE="${WORK_DIR}/install.conf"
LOG_FILE="${WORK_DIR}/install.log"
STATE_FILE="${WORK_DIR}/state.env"
INSTALLED_BIN="/usr/local/bin/speed"

DEFAULT_START_PORT="30000"
DEFAULT_NGINX_PORT="8001"
DEFAULT_WS_PATH="argox"
DEFAULT_NODE_NAME="Speed-Slayer"

# Skyline Speeder 后置优化：始终走 --prebuilt，不安装 clang/LLVM/Rust 编译工具链；运行前按需安装 bpftool。
SKYLINE_REPO_DEFAULT="CYBERVERSE-Research/skyline-speeder"
SKYLINE_INSTALLER_URL="${SKYLINE_INSTALLER_URL:-https://raw.githubusercontent.com/CYBERVERSE-Research/skyline-speeder/main/install.sh}"
SKYLINE_LOG_FILE="${WORK_DIR}/skyline-optimize.log"
SKYLINE_PROFILE_FILE="${WORK_DIR}/skyline-profile.env"
SKYLINE_ROLLBACK_FILE="${WORK_DIR}/skyline-rollback.env"
SKYLINE_RTT_FALLBACK_MS_DEFAULT=180
SKYLINE_STUN_HOST_DEFAULT="stun.hitv.com"
SKYLINE_STUN_TARGETS_DEFAULT="175.6.157.109 116.162.157.194 111.8.4.248"
SKYLINE_STUN_PORT_DEFAULT=3478
SKYLINE_STUN_PROBE_COUNT_DEFAULT=10
SKYLINE_STUN_TIMEOUT_DEFAULT=3
SKYLINE_STUN_INTERVAL_DEFAULT=1
SKYLINE_CGROUP_PATH="${SKYLINE_CGROUP_PATH:-/sys/fs/cgroup/skyline-speeder}"
TCP_OPTIMIZE_COMPLETED=0

if [ -t 1 ]; then
  C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'; C_UNDERLINE='\033[4m'
  C_RED='\033[31m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_BLUE='\033[34m'; C_MAGENTA='\033[35m'; C_CYAN='\033[36m'; C_WHITE='\033[97m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_UNDERLINE=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_MAGENTA=''; C_CYAN=''; C_WHITE=''
fi

cecho() { printf "%b%s%b\n" "$1" "$2" "$C_RESET"; }
info() { printf "%b◆ INFO%b %s\n" "$C_CYAN" "$C_RESET" "$*"; }
success() { printf "%b◆ DONE%b %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%b◆ WARN%b %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
err() { printf "%b◆ ERR %b %s\n" "$C_RED" "$C_RESET" "$*" >&2; }

line() { printf "%b%s%b\n" "$C_MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$C_RESET"; }
section() { echo ""; line; printf "%b%s%b\n" "$C_BOLD$C_CYAN" " $1" "$C_RESET"; line; }

banner() {
  printf "%b" "$C_BOLD$C_MAGENTA"
  cat <<'EOF'
███████╗██████╗ ███████╗███████╗██████╗     ███████╗██╗      █████╗ ██╗   ██╗███████╗██████╗ 
██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗    ██╔════╝██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗
███████╗██████╔╝█████╗  █████╗  ██║  ██║    ███████╗██║     ███████║ ╚████╔╝ █████╗  ██████╔╝
╚════██║██╔═══╝ ██╔══╝  ██╔══╝  ██║  ██║    ╚════██║██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗
███████║██║     ███████╗███████╗██████╔╝    ███████║███████╗██║  ██║   ██║   ███████╗██║  ██║
╚══════╝╚═╝     ╚══════╝╚══════╝╚═════╝     ╚══════╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
EOF
  printf "%b" "$C_RESET"
}

intro() {
  echo ""
  printf " %b%s%b\n" "$C_BOLD$C_CYAN" "VPS 网络加速 · Argo 隧道 · VMess WebSocket" "$C_RESET"
  printf " %b%s%b\n" "$C_WHITE" "斩断延迟，撕开隧道，释放节点。" "$C_RESET"
  echo ""
  printf " %b入口：%b输入 %bspeed%b 进入控制台；重启后输入 %bspeed%b 自动续跑。\n" "$C_YELLOW" "$C_RESET" "$C_BOLD$C_GREEN" "$C_RESET" "$C_BOLD$C_GREEN" "$C_RESET"
  printf " %bGitHub:%b %s  %bVersion:%b %s\n" "$C_CYAN" "$C_RESET" "$PROJECT_URL" "$C_CYAN" "$C_RESET" "$SPEED_SLAYER_VERSION" "$C_CYAN" "$C_RESET"
  echo ""
}

render_header_once() {
  if [ "${SPEED_HEADER_RENDERED:-0}" = "1" ]; then
    return 0
  fi
  SPEED_HEADER_RENDERED=1
  banner
  intro
}

require_root() {
  if [ "$(id -u)" != "0" ]; then
    err "请使用 root 执行：sudo -i 后重新运行"
    exit 1
  fi
}

confirm_action() {
  local prompt="$1"
  local ans
  if [ "${ASSUME_Y:-0}" = "1" ]; then
    return 0
  fi
  printf "%b?%b %s %b[Y/n]%b " "$C_YELLOW" "$C_RESET" "$prompt" "$C_GREEN" "$C_RESET"
  read -r ans || ans=""
  ans="${ans:-Y}"
  [[ "$ans" =~ ^[Yy]$ ]]
}

download_script() {
  local raw_path="$1"
  local out
  out="$(mktemp /tmp/speed-slayer.XXXXXX.sh)"
  curl -fsSL "${REPO_RAW_BASE}/${raw_path}" -o "$out"
  bash -n "$out"
  chmod +x "$out"
  echo "$out"
}

fetch_or_run_script() {
  local local_path="$1"
  local raw_path="$2"
  shift 2
  if [ -s "$local_path" ]; then
    bash "$local_path" "$@"
  else
    local tmp_script
    tmp_script="$(download_script "$raw_path")"
    bash "$tmp_script" "$@"
  fi
}

install_shortcut() {
  require_root
  mkdir -p "$WORK_DIR"
  if [ -s "${BASH_SOURCE[0]}" ]; then
    local src_path dst_path
    src_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
    dst_path="$(readlink -f "$INSTALLED_BIN" 2>/dev/null || echo "$INSTALLED_BIN")"
    if [ "$src_path" != "$dst_path" ]; then
      cp "${BASH_SOURCE[0]}" "$INSTALLED_BIN"
    else
      curl -fsSL "${REPO_RAW_BASE}/scripts/vps-argo-vmess-oneclick.sh?$(date +%s)" -o "$INSTALLED_BIN.tmp"
      bash -n "$INSTALLED_BIN.tmp"
      mv "$INSTALLED_BIN.tmp" "$INSTALLED_BIN"
    fi
  else
    curl -fsSL "${REPO_RAW_BASE}/scripts/vps-argo-vmess-oneclick.sh?$(date +%s)" -o "$INSTALLED_BIN"
  fi
  chmod +x "$INSTALLED_BIN"
  success "已安装快捷命令：speed"
  echo "以后可直接执行："
  echo "  speed"
  echo "  speed --force-all"
}

save_pending_state() {
  require_root
  mkdir -p "$WORK_DIR"
  local mode="${1:-tcp}"
  cat > "$STATE_FILE" <<EOF
PENDING_CONTINUE=1
PENDING_MODE=${mode}
CREATED_AT=$(date -Is 2>/dev/null || date)
NEXT_ACTION=continue
EOF
  chmod 600 "$STATE_FILE"
}

pending_mode() {
  if [ -s "$STATE_FILE" ]; then
    # shellcheck disable=SC1090
    . "$STATE_FILE" 2>/dev/null || true
    echo "${PENDING_MODE:-full}"
  else
    echo ""
  fi
}

cdn_recommendation() {
  echo ""
  line
  printf "%b%s%b
" "$C_BOLD$C_YELLOW" " 推荐下一步：本地优选 Cloudflare CDN" "$C_RESET"
  printf "  节点已经生成，建议继续在本地运行 %bCloudflareSpeedTest%b，选择延迟更低、速度更稳的 CDN IP。
" "$C_GREEN" "$C_RESET"
  printf "  项目地址：%bhttps://github.com/XIU2/CloudflareSpeedTest%b
" "$C_UNDERLINE$C_CYAN" "$C_RESET"
  line
}

clear_state() {
  require_root
  rm -f "$STATE_FILE"
  success "已清理续跑状态：$STATE_FILE"
  cdn_recommendation
}

is_xanmod_kernel() {
  uname -r | grep -qi xanmod
}

is_container_env() {
  [ -f /.dockerenv ] && return 0
  [ -f /run/.containerenv ] && return 0
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt --container --quiet 2>/dev/null && return 0
  fi
  grep -qaE '/(docker|lxc|kubepods|containerd)/' /proc/1/cgroup 2>/dev/null
}

show_continue_hint() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 下一步"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "已完成内核组件安装，需要重启服务器加载新内核。"
  echo "重启后只需要执行："
  echo ""
  echo "  speed"
  echo ""
  echo "Speed Slayer 会根据当前流程继续：单独 TCP 只继续 TCP，完整流程才继续 Argo。"
}

confirm_reboot_now() {
  show_continue_hint
  local choice="Y"
  if [ "${ASSUME_Y:-0}" = "1" ]; then
    choice="Y"
  elif [ -t 0 ]; then
    printf "%b?%b 是否现在重启服务器？默认回车 = Y %b[Y/n]%b " "$C_YELLOW" "$C_RESET" "$C_GREEN" "$C_RESET"
    read -r choice || choice=""
    choice="${choice:-Y}"
  else
    warn "非交互环境：已保存续跑状态，请手动重启后执行 speed。"
    return 0
  fi
  case "$choice" in
    [Yy]*)
      success "即将重启服务器。重启后执行：speed"
      sync || true
      if command -v systemctl >/dev/null 2>&1; then
        systemctl reboot
      else
        reboot
      fi
      ;;
    *)
      warn "已暂不重启。准备好后执行：reboot；重启后执行：speed"
      ;;
  esac
}

run_with_progress() {
  local title="$1"
  shift
  local log_file="$1"
  shift
  mkdir -p "$(dirname "$log_file")"
  section "$title"
  "$@" >"$log_file" 2>&1 &
  local pid=$!
  local frames=('▱▱▱▱▱▱▱▱▱▱ 0%' '▰▱▱▱▱▱▱▱▱▱ 10%' '▰▰▱▱▱▱▱▱▱▱ 20%' '▰▰▰▱▱▱▱▱▱▱ 30%' '▰▰▰▰▱▱▱▱▱▱ 40%' '▰▰▰▰▰▱▱▱▱▱ 50%' '▰▰▰▰▰▰▱▱▱▱ 60%' '▰▰▰▰▰▰▰▱▱▱ 70%' '▰▰▰▰▰▰▰▰▱▱ 80%' '▰▰▰▰▰▰▰▰▰▱ 90%')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r%b◆ RUN %b%s" "$C_CYAN" "$C_RESET" "${frames[$((i % ${#frames[@]}))]}"
    i=$((i + 1))
    sleep 1
  done
  set +e
  wait "$pid"
  local code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    printf "\r%b◆ DONE%b %s\n" "$C_GREEN" "$C_RESET" "▰▰▰▰▰▰▰▰▰▰ 100%"
  else
    printf "\r%b◆ FAIL%b 见日志：%s\n" "$C_RED" "$C_RESET" "$log_file"
    tail -n 40 "$log_file" || true
    return "$code"
  fi
}

tcp_value() { sysctl -n "$1" 2>/dev/null || echo "unknown"; }

tcp_status_panel() {
  section "Speed Slayer · TCP 状态"
  printf "%b%-18s%b %s\n" "$C_CYAN" "Kernel" "$C_RESET" "$(uname -r)"
  printf "%b%-18s%b %s\n" "$C_CYAN" "XanMod" "$C_RESET" "$(is_xanmod_kernel && echo YES || echo NO)"
  printf "%b%-18s%b %s\n" "$C_CYAN" "Container" "$C_RESET" "$(is_container_env && echo YES || echo NO)"
  printf "%b%-18s%b %s\n" "$C_CYAN" "Congestion" "$C_RESET" "$(tcp_value net.ipv4.tcp_congestion_control)"
  printf "%b%-18s%b %s\n" "$C_CYAN" "Qdisc" "$C_RESET" "$(tcp_value net.core.default_qdisc)"
  printf "%b%-18s%b %s\n" "$C_CYAN" "IPv6 disabled" "$C_RESET" "$(tcp_value net.ipv6.conf.all.disable_ipv6)"
  if command -v ssctl >/dev/null 2>&1 && [ -S /run/skyline-speeder/speeder.sock ]; then
    printf "%b%-18s%b %s\n" "$C_CYAN" "Skyline Speeder" "$C_RESET" "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null | grep -qx skyline_cc && echo ACTIVE || echo INSTALLED)"
  else
    printf "%b%-18s%b %s\n" "$C_CYAN" "Skyline Speeder" "$C_RESET" "NOT INSTALLED"
  fi
}

tcp_plan_panel() {
  section "Speed Slayer · TCP 施工计划"
  if is_xanmod_kernel; then
    progress_step 10 "已在 XanMod 内核：跳过内核安装阶段"
    progress_step 35 "执行 BBR v3 / FQ 网络参数优化"
    progress_step 55 "执行 DNS 净化 / 网络稳定性修复"
    progress_step 75 "执行 Realm 首连超时修复"
    progress_step 90 "可选 IPv6 禁用"
    progress_step 100 "输出 TCP 状态摘要"
  elif is_container_env; then
    progress_step 10 "检测到容器环境：跳过 XanMod 内核安装"
    progress_step 35 "进入无内核降级模式：仅应用容器内可生效的网络参数"
    progress_step 100 "输出 TCP 状态摘要"
  else
    progress_step 10 "当前不是 XanMod：准备安装 XanMod + BBR v3 内核"
    progress_step 60 "安装完成后需要重启"
    progress_step 100 "重启后执行 speed 自动继续当前流程"
  fi
}

detect_x64_level() {
  local flags level="1"
  flags="$(grep -m1 '^flags' /proc/cpuinfo 2>/dev/null || true)"
  if echo "$flags" | grep -qw 'avx512f'; then level="4"
  elif echo "$flags" | grep -qw 'avx2'; then level="3"
  elif echo "$flags" | grep -qw 'sse4_2'; then level="2"
  fi
  echo "$level"
}

xanmod_pkg_available() {
  local pkg="$1"
  apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2; exit}' | grep -vqE '^(\(none\)|)$'
}

select_xanmod_pkg() {
  local level="$1" n pkg flavor candidates=()

  # Prefer stable mainline, then LTS, then edge. Never pick RT by default.
  # Some distributions/repos only expose lts-x64v1 for old CPU levels, so include safe downgrade candidates.
  for flavor in "linux-xanmod-x64v" "linux-xanmod-lts-x64v" "linux-xanmod-edge-x64v"; do
    for n in "$level" 4 3 2 1; do
      [ "$n" -gt "$level" ] 2>/dev/null && continue
      candidates+=("${flavor}${n}")
    done
  done
  candidates+=("linux-xanmod")

  echo "[XanMod PKG] CPU level: x86-64-v${level}" >>"$WORK_DIR/kernel-install.log"
  echo "[XanMod PKG] candidates: ${candidates[*]}" >>"$WORK_DIR/kernel-install.log"

  for pkg in "${candidates[@]}"; do
    if xanmod_pkg_available "$pkg"; then
      echo "[XanMod PKG] selected: $pkg" >>"$WORK_DIR/kernel-install.log"
      echo "$pkg"
      return 0
    fi
  done

  # Fallback: parse apt-cache search output. Some mirrors expose packages in search
  # but apt-cache policy may not report Candidate as expected in minimal images.
  local available
  available="$(apt-cache search '^linux-xanmod' 2>/dev/null | awk '{print $1}')"
  echo "[XanMod PKG] apt search available: $(echo "$available" | tr '
' ' ')" >>"$WORK_DIR/kernel-install.log"
  for pkg in "${candidates[@]}"; do
    if echo "$available" | grep -qx "$pkg"; then
      echo "[XanMod PKG] selected from search fallback: $pkg" >>"$WORK_DIR/kernel-install.log"
      echo "$pkg"
      return 0
    fi
  done

  echo "[XanMod PKG] no candidate package found" >>"$WORK_DIR/kernel-install.log"
  return 1
}

show_xanmod_candidates() {
  apt-cache search '^linux-xanmod' 2>/dev/null | awk '{print "  - "$1}' | sort -u | head -30 || true
}

native_install_xanmod_kernel() {
  section "Speed Slayer · 内核加速组件"
  if [ "$(uname -m)" != "x86_64" ]; then
    warn "当前架构暂未适配自动内核安装，将切换到兼容安装路径。"
    return 2
  fi
  if [ ! -r /etc/os-release ]; then
    err "无法识别系统：缺少 /etc/os-release"
    return 2
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" != "debian" ] && [ "${ID:-}" != "ubuntu" ]; then
    warn "当前系统暂未适配自动内核安装，将切换到兼容安装路径。"
    return 2
  fi

  progress_step 10 "安装依赖：wget / gnupg / ca-certificates"
  apt-get update -y >>"$WORK_DIR/kernel-install.log" 2>&1 || true
  apt-get install -y curl wget gnupg ca-certificates lsb-release >>"$WORK_DIR/kernel-install.log" 2>&1

  progress_step 25 "导入 XanMod GPG key"
  local keyring="/usr/share/keyrings/xanmod-archive-keyring.gpg"
  local key_tmp key_url key_ok=0
  key_tmp="$(mktemp)"
  : > "$key_tmp"
  echo "[XanMod GPG] start $(date -Is 2>/dev/null || date)" >>"$WORK_DIR/kernel-install.log"
  for key_url in "https://dl.xanmod.org/archive.key"; do
    echo "[XanMod GPG] try: $key_url" >>"$WORK_DIR/kernel-install.log"
    if command -v curl >/dev/null 2>&1; then
      # Cloudflare may challenge HEAD/odd clients; use normal GET, HTTP/1.1, browser UA, and retry IPv4 if needed.
      if curl -fL --http1.1 -A "Mozilla/5.0 Speed-Slayer" --connect-timeout 10 --max-time 30 --retry 2 "$key_url" -o "$key_tmp" >>"$WORK_DIR/kernel-install.log" 2>&1 || \
         curl -4 -fL --http1.1 -A "Mozilla/5.0 Speed-Slayer" --connect-timeout 10 --max-time 30 --retry 2 "$key_url" -o "$key_tmp" >>"$WORK_DIR/kernel-install.log" 2>&1; then
        if grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$key_tmp" 2>/dev/null; then
          key_ok=1
          break
        fi
        if grep -qiE "cf-mitigated|challenge|cloudflare|Just a moment" "$key_tmp" 2>/dev/null; then
          echo "[XanMod GPG] Cloudflare challenge page detected" >>"$WORK_DIR/kernel-install.log"
        else
          echo "[XanMod GPG] downloaded content is not an ASCII armored PGP key" >>"$WORK_DIR/kernel-install.log"
        fi
      fi
    fi
    if command -v wget >/dev/null 2>&1; then
      if wget --user-agent="Mozilla/5.0 Speed-Slayer" --timeout=30 --tries=2 -O "$key_tmp" "$key_url" >>"$WORK_DIR/kernel-install.log" 2>&1; then
        if grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$key_tmp" 2>/dev/null; then
          key_ok=1
          break
        fi
        if grep -qiE "cf-mitigated|challenge|cloudflare|Just a moment" "$key_tmp" 2>/dev/null; then
          echo "[XanMod GPG] Cloudflare challenge page detected" >>"$WORK_DIR/kernel-install.log"
        else
          echo "[XanMod GPG] downloaded content is not an ASCII armored PGP key" >>"$WORK_DIR/kernel-install.log"
        fi
      fi
    fi
  done
  if [ "$key_ok" -ne 1 ]; then
    err "XanMod GPG key 下载失败，已记录详细 curl/wget 错误：$WORK_DIR/kernel-install.log"
    echo "建议检查：DNS、HTTPS 出站、dl.xanmod.org 访问；也可先执行 speed --netcheck。"
    rm -f "$key_tmp"
    return 1
  fi
  if ! gpg --dearmor -o "$keyring" --yes < "$key_tmp" >>"$WORK_DIR/kernel-install.log" 2>&1; then
    err "XanMod GPG key 导入失败，日志：$WORK_DIR/kernel-install.log"
    rm -f "$key_tmp"
    return 1
  fi
  rm -f "$key_tmp"

  progress_step 40 "写入临时 XanMod APT 源"
  local repo_file="/etc/apt/sources.list.d/xanmod-release.list"
  local distro_codename="${VERSION_CODENAME:-}"
  [ -z "$distro_codename" ] && distro_codename="$(lsb_release -sc 2>/dev/null || true)"
  [ -z "$distro_codename" ] && distro_codename="bookworm"

  # XanMod package availability changes across suites. Try the system codename first,
  # then known package-carrying suites, and finally the generic releases suite.
  local repo_suite repo_suites=()
  repo_suites+=("$distro_codename")
  [ "$distro_codename" = "bookworm" ] || repo_suites+=("bookworm")
  [ "$distro_codename" = "trixie" ] || repo_suites+=("trixie")
  [ "$distro_codename" = "releases" ] || repo_suites+=("releases")

  progress_step 55 "检测 CPU x86-64-v 等级"
  local level pkg install_ok=0 repo_ok=0
  level="$(detect_x64_level)"
  for repo_suite in "${repo_suites[@]}"; do
    echo "deb [signed-by=${keyring}] https://deb.xanmod.org ${repo_suite} main" > "$repo_file"
    echo "[XanMod APT] repo suite: ${repo_suite}" >>"$WORK_DIR/kernel-install.log"
    progress_step 45 "刷新 XanMod APT 源：${repo_suite}"
    apt-get update -y >>"$WORK_DIR/kernel-install.log" 2>&1 || true
    if pkg="$(select_xanmod_pkg "$level")"; then
      repo_ok=1
      echo "[XanMod APT] selected suite: ${repo_suite}" >>"$WORK_DIR/kernel-install.log"
      break
    fi
    echo "[XanMod APT] no package in suite: ${repo_suite}" >>"$WORK_DIR/kernel-install.log"
  done
  if [ "$repo_ok" -ne 1 ]; then
    err "未找到可安装的 XanMod 内核包。"
    echo "可用包候选："
    show_xanmod_candidates
    echo "日志：$WORK_DIR/kernel-install.log"
    echo "建议确认已更新到最新版：speed --update-self && speed --version"
    return 1
  fi
  info "CPU 等级：x86-64-v${level}；选择内核包：${pkg}"

  progress_step 70 "安装 XanMod 内核包"
  if apt-get install -y "$pkg" >>"$WORK_DIR/kernel-install.log" 2>&1; then
    install_ok=1
  else
    warn "${pkg} 安装失败，尝试通用 XanMod 内核包。"
    if [ "$pkg" != "linux-xanmod" ] && xanmod_pkg_available "linux-xanmod" && apt-get install -y linux-xanmod >>"$WORK_DIR/kernel-install.log" 2>&1; then
      pkg="linux-xanmod"
      install_ok=1
    fi
  fi
  [ "$install_ok" -eq 1 ] || { err "XanMod 内核包安装失败，日志：$WORK_DIR/kernel-install.log"; return 1; }

  progress_step 88 "验证内核包安装"
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    if ! dpkg -l 2>/dev/null | grep -qE '^ii\s+linux-(image|headers)-.*xanmod'; then
      err "内核包安装验证失败：${pkg}"
      echo "日志：$WORK_DIR/kernel-install.log"
      return 1
    fi
  fi

  progress_step 95 "清理临时 XanMod APT 源"
  rm -f "$repo_file"
  apt-get update -y >>"$WORK_DIR/kernel-install.log" 2>&1 || true

  progress_step 100 "XanMod 安装完成，重启后执行 speed 继续"
  return 0
}

run_tcp_backend_visible() {
  mkdir -p "$WORK_DIR"
  if [ "${SPEED_KERNEL_MODE:-native}" = "native" ]; then
    set +e
    native_install_xanmod_kernel
    local code=$?
    set -e
    if [ "$code" -eq 0 ]; then
      return 0
    elif [ "$code" -ne 2 ]; then
      return "$code"
    fi
  fi
  warn "正在切换到兼容安装路径。"
  fetch_or_run_script "$TCP_SCRIPT_LOCAL" "scripts/tcp-one-click-optimize.sh"
}

skyline_value_or_default() {
  local value="$1" fallback="$2"
  if printf '%s' "$value" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

skyline_clamp_int() {
  local value="$1" minimum="$2" maximum="$3"
  [ "$value" -lt "$minimum" ] 2>/dev/null && value="$minimum"
  [ "$value" -gt "$maximum" ] 2>/dev/null && value="$maximum"
  printf '%s\n' "$value"
}

skyline_install_stun_probe() {
  local missing=()
  command -v tcpdump >/dev/null 2>&1 || missing+=(tcpdump)
  command -v turnutils_stunclient >/dev/null 2>&1 || missing+=(coturn)
  command -v ip >/dev/null 2>&1 || missing+=(iproute2)
  command -v timeout >/dev/null 2>&1 || missing+=(coreutils)
  [ "${#missing[@]}" -eq 0 ] && return 0
  command -v apt-get >/dev/null 2>&1 || {
    err "缺少 STUN 探测依赖（${missing[*]}），且当前系统没有 apt-get，无法自动安装。"
    return 1
  }
  mkdir -p "$(dirname "$SKYLINE_LOG_FILE")"
  info "未检测到完整 STUN 探测依赖，自动安装 tcpdump、coturn、iproute2 和 coreutils。" >&2
  apt-get update -y >>"$SKYLINE_LOG_FILE" 2>&1 || return 1
  apt-get install -y tcpdump coturn iproute2 coreutils >>"$SKYLINE_LOG_FILE" 2>&1 || return 1
  command -v tcpdump >/dev/null 2>&1 && command -v turnutils_stunclient >/dev/null 2>&1 && command -v ip >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1
}

skyline_stun_rtt_ms() {
  local server_ip="$1" port="${SKYLINE_STUN_PORT:-$SKYLINE_STUN_PORT_DEFAULT}"
  local count="${SKYLINE_STUN_PROBE_COUNT:-$SKYLINE_STUN_PROBE_COUNT_DEFAULT}"
  local timeout_s="${SKYLINE_STUN_TIMEOUT:-$SKYLINE_STUN_TIMEOUT_DEFAULT}"
  local interval="${SKYLINE_STUN_INTERVAL:-$SKYLINE_STUN_INTERVAL_DEFAULT}"
  local route iface srcip cap tcpid request_ts response_ts rtt timestamps i
  local -a rtts=()
  SKYLINE_STUN_SENT=0
  SKYLINE_STUN_RESPONSES=0
  SKYLINE_STUN_LOSS_PERCENT=100
  SKYLINE_STUN_RTT_MS=""
  SKYLINE_STUN_MIN_RTT_MS=""
  SKYLINE_STUN_AVG_RTT_MS=""
  SKYLINE_STUN_MAX_RTT_MS=""
  SKYLINE_STUN_JITTER_MS=""
  SKYLINE_STUN_INTERFACE=""
  SKYLINE_STUN_SOURCE_IP=""

  count="$(skyline_clamp_int "$(skyline_value_or_default "$count" "$SKYLINE_STUN_PROBE_COUNT_DEFAULT")" 1 20)"
  timeout_s="$(skyline_clamp_int "$(skyline_value_or_default "$timeout_s" "$SKYLINE_STUN_TIMEOUT_DEFAULT")" 1 15)"
  port="$(skyline_clamp_int "$(skyline_value_or_default "$port" "$SKYLINE_STUN_PORT_DEFAULT")" 1 65535)"
  SKYLINE_STUN_SENT="$count"

  route="$(ip -4 route get "$server_ip" 2>/dev/null)" || return 1
  iface="$(printf '%s\n' "$route" | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
  srcip="$(printf '%s\n' "$route" | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
  [ -n "$iface" ] && [ -n "$srcip" ] || return 1
  SKYLINE_STUN_INTERFACE="$iface"
  SKYLINE_STUN_SOURCE_IP="$srcip"

  for i in $(seq 1 "$count"); do
    cap="$(mktemp /tmp/skyline-stun.XXXXXX)"
    timeout "${timeout_s}s" tcpdump -l -tt -nn -i "$iface" -c 2 "host $server_ip and udp and port $port" >"$cap" 2>/dev/null &
    tcpid=$!
    sleep 0.2
    timeout "${timeout_s}s" turnutils_stunclient -p "$port" "$server_ip" >/dev/null 2>&1 || true
    wait "$tcpid" 2>/dev/null || true

    timestamps="$(awk -v ip="$server_ip" -v port="$port" '
      $0 ~ (" > " ip "\\." port ": UDP") && request == "" { request=$1 }
      $0 ~ (ip "\\." port " > ") && response == "" { response=$1 }
      END { print request, response }
    ' "$cap")"
    rm -f "$cap"
    read -r request_ts response_ts <<< "$timestamps"
    if [ -n "$request_ts" ] && [ -n "$response_ts" ]; then
      rtt="$(awk -v a="$request_ts" -v b="$response_ts" 'BEGIN { printf "%.3f", (b-a)*1000 }')"
      if awk -v r="$rtt" 'BEGIN { exit !(r >= 0 && r < 10000) }'; then
        rtts+=("$rtt")
        printf 'stun target=%s round=%s rtt=%sms\n' "$server_ip" "$i" "$rtt" >>"$SKYLINE_LOG_FILE"
      else
        printf 'stun target=%s round=%s invalid-rtt=%s\n' "$server_ip" "$i" "$rtt" >>"$SKYLINE_LOG_FILE"
      fi
    else
      printf 'stun target=%s round=%s timeout\n' "$server_ip" "$i" >>"$SKYLINE_LOG_FILE"
    fi
    sleep "$interval"
  done

  SKYLINE_STUN_RESPONSES="${#rtts[@]}"
  SKYLINE_STUN_LOSS_PERCENT="$(( (SKYLINE_STUN_SENT - SKYLINE_STUN_RESPONSES) * 100 / SKYLINE_STUN_SENT ))"
  [ "$SKYLINE_STUN_RESPONSES" -gt 0 ] 2>/dev/null || return 1

  # Match the standalone STUN probe summary: calculate min / average / max,
  # then compare routes using the rounded average RTT after packet loss.
  read -r SKYLINE_STUN_MIN_RTT_MS SKYLINE_STUN_AVG_RTT_MS SKYLINE_STUN_MAX_RTT_MS <<EOF
$(printf '%s\n' "${rtts[@]}" | awk '
  NR == 1 { min=$1; max=$1 }
  { sum+=$1; if ($1 < min) min=$1; if ($1 > max) max=$1 }
  END { printf "%.3f %.3f %.3f", min, sum/NR, max }
')
EOF
  SKYLINE_STUN_RTT_MS="$(awk -v rtt="$SKYLINE_STUN_AVG_RTT_MS" 'BEGIN { printf "%d", rtt + 0.5 }')"
  SKYLINE_STUN_JITTER_MS="$(printf '%s\n' "${rtts[@]}" | awk '
    NR == 1 { previous=$1; next }
    { delta=$1-previous; if (delta < 0) delta=-delta; total+=delta; samples++; previous=$1 }
    END { if (samples) printf "%.3f", total/samples; else print "0.000" }
  ')"
}

skyline_detect_rtt_ms() {
  local host="${SKYLINE_STUN_HOST:-$SKYLINE_STUN_HOST_DEFAULT}"
  local targets="${SKYLINE_STUN_TARGETS:-$SKYLINE_STUN_TARGETS_DEFAULT}"
  local target result responses sent loss jitter min_rtt avg_rtt max_rtt fallback
  local worst_rtt=0 worst_target="" worst_jitter=0 worst_loss=-1 worst_unreachable=0 responsive_targets=0
  local -a measurements=()

  fallback="$(skyline_clamp_int "$(skyline_value_or_default "${SKYLINE_RTT_FALLBACK_MS:-$SKYLINE_RTT_FALLBACK_MS_DEFAULT}" 180)" 50 1000)"
  SKYLINE_STUN_MEASUREMENTS=""
  SKYLINE_STUN_WORST_TARGET=""
  SKYLINE_STUN_WORST_RTT_MS="$fallback"
  SKYLINE_STUN_WORST_LOSS_PERCENT=100
  SKYLINE_STUN_WORST_JITTER_MS=0
  SKYLINE_STUN_WORST_MIN_RTT_MS=""
  SKYLINE_STUN_WORST_AVG_RTT_MS=""
  SKYLINE_STUN_WORST_MAX_RTT_MS=""
  SKYLINE_STUN_ALL_UNREACHABLE=1
  SKYLINE_STUN_HOST_USED="$host"
  SKYLINE_STUN_TARGETS_USED="$targets"
  SKYLINE_STUN_PORT_USED="${SKYLINE_STUN_PORT:-$SKYLINE_STUN_PORT_DEFAULT}"
  SKYLINE_STUN_PROBE_COUNT_USED="${SKYLINE_STUN_PROBE_COUNT:-$SKYLINE_STUN_PROBE_COUNT_DEFAULT}"
  SKYLINE_STUN_TIMEOUT_USED="${SKYLINE_STUN_TIMEOUT:-$SKYLINE_STUN_TIMEOUT_DEFAULT}"
  SKYLINE_STUN_INTERVAL_USED="${SKYLINE_STUN_INTERVAL:-$SKYLINE_STUN_INTERVAL_DEFAULT}"

  if ! skyline_install_stun_probe; then
    warn "无法安装 STUN 探测依赖，使用默认 Skyline 参数档和回退 RTT ${fallback}ms。" >&2
    SKYLINE_STUN_MEASUREMENTS="probe-unavailable"
    SKYLINE_STUN_WORST_TARGET="none"
    SKYLINE_STUN_ALL_UNREACHABLE=1
    SKYLINE_DETECTED_RTT_MS="$fallback"
    return 0
  fi

  for target in $targets; do
    if skyline_stun_rtt_ms "$target"; then
      result="$SKYLINE_STUN_RTT_MS"
      responses="$SKYLINE_STUN_RESPONSES"
      sent="$SKYLINE_STUN_SENT"
      loss="$SKYLINE_STUN_LOSS_PERCENT"
      jitter="$SKYLINE_STUN_JITTER_MS"
      min_rtt="$SKYLINE_STUN_MIN_RTT_MS"
      avg_rtt="$SKYLINE_STUN_AVG_RTT_MS"
      max_rtt="$SKYLINE_STUN_MAX_RTT_MS"
      measurements+=("$target=avg:${result}ms,min:${min_rtt}ms,avg:${avg_rtt}ms,max:${max_rtt}ms,${responses}/${sent},loss:${loss}%,jitter:${jitter}ms")
      responsive_targets=$((responsive_targets + 1))
      SKYLINE_STUN_ALL_UNREACHABLE=0
      if [ "$worst_unreachable" -eq 0 ] && { [ "$loss" -gt "$worst_loss" ] || { [ "$loss" -eq "$worst_loss" ] && [ "$result" -gt "$worst_rtt" ]; } || [ -z "$worst_target" ]; } 2>/dev/null; then
        worst_rtt="$result"
        worst_target="$target"
        worst_loss="$loss"
        worst_jitter="$jitter"
        SKYLINE_STUN_WORST_MIN_RTT_MS="$min_rtt"
        SKYLINE_STUN_WORST_AVG_RTT_MS="$avg_rtt"
        SKYLINE_STUN_WORST_MAX_RTT_MS="$max_rtt"
      fi
    else
      responses="${SKYLINE_STUN_RESPONSES:-0}"
      sent="${SKYLINE_STUN_SENT:-$SKYLINE_STUN_PROBE_COUNT_USED}"
      loss="${SKYLINE_STUN_LOSS_PERCENT:-100}"
      measurements+=("$target=unreachable(${responses}/${sent},loss:${loss}%)")
      if [ "$worst_unreachable" -eq 0 ]; then
        worst_unreachable=1
        worst_target="$target"
        worst_loss=100
        worst_jitter=0
        SKYLINE_STUN_WORST_MIN_RTT_MS=""
        SKYLINE_STUN_WORST_AVG_RTT_MS=""
        SKYLINE_STUN_WORST_MAX_RTT_MS=""
      fi
    fi
  done

  SKYLINE_STUN_MEASUREMENTS="${measurements[*]}"
  SKYLINE_STUN_WORST_TARGET="${worst_target:-none}"
  SKYLINE_STUN_WORST_LOSS_PERCENT="$worst_loss"
  SKYLINE_STUN_WORST_JITTER_MS="$worst_jitter"
  if [ "$worst_unreachable" -eq 1 ]; then
    [ "$worst_rtt" -gt "$fallback" ] 2>/dev/null || worst_rtt="$fallback"
  fi
  if [ "$responsive_targets" -eq 0 ] 2>/dev/null; then
    SKYLINE_STUN_ALL_UNREACHABLE=1
    worst_rtt="$fallback"
    SKYLINE_STUN_WORST_TARGET="none"
    SKYLINE_STUN_WORST_LOSS_PERCENT=100
    warn "三个 STUN 目标均无有效响应，使用默认 Skyline 参数档和回退 RTT ${worst_rtt}ms。" >&2
  fi
  SKYLINE_STUN_WORST_RTT_MS="$worst_rtt"
  SKYLINE_DETECTED_RTT_MS="$worst_rtt"
}

skyline_write_profile() {
  local bandwidth="$1" mem_mb="$2" rtt_ms="$3"
  local max_pacing max_cwnd queue_delay initial_cwnd
  local startup_gain cruise_inflight cruise_pacing loss_ratio profile_mode
  local stun_host stun_targets stun_port stun_count stun_timeout stun_interval stun_worst_target stun_loss stun_jitter stun_measurements

  stun_host="${SKYLINE_STUN_HOST_USED:-${SKYLINE_STUN_HOST:-$SKYLINE_STUN_HOST_DEFAULT}}"
  stun_targets="${SKYLINE_STUN_TARGETS_USED:-${SKYLINE_STUN_TARGETS:-$SKYLINE_STUN_TARGETS_DEFAULT}}"
  stun_port="${SKYLINE_STUN_PORT_USED:-${SKYLINE_STUN_PORT:-$SKYLINE_STUN_PORT_DEFAULT}}"
  stun_count="${SKYLINE_STUN_PROBE_COUNT_USED:-${SKYLINE_STUN_PROBE_COUNT:-$SKYLINE_STUN_PROBE_COUNT_DEFAULT}}"
  stun_timeout="${SKYLINE_STUN_TIMEOUT_USED:-${SKYLINE_STUN_TIMEOUT:-$SKYLINE_STUN_TIMEOUT_DEFAULT}}"
  stun_interval="${SKYLINE_STUN_INTERVAL_USED:-${SKYLINE_STUN_INTERVAL:-$SKYLINE_STUN_INTERVAL_DEFAULT}}"
  stun_worst_target="${SKYLINE_STUN_WORST_TARGET:-none}"
  stun_loss="${SKYLINE_STUN_WORST_LOSS_PERCENT:-100}"
  stun_jitter="${SKYLINE_STUN_WORST_JITTER_MS:-0}"
  stun_measurements="${SKYLINE_STUN_MEASUREMENTS:-unavailable}"

  # The upstream Skyline profile is tuned for random 10-20% loss and
  # 100-300ms RTT, which is the mainland-China long-haul target. Keep those
  # validated gains stable; only scale hard ceilings for measured bandwidth and
  # memory so a low-end VPS cannot over-allocate cwnd.
  max_pacing=$((bandwidth * 3))
  max_pacing="$(skyline_clamp_int "$max_pacing" 1200 10000)"
  max_cwnd=50000
  if [ "$mem_mb" -lt 1024 ] 2>/dev/null; then
    max_cwnd=12000
  elif [ "$mem_mb" -lt 2048 ] 2>/dev/null; then
    max_cwnd=24000
  fi
  queue_delay=100
  initial_cwnd=100
  startup_gain=3.0
  cruise_inflight=2.0
  cruise_pacing=1.1
  loss_ratio=0.5
  [ "$mem_mb" -lt 1024 ] 2>/dev/null && initial_cwnd=32
  profile_mode="china-mainland-random-loss"

  if [ "${SKYLINE_STUN_ALL_UNREACHABLE:-0}" = "1" ]; then
    # No STUN target answered, so there is no route evidence to justify
    # bandwidth/memory-derived ceilings or a custom RTO profile. Restore the
    # values shipped by Skyline instead of tuning from an unavailable signal.
    profile_mode="default"
    max_pacing=1200
    max_cwnd=50000
    queue_delay=100
    initial_cwnd=100
    startup_gain=3.0
    cruise_inflight=2.0
    cruise_pacing=1.1
    loss_ratio=0.5
  fi

  cat > "$SKYLINE_PROFILE_FILE" <<EOF
# Generated by Speed Slayer Skyline Speeder China-mainland auto-tuning.
# bandwidth=${bandwidth}Mbps memory=${mem_mb}MB baseline_rtt=${rtt_ms}ms
SKYLINE_PROFILE_NAME=$profile_mode
SKYLINE_BANDWIDTH_MBPS=$bandwidth
SKYLINE_MEMORY_MB=$mem_mb
SKYLINE_RTT_MS=$rtt_ms
SKYLINE_STUN_HOST=$(printf '%q' "$stun_host")
SKYLINE_STUN_TARGETS=$(printf '%q' "$stun_targets")
SKYLINE_STUN_PORT=$stun_port
SKYLINE_STUN_PROBE_COUNT=$stun_count
SKYLINE_STUN_TIMEOUT=$stun_timeout
SKYLINE_STUN_INTERVAL=$stun_interval
SKYLINE_STUN_WORST_TARGET=$(printf '%q' "$stun_worst_target")
SKYLINE_STUN_WORST_RTT_MS=${SKYLINE_STUN_WORST_RTT_MS:-$rtt_ms}
SKYLINE_STUN_WORST_MIN_RTT_MS=${SKYLINE_STUN_WORST_MIN_RTT_MS:-unavailable}
SKYLINE_STUN_WORST_AVG_RTT_MS=${SKYLINE_STUN_WORST_AVG_RTT_MS:-unavailable}
SKYLINE_STUN_WORST_MAX_RTT_MS=${SKYLINE_STUN_WORST_MAX_RTT_MS:-unavailable}
SKYLINE_STUN_WORST_LOSS_PERCENT=$stun_loss
SKYLINE_STUN_WORST_JITTER_MS=$stun_jitter
SKYLINE_STUN_MEASUREMENTS=$(printf '%q' "$stun_measurements")
SKYLINE_MAX_PACING_MBPS=$max_pacing
SKYLINE_MAX_CWND_PACKETS=$max_cwnd
SKYLINE_MAX_QUEUE_DELAY_MS=$queue_delay
SKYLINE_INITIAL_CWND_PACKETS=$initial_cwnd
SKYLINE_STARTUP_GAIN=$startup_gain
SKYLINE_CRUISE_INFLIGHT_GAIN=$cruise_inflight
SKYLINE_CRUISE_PACING_GAIN=$cruise_pacing
SKYLINE_GUARDRAIL_GAIN=0.8
SKYLINE_LOSS_INFLATION_MAX_RATIO=$loss_ratio
SKYLINE_RTO_FLOOR_US=20000
SKYLINE_RTO_CEILING_US=200000
SKYLINE_RTO_MAX_NORMAL_PERMILLE=3000
SKYLINE_RTO_MAX_CONGESTED_PERMILLE=6000
EOF
  chmod 600 "$SKYLINE_PROFILE_FILE"
}

skyline_download_installer() {
  local out="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --tlsv1.2 "$SKYLINE_INSTALLER_URL" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$SKYLINE_INSTALLER_URL"
  else
    err "缺少 curl/wget，无法下载 Skyline Speeder 安装器。"
    return 1
  fi
  [ -s "$out" ] || { err "Skyline Speeder 安装器下载为空。"; return 1; }
  if head -n 5 "$out" | grep -qiE '<!DOCTYPE|<html'; then
    err "Skyline Speeder 安装器下载内容不是 Bash 脚本。"
    return 1
  fi
  bash -n "$out"
  chmod 700 "$out"
}

skyline_prepare_kernel() {
  require_root
  mkdir -p "$WORK_DIR"
  : > "$SKYLINE_LOG_FILE"

  if ! command -v bpftool >/dev/null 2>&1; then
    info "未检测到 bpftool，安装 Linux BPF 工具包。"
    command -v apt-get >/dev/null 2>&1 || {
      err "缺少 bpftool，且当前系统没有 apt-get，无法继续 Skyline Speeder。"
      return 1
    }
    apt-get update -y >>"$SKYLINE_LOG_FILE" 2>&1 || {
      err "apt-get update 失败，日志：$SKYLINE_LOG_FILE"
      return 1
    }
    apt-get install -y linux-tools-common linux-tools-generic >>"$SKYLINE_LOG_FILE" 2>&1 || {
      err "bpftool 安装失败，日志：$SKYLINE_LOG_FILE"
      return 1
    }
  fi
  command -v bpftool >/dev/null 2>&1 || {
    err "安装后仍未找到 bpftool，无法继续 Skyline Speeder。"
    return 1
  }
  info "bpftool：$(bpftool version 2>/dev/null | head -n 1 || echo available)"

  command -v modprobe >/dev/null 2>&1 || {
    err "缺少 modprobe，无法加载内核 tcp_cubic 模块。"
    return 1
  }
  if ! modprobe tcp_cubic >>"$SKYLINE_LOG_FILE" 2>&1; then
    err "当前内核无法加载 tcp_cubic，Skyline Speeder 安装已终止。"
    return 1
  fi
  if ! sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw cubic; then
    err "当前内核没有可用的 cubic 拥塞控制，Skyline Speeder 安装已终止。"
    return 1
  fi

  local cubic_modules_file="/etc/modules-load.d/99-speed-slayer-cubic.conf"
  local module_state="unchanged"
  if [ -r "$SKYLINE_ROLLBACK_FILE" ]; then
    # Preserve the first-run state so a repeated Skyline invocation cannot
    # forget that this file or line was created by Speed Slayer.
    # shellcheck disable=SC1090
    . "$SKYLINE_ROLLBACK_FILE"
    case "${SKYLINE_CUBIC_MODULE_STATE:-}" in
      created|appended|unchanged)
        success "内核 cubic 已加载并验证可用；沿用现有 Skyline 回滚记录。"
        return 0
        ;;
    esac
  fi
  if [ ! -e "$cubic_modules_file" ]; then
    printf '%s\n' tcp_cubic > "$cubic_modules_file"
    module_state="created"
  elif grep -qw '^tcp_cubic$' "$cubic_modules_file"; then
    module_state="unchanged"
  else
    printf '\n%s\n' tcp_cubic >> "$cubic_modules_file"
    module_state="appended"
  fi
  cat > "$SKYLINE_ROLLBACK_FILE" <<EOF
SKYLINE_CUBIC_MODULE_FILE=$(printf '%q' "$cubic_modules_file")
SKYLINE_CUBIC_MODULE_STATE=$(printf '%q' "$module_state")
EOF
  chmod 600 "$SKYLINE_ROLLBACK_FILE"
  success "内核 cubic 已加载并验证可用；已准备 Skyline 回滚记录。"
}

skyline_preflight() {
  [ "$(id -u)" = "0" ] || { err "Skyline Speeder 需要 root 权限。"; return 1; }
  [ -r /etc/os-release ] || { err "Skyline Speeder 仅支持 Debian/Ubuntu，无法读取 /etc/os-release。"; return 1; }
  command -v systemctl >/dev/null 2>&1 || { err "Skyline Speeder 需要 systemd。"; return 1; }
  [ -d /run/systemd/system ] || { err "当前系统未运行 systemd，无法启用 Skyline Speeder 服务。"; return 1; }
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
    debian:*|ubuntu:*|*:*debian*|*:*ubuntu*) ;;
    *) err "Skyline Speeder 当前仅支持 Debian/Ubuntu：${PRETTY_NAME:-unknown}"; return 1 ;;
  esac
  local kver kmajor kminor
  kver="$(uname -r)"; kmajor="${kver%%.*}"; kminor="${kver#*.}"; kminor="${kminor%%.*}"
  if [ "$kmajor" -lt 6 ] || { [ "$kmajor" -eq 6 ] && [ "$kminor" -lt 12 ]; }; then
    err "当前内核 ${kver} 不满足 Skyline Speeder 要求（需要 6.12+）。"
    return 1
  fi
  [ -r /sys/kernel/btf/vmlinux ] || { err "缺少 /sys/kernel/btf/vmlinux，无法加载 Skyline CO-RE BPF。"; return 1; }
  grep -qw cgroup2 /proc/filesystems 2>/dev/null || { err "当前内核未启用 cgroup v2。"; return 1; }
}

skyline_apply_auto_profile() {
  require_root
  if ! command -v ssctl >/dev/null 2>&1 || [ ! -S /run/skyline-speeder/speeder.sock ]; then
    err "Skyline Speeder 尚未运行，无法应用自动参数。"
    return 1
  fi
  # ssctl set-module-config 是全量覆盖接口，因此这里显式传入所有字段，
  # 避免只改一个参数时意外恢复其它参数的 CLI 默认值。
  # shellcheck disable=SC1090
  . "$SKYLINE_PROFILE_FILE"
  # If every STUN target was silent, keep Skyline's shipped defaults. In
  # particular, do not enable a custom RACK RTO policy from an unavailable
  # measurement; the profile still records the failed probe for diagnosis.
  if [ "${SKYLINE_PROFILE_NAME:-}" = "default" ]; then
    ssctl reset-module-config >>"$SKYLINE_LOG_FILE" 2>&1
    ssctl reset-rack-rto >>"$SKYLINE_LOG_FILE" 2>&1
    ssctl status >>"$SKYLINE_LOG_FILE" 2>&1
    success "三个 STUN 目标均无响应，已使用 Skyline 默认参数档（未应用自定义 RTO）。"
    echo "参数档案：$SKYLINE_PROFILE_FILE"
    echo "详细日志：$SKYLINE_LOG_FILE"
    return 0
  fi
  local rto_floor="${SKYLINE_RTO_FLOOR_US:-20000}"
  local rto_ceiling="${SKYLINE_RTO_CEILING_US:-200000}"
  rto_floor="$(skyline_clamp_int "$rto_floor" 1000 200000)"
  rto_ceiling="$(skyline_clamp_int "$rto_ceiling" "$rto_floor" 200000)"
  ssctl set-module-config \
    --max-pacing-mbps "$SKYLINE_MAX_PACING_MBPS" \
    --max-cwnd-packets "$SKYLINE_MAX_CWND_PACKETS" \
    --max-queue-delay-ms "$SKYLINE_MAX_QUEUE_DELAY_MS" \
    --max-queue-delay-ratio 1.0 \
    --initial-cwnd-packets "$SKYLINE_INITIAL_CWND_PACKETS" \
    --min-rtt-window-s 10 --bw-window-rtts 10 \
    --startup-plateau-rtts 3 --startup-growth-ratio 0.25 \
    --startup-gain "$SKYLINE_STARTUP_GAIN" \
    --cruise-inflight-gain "$SKYLINE_CRUISE_INFLIGHT_GAIN" \
    --cruise-pacing-gain "$SKYLINE_CRUISE_PACING_GAIN" \
    --guardrail-gain "${SKYLINE_GUARDRAIL_GAIN:-0.8}" \
    --loss-inflation-max-ratio "$SKYLINE_LOSS_INFLATION_MAX_RATIO" \
    >>"$SKYLINE_LOG_FILE" 2>&1
  ssctl set-rack-rto \
    --srtt-permille 1100 --floor-us "$rto_floor" --ceiling-us "$rto_ceiling" \
    --warmup-samples 4 \
    --rto-max-normal-permille "${SKYLINE_RTO_MAX_NORMAL_PERMILLE:-3000}" \
    --rto-max-congested-permille "${SKYLINE_RTO_MAX_CONGESTED_PERMILLE:-6000}" \
    --rto-max-congestion-ratio-permille 0 \
    >>"$SKYLINE_LOG_FILE" 2>&1
  ssctl status >>"$SKYLINE_LOG_FILE" 2>&1
  if [ ! -w "$SKYLINE_CGROUP_PATH/cgroup.procs" ]; then
    warn "动态 RTO 仅对 $SKYLINE_CGROUP_PATH 内新建的连接生效；如需包装服务，请使用 /opt/skyline-speeder/infra/run-in-skyline-cgroup.sh。"
  fi
  success "Skyline 参数档 ${SKYLINE_PROFILE_NAME:-china-mainland-random-loss} 已应用：${SKYLINE_BANDWIDTH_MBPS}Mbps / ${SKYLINE_MEMORY_MB}MB / RTT ${SKYLINE_RTT_MS}ms"
  echo "参数档案：$SKYLINE_PROFILE_FILE"
  echo "详细日志：$SKYLINE_LOG_FILE"
}

skyline_status() {
  require_root
  section "Speed Slayer · Skyline Speeder 状态"
  if command -v ssctl >/dev/null 2>&1 && [ -S /run/skyline-speeder/speeder.sock ]; then
    ssctl status
  else
    warn "Skyline Speeder 未安装或服务未运行。"
    systemctl is-active skyline-speederd.service skyline-speeder-enable.service 2>/dev/null || true
    echo "执行：speed --skyline"
    return 1
  fi
}

skyline_is_installed() {
  [ -e /usr/local/sbin/skyline-speederd ] ||
    [ -e /usr/local/bin/skyline-speederd ] ||
    { command -v ssctl >/dev/null 2>&1; } ||
    { systemctl cat skyline-speederd.service >/dev/null 2>&1; } ||
    { systemctl cat skyline-speeder-enable.service >/dev/null 2>&1; }
}

skyline_restore_kernel_record() {
  if [ -r "$SKYLINE_ROLLBACK_FILE" ]; then
    # shellcheck disable=SC1090
    . "$SKYLINE_ROLLBACK_FILE"
    case "${SKYLINE_CUBIC_MODULE_STATE:-unchanged}" in
      created)
        rm -f "${SKYLINE_CUBIC_MODULE_FILE:-/etc/modules-load.d/99-speed-slayer-cubic.conf}"
        ;;
      appended)
        sed -i '/^tcp_cubic$/d' \
          "${SKYLINE_CUBIC_MODULE_FILE:-/etc/modules-load.d/99-speed-slayer-cubic.conf}" \
          2>/dev/null || true
        ;;
    esac
  fi
  rm -f "$SKYLINE_ROLLBACK_FILE"
}

skyline_rollback() {
  require_root
  render_header_once
  section "Speed Slayer · Skyline Speeder 回滚"
  if ! confirm_action "确认卸载 Skyline Speeder 并恢复安装前 TCP 配置？默认回车 = Y"; then
    warn "已取消 Skyline Speeder 回滚。"
    return 0
  fi

  local skyline_installed=0
  skyline_is_installed && skyline_installed=1
  if [ "$skyline_installed" -eq 0 ] && [ ! -e "$SKYLINE_ROLLBACK_FILE" ]; then
    warn "未检测到 Skyline Speeder 安装或回滚记录。"
    return 0
  fi

  mkdir -p "$WORK_DIR"
  local installer install_rc=0
  if [ "$skyline_installed" -eq 1 ]; then
    installer="$(mktemp /tmp/skyline-speeder-uninstall.XXXXXX.sh)"
    if ! skyline_download_installer "$installer" >>"$SKYLINE_LOG_FILE" 2>&1; then
      rm -f "$installer"
      err "Skyline Speeder 卸载器下载/校验失败，未执行回滚；日志：$SKYLINE_LOG_FILE"
      return 1
    fi
    bash "$installer" --uninstall >>"$SKYLINE_LOG_FILE" 2>&1 || install_rc=$?
    rm -f "$installer"
    if [ "$install_rc" -ne 0 ]; then
      err "Skyline Speeder 卸载失败（退出码 $install_rc），未清理回滚记录；日志：$SKYLINE_LOG_FILE"
      tail -n 60 "$SKYLINE_LOG_FILE" || true
      return "$install_rc"
    fi
  else
    info "未检测到 Skyline 服务，仅清理 Speed Slayer 的内核前置变更。"
  fi

  skyline_restore_kernel_record
  rm -f "$SKYLINE_PROFILE_FILE"
  if [ "$skyline_installed" -eq 1 ]; then
    success "Skyline Speeder 已回滚；bpftool 保留为系统工具，tcp_cubic 模块不强制卸载。"
  else
    success "Skyline 内核前置变更已回滚；bpftool 保留为系统工具，tcp_cubic 模块不强制卸载。"
  fi
  echo "详细日志：$SKYLINE_LOG_FILE"
}

run_skyline_optimize() {
  require_root
  render_header_once
  section "Speed Slayer · Skyline Speeder 后置优化"
  if ! confirm_action "是否安装并应用 Skyline Speeder？默认回车 = Y"; then
    warn "已取消 Skyline Speeder 后置优化。"
    return 0
  fi
  info "将先安装 Skyline Speeder 已发布预编译包，再自动探测并应用参数。"
  info "目标机不会安装 clang、LLVM 或 Rust 编译工具链；缺少 bpftool 时自动安装系统工具包。"
  skyline_preflight || return 1
  mkdir -p "$WORK_DIR"
  : > "$SKYLINE_LOG_FILE"
  skyline_prepare_kernel || return 1

  local mem_mb bandwidth rtt_ms installer
  mem_mb="$(detect_memory_mb)"; mem_mb="$(skyline_value_or_default "$mem_mb" 1024)"
  if [ -n "${SPEED_BANDWIDTH_MBPS:-}" ] && printf '%s' "$SPEED_BANDWIDTH_MBPS" | grep -Eq '^[0-9]+$'; then
    bandwidth="$SPEED_BANDWIDTH_MBPS"
  else
    detect_bandwidth_profile
    bandwidth="${BANDWIDTH_MBPS:-1000}"
  fi
  bandwidth="$(skyline_clamp_int "$(skyline_value_or_default "$bandwidth" 1000)" 1 10000)"
  skyline_detect_rtt_ms
  rtt_ms="${SKYLINE_DETECTED_RTT_MS:-$SKYLINE_RTT_FALLBACK_MS_DEFAULT}"
  skyline_write_profile "$bandwidth" "$mem_mb" "$rtt_ms"
  printf "自动探测：带宽=%sMbps，内存=%sMB，最差 STUN 目标=%s，RTT=%sms，丢失=%s%%，抖动=%sms\n" \
    "$bandwidth" "$mem_mb" "${SKYLINE_STUN_WORST_TARGET:-none}" "$rtt_ms" \
    "${SKYLINE_STUN_WORST_LOSS_PERCENT:-100}" "${SKYLINE_STUN_WORST_JITTER_MS:-0}"

  installer="$(mktemp /tmp/skyline-speeder-install.XXXXXX.sh)"
  if ! skyline_download_installer "$installer" >>"$SKYLINE_LOG_FILE" 2>&1; then
    rm -f "$installer"
    err "Skyline Speeder 安装器下载/校验失败，日志：$SKYLINE_LOG_FILE"
    return 1
  fi
  local install_rc=0
  if [ -n "${SKYLINE_RELEASE:-}" ]; then
    SKYLINE_REPO="${SKYLINE_REPO:-$SKYLINE_REPO_DEFAULT}" bash "$installer" --prebuilt --release "$SKYLINE_RELEASE" >>"$SKYLINE_LOG_FILE" 2>&1 || install_rc=$?
  else
    SKYLINE_REPO="${SKYLINE_REPO:-$SKYLINE_REPO_DEFAULT}" bash "$installer" --prebuilt >>"$SKYLINE_LOG_FILE" 2>&1 || install_rc=$?
  fi
  rm -f "$installer"
  if [ "$install_rc" -ne 0 ]; then
    err "Skyline Speeder 预编译安装失败（退出码 $install_rc），日志：$SKYLINE_LOG_FILE"
    tail -n 40 "$SKYLINE_LOG_FILE" || true
    return "$install_rc"
  fi
  skyline_apply_auto_profile
}

detect_swap_status() {
  local total used
  total="$(free -m 2>/dev/null | awk '/^Swap:/ {print $2+0}')"
  used="$(free -m 2>/dev/null | awk '/^Swap:/ {print $3+0}')"
  echo "${total:-0}:${used:-0}"
}

detect_memory_mb() {
  free -m 2>/dev/null | awk '/^Mem:/ {print $2+0}'
}

public_ipv4() {
  curl -4fsS --max-time 6 https://api.ipify.org 2>/dev/null || \
    curl -4fsS --max-time 6 https://ifconfig.co/ip 2>/dev/null || true
}

detect_ip_country_code() {
  local ip="${1:-}" cc=""
  [ -n "$ip" ] || ip="$(public_ipv4)"
  if [ -n "$ip" ]; then
    cc="$(curl -fsS --max-time 6 "https://ipapi.co/${ip}/country/" 2>/dev/null | tr -cd 'A-Za-z' | tr '[:lower:]' '[:upper:]' | head -c 2 || true)"
  fi
  if [ -z "$cc" ]; then
    cc="$(curl -fsS --max-time 6 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | awk -F= '/^loc=/{print toupper($2); exit}' | tr -cd 'A-Z' | head -c 2 || true)"
  fi
  [ -n "$cc" ] && echo "$cc" || echo "XX"
}

sanitize_node_part() {
  printf '%s' "$1" | tr '[:space:]' '-' | tr -cd 'A-Za-z0-9._-' | sed -E 's/-+/-/g; s/^-//; s/-$//'
}

default_node_name() {
  local country host type
  country="$(detect_ip_country_code)"
  host="$(sanitize_node_part "$(hostname 2>/dev/null || echo vps)")"
  host="${host:-vps}"
  type="vmess-ws-argo"
  echo "${country}-${host}-${type}"
}

is_nat_network() {
  local pub priv defaults default_count
  pub="$(public_ipv4)"
  priv="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -nE 's/.* src ([0-9.]+).*/\1/p' | head -1)"
  [ -n "$priv" ] || priv="$(hostname -I 2>/dev/null | awk '{print $1}')"
  default_count="$(ip -4 route show default 2>/dev/null | wc -l | tr -d ' ')"
  case "$priv" in
    10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|100.6[4-9].*|100.[7-9][0-9].*|100.1[0-1][0-9].*|100.12[0-7].*)
      [ -n "$pub" ] && [ "$pub" != "$priv" ] && return 0
      ;;
  esac
  [ "$default_count" -gt 1 ] 2>/dev/null && return 0
  return 1
}

manual_bandwidth_prompt() {
  local ans
  if [ -n "${SPEED_BANDWIDTH_MBPS:-}" ] && echo "$SPEED_BANDWIDTH_MBPS" | grep -Eq '^[0-9]+$'; then
    echo "$SPEED_BANDWIDTH_MBPS"
    return 0
  fi
  if [ -t 0 ]; then
    echo "" >&2
    warn "检测到 NAT / LXC 环境，Ookla Speedtest 容易卡在 socket/latency 阶段。" >&2
    printf "%b?%b 请选择上行带宽档位 Mbps：1)100  2)300  3)500  4)1000  5)自定义，默认 1000: " "$C_YELLOW" "$C_RESET" >&2
    read -r ans || ans=""
    case "${ans:-4}" in
      1) echo 100 ;; 2) echo 300 ;; 3) echo 500 ;; 4|'') echo 1000 ;;
      5) printf "%b?%b 输入上行带宽 Mbps: " "$C_YELLOW" "$C_RESET" >&2; read -r ans || ans=""; echo "${ans:-1000}" ;;
      *) echo "$ans" ;;
    esac | grep -E '^[0-9]+$' || echo 1000
  else
    echo 1000
  fi
}

install_speedtest_cli() {
  command -v speedtest >/dev/null 2>&1 && return 0
  local arch url tmp
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *) return 1 ;;
  esac
  url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${arch}.tgz"
  tmp="$(mktemp -d)"
  if curl -LfsS "$url" -o "$tmp/speedtest.tgz" 2>/dev/null || wget -q "$url" -O "$tmp/speedtest.tgz" 2>/dev/null; then
    tar -xzf "$tmp/speedtest.tgz" -C "$tmp" >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }
    [ -x "$tmp/speedtest" ] || { rm -rf "$tmp"; return 1; }
    mv "$tmp/speedtest" /usr/local/bin/speedtest
    chmod +x /usr/local/bin/speedtest
    rm -rf "$tmp"
    return 0
  fi
  rm -rf "$tmp"
  return 1
}

speedtest_bandwidth_mbps() {
  install_speedtest_cli || return 1
  local servers sid out mbps server_name attempt=0
  : > "$WORK_DIR/speedtest.log"
  echo "Speed Slayer Speedtest - $(date -Is 2>/dev/null || date)" >> "$WORK_DIR/speedtest.log"
  servers="$(timeout 25 speedtest --accept-license --accept-gdpr --servers 2>/dev/null | sed -nE 's/^[[:space:]]*([0-9]+).*/\1/p' | head -n 8 || true)"
  if [ -z "$servers" ]; then
    servers="auto"
  fi
  for sid in $servers; do
    attempt=$((attempt + 1))
    if [ "$sid" = "auto" ]; then
      out="$(timeout 120 speedtest --accept-license --accept-gdpr 2>&1 || true)"
    else
      out="$(timeout 120 speedtest --accept-license --accept-gdpr --server-id="$sid" 2>&1 || true)"
    fi
    {
      echo ""
      echo "===== attempt ${attempt} server ${sid} ====="
      echo "$out"
    } >> "$WORK_DIR/speedtest.log"
    mbps="$(printf '%s\n' "$out" | awk '/Upload:/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9]+(\.[0-9]+)?$/){print int($i); exit}}')"
    server_name="$(printf '%s\n' "$out" | sed -n 's/.*Server:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
    if [ -n "$mbps" ] && [ "$mbps" -gt 0 ] 2>/dev/null && ! printf '%s\n' "$out" | grep -qiE 'FAILED|error|timeout'; then
      SPEEDTEST_SERVER="$server_name"
      echo "$mbps"
      return 0
    fi
  done
  return 1
}

netcheck_one() {
  local label="$1" cmd="$2" hint="${3:-}"
  if eval "$cmd" >/dev/null 2>&1; then
    printf "%b[OK]%b   %s\n" "$C_GREEN" "$C_RESET" "$label"
  else
    printf "%b[FAIL]%b %s\n" "$C_RED" "$C_RESET" "$label"
    [ -n "$hint" ] && printf "       建议：%s\n" "$hint"
    return 1
  fi
}

run_netcheck() {
  require_root
  section "Speed Slayer · Netcheck"
  local failed=0
  mkdir -p "$WORK_DIR"
  {
    echo "Speed Slayer Netcheck - $(date -Is 2>/dev/null || date)"
    echo "Kernel: $(uname -r)"
    echo "Default route: $(ip route show default 2>/dev/null | head -1)"
    echo "IPv4: $(curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || echo unknown)"
    echo "IPv6: $(curl -6fsS --max-time 8 https://api64.ipify.org 2>/dev/null || echo unavailable)"
  } > "$WORK_DIR/netcheck.log"

  netcheck_one "IPv4 出站" 'curl -4fsS --max-time 8 https://api.ipify.org' "检查 DNS / 默认路由 / 防火墙" || failed=1
  netcheck_one "DNS 解析" 'getent hosts github.com || nslookup github.com' "检查 /etc/resolv.conf 或 systemd-resolved" || failed=1
  netcheck_one "GitHub Raw 访问" 'curl -fsS --max-time 12 https://raw.githubusercontent.com/Suyunmeng/tcpspeed-optimization/main/README.md' "GitHub 访问异常会影响自更新" || failed=1
  netcheck_one "Cloudflare 访问" 'curl -fsS --max-time 12 https://www.cloudflare.com/cdn-cgi/trace' "Cloudflare 异常会影响 Argo Tunnel" || failed=1
  netcheck_one "HTTPS/443 出站" 'timeout 8 bash -c "</dev/tcp/1.1.1.1/443"' "检查机房出站 443" || failed=1
  if command -v ping >/dev/null 2>&1; then
    netcheck_one "ICMP 延迟" 'ping -c 3 -W 2 1.1.1.1' "ICMP 失败不一定影响代理，但可用于判断线路" || true
  fi
  echo "日志：$WORK_DIR/netcheck.log"
  [ "$failed" -eq 0 ] && success "Netcheck 完成：关键出站链路正常。" || { err "Netcheck 完成：发现关键链路异常。"; return 1; }
}

run_speedtest_cmd() {
  require_root
  section "Speed Slayer · Speedtest"
  mkdir -p "$WORK_DIR"
  info "正在测速，结果用于评估上行带宽；失败不会影响安装。"
  if ! install_speedtest_cli; then
    err "speedtest CLI 安装失败。"
    echo "日志：$WORK_DIR/speedtest.log"
    return 1
  fi
  local measured
  if measured="$(speedtest_bandwidth_mbps)"; then
    local color
    color="$(bandwidth_color "$measured")"
    printf "%b◆ SPEEDTEST%b Upload: %b%s Mbps%b
" "$C_GREEN" "$C_RESET" "$color" "$measured" "$C_RESET"
    [ -n "${SPEEDTEST_SERVER:-}" ] && echo "Server: $SPEEDTEST_SERVER"
    echo "日志：$WORK_DIR/speedtest.log"
  else
    err "Speedtest 测速失败。日志：$WORK_DIR/speedtest.log"
    tail -n 80 "$WORK_DIR/speedtest.log" 2>/dev/null || true
    return 1
  fi
}

detect_bandwidth_profile() {
  BANDWIDTH_MBPS=""
  BANDWIDTH_SOURCE="default"
  BANDWIDTH_NOTE=""
  if [ -n "${SPEED_BANDWIDTH_MBPS:-}" ] && echo "$SPEED_BANDWIDTH_MBPS" | grep -Eq '^[0-9]+$'; then
    BANDWIDTH_MBPS="$SPEED_BANDWIDTH_MBPS"
    BANDWIDTH_SOURCE="manual"
    BANDWIDTH_NOTE="由 SPEED_BANDWIDTH_MBPS 指定"
    return 0
  fi
  if is_nat_network && [ "${SPEED_FORCE_SPEEDTEST:-0}" != "1" ]; then
    BANDWIDTH_MBPS="$(manual_bandwidth_prompt)"
    BANDWIDTH_SOURCE="manual-nat"
    BANDWIDTH_NOTE="检测到 NAT/LXC 网络，已跳过 Ookla Speedtest；使用手动带宽 ${BANDWIDTH_MBPS} Mbps"
    return 0
  fi
  if [ "${SPEED_AUTO_SPEEDTEST:-1}" = "1" ]; then
    progress_step 18 "正在执行 Speedtest 带宽探测"
    local measured
    if measured="$(speedtest_bandwidth_mbps 2>/dev/null)" && [ -n "$measured" ]; then
      BANDWIDTH_MBPS="$measured"
      BANDWIDTH_SOURCE="measured"
      BANDWIDTH_NOTE="Ookla Speedtest Upload 实测${SPEEDTEST_SERVER:+ · $SPEEDTEST_SERVER}"
      local measured_color
      measured_color="$(bandwidth_color "$measured")"
      printf "%b✓ Speedtest%b 上传带宽：%b%s Mbps%b%s
" "$C_GREEN" "$C_RESET" "$measured_color" "$measured" "$C_RESET" "${SPEEDTEST_SERVER:+ · Server: $SPEEDTEST_SERVER}"
      return 0
    fi
    BANDWIDTH_NOTE="Speedtest 未成功，已回退默认值；日志：$WORK_DIR/speedtest.log"
  else
    BANDWIDTH_NOTE="已关闭自动测速 SPEED_AUTO_SPEEDTEST=0"
  fi
  BANDWIDTH_MBPS="1000"
  BANDWIDTH_SOURCE="default"
  return 0
}

calculate_tcp_buffer_mb() {
  local bandwidth="$1" mem_mb="$2" buffer=32 cap reason=""

  # Speed Slayer v1.0.1 strategy: bandwidth-tiered TCP buffer.
  # Keep it explainable and conservative; avoid giant buffers causing memory pressure/bufferbloat.
  if ! [[ "$bandwidth" =~ ^[0-9]+$ ]] || [ "$bandwidth" -le 0 ] 2>/dev/null; then
    bandwidth=500
  fi

  if [ "$bandwidth" -le 100 ] 2>/dev/null; then buffer=16
  elif [ "$bandwidth" -le 500 ] 2>/dev/null; then buffer=32
  elif [ "$bandwidth" -le 1000 ] 2>/dev/null; then buffer=64
  elif [ "$bandwidth" -le 2500 ] 2>/dev/null; then buffer=128
  else buffer=256
  fi

  # Small-memory guardrail.
  if [ "$mem_mb" -lt 1024 ] 2>/dev/null; then cap=16; reason="<1GB RAM cap"
  elif [ "$mem_mb" -lt 2048 ] 2>/dev/null; then cap=32; reason="<2GB RAM cap"
  elif [ "$mem_mb" -lt 4096 ] 2>/dev/null; then cap=128; reason="<4GB RAM cap"
  else cap=256
  fi
  [ "$buffer" -gt "$cap" ] && buffer="$cap"
  [ -n "$reason" ] && TCP_BUFFER_REASON="$reason" || TCP_BUFFER_REASON="bandwidth-tier"
  echo "$buffer"
}

clean_tcp_conflicts() {
  [ -f /etc/sysctl.conf ] && cp /etc/sysctl.conf "$WORK_DIR/sysctl.conf.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
  if [ -f /etc/sysctl.conf ]; then
    sed -i '/^net\.core\.rmem_max/s/^/# Speed Slayer disabled conflict: /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.core\.wmem_max/s/^/# Speed Slayer disabled conflict: /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.ipv4\.tcp_rmem/s/^/# Speed Slayer disabled conflict: /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.ipv4\.tcp_wmem/s/^/# Speed Slayer disabled conflict: /' /etc/sysctl.conf 2>/dev/null || true
  fi
  rm -f /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
  find /etc/sysctl.d -maxdepth 1 -type f ! -name '99-speed-slayer-tcp.conf' -print0 2>/dev/null | while IFS= read -r -d '' conf; do
    if grep -qE '^(net\.core\.(rmem_max|wmem_max)|net\.ipv4\.tcp_(rmem|wmem|congestion_control))' "$conf" 2>/dev/null; then
      cp "$conf" "${conf}.speed-slayer.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
      sed -i '/^net\.core\.rmem_max/s/^/# Speed Slayer disabled conflict: /; /^net\.core\.wmem_max/s/^/# Speed Slayer disabled conflict: /; /^net\.ipv4\.tcp_rmem/s/^/# Speed Slayer disabled conflict: /; /^net\.ipv4\.tcp_wmem/s/^/# Speed Slayer disabled conflict: /; /^net\.ipv4\.tcp_congestion_control/s/^/# Speed Slayer disabled conflict: /' "$conf" 2>/dev/null || true
    fi
  done
}

bandwidth_color() {
  local mbps="$1"
  if [ "$mbps" -ge 2000 ] 2>/dev/null; then echo "$C_GREEN"
  elif [ "$mbps" -ge 500 ] 2>/dev/null; then echo "$C_CYAN"
  elif [ "$mbps" -ge 100 ] 2>/dev/null; then echo "$C_YELLOW"
  else echo "$C_RED"
  fi
}


select_tcp_buffer_mb() {
  local recommended="$1" mem_mb="$2" selected=""
  echo "" >&2
  section "TCP 缓存档位确认" >&2
  echo "检测后推荐缓存：${recommended}MB（${TCP_BUFFER_REASON:-bandwidth-tier}）" >&2
  echo "" >&2
  echo "请选择 TCP 缓存档位：" >&2
  echo "1. 使用推荐值 ${recommended}MB ⭐ 推荐" >&2
  echo "2. 16MB  （≤100Mbps / 小内存保守）" >&2
  echo "3. 32MB  （100-500Mbps 标准）" >&2
  echo "4. 64MB  （500Mbps-1Gbps 高速）" >&2
  echo "5. 128MB （1Gbps-2.5Gbps 极限）" >&2
  echo "6. 256MB（≥2.5Gbps 高级/实验）" >&2
  echo "7. 手动输入 MB（高级）" >&2
  echo "" >&2
  echo "提示：缓存不是越大越好；高并发或小内存机器过大可能增加内存压力。" >&2

  if [ ! -t 0 ]; then
    echo "非交互环境，自动使用推荐值 ${recommended}MB" >&2
    echo "$recommended"
    return 0
  fi

  read -r -p "请输入选择 [1]: " selected
  selected="${selected:-1}"
  case "$selected" in
    1) echo "$recommended" ;;
    2) echo "16" ;;
    3) echo "32" ;;
    4) echo "64" ;;
    5) echo "128" ;;
    6) echo "256" ;;
    7)
      local manual=""
      while true; do
        read -r -p "请输入缓存大小 MB（建议 16/32/64/128/256，范围 4-512）: " manual
        if [[ "$manual" =~ ^[0-9]+$ ]] && [ "$manual" -ge 4 ] && [ "$manual" -le 512 ]; then
          echo "$manual"
          break
        fi
        warn "请输入 4-512 之间的整数。" >&2
      done
      ;;
    *)
      warn "无效选择，使用推荐值 ${recommended}MB" >&2
      echo "$recommended"
      ;;
  esac
}

native_speed_tcp_tune() {
  local ipv6_choice="$1"
  section "Speed Slayer · TCP 加速配置"
  mkdir -p "$WORK_DIR"

  progress_step 8 "[步骤 1/6] 检测虚拟内存（SWAP）配置"
  local mem_mb swap_info swap_total swap_used vm_swappiness vm_dirty_ratio vm_min_free_kbytes
  mem_mb="$(detect_memory_mb)"; mem_mb="${mem_mb:-1024}"
  swap_info="$(detect_swap_status)"; swap_total="${swap_info%%:*}"; swap_used="${swap_info##*:}"
  printf "Memory=%b%sMB%b Swap=%b%sMB%b Used=%b%sMB%b\n" "$C_GREEN" "$mem_mb" "$C_RESET" "$C_YELLOW" "$swap_total" "$C_RESET" "$C_CYAN" "$swap_used" "$C_RESET"
  vm_swappiness=5; vm_dirty_ratio=15; vm_min_free_kbytes=65536
  if [ "$mem_mb" -lt 2048 ] 2>/dev/null; then
    vm_swappiness=20; vm_dirty_ratio=20; vm_min_free_kbytes=32768
  fi
  [ "$swap_total" -eq 0 ] 2>/dev/null && warn "未检测到 SWAP；小内存 VPS 建议配置 512MB-1GB SWAP。"

  progress_step 20 "[步骤 2/6] 检测服务器带宽并计算最优缓冲区"
  local bandwidth buffer_mb buffer_bytes region
  detect_bandwidth_profile
  bandwidth="$BANDWIDTH_MBPS"
  region="${SPEED_REGION:-global}"
  local recommended_buffer_mb
  recommended_buffer_mb="$(calculate_tcp_buffer_mb "$bandwidth" "$mem_mb")"
  buffer_mb="$(select_tcp_buffer_mb "$recommended_buffer_mb" "$mem_mb")"
  [ "$buffer_mb" != "$recommended_buffer_mb" ] && TCP_BUFFER_REASON="manual-select"
  buffer_bytes=$((buffer_mb * 1024 * 1024))
  local bw_color
  bw_color="$(bandwidth_color "$bandwidth")"
  printf "%b➜ TCP Profile%b Bandwidth=%b%sMbps%b Source=%s Buffer=%sMB Policy=%s
" "$C_CYAN" "$C_RESET" "$bw_color" "$bandwidth" "$C_RESET" "$BANDWIDTH_SOURCE" "$buffer_mb" "${TCP_BUFFER_REASON:-bandwidth-tier}"
  [ -n "$BANDWIDTH_NOTE" ] && printf "%b• BandwidthNote%b %s
" "$C_DIM" "$C_RESET" "$BANDWIDTH_NOTE"

  progress_step 34 "[步骤 3/6] 清理配置冲突"
  clean_tcp_conflicts

  progress_step 50 "[步骤 4/6] 创建配置文件"
  modprobe tcp_bbr >/dev/null 2>&1 || true
  cat > /etc/modules-load.d/99-speed-slayer-bbr.conf <<'EOF'
tcp_bbr
EOF
  cat > /etc/sysctl.d/99-speed-slayer-tcp.conf <<EOF
# Speed Slayer native TCP profile
# Generated on $(date)
# Bandwidth: ${bandwidth} Mbps | Memory: ${mem_mb} MB | Buffer: ${buffer_mb} MB | Policy: ${TCP_BUFFER_REASON:-bandwidth-tier}
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_abort_on_overflow = 0
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 250000
net.core.rmem_max = ${buffer_bytes}
net.core.wmem_max = ${buffer_bytes}
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 4096 87380 ${buffer_bytes}
net.ipv4.tcp_wmem = 4096 65536 ${buffer_bytes}
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
vm.swappiness = ${vm_swappiness}
vm.dirty_ratio = ${vm_dirty_ratio}
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1
vm.min_free_kbytes = ${vm_min_free_kbytes}
vm.vfs_cache_pressure = 50
kernel.sched_autogroup_enabled = 0
kernel.numa_balancing = 0
EOF

  progress_step 66 "[步骤 5/6] 应用所有优化参数"
  local sysctl_output sysctl_rc
  sysctl_output="$(sysctl -p /etc/sysctl.d/99-speed-slayer-tcp.conf 2>&1)"; sysctl_rc=$?
  if [ "$sysctl_rc" -ne 0 ]; then
    warn "部分 sysctl 参数应用失败，已继续保留支持项："
    echo "$sysctl_output" | grep -iE 'error|invalid|unknown|cannot|permission' | head -6 || true
  fi

  progress_step 76 "⚙️ 应用 FQ 队列与持久化限制"
  local dev fq_ok=0 fq_total=0
  for dev in $(ls /sys/class/net 2>/dev/null | grep -vE '^(lo|docker|veth|br-|virbr|tun|tap)'); do
    fq_total=$((fq_total + 1))
    tc qdisc replace dev "$dev" root fq >/dev/null 2>&1 || true
    if tc qdisc show dev "$dev" 2>/dev/null | grep -q '^qdisc fq'; then
      fq_ok=$((fq_ok + 1))
    fi
  done
  printf "%b✓ FQ 队列%b 已应用：%s/%s 个网卡；详细状态可用 %sspeed --tcp-status%s 查看。\n" "$C_GREEN" "$C_RESET" "$fq_ok" "$fq_total" "$C_CYAN" "$C_RESET"
  if ! grep -q 'Speed Slayer file descriptor limits' /etc/security/limits.conf 2>/dev/null; then
    cat >> /etc/security/limits.conf <<'EOF'
# Speed Slayer file descriptor limits
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
  fi
  mkdir -p /etc/systemd/system.conf.d /etc/systemd/user.conf.d /etc/systemd/resolved.conf.d
  cat > /etc/systemd/system.conf.d/99-speed-slayer-limits.conf <<'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
EOF
  cat > /etc/systemd/user.conf.d/99-speed-slayer-limits.conf <<'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
EOF
  systemctl daemon-reexec >/dev/null 2>&1 || true

  progress_step 84 "DNS 稳定性配置"
  cat > /etc/systemd/resolved.conf.d/99-speed-slayer-dns.conf <<'EOF'
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=9.9.9.9 1.0.0.1
DNSSEC=no
EOF
  systemctl restart systemd-resolved >/dev/null 2>&1 || true

  progress_step 90 "IPv6 策略"
  if [[ "$ipv6_choice" =~ ^[Yy]$ ]]; then
    cat > /etc/sysctl.d/99-speed-slayer-disable-ipv6.conf <<'EOF'
# Speed Slayer optional IPv6 disable
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p /etc/sysctl.d/99-speed-slayer-disable-ipv6.conf >/dev/null 2>&1 || true
  else
    rm -f /etc/sysctl.d/99-speed-slayer-disable-ipv6.conf
  fi

  progress_step 100 "[步骤 6/6] 验证优化结果"
  echo "congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  echo "qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
  echo "buffer=${buffer_mb}MB nofile=$(ulimit -n 2>/dev/null || echo unknown)"
}

prepare_tcp_core_lib() {
  local src="$1" out
  out="$(mktemp /tmp/speed-slayer-tcp-core.XXXXXX.sh)"
  # 生成可加载的 TCP 函数库，避免启动交互菜单。
  sed '/^[[:space:]]*main[[:space:]]*"\$@"[[:space:]]*$/d' "$src" > "$out"
  bash -n "$out"
  echo "$out"
}

run_tcp_backend_silent() {
  local ipv6_choice="$1"
  if [ "${SPEED_TCP_MODE:-native}" = "native" ]; then
    native_speed_tcp_tune "$ipv6_choice"
    return 0
  fi

  local src core
  if [ -s "$TCP_CORE_LIB_LOCAL" ]; then
    core="$TCP_CORE_LIB_LOCAL"
  else
    if [ -s "$TCP_SCRIPT_LOCAL" ]; then
      src="$TCP_SCRIPT_LOCAL"
    else
      src="$(download_script "scripts/tcp-one-click-optimize.sh")"
    fi
    core="$(prepare_tcp_core_lib "$src")"
  fi
  # shellcheck disable=SC1090
  source "$core"
  AUTO_MODE=1
  echo "[15%] TCP 核心优化"
  bbr_configure_direct
  echo "[35%] DNS 与网络稳定性"
  dns_purify_and_harden
  echo "[55%] 首连稳定性修复"
  realm_fix_timeout
  if [[ "$ipv6_choice" =~ ^[Yy]$ ]]; then
    echo "[75%] IPv6 策略应用"
    disable_ipv6_permanent
  else
    echo "[75%] 跳过 IPv6 永久禁用"
  fi
  AUTO_MODE=""
}

run_tcp_optimize() {
  TCP_OPTIMIZE_COMPLETED=0
  require_root
  render_header_once
  tcp_status_panel
  tcp_plan_panel
  warn "TCP 阶段会修改内核 / sysctl / DNS / IPv6 等系统网络配置，且可能要求重启。"
  if ! confirm_action "是否继续？默认回车 = Y"; then
    warn "已取消 TCP 优化。"
    return 0
  fi
  install_shortcut || true

  if ! is_xanmod_kernel; then
    if is_container_env; then
      warn "检测到容器环境：容器不能安装/切换 XanMod 宿主机内核，已进入无内核降级模式。"
    else
      save_pending_state "${SPEED_PENDING_MODE:-tcp}"
      section "安装 XanMod + BBR v3 内核"
      warn "当前不是 XanMod 内核。此阶段保留核心输出，避免隐藏安装失败或重启提示。"
      if run_tcp_backend_visible; then
        confirm_reboot_now
        return 0
      fi
      err "内核组件安装失败，日志：$WORK_DIR/kernel-install.log"
      return 1
    fi
  fi

  local ipv6_choice="Y"
  if [ "${ASSUME_Y:-0}" != "1" ]; then
    printf "%b?%b TCP 调优最后是否永久禁用 IPv6？默认回车 = Y %b[Y/n]%b " "$C_YELLOW" "$C_RESET" "$C_GREEN" "$C_RESET"
    read -r ipv6_choice || ipv6_choice=""
    ipv6_choice="${ipv6_choice:-Y}"
  fi

  section "执行 TCP 网络调优"
  info "正在应用 Speed Slayer TCP 加速配置。"
  if [ "${SPEED_TCP_MODE:-native}" = "native" ]; then
    native_speed_tcp_tune "$ipv6_choice" 2>&1 | tee "$WORK_DIR/tcp-optimize.log"
  else
    run_with_progress "Speed Slayer TCP 加速配置" "$WORK_DIR/tcp-optimize.log" run_tcp_backend_silent "$ipv6_choice"
  fi
  progress_step 100 "TCP 调优完成"
  TCP_OPTIMIZE_COMPLETED=1
  tcp_status_panel || true
}

gen_uuid() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  elif command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr 'A-Z' 'a-z'
  else
    cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/'
  fi
}

shell_quote() { printf '%q' "$1"; }

write_argox_vmess_config() {
  require_root
  mkdir -p "$WORK_DIR"

  local uuid="${UUID:-}"
  local ws_path="${WS_PATH:-$DEFAULT_WS_PATH}"
  local start_port="${START_PORT:-$DEFAULT_START_PORT}"
  local nginx_port="${NGINX_PORT:-$DEFAULT_NGINX_PORT}"
  local node_name="${NODE_NAME:-$(default_node_name)}"
  local argo_domain="${ARGO_DOMAIN:-}"
  local argo_auth="${ARGO_AUTH:-}"
  local server="${SERVER:-}"
  local server_port="${SERVER_PORT:-443}"

  [ -n "$uuid" ] || uuid="$(gen_uuid)"

  {
    echo '# Generated by Speed Slayer'
    echo '# Native VMess + WebSocket config. No ArgoX install chain.'
    echo 'INSTALL_PROTOCOLS=(f)'
    printf 'START_PORT=%s\n' "$start_port"
    printf 'VMESS_WS_PORT=%s\n' "$start_port"
    printf 'NGINX_PORT=%s\n' "$nginx_port"
    printf 'UUID=%s\n' "$(shell_quote "$uuid")"
    printf 'WS_PATH=%s\n' "$(shell_quote "$ws_path")"
    printf 'NODE_NAME=%s\n' "$(shell_quote "$node_name")"
    [ -n "$argo_domain" ] && printf 'ARGO_DOMAIN=%s\n' "$(shell_quote "$argo_domain")"
    [ -n "$argo_auth" ] && printf 'ARGO_AUTH=%s\n' "$(shell_quote "$argo_auth")"
    if [ -n "$server" ]; then
      printf 'SERVER=%s\n' "$(shell_quote "$server")"
      printf 'SERVER_PORT=%s\n' "$(shell_quote "$server_port")"
    fi
  } > "$CONFIG_FILE"

  chmod 600 "$CONFIG_FILE"
  success "已生成 VMess+WS 配置：$CONFIG_FILE"
  info "协议：VMess + WebSocket | Path：/${ws_path}-vm | Xray：${start_port} | Nginx：${nginx_port}"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64|64" ;;
    aarch64|arm64) echo "arm64|arm64-v8a" ;;
    *) err "暂只支持 x86_64 / arm64：$(uname -m)"; return 1 ;;
  esac
}

install_base_deps() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y curl wget unzip nginx openssl ca-certificates iproute2 >/dev/null 2>&1
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl wget unzip nginx openssl ca-certificates iproute >/dev/null 2>&1
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl wget unzip nginx openssl ca-certificates iproute >/dev/null 2>&1
  else
    err "暂不支持当前系统包管理器"
    return 1
  fi
}

download_speed_binaries() {
  local archs cf_arch xray_arch tmp
  archs="$(detect_arch)"; cf_arch="${archs%%|*}"; xray_arch="${archs##*|}"
  mkdir -p /etc/argox /etc/argox/subscribe
  if [ ! -x /etc/argox/cloudflared ]; then
    curl -LfsS "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}" -o /etc/argox/cloudflared
    chmod +x /etc/argox/cloudflared
  fi
  if [ ! -x /etc/argox/xray ]; then
    tmp="$(mktemp -d)"
    curl -LfsS "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${xray_arch}.zip" -o "$tmp/xray.zip"
    unzip -qo "$tmp/xray.zip" -d "$tmp"
    mv "$tmp/xray" /etc/argox/xray
    [ -f "$tmp/geoip.dat" ] && mv "$tmp/geoip.dat" /etc/argox/geoip.dat || true
    [ -f "$tmp/geosite.dat" ] && mv "$tmp/geosite.dat" /etc/argox/geosite.dat || true
    chmod +x /etc/argox/xray
    rm -rf "$tmp"
  fi
}

load_speed_config() {
  [ -s "$CONFIG_FILE" ] && . "$CONFIG_FILE"
  UUID="${UUID:-$(gen_uuid)}"
  WS_PATH="${WS_PATH:-$DEFAULT_WS_PATH}"
  VMESS_WS_PORT="${VMESS_WS_PORT:-${START_PORT:-$DEFAULT_START_PORT}}"
  NGINX_PORT="${NGINX_PORT:-$DEFAULT_NGINX_PORT}"
  NODE_NAME="${NODE_NAME:-$(default_node_name)}"
}

write_native_xray_config() {
  cat > /etc/argox/inbound.json <<EOF
{"log":{"loglevel":"warning","access":"/etc/argox/xray-access.log","error":"/etc/argox/xray-error.log"},"inbounds":[{"tag":"${NODE_NAME}","listen":"127.0.0.1","port":${VMESS_WS_PORT},"protocol":"vmess","settings":{"clients":[{"id":"${UUID}","alterId":0}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/${WS_PATH}-vm"}},"sniffing":{"enabled":true,"destOverride":["http","tls"]}}],"outbounds":[{"protocol":"freedom","tag":"direct"}]}
EOF
}

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n"))[1:-1])'; }

make_vmess_url() {
  local host="$1" server="${SERVER:-www.visa.com}" port="${SERVER_PORT:-443}" payload
  payload=$(cat <<EOF
{"v":"2","ps":"$(printf '%s' "${NODE_NAME}" | json_escape)","add":"$(printf '%s' "$server" | json_escape)","port":"${port}","id":"${UUID}","aid":"0","scy":"none","net":"ws","type":"none","host":"$(printf '%s' "$host" | json_escape)","path":"/${WS_PATH}-vm","tls":"tls","sni":"$(printf '%s' "$host" | json_escape)","fp":"chrome"}
EOF
)
  printf 'vmess://%s\n' "$(printf '%s' "$payload" | base64 -w0)"
}

write_native_subscriptions() {
  local host="$1" vmess_url
  mkdir -p /etc/argox/subscribe
  vmess_url="$(make_vmess_url "$host")"
  printf '%s\n' "$vmess_url" > /etc/argox/vmess.txt
  printf '%s\n' "$vmess_url" | base64 -w0 > /etc/argox/subscribe/base64
  cat > /etc/argox/subscribe/clash <<EOF
proxies:
  - name: "${NODE_NAME}"
    type: vmess
    server: "${SERVER:-www.visa.com}"
    port: ${SERVER_PORT:-443}
    uuid: "${UUID}"
    alterId: 0
    cipher: none
    tls: true
    servername: "${host}"
    network: ws
    ws-opts:
      path: "/${WS_PATH}-vm"
      headers: { Host: "${host}" }
EOF
  cp /etc/argox/subscribe/base64 /etc/argox/subscribe/shadowrocket
  cat > /etc/argox/list <<EOF
Protocol : VMess
Network  : WebSocket
UUID     : ${UUID}
Host/SNI : ${host}
Path     : /${WS_PATH}-vm
CDN      : ${SERVER:-www.visa.com}:${SERVER_PORT:-443}

VMess URL:
${vmess_url}

Subscriptions:
https://${host}/${UUID}/base64
https://${host}/${UUID}/clash
https://${host}/${UUID}/shadowrocket
https://${host}/${UUID}/auto
EOF
}

write_native_nginx_config() {
  cat > /etc/argox/nginx.conf <<EOF
worker_processes auto;
events { worker_connections 1024; }
http { server { listen 127.0.0.1:${NGINX_PORT}; server_name _;
location /${WS_PATH}-vm { proxy_pass http://127.0.0.1:${VMESS_WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
location /${UUID}/base64 { alias /etc/argox/subscribe/base64; default_type text/plain; }
location /${UUID}/clash { alias /etc/argox/subscribe/clash; default_type text/plain; }
location /${UUID}/shadowrocket { alias /etc/argox/subscribe/shadowrocket; default_type text/plain; }
location /${UUID}/auto { alias /etc/argox/subscribe/base64; default_type text/plain; }
location / { return 200 'Speed Slayer OK'; }
} }
EOF
}

write_native_services() {
  cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Speed Slayer Xray VMess WS
After=network.target
[Service]
User=root
ExecStart=/etc/argox/xray run -c /etc/argox/inbound.json
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
  cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=Speed Slayer Cloudflare Tunnel
After=network.target xray.service
[Service]
Type=simple
ExecStart=/etc/argox/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://127.0.0.1:${NGINX_PORT} --metrics 127.0.0.1:0
Restart=on-failure
RestartSec=5
StandardOutput=append:/etc/argox/argo.log
StandardError=append:/etc/argox/argo.log
[Install]
WantedBy=multi-user.target
EOF
}

fetch_quick_tunnel_domain() {
  local domain i metrics
  for i in $(seq 1 45); do
    domain="$(grep -Eo 'https://[-a-zA-Z0-9.]+\.trycloudflare\.com' /etc/argox/argo.log 2>/dev/null | tail -n1 | sed 's#https://##' || true)"
    [ -n "$domain" ] && { echo "$domain"; return 0; }
    metrics="$(ss -lntp 2>/dev/null | awk '/cloudflared/ {print $4}' | awk -F: '{print $NF}' | tail -n1)"
    [ -n "$metrics" ] && domain="$(curl -fsS "http://127.0.0.1:${metrics}/quicktunnel" 2>/dev/null | awk -F'"' '{print $4}' || true)"
    [[ "${domain:-}" =~ trycloudflare\.com$ ]] && { echo "$domain"; return 0; }
    sleep 1
  done
  return 1
}

progress_step() {
  local pct="$1" msg="$2"
  printf "%b[%3s%%]%b %s\n" "$C_MAGENTA" "$pct" "$C_RESET" "$msg"
}

native_argo_install_staged() {
  section "Speed Slayer · Argo VMess+WS"
  load_speed_config
  progress_step 5 "安装前检查端口与残留"
  preflight_argo_ports
  progress_step 10 "安装基础依赖"
  install_base_deps >>"$LOG_FILE" 2>&1
  progress_step 25 "下载 / 校验 cloudflared 与 Xray-core"
  download_speed_binaries >>"$LOG_FILE" 2>&1
  progress_step 45 "写入纯 VMess+WS Xray 配置"
  write_native_xray_config >>"$LOG_FILE" 2>&1
  progress_step 55 "写入 Nginx WebSocket 反代与订阅接口"
  write_native_nginx_config >>"$LOG_FILE" 2>&1
  progress_step 65 "写入 systemd 服务"
  write_native_services >>"$LOG_FILE" 2>&1
  progress_step 75 "启动 Xray / Nginx / Cloudflared"
  systemctl daemon-reload >>"$LOG_FILE" 2>&1
  systemctl enable --now xray >>"$LOG_FILE" 2>&1
  nginx -t -c /etc/argox/nginx.conf >>"$LOG_FILE" 2>&1
  pkill -f 'nginx.*argox/nginx.conf' >>"$LOG_FILE" 2>&1 || true
  nginx -c /etc/argox/nginx.conf >>"$LOG_FILE" 2>&1
  : > /etc/argox/argo.log
  systemctl enable --now argo >>"$LOG_FILE" 2>&1
  progress_step 88 "获取 Argo 隧道域名"
  local host
  host="${ARGO_DOMAIN:-}"
  [ -n "$host" ] || host="$(fetch_quick_tunnel_domain)"
  [ -n "$host" ] || { err "未获取到 Argo 临时域名，查看 /etc/argox/argo.log"; return 1; }
  progress_step 96 "生成 VMess URL 与订阅文件"
  write_native_subscriptions "$host" >>"$LOG_FILE" 2>&1
  progress_step 100 "完成"
}

verify_vmess_only() {
  local inbound="/etc/argox/inbound.json"
  [ -s "$inbound" ] || { err "未找到 inbound 配置：$inbound"; return 1; }
  python3 - "$inbound" <<'PYVERIFY'
import json, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
inbounds = data.get('inbounds') or []
if len(inbounds) != 1:
    print(f"inbound 数量异常：{len(inbounds)}", file=sys.stderr)
    sys.exit(1)
ib = inbounds[0]
if ib.get('protocol') != 'vmess':
    print(f"协议异常：{ib.get('protocol')}", file=sys.stderr)
    sys.exit(1)
stream = ib.get('streamSettings') or {}
if stream.get('network') != 'ws':
    print(f"传输异常：{stream.get('network')}", file=sys.stderr)
    sys.exit(1)
print('VMess+WS 校验通过')
PYVERIFY
}

extract_vmess_only() {
  if [ ! -s /etc/argox/list ]; then
    warn "尚未生成 /etc/argox/list"
    return 0
  fi
  local line
  while IFS= read -r line; do
    case "$line" in
      vmess://*) printf "%b%s%b\n" "$C_BOLD$C_GREEN" "$line" "$C_RESET" ;;
      *http://*|*https://*) printf "%b%s%b\n" "$C_CYAN" "$line" "$C_RESET" ;;
      *) printf "%s\n" "$line" ;;
    esac
  done < /etc/argox/list
}

install_argo_vmess_ws() {
  render_header_once
  require_root
  clean_argo_state >/dev/null 2>&1 || true
  write_argox_vmess_config
  info "正在部署 Argo VMess+WS 节点。"
  info "安装前会自动清理旧服务、旧进程和旧配置，支持重复安装。"
  if ! native_argo_install_staged; then
    fail_report "Argo VMess+WS 部署"
    return 1
  fi
  if ! verify_vmess_only; then
    fail_report "VMess+WS 配置校验"
    return 1
  fi
  success "Argo VMess+WS 安装流程结束"
  summarize_result || true
  health_check || true
}

show_argo_vmess_ws_info() {
  require_root
  extract_vmess_only
}

uninstall_argo_vmess_ws() {
  render_header_once
  require_root
  warn "卸载 Speed Slayer Argo VMess+WS 服务"
  systemctl stop argo xray >/dev/null 2>&1 || true
  pkill -f 'nginx.*argox/nginx.conf' >/dev/null 2>&1 || true
  systemctl disable argo xray >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/argo.service /etc/systemd/system/xray.service
  systemctl daemon-reload >/dev/null 2>&1 || true
  rm -rf /etc/argox
  success "Speed Slayer Argo VMess+WS 已卸载"
}

clean_argo_state() {
  require_root
  warn "清理现有 Argo 配置并备份数据。"
  local ts
  ts="$(date +%Y%m%d%H%M%S)"
  systemctl stop argo xray >/dev/null 2>&1 || true
  systemctl disable argo xray >/dev/null 2>&1 || true
  pkill -f '/etc/argox/cloudflared' >/dev/null 2>&1 || true
  pkill -f '/etc/argox/xray' >/dev/null 2>&1 || true
  pkill -f 'nginx.*argox/nginx.conf' >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/argo.service /etc/systemd/system/xray.service
  systemctl daemon-reload >/dev/null 2>&1 || true
  if [ -d /etc/argox ]; then
    mv /etc/argox "/etc/argox.bak.${ts}" 2>/dev/null || rm -rf /etc/argox
  fi
  mkdir -p /etc/argox /etc/argox/subscribe
  success "Argo 配置已备份清理。"
}

force_all() {
  render_header_once
  ASSUME_Y=1
  install_shortcut || true
  if ! is_xanmod_kernel && ! is_container_env; then
    SPEED_PENDING_MODE=full run_tcp_optimize
    return 0
  fi
  SPEED_PENDING_MODE=full run_tcp_optimize
  install_argo_vmess_ws
  clear_state || true
}

run_tcp_then_skyline() {
  render_header_once
  warn "将执行已有 TCP 调优，完成后安装 Skyline Speeder 预编译包并自动应用参数。"
  SPEED_PENDING_MODE=tcp-skyline run_tcp_optimize || return $?
  if [ "${TCP_OPTIMIZE_COMPLETED:-0}" != "1" ]; then
    warn "TCP 调优尚未完成（通常是等待重启进入 XanMod），本次不会执行 Skyline Speeder。"
    echo "重启后执行：speed --tcp-skyline"
    return 0
  fi
  run_skyline_optimize
}

run_all() {
  render_header_once
  warn "--all 将执行完整流程：TCP 调优 + Argo VMess+WS 节点生成。"
  force_all
}

run_menu() {
  render_header_once
  install_shortcut || true
  menu_body
}

continue_after_reboot() {
  render_header_once
  require_root
  install_shortcut || true
  if ! is_xanmod_kernel; then
    err "当前仍未进入 XanMod 内核，暂停继续安装 Argo，避免循环。"
    echo "当前内核: $(uname -r)"
    echo ""
    echo "已安装的 XanMod 包："
    dpkg -l 2>/dev/null | awk '/^ii\s+linux-.*xanmod/ {print "  - "$2" "$3}' || true
    if ! dpkg -l 2>/dev/null | grep -qE '^ii\s+linux-.*xanmod'; then
      echo "  - 未检测到已安装的 XanMod 内核包"
    fi
    echo ""
    echo "下一步建议："
    echo "  1. 如果刚安装完内核，请先执行 reboot，重启后再输入 speed。"
    echo "  2. 如果重启后仍不是 XanMod，说明 VPS 可能不支持自定义内核/GRUB 未切换。"
    echo "  3. 如需重试内核安装：speed --optimize"
    echo "  4. 如需取消续跑状态回到主页：speed --clear-state"
    exit 1
  fi
  local mode
  mode="$(pending_mode)"
  case "$mode" in
    full|all)
      info "检测到 XanMod 内核，继续完整流程：TCP 网络调优 + Argo VMess+WS"
      SPEED_PENDING_MODE=full run_tcp_optimize
      install_argo_vmess_ws
      clear_state || true
      ;;
    tcp-skyline)
      info "检测到 XanMod 内核，继续 TCP 调优，然后应用 Skyline Speeder。"
      SPEED_PENDING_MODE=tcp-skyline run_tcp_optimize
      if [ "${TCP_OPTIMIZE_COMPLETED:-0}" = "1" ]; then
        run_skyline_optimize
      fi
      clear_state || true
      ;;
    tcp|tcp-only|tcp_only|*)
      info "检测到 XanMod 内核，继续单独 TCP 调优流程。"
      SPEED_PENDING_MODE=tcp run_tcp_optimize
      clear_state || true
      ;;
  esac
}

check_environment() {
  require_root
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Speed Slayer · 环境检测"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "系统内核: $(uname -r)"
  echo "系统架构: $(uname -m)"
  echo "Root 权限: OK"
  for cmd in curl wget bash systemctl ss openssl; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "%-12s: OK\n" "$cmd"
    else
      printf "%-12s: MISSING\n" "$cmd"
    fi
  done
  echo "TCP 拥塞控制: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  echo "默认队列算法: $(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
  if [ -s /etc/argox/list ]; then
    echo "Speed Slayer 节点信息: FOUND /etc/argox/list"
  else
    echo "Speed Slayer 节点信息: NOT FOUND"
  fi
}

field_from_list() {
  local key="$1"
  awk -F: -v k="$key" '$1 ~ k {sub(/^[[:space:]]+/,"",$2); print $2; exit}' /etc/argox/list 2>/dev/null
}

subscription_url() {
  local name="$1"
  grep -E "https://.*/${name}$" /etc/argox/list 2>/dev/null | head -1
}

kv() { printf "%b%-13s%b %b%s%b\n" "$C_DIM" "$1" "$C_RESET" "$3" "$2" "$C_RESET"; }

summarize_result() {
  echo ""
  line
  printf "%b%s%b\n" "$C_BOLD$C_GREEN" " Speed Slayer · Installation Complete" "$C_RESET"
  line
  kv "Kernel" "$(uname -r)" "$C_WHITE"
  kv "BBR" "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)" "$C_GREEN"
  kv "Queue" "$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)" "$C_GREEN"

  if [ -s /etc/argox/list ]; then
    local uuid host path cdn vmess base64 clash shadowrocket auto
    uuid="$(field_from_list 'UUID')"
    host="$(field_from_list 'Host/SNI')"
    path="$(field_from_list 'Path')"
    cdn="$(field_from_list 'CDN')"
    vmess="$(grep -m1 '^vmess://' /etc/argox/list 2>/dev/null || true)"
    base64="$(subscription_url base64)"
    clash="$(subscription_url clash)"
    shadowrocket="$(subscription_url shadowrocket)"
    auto="$(subscription_url auto)"

    echo ""
    printf "%b%s%b\n" "$C_BOLD$C_CYAN" "Node" "$C_RESET"
    kv "Protocol" "VMess" "$C_GREEN"
    kv "Network" "WebSocket" "$C_GREEN"
    kv "TLS" "Enabled" "$C_GREEN"
    kv "Host/SNI" "$host" "$C_YELLOW"
    kv "Path" "$path" "$C_YELLOW"
    kv "UUID" "$uuid" "$C_MAGENTA"
    kv "CDN" "$cdn" "$C_CYAN"

    echo ""
    printf "%b%s%b\n" "$C_BOLD$C_MAGENTA" "VMess URL" "$C_RESET"
    printf "%b%s%b\n" "$C_GREEN" "$vmess" "$C_RESET"

    echo ""
    printf "%b%s%b\n" "$C_BOLD$C_MAGENTA" "Subscriptions" "$C_RESET"
    [ -n "$base64" ] && kv "Base64" "$base64" "$C_WHITE"
    [ -n "$clash" ] && kv "Clash" "$clash" "$C_WHITE"
    [ -n "$shadowrocket" ] && kv "Shadowrocket" "$shadowrocket" "$C_WHITE"
    [ -n "$auto" ] && kv "Auto" "$auto" "$C_WHITE"

    echo ""
    printf "%b%s%b\n" "$C_BOLD$C_CYAN" "Next Commands" "$C_RESET"
    printf "  %bspeed%b              进入 Speed Slayer 控制台 / 重启后自动续跑\n" "$C_BOLD$C_GREEN" "$C_RESET"
    printf "  %bspeed --doctor%b     全链路诊断\n" "$C_BOLD$C_GREEN" "$C_RESET"
    printf "  %bspeed --logs%b       查看日志\n" "$C_BOLD$C_GREEN" "$C_RESET"
    printf "  %bspeed --repair%b     清理并重装节点\n" "$C_BOLD$C_GREEN" "$C_RESET"
    echo ""
    printf "%b完整信息：%b/etc/argox/list\n" "$C_DIM" "$C_RESET"
  else
    echo ""
    warn "未检测到节点信息。"
    printf "如果刚完成内核安装，请重启后执行：%bspeed%b\n" "$C_BOLD$C_GREEN" "$C_RESET"
    printf "如果需要单独部署节点，请执行：%bspeed --install-argo-vmess%b\n" "$C_BOLD$C_GREEN" "$C_RESET"
  fi
}

service_state() {
  local svc="$1"
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      echo "running"
    elif systemctl list-unit-files "$svc" >/dev/null 2>&1 || systemctl status "$svc" >/dev/null 2>&1; then
      echo "installed-but-not-running"
    else
      echo "not-found"
    fi
  else
    if pgrep -f "$svc" >/dev/null 2>&1; then
      echo "running"
    else
      echo "unknown"
    fi
  fi
}

port_state() {
  local port="$1"
  if command -v ss >/dev/null 2>&1 && ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${port}$"; then
    echo "listening"
  else
    echo "not-listening"
  fi
}

health_check() {
  require_root
  section "🩺 Speed Slayer · 健康检查"

  local fail=0
  local argo_state xray_state nginx_state nginx_port argo_domain port_status port_owner_text
  argo_state="$(service_state argo)"
  xray_state="$(service_state xray)"
  nginx_state="$(service_state nginx)"
  nginx_port="$(awk -F= '/^NGINX_PORT=/{print $2}' "$CONFIG_FILE" 2>/dev/null | tr -d "'\"")"
  nginx_port="${nginx_port:-8001}"
  port_status="$(port_state "$nginx_port")"
  port_owner_text="$(port_owner "$nginx_port")"

  status_row() {
    local label="$1" value="$2" good="$3"
    if [ "$good" = "1" ]; then
      printf "  %b✓ %-16s%b %b%s%b\n" "$C_GREEN" "$label" "$C_RESET" "$C_GREEN" "$value" "$C_RESET"
    else
      printf "  %b✗ %-16s%b %b%s%b\n" "$C_RED" "$label" "$C_RESET" "$C_RED" "$value" "$C_RESET"
    fi
  }

  status_row "Argo 服务" "$argo_state" "$([ "$argo_state" = "running" ] && echo 1 || echo 0)"
  status_row "Xray 服务" "$xray_state" "$([ "$xray_state" = "running" ] && echo 1 || echo 0)"
  status_row "Nginx 服务" "$nginx_state" "$([ "$nginx_state" = "running" ] && echo 1 || echo 0)"
  status_row "本地入口" "${nginx_port} / ${port_status}" "$([ "$port_status" = "listening" ] && echo 1 || echo 0)"
  [ "$port_status" != "listening" ] || printf "  %b• 端口占用%b %s\n" "$C_DIM" "$C_RESET" "$port_owner_text"

  [ "$argo_state" = "running" ] || fail=1
  [ "$xray_state" = "running" ] || fail=1
  [ "$port_status" = "listening" ] || fail=1

  if [ -s /etc/argox/list ]; then
    status_row "节点列表" "FOUND /etc/argox/list" 1
    argo_domain="$(grep -Eo 'https?://[^/ ]+' /etc/argox/list | sed 's#https\?://##' | grep -E 'trycloudflare\.com|cloudflare|\.' | head -n1 || true)"
    [ -n "$argo_domain" ] && printf "  %b• Argo 域名%b %s\n" "$C_CYAN" "$C_RESET" "$argo_domain" || printf "  %b• Argo 域名%b 未能从节点列表提取\n" "$C_YELLOW" "$C_RESET"
  else
    status_row "节点列表" "MISSING /etc/argox/list" 0
    fail=1
  fi

  if [ -s /etc/argox/subscribe/base64 ]; then
    status_row "Base64订阅" "FOUND" 1
  else
    status_row "Base64订阅" "MISSING" 0
    fail=1
  fi

  echo ""
  if [ "$fail" -eq 0 ]; then
    success "🎉 健康检查通过：Argo / Xray / 本地入口 / 订阅文件均可用"
    return 0
  fi

  warn "⚠️ 健康检查未完全通过，建议按以下方向排查："
  [ "$argo_state" = "running" ] || printf "  %b•%b Argo 未运行：systemctl status argo 或重新运行 --install-argo-vmess\n" "$C_YELLOW" "$C_RESET"
  [ "$xray_state" = "running" ] || printf "  %b•%b Xray 未运行：systemctl status xray，检查 /etc/argox/xray.log\n" "$C_YELLOW" "$C_RESET"
  [ "$port_status" = "listening" ] || printf "  %b•%b 本地入口端口未监听：检查 nginx 配置或端口占用 ss -lntp | grep %s\n" "$C_YELLOW" "$C_RESET" "$nginx_port"
  [ -s /etc/argox/list ] || printf "  %b•%b 节点列表未生成：查看 %s，确认 Argo 是否拿到隧道域名\n" "$C_YELLOW" "$C_RESET" "$LOG_FILE"
  [ -s /etc/argox/subscribe/base64 ] || printf "  %b•%b 订阅文件缺失：重新执行 --show-url 或 --install-argo-vmess\n" "$C_YELLOW" "$C_RESET"
  return 1
}

remote_version() {
  local tmp api_url
  tmp="$(mktemp /tmp/speed-slayer-version.XXXXXX)"
  api_url="https://api.github.com/repos/Suyunmeng/tcpspeed-optimization/contents/scripts/vps-argo-vmess-oneclick.sh?ref=main&ts=$(date +%s)"
  if curl -fsSL -H 'Accept: application/vnd.github.raw' -H 'Cache-Control: no-cache' "$api_url" -o "$tmp" 2>/dev/null; then
    grep -m1 '^SPEED_SLAYER_VERSION=' "$tmp" | cut -d= -f2- | tr -d '"'
  fi
  rm -f "$tmp"
}

version_rank() {
  local v="$1" major minor patch rev
  v="${v#v}"
  rev=0
  case "$v" in
    *-r*) rev="${v##*-r}"; v="${v%%-r*}" ;;
  esac
  major="${v%%.*}"
  v="${v#*.}"
  minor="${v%%.*}"
  patch="${v#*.}"
  major="${major:-0}"; minor="${minor:-0}"; patch="${patch:-0}"; rev="${rev:-0}"
  case "$major$minor$patch$rev" in *[!0-9]*) return 1 ;; esac
  printf "%03d%03d%03d%03d\n" "$major" "$minor" "$patch" "$rev"
}

is_newer_version() {
  local remote="$1" current="$2" rr cr
  rr="$(version_rank "$remote")" || return 1
  cr="$(version_rank "$current")" || return 1
  [ -n "$rr" ] && [ -n "$cr" ] && [ "$rr" -gt "$cr" ]
}

check_self_update_hint() {
  [ "${SKIP_UPDATE_CHECK:-0}" = "1" ] && return 0
  [ -t 1 ] || return 0
  local rv
  rv="$(remote_version || true)"
  if [ -n "$rv" ] && is_newer_version "$rv" "$SPEED_SLAYER_VERSION"; then
    warn "检测到新版本：${rv}（当前：${SPEED_SLAYER_VERSION}）。建议先执行：speed --update-self"
  fi
}

update_self() {
  require_root
  mkdir -p "$WORK_DIR"
  local api_url raw_url tmp version_after
  tmp="$INSTALLED_BIN.tmp"
  api_url="https://api.github.com/repos/Suyunmeng/tcpspeed-optimization/contents/scripts/vps-argo-vmess-oneclick.sh?ref=main&ts=$(date +%s)"
  raw_url="${REPO_RAW_BASE}/scripts/vps-argo-vmess-oneclick.sh?$(date +%s)"

  rm -f "$tmp"
  if curl -fsSL -H 'Accept: application/vnd.github.raw' -H 'Cache-Control: no-cache' "$api_url" -o "$tmp"; then
    :
  else
    warn "GitHub API 下载失败，尝试 raw.githubusercontent.com"
    curl -fsSL -H 'Cache-Control: no-cache' "$raw_url" -o "$tmp"
  fi

  if ! head -n 1 "$tmp" | grep -qE '^#!/usr/bin/env bash|^#!/bin/bash'; then
    err "下载到的不是 bash 脚本，已取消更新。文件头部："
    head -n 5 "$tmp" >&2 || true
    rm -f "$tmp"
    return 1
  fi

  bash -n "$tmp"
  version_after="$(grep -m1 '^SPEED_SLAYER_VERSION=' "$tmp" | cut -d= -f2- | tr -d '"')"
  mv "$tmp" "$INSTALLED_BIN"
  chmod +x "$INSTALLED_BIN"
  success "speed 已更新：${version_after:-unknown} -> $INSTALLED_BIN"
  "$INSTALLED_BIN" --version || true
}

show_roadmap() {
  section "Speed Slayer · Roadmap"
  cat <<'EOF'
当前进度：约 97%

已完成：
- 一键完整流程与重启续跑
- BBR v3 / TCP 加速配置
- Argo VMess+WS 部署与订阅生成
- 重复安装预清理与 JSON 校验
- 日志菜单与修复命令
- 版本号与自更新
- 产品化文案清理

正在施工：
- 稳定性与失败提示收口
- 重复安装与残留处理继续加固
- 菜单结构产品化

下一步：
1. 收拢主页为二级菜单
2. 增强 doctor：端口、服务、配置、订阅全链路诊断
3. 输出最终安装摘要与复制友好节点信息
4. README / CHANGELOG / 发布版本收口

预计剩余：
- 可用 Beta：已接近，可进入实机回归
- 接近 V1.0：约 1 轮施工
EOF
}

show_logs() {
  require_root
  local target="${1:-menu}"
  case "$target" in
    kernel) tail -n 160 "$WORK_DIR/kernel-install.log" 2>/dev/null || warn "暂无内核安装日志" ;;
    tcp) tail -n 160 "$WORK_DIR/tcp-optimize.log" 2>/dev/null || warn "暂无 TCP 日志" ;;
    skyline) tail -n 200 "$SKYLINE_LOG_FILE" 2>/dev/null || warn "暂无 Skyline Speeder 日志" ;;
    install) tail -n 160 "$LOG_FILE" 2>/dev/null || warn "暂无安装日志" ;;
    argo) tail -n 160 /etc/argox/argo.log 2>/dev/null || warn "暂无 Argo 日志" ;;
    xray) tail -n 160 /etc/argox/xray-error.log 2>/dev/null || warn "暂无 Xray 错误日志" ;;
    menu)
      section "Speed Slayer · 日志"
      echo "1. 安装总日志      $LOG_FILE"
      echo "2. 内核安装日志    $WORK_DIR/kernel-install.log"
      echo "3. TCP 调优日志    $WORK_DIR/tcp-optimize.log"
      echo "4. Skyline 日志     $SKYLINE_LOG_FILE"
      echo "5. Argo 日志       /etc/argox/argo.log"
      echo "6. Xray 错误日志   /etc/argox/xray-error.log"
      echo "0. 返回"
      read -r -p "请选择: " log_choice
      case "$log_choice" in
        1) show_logs install ;;
        2) show_logs kernel ;;
        3) show_logs tcp ;;
        4) show_logs skyline ;;
        5) show_logs argo ;;
        6) show_logs xray ;;
        *) return 0 ;;
      esac
      ;;
    *) err "未知日志类型：$target"; return 1 ;;
  esac
}

repair_install() {
  require_root
  section "Speed Slayer · 修复"
  warn "将清理 Argo 服务/进程/配置残留，然后重新部署 VMess+WS。"
  if ! confirm_action "是否继续修复？默认回车 = Y"; then
    warn "已取消修复。"
    return 0
  fi
  clean_argo_state
  install_argo_vmess_ws
}


menu_section_repair() {
  while true; do
    section "Speed Slayer · 修复 / 清理 / 卸载"
    cat <<'EOF'
1. 修复 Argo 安装（清理残留并重装）
2. 清理 Argo 配置（备份 /etc/argox）
3. 删除 / 卸载 Speed Slayer ⭐
0. 返回主页
EOF
    read -r -p "请选择: " choice
    case "$choice" in
      1) repair_install; menu_pause ;;
      2) clean_argo_state; menu_pause ;;
      3) uninstall_speed_slayer; menu_pause ;;
      0) return 0 ;;
      *) err "无效选择"; menu_pause ;;
    esac
  done
}


uninstall_speed_slayer() {
  render_header_once
  require_root
  section "🗑️ Speed Slayer · 删除/卸载"
  warn "此操作会移除 Speed Slayer 安装的快捷命令、续跑状态、Argo/Xray/Nginx 配置、TCP sysctl 配置与 systemd 残留。"
  warn "不会卸载 XanMod 内核本身，避免误删系统内核；如需回退内核，请在系统启动项/包管理器中单独处理。"
  local confirm_delete=""
  printf "%b?%b 确认删除 Speed Slayer 相关内容？默认回车 = N %b[y/N]%b " "$C_YELLOW" "$C_RESET" "$C_RED" "$C_RESET"
  read -r confirm_delete || confirm_delete=""
  case "$confirm_delete" in
    [Yy]|[Yy][Ee][Ss]) ;;
    *)
      warn "已取消删除。"
      return 0
      ;;
  esac

  local ts
  ts="$(date +%Y%m%d%H%M%S)"

  progress_step 15 "停止并移除 Argo / Xray 服务"
  systemctl stop argo xray >/dev/null 2>&1 || true
  systemctl disable argo xray >/dev/null 2>&1 || true
  pkill -f '/etc/argox/cloudflared' >/dev/null 2>&1 || true
  pkill -f '/etc/argox/xray' >/dev/null 2>&1 || true
  pkill -f 'nginx.*argox/nginx.conf' >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/argo.service /etc/systemd/system/xray.service

  progress_step 35 "备份并清理节点配置"
  if [ -d /etc/argox ]; then
    mv /etc/argox "/etc/argox.bak.${ts}" 2>/dev/null || rm -rf /etc/argox
    success "已备份 /etc/argox -> /etc/argox.bak.${ts}"
  fi

  progress_step 55 "清理 Speed Slayer TCP / DNS / IPv6 配置"
  rm -f /etc/sysctl.d/99-speed-slayer-tcp.conf
  rm -f /etc/sysctl.d/99-speed-slayer-disable-ipv6.conf
  rm -f /etc/modules-load.d/99-speed-slayer-bbr.conf
  rm -f /etc/systemd/system.conf.d/99-speed-slayer-limits.conf
  rm -f /etc/systemd/user.conf.d/99-speed-slayer-limits.conf
  rm -f /etc/systemd/resolved.conf.d/99-speed-slayer-dns.conf
  sysctl --system >/dev/null 2>&1 || true

  progress_step 75 "清理续跑状态与工作目录"
  rm -f "$STATE_FILE"
  if [ -d "$WORK_DIR" ]; then
    mv "$WORK_DIR" "${WORK_DIR}.bak.${ts}" 2>/dev/null || rm -rf "$WORK_DIR"
    success "已备份 $WORK_DIR -> ${WORK_DIR}.bak.${ts}"
  fi

  progress_step 90 "移除 speed 快捷命令"
  rm -f "$INSTALLED_BIN" "$INSTALLED_BIN.tmp"
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl daemon-reexec >/dev/null 2>&1 || true
  systemctl restart systemd-resolved >/dev/null 2>&1 || true

  progress_step 100 "删除完成"
  success "Speed Slayer 已删除。保留的 .bak 目录可用于排障回溯。"
  echo ""
  echo "如需继续安装，请执行："
  echo "  bash <(curl -fsSL https://github.com/Suyunmeng/tcpspeed-optimization/raw/main/install.sh) --all"
  echo ""
  echo "如果环境不支持 <(...)，请执行："
  echo "  curl -fsSL https://github.com/Suyunmeng/tcpspeed-optimization/raw/main/install.sh -o /tmp/speed-install && bash /tmp/speed-install --all"
}

doctor_check() {
  local label="$1" cmd="$2" fix="${3:-}"
  if eval "$cmd" >/dev/null 2>&1; then
    printf "%b[OK]%b   %s\n" "$C_GREEN" "$C_RESET" "$label"
  else
    printf "%b[FAIL]%b %s\n" "$C_RED" "$C_RESET" "$label"
    [ -n "$fix" ] && printf "       修复建议：%s\n" "$fix"
    return 1
  fi
}

doctor_warn() {
  local label="$1" cmd="$2" fix="${3:-}"
  if eval "$cmd" >/dev/null 2>&1; then
    printf "%b[OK]%b   %s\n" "$C_GREEN" "$C_RESET" "$label"
  else
    printf "%b[WARN]%b %s\n" "$C_YELLOW" "$C_RESET" "$label"
    [ -n "$fix" ] && printf "       建议：%s\n" "$fix"
  fi
}

doctor() {
  require_root
  section "Speed Slayer · Doctor"
  local failed=0
  doctor_check "Root 权限" '[ "$(id -u)" -eq 0 ]' "使用 root 执行 speed" || failed=1
  doctor_check "systemd 可用" 'command -v systemctl && [ -d /run/systemd/system ]' "当前系统可能不支持 systemd，建议使用 Debian/Ubuntu VPS" || failed=1
  doctor_check "curl 可用" 'command -v curl' "apt install -y curl" || failed=1
  doctor_check "ss 可用" 'command -v ss' "apt install -y iproute2" || failed=1
  doctor_check "python3 可用" 'command -v python3' "apt install -y python3" || failed=1

  echo ""
  echo "服务状态："
  doctor_warn "xray.service 运行" 'systemctl is-active --quiet xray' "执行 speed --repair"
  doctor_warn "argo.service 运行" 'systemctl is-active --quiet argo' "执行 speed --repair"
  doctor_warn "入口端口监听" '[ "$(port_state "${NGINX_PORT:-8001}")" = "listening" ]' "检查 nginx 或执行 speed --repair"
  doctor_warn "内部 WS 端口监听" '[ "$(port_state "${VMESS_WS_PORT:-30000}")" = "listening" ]' "检查 xray 或执行 speed --repair"

  echo ""
  echo "配置与订阅："
  doctor_check "inbound.json 存在" '[ -s /etc/argox/inbound.json ]' "执行 speed --install-argo-vmess" || failed=1
  if [ -s /etc/argox/inbound.json ]; then
    doctor_check "VMess+WS 配置有效" 'verify_vmess_only' "执行 speed --repair" || failed=1
  fi
  doctor_warn "节点信息已生成" '[ -s /etc/argox/list ]' "执行 speed --install-argo-vmess"
  doctor_warn "Base64 订阅存在" '[ -s /etc/argox/subscribe/base64 ]' "执行 speed --install-argo-vmess"

  echo ""
  echo "网络加速："
  doctor_warn "BBR 已启用" '[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ]' "执行 speed --optimize"
  doctor_warn "队列算法 fq" '[ "$(sysctl -n net.core.default_qdisc 2>/dev/null)" = "fq" ]' "执行 speed --optimize"

  echo ""
  echo "Skyline Speeder："
  doctor_warn "Skyline 服务运行" 'systemctl is-active --quiet skyline-speederd.service && systemctl is-active --quiet skyline-speeder-enable.service' "执行 speed --skyline"
  doctor_warn "Skyline 拥塞控制已启用" '[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "skyline_cc" ]' "执行 speed --skyline"

  echo ""
  if [ "$failed" -eq 0 ]; then
    success "Doctor 完成：核心链路未发现阻断项。"
  else
    err "Doctor 完成：发现阻断项，建议优先执行 speed --repair 或查看 speed --logs。"
    return 1
  fi
}

usage() {
  cat <<'EOF'
Speed Slayer

Usage:
  bash vps-argo-vmess-oneclick.sh [command]

Commands:
  --tcp-status           查看 TCP / BBR / 内核状态
  --tcp                  单独执行 TCP 调优流程（等同 --optimize）
  --tcp-skyline          执行已有 TCP 调优后，再安装并自动配置 Skyline Speeder
  --skyline              安装并自动配置 Skyline Speeder（免编译工具链）
  --skyline-status       查看 Skyline Speeder 状态
  --skyline-rollback     卸载并回滚 Skyline Speeder 特殊优化配置
  --optimize             单独执行 TCP 调优流程：BBR/XanMod/容器降级 + 网络参数
  --argo                 单独执行 Argo VMess+WS 节点流程（等同 --install-argo-vmess）
  --install-argo-vmess   单独安装/重装 Argo VMess+WS，并生成节点/订阅 URL
  --all                  完整流程：TCP 调优 + Argo 节点；如需重启，重启后执行 speed 继续
  --force-all            等同 --all
  --menu                 安装/刷新 speed 快捷命令并打开交互控制台
  --continue             自动续跑：TCP 网络调优 + Argo VMess + WS
  --show-url             查看已生成的节点/订阅信息
  --uninstall-argo       卸载 Argo VMess + WS 相关服务
  --clean-argo           清理现有 Argo 配置，备份 /etc/argox 后重装 VMess+WS
  --write-config         仅生成 Argo VMess + WS 配置文件，不安装
  --install-shortcut     安装 speed 快捷命令到 /usr/local/bin/speed
  --clear-state          清理续跑状态
  --check                检测当前环境和已安装状态
  --summary              输出结果摘要
  --health               安装后健康检查
  --doctor               一键诊断：环境检测 + 结果摘要 + 健康检查
  --logs [type]          查看日志：install/kernel/tcp/skyline/argo/xray
  --repair               清理残留并重装 Argo VMess+WS
  --uninstall            删除 Speed Slayer 相关服务、配置、状态和 speed 命令
  --speedtest            执行 Ookla Speedtest 测速
  --netcheck             检查 DNS / GitHub / Cloudflare / 出站连通性
  --update-self          更新 /usr/local/bin/speed 到 GitHub 最新版本
  --version              显示当前 Speed Slayer 版本
  -h, --help             显示帮助

Optional environment variables:
  UUID                   指定 VMess UUID，默认自动生成
  WS_PATH                指定 WS Path 前缀，默认 argox，实际 path 为 /<WS_PATH>-vm
  START_PORT             指定 Xray VMess 内部监听端口，默认 30000
  NGINX_PORT             指定 Nginx/Argo 本地入口端口，默认 8001
  NODE_NAME              指定节点名，默认自动生成：国家代码-主机名-vmess-ws-argo
  ARGO_DOMAIN            固定 Argo 域名；不填则使用 trycloudflare 临时域名
  ARGO_AUTH              Argo Token / Json / Cloudflare API 信息；固定隧道时使用
  SERVER                 CDN 优选地址，默认 www.visa.com
  SERVER_PORT            优选 CDN 端口，默认 443

Examples:
  bash vps-argo-vmess-oneclick.sh --all
  WS_PATH=zaki NODE_NAME=Zaki-VPS bash vps-argo-vmess-oneclick.sh --install-argo-vmess
  ARGO_DOMAIN=tunnel.example.com ARGO_AUTH='eyJhIj...' bash vps-argo-vmess-oneclick.sh --install-argo-vmess
EOF
}

menu_pause() {
  [ -t 0 ] || return 0
  echo ""
  read -r -p "按回车返回上级菜单..." _ || true
}

menu_section_node() {
  while true; do
    section "Speed Slayer · 节点管理"
    cat <<'EOF'
1. 安装/重装 Argo VMess+WS
2. 查看节点/订阅信息
3. 修复 Argo 安装
4. 卸载 Argo VMess+WS
5. 清理 Argo 配置
0. 返回主页
EOF
    read -r -p "请选择: " choice
    case "$choice" in
      1) install_argo_vmess_ws; menu_pause ;;
      2) show_argo_vmess_ws_info; menu_pause ;;
      3) repair_install; menu_pause ;;
      4) uninstall_argo_vmess_ws; menu_pause ;;
      5) clean_argo_state; menu_pause ;;
      0) return 0 ;;
      *) err "无效选择"; menu_pause ;;
    esac
  done
}

menu_section_tcp() {
  while true; do
    section "Speed Slayer · TCP 加速"
    cat <<'EOF'
1. 查看 TCP / BBR / 内核状态
2. 执行 TCP 优化
3. TCP 优化 + Skyline Speeder 后置优化 ⭐
4. 单独安装 / 自动配置 Skyline Speeder
5. 查看 Skyline Speeder 状态
6. 重启后继续安装
7. 回滚 Skyline Speeder 特殊优化
0. 返回主页
EOF
    read -r -p "请选择: " choice
    case "$choice" in
      1) tcp_status_panel; menu_pause ;;
      2) run_tcp_optimize; menu_pause ;;
      3) run_tcp_then_skyline; menu_pause ;;
      4) run_skyline_optimize; menu_pause ;;
      5) skyline_status; menu_pause ;;
      6) continue_after_reboot; menu_pause ;;
      7) skyline_rollback; menu_pause ;;
      0) return 0 ;;
      *) err "无效选择"; menu_pause ;;
    esac
  done
}

menu_section_diag() {
  while true; do
    section "Speed Slayer · 诊断与日志"
    cat <<'EOF'
1. 一键诊断 doctor
2. 环境检测
3. 结果摘要
4. 健康检查
5. 查看日志
6. Speedtest 测速
7. Netcheck 网络检测
0. 返回主页
EOF
    read -r -p "请选择: " choice
    case "$choice" in
      1) doctor; menu_pause ;;
      2) check_environment; menu_pause ;;
      3) summarize_result; menu_pause ;;
      4) health_check; menu_pause ;;
      5) show_logs; menu_pause ;;
      6) run_speedtest_cmd; menu_pause ;;
      7) run_netcheck; menu_pause ;;
      0) return 0 ;;
      *) err "无效选择"; menu_pause ;;
    esac
  done
}

menu_section_system() {
  while true; do
    section "Speed Slayer · 更新 / 删除"
    cat <<'EOF'
1. 安装 speed 快捷命令
2. 更新 speed 自身
3. 删除 / 卸载 Speed Slayer
0. 返回主页
EOF
    read -r -p "请选择: " choice
    case "$choice" in
      1) install_shortcut; menu_pause ;;
      2) update_self; menu_pause ;;
      3) uninstall_speed_slayer; menu_pause ;;
      0) return 0 ;;
      *) err "无效选择"; menu_pause ;;
    esac
  done
}

menu_body() {
  while true; do
    cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 『Speed Slayer 控制台』
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Speed Slayer TCP+Argo 🚀
  2. 一键TCP调优
  3. 一键Vmess+Argo 节点生成
  4. 查看节点/订阅信息
  5. 诊断与日志
  6. 修复/清理/卸载
  7. 更新
  0. 退出
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    read -r -p "请输入选择: " choice
    case "$choice" in
      1) force_all; menu_pause ;;
      2) menu_section_tcp ;;
      3) menu_section_node ;;
      4) show_argo_vmess_ws_info; menu_pause ;;
      5) menu_section_diag ;;
      6) menu_section_repair ;;
      7) menu_section_system ;;
      0) exit 0 ;;
      *) err "无效选择"; menu_pause ;;
    esac
  done
}

menu() {
  render_header_once
  menu_body
}

default_action() {
  render_header_once
  check_self_update_hint
  require_root
  install_shortcut || true
  if [ -s "$STATE_FILE" ]; then
    info "检测到续跑状态，自动继续当前流程。"
    continue_after_reboot
  fi
  menu
}

case "${1:-}" in
  --tcp-status) tcp_status_panel ;;
  --tcp) run_tcp_optimize ;;
  --tcp-skyline) run_tcp_then_skyline ;;
  --skyline) run_skyline_optimize ;;
  --skyline-status) skyline_status ;;
  --skyline-rollback) skyline_rollback ;;
  --optimize) run_tcp_optimize ;;
  --argo) install_argo_vmess_ws ;;
  --install-argo-vmess) install_argo_vmess_ws ;;
  --all) run_all ;;
  --force-all) force_all ;;
  --menu) run_menu ;;
  --continue) continue_after_reboot ;;
  --show-url) show_argo_vmess_ws_info ;;
  --uninstall-argo) uninstall_argo_vmess_ws ;;
  --clean-argo) clean_argo_state ;;
  --write-config) write_argox_vmess_config ;;
  --install-shortcut) install_shortcut ;;
  --clear-state) clear_state ;;
  --check) check_environment ;;
  --summary) summarize_result ;;
  --health) health_check ;;
  --doctor) doctor ;;
  --logs) show_logs "${2:-menu}" ;;
  --repair) repair_install ;;
  --uninstall) uninstall_speed_slayer ;;
  --speedtest) run_speedtest_cmd ;;
  --netcheck) run_netcheck ;;
  --update-self) update_self ;;
  --version) echo "Speed Slayer ${SPEED_SLAYER_VERSION}" ;;
  -h|--help) usage ;;
  "") default_action ;;
  *) err "未知参数：$1"; usage; exit 1 ;;
esac
