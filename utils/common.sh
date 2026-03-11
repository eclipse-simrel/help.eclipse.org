#!/usr/bin/env bash
#*******************************************************************************
# Copyright (c) 2021 Eclipse Foundation and others.
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License 2.0
# which is available at http://www.eclipse.org/legal/epl-v20.html,
# or the MIT License which is available at https://opensource.org/licenses/MIT.
# SPDX-License-Identifier: EPL-2.0 OR MIT
#*******************************************************************************

# Bash strict-mode
set -o errexit
set -o nounset
set -o pipefail

IFS=$'\n\t'

#TODO: can actions be called that are defined in the script that is sourcing the common.sh script? => YES
_question_action() {
  local message="${1:-}"
  local action="${2:-}"
  read -rp "Do you want to ${message}? (Y)es, (N)o, E(x)it: " yn
  case $yn in
    [Yy]* ) ${action};;
    [Nn]* ) return ;;
    [Xx]* ) exit 0;;
        * ) echo "Please answer (Y)es, (N)o, E(x)it"; _question_action "${message}" "${action}";
  esac
}

#TODO: add E(x)it condition ( => exit 0) that works reliably also in a subshell
_question_true_false() {
  local message="${1:-}"
  read -rp "Do you want to ${message}? (Y)es, (N)o: " yn
  case $yn in
    [Yy]* ) return 0 ;;
    [Nn]* ) return 1 ;;
        * ) echo "Please answer (Y)es, (N)o"; _question_true_false "${message}";
  esac
}

_check_parameter() {
  local param_name="${1:-}"
  local param="${2:-}"
  # check that parameter is not empty
  if [[ -z "${param}" ]]; then
    printf "ERROR: a %s must be given.\n" "${param_name}"
    exit 1
  fi
}

_open_url() {
  local url="${1:-}"
  if which xdg-open > /dev/null; then # most Linux
    xdg-open "${url}"
  elif which open > /dev/null; then # macOS
    open "${url}"
  fi
}

# Generates a password that can be safely used in shells by excluding
# certain special characters that are treated specially by a shell.
#   param 1: the requested length of the password, by default 64
_generate_shell_safe_password() {
  local length="${1:-64}"
  # exclude the following special chars:
  # ', ", !, `, ~, \ are filtered out as they are treated specially by shells
  # '<', '>' and '&' need to be filtered out, since jenkins credentials have issues with those characters
  local pwgen_special="'"'"&!$`~\<>{}[]%;'
  pwgen -1 -s -r $pwgen_special -y $length
}
