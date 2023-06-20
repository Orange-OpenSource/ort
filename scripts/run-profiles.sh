#!/bin/sh
#
# Copyright (C) 2023 Orange
# Author: Nicolas Toussaint <nicolas.toussaint@orange.com>
# Author: Pawel Woznicki <pawel.woznicki@orange.com>
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

# Possible environment variables:
# ORT_PROFILE: optional
# LOG_LEVEL  : optional

# Source code expected in $ORT_PROJECT_FOLDER folder

ORT_PROJECT_FOLDER="/tmp/project"
ORT_FORMAT_EXT="json"
ORT_FORMAT="JSON"
ORT_CLEARLY_DEFINED=""
ORT_RULES_FILE_PATH="/tmp/.ort/config/rules.kts"
ORT_CLASSIFICATION_FILE_PATH="/tmp/.ort/config/license-classifications.yml"
ORT_GARBAGE_FILE_PATH="/tmp/.ort/config/copyright-garbage.yml"
ORT_BIN="/opt/ort/bin/ort"

ORT_ANALYSE="true"
ORT_SCAN="false"
ORT_ADVISE="false"
ORT_EVALUATE="false"
ORT_REPORT="true"
# default ORT_SCAN_TYPE is BASIC, other options LICENSING, SECURITY, CUSTOM
[ -z "$ORT_PROFILE" ] && ORT_PROFILE="BASIC"

# ORT working folder, placed inside the Project folder by default
ORT_WORK_SUBFOLDER="ort"
ORT_CLEAN_OLD_REPORTS="false"

# Will filter out any package that applying to levels greater than argument, from JSON reports
ORT_FILTER_PACKAGE_LEVELS=""

# Folder where the final Reports are stored, inside the Work folder
ORT_REPORT_SUBFOLDER="Reports"

ORT_ADVISE_PROVIDER="OssIndex"

f_usage() {
    echo ""
cat <<EOS

Usage: $(basename $0) <options>
    -c Custom Steps  : select the steps manually <TODO, finish doc>
    -d Enable debug  : show debug output
    -f Project folder: folder with the the source code to be analysed (default is $ORT_PROJECT_FOLDER)
    -g Config file   : ORT config file path to define ORT configuration
    -l Clean reports : remove existing working files and reports found in in working folder
    -p Profile       : select Profile (default is $ORT_PROFILE)
    -t <level>       : Filter out (from JSON reports) packages with only higher levels (requires `jq` utility)
    -w Work folder   : where working files and Reports will be stored (default is ${ORT_PROJECT_FOLDER}/${ORT_WORK_SUBFOLDER})
    -h This help

EOS
    exit $1
}

f_log() {
    echo "$@"
}

f_fatal() {
    f_log "ERROR: $*"
    exit 1
}

f_check_folder_file() {
    [ -e "${1}" ] && return 0
    f_fatal "Could not find file or directory "${1}""
}

# Set Log level
case "$LOG_LEVEL" in
    DEBUG) ort_log_level="--debug" ;;
    INFO)  ort_log_level="--info" ;;
    *)     ort_log_level="--info" ;;
esac

# Handle options
while getopts "c:df:g:hlp:t:w:" opt
do
    case $opt in
        c) ORT_CUSTOM=$(echo "_${OPTARG}_"  | sed -E 's/[^a-zA-Z]+/_/g')
           ORT_ANALYSE=true
           echo "$ORT_CUSTOM" | grep -iq "_SCAN_" && ORT_SCAN=true
           echo "$ORT_CUSTOM" | grep -iq "_ADVISE_" && ORT_ADVISE=true
           echo "$ORT_CUSTOM" | grep -iq "_EVALUATE_" && ORT_EVALUATE=true
           echo "$ORT_CUSTOM" | grep -iq "_REPORT_" && ORT_REPORT=true
           ;;
        d) ort_log_level="--debug" ;;
        f) ORT_PROJECT_FOLDER=$OPTARG ;;
        g) ORT_CONFIG_FILE=$OPTARG ;;
        l) ORT_CLEAN_OLD_REPORTS=true ;;
        p) ORT_PROFILE=$OPTARG ;;
        t) echo "$OPTARG" | grep '^[0-9][0-9]*$' || f_usage 1
           jq --version >/dev/null 2>&1 || f_fatal "Can not find required command `jq`"
           ORT_FILTER_PACKAGE_LEVELS=$OPTARG
           ;;
        w) ORT_WORK_FOLDER=$OPTARG ;;
        h) f_usage 0 ;;
    esac
done

# If the ORT Work folder was not overridden by command line option,
# then set it now since the default value is based on the Project Folder
# that may have be overridden.
[ -n "$ORT_WORK_FOLDER" ] || ORT_WORK_FOLDER="${ORT_PROJECT_FOLDER}/${ORT_WORK_SUBFOLDER}"
ORT_REPORT_FOLDER="${ORT_WORK_FOLDER}/${ORT_REPORT_SUBFOLDER}"

ORT_OUTFILE_ANALYZE="${ORT_WORK_FOLDER}/analyzer-result.${ORT_FORMAT_EXT}"
ORT_OUTFILE_SCAN="${ORT_WORK_FOLDER}/scan-result.${ORT_FORMAT_EXT}"
ORT_OUTFILE_ADVISE="${ORT_WORK_FOLDER}/advisor-result.${ORT_FORMAT_EXT}"
ORT_OUTFILE_EVALUATE="${ORT_WORK_FOLDER}/evaluation-result.${ORT_FORMAT_EXT}"

ORT_ADVISE_ARGS="-a ${ORT_ADVISE_PROVIDER} -o ${ORT_WORK_FOLDER} -f ${ORT_FORMAT}"
ORT_SCAN_ARGS="-o ${ORT_WORK_FOLDER} -f ${ORT_FORMAT}"
ORT_ANALYZE_ARGS="-i ${ORT_PROJECT_FOLDER} -o ${ORT_WORK_FOLDER} -f ${ORT_FORMAT}"
ORT_EVALUATE_ARGS="-o ${ORT_WORK_FOLDER} -f ${ORT_FORMAT}"
ORT_REPORT_ARGS="-o ${ORT_REPORT_FOLDER} --report-formats CycloneDx,PlainTextTemplate,SpdxDocument,StaticHtml,WebApp,EvaluatedModel"

ORT_JSON_REPORT="$ORT_REPORT_FOLDER/evaluated-model.json"
ORT_JSON_REPORT_FILTERED="$ORT_REPORT_FOLDER/evaluated-model-filtered.json"

# Ignore Garbage file if it does not exist
[ -e "$ORT_GARBAGE_FILE_PATH" ] || unset ORT_GARBAGE_FILE_PATH

# Seelct steps according to Profile
case $ORT_PROFILE in
"BASIC")
    f_log "ORT Profile set to BASIC [Analyse, Report]"
    ORT_ANALYSE=true
    ORT_SCAN=false
    ORT_ADVISE=false
    ORT_EVALUATE=false
    ORT_REPORT=true
    ;;
"LICENSING")
    f_log "ORT Profile set to LICENSING [Analyse, Scan, Report]"
    ORT_ANALYSE=true
    ORT_SCAN=true
    ORT_ADVISE=false
    ORT_EVALUATE=false
    ORT_REPORT=true
    ;;
"SECURITY")
    f_log "ORT Profile set to SECURITY [Analyse, Advise, Report]"
    ORT_ANALYSE=true
    ORT_SCAN=false
    ORT_ADVISE=true
    ORT_EVALUATE=false
    ORT_REPORT=true
    ;;
"CUSTOM")
    f_log "ORT Profile set to CUSTOM"
    custom_abort=false
    for v in ORT_ANALYSE ORT_SCAN ORT_ADVISE ORT_EVALUATE ORT_REPORT
    do
        val=foo
        eval "val=\"\$$v\""
        if echo "$val" | grep -q "^true$\|^false$"
        then
            f_log "  $v: $val"
        else
            f_log "  $v: wrong value '$val' - expected 'true' or 'false'"
            custom_abort=true
        fi
    done
    $custom_abort && f_fatal "Wrong values for CUSTOM steps"
    ;;
*)
    f_fatal "ORT Profile is not one of the following options [BASIC, LICENSING, SECURITY, CUSTOM]"
    exit 1
    ;;
esac

cat <<EOS

Selected steps:
  Analyse:  $ORT_ANALYSE
  Scan:     $ORT_SCAN
  Advise:   $ORT_ADVISE
  Evaluate: $ORT_EVALUATE
  Report:   $ORT_REPORT

Project folder: ${ORT_PROJECT_FOLDER}
Work folder   : ${ORT_WORK_FOLDER}
Report folder : ${ORT_REPORT_FOLDER}
Config file   : ${ORT_CONFIG_FILE}

EOS

test -x $ORT_BIN || f_fatal "Command missing: $ORT_BIN"

if $ORT_CLEAN_OLD_REPORTS
then
    f_log "Remove existing files in Work and Report folders"
    [ -d "$ORT_WORK_FOLDER" ] && find "$ORT_WORK_FOLDER" -type f -print0 | xargs -0 rm -v
    [ -d "$ORT_REPORT_FOLDER" ] && find "$ORT_REPORT_FOLDER" -type f -print0 | xargs -0 rm -v
fi

# Execute all steps

f_log "ORT analyse"
$ORT_BIN ${ORT_CONFIG_FILE+-c $ORT_CONFIG_FILE} $ort_log_level analyze $ORT_ANALYZE_ARGS \
    ${ORT_CURATIONS_FILE+--package-curations-file $ORT_CURATIONS_FILE} || true
f_check_folder_file "${ORT_OUTFILE_ANALYZE}"
ORT_NEXT_STEP_IN="${ORT_OUTFILE_ANALYZE}"

if [ "$ORT_SCAN" = true ]
then
    f_log "ORT scan (in: ${ORT_NEXT_STEP_IN})"
    $ORT_BIN ${ORT_CONFIG_FILE+-c $ORT_CONFIG_FILE} $ort_log_level scan -i ${ORT_NEXT_STEP_IN} $ORT_SCAN_ARGS || true
    f_check_folder_file "${ORT_OUTFILE_SCAN}"
    ORT_NEXT_STEP_IN="${ORT_OUTFILE_SCAN}"
fi

if [ "$ORT_ADVISE" = true ]
then
    f_log "ORT advise (in: ${ORT_NEXT_STEP_IN})"
    $ORT_BIN ${ORT_CONFIG_FILE+-c $ORT_CONFIG_FILE} $ort_log_level advise -i ${ORT_NEXT_STEP_IN} $ORT_ADVISE_ARGS || true
    f_check_folder_file "${ORT_OUTFILE_ADVISE}"
    ORT_NEXT_STEP_IN="${ORT_OUTFILE_ADVISE}"
fi

if [ "$ORT_EVALUATE" = true ]
then
    f_log "ORT evaluate (in ${ORT_NEXT_STEP_IN})"
    $ORT_BIN ${ORT_CONFIG_FILE+-c $ORT_CONFIG_FILE} $ort_log_level evaluate -i ${ORT_NEXT_STEP_IN} $ORT_EVALUATE_ARGS \
    ${ORT_CLASSIFICATION_FILE_PATH+--license-classifications-file $ORT_CLASSIFICATION_FILE_PATH} ${ORT_RULES_FILE_PATH+--rules-file $ORT_RULES_FILE_PATH} || true
    f_check_folder_file "${ORT_OUTFILE_EVALUATE}"
    ORT_NEXT_STEP_IN="${ORT_OUTFILE_EVALUATE}"
fi

if [ "$ORT_REPORT" = true ]
then
    f_log "ORT report (in: ${ORT_NEXT_STEP_IN})"
    $ORT_BIN ${ORT_CONFIG_FILE+-c $ORT_CONFIG_FILE} $ort_log_level report -i ${ORT_NEXT_STEP_IN} $ORT_REPORT_ARGS \
    ${ORT_GARBAGE_FILE_PATH+--copyright-garbage-file $ORT_GARBAGE_FILE_PATH} || true
    if [ -n "$ORT_FILTER_PACKAGE_LEVELS" ]
    then
        f_log "Generate filtered JSON report (level <= $ORT_FILTER_PACKAGE_LEVELS)"
        [ -r "$ORT_JSON_REPORT" ] || f_fatal "Can not find JSON report"
        jq ".packages |= map(select(.levels | min <= $ORT_FILTER_PACKAGE_LEVELS))" $ORT_JSON_REPORT > $ORT_JSON_REPORT_FILTERED
    fi
    f_check_folder_file "${ORT_REPORT_FOLDER}"
fi
