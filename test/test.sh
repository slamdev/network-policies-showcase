set -o errexit
set -o nounset
set -o pipefail

#
# Verify pod can is reachable without network policy attached
#
# $1 - path to kubeconfig file
# $2 - path to working dir
function should_access_pod_without_network_policy() {
  echo "--- running should_access_pod_without_network_policy test ---"
  local kubeconfig_file=$1
  local working_dir=$2

  local ns
  ns=$(openssl rand -hex 3)

  kubectl --kubeconfig "${kubeconfig_file}" create ns "${ns}"
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" apply -f "${working_dir}/service.yaml"
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" rollout status deploy/np-service

  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" apply -f "${working_dir}/untrusted-client.yaml"
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" wait --for=condition=complete --timeout=30s job/np-untrusted-client
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" get pod -lapp=np-untrusted-client

  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" apply -f "${working_dir}/trusted-client.yaml"
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" wait --for=condition=complete --timeout=30s job/np-trusted-client
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" get pod -lapp=np-trusted-client
}

#
# Verify pod can is not reachable with network policy attached
#
# $1 - path to kubeconfig file
# $2 - path to working dir
function should_not_access_pod_with_network_policy() {
  echo "--- running should_not_access_pod_with_network_policy test ---"
  local kubeconfig_file=$1
  local working_dir=$2

  local ns
  ns=$(openssl rand -hex 3)

  kubectl --kubeconfig "${kubeconfig_file}" create ns "${ns}"
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" apply -f "${working_dir}/service.yaml"
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" rollout status deploy/np-service

  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" apply -f "${working_dir}/network-policy.yaml"

  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" apply -f "${working_dir}/untrusted-client.yaml"
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" wait --for=condition=failed --timeout=30s job/np-untrusted-client
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" get pod -lapp=np-untrusted-client

  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" apply -f "${working_dir}/trusted-client.yaml"
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" wait --for=condition=complete --timeout=30s job/np-trusted-client
  kubectl --kubeconfig "${kubeconfig_file}" -n "${ns}" get pod -lapp=np-trusted-client
}

SWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "${SWD}/setup.sh"

KUBECONFIG=$(create_temp_cluster "${SWD}/kind-config.yaml")
trap "delete_temp_cluster ${KUBECONFIG}" EXIT

# install calico because kindnetd doesn't support network policies
# https://github.com/kubernetes-sigs/kind/issues/842
kubectl --kubeconfig "${KUBECONFIG}" apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml >/dev/null

should_access_pod_without_network_policy "${KUBECONFIG}" "${SWD}/../"
should_not_access_pod_with_network_policy "${KUBECONFIG}" "${SWD}/../"
