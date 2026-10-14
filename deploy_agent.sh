#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"


info() {
    echo "[INFO] $1"
}

error(){
    echo "Error: $1" >&2
}

deploy(){
    info "Deploy: not implemented yet"
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
