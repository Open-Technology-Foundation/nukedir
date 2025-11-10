#!/usr/bin/env bash
#shellcheck disable=SC2155
# nukedir installer script
# Can be run directly or as a one-liner:
# curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/nukedir/main/install.sh | sudo bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Security: Lock down PATH to prevent injection attacks
# Critical for scripts running as root - ensures only system binaries are used
declare -r PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

declare -r INSTALL_DIR=/usr/local/bin
declare -r COMPLETION_DIR=/etc/bash_completion.d
declare -r TARGET_SCRIPT_NAME=nukedir
declare -r COMPLETION_NAME=nukedir

# Colors for output (only if terminal supports it)
if [[ -t 1 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

_msg() {
  local -- status="${FUNCNAME[1]}" prefix="$TARGET_SCRIPT_NAME:" msg
  case "$status" in
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}▲${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}
# Standard message functions
info()    { >&2 _msg "$@"; }
warn()    { >&2 _msg "$@"; }
success() { >&2 _msg "$@"; }
error()   { >&2 _msg "$@"; }
die()     { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Check for root privileges
check_root() {
  ((EUID==0)) || die 1 'This installer must be run as root.' "Please use: sudo $0"
}

# Detect if we're running from a local directory or via curl
detect_source() {
  local -- script_dir
  if [[ -f "$0" && "$0" != bash ]]; then
    # Running as a local script
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    echo "$script_dir"
  else
    # Running via curl/pipe - download files
    echo 'REMOTE'
  fi
}

# Download file from GitHub
download_file() {
  local -- file=$1
  local -- url=https://raw.githubusercontent.com/Open-Technology-Foundation/nukedir/main/"$file"
  local -- temp_file
  temp_file=$("$MKTEMP")

  if [[ -n "$CURL" ]]; then
    "$CURL" -fsSL "$url" -o "$temp_file" || return 1
  elif [[ -n "$WGET" ]]; then
    "$WGET" -qO "$temp_file" "$url" || return 1
  else
    die 1 'Neither curl nor wget found. Please install one of them.'
  fi

  echo "$temp_file"
}

# Install nukedir script
install_script() {
  local -- source_dir=$1
  local -- script_path temp_script
  
  info "Installing ${TARGET_SCRIPT_NAME@Q} to ${INSTALL_DIR@Q}..."
  
  # Create install directory if it doesn't exist
  [[ -d "$INSTALL_DIR" ]] || "$MKDIR" -p "$INSTALL_DIR"

  if [[ "$source_dir" == REMOTE ]]; then
    # Download from GitHub
    info "Downloading ${TARGET_SCRIPT_NAME@Q} from GitHub..."
    temp_script=$(download_file "$TARGET_SCRIPT_NAME") || die 1 "Failed to download ${TARGET_SCRIPT_NAME@Q}"
    script_path="$temp_script"
  else
    # Copy from local directory
    script_path="$source_dir"/"$TARGET_SCRIPT_NAME"
    [[ -f "$script_path" ]] || die 1 "Script not found ${script_path@Q}"
  fi

  # Install the script
  "$CP" "$script_path" "$INSTALL_DIR"/"$TARGET_SCRIPT_NAME" || die 1 'Failed to copy script'
  "$CHMOD" +x "$INSTALL_DIR"/"$TARGET_SCRIPT_NAME" || die 1 'Failed to set execute permission'

  # Clean up temp file if downloaded
  [[ "$source_dir" == REMOTE ]] && "$RM" -f "$script_path"
  
  success "${TARGET_SCRIPT_NAME@Q} installed successfully"
  return 0
}

# Install bash completion
install_completion() {
  local -- source_dir=$1
  local -- completion_path temp_completion
  
  info 'Installing bash completion...'
  
  # Check if bash-completion is installed
  if [[ ! -d "$COMPLETION_DIR" ]]; then
    warn "Directory ${COMPLETION_DIR@Q} not found" \
         'bash-completion might not be installed'
    info 'To install bash-completion:' \
         '  Ubuntu/Debian: sudo apt-get install bash-completion' \
         '  RHEL/CentOS: sudo yum install bash-completion' \
         '  macOS: brew install bash-completion'
    return 1
  fi
  
  if [[ "$source_dir" == REMOTE ]]; then
    # Download from GitHub
    info 'Downloading bash completion from GitHub...'
    temp_completion=$(download_file .bash_completion) || {
      warn 'Failed to download bash completion file'
      return 1
    }
    completion_path="$temp_completion"
  else
    # Copy from local directory
    completion_path="$source_dir"/.bash_completion
    if [[ ! -f "$completion_path" ]]; then
      warn "Bash completion file not found ${completion_path@Q}"
      return 1
    fi
  fi
  
  # Install the completion file
  "$CP" "$completion_path" "$COMPLETION_DIR"/"$COMPLETION_NAME" || {
    warn 'Failed to copy bash completion'
    [[ "$source_dir" == REMOTE ]] && "$RM" -f "$completion_path"
    return 1
  }

  # Clean up temp file if downloaded
  [[ "$source_dir" == REMOTE ]] && "$RM" -f "$completion_path" || :
  
  success 'Bash completion installed successfully'
  info "Reload your shell or run: source '$COMPLETION_DIR/$COMPLETION_NAME'"
  return 0
}

# Verify installation
verify_installation() {
  info 'Verifying installation...'
  
  # Check if nukedir is in PATH
  if command -v nukedir >/dev/null 2>&1; then
    local -- version
    version=$(nukedir --version 2>/dev/null || echo 'unknown')
    success "nukedir is installed and accessible (version $version)"
  else
    warn 'nukedir installed but not in PATH'
    info "Add ${INSTALL_DIR@Q} to your PATH if needed"
  fi
  
  # Check if completion is available
  if [[ -f "$COMPLETION_DIR"/"$COMPLETION_NAME" ]]; then
    success 'Bash completion is installed'
  else
    warn 'Bash completion not installed'
  fi
}

# Uninstall function
uninstall() {
  info 'Uninstalling nukedir...'

  # Remove script
  if [[ -f "$INSTALL_DIR"/"$TARGET_SCRIPT_NAME" ]]; then
    "$RM" -f "$INSTALL_DIR"/"$TARGET_SCRIPT_NAME" || warn "Failed to remove '$INSTALL_DIR/$TARGET_SCRIPT_NAME'"
    success "Removed '$INSTALL_DIR/$TARGET_SCRIPT_NAME'"
  else
    info "'$INSTALL_DIR/$TARGET_SCRIPT_NAME' not found"
  fi

  # Remove completion
  if [[ -f "$COMPLETION_DIR"/"$COMPLETION_NAME" ]]; then
    "$RM" -f "$COMPLETION_DIR"/"$COMPLETION_NAME" || warn "Failed to remove '$COMPLETION_DIR/$COMPLETION_NAME'"
    success "Removed '$COMPLETION_DIR/$COMPLETION_NAME'"
  else
    info "'$COMPLETION_DIR/$COMPLETION_NAME' not found"
  fi
  
  success 'Uninstallation complete'
}

# Locate and cache critical commands using secured PATH
# This prevents repeated lookups and ensures consistent binary usage
declare -r CURL=$(command -v curl 2>/dev/null || echo '')
declare -r WGET=$(command -v wget 2>/dev/null || echo '')
declare -r CP=$(command -v cp || die 1 'cp command not found')
declare -r CHMOD=$(command -v chmod || die 1 'chmod command not found')
declare -r MKDIR=$(command -v mkdir || die 1 'mkdir command not found')
declare -r RM=$(command -v rm || die 1 'rm command not found')
declare -r MKTEMP=$(command -v mktemp || die 1 'mktemp command not found')

# Main installation flow
main() {
  local -- action=install
  
  # Parse arguments
  while (($#)); do
    case $1 in
      --uninstall|-u)
        action=uninstall
        ;;
      --help|-h)
        cat <<EOF
nukedir Installer

Usage: 
  $0 [OPTIONS]

Options:
  --uninstall, -u    Uninstall nukedir
  --help, -h         Show this help message

Installation:
  Local:    sudo ./install.sh
  Remote:   curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/nukedir/main/install.sh | sudo bash

Uninstallation:
  sudo ./install.sh --uninstall
EOF
        exit 0
        ;;
      *)
        die 22 "Unknown option ${1@Q}"
        ;;
    esac
    shift
  done
  
  # Check for root
  check_root
  
  if [[ "$action" == uninstall ]]; then
    uninstall
    exit 0
  fi
  
  info  '================================' \
        '  nukedir Installer' \
        '================================' ''
  
  # Detect if running locally or via curl
  local -- source_dir
  source_dir=$(detect_source)
  
  if [[ "$source_dir" == REMOTE ]]; then
    info 'Installing from GitHub repository...'
  else
    info "Installing from local directory ${source_dir@Q}"
  fi
  
  install_script "$source_dir"
  
  # Install bash completion (don't fail if it doesn't work)
  install_completion "$source_dir" || true
  
  info '================================' \
       '  Installation Complete!' \
       '================================' ''
  
  verify_installation
  
  echo
  info 'To use nukedir, run: nukedir --help' \
       "To uninstall, run: sudo $0 --uninstall"
}

main "$@"
#fin
