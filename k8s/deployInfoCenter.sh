#!/usr/bin/env bash

#*******************************************************************************
# Copyright (c) 2019 Eclipse Foundation and others.
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

# Parameters:
release_name="${1:-}"

# Verify inputs
if [[ -z "${release_name}" ]]; then
  printf "ERROR: a release name must be given.\n"
  exit 1
fi

oc apply -f "${release_name}/route.yml"
oc apply -f "${release_name}/service.yml"
oc apply -f "${release_name}/deployment.yml"
