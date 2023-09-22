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

SCRIPT_FOLDER="$(dirname "$(readlink -f "${0}")")"

# Parameters:
RELEASE_NAME="${1:-}"


if [ "${RELEASE_NAME}" == "" ]; then
  printf "ERROR: a release name must be given.\n"
  exit 1
fi

open_url() {
  local url=$1
  if which xdg-open > /dev/null; then # most Linux
    xdg-open "${url}"
  elif which open > /dev/null; then # macOS
    open "${url}"
  fi
}

open_infocenter_in_browser() {
  local release_name=$1
  local url="https://help.eclipse.org/${release_name}"
  # This might require something like:
  wget -O - --tries=1 --header='X-Cache-Bypass: true' "${url}" > /dev/null
  # Update banner specifically
  wget -O - --tries=1 --header='X-Cache-Bypass: true' "${url}/topic/org.foundation.helpbanner2/banner.html" > /dev/null

  # open url in browser
  open_url "${url}"
}

yes_skip_exit() {
  echo
  read -rp "Do you want to $1? (Y)es, (S)kip, E(x)it: " yn
  shift
  case $yn in
    [Yy]* ) "${@}";;
    [Ss]* ) echo "Skipping...";;
    [Xx]* ) exit;;
        * ) echo "Please answer (Y)es, (S)kip, E(x)it";;
  esac
}

config_create_infocenter_job() {
  echo
  echo "Add the latest p2_repo_dir to the Choice Parameter in https://ci.eclipse.org/simrel/job/simrel.create_and_publish_infocenter_pipeline job..."
  echo "  - Dir can be found here: https://download.eclipse.org/releases/${RELEASE_NAME} (e.g. releases/2022-03/202203161000)"
  open_url "https://github.com/eclipse-simrel/help.eclipse.org/blob/main/Jenkinsfile#L15"
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

run_create_infocenter_job() {
  echo
  echo "Run https://ci.eclipse.org/simrel/job/simrel.create_and_publish_infocenter_pipeline to package and deploy a new infocenter... "
  open_url "https://ci.eclipse.org/simrel/job/simrel.create_and_publish_infocenter_pipeline/build?delay=0sec"
#TODO: set the parameters via URL
  echo "  - set the release_name parameter (${RELEASE_NAME})"
  echo "  - make sure that use_latest_platform is enabled (unless you know exactly what you are doing)"
  echo "  - select latest p2_repo_dir"
  echo "  - wait for the build to finish"
#TODO: set build description automatically
  echo "  - set build description (e.g. '${RELEASE_NAME} with 4.xx platform')"
  echo "  - copy <sha256> (without the sha256: prefix) from the last lines in the console log"
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

create_and_deploy_infocenter() {
  echo
  echo "Create infocenter YAML and deploy it on the cluster..."

  pushd "${SCRIPT_FOLDER}/k8s"
  # skip creation if it exists already
  if [[ -d "${RELEASE_NAME}" ]]; then
    echo "Directory ${RELEASE_NAME} already exists, skipping creation..."
  else
    # create info center
    read -rp "    sha256: " sha_256
#TODO: remove the "sha256:" prefix automatically
    echo "Creating yaml file..."
    ./createInfoCenter_yaml.sh "${RELEASE_NAME}" "${sha_256}"
  fi

  # deploy info center
  echo "Deploying infocenter ${RELEASE_NAME}..."
  ./deployInfoCenter.sh "${RELEASE_NAME}"

  echo "Check that infocenter container is running on the cluster (wait for it ~2min20sec)..."
  kubectl rollout status -n "infocenter" "deployment/infocenter-${RELEASE_NAME}"
  oc get pods -n infocenter
  read -p "Press enter to continue or CTRL-C to stop the script"
  popd
}

shutdown_oldest_infocenter() {
  echo
  echo "Shutdown oldest infocenter on the cluster and remove the folder in the repo..."
  pushd k8s
  #TODO: find oldest release directory automatically
  read -rp "Oldest release name: " oldest_release_name

  #TODO: check that ${oldest_release_name} exists
  if [[ ! -d "${oldest_release_name}" ]]; then
    echo "ERROR: ${oldest_release_name} does not exist. Skipping..."
  else
    echo "Removing info center ${oldest_release_name}..."
    ./removeInfoCenter.sh "${oldest_release_name}"
    #- remove the oldest directory
    git add "${oldest_release_name}"
  fi
  popd
}

commit_changes() {
  echo
  echo "Commit the changes in k8s folder..."
  #- new directory for the latest release (e.g. 2019-12)
  git add k8s/"${RELEASE_NAME}"

#TODO: add instructions for updating the second to latest infocenter
  echo
  git status
  echo
  echo "Please double-check the staged files and commit them with a commit message (e.g. 'Add infocenter ${RELEASE_NAME}, remove oldest infocenter') ..."
#TODO: add commit message
#TODO: confirm before comitting
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

adapt_nginx() {
  echo
  echo "Adapt nginx config in puppet..."
  #Adapt nginx config in puppet (ssh://<username>@foundation.eclipse.org:29418/puppet/modules):
  #/modules/nginx/files/etc/nginx/conf.d/help.eclipse.org.common
  echo "  - add new location to /modules/nginx/files/etc/nginx/conf.d/help.eclipse.org.common:"
  echo
  echo "    #eclipse 4.xx (${RELEASE_NAME})"
  echo "    location /${RELEASE_NAME} {"
  echo "      rewrite ^/${RELEASE_NAME}/?\$ /${RELEASE_NAME}/index.jsp permanent;"
  echo "      proxy_pass https://okd-ingress-tls\$request_uri;"
  echo "    }"
  echo
  echo "  - add redirection from oldest location to /latest"
  echo "    - e.g. rewrite ^/2020-03(.*)\$ https://help.eclipse.org/latest\$1 permanent;"
  echo "  - remove oldest location"
  echo "  - commit changes"
  echo "    - commit message: \"Update infocenters\""
  #Commit the change and wait for nginx to reload (=> manually reload nginx for now!)
  echo "  - run puppet"
  echo "  - reload nginx manually"
  #TODO: or use expect script? security issues?
  #ssh outage4@nginx1
  #su -
  #/usr/bin/puppet  agent --server puppet.eclipse.org --no-daemonize -o -d -l /dev/stdout
  #cat /etc/nginx/conf.d/help.eclipse.org.common
  #nginx -t
  #systemctl reload nginx
  read -p "Press enter to continue or CTRL-C to stop the script"
}

check_after_deployment(){
  echo
  echo "Check that the new infocenter works after the deployment..."
  open_infocenter_in_browser "${RELEASE_NAME}"
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

update_latest_redirection(){
  echo
#TODO: extract that and do it only on release day?
  echo "Update k8s/route_latest.yml to point to the latest info center..."
  #- update route
  route_latest_file="k8s/route_latest.yml"
  sed -i -E "s/infocenter-[0-9]{4}-[0-9]{2}/infocenter-${RELEASE_NAME}/" "${route_latest_file}"
  cat "${route_latest_file}"
  #- Deploy the route
  oc apply -f "${route_latest_file}"
  echo "Sleep for 20 seconds..."
  sleep 20
  echo "Check that https://help.eclipse.org/latest shows the latest version..."
  open_infocenter_in_browser "latest"
  echo "TODO:"
  git add "k8s/route_latest.yml"
  echo "- Commit k8s/route_latest.yml"
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

update_check_infocenter_job(){
  echo
  echo "Add new info center to the shell script in this job (and remove oldest):"
  echo "=> https://ci.eclipse.org/simrel/job/simrel.check_infocenter"
  open_url "https://ci.eclipse.org/simrel/job/simrel.check_infocenter/configure"
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

echo "Create infocenter for release ${RELEASE_NAME}:"
echo "======================================"

yes_skip_exit "configure the simrel.create_infocenter job" config_create_infocenter_job

yes_skip_exit "run the simrel.create_infocenter job" run_create_infocenter_job

yes_skip_exit "create and deploy the new infocenter" create_and_deploy_infocenter

yes_skip_exit "shutdown the oldest infocenter" shutdown_oldest_infocenter

yes_skip_exit "commit the changes" commit_changes

yes_skip_exit "adapt the nginx configuration" adapt_nginx

yes_skip_exit "check infocenter after deployment" check_after_deployment

yes_skip_exit "update the latest redirection" update_latest_redirection

yes_skip_exit "update simrel.check_infocenter job" update_check_infocenter_job

echo "Done."