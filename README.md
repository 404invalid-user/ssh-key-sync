# ssh-key-sync
Sync your ssh keys from your git provider to your linux server running openssh or other that support it's config format


## Supported os
Most if not all Debain based OS


## install


download setup script
```bash
curl -fsSL https://raw.githubusercontent.com/404invalid-user/ssh-key-sync/refs/heads/main/setup.sh -o setup.sh
```
verify file content

run setup script (as root or sudo)
```bash
bash setup.sh -u=404invalid-user
```

restart your ssh service
```bash
systemctl restart ssh
```

remove unneeded script
```bash
rm setup.sh
```

become your regular user and setup cron (replace invaliduser with your name)
```
su invaliduser
(crontab -l 2>/dev/null; echo '*/15 * * * * /usr/local/bin/ssh-key-sync.sh') | crontab -
```
