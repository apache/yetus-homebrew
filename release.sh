#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SHELLDOC-IGNORE

USER_NAME=${SUDO_USER:=$USER}
USER_ID=$(id -u "${USER_NAME}")
GPG=$(command -v gpg)
GPGAGENT=$(command -v gpg-agent)
LOGDIR="/tmp/homebrew-sign.$$"
mkdir -p "${LOGDIR}"

usage() {
  cat <<EOF
$0 YETUS-xxx 0.0.0
EOF
  exit 1
}

cleanup() {
  git checkout --force main
  stopgpgagent
  rm -rf "${LOGDIR}"
  exit 1
}

verifyparams() {

  if [[ $# -ne 2 ]]; then
    usage
  fi

  JIRAISSUE=$1
  VERSION=$2

  if [[ ! "${JIRAISSUE}" =~ YETUS- ]]; then
      echo "ERROR: Bad JIRA issue format."
      usage
  fi
}

startgpgagent()
{
    if [[ -n "${GPGAGENT}" && -z "${GPG_AGENT_INFO}" ]]; then
      echo "starting gpg agent"
      echo "default-cache-ttl 36000" > "${LOGDIR}/gpgagent.conf"
      echo "max-cache-ttl 36000" >> "${LOGDIR}/gpgagent.conf"
      # shellcheck disable=2046
      eval $("${GPGAGENT}" --daemon \
        --options "${LOGDIR}/gpgagent.conf" \
        --log-file="${LOGDIR}/create-release-gpgagent.log")
      GPGAGENTPID=$(pgrep "${GPGAGENT}")
      GPG_AGENT_INFO="$HOME/.gnupg/S.gpg-agent:$GPGAGENTPID:1"
      export GPG_AGENT_INFO
    fi

    if [[ -n "${GPG_AGENT_INFO}" ]]; then
      echo "Warming the gpg-agent cache prior to calling maven"
      # warm the agent's cache:
      touch "${LOGDIR}/warm"
      "${GPG}" --use-agent --armor --output "${LOGDIR}/warm.asc" --detach-sig "${LOGDIR}/warm"
      rm "${LOGDIR}/warm.asc" "${LOGDIR}/warm"
    else
      yetus_error "ERROR: Unable to launch or acquire gpg-agent. Disable signing."
    fi
}

stopgpgagent()
{
  if [[ -n "${GPGAGENTPID}" ]]; then
    kill "${GPGAGENTPID}"
  fi
}

verifyparams "$@"

trap cleanup INT QUIT TRAP ABRT BUS SEGV TERM ERR

startgpgagent

set -x

git clean -xdf
git checkout --force main
git fetch origin
git rebase origin/main

docker run -i --rm \
  -v "${PWD}:/src" \
  -u "${USER_ID}" \
  -w /src \
  "ghcr.io/apache/yetus:${VERSION}" \
    ./update-homebrew.sh "${VERSION}"

git commit -a -S -m "${JIRAISSUE}. Release ${VERSION}"

stopgpgagent
rm -rf "${LOGDIR}"