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
sha_256="${2:-}"
namespace="infocenter"
hostname="help.eclipse.org"

# Verify inputs
if [[ -z "${release_name}" ]]; then
  printf "ERROR: a release name must be given.\n"
  exit 1
fi

if [[ -z "${sha_256}" ]]; then
  printf "ERROR: a sha_256 must be given.\n"
  exit 1
fi

create_license_header() {
  local file="${1:-}"
  local year="2021"
  cat <<EOF > "${file}"
#*******************************************************************************
# Copyright (c) ${year} Eclipse Foundation and others.
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License 2.0
# which is available at http://www.eclipse.org/legal/epl-v20.html,
# or the MIT License which is available at https://opensource.org/licenses/MIT.
# SPDX-License-Identifier: EPL-2.0 OR MIT
#*******************************************************************************
EOF
}

create_route () {
  local release_name="${1:-}"
  local namespace_name="${2:-}"
  local host_name="${3:-}"
  local file_name="${release_name}/route.yml"
  create_license_header "${file_name}"
  cat <<EOF >> "${file_name}"
apiVersion: "route.openshift.io/v1"
kind: "Route"
metadata:
  labels:
    infocenter.version: "${release_name}"
  namespace: "${namespace_name}"
  annotations:
    haproxy.router.openshift.io/timeout: 60s
    haproxy.router.openshift.io/rewrite-target: /help
  name: "infocenter-${release_name}"
spec:
  host: "${host_name}"
  path: "/${release_name}"
  port:
    targetPort: "http"
  tls:
    insecureEdgeTerminationPolicy: "Redirect"
    termination: "edge"
  to:
    kind: "Service"
    name: "infocenter-${release_name}"
    weight: 100
EOF
}

create_service () {
  local release_name="${1:-}"
  local namespace_name="${2:-}"
  local file_name="${release_name}/service.yml"
  create_license_header "${file_name}"
  cat <<EOF >> "${file_name}"
apiVersion: "v1"
kind: "Service"
metadata:
  labels:
    infocenter.version: "${release_name}"
  namespace: "${namespace_name}"
  name: "infocenter-${release_name}"
spec:
  ports:
  - name: "http"
    port: 80
    protocol: "TCP"
    targetPort: 8086
  selector:
    infocenter.version: "${release_name}"
EOF
}

create_deployment () {
  local release_name="${1:-}"
  local namespace_name="${2:-}"
  local sha256="${3:-}"
  #local sha256="$(docker inspect --format='{{index .RepoDigests 0}}' "${dockerhub_repo}:${release_name}" | sed -E 's/.*sha256:(.*)/\1/g')"
  local file_name="${release_name}/deployment.yml"
  local dockerhub_repo="eclipsecbi/eclipse-infocenter"
  local infocenter_image="${dockerhub_repo}:${release_name}@sha256:${sha256}"
  echo "Image name: ${infocenter_image}"
  
  create_license_header "${file_name}"
  cat <<EOF >> "${file_name}"
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    infocenter.version: "${release_name}"
  namespace: "${namespace_name}"
  name: "infocenter-${release_name}"
spec:
  replicas: 1
  selector:
    matchLabels:
      infocenter.version: "${release_name}"
  serviceName: "infocenter-${release_name}"
  template:
    metadata:
      name: "infocenter-${release_name}"
      labels:
        infocenter.version: "${release_name}"
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: speed
                operator: NotIn
                values:
                - fast
      terminationGracePeriodSeconds: 180
      containers:
      - name: infocenter-${release_name}
        image: ${infocenter_image}
        imagePullPolicy: IfNotPresent
        command:
          - /infocenter/startDockerInfoCenter.sh
        livenessProbe:
          httpGet:
            path: /help/index.jsp
            port: 8086
            scheme: HTTP
          initialDelaySeconds: 480
          periodSeconds: 60
          failureThreshold: 2
          timeoutSeconds: 90
        readinessProbe:
          httpGet:
            path: /help/index.jsp
            port: 8086
          periodSeconds: 60
          timeoutSeconds: 90
          initialDelaySeconds: 60
        ports:
        - containerPort: 8086
          protocol: TCP
        resources:
          requests:
            cpu: 500m
          limits:
            cpu: 2
            memory: 1.5Gi
        volumeMounts:
        - name: workspace
          mountPath: "/infocenter/workspace"
      volumes:
      - name: workspace
        emptyDir: {}
EOF
}

mkdir -p "${release_name}"
create_route "${release_name}" "${namespace}" "${hostname}"
create_service "${release_name}" "${namespace}"
create_deployment "${release_name}" "${namespace}" "${sha_256}"

