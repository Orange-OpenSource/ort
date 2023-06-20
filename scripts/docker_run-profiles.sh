#!/bin/sh
#
# Copyright (C) 2022 The ORT Project Authors (see <https://github.com/oss-review-toolkit/ort/blob/main/NOTICE>)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
# License-Filename: LICENSE

# Usage:
#  Arg1: the local folder that will be mounted and scanned by ORT
#  Arg*: all other args are passed to the run-profiles.sh folder.
#
# Environment variables:
# DOCKER_IMAGE : to store Docker image ref

f_fatal() {
    echo "ERROR: $*"
    exit 1
}

[ -n "$DOCKER_IMAGE" ] || f_fatal "Missing DOCKER_IMAGE variable"

DOCKER_ENV=""
[ -n "$https_proxy" ] && DOCKER_ENV="$DOCKER_ENV -e https_proxy"
[ -n "$http_proxy" ] && DOCKER_ENV="$DOCKER_ENV -e http_proxy"

project_folder="$1"
shift
[ -d "$project_folder" ] || f_fatal "Unknown folder: '$project_folder'"

docker run \
    -v "$project_folder":/tmp/project \
     $DOCKER_ENV \
    --entrypoint '/opt/ort/bin/run-profiles.sh' \
    "$DOCKER_IMAGE" "$@"
