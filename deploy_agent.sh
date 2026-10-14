#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"


info() {
    echo "[INFO] $1"
}

error(){
    echo "Error: $1" >&2
}

preflight() {
    local missing=0
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

deploy(){
    preflight || return 1
    info "Preflight checks passed"
}

run(){
    info "Run: not implemented yet"
}

archive(){
    info "Archive: not implemented yet"
}

while true
do 
    echo "Deploy, Run, Archive, Quit"
    read -r -p "Select an option: " action || break
    case "${action,,}" in 
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
