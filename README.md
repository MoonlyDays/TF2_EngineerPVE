# One Thousand Engineers

A special PVE gamemode designed by Uncle Dane for Uncletopia servers. The BLUE team consisting of up to 12 human players is faced with an army of Engineer Bots on RED team. The goal of the gamemode is to fight through the defenses of the Engineer bots and win the round. Best played on Payload and A/D maps.  

## ConVars
- `sm_danepve_allow_respawnroom_build` (default: 1) - allows human engineers to build in spawnrooms.
- `sm_danepve_max_playing_humans` (default: 12) - maximum amount of humans that are allowed to be playing at the same time.
- `sm_danepve_max_connected_humans` (default: 16) - maximum amount of humans that are allowed to connect.
- `sm_danepve_bot_sapper_insta_remove` (default: 1) - will engineer bots insta remove all sappers with one Wrench swing?
- `sm_danepve_respawn_bots_on_round_end` (default: 0) - will engineer bots respawn on round end?
- `sm_danepve_clear_bots_building_gibs` (default: 1) - don't spawn bots building gibs

## Commands
- `sm_danepve_reload` - Reloads the Config
- `sm_becomedanebot` - 🤫

## Requires

- TF2Attributes (https://github.com/FlaminSarge/tf2attributes)
- TF2 Econ Data (https://github.com/nosoop/SM-TFEconData)
- TF2Items (https://github.com/asherkin/TF2Items)

## Configuratuin
Plugin is configured inside the `configs/danepve.cfg` directory. 
|Key|Description|
|---|-----------|
|Names|A list of names bots will use|
|Count|Amount of bots to fill the RED team with|
|Difficulty|Desired `tf_bot_difficulty` value|
|Attributes|TF2 attributes applied on the player itself|
|Weapons|A list of weapons that bots will use, defined as a list of items per slot. Upon spawn, bots will pick a random one for each slot|
|Cosmetics|A list of cosmetics equipped on the bots|

## Update History

### 0.7.1
- Added fail states if gamedata was setup incorrectly.

### 0.7.0
- Added `sm_danepve_clear_bots_building_gibs` to clear gibs from building to prevent server crashes.
- Stopped spawning gibs for some time when bots are in the joining phase and dying a lot.

### 0.6.2
- Also remove halloween souls packs.

### 0.6.1
- Use our own system for forced team joins.

### 0.6.0
- Attempt to ensure that players are only on the team that they are allowed to be on.
- Round timer is now a stopwatch that shows how much has passed during a round.
- Delete edict entities that appear from dying engineers during round end.
- Engineer health is 185.
- Added sm_becomedanebot command. (Exclusive to Uncle Dane :O)

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
