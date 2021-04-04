#!/usr/bin/env bash
set -euoE pipefail

function main() {

    # these must be set by CI
    _assert_variables_set GCP_PROJECT_ID WEAVE_IMAGE_NAME WEAVE_IMAGE_VERSION

    APP_IMAGE_NAME=eu.gcr.io/"${GCP_PROJECT_ID}"/"${WEAVE_IMAGE_NAME}"
    AGENT_IMAGE_NAME=eu.gcr.io/"${GCP_PROJECT_ID}"/docker.io/"${WEAVE_IMAGE_NAME}"


    if [[ ${CI_SERVER:-} == "yes" ]]; then

        _assert_variables_set GOOGLE_PLATFORM_CREDENTIALS CLUSTER_REGION CLUSTER_NAME

        echo "${GOOGLE_PLATFORM_CREDENTIALS}" | gcloud auth activate-service-account --key-file -
        trap "gcloud auth revoke --verbosity=error" EXIT

        gcloud config set project "${GCP_PROJECT_ID}"
        gcloud config set compute/region "${CLUSTER_REGION}"
        gcloud config set container/cluster "${CLUSTER_NAME}"
        gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${CLUSTER_REGION}" --project "${GCP_PROJECT_ID}"

    fi

    pushd "k8s/" >/dev/null || return

    kustomize edit set image APP_IMAGE_NAME="${APP_IMAGE_NAME}":"${WEAVE_IMAGE_VERSION}"
    kustomize edit set image AGENT_IMAGE_NAME="${AGENT_IMAGE_NAME}":"${WEAVE_IMAGE_VERSION}"
    kustomize build . | kubectl apply -f -
    kubectl rollout status deploy/weave-scope-app -n=weave --timeout=60s
    kubectl rollout status deploy/weave-scope-cluster-agent -n=weave --timeout=60s
    kubectl rollout status daemonset/weave-scope-agent -n=weave --timeout=60s

    popd >/dev/null || return

}


function _assert_variables_set() {
  local error=0
  local varname
  for varname in "$@"; do
    if [[ -z "${!varname-}" ]]; then
      echo "${varname} must be set" >&2
      error=1
    fi
  done
  if [[ ${error} = 1 ]]; then
    exit 1
  fi
}

main
