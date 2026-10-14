#!/usr/bin/env bash
# Absolute path of the folder this script is in, so templates/ is found however the script is launched
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Helpers for consistent output: info for progress, error for problems (sent to stderr)
info() {
    echo "[INFO] $1"
}

error(){
    echo "Error: $1" >&2
}

# Pre-flight: check python3, zip and the template files exist before deploy creates anything
preflight() {
    local missing=0 #Uses a variable local to the function to return whether there's something missing or not
    if command -v python3 >/dev/null; then
        info "Python is installed!"
        python3 --version
    else
        error "Python is not installed."
        missing=1
    fi

    if command -v zip >/dev/null; then
        info "Zip is installed!"
    else
        error "Zip is not installed."
        missing=1
    fi

    for file_name in attendance_checker.py config.json assets.csv
    do
        if [ -f "$TEMPLATES_DIR/$file_name" ]; then
            info "$file_name found"
        else 
            error "Template missing: $file_name"
            missing=1
        fi
    done
    return "$missing"
}

# Create the directories, files and populate them
deploy(){
    preflight || return 1   #If preflight fails, stop deploy here and go back to the menu
    info "Preflight checks passed"
    # Validates user entry in case users try to use the wrong folder naming convention
    read -r -p "Enter a project name(letters, digits, _ or -): " name 
    if [[ ! $name =~ ^[A-Za-z0-9_-]+$ ]]; then
        error "Invalid name '$name': use only letters, digits, _ or -"
        return 1
    fi
    # In case file permissions are denied, we get a clear error message
    if [ ! -w . ]; then
        error "Cannot write to current folder: $PWD"
        return 1
    fi
    if [ -d "attendance_tracker_$name" ]; then 
        # Folder already exists: ask before deleting it, so a project is never overwritten silently
        read -r -p "Would you like to overwrite(y/n): " choice
        if [ "${choice,,}" == "y" ]; then
            rm -rf "attendance_tracker_$name"
            info "Removed existing folder attendance_tracker_$name"
        else 
            error "Folder kept, deploy cancelled"
            return 1
        fi
    fi
    mkdir -p "attendance_tracker_$name"/Helpers || { error "Could not create Helpers folder"; return 1; }
    mkdir -p "attendance_tracker_$name"/reports || { error "Could not create reports folder"; return 1; }
    info "Created attendance_tracker_$name/ with Helpers/ and reports/"
}

# Runs attendance_checker.py
run(){
    info "Run: not implemented yet"
}

# After running, archive the generated logs
archive(){
    info "Archive: not implemented yet"
}

# Menu loop for the user
while true
do 
    echo "Deploy, Run, Archive, Quit"
    read -r -p "Select an option: " action || break #exits cleanly on Ctrl+D instead of looping forever
    case "${action,,}" in #lowercases the input so mixed case or uppercase user entries will still work
        deploy)
            deploy
            ;;
        run)
            run
            ;;
        archive)
            archive
            ;;
        quit)
            info "Goodbye"
            break
            ;;
        *)
            error "Invalid choice. Pick one of the options."
            ;;

    esac
done
