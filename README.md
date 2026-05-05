# NBA Schedule Widget for KDE Plasma 6

**Requirements:** balldontlie.io API key  
*TODO: transfer to espn api*

## Setup
Add your API key to `.env`:
```bash
echo "NBA_API_KEY=your_key_here" > .env
```

## Install/Update
```bash
./devInstall.sh
```

## Standalone Window 
```bash
plasmawindowed org.kde.plasma.nba-schedule
```

## Reload Plasma (Update)
```bash
systemctl --user restart plasma-plasmashell.service
```

## TODO: Config
Right-click widget > **Configure**
