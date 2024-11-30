#! /bin/env bash

############################# taken from https://gist.github.com/bmc/1323553/712a355e093f4c0f7fb05290373620e4e58f15fd

# A stack, using bash arrays.
# ---------------------------------------------------------------------------

# Create a new stack.
#
# Usage: stack_new name
#
# Example: stack_new x
stack_new()
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
stack_destroy()
{
    : ${1?'Missing stack name'}
    eval "unset _stack_$1 _stack_$1_i"
    return 0
}

# Push one or more items onto a stack.
#
# Usage: stack_push stack item ...
stack_push()
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
stack_print()
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
stack_size()
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
stack_pop()
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

no_such_stack()
{
    : ${1?'Missing stack name'}
    stack_exists $1
    declare -i x
    let x="1 - $?"
    return $x
}

stack_exists()
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
NORMAL="\033[0m"

STACK_NAME=directory_stack

ensure_dir() {

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

ensure_dir "$(pwd)/data" DIRECTORY_PREFIX
ensure_dir "$DIRECTORY_PREFIX/reports" REPORT_DIR
ensure_dir "$DIRECTORY_PREFIX/tools" TOOLS_DIR
ensure_dir "$DIRECTORY_PREFIX/repositories" REPOSITORIES_DIR

# declare -A STANDARDS=( ["SPDX"]="spdx" ["CycloneDX"]="cdx" ["SWID"]="swid" )
declare -A STANDARDS=( ["CycloneDX"]="cdx" )

cleanup_tool() {
    : ${1?'Missing name of the built executable tool'}
    
    printf "Cleaning up ${GREEN}\"$1\"${NORMAL}... "

    rm -f $1   

    RESULT=$?

    if [[ $RESULT -eq 0 ]]; then
        printf "${GREEN}CLEANUP SUCCESS!${NORMAL}\n" ;
    else
        printf "${RED}ERROR${NORMAL}: could not clean up tool files. Skipping..." ;
    fi

    return $RESULT ;
}

build_tool() {
    
    : ${1?'Missing name of the built executable tool'}

    if [[ ! -f "./build.sh" ]]; then
        printf "${RED}ERROR${NORMAL}: no build script found." ;
        return 1 ;
    fi

    printf "Building ${GREEN}\"$1\"${NORMAL}... "

    ./build.sh "$1"

    RESULT=$?

    if [[ $RESULT -eq 0 ]]; then
        printf "${GREEN}BUILD SUCCESS!${NORMAL}\n" ;
    else
        printf "${RED}ERROR${NORMAL}: could not build tool at ${BOLD}${YELLOW}${1}${NORMAL}${NO_BOLD}. Skipping tool..." ;
    fi

    return $RESULT ;
}

report_for_tool_and_repo() {
    # shellcheck disable=SC2086
    : ${1?'Missing executable path'}
    # shellcheck disable=SC2086
    : ${2?'Missing tool name'}
    # shellcheck disable=SC2086
    : ${3?'Missing example repository path'}
    # shellcheck disable=SC2086
    : ${4?'Missing extension for generated report files'}

    echo $2
    echo $3

}

reports_for_tool() {

    # shellcheck disable=SC2086
    : ${1?'Missing tool directory'}
    # shellcheck disable=SC2086
    : ${2?'Missing extension for generated report files'}
    # shellcheck disable=SC2086
    : ${3?'Missing directory for generated report files'}

    printf "Entering ${YELLOW}${BOLD}$1${NORMAL}...\n"
    stack_push $STACK_NAME "$(pwd)"
    cd "$1" || { printf "${RED}ERROR${NORMAL}: could not change directory to ${BOLD}${YELLOW}${1}${NORMAL}${NO_BOLD}. Aborting..." ; return 1 ;}

    # shellcheck disable=SC2206
    IFS=$'/' PATH_PARTS=($1)
    IFS=

    TOOL_CANONICAL_NAME=${PATH_PARTS[${#PATH_PARTS[@]} - 1]}

    TOOL_NAME="${TOOL_CANONICAL_NAME}EXE"

    if build_tool "$TOOL_NAME"; then
        stack_push $STACK_NAME "$(pwd)"
        EXECUTABLE_PATH="$(pwd)/$TOOL_NAME"

        printf "Building reports for sample repositories\n"
        
        while IFS= read -r -d '' REPOSITORY_DIR; do
            report_for_tool_and_repo "$EXECUTABLE_PATH" "$TOOL_NAME" "$REPOSITORY_DIR" "$2"
        done < <(find "$REPOSITORIES_DIR" -maxdepth 1 -mindepth 1 -type d -print0)

        stack_pop "$STACK_NAME" TOOL_DIR
        cd "$TOOL_DIR" || { printf "${RED}ERROR${NORMAL}: could not change directory to ${BOLD}${YELLOW}${TOOL_DIR}${NORMAL}${NO_BOLD}. Aborting..." ; return 1 ;}

        cleanup_tool "$TOOL_NAME"
    fi
 
    printf "Leaving ${YELLOW}${BOLD}$1${NORMAL}...\n"
    stack_pop "$STACK_NAME" START_DIR
    cd "$START_DIR" || { printf "${RED}ERROR${NORMAL}: could not change directory to ${BOLD}${YELLOW}${START_DIR}${NORMAL}${NO_BOLD}. Aborting..." ; return 1 ;}

    printf "\n"
}

main() {
    stack_new $STACK_NAME

    for STANDARD in "${!STANDARDS[@]}"; do
        # create directory to store the current $STANDARD's reports
        ensure_dir "$REPORT_DIR/$STANDARD" "REPORTS_DIR"

        STANDARD_EXTENSION="${STANDARDS[$STANDARD]}.json"

        printf "Writing reports for ${BOLD}$STANDARD${NO_BOLD} in \"$REPORTS_DIR\"\n\n"

        while IFS= read -r -d '' TOOL_DIR; do
            reports_for_tool "$TOOL_DIR" "$STANDARD_EXTENSION" "$REPORT_DIR"
        done < <(find "$TOOLS_DIR" -maxdepth 1 -mindepth 1 -type d -print0)

        printf "========================================================\n"
    done

    stack_destroy $STACK_NAME
}

main
