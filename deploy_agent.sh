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
