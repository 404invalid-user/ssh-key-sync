#!/bin/bash

set -e

if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

users=()
allow_pw_auth=false

is_valid_username() {
    local u="$1"
    # GitHub usernames: alphanumeric + hyphen, cannot start/end with hyphen, 1-39 chars
    if [[ "$u" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# pars args
for arg in "$@"; do
  case "$arg" in -u=*|--user=*)
    username="${arg#*=}"
    if is_valid_username "$username"; then
      users+=("$username")
    else
      echo "Warning: Skipping invalid username '$username'"
    fi
    ;;
    --allow-pw-auth=true)
    allow_pw_auth=true
    ;;
    --help|-h)
    echo "Usage: $0 --user=username... [--allow-pw-auth
=true]"
    echo
    echo "Options:"
    echo "  -u=username, --user=username  Specify a GitHub-style username to include."
    echo "  --allow-pw-auth=true          Allow password authentication (not recommended)."
    echo "  -h, --help                    Show this help message and exit."
    exit 0
    ;;
    *)
      echo "Warning: Unknown argument '$arg'"
    ;;
  esac
done

if [[ "${#users[@]}" -eq 0 ]]; then
  echo "Error: No valid users provided. use -h"
  exit 1
fi

akf=".ssh/authorized_keys"
for u in "${users[@]}"; do
  akf+=" .ssh/${u}.keys"
done

conf_file="/etc/ssh/sshd_config.d/ssh-key-sync.conf"
{
  echo "AuthorizedKeysFile $akf"
  if $allow_pw_auth; then
    echo "#PasswordAuthentication no"
  else
    echo "PasswordAuthentication no"
  fi
  echo "PubkeyAuthentication yes"
} > "$conf_file"

echo "Config written to $conf_file successfully."

# Download main script
tmpfile=$(mktemp /tmp/ssh-key-sync.XXXXXX.sh)
curl -fsSL https://raw.githubusercontent.com/404invalid-user/ssh-key-sync/refs/heads/main/ssh-key-sync.sh -o "$tmpfile"

echo "Downloaded ssh-key-sync script to temporary file: $tmpfile"
echo "Please review the file manually to ensure it is safe."

mv "$tmpfile" /usr/local/bin/ssh-key-sync.sh
chmod +x /usr/local/bin/ssh-key-sync.sh
echo "Moved to /usr/local/bin/ssh-key-sync.sh and made it executable."
echo ""
echo "To set up a cron job to run every 15 minutes, (make sure to switch to correct user eg invaliduser) use this one-liner:"
echo "  echo 'WARNING: This will run as root. Are you sure you want it?'; read -p 'Press ENTER to continue or Ctrl+C to abort'; (crontab -l 2>/dev/null; echo '*/15 * * * * /usr/local/bin/ssh-key-sync.sh') | crontab -"
