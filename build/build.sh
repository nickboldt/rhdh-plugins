#!/bin/bash
#
# Copyright (c) 2023 Red Hat, Inc.
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

BACKSTAGE_RELEASE="v1.26.4"
git clone https://github.com/backstage/backstage --depth 1 -b $BACKSTAGE_RELEASE 
pushd backstage || exit 1
YARN=.yarn/releases/yarn-3.8.1.cjs
WORKSPACE="$(pwd)"
$YARN install
$YARN tsc
mkdir -p "${WORKSPACE}/dynamic-plugins-archives"

packDestination="${WORKSPACE}/dynamic-plugins-archives"
janus_cli_version="^1.8.1"
config_file_name="${WORKSPACE}/../app-config.dynamic.yaml"

errors=''
IFS=$'\n'
for plugin in $(cat ${pluginsfile}); do
    if [[ "$(echo $plugin | sed 's/ *//')" == "" ]]
    then
    echo "Skip empty line"
    continue
    fi
    if [[ "$(echo $plugin | sed 's/^#.*//')" == "" ]]
    then
    echo "Skip commented line"
    continue
    fi
    pluginPath=$(echo $plugin | sed 's/^\(^[^:]*\): *\(.*\)$/\1/')
    args=$(echo $plugin | sed 's/^\(^[^:]*\): *\(.*\)$/\2/')
    pushd $pluginPath > /dev/null
    if [[ "$(grep -e '"role" *: *"frontend-plugin' package.json)" != "" ]]
    then
    echo ========== Exporting frontend plugin $pluginPath ==========
    sed -i 's/\(^ *\)"dist"\( *\)$/\1"dist-scalprum", "dist"\2/' package.json
    set +e
    echo "$args" | xargs npx --yes @janus-idp/cli@${janus_cli_version} package export-dynamic-plugin
    if [ $? -ne 0 ]
    then
        errors="${errors}\n${pluginPath}"
        set -e
        popd > /dev/null
        continue
    fi
    json=$(npm pack . --pack-destination $packDestination --json)
    if [ $? -ne 0 ]
    then
        errors="${errors}\n${pluginPath}"
        set -e
        popd > /dev/null
        continue
    fi
    set -e
    else
    echo ========== Exporting backend plugin $pluginPath ==========
    set +e
    echo "$args" | xargs npx --yes @janus-idp/cli@${janus_cli_version} package export-dynamic-plugin --embed-as-dependencies 
    if [ $? -ne 0 ]
    then
        errors="${errors}\n${pluginPath}"
        set -e
        popd > /dev/null
        continue
    fi
    json=$(npm pack ./dist-dynamic --pack-destination $packDestination --json)
    if [ $? -ne 0 ]
    then
        errors="${errors}\n${pluginPath}"
        set -e
        popd > /dev/null
        continue
    fi
    set -e
    fi
    filename=$(echo "$json" | jq -r '.[0].filename')
    integrity=$(echo "$json" | jq -r '.[0].integrity')
    echo "$integrity" > $packDestination/${filename}.integrity
    optionalConfigFile="$(dirname ${pluginsfile})/${pluginPath}/${config_file_name}"
    if [ -f "${optionalConfigFile}" ]
    then
    cp "${optionalConfigFile}" "$packDestination/${filename}.${config_file_name}"
    fi
    popd > /dev/null
done

if [[ $errors != "" ]]; then
    echo "The export failed for the following plugins: $errors"; exit 1
fi

popd || exit 1