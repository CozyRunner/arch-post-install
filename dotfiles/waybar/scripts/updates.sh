#!/usr/bin/env bash

# Arch + AUR update checker for Waybar/Hyprland
# Shows:
#   text     -> repo_count|aur_count
#   tooltip  -> full package list
#   class    -> pending / updated

set -u

# ---------- Helpers ----------

get_repo_updates() {
  checkupdates 2>/dev/null || true
}

get_aur_updates() {
  yay -Qua 2>/dev/null || true
}

escape_json() {
  sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g'
}

# ---------- Fetch Updates ----------

repo_list="$(get_repo_updates)"
aur_list="$(get_aur_updates)"

# Count only non-empty lines
repo_count=$(printf "%s\n" "$repo_list" | sed '/^\s*$/d' | wc -l)
aur_count=$(printf "%s\n" "$aur_list" | sed '/^\s*$/d' | wc -l)

# Fix empty output edge case
[[ -z "$repo_list" ]] && repo_count=0
[[ -z "$aur_list" ]] && aur_count=0

total=$((repo_count + aur_count))

# ---------- Status Class ----------

if ((total > 0)); then
  class="pending"
else
  class="updated"
fi

# ---------- Tooltip ----------

tooltip=""

if ((repo_count > 0)); then
  tooltip+="󰮯 Official Repo Updates (${repo_count})\n"
  tooltip+="${repo_list}\n\n"
fi

if ((aur_count > 0)); then
  tooltip+="󰣇 AUR Updates (${aur_count})\n"
  tooltip+="${aur_list}\n"
fi

if ((total == 0)); then
  tooltip="System is fully updated"
fi

tooltip=$(printf "%b" "$tooltip" | escape_json)

# ---------- Display Text ----------

text="${repo_count}|${aur_count}"

# ---------- JSON Output ----------

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
  "$text" \
  "$tooltip" \
  "$class"
