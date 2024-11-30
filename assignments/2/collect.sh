#! /bin/env bash

############################# taken from https://gist.github.com/bmc/1323553/712a355e093f4c0f7fb05290373620e4e58f15fd

# A stack, using bash arrays.
# ---------------------------------------------------------------------------

# Create a new stack.
#
# Usage: stack_new name
#
# Example: stack_new x
function stack_new
{
    : ${1?'Missing stack name'}
    if stack_exists $1
    then
        echo "Stack already exists -- $1" >&2
        return 1
    fi

    eval "declare -ag _stack_$1"
    eval "declare -ig _stack_$1_i"
    eval "let _stack_$1_i=0"
    return 0
}

# Destroy a stack
#
# Usage: stack_destroy name
function stack_destroy
{
    : ${1?'Missing stack name'}
    eval "unset _stack_$1 _stack_$1_i"
    return 0
}

# Push one or more items onto a stack.
#
# Usage: stack_push stack item ...
function stack_push
{
    : ${1?'Missing stack name'}
    : ${2?'Missing item(s) to push'}

    if no_such_stack $1
    then
        echo "No such stack -- $1" >&2
        return 1
    fi

    stack=$1
    shift 1

    while (( $# > 0 ))
    do
        eval '_i=$'"_stack_${stack}_i"
        eval "_stack_${stack}[$_i]='$1'"
        eval "let _stack_${stack}_i+=1"
        shift 1
    done

    unset _i
    return 0
}

# Print a stack to stdout.
#
# Usage: stack_print name
function stack_print
{
    : ${1?'Missing stack name'}

    if no_such_stack $1
    then
        echo "No such stack -- $1" >&2
        return 1
    fi

    tmp=""
    eval 'let _i=$'"_stack_$1_i"
    while (( $_i > 0 ))
    do
        let _i=$_i-1
        eval 'e=$'"{_stack_$1[$_i]}"
        tmp="$tmp $e"
    done
    echo "(" $tmp ")"
}

# Get the size of a stack
#
# Usage: stack_size name var
#
# Example:
#    stack_size mystack n
#    echo "Size is $n"
function stack_size
{
    : ${1?'Missing stack name'}
    : ${2?'Missing name of variable for stack size result'}
    if no_such_stack $1
    then
        echo "No such stack -- $1" >&2
        return 1
    fi
    eval "$2"='$'"{#_stack_$1[*]}"
}

# Pop the top element from the stack.
#
# Usage: stack_pop name var
#
# Example:
#    stack_pop mystack top
#    echo "Got $top"
function stack_pop
{
    : ${1?'Missing stack name'}
    : ${2?'Missing name of variable for popped result'}

    eval 'let _i=$'"_stack_$1_i"
    if no_such_stack $1
    then
        echo "No such stack -- $1" >&2
        return 1
    fi

    if [[ "$_i" -eq 0 ]]
    then
        echo "Empty stack -- $1" >&2
        return 1
    fi

    let _i-=1
    eval "$2"='$'"{_stack_$1[$_i]}"
    eval "unset _stack_$1[$_i]"
    eval "_stack_$1_i=$_i"
    unset _i
    return 0
}

function no_such_stack
{
    : ${1?'Missing stack name'}
    stack_exists $1
    declare -i x
    let x="1 - $?"
    return $x
}

function stack_exists
{
    : ${1?'Missing stack name'}
    eval '_i=$'"_stack_$1_i"
    if [[ -z "$_i" ]]
    then
        return 1
    else
        return 0
    fi
}

#############################

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BOLD="\033[1m"
NO_BOLD="\033[22m"
UNDERLINE="\033[4m"
NO_UNDERLINE="\033[24m"
NORMAL="\033[0m"

STACK_NAME=directory_stack

function ensure_dir {

    : ${1?'Missing directory subpath'}
    : ${2?'Missing name of variable for directory path'}

    if [ ! -d "./$1" ]; then
        mkdir -p "./$1"
    fi

    eval "$2"="$1"
    # shellcheck disable=SC2163
    export "$2" # HACK: ShellCheck gives a warning on this line for a reason

    return 0
}

ensure_dir "./data" DIRECTORY_PREFIX
ensure_dir "$DIRECTORY_PREFIX/reports" REPORT_DIR
ensure_dir "$DIRECTORY_PREFIX/tools" TOOLS_DIR
ensure_dir "$DIRECTORY_PREFIX/repositories" REPOSITORY_DIR

# declare -A STANDARDS=( ["SPDX"]="spdx" ["CycloneDX"]="cdx" ["SWID"]="swid" )
declare -A STANDARDS=( ["CycloneDX"]="cdx" )

function build_tool {
    
    : ${1?'Missing name of the built executable tool'}

    if [[ ! -f "./build.sh" ]]; then
        echo -e "${RED}ERROR${NORMAL}: no build script found." ;
        return 1 ;
    fi

    echo -en "Building ${GREEN}\"$1\"${NORMAL}... "

    ./build.sh "$1"

    RESULT=$?

    if [[ $RESULT -eq 0 ]]; then
        echo -e "${GREEN}BUILD SUCCESS!${NORMAL}" ;
    else
        echo -e "${RED}ERROR${NORMAL}: could not build tool at ${BOLD}${YELLOW}${1}${NORMAL}${NO_BOLD}. Skipping tool..." ;
    fi

    return $RESULT ;
}

function reports_for_tool {

    : ${1?'Missing tool directory'}
    : ${2?'Missing extension for generated report files'}
    : ${3?'Missing directory for generated report files'}

    echo -e "Entering ${YELLOW}${BOLD}$1${NORMAL}..."
    stack_push $STACK_NAME "$(pwd)"
    cd "$1" || { echo -e "${RED}ERROR${NORMAL}: could not change directory to ${BOLD}${YELLOW}${1}${NORMAL}${NO_BOLD}. Aborting..." ; return 1 ;}

    # shellcheck disable=SC2206
    IFS=$'/' PATH_PARTS=($1)
    IFS=

    TOOL_CANONICAL_NAME=${PATH_PARTS[${#PATH_PARTS[@]} - 1]}

    TOOL_NAME="${TOOL_CANONICAL_NAME}EXE"

    build_tool "$TOOL_NAME"

    if [[ $? -eq 0 ]]; then
        EXECUTABLE_PATH="$(pwd)/$TOOL_NAME"

        echo $EXECUTABLE_PATH
    fi

    echo -e "Leaving ${YELLOW}${BOLD}$1${NORMAL}..."
    stack_pop "$STACK_NAME" START_DIR
    cd "$START_DIR" || { echo -e "${RED}ERROR${NORMAL}: could not change directory to ${BOLD}${YELLOW}${START_DIR}${NORMAL}${NO_BOLD}. Aborting..." ; return 1 ;}

    echo -e "\n"
}

function main {
    stack_new $STACK_NAME

    for STANDARD in "${!STANDARDS[@]}"; do
        # create directory to store the current $STANDARD's reports
        ensure_dir "$REPORT_DIR/$STANDARD" "REPORTS_DIR"

        STANDARD_EXTENSION="${STANDARDS[$STANDARD]}.json"

        echo -e "Writing reports for ${BOLD}$STANDARD${NO_BOLD} in \"$REPORTS_DIR\"\n\n"

        while IFS= read -r -d '' TOOL_DIR; do
            reports_for_tool "$TOOL_DIR" "$STANDARD_EXTENSION" "$REPORT_DIR"
        done < <(find "$TOOLS_DIR" -maxdepth 1 -mindepth 1 -type d -print0)

        echo -e "========================================================\n"
    done

    stack_destroy $STACK_NAME
}

main
