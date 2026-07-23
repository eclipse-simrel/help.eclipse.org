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

IFS=$'\n\t'
SCRIPT_FOLDER="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

BUILDKIT_URL="tcp://buildkitd.foundation-internal-infra-buildkitd:1234"

SOURCE_URL="https://github.com/eclipse-simrel/help.eclipse.org/blob/main/docker/Dockerfile"
DATE="$(date +%FT%T%:z)"
GIT_TAG="$(git rev-parse HEAD)"
DOCKERHUB_REPO=eclipsecbi/eclipse-infocenter

# Parameters:
release_name=${1:-}

# Verify inputs
if [[ -z "${release_name}" && $# -lt 1 ]]; then
  printf "ERROR: a release name must be given.\n"
  exit 1
fi

#workaround
tmp_dir=tmp
mkdir -p ${tmp_dir}
tar xzf info-center-${release_name}-*.tar.gz --strip-components=2 -C ${tmp_dir}
rm ${tmp_dir}/*InfoCenter.sh
cat <<EOF > ${tmp_dir}/startDockerInfoCenter.sh
#!/usr/bin/env bash
./eclipse -nosplash -application org.eclipse.help.base.infocenterApplication -nl en -locales en -data workspace -plugincustomization plugin_customization.ini -vmargs -Xmx1024m -Dserver_port=8086
EOF

echo "INFO: Building docker image remotely..."

builder="remote-okd"

docker buildx ls

echo "FOO"
# only create builder if it does not exist yet
if ! docker buildx ls | grep "^${builder}" > /dev/null; then
  docker buildx create --name "${builder}" --driver remote "${BUILDKIT_URL}"
fi

echo "BAR"

#NOTE: this call always pushes the image
DOCKER_BUILDKIT=1 docker buildx build \
  --builder "${builder}" \
  --build-arg "CREATED=${DATE}" --build-arg "SOURCE=${SOURCE_URL}" --build-arg "VERSION=${GIT_TAG}" \
  --no-cache \
  -t "${DOCKERHUB_REPO}:${release_name}" \
  --push .

rm -rf ${tmp_dir}