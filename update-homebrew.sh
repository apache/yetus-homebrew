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

this="${BASH_SOURCE-$0}"
thisdir=$(cd -P -- "$(dirname -- "${this}")" >/dev/null && pwd -P)

pushd "${thisdir}" >/dev/null || exit 1


if [[ ! -d Formula ]]; then
  echo "ERROR: Confused about directory structure."
  exit 1
fi

VERSION=$1

if [[ -z "${VERSION}" ]]; then
  echo "ERROR: need a version"
  exit 1
fi

newfile=/tmp/versionsedit.$$

sed -E -i "s,[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+,${VERSION},g" Formula/yetus.rb

URL=$(awk '/url/ {print $NF}' Formula/yetus.rb)
URL=${URL//\"/}

curl --location --fail --output "/tmp/yetus-binary.tgz" "${URL}"


if ! tar tzf /tmp/yetus-binary.tgz >/dev/null; then
  echo "ERROR: Failed to download a tgz file from ${URL}"
  exit 1
fi

SHA256=$(sha256sum /tmp/yetus-binary.tgz)
SHA256=${SHA256%% *}

rm /tmp/yetus-binary.tgz

echo "Got SHA256: ${SHA256}"

## NOTE: $REPLY, the default for read, is used
## here because it will maintain any leading spaces!
## if read is given a variable, then IFS manipulation
## will be required!

while read -r; do
  if [[ "${REPLY}" =~ sha256 ]]; then
    echo "  sha256 \"${SHA256}\"" >> "${newfile}"
  else
    echo "${REPLY}" >> "${newfile}"
  fi
done < Formula/yetus.rb

mv "${newfile}" Formula/yetus.rb



