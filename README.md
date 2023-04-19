# One Thousand Uncles

A special PVE gamemode designed by Uncle Dane for Uncletopia servers. The BLUE team consisting of up to 12 human players is faced with an army of Engineer Bots on RED team. The goal of the gamemode is to fight through the defenses of the Engineer bots and win the round. Best played on Payload and A/D maps.  

## Requires

- TF2Attributes (https://github.com/FlaminSarge/tf2attributes)
- TF2 Econ Data (https://github.com/nosoop/SM-TFEconData)
- TF2Items (https://github.com/asherkin/TF2Items)

## Update History

### 0.6.0
- Attempt to ensure that players are only on the team that they are allowed to be on.
- Rount timer is now a stopwatch that shows how much has passed during a round.
- Delete edict entities that appear from dying engineers during round end.

### 0.5.0
- Show message when someone tries to join BLUE
- Fixed some bugs with player limits.

### 0.4.0
- Added sm_danepve_respawn_bots_on_round_end (default: 0) to stop bots from respawning during round end. 
- Added sm_danepve_max_playing_humans (default: 12), sm_danepve_max_connected_humans (default: 16).
- sm_danepve_max_connected_humans affects visible max players.
- Increased Engineer Bots's max health to 180.

### 0.3.0
- Round timer is now infinite.
- Bots insta remove sappers.
- Changed "fire rate bonus" wrench stat to +40%
- Redo unusual effect to Uncle Dane loadout

### 0.2.1

- Introduced the max connected humans limit. (12 by default)
- Fixed SourceTV being treated as the bot.
- Bots have killstreaks now.
- Bots respawn immediately.
- Players are now forced to BLUE team.

### 0.2.0

- Bot count now uses tf_bot_quota
- Added support for weapon customization
- Golden Pan Easter Egg!
- Switch teams is disabled.

### 0.1.0

- Initial Release
