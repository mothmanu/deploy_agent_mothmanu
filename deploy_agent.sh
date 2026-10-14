#!/usr/bin/env bash
# Absolute path of the folder this script is in, so templates/ is found however the script is launched
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
# Sample names for Option B. Every first name is paired with every last name,
# so 10 x 10 = 100 unique students, enough for the 1-50 limit
first_names=(Ada Oyin Aisha Chidi Tunde Ngozi Emeka Zainab Ifeoma Bola)
last_names=(Obi Adeleke Hauwa Okafor Bello Eze Adebayo Musa Danjuma Ibrahim)

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

# Handles Ctrl+C or Ctrl+Z presses. Only active while deploy is creating the project
on_interrupt(){
    echo
    error "Deployment interrupted. Archiving incomplete project..."
    if [ -d "attendance_tracker_$name" ]; then
        rm -f "attendance_tracker_${name}_archive.zip"
        if zip -r -q "attendance_tracker_${name}_archive.zip" "attendance_tracker_$name"; then    
            rm -rf "attendance_tracker_$name"
            info "Removed incomplete folder attendance_tracker_$name"
            info "Zip succeeded. It is located at $PWD/attendance_tracker_${name}_archive.zip"
        else
            error "Could not create archive, folder left in place"
        fi
    fi
    exit 130
}

# Offers to change the warning/failure thresholds in the deployed config.json.
# Called from deploy while the trap is still active, so Ctrl+C or Ctrl+D here also archives the project.
update_thresholds(){
    local config="$1"
    local answer warning failure
    read -r -p "Update attendance thresholds? (y/n): " answer || on_interrupt
    if [ "${answer,,}" != "y" ]; then
        info "Keeping default thresholds (warning 75, failure 50)"
        return 0
    fi

    # Ask for both values until every check passes. Nothing is written to the file before that.
    while true
    do
        read -r -p "Warning threshold % [75]: " warning || on_interrupt
        read -r -p "Failure threshold % [50]: " failure || on_interrupt
        # ${var:-default} uses the default when the user just presses Enter
        warning=${warning:-75}
        failure=${failure:-50}

        # Whole numbers only, with no leading zeros: bash reads 08 as octal, and 08 is invalid JSON
        if [[ ! $warning =~ ^(0|[1-9][0-9]*)$ || ! $failure =~ ^(0|[1-9][0-9]*)$ ]]; then
            error "Thresholds must be whole numbers like 75 (got '$warning' and '$failure')"
        # They are percentages, so they cannot go above 100
        elif (( warning > 100 || failure > 100 )); then
            error "Thresholds must be between 0 and 100"
        # A student should be warned before they fail, so failure must be lower than warning
        elif (( failure >= warning )); then
            error "Failure threshold ($failure) must be lower than warning threshold ($warning)"
        else
            break
        fi
    done

    # Replace only the number after each key. \1 puts back the key and its spacing,
    # so the file is not reformatted or reordered. The quotes switch from '...' to "$var"
    # because bash does not expand variables inside single quotes.
    sed -i -E \
        -e 's/("warning":[[:space:]]*)[0-9]+/\1'"$warning"'/' \
        -e 's/("failure":[[:space:]]*)[0-9]+/\1'"$failure"'/' \
        "$config" || { error "Could not update $config"; return 1; }

    # sed succeeds even when its pattern matches nothing, so check the new values are really in the file
    if ! grep -Eq "\"warning\":[[:space:]]*$warning([^0-9]|$)" "$config" ||
       ! grep -Eq "\"failure\":[[:space:]]*$failure([^0-9]|$)" "$config"; then
        error "New thresholds were not found in $config"
        return 1
    fi
    info "Thresholds updated:"
    grep -E '"(warning|failure)"' "$config"
    # GNU sed -i keeps the file's permissions, so this should still show owner-only (600)
    stat -c '%A %n' "$config"
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
    # Trap is set after the overwrite question so it never deletes a project that already existed
    trap on_interrupt INT TSTP
    mkdir -p "attendance_tracker_$name"/Helpers || { error "Could not create Helpers folder"; trap - INT TSTP; return 1; }
    mkdir -p "attendance_tracker_$name"/reports || { error "Could not create reports folder"; trap - INT TSTP; return 1; }
    info "Created attendance_tracker_$name/ with Helpers/ and reports/"
    # Copies files from template unchanged into target directory
    cp "$TEMPLATES_DIR/attendance_checker.py" "attendance_tracker_$name" || { error "Could not copy py file"; trap - INT TSTP; return 1; }
    cp "$TEMPLATES_DIR/config.json" "attendance_tracker_$name/Helpers" || { error "Could not copy json file"; trap - INT TSTP; return 1; }

    while true
    do
        # Ask the user whether they want to copy data from template or generate a fresh roster
        read -r -p "Roster: (A) copy from template, (B) generate fresh: " roster_option || on_interrupt
        if [ "${roster_option,,}" == "a" ]; then
            while true
            do
                read -r -p "How many students(1-10): " count || on_interrupt
                if [[ ! $count =~ ^[0-9]+$ ]]; then
                    error "Invalid entry. Enter a number"
                elif (( count >= 1 && count <= 10 )); then #The template only has 10 students
                    info "Number is in range."
                    break
                else
                    error "Number is out of range"
                fi
            done
            # The header line means we have to use count + 1 and total session isn't changed because these rows already have 4 prior sessions
            head -n $((count + 1)) "$TEMPLATES_DIR/assets.csv" > "attendance_tracker_$name/Helpers/assets.csv" || { error "Could not create assets.csv"; trap - INT TSTP; return 1; }
            info "Copied $count students from template (total_sessions stays 5)"
            break
        elif [ "${roster_option,,}" == "b" ]; then
            # Ask again until we get a whole number from 1 to 50
            while true
            do 
                read -r -p "How many students(1-50): " count || on_interrupt
                if [[ $count =~ ^[0-9]+$ ]] && (( count >= 1 && count <= 50 )); then
                    break
                fi
                error "Enter a whole number from 1 to 50"
            done

            roster="attendance_tracker_$name/Helpers/assets.csv"
            # Header must match the template exactly, with no spaces after the commas
            echo "Email,Names,Attendance Count,Absence Count" > "$roster"

            num_first=${#first_names[@]}
            num_last=${#last_names[@]}
            for (( i = 0; i < count; i++ ))
            do
                # First name changes every row; last name changes once per full cycle of first names
                first=${first_names[i % num_first]}
                last=${last_names[(i / num_first) % num_last]}
                # New students start with 0 attended and 0 absent
                echo "${first,,}.${last,,}@example.com,$first $last,0,0" >> "$roster"
            done

            # Fresh roster has no prior sessions, so today is session 1.
            # \1 keeps the key and spacing; the 1 after it is the new value
            sed -i -E 's/("total_sessions":[[:space:]]*)[0-9]+/\11/' "attendance_tracker_$name/Helpers/config.json"
            info "Generated $count students in $roster and set total_sessions to 1"
            break
        else
            error "Invalid option"
        fi
    done
    # Makes the app executable
    chmod +x "attendance_tracker_$name/attendance_checker.py" || { error "Could not make python file executable"; trap - INT TSTP; return 1; }
    # Other users shouldn't be able to read or change grading thresholds in the config
    chmod 600 "attendance_tracker_$name/Helpers/config.json" || { error "Could not restrict config.json permissions"; trap - INT TSTP; return 1; }
    info "Permissions set:"
    stat -c '%A %n' "attendance_tracker_$name/attendance_checker.py" "attendance_tracker_$name/Helpers/config.json"
    # Optionally change the alert thresholds. This runs before the trap is removed, so it is still protected.
    update_thresholds "attendance_tracker_$name/Helpers/config.json" || { trap - INT TSTP; return 1; }
    trap - INT TSTP #Turn the trap off here so Ctrl+C later doesn't archive and delete a finished project.
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
