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

usage() {
  cat <<EOF
$0 YETUS-xxx 0.0.0
EOF
  exit 1
}

cleanup() {
  git checkout --force main
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

verifyparams "$@"

trap cleanup INT QUIT TRAP ABRT BUS SEGV TERM ERR

set -x

git clean -xdf
git checkout --force main
git fetch origin
git rebase origin/main

docker run -i --rm \
  -v "${PWD}:/src" \
  -u "${USER_ID}" \
  "apache/yetus:main" \
    ./update-homebrew.sh "${VERSION}"

git commit -a -S -m "${JIRAISSUE}. Release ${VERSION}"
