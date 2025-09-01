#!/usr/bin/env bash
set -euo pipefail

# nukedir installer script
# Can be run directly or as a one-liner:
# curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/nukedir/main/install.sh | sudo bash

readonly INSTALL_DIR="/usr/local/bin"
readonly COMPLETION_DIR="/etc/bash_completion.d"
readonly SCRIPT_NAME="nukedir"
readonly COMPLETION_NAME="nukedir"

# Colors for output (only if terminal supports it)
if [[ -t 1 ]]; then
  readonly RED=$'\033[0;31m'
  readonly GREEN=$'\033[0;32m'
  readonly YELLOW=$'\033[0;33m'
  readonly BLUE=$'\033[0;34m'
  readonly RESET=$'\033[0m'
else
  readonly RED='' GREEN='' YELLOW='' BLUE='' RESET=''
fi

# Helper functions
info() { echo "${BLUE}[INFO]${RESET} $*"; }
success() { echo "${GREEN}[SUCCESS]${RESET} $*"; }
warn() { echo "${YELLOW}[WARNING]${RESET} $*" >&2; }
error() { echo "${RED}[ERROR]${RESET} $*" >&2; }
die() { error "$@"; exit 1; }

# Check for root privileges
check_root() {
  if [[ $EUID -ne 0 ]]; then
    die "This installer must be run as root. Please use: sudo $0"
  fi
}

# Detect if we're running from a local directory or via curl
detect_source() {
  local script_dir
  if [[ -f "$0" ]] && [[ "$0" != "bash" ]]; then
    # Running as a local script
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    echo "$script_dir"
  else
    # Running via curl/pipe - download files
    echo "REMOTE"
  fi
}

# Download file from GitHub
download_file() {
  local file="$1"
  local url="https://raw.githubusercontent.com/Open-Technology-Foundation/nukedir/main/$file"
  local temp_file
  temp_file=$(mktemp)
  
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$temp_file" || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$temp_file" "$url" || return 1
  else
    die "Neither curl nor wget found. Please install one of them."
  fi
  
  echo "$temp_file"
}

# Install nukedir script
install_script() {
  local source_dir="$1"
  local script_path
  local temp_script
  
  info "Installing ${SCRIPT_NAME} to ${INSTALL_DIR}..."
  
  # Create install directory if it doesn't exist
  [[ -d "$INSTALL_DIR" ]] || mkdir -p "$INSTALL_DIR"
  
  if [[ "$source_dir" == "REMOTE" ]]; then
    # Download from GitHub
    info "Downloading ${SCRIPT_NAME} from GitHub..."
    temp_script=$(download_file "${SCRIPT_NAME}") || die "Failed to download ${SCRIPT_NAME}"
    script_path="$temp_script"
  else
    # Copy from local directory
    script_path="${source_dir}/${SCRIPT_NAME}"
    [[ -f "$script_path" ]] || die "Script not found: $script_path"
  fi
  
  # Install the script
  cp "$script_path" "${INSTALL_DIR}/${SCRIPT_NAME}" || die "Failed to copy script"
  chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}" || die "Failed to set execute permission"
  
  # Clean up temp file if downloaded
  [[ "$source_dir" == "REMOTE" ]] && rm -f "$script_path"
  
  success "${SCRIPT_NAME} installed successfully"
}

# Install bash completion
install_completion() {
  local source_dir="$1"
  local completion_path
  local temp_completion
  
  info "Installing bash completion..."
  
  # Check if bash-completion is installed
  if [[ ! -d "$COMPLETION_DIR" ]]; then
    warn "Directory $COMPLETION_DIR not found"
    warn "bash-completion might not be installed"
    info "To install bash-completion:"
    info "  Ubuntu/Debian: sudo apt-get install bash-completion"
    info "  RHEL/CentOS: sudo yum install bash-completion"
    info "  macOS: brew install bash-completion"
    return 1
  fi
  
  if [[ "$source_dir" == "REMOTE" ]]; then
    # Download from GitHub
    info "Downloading bash completion from GitHub..."
    temp_completion=$(download_file ".bash_completion") || {
      warn "Failed to download bash completion file"
      return 1
    }
    completion_path="$temp_completion"
  else
    # Copy from local directory
    completion_path="${source_dir}/.bash_completion"
    if [[ ! -f "$completion_path" ]]; then
      warn "Bash completion file not found: $completion_path"
      return 1
    fi
  fi
  
  # Install the completion file
  cp "$completion_path" "${COMPLETION_DIR}/${COMPLETION_NAME}" || {
    warn "Failed to copy bash completion"
    [[ "$source_dir" == "REMOTE" ]] && rm -f "$completion_path"
    return 1
  }
  
  # Clean up temp file if downloaded
  [[ "$source_dir" == "REMOTE" ]] && rm -f "$completion_path"
  
  success "Bash completion installed successfully"
  info "Reload your shell or run: source ${COMPLETION_DIR}/${COMPLETION_NAME}"
  return 0
}

# Verify installation
verify_installation() {
  info "Verifying installation..."
  
  # Check if nukedir is in PATH
  if command -v nukedir >/dev/null 2>&1; then
    local version
    version=$(nukedir --version 2>/dev/null || echo "unknown")
    success "nukedir is installed and accessible (version: $version)"
  else
    warn "nukedir installed but not in PATH"
    info "Add ${INSTALL_DIR} to your PATH if needed"
  fi
  
  # Check if completion is available
  if [[ -f "${COMPLETION_DIR}/${COMPLETION_NAME}" ]]; then
    success "Bash completion is installed"
  else
    warn "Bash completion not installed"
  fi
}

# Uninstall function
uninstall() {
  info "Uninstalling nukedir..."
  
  # Remove script
  if [[ -f "${INSTALL_DIR}/${SCRIPT_NAME}" ]]; then
    rm -f "${INSTALL_DIR}/${SCRIPT_NAME}" || warn "Failed to remove ${INSTALL_DIR}/${SCRIPT_NAME}"
    success "Removed ${INSTALL_DIR}/${SCRIPT_NAME}"
  else
    info "${INSTALL_DIR}/${SCRIPT_NAME} not found"
  fi
  
  # Remove completion
  if [[ -f "${COMPLETION_DIR}/${COMPLETION_NAME}" ]]; then
    rm -f "${COMPLETION_DIR}/${COMPLETION_NAME}" || warn "Failed to remove ${COMPLETION_DIR}/${COMPLETION_NAME}"
    success "Removed ${COMPLETION_DIR}/${COMPLETION_NAME}"
  else
    info "${COMPLETION_DIR}/${COMPLETION_NAME} not found"
  fi
  
  success "Uninstallation complete"
}

# Main installation flow
main() {
  local action="install"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uninstall|-u)
        action="uninstall"
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
        die "Unknown option: $1"
        ;;
    esac
    shift
  done
  
  # Check for root
  check_root
  
  if [[ "$action" == "uninstall" ]]; then
    uninstall
    exit 0
  fi
  
  echo "${GREEN}================================${RESET}"
  echo "${GREEN}  nukedir Installer${RESET}"
  echo "${GREEN}================================${RESET}"
  echo
  
  # Detect if running locally or via curl
  local source_dir
  source_dir=$(detect_source)
  
  if [[ "$source_dir" == "REMOTE" ]]; then
    info "Installing from GitHub repository..."
  else
    info "Installing from local directory: $source_dir"
  fi
  
  install_script "$source_dir"
  
  # Install bash completion (don't fail if it doesn't work)
  install_completion "$source_dir" || true
  
  echo
  echo "${GREEN}================================${RESET}"
  echo "${GREEN}  Installation Complete!${RESET}"
  echo "${GREEN}================================${RESET}"
  echo
  
  verify_installation
  
  echo
  info "To use nukedir, run: nukedir --help"
  info "To uninstall, run: sudo $0 --uninstall"
}

main "$@"
#fin
