#!/usr/bin/env bash
set -euoE pipefail

function main() {

    if [[ ${CI_SERVER:-} == "yes" ]]; then

        _assert_variables_set GCP_PROJECT_ID GOOGLE_PLATFORM_CREDENTIALS CLUSTER_REGION CLUSTER_NAME

        echo "${GOOGLE_PLATFORM_CREDENTIALS}" | gcloud auth activate-service-account --key-file -
        trap "gcloud auth revoke --verbosity=error" EXIT

        gcloud config set project "${GCP_PROJECT_ID}"
        gcloud config set compute/region "${CLUSTER_REGION}"
        gcloud config set container/cluster "${CLUSTER_NAME}"
        gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${CLUSTER_REGION}" --project "${GCP_PROJECT_ID}"

    fi

    kubectl apply -f ./rbac/

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
