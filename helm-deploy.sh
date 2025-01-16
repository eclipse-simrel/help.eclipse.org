#!/usr/bin/env bash

#*******************************************************************************
# Copyright (c) 2024 Eclipse Foundation and others.
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License 2.0
# which is available at http://www.eclipse.org/legal/epl-v20.html
# SPDX-License-Identifier: EPL-2.0
#*******************************************************************************

# Bash strict-mode
set -o errexit
set -o nounset
set -o pipefail

IFS=$'\n\t'
SCRIPT_FOLDER="$(dirname "$(readlink -f "${0}")")"
ROOT_DIR="${SCRIPT_FOLDER}"

chart_name="infocenter"
namespace="infocenter"

release_name="${1:-}"
image_tag="${2:-}" #optional

# check that release_name is not empty
if [[ -z "${release_name}" ]]; then
  printf "ERROR: a release_name (e.g. '2024-12') must be given.\n"
  exit 1
fi

values_file="${ROOT_DIR}/charts/${chart_name}/values-${release_name}.yaml"

if helm list -n "${namespace}" | grep "${release_name}" > /dev/null; then
  echo "Found installed Helm chart for release name '${release_name}'. Upgrading..."
  action="upgrade"
else
  echo "Found no installed Helm chart for release name '${release_name}'. Installing..."
  action="install"
fi

if [[ -z "${image_tag}" ]]; then
 helm "${action}" "${release_name}" "${ROOT_DIR}/charts/${chart_name}" -f "${values_file}" --namespace "${namespace}"
else
 helm "${action}" "${release_name}" "${ROOT_DIR}/charts/${chart_name}" -f "${values_file}" --set image.tag="${image_tag}" --namespace "${namespace}"
fi
