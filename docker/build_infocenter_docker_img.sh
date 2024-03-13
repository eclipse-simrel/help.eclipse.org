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

source_url="https://github.com/eclipse-simrel/help.eclipse.org/blob/main/docker/Dockerfile"
date="$(date +%FT%T%:z)"
git_tag="$(git rev-parse HEAD)"

# Parameters:
release_name=${1:-}
dockerhub_repo=eclipsecbi/eclipse-infocenter

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

docker build --build-arg "CREATED=${date}" --build-arg "SOURCE=${source_url}" --build-arg "VERSION=${git_tag}" -t ${dockerhub_repo}:${release_name} .
docker push ${dockerhub_repo}:${release_name}
rm -rf ${tmp_dir}