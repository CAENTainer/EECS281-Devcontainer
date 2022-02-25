#!/bin/bash

# This script referenced code from following open source projects:
# https://github.com/ohmyzsh/ohmyzsh (Under MIT License)

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

print_info() {
  printf '%s[INFO] %s%s\n' "${FMT_BLUE}" "$*" "$FMT_RESET" >&2
}

print_success() {
  printf '%s[INFO] %s%s\n' "${FMT_GREEN}" "$*" "$FMT_RESET" >&2
}

print_warning() {
  printf '%s[WARN] %s%s\n' "${FMT_YELLOW}" "$*" "$FMT_RESET" >&2
}

print_error() {
  printf '%s[ERROR] %s%s\n' "${FMT_BOLD}${FMT_RED}" "$*" "$FMT_RESET" >&2
}

prompt_confirm () {
    while true; do
        read -p "${FMT_YELLOW}$1 (y/n):$FMT_RESET " choice
        case $choice in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) print_error "$choice is not a valid option";;
        esac
    done
}

setup_check() {
  FMT_RED=$(printf '\033[31m')
  FMT_GREEN=$(printf '\033[1;32m')
  FMT_YELLOW=$(printf '\033[1;33m')
  FMT_BLUE=$(printf '\033[1;34m')
  FMT_BOLD=$(printf '\033[1m')
  FMT_RESET=$(printf '\033[0m')

  if ! command_exists curl; then
    print_error "Please install curl before continuing. Follow setup guide for more info."
    exit 1
  elif ! command_exists sed; then
    print_error "Please install sed before continuing. Follow setup guide for more info."
    exit 1
  fi
}

setup_folder() {
  read -p "${FMT_YELLOW}Name your new project folder (e.g. Project2A):$FMT_RESET " PROJECT_DIRNAME
  PARENT_DIR=$(pwd)
  PROJECT_DIR="${PARENT_DIR}/${PROJECT_DIRNAME}"

  print_success "Workspace path: $PROJECT_DIR"

  # Check if directory already exists
  if [ -d "$PROJECT_DIR" ]; then
    print_error "Directory already exists. Please try again."
    exit 1
  fi

  if ! prompt_confirm "Create your new project here?"; then
    print_error "Please run this script from the directory you want new project to be created."
    exit 1
  fi
}

get_scaffold() {
  curl -fsSL "https://github.com/CAENTainer/EECS281-Devcontainer/tarball/main" -o ${TMP_DIR}/scaffold.tar.gz
  if [ $? -ne 0 ]; then
    print_error "Failed to download starter files, please try again."
    exit 1
  fi
  tar -xzf ${TMP_DIR}/scaffold.tar.gz --strip-components=1 -C ${TMP_DIR}

  curl -fsSL "https://gitlab.umich.edu/eecs281/makefile/-/raw/master/Makefile" -o ${TMP_DIR}/Scaffold/Makefile
  if [ $? -ne 0 ]; then
    print_error "Failed to download 281 Makefile template, please try again."
    exit 1
  fi
}

open_project() {
  if command_exists devcontainer; then
    devcontainer open ${PROJECT_DIR}
  elif command_exists code; then
    code ${PROJECT_DIR}
  fi
}

config_workspace() {
  local executable_name
  local project_id
  local uniqname

  read -p "${FMT_YELLOW}Enter the project executable name:$FMT_RESET " executable_name

  read -p "${FMT_YELLOW}Enter the project identifier:$FMT_RESET " project_id
  while [[ ! $project_id =~ ^[A-Z0-9]{40}$ ]]; do
    print_error "Invalid project identifier, please try again."
    read -p "${FMT_YELLOW}Enter the project identifier:$FMT_RESET " project_id
  done

  read -p "${FMT_YELLOW}Enter your uniqname:$FMT_RESET " uniqname
  while [[ ! $uniqname =~ ^[A-Za-z0-9]{3,8}$ ]]; do
    print_error "Invalid uniqname, please try again."
    read -p "${FMT_YELLOW}Enter your uniqname:$FMT_RESET " uniqname
  done
  
  print_info "Applying project info to starter files..."
  # Set up Makefile and launch.json
  local sed_failed=0
  sed -i.bak "s/EXECUTABLE  = executable/EXECUTABLE  = ${executable_name}/g" ${TMP_DIR}/Scaffold/Makefile || sed_failed=1
  sed -i.bak "s/EEC50281EEC50281EEC50281EEC50281EEC50281/${project_id}/g" ${TMP_DIR}/Scaffold/Makefile || sed_failed=1
  sed -i.bak "s/youruniqname/${uniqname}/g" ${TMP_DIR}/Scaffold/Makefile || sed_failed=1

  if [[ ${executable_name} =~ ^test.* ]]; then
    # Special case for P2B unit test
    sed -i.bak "s/make -j debug/make -j ${executable_name}/g" ${TMP_DIR}/Scaffold/.vscode/tasks.json || sed_failed=1
    sed -i.bak "s/EXECUTABLE_debug/${executable_name}/g" ${TMP_DIR}/Scaffold/.vscode/launch.json || sed_failed=1
  else
    sed -i.bak "s/EXECUTABLE_debug/${executable_name}_debug/g" ${TMP_DIR}/Scaffold/.vscode/launch.json || sed_failed=1
  fi
  
  rm -f ${TMP_DIR}/Scaffold/*.bak ${TMP_DIR}/Scaffold/.vscode/*.bak # Have to do .bak thing for BSD sed compatibility

  if [ $sed_failed -eq 1 ]; then
    print_error "Failed to apply project info to starter files, please try again or contact course staff."
    exit 1
  fi

  # @TODO: setup .gitignore
}

main() {
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf -- "$TMP_DIR"' EXIT

  setup_check
  print_info "Welcome to EECS 281 Dev Container Environment Setup Wizard"

  setup_folder

  print_info "Downloading starter files..."
  get_scaffold

  print_info "Configuring workspace..."
  config_workspace

  print_info "Moving files to workspace..."
  mv ${TMP_DIR}/Scaffold ${PROJECT_DIR}

  print_success "Setup complete 🎉 Happy coding!"
  open_project
}

main "$@"