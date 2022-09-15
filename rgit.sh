#!/bin/bash
# gfx2501
# Recursively visits the folder and its sub folders to execute a git command.
# 2017/09 : v1 git-rec is alive!!!
# 2018/06 : v2 Enhances time report
# 2019/01 : v3 Enhances again time report (removes bc dependency)
# 2020/01 : v4 Enhances output with more human readable information
#              Uses lower case variable names
# 2020/10 : v5 Corrects small things and documentation
#              Changes exclusion configuration to make it work with only relative project names and globbing
#              Changes configuration file location to be in the same folder as the script
# 2020/12 : v6 Adds colors...
#              Corrects bad configuration file path
# 2021/02 : v7 Enhances color use in print
#              Adds option to log command for graph display
#           v7.1 Adds branch name to repository label
# 2021/03 : v8 Adds a list repositories command
# 2021/08 : v9 Renames git-rec to rgit (recursive git)
#              Adds version command
#              Reworks help message
#              Adds repository duration
# 2021/09 : v9.1 Fixes configuration file loading
# 2021/10 : v10 Adds repository average duration in footer
# 2022/01 : v11 Adds repository progress
#               Fixes global repositories count
# 2022/06 : v12 Sanitizes variable names and adds readonly for constants
# 2022/06 : v13 Adds log of executions' statistics
# 2022/07 : v14 Fixes missing ms in date command (MacOS compatibility)
#               Fixes repositories order in listing

# Defaults, not readonly because overridden by configuration file
COMMAND="status"
EXCLUDED=""
MAX_DEPTH=2
THEME="dark"
STAT=1

# Version
readonly NAME=rgit
readonly MAJOR=14
readonly MINOR=0
readonly RELEASE_DATE="2022/07/27"

# Configuration filename
readonly CONF_FILE=".$NAME"

# Colors reference (add '01;' for lighter color like in \033[01;36m for light cyan)
# readonly COL_BLACK='\033[30m'
# readonly COL_RED='\033[31m'
# readonly COL_GREEN='\033[32m'
readonly COL_YELLOW='\033[33m'
readonly COL_YELLOW_LIGHT='\033[01;33m'
readonly COL_BLUE='\033[34m'
readonly COL_BLUE_LIGHT='\033[01;34m'
# readonly COL_MAGENTA='\033[35m'
readonly COL_CYAN='\033[36m'
readonly COL_CYAN_LIGHT='\033[01;36m'
# readonly COL_WHITE='\033[37m'
readonly COL_RESET='\033[00m'

# Tests date can return ms precision
function isDateMs() {
    local d=$(date +%s%3N)
    local end=${d: -1}
    if [[ "$end" != "N" ]]
    then
        echo 1
    else
        echo 0
    fi
}

readonly HAS_MS=$(isDateMs)

# Generates now timestamp
function now() {
    if [[ $HAS_MS -eq 1 ]]
    then
        date +%s%3N
    else
        date +%s000
    fi
}

# Start time
start=$(now)

# Writes default configuration file
function confFile() {
    if [[ -f "$CONF_FILE" ]]
    then
        echo "Configuration file $CONF_FILE already exist !"
        ls -al "$CONF_FILE"
    else
        cat << EOM >"$CONF_FILE"
# recursive git configuration file

# List of excluded repositories (separated by two dot ":")
EXCLUDED="redkryptonite:old/smallville:krypton/*"

# Default command (used when no arguments provided) as with --command
#COMMAND="$COMMAND"

# Maximum depth of search
#MAX_DEPTH=$MAX_DEPTH

# Color theme (dark|light|no)
#THEME="$THEME"

# Log statistics (0|1)
STAT=$STAT
EOM
        echo "Configuration file $CONF_FILE created"
        ls -al "$CONF_FILE"
    fi
}

# Prints help message
function help() {
    read -r -d '' msgHelp << EOM
Recursively visits the folder and its sub folders to execute a git command.

Usage:
  `basename ${0}` -h | --help
  `basename ${0}` [-d | --depth <number>] -s | --status
  `basename ${0}` [-d | --depth <number>] [-n <number>] [-g | --graph] -l | --log
  `basename ${0}` [-d | --depth <number>] -p | --pull
  `basename ${0}` [-d | --depth <number>] -b | --branch-name
  `basename ${0}` [-d | --depth <number>] -c | --command <args>

Options:
  -s, --status          Print status.
  -l, --log             Print last log.
  -p, --pull            Pull origin.
  -b, --branch-name     Print current branch name.
  -B, --branch-all      Print all branches names with commit subject line for each head.
  -c, --command         Execute following git command (do not include 'git').
      --list            List all git repositories found in folder.

  -d, --depth <number>  Maximum depth of recursive browsing [default: 2].
  -n <number>           Number of commit messages [default: 5] for log.
  -g, --graph           Add metro lines graph to log.
      --no-color        Remove color from output (useful for text storage).

Miscellaneous:
  -h, --help            Display this help message and exit.
  -v, --version         Display version information and exit.
      --create-conf     Create an example configuration file in script folder (if not present).

You can add a $CONF_FILE file in the same folder with your defaults
and a list of excluded repositories. Use --create-conf option.
EOM
    echo "$msgHelp"
}

# Prints version message
function version() {
    echo "$NAME (recursive git) version $MAJOR.$MINOR ($RELEASE_DATE)"
}

# Converts duration between start to end to human readable
function formatDuration() {
    # Calculate difference between end and start (in ms)
    local d=$(( ${1} - ${2:-0} ))
    # Elapsed time in seconds (removes ms)
    local dT=$(( $d / 1000 ))
    # Days part of the elapsed time
    local dD=$(( $dT / 60 / 60 / 24 ))
    # Hours part of the elapsed time
    local dH=$(( $dT / 60 / 60 % 24 ))
    # Minutes part of the elapsed time
    local dM=$(( $dT / 60 % 60 ))
    # Seconds part of the elapsed time
    local dS=$(( $dT % 60 ))
    # Milliseconds part of the elapsed time
    local dMS=$(( $d % 1000 ))
    (( $dD > 0 )) && printf '%d d ' $dD
    (( $dH > 0 )) && printf '%02dh' $dH
    (( $dM > 0 )) && printf '%02dm' $dM
    printf '%02d.%03ds' $dS $dMS
}

# Try to load configuration from file
if [[ -r $CONF_FILE ]]
then
    . $CONF_FILE
fi

gitCommand="$COMMAND"
graphOption=""
list=0
maxCount=5
maxDepth=$MAX_DEPTH
theme=$THEME
stat=$STAT

# Parses command line
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -d|--depth)
        maxDepth=$2
        shift 2
        ;;
        -n)
        maxCount=$2
        shift 2
        ;;
        -g|--graph)
        graphOption=" --graph"
        shift
        ;;

        -b|--branch-name)
        gitCommand="rev-parse --abbrev-ref HEAD"
        shift
        ;;
        -B|--branch-all)
        gitCommand="branch --list -a -v"
        shift
        ;;
        -p|--pull)
        gitCommand="pull"
        shift
        ;;
        -s|--status)
        gitCommand="status"
        shift
        ;;
        -l|--log)
        gitCommand="log -n $maxCount$graphOption --date=local --pretty=format:'%C(bold green)%cd%Creset %C(yellow)%h%Creset -%C(bold red)%d%Creset %s %C(bold yellow)<%an>%Creset'"
        shift
        ;;
        -c|--command)
        shift
        gitCommand="$*"
        shift $# # Consumes all arguments
        ;;

        --create-conf)
        confFile
        exit 0
        ;;

        --list)
        list=1
        shift
        ;;

        --no-color)
        theme="no"
        shift
        ;;

        -v|--version)
        version
        exit 0
        ;;

        -h|--help)
        help
        exit 0
        ;;
        *)
        echo "Sorry, unknown arguments"
        help
        exit 1
        ;;
    esac
done

# Colors for messages
cBranch=
cDate=
cLabel=
cRepo=
cReset=
case $theme in
    dark)
    cBranch=$COL_CYAN_LIGHT
    cDate=$COL_YELLOW_LIGHT
    cLabel=$COL_CYAN_LIGHT
    cRepo=$COL_BLUE_LIGHT
    cReset=$COL_RESET
    ;;
    light)
    cBranch=$COL_CYAN
    cDate=$COL_YELLOW
    cLabel=$COL_CYAN
    cRepo=$COL_BLUE
    cReset=$COL_RESET
    ;;
    no)
    ;;
    *)
    echo "Sorry, unknown theme, use either dark|light|no"
    ;;
esac

base=$PWD
nbExcluded=0
# We search for .git folder so we need to go down one more
(( maxDepth++ ))
execCommand="git $gitCommand"

# Header
if [[ $list -eq 0 ]]
then
    printf 'git recursive command\n%bBase folder:%b %q\n%bCommand    :%b %s\n%bBegin      :%b %b%s%b\n' "${cLabel}" "${cReset}" "$base" "${cLabel}" "${cReset}" "$execCommand" "${cLabel}" "${cReset}" "${cDate}" "$(date)" "${cReset}"
else
    printf 'git recursive command\n%bBase folder:%b %q\n%bBegin      :%b %b%s%b\n' "${cLabel}" "${cReset}" "$base" "${cLabel}" "${cReset}" "${cDate}" "$(date)" "${cReset}"
fi

echo

# Rebuilds excluded repositories list with globbing
IFS=$':'
excludedPaths=""
for path in $EXCLUDED
do
    excludedPaths="$excludedPaths:$path";
done
IFS=$' \t\n'

# Count repositories
count=$(find . -maxdepth $maxDepth -type d -name '.git' | wc -l)

if [[ $list -eq 0 ]]
then
    nb=1

    # Browses repositories
    while read -r dir
    do
        # Go to repository folder
        cd "$dir/.." || continue
        # Repository start time
        repoStart=$(now)

        if [[ $nb -ge 2 ]]
        then
            echo
        fi
        echo

        # Extracts current full repository name
        repoName=${dir%%/\.git}
        repoName=${repoName#\./}

        branchName=$(git rev-parse --abbrev-ref HEAD)

        # Tests if repository is not excluded
        if [[ $excludedPaths =~ (^|:)$repoName($|:) ]]
        then
            printf '%bRepository :%b %b%q%b %b(%s)%b - %d/%d (excluded)\n' "${cLabel}" "${cReset}" "${cRepo}" "$repoName" "${cReset}" "${cBranch}" "$branchName" "${cReset}" "$nb" "$count"

            # Number of repository excluded
            (( nbExcluded++ ))
        else
            printf '%bRepository :%b %b%q%b %b(%s)%b - %d/%d\n%s\n' "${cLabel}" "${cReset}" "${cRepo}" "$repoName" "${cReset}" "${cBranch}" "$branchName" "${cReset}" "$nb" "$count" "$execCommand"

            # Executes command
            eval "$execCommand"

            # Repository end time
            repoEnd=$(now)
            repoDuration=$(formatDuration $repoEnd $repoStart)

            printf '%bRepo end   :%b %b%s (%s)%b\n' "${cLabel}" "${cReset}" "${cDate}" "$(date)" "$repoDuration" "${cReset}"
        fi

        # Number of repository browsed
        (( nb++ ))

        # Returns to base
        cd "$base" || continue
    done < <(find . -maxdepth $maxDepth -type d -name '.git' | sort --version-sort)
else
    # Lists repositories
    while read -r dir
    do
        # Goes to repository folder
        cd "$dir/.." || continue

        # Extracts current full repository name
        repoName=${dir%%/\.git}
        repoName=${repoName#\./}

        branchName=$(git rev-parse --abbrev-ref HEAD)

        excludedMsg=
        # Tests if repository is not excluded
        if [[ $excludedPaths =~ (^|:)$repoName($|:) ]]
        then
            excludedMsg=" (excluded)"
            # Number of repository excluded
            (( nbExcluded++ ))
        fi
        printf '%b%q%b %b(%s)%b%s\n' "${cRepo}" "$repoName" "${cReset}" "${cBranch}" "$branchName" "${cReset}" "$excludedMsg"

        # Returns to base
        cd "$base" || continue
    done < <(find . -maxdepth $maxDepth -type d -name '.git' | sort --version-sort)
fi

# Reports
repositoriesMsg="repository"
if [[ $count -ge 1 ]]
then
    repositoriesMsg="repositories"
fi
excludedMsg=
if [[ $nbExcluded -ge 0 ]]
then
    excludedMsg=" ($nbExcluded excluded)"
fi

end=$(now)
duration=$(formatDuration $end $start)
davg=$(( ($end - $start) / $count ))
avg=$(formatDuration $davg)
printf '\n%bEnd        :%b %b%s%b\n%d %s browsed in %b%s (%s / repo)%b%s\n' "${cLabel}" "${cReset}" "${cDate}" "$(date)" "${cReset}" "$count" "$repositoriesMsg" "${cDate}" "$duration" "$avg" "${cReset}" "$excludedMsg"

if [[ $stat -eq 1 ]]
then
    # CSV log export
    # date ; start ; duration ; command ; repositories number ; excluded number
    printf '%s;%d;%d;%s;%d;%d\n' "$(date)" "$start" "$(( $end - $start ))" "$execCommand" "$count" "$nbExcluded" >> "$NAME-stat.log"
fi

# This is the end
