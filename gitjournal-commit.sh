#!/bin/bash
command="git commit"
line=1

echo "Dont forget to git add"

# --- Load config ---

CONFIG_FILE="$(dirname "$0")/config.yml"
if [[ -f "$CONFIG_FILE" ]]; then

    # finds the alias line, keep first match, 
    # extract the value after '=' or ':', 
    # removes single and double quotes,
    # removes surrounding whitespace.
    alias_name=$(grep -E '^[[:space:]]*default_alias[[:space:]]*[:=]' "$CONFIG_FILE" 2>/dev/null | head -n1 | cut -d'=' -f2- | cut -d':' -f2- | tr -d '"' | tr -d "'" | xargs)

    # parse default_project
    default_project=$(grep -E '^[[:space:]]*default_project[[:space:]]*[:=]' "$CONFIG_FILE" 2>/dev/null | head -n1 | cut -d'=' -f2- | cut -d':' -f2- | tr -d '"' | tr -d "'" | xargs)

    if [[ -n "$alias_name" ]]; then
        script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
        alias_cmd="alias $alias_name='bash \"$script_path\"'"
        eval "$alias_cmd"
        echo "Created alias in this shell: $alias_name -> $script_path"

        # TODO: check if alias existsm right now it just appends
        if [[ ! -e "$HOME/.bashrc" ]]; then
            touch "$HOME/.bashrc" 2>/dev/null || true
        fi
        printf "\n# gitjournal-commit alias\n%s\n" "$alias_cmd" >> "$HOME/.bashrc" 2>/dev/null || true
        echo "Alias appended to ~/.bashrc (no duplicate checks performed)."
    fi
fi

# --- Commit name ---
read -ep "Commit name: " name
command+=" -m \"$name\""

# --- Duration calculation ---
commitTime=$(git log -1 --format="%at")
time=$(date +%s)

duration=$(( (time - commitTime) / 60 ))  # convert seconds → minutes

read -ep "Commit duration: $duration min. Is this correct ? (Y/n) " changeDuration
changeDuration=${changeDuration:-y}

if [[ "$changeDuration" != "y" && "$changeDuration" != "Y" ]]; then
    read -ep "New commit duration (+/-value or absolute): " newDuration

    # If the user typed +X or -X
    if [[ "$newDuration" =~ ^\+[0-9]+$ ]]; then
        duration=$(( duration + ${newDuration:1} ))
    elif [[ "$newDuration" =~ ^-[0-9]+$ ]]; then
        duration=$(( duration - ${newDuration:1} ))
    elif [[ "$newDuration" =~ ^[0-9]+$ ]]; then
        duration=$newDuration
    else
        echo "Invalid duration format."
        exit 1
    fi
fi

echo "Final duration: $duration"

# --- Status ---
read -ep "Commit status: " status
command+=" -m \"[$duration] [$status]\""

# --- Project ---
if [[ -n "$default_project" ]]; then
    # Enter = use default, y = enter a different project name, N = skip
    read -ep "Add project? [Enter = use default '$default_project', y = different, N = skip]: " proj_choice
    if [[ -z "$proj_choice" ]]; then
        addProject="$default_project"
    elif [[ "$proj_choice" =~ ^[nN]$ ]]; then
        addProject=""
    elif [[ "$proj_choice" =~ ^[yY]$ ]]; then
        read -ep "Project name: " addProject
        addProject=${addProject:-$default_project}
    else
        # if user types name
        addProject="$proj_choice"
    fi
else
    read -ep "Do you want to add a project? (y/N): " proj_choice
    proj_choice=${proj_choice:-n}
    if [[ "$proj_choice" =~ ^[yY]$ ]]; then
        read -ep "Project name: " addProject
    else
        addProject=""
    fi
fi

if [[ -n "$addProject" ]]; then
    command+=" -m \"{$addProject}\""
fi

# --- Description (optional) ---
read -ep "Do you want to add a description (y/N): " addDescription
addDescription=${addDescription:-n}

if [[ "$addDescription" =~ ^[yY]$ ]]; then
    while [[ "$addDescription" =~ ^[yY]$ ]]; do
        read -ep "Line $line of the description: " desc
        command+=" -m \"$desc\""
        ((line++))
        read -ep "Add another line? (Y/n): " addDescription
		addDescription=${addDescription:-y}
    done
fi
# Regex works with a : b or a = b
# b can be true, 1, y, case insensitive
if [[ -f "$CONFIG_FILE" ]] && grep -Eiq '^\s*allow_empty\s*[:=]\s*(true|1|y)\b' "$CONFIG_FILE"; then
    command+=" --allow-empty"
fi

echo "$command"
eval "$command"

echo ""
echo "If mistake:"
echo "  git reset --soft HEAD~1 to delete last commit"
echo "  git commit --rebase to modify last commit"