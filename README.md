# NBA Schedule Widget for KDE Plasma 6

![Widget Preview](images/preview/preview.png)
## Install Or Update

From the repo root, run:

```bash
./devInstall.sh
```

##Testing Commands
Test in window mode:

```bash
plasmawindowed org.kde.plasma.nba-schedule
```

Update installed widget + refresh plasma: 

```bash
kpackagetool6 --type Plasma/Applet --upgrade package
systemctl --user restart plasma-plasmashell.service
```