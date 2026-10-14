# deploy_agent_mothmanu

`deploy_agent.sh` bootstraps the **Student Attendance Tracker** (`attendance_checker.py`).
It has three features: **Deploy**, **Run** and **Archive**. While a deployment is in
progress, it also handles Ctrl+C and Ctrl+Z cleanly.

---

## Demo Video

**Watch the walkthrough:** https://youtu.be/fYbHWtyHX-I

The video covers:
- the approach and how the script is built, section by section
- a live deploy with Option A and a threshold update
- a short marking session, then archiving the logs
- edge cases: invalid input, an existing folder, a missing `absent.log`
- interrupting a deploy with Ctrl+C, then checking the `.zip` and that the folder was removed

---

## Requirements

- Linux or WSL (Ubuntu). Run the script from the Linux filesystem (for example `~/`), not `/mnt/c/...`,
  because `chmod` has no effect on Windows drives mounted in WSL.
- `bash`, `python3` and `zip`. Deploy checks for `python3` and `zip` before it creates anything.
- The `templates/` folder must sit next to `deploy_agent.sh`. It holds the three source files, which are never modified:
  `attendance_checker.py`, `assets.csv` and `config.json`.

## How to run

```bash
git clone https://github.com/mothmanu/deploy_agent_mothmanu.git
cd deploy_agent_mothmanu
chmod +x deploy_agent.sh   # only needed if the execute bit was lost
./deploy_agent.sh
```

The script finds `templates/` relative to its own location (`$(dirname "$0")`), so you can also
start it from another folder, for example `bash deploy_agent_mothmanu/deploy_agent.sh`.
Projects are created in, and looked up from, **the folder you run the script from**.

## Selecting a feature: interactive menu

The script shows a menu and loops until you choose **Quit**:

```
Deploy, Run, Archive, Quit
Select an option:
```

Type one of the four words. Case does not matter (`deploy`, `Deploy` and `DEPLOY` all work).
An invalid choice prints an error and shows the menu again. Ctrl+D at the menu exits cleanly.

| Option | What it does |
|---|---|
| **Deploy** | Builds a new `attendance_tracker_<name>/` project, then starts the app to verify it |
| **Run** | Lists deployed projects, asks which one, and starts the app inside it |
| **Archive** | Lists deployed projects, asks which one, and archives its logs |
| **Quit** | Exits |

---

## Feature 1: Deploy

Steps, in order:

1. **Pre-flight checks.** Checks that `python3` and `zip` are installed, prints `python3 --version`, and checks that the
   three template files exist. If anything is missing, every problem is listed and deploy stops before creating anything.
2. **Project name.** Asks for a name and creates `attendance_tracker_<name>/`. Only letters, digits, `_` and `-` are allowed,
   which rejects empty names, spaces and paths such as `../`. Deploy also stops with a clear message if the current folder is not writable.
3. **Existing folder.** If `attendance_tracker_<name>/` already exists, the script asks before overwriting it.
   `y` deletes the old folder and starts fresh. Any other answer cancels deploy and leaves the folder untouched.
4. **Structure.** Creates the layout the app expects. The app opens these paths relative to the project root:
   ```
   attendance_tracker_<name>/
   ├── attendance_checker.py
   ├── Helpers/
   │   ├── assets.csv
   │   └── config.json
   └── reports/
   ```
   `attendance_checker.py` and `config.json` are copied unchanged from `templates/`.
5. **Roster (`Helpers/assets.csv`).** You choose how to build it:
   - **Option A, copy from template:** enter 1–10 students (the template has 10). The header plus that many rows are copied with `head`.
   - **Option B, generate fresh:** enter 1–50 students. Rows are built from two arrays of 10 first names and 10 last names.
     Every first name is paired with every last name, giving 100 unique names and emails. Every student starts at `0,0`.
6. **Permissions.** `chmod +x attendance_checker.py`, and `chmod 600 Helpers/config.json` (owner read/write only, because it
   holds grading thresholds). The resulting permissions are printed:
   ```
   -rwxr-xr-x attendance_tracker_demo/attendance_checker.py
   -rw------- attendance_tracker_demo/Helpers/config.json
   ```
   `attendance_checker.py` has no shebang line, so the script starts it with `python3 attendance_checker.py`.
7. **Threshold update** (optional, see below).
8. **Verification.** Deploy finishes by running the app (Feature 2). A successful start proves that the structure, roster and config work together.

### Why `total_sessions` is 5 or 1

The app calculates each student's percentage as `attended / total_sessions`, where `total_sessions` includes **today's** session.
So it must always be **one more than the prior sessions in the roster** (Attendance Count + Absence Count).

| Roster | Prior sessions per student | `total_sessions` |
|---|---|---|
| Option A (template rows) | 4 | **5**, the template's value, left unchanged |
| Option B (fresh rows, `0,0`) | 0 | **1**, set automatically with `sed` on the deployed copy |

Without the Option B change, a student who is present today would show 1/5 = 20% and be flagged as failing.
No prompt is needed: each option ships a consistent value.

### How the threshold update works

After the permissions are set, deploy asks `Update attendance thresholds? (y/n)`.

- **Any answer other than `y`** keeps the defaults (warning 75, failure 50).
- **`y`** asks for both values. The default is shown in brackets, and pressing Enter uses it (`${warning:-75}`).
- **Validation before anything is written.** The script asks again until all of these pass:
  - Whole numbers only, with no leading zeros. `abc`, `-5` and `08` are rejected. `08` would be read as octal by bash and is invalid JSON.
  - 0–100, because the values are percentages.
  - Failure must be **lower** than warning.
- **Editing with `sed -i`** changes only the number after each key in the **deployed** `Helpers/config.json`:
  ```bash
  sed -i -E 's/("warning":[[:space:]]*)[0-9]+/\1'"$warning"'/'
  ```
  `\1` puts back the key and its spacing, so the file is not reformatted or reordered.
- **Checked afterwards.** `sed` succeeds even when nothing matches, so the script greps the file for the new values,
  prints them, and shows that `config.json` is still `-rw-------`.

---

## Feature 2: Run

Lists the deployed `attendance_tracker_*` folders and asks for a project name. Before starting the app, it checks that
`attendance_checker.py`, `Helpers/assets.csv`, `Helpers/config.json` and `reports/` all exist. Then it runs:

```bash
( cd attendance_tracker_<name> && python3 attendance_checker.py )
```

The `( )` subshell does the `cd`, so the script's own working folder does not change. The app is interactive: the instructor
marks each student `P` or `A`. When the app exits, the script reports the result:

- exit code `0`: marking finished, logs are in `reports/`
- exit code `130`: the instructor pressed Ctrl+C (the app saves the students marked so far)

Either way, the script returns to the menu.

---

## Feature 3: Archive

Lists the deployed projects, asks which one, and **moves** each log into its own archive folder with a timestamp:

```
attendance_tracker_<name>/
└── archives/
    ├── attendance/
    │   └── attendance_20261014_223953.log
    └── absent/
        └── absent_20261014_223953.log
```

- **Timestamp:** `date +%Y%m%d_%H%M%S` (YYYYMMDD_HHMMSS) is taken once per archive run, so both logs from the same session share it
  and every archived file is unique and traceable.
- **Move rather than copy:** the app *appends* to its logs. Moving them means the next session starts with fresh logs, like log rotation.
- **Missing logs are not errors.** `absent.log` is only created when at least one student was absent. A missing log is reported
  and skipped:
  ```
  [INFO] Archived attendance.log -> attendance_tracker_x1/archives/attendance/attendance_20261014_223955.log
  [INFO] No absent.log in attendance_tracker_x1/reports/, skipped
  ```
- An existing archive file is never overwritten.

---

## Ctrl+C / Ctrl+Z during deployment (signal trap)

### When the trap is active

`trap on_interrupt INT TSTP` is set **after** the overwrite question and removed with `trap - INT TSTP` **before** the app starts.

- **Set after the overwrite question:** pressing Ctrl+C while deciding whether to overwrite can never delete a project that already existed.
- **Removed before the app starts:** Ctrl+C during a marking session is handled by the app itself and never archives or deletes a finished project.

### What happens on Ctrl+C (SIGINT) or Ctrl+Z (SIGTSTP)

The archive trigger runs these steps:

1. Prints `Deployment interrupted. Archiving incomplete project...`
2. Deletes any old `attendance_tracker_<name>_archive.zip`. Otherwise `zip` would add to it instead of replacing it.
3. Zips whatever exists of `attendance_tracker_<name>/` into `attendance_tracker_<name>_archive.zip`, next to the script's working folder.
4. **Only if the zip succeeded**, deletes the incomplete folder, so no half-made project is left behind.
   If the zip fails, the folder is kept and an error is shown.
5. Exits with code `130`.

Ctrl+D (end of input) at any deploy prompt after this point is handled the same way, so the script never loops forever on empty input.

### How to test it

Deployment itself takes under a second, so press the keys while deploy is **waiting at a prompt after the folder is created**:
the roster question `(A)/(B)`, the student count, or the threshold prompts.

```bash
./deploy_agent.sh
# Deploy -> name: test -> roster: b -> at "How many students(1-50):" press Ctrl+C
ls                                       # attendance_tracker_test_archive.zip, no attendance_tracker_test/
unzip -l attendance_tracker_test_archive.zip
```

Example output after interrupting at the student-count prompt:

```
Error: Deployment interrupted. Archiving incomplete project...
[INFO] Removed incomplete folder attendance_tracker_test
[INFO] Zip succeeded. It is located at .../attendance_tracker_test_archive.zip

  Length      Date    Time    Name
---------  ---------- -----   ----
        0  2026-10-14 22:43   attendance_tracker_test/
     8147  2026-10-14 22:43   attendance_tracker_test/attendance_checker.py
        0  2026-10-14 22:43   attendance_tracker_test/reports/
        0  2026-10-14 22:43   attendance_tracker_test/Helpers/
      123  2026-10-14 22:43   attendance_tracker_test/Helpers/config.json
```

**What the zip contains:** exactly what had been created when the signal arrived. Interrupted at the roster prompt, it holds the
folders, `attendance_checker.py` and `config.json`. Interrupted at the threshold prompts, it also holds `assets.csv`.
Repeat the test with **Ctrl+Z**: the result is the same, and no stopped job is left behind (`jobs` is empty).

---

## How I tested

| Area | Test | Expected result |
|---|---|---|
| Pre-flight | Temporarily rename `templates/config.json`, or misspell `zip` in the check | Error lists what is missing and deploy stops |
| Name | Empty, `a b`, `x/y`, `../evil`, `name!` | Rejected with "Invalid name" |
| Existing folder | Deploy the same name twice, answer `n` / Enter / `y` | `n` and Enter keep the folder, `y` recreates it |
| Permission denied | Run inside a folder made with `chmod 555` | "Cannot write to current folder" |
| Option A | 3 students; 10 students; `0`, `11`, `abc` | Header + N rows, `total_sessions` 5; invalid counts asked again |
| Option B | 5 students; 50 students | All `0,0`, `total_sessions` 1, no duplicate emails (`cut -d, -f1 Helpers/assets.csv \| sort \| uniq -d` prints nothing) |
| Permissions | `stat -c '%A %n'` after deploy | `-rwxr-xr-x` for the app, `-rw-------` for the config |
| Thresholds | `n`; Enter twice; `abc`, `150`, `-5`, `08`, failure ≥ warning; then `80`/`40` | Defaults kept or invalid values asked again; `diff templates/config.json <project>/Helpers/config.json` shows only the two numbers changed |
| Signals | Ctrl+C and Ctrl+Z at the count prompt; Ctrl+C at the overwrite prompt | Zip created and folder removed; an existing project is untouched |
| Trap removed | Ctrl+C during a marking session | Script returns to the menu, project is **not** zipped or deleted |
| Run | Valid project; `../x`; project with `config.json` deleted | App starts; "No project called…"; "missing, deploy again" |
| Archive | After a session with an absence; with nobody absent; twice | Both logs archived; `absent.log` skipped; distinct timestamped files |

Deployed structure after a deploy (Option A, 3 students, thresholds 80/40) and one marking session:

```
$ find attendance_tracker_demo | sort
attendance_tracker_demo
attendance_tracker_demo/Helpers
attendance_tracker_demo/Helpers/assets.csv
attendance_tracker_demo/Helpers/config.json
attendance_tracker_demo/attendance_checker.py
attendance_tracker_demo/reports
attendance_tracker_demo/reports/absent.log
attendance_tracker_demo/reports/attendance.log
```

---

## Repository layout and workflow

```
deploy_agent_mothmanu/
├── deploy_agent.sh
├── README.md
├── .gitignore        # ignores generated attendance_tracker_* folders and *_archive.zip files
├── .gitattributes    # forces LF line endings so the script runs on Linux
└── templates/
    ├── attendance_checker.py
    ├── assets.csv
    └── config.json
```

Each feature was built on its own branch and merged into `main` through a pull request:
`feature/skeleton` → `feature/deploy` → `feature/signal-trap` → `feature/deploy_files` → `feature/run` → `feature/archive` → `docs/readme`.
