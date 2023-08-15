#!/bin/bash
# ------------------------------------------------------
# Pasta: Post Archive Seed Torrent Automatic Extraction
# Author: Michael Edie (c) 2023
# ------------------------------------------------------
#
# DESCRIPTION:
# The 'pasta' script automates the processing and extraction of archived torrents,
# helping to manage torrent directories and facilitate seamless extraction of
# content from various sources. It can process torrents invoked by Transmission,
# and can also operate in batch mode to handle multiple torrents at once.

# GLOBAL VARIABLES:
# - VERBOSE: Set to "true" to enable verbose mode, displaying additional output.
# - P_BATCH: Set to "true" to enable batch mode, processing all eligible torrents.
# - TR_TORRENT_DIR: The directory of the current Transmission-invoked torrent.
# - TR_TORRENT_NAME: The name of the current Transmission-invoked torrent.
# - COMPLETED_DIR: The directory containing completed torrents for processing.
# ------------------------------------------------------------------------------------------
set -e 
VERSION="0.0.1"
# Configuration
P_BATCH=false
# Wildcards are NOT supported, must be exact names
EXCLUDED_DIRS=( "anime" "misc" "backups" )
# pasta will search all sub directories below this path
COMPLETED_DIR="/data/completed"
MIN_DIR_AGE=900  # 15 minutes in seconds
REMOVE_RAR_FILES=false  # Set to 'false' if you want to keep rar files
LOG_DIR="/data/transmission-home"
LOG_FILE="${LOG_DIR}"/pasta.log
VERBOSE=false
# ------------------------------------------------------------------------------------------
# WARNING: Do not modify anything below this line unless you are familiar with the script's internals.
# Modifying this section can lead to unintended behavior and script malfunctions.
# If you have suggestions or need to customize the script, consider submitting a feature request
# or a pull request to the script's repository.
# ------------------------------------------------------------------------------------------
show_help() {
    cat <<-EOF
    Usage: $(basename "$0") [OPTIONS]
    Options:
      -v     Enable verbose output
      -b     Process archived torrents in batch mode
      -h     Display this help message and exit

    Author: Michael Edie <michael@sawbox.net>
	EOF
}

while getopts "vbh" opt; do
    case "$opt" in
        h) show_help ;;
        v) VERBOSE=true ;;
        b) P_BATCH=true ;;
        *) echo "Usage: $(basename "$0") [-v] [-b] [-h]" >&2
           exit 1 ;;
    esac
done

splash() {
    echo "
 ▄▄▄· ▄▄▄· .▄▄ · ▄▄▄▄▄ ▄▄▄· 
▐█ ▄█▐█ ▀█ ▐█ ▀. •██  ▐█ ▀█ 
 ██▀·▄█▀▀█ ▄▀▀▀█▄ ▐█.▪▄█▀▀█ 
▐█▪·•▐█ ▪▐▌▐█▄▪▐█ ▐█▌·▐█ ▪▐▌
.▀    ▀  ▀  ▀▀▀▀  ▀▀▀  ▀  ▀
by: Michael Edie
"
}

logger() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S.%3N")
    local message="$1"
    echo "[$timestamp] pasta: ${message}" >> "$LOG_FILE"

    if [ "$VERBOSE" ]; then
        echo "[$timestamp] ${message}"
    fi
}

# ------------------------------------------------------------------
# Determine whether a directory should be processed based on its age.
#
# This function checks if a specified directory should be processed
# based on its age in seconds. If the age of the directory exceeds
# the minimum age threshold specified by MIN_DIR_AGE, the
# directory is considered eligible for processing.
#
# Parameters:
#   $1: The path to the directory to be evaluated.
#
# Environment Variables:
#   MIN_DIR_AGE: The minimum age threshold in seconds for
#                a directory to be considered for processing.
#
# Returns:
#   0: The directory is eligible for processing.
#   1: The directory is not eligible for processing.
# ------------------------------------------------------------------
should_process_directory() {
    local directory_path="$1"
    local directory_creation_time
    
    # Linux
    directory_creation_time=$(stat -c %Z "$directory_path")
    
    local current_time=$(date +%s)
    local time_difference=$((current_time - directory_creation_time))
    echo "td" $time_difference
    echo "md" $MIN_DIR_AGE
    if [ "$time_difference" -ge "$MIN_DIR_AGE" ]; then
        return 0
    else
        return 1
    fi
}

has_extraction_marker() {
    local directory="$1"
    [ -f "$directory/.pasta" ]
}

mark_extraction_complete() {
    local directory="$1"
    touch "$directory/.pasta"
}

# ------------------------------------------------------------------
# Extract and unrar a specified file.
#
# This function extracts the contents of a given RAR archive file.
# It uses the 'unrar' utility to perform the extraction.
# If extraction is successful, an extraction marker is added to
# the directory to indicate completion.
#
# Parameters:
#   $1: The path to the RAR archive file to be extracted.
#
# Environment Variables:
#   VERBOSE: If set, enables verbose mode, suppressing confirmation
#            prompts during extraction.
#
# Dependencies:
#   This function requires the 'unrar' utility to be installed.
#
# Exit Codes:
#   0: Successful extraction.
#   1: An error occurred during extraction.
# ------------------------------------------------------------------
unrar_file() {
    local file_path="$1"
    local directory=$(dirname "$file_path")
    local unrar_options="-inul"  # Default option

    if [ "$VERBOSE" ]; then
        unrar_options="-o+"  # No confirmation prompts
    fi

    if ! has_extraction_marker "$directory"; then
        cd $(dirname "$file_path")
        unrar x "$unrar_options" $(basename "$file_path")
        if [ $? -gt 0 ]; then
            logger "Error extracting ${file_path}"
            return 1
        fi
        mark_extraction_complete "$directory"
        logger "Extraction complete for ${file_path}"
    else
        logger "Skipping unrar for ${file_path} (Already extracted)"
    fi
}

remove_rar() {
    local dir_path="$1"
    if [ "$REMOVE_RAR_FILES" = true ]; then
        find "$dir_path"/ -name "*.r[0-9][0-9]" -type f -exec rm {} \; >/dev/null 2>&1
        rm "$dir_path"/*.rar
        
	logger "Removed .rxx files"
    fi
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        logger "Error: $1 is required but not installed. Aborting."
        exit 1
    }
}

check_command_option() {
    local cmd="$1"
    local option="$2"
    
    if ! "$cmd" $option >/dev/null 2>&1; then
        logger "Error: ${cmd} does not support required option '${option}'. Aborting."
        exit 1
    fi
}

# The macOS stat command behaves differently from the Linux version
# and lacks certain options that are commonly available on Linux systems.
# This includes the -c option for specifying custom output formatting,
# which is available in the Linux version of stat.
#
# So the stat check might fail on BSD-based systems (e.g. macOS)
# TODO: (feat) add BSD stat support
# Workaround is to skip 'should_process_dir()' check
check_dependencies() {
    check_command unrar
    check_command cut
    check_command date
    check_command stat
    check_command cut
    check_command_option stat "-c %Y ."
}

# ------------------------------------------------------------------
# Process archived torrents in the specified directory.
#
# This function searches for files with the ".rar" extension
# in the provided directory. Excluded directories can be
# specified using the EXCLUDED_DIRS array.
#
# Parameters:
#   $1 (optional):
# The directory to search for archived torrents.
# Defaults to the value of the COMPLETED_DIR environment variable.
# ------------------------------------------------------------------
process_archived_torrents(){
    local torrent_dir="${1:-$COMPLETED_DIR}"
    local find_command=("find" "${torrent_dir}" "-name" "*.rar")

    if [ "${#EXCLUDED_DIRS[@]}" -gt 0 ]; then
        local dirs="${EXCLUDED_DIRS[@]}"
        logger "Excluding directories: ${dirs}"
        for excluded_dir in "${EXCLUDED_DIRS[@]}"; do
        find_command+=("-not" "-path" "${torrent_dir}/${excluded_dir}/*")
        done
    fi

    for file_path in $("${find_command[@]}"); do
        local dir_path=$(dirname "$file_path")
        if should_process_directory "$dir_path"; then
            logger "Processing file: ${file_path}"
            unrar_file "$file_path"
        fi
    done
}

main() {

    if [ "$VERBOSE" = true ]; then
        splash
    fi

    check_dependencies
    # If we are invoked from transmission
    if [ -d "$TR_TORRENT_DIR" ]; then
        logger "[Transmission] Processing torrent ${TR_TORRENT_NAME}"
        process_archived_torrents "${TR_TORRENT_DIR}/${TR_TORRENT_NAME}"
    fi
    
    # Only if requested; default is false
    if [ "$P_BATCH" = true ]; then
        process_archived_torrents
    fi
}

main
