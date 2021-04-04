#!/usr/bin/env bash
set -euoE pipefail

# APP   = rebuilt upstream to run as non-root
# AGENT = just re-tag of the upstream image

function main() {

    _assert_variables_set WEAVE_IMAGE_NAME WEAVE_IMAGE_VERSION

    UPSTREAM_AGENT_IMAGE=docker.io/"${WEAVE_IMAGE_NAME}"
    APP_IMAGE_NAME=eu.gcr.io/"${GCP_PROJECT_ID}"/"${WEAVE_IMAGE_NAME}"
    AGENT_IMAGE_NAME=eu.gcr.io/"${GCP_PROJECT_ID}"/docker.io/"${WEAVE_IMAGE_NAME}"

    if [[ ${CI_SERVER:-} == "yes" ]]; then
        _assert_variables_set GOOGLE_PLATFORM_CREDENTIALS
        echo "${GOOGLE_PLATFORM_CREDENTIALS}" | gcloud auth activate-service-account --key-file -
        trap "gcloud auth revoke --verbosity=error" EXIT
        gcloud auth configure-docker --quiet
    fi

    # build non-root version and push
    docker build -t "${APP_IMAGE_NAME}":"${WEAVE_IMAGE_VERSION}" --build-arg VERSION=${WEAVE_IMAGE_VERSION} .
    docker push "${APP_IMAGE_NAME}":"${WEAVE_IMAGE_VERSION}"

    # re-tag upstream so in our registry
    docker pull "${UPSTREAM_AGENT_IMAGE}":"${WEAVE_IMAGE_VERSION}"
    docker tag  "${UPSTREAM_AGENT_IMAGE}":"${WEAVE_IMAGE_VERSION}" "${AGENT_IMAGE_NAME}":"${WEAVE_IMAGE_VERSION}"
    docker push "${AGENT_IMAGE_NAME}":"${WEAVE_IMAGE_VERSION}"

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
