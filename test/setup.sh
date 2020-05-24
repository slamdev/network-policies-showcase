#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly CLUSTER_NAME=testing

#
# Create temp cluster and return path to its kubeconfig file
#
# $1 - path to cluster definition file
function create_temp_cluster() {
  local def_file=$1

  local kind_version=v0.8.1
  local kube_version=v1.17.5

  local temp_dir
  temp_dir=$(mktemp -d)

  wget -nc -q -O "${temp_dir}/kind" "https://github.com/kubernetes-sigs/kind/releases/download/${kind_version}/kind-$(uname)-amd64"
  chmod +x "${temp_dir}/kind"

  "${temp_dir}/kind" create cluster --name "${CLUSTER_NAME}" --config "${def_file}" --image "kindest/node:$kube_version" --kubeconfig "${temp_dir}/kubecfg.yaml" >/dev/null

  echo "${temp_dir}/kubecfg.yaml"
}

#
# Delete temp cluster
#
# $1 - path to kubeconfig file
function delete_temp_cluster() {
  local kubeconfig_file=$1

  local cluster_dir
  cluster_dir=$(dirname "${kubeconfig_file}")

  "${cluster_dir}/kind" export logs --name "${CLUSTER_NAME}"
  "${cluster_dir}/kind" delete cluster --name "${CLUSTER_NAME}"
}
