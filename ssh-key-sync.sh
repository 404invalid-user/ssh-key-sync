#!/bin/bash

GIT_BASE="https://github.com"
CONFIG_FILE="/etc/ssh/sshd_config.d/ssh-key-sync.conf"
SSH_DIR="$HOME/.ssh"

# checks
mkdir -p "$SSH_DIR"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR]: Config file not found: $CONFIG_FILE"
  exit 1
fi

git_users=()

# Parse SSHD config for .keys users
while IFS= read -r line; do
  # skip lines not starting with AuthorizedKeysFile
  [[ ! "$line" =~ ^[[:space:]]*AuthorizedKeysFile ]] && continue

  # fix space strip AuthorizedKeysFile
  line=$(echo "$line" | tr -s ' ')
  line=${line#AuthorizedKeysFile }

  # split each .keys path statgin with .ssh/
  for path in $line; do
    if [[ $path == .ssh/*.keys ]]; then
      file=${path##*/}             # strip directory
      username=${file%.keys}       # strip extension
      [[ "$username" == "%u" ]] && continue
      git_users+=("$username")
    fi
  done
done < "$CONFIG_FILE"

mapfile -t git_users < <(printf "%s\n" "${git_users[@]}" | sort -u)
echo "[INFO]: Users detected: ${git_users[*]}"

if (( ${#git_users[@]} == 0 )); then
  echo "[INFO]: No users detected, exiting."
  exit 0
fi

MAX_BYTES=104857600  # 100 MiB

# Loop over users and fetch their keys
for user in "${git_users[@]}"; do
  DEST_FILE="$SSH_DIR/${user}.keys"

  #store body in a temp file
  tmp_file=$(mktemp)

  http_status=$(curl -sSL --max-filesize "$MAX_BYTES" -w "%{http_code}" -o "$tmp_file" "$GIT_BASE/${user}.keys")
  curl_exit=$?

  if [[ $curl_exit -eq 63 || $(stat -c%s "$tmp_file") > MAX_BYTES ]]; then
    echo "[WARNING]: Keys for '$user' exceed 100MB, keeping existing file."
    rm -f "$tmp_file"
    continue
  elif [[ $curl_exit -ne 0 ]]; then
    echo "[WARNING]: curl failed for '$user' (exit code $curl_exit), keeping existing file."
    rm -f "$tmp_file"
    continue
  fi

  if [[ "$http_status" != "200" ]]; then
    echo "[WARNING]: Server returned HTTP $http_status for '$user', keeping existing file."
    rm -f "$tmp_file"
    continue
  fi


  # Check if file is empty or only whitespace
  if [[ -s "$tmp_file" ]]; then
    if [[ -z $(tr -d '[:space:]' < "$tmp_file") ]]; then
      echo "[INFO]: No keys returned for '$user', keeping existing file."
      rm -f "$tmp_file"
      continue
    fi
  else
    echo "[INFO]: No keys returned for '$user', keeping existing file."
    rm -f "$tmp_file"
    continue
  fi

  mv "$tmp_file" "$DEST_FILE"
  chmod 600 "$DEST_FILE"
  echo "[OK] Updated $DEST_FILE"
done

echo "[INFO]: Key sync complete."
