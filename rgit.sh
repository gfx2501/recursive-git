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

# Start time
start=$(date +%s%3N)

# Version
name=rgit
major=10
minor=0
releaseDate="2021/10/11"

conf=".$name"

# Colors reference (add '01;' for lighter color like in \033[01;36m for light cyan)
# colBlack='\033[30m'
# colRed='\033[31m'
# colGreen='\033[32m'
colYellow='\033[33m'
colYellowLight='\033[01;33m'
colBlue='\033[34m'
colBlueLight='\033[01;34m'
# colMagenta='\033[35m'
colCyan='\033[36m'
colCyanLight='\033[01;36m'
# colWhite='\033[37m'
colReset='\033[00m'

# Writes default configuration file
function confFile {
    if [[ -f "$conf" ]]
    then
        echo "Configuration file $conf already exist !"
        ls -al "$conf"
    else
        cat << EOM >"$conf"
# recursive git configuration file

# List of excluded repositories (separated by two dot ":")
EXCLUDED="redkryptonite:old/smallville:krypton/*"

# Default command (used when no arguments provided) as with --command
#COMMAND=status

# Maximum depth of search
#MAXDEPTH=5

# Color theme (dark|light|no)
#THEME=dark
EOM
        echo "Configuration file $conf created"
        ls -al "$conf"
    fi
}

# Prints help message
function help {
    read -r -d '' msgHelp << EOM
Recursively visits the folder and its sub folders to execute a git command.

Usage:
  `basename ${0}` -h | --help
  `basename ${0}` [-d | -depth <number>] -s | --status
  `basename ${0}` [-d | -depth <number>] [-n <number>] [-g | --graph] -l | --log
  `basename ${0}` [-d | -depth <number>] -p | --pull
  `basename ${0}` [-d | -depth <number>] -b | --branch-name
  `basename ${0}` [-d | -depth <number>] -c | --command <args>

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

You can add a $conf file in the same folder with your defaults
and a list of excluded repositories. Use --create-conf option.
EOM
    echo "$msgHelp"
}

# Prints version message
function version {
    echo "rgit (recursive git) version $major.$minor ($releaseDate)"
}

# Converts duration between start to end to human readable
function formatDuration {
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

# Defaults
list=0
COMMAND="status"
MAXCOUNT=5
MAXDEPTH=2
THEME="dark"

# Try to load configuration from file
if [[ -r $conf ]]
then
    . $conf
fi

graphOption=""
# Parses command line
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -d|--depth)
        MAXDEPTH=$2
        shift 2
        ;;
        -n)
        MAXCOUNT=$2
        shift 2
        ;;
        -g|--graph)
        graphOption=" --graph"
        shift
        ;;

        -b|--branch-name)
        COMMAND="rev-parse --abbrev-ref HEAD"
        shift
        ;;
        -B|--branch-all)
        COMMAND="branch --list -a -v"
        shift
        ;;
        -p|--pull)
        COMMAND="pull"
        shift
        ;;
        -s|--status)
        COMMAND="status"
        shift
        ;;
        -l|--log)
        COMMAND="log -n $MAXCOUNT$graphOption --date=local --pretty=format:'%C(bold green)%cd%Creset %C(yellow)%h%Creset -%C(bold red)%d%Creset %s %C(bold yellow)<%an>%Creset'"
        shift
        ;;
        -c|--command)
        shift
        COMMAND="$*"
        shift $# # Consume all arguments
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
        THEME='no'
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

case $THEME in
    dark)
    cBranch=$colCyanLight
    cDate=$colYellowLight
    cLabel=$colCyanLight
    cRepo=$colBlueLight
    cReset=$colReset
    ;;
    light)
    cBranch=$colCyan
    cDate=$colYellow
    cLabel=$colCyan
    cRepo=$colBlue
    cReset=$colReset
    ;;
    no|*)
    echo "Sorry, unknown theme, use either dark|light|no"
    cBranch=
    cDate=
    cLabel=
    cRepo=
    cReset=
    ;;
esac

base=$PWD
nb=0
nbExcluded=0
# We search for .git folder so we need to go down one more
(( MAXDEPTH++ ))
COMMAND="git $COMMAND"

# Header
if [[ $list -eq 0 ]]
then
    printf 'git recursive command\n%bBase folder:%b %q\n%bCommand    :%b %s\n%bBegin      :%b %b%s%b\n' "${cLabel}" "${cReset}" "$base" "${cLabel}" "${cReset}" "$COMMAND" "${cLabel}" "${cReset}" "${cDate}" "$(date)" "${cReset}"
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

if [[ $list -eq 0 ]]
then
    first=1

    # Browses repositories
    while read -r dir
    do
        # Go to repository folder
        cd "$dir/.." || continue
        # Repository start time
        repoStart=$(date +%s%3N)

        if [[ $first -eq 1 ]]
        then
            first=0
        else
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
            printf '%bRepository :%b %b%q%b %b(%s)%b (excluded)\n' "${cLabel}" "${cReset}" "${cRepo}" "$repoName" "${cReset}" "${cBranch}" "$branchName" "${cReset}"

            # Number of repository excluded
            (( nbExcluded++ ))
        else
            printf '%bRepository :%b %b%q%b %b(%s)%b\n%s\n' "${cLabel}" "${cReset}" "${cRepo}" "$repoName" "${cReset}" "${cBranch}" "$branchName" "${cReset}" "$COMMAND"

            # Executes command
            eval "$COMMAND"

            # Number of repository browsed
            (( nb++ ))

            # Repository end time 
            repoEnd=$(date +%s%3N)
            repoDuration=$(formatDuration $repoEnd $repoStart)

            printf '%bRepo end   :%b %b%s (%s)%b\n' "${cLabel}" "${cReset}" "${cDate}" "$(date)" "$repoDuration" "${cReset}"
        fi

        # Returns to base
        cd "$base" || continue
    done < <(find . -maxdepth $MAXDEPTH -type d -name '.git')
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
        else
            # Number of repository browsed
            (( nb++ ))
        fi
        printf '%b%q%b %b(%s)%b%s\n' "${cRepo}" "$repoName" "${cReset}" "${cBranch}" "$branchName" "${cReset}" "$excludedMsg"

        # Returns to base
        cd "$base" || continue
    done < <(find . -maxdepth $MAXDEPTH -type d -name '.git')
fi

# Reports
repositoriesMsg="repository"
if [[ $nb -ge 1 ]]
then
    repositoriesMsg="repositories"
fi
excludedMsg=
if [[ $nbExcluded -ge 0 ]]
then
    excludedMsg=" ($nbExcluded excluded)"
fi

end=$(date +%s%3N)
duration=$(formatDuration $end $start)
davg=$(( ($end - $start) / ($nb - $nbExcluded) ))
avg=$(formatDuration $davg)
printf '\n%bEnd        :%b %b%s%b\n%d %s browsed in %b%s (%s / repo)%b%s\n' "${cLabel}" "${cReset}" "${cDate}" "$(date)" "${cReset}" "$nb" "$repositoriesMsg" "${cDate}" "$duration" "$avg" "${cReset}" "$excludedMsg"

# This is the end
