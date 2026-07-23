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
#shellcheck disable=SC1091
source "${SCRIPT_FOLDER}/utils/common.sh"

JIRO_ROOT_DIR="$("${SCRIPT_FOLDER}/utils/local_config.sh" "get_var" "jiro-root-dir")"
JENKINS_USER="$("${SCRIPT_FOLDER}/utils/local_config.sh" "get_var" "user" "jenkins_login")"
JENKINS_PW="$("${SCRIPT_FOLDER}/utils/local_config.sh" "get_var" "pw" "jenkins_login")"
INFOCENTER_JENKINS_JOB="simrel.create_and_publish_infocenter_pipeline"
NAMESPACE="infocenter"


# Parameters:
RELEASE_NAME="${1:-}"


if [ "${RELEASE_NAME}" == "" ]; then
  printf "ERROR: a release name must be given.\n"
  exit 1
fi

open_infocenter_in_browser() {
  local release_name="${1:-}"
  local url="https://help.eclipse.org/${release_name}"
  # This might require something like:
  wget -O - --tries=1 --header='X-Cache-Bypass: true' "${url}" > /dev/null
  # Update banner specifically
  wget -O - --tries=1 --header='X-Cache-Bypass: true' "${url}/topic/org.foundation.helpbanner2/banner.html" > /dev/null

  # open url in browser
  _open_url "${url}"
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

run_create_infocenter_job() {
  local past_release="${1:-'false'}"
  echo
  echo "Fetching the latest p2_repo_dir from https://download.eclipse.org/releases/${RELEASE_NAME}"
  release_list="$(ssh projects-storage ls -d /home/data/httpd/download.eclipse.org/releases/${RELEASE_NAME}/*/)"
  #echo "${release_list}"
  local release="$(echo "${release_list}" | tail -n 1)"
  release="${release#/home/*org}" #TODO: improve
  echo "Found release: ${release}"
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
  echo
  echo "Running https://ci.eclipse.org/simrel/job/simrel.create_and_publish_infocenter_pipeline to package and deploy a new infocenter... "
  pushd "${JIRO_ROOT_DIR}" > /dev/null
  echo "  - waiting for the build to finish"
  #TODO: simplify
  if [[ "${past_release}" == "true" ]]; then
    ./jenkins-cli.sh instances/technology.simrel build "${INFOCENTER_JENKINS_JOB}" -p release_name="${RELEASE_NAME}" -p p2_repo_dir="${release}" -p past_release="true" -s
  else
    ./jenkins-cli.sh instances/technology.simrel build "${INFOCENTER_JENKINS_JOB}" -p release_name="${RELEASE_NAME}" -p p2_repo_dir="${release}" -s
  fi
  #TODO: deal with failing build gracefully
  #_open_url "https://ci.eclipse.org/simrel/job/simrel.create_and_publish_infocenter_pipeline/build?delay=0sec"
  #echo "  - set the release_name parameter (${RELEASE_NAME})"
  #echo "  - make sure that use_latest_platform is enabled (unless you know exactly what you are doing)"
  #echo "  - select latest p2_repo_dir"
  echo "  - setting build description (e.g. '${RELEASE_NAME} with 4.xx platform')"
  # get latest build number
  LATEST_JOB_NUMBER="$(curl -sSL --user "${JENKINS_USER}:${JENKINS_PW}" "https://ci.eclipse.org/simrel/job/${INFOCENTER_JENKINS_JOB}/api/json/" | jq '.lastBuild.number')"
  echo "Found latest job number: ${LATEST_JOB_NUMBER}"
  read -p "Press enter to continue or CTRL-C to stop the script"
  # get platform version
  #TODO: derive platform version automatically
  read -rp "    Platform version (e.g. 4.37): " PLATFORM_VERSION
  ./jenkins-cli.sh instances/technology.simrel set-build-description "${INFOCENTER_JENKINS_JOB}" "${LATEST_JOB_NUMBER}" "${RELEASE_NAME} with ${PLATFORM_VERSION} platform"
  echo "  - copying <sha256> (without the sha256: prefix) from the last lines in the console log"
  SHA_256="$(./jenkins-cli.sh instances/technology.simrel console "${INFOCENTER_JENKINS_JOB}" "${LATEST_JOB_NUMBER}" -n 50 | grep '2026-06@sha256' | head -n 1 | sed 's/.*sha256://g' | sed 's/ size:.*//g')"
  echo "Found SHA256: ${SHA_256}"
  popd > /dev/null
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

create_infocenter() {
  echo
  echo "Creating Infocenter Helm chart..."
  local values_file="values-${RELEASE_NAME}.yaml"

  pushd "${SCRIPT_FOLDER}/charts/infocenter" > /dev/null
  # skip creation if it exists already
  #TODO: always create fresh to update SHA256
  if [[ -f "${values_file}" ]]; then
    echo "${values_file} already exists, skipping creation..."
  else
    if [[ -z "${SHA_256}" ]]; then
      echo "${SHA_256} is empty! Please set it manually:"
      # create info center
      read -rp "    sha256: " SHA_256
      #TODO: remove the "sha256:" prefix automatically
    fi
    echo "Creating values file..."
    cat <<EOF >> "${values_file}"
# Default values for infocenter.
namespace: ${NAMESPACE}
infocenterVersion: ${RELEASE_NAME}
replicaCount: 1

image:
  repository: eclipsecbi/eclipse-infocenter
  pullPolicy: IfNotPresent
  tag: "${RELEASE_NAME}@sha256:${SHA_256}"

service:
  type: ClusterIP
  port: 80
  targetPort: 8086

route:
  host: help.eclipse.org

affinity: {}
EOF
  fi
  popd > /dev/null
}

deploy_infocenter() {
  # deploy info center
  echo "Deploying infocenter ${RELEASE_NAME}..."

  if helm list -n "${NAMESPACE}" | grep "${RELEASE_NAME}" > /dev/null; then
    echo "Found installed Helm chart for release name '${RELEASE_NAME}'. Upgrading..."
    action="upgrade"
  else
    echo "Found no installed Helm chart for release name '${RELEASE_NAME}'. Installing..."
    action="install"
  fi

  echo "helm ${action} -f charts/infocenter/values-${RELEASE_NAME}.yaml ${RELEASE_NAME} charts/infocenter --namespace ${NAMESPACE}"
  read -p "Press enter to continue or CTRL-C to stop the script"
  #TODO: make sure that you are connected to the cluster
  helm "${action}" -f "charts/infocenter/values-${RELEASE_NAME}.yaml" "${RELEASE_NAME}" "charts/infocenter" --namespace "${NAMESPACE}"

  echo "Check that infocenter container is running on the cluster (wait for it ~2min20sec)..."
  kubectl rollout status -n "${NAMESPACE}" "deployment/infocenter-${RELEASE_NAME}"
  oc get pods -n "${NAMESPACE}"
  read -p "Press enter to continue or CTRL-C to stop the script"
}

shutdown_oldest_infocenter() {
  echo
  echo "Shutdown oldest infocenter on the cluster and remove the helm chart values file..."
  #TODO: find oldest release directory automatically
  read -rp "Oldest release name: " oldest_release_name

  if [[ ! -f "charts/infocenter/values-${oldest_release_name}.yaml" ]]; then
    echo "ERROR: values-${oldest_release_name}.yaml does not exist. Skipping..."
  else
    echo "Removing info center ${oldest_release_name}..."
    helm uninstall "${oldest_release_name}" --namespace "${NAMESPACE}" || true
    git rm "charts/infocenter/values-${oldest_release_name}.yaml"
  fi
}

commit_changes() {
  echo
  echo "Committing the changes..."
  #- new directory for the latest release (e.g. 2019-12)
  git add "charts/infocenter/values-${RELEASE_NAME}.yaml"
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
  echo "    #eclipse ${PLATFORM_VERSION} (${RELEASE_NAME})"
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
  _open_url "https://ci.eclipse.org/simrel/job/simrel.check_infocenter/configure"
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

update_former_latest(){
  #TODO: calculate former latest release name automatically
  read -rp "Set former latest release name: " RELEASE_NAME
  run_create_infocenter_job true
  # modify YAML file
  yq -i e '.image.tag |= "'"${RELEASE_NAME}@sha256:${SHA_256}"'"' "charts/infocenter/values-${RELEASE_NAME}.yaml"
  # deploy infocenter
  deploy_infocenter
  # double check
  echo "Check that the infocenter works after the deployment..."
  open_infocenter_in_browser "${RELEASE_NAME}"
  # commit and push changes
  echo "TODO:"
  git add "charts/infocenter/values-${RELEASE_NAME}.yaml"
  echo "- Commit charts/infocenter/values-${RELEASE_NAME}.yaml"
  #TODO: automate git commit
  echo
  read -p "Press enter to continue or CTRL-C to stop the script"
}

echo "Create infocenter for release ${RELEASE_NAME}:"
echo "======================================"

yes_skip_exit "run the simrel.create_infocenter job" run_create_infocenter_job

yes_skip_exit "create the new infocenter" create_infocenter

yes_skip_exit "deploy the new infocenter" deploy_infocenter

yes_skip_exit "shutdown the oldest infocenter" shutdown_oldest_infocenter

yes_skip_exit "commit the changes" commit_changes

yes_skip_exit "adapt the nginx configuration" adapt_nginx

yes_skip_exit "check infocenter after deployment" check_after_deployment

yes_skip_exit "update the latest redirection" update_latest_redirection

yes_skip_exit "update simrel.check_infocenter job" update_check_infocenter_job

yes_skip_exit "update former latest infocenter banner to state 'Past release'" update_former_latest

echo "Done."