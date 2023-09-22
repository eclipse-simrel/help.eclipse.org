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
sha256="${2:-}"

# Verify inputs
if [[ -z "${release_name}" ]]; then
  printf "ERROR: a release name must be given.\n"
  exit 1
fi

if [[ -z "${sha256}" ]]; then
  printf "ERROR: a sha256 must be given.\n"
  exit 1
fi

pushd k8s/
./createInfoCenter_yaml.sh "${release_name}" "${sha256}"
./deployInfoCenter.sh "${release_name}"
popd

#TODO: actually check when pods are online
# oc get pods -n infocenter | grep "infocenter-${release_name}"
echo "Wait for pods to start..."
sleep 30
oc get pods -n infocenter

#TODO: do you want to remove the oldest infocenter?
oldest_release_name=""
oc delete deployment "infocenter-${oldest_release_name}" -n infocenter
oc delete service "infocenter-${oldest_release_name}" -n infocenter
oc delete route "infocenter-${oldest_release_name}" -n infocenter
