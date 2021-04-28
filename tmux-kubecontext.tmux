#!/usr/bin/env bash

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

init(){
  tmux source-file ${SCRIPT_ROOT}/default.tmux

  # Options for tmux_kubecontext state
  tmux set-option -goq @tmux_kubecontext_status_updated_time 0
  tmux set-option -goq @tmux_kubecontext_status_context "N/A"
  tmux set-option -goq @tmux_kubecontext_status_namespace "N/A"
  tmux set-option -goq @tmux_kubecontext_status_last_kubeconfig ""
  tmux set-option -goq @tmux_kubecontext_status_error ""
}

set_tmux_option(){
  tmux set-option -gq "$1" "$2"
}

get_tmux_option(){
  tmux show-option -gqv $1
}

# getter for user options
get_kubeconfig() {
  get_tmux_option "@tmux_kubecontext_kubeconfig_#{pane_id}-#{session_id}-#{window_id}"
}

get_kubectl_binary() {
  get_tmux_option "@tmux_kubecontext_kubectl_binary"
}

symbol_enabled(){
  local enabled=$(get_tmux_option "@tmux_kubecontext_symbol_enable")
  [[ $enabled == true ]]
} 

get_symbol() {
  get_tmux_option "@tmux_kubecontext_symbol"
}

get_symbol_fg_color() {
  get_tmux_option "@tmux_kubecontext_symbol_fg_color"
}

get_context_fg_color(){
  get_tmux_option "@tmux_kubecontext_context_fg_color"
}

get_separator(){
  get_tmux_option "@tmux_kubecontext_separator"
}

get_separator_fg_color(){
  get_tmux_option "@tmux_kubecontext_separator_fg_color"
}

namespace_enabled(){
  local enabled=$(get_tmux_option "@tmux_kubecontext_namespace_enable")
  [[ $enabled == true ]]
} 

get_namespace_fg_color(){
  get_tmux_option "@tmux_kubecontext_namespace_fg_color"
}

error_enabled(){
  local enabled=$(get_tmux_option "@tmux_kubecontext_error_enable")
  [[ $enabled == true ]]
} 

get_error_prefix(){
  get_tmux_option "@tmux_kubecontext_error_prefix"
}

get_error_fg_color(){
  get_tmux_option "@tmux_kubecontext_error_fg_color"
}

lock_enabled(){
  local enabled=$(get_tmux_option "@tmux_kubecontext_lock_enable")
  [[ $enabled == true ]]
}


# getter and setter for status options
set_status_context(){
  set_tmux_option "@tmux_kubecontext_status_context" "$1"
}

get_status_context(){
  get_tmux_option "@tmux_kubecontext_status_context"
}

set_status_namespace(){
  set_tmux_option "@tmux_kubecontext_status_namespace" "$1"
}

get_status_namespace(){
  get_tmux_option "@tmux_kubecontext_status_namespace"
}

set_status_updated_time(){
  set_tmux_option @tmux_kubecontext_status_updated_time "${1}"
}

get_status_updated_time(){
  get_tmux_option "@tmux_kubecontext_status_updated_time"
}

reset_status_updated_time(){
  set_status_updated_time 0
}

update_status_updated_time_to_now(){
  local updated_time=$(date +%s)
  set_status_updated_time "${updated_time}"
}

set_status_last_kubeconfig(){
  set_tmux_option "@tmux_kubecontext_status_last_kubeconfig" "$1"
}

get_status_last_kubeconfig(){
  get_tmux_option "@tmux_kubecontext_status_last_kubeconfig"
}

get_status_error(){
  get_tmux_option "@tmux_kubecontext_status_error"
}

set_status_error(){
  set_tmux_option "@tmux_kubecontext_status_error" "$1"
}

clear_status_error(){
  set_tmux_option "@tmux_kubecontext_status_error" ""
}

reset_context(){
  set_status_context "N/A"
  set_status_namespace "N/A"
}

try_to_lock(){
  local lockfile
  [[ -z $TMPDIR ]] && TMPDIR=${TMPDIR:-/tmp}
  lockfile=${TMPDIR}/tmux_kubeconfig.lock
  if ln -s /dev/null ${lockfile} >/dev/null 2>&1; then
    trap "rm ${lockfile}" EXIT
    return 0
  fi
  return 1
}

file_order_changed(){
  local files1=${1//:/ } files2=${2//:/ }

  for ((i=0; i<${#files1[@]}; i++)); do
    [[ ${files1[${i}]} != ${files2[${i}]} ]] && return 0
  done

  return 1
}

should_update_context(){
  local stat_cmd
  case $OSTYPE in
    linux*)
      stat_cmd='stat -c %Y'
      ;;
    darwin*)
      stat_cmd='/usr/bin/stat -f %m'
      ;;
    *)
      set_status_error "unsupported platform"
      # Update 'updated_time' to now not to run any more.
      update_status_updated_time_to_now
      return 1
      ;;
  esac

  # Check updated kubeconfig files
  local f files t=0 exitcode=0 found=0 updated=0
  local kubeconfig=$(get_kubeconfig)
  local last_kubeconfig=$(get_status_last_kubeconfig)
  local last_updated_time=$(get_status_updated_time)

  # When KUBECONFIG order is changed, reset status updated time.
  # When order changed, it has possibility that reffered contexts are changed.
  if file_order_changed "${kubeconfig}" "${last_kubeconfig}"; then
    reset_status_updated_time
  fi
  set_status_last_kubeconfig "${kubeconfig}"

  # Check updated kubeconfig exists
  files=(${kubeconfig//:/ })
  ## If not set KUBECONFIG, check ${HOME}/.kube/config.
  [[ ${#files[@]} == 0 ]] && files=(${files[@]} "${HOME}/.kube/config")
  for f in "${files[@]}"; do
    if [[ ! -e "${f}" ]]; then
      set_status_error "\"${f}\" was not found"
      reset_context
      return 1
    fi

    t=$(${stat_cmd} ${f} 2>/dev/null)
    exitcode=$?
    if [[ $exitcode != 0 ]]; then
      set_status_error "stat command was failed"
      return 1
    fi

    if [[ "${t}" -gt "${last_updated_time}" ]]; then
      updated=1
    fi
    found=1
  done

  ## Reset @tmux_kubecontext_status_updated_time to update context immediately,
  ## when kubeconfig files isn't found.
  if [[ $found == 0 ]]; then
    set_status_error "kubeconfig file was not found"
    reset_context
    reset_status_updated_time
    return 1
  fi

  ## If all kubeconfig files didn't be updated, should not update context.
  if [[ $updated == 0 ]]; then
    return 1
  fi

  return 0
}

update_context(){
  # Support KUBECONFIG env
  export KUBECONFIG=$(get_kubeconfig)

  # Confirm kubectl binary is executable
  local kubectl_bin exitcode=0
  kubectl_bin=$(get_kubectl_binary)
  if [[ ! -x "$(command -v ${kubectl_bin})" ]]; then
    set_status_error "executable kubectl command was not found"
    return
  fi

  # Update context
  local context
  context="$(${kubectl_bin} config current-context 2>/dev/null)"
  exitcode=$?
  if [[ -z "${context}" ]] || [[ $exitcode != 0 ]]; then
    set_status_error "failed to get context with kubectl"
    return
  fi
  set_status_context $context

  # Update namespace
  local namespace
  if namespace_enabled; then
    namespace="$(${kubectl_bin} config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)"
    exitcode=$?
    if [[ $exitcode != 0 ]]; then
      set_status_error "failed to get namespace with kubectl"
      return
    fi
    namespace="${namespace:-default}"
    set_status_namespace $namespace
  fi

  # If updated context correctly, update updated_time and clear error.
  update_status_updated_time_to_now
  clear_status_error
}

try_to_update_context() {
  should_update_context && update_context

  if [[ -n $(get_status_error) ]]; then
    reset_status_updated_time
  fi
}

main() {
  init
  if lock_enabled; then
    if try_to_lock; then
      try_to_update_context
    else
      set_status_error "locked file exists!"
    fi
  else
    try_to_update_context
  fi

  local result

  local context=$(get_status_context)
  local namespace=$(get_status_namespace)
  local symbol=$(get_symbol)
  local separator=$(get_separator)
  local error=$(get_status_error)
  local error_prefix=$(get_error_prefix)

  local context_fg_color=$(get_context_fg_color)
  local namespace_fg_color=$(get_namespace_fg_color)
  local symbol_fg_color=$(get_symbol_fg_color)
  local separator_fg_color=$(get_separator_fg_color)
  local error_fg_color=$(get_error_fg_color)

  # Symbol
  if symbol_enabled; then
    if [[ -n ${symbol_fg_color} ]]; then
      result+="#[fg=${symbol_fg_color}]${symbol}#[default]"
    else
      result+="${symbol}"
    fi
    result+=" "
  fi

  # Context
  if [[ -n ${context_fg_color} ]]; then
    result+="#[fg=${context_fg_color}]${context}#[default]"
  else
    result+="${context}"
  fi

  # Separator
  if [[ -n ${separator_fg_color} ]]; then
    result+="#[fg=${separator_fg_color}]${separator}#[default]"
  else
    result+="${separator}"
  fi

  # Namespace
  if namespace_enabled && [[ -n ${namespace} ]]; then
    if [[ -n ${namespace_fg_color} ]]; then
      result+="#[fg=${namespace_fg_color}]${namespace}#[default]"
    else
      result+="${namespace}"
    fi
  fi

  # Error
  if error_enabled && [[ -n ${error} ]]; then
    result+=" "
    if [[ -n ${error_fg_color} ]]; then
      result+="#[fg=${error_fg_color}]${error_prefix}${error}#[default]"
    else
      result+="${error_prefix}${error}"
    fi
  fi

  echo -n "${result}"
}

main
