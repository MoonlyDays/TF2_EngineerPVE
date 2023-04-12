#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>
#include <dhooks>

#include <danepve/constants.sp>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo = 
{
	name = "[TF2] Uncle Dane PVE",
	author = "Moonly Days",
	description = "Uncle Dane PVE",
	version = "1.0.0",
	url = "https://github.com/MoonlyDays"
};

// Plugin ConVars
ConVar danepve_bot_limit;
ConVar danepve_allow_respawnroom_build;

// Native ConVars
ConVar tf_bot_force_class;
ConVar tf_bot_difficulty;
ConVar mp_humans_must_join_team;
ConVar mp_disable_respawn_times;
ConVar mp_forceautoteam;
ConVar mp_teams_unbalance_limit;
ConVar sv_visiblemaxplayers;

// SDK Call Handles
Handle g_hSdkEquipWearable;
Handle gHook_PointIsWithin;
Handle gHook_EstimateValidBuildPos;

ArrayList g_hBotCosmetics = null;
ArrayList g_hBotNames = null;

int g_nOffset_CBaseEntity_m_iTeamNum;

public OnPluginStart()
{
	//
	// Create plugin ConVars
	//

	CreateConVar("danepve_version", PLUGIN_VERSION, "[TF2] Uncle Dane PVE Version", FCVAR_DONTRECORD);
	danepve_bot_limit = CreateConVar("danepve_bot_limit", "16", "Amount of bots to spawn on the BOT team.");
	danepve_allow_respawnroom_build = CreateConVar("danepve_allow_respawnroom_build", "1", "Can humans build in respawn rooms?");

	//
	// Find Native ConVars
	//

	tf_bot_force_class 			= FindConVar("tf_bot_force_class");
	tf_bot_difficulty 			= FindConVar("tf_bot_difficulty");
	mp_humans_must_join_team 	= FindConVar("mp_humans_must_join_team");
	mp_forceautoteam 			= FindConVar("mp_forceautoteam");
	mp_disable_respawn_times	= FindConVar("mp_disable_respawn_times");
	mp_teams_unbalance_limit 	= FindConVar("mp_teams_unbalance_limit");
	sv_visiblemaxplayers 		= FindConVar("sv_visiblemaxplayers");

	PrintToChatAll("%d", g_nOffset_CBaseEntity_m_iTeamNum);

	//
	// Admin Commands
	//

	RegAdminCmd("sm_danepve_reload", cReload, ADMFLAG_CHANGEMAP, "Reloads Uncle Dane PVE config.");

	//
	// Hook Events
	//

	HookEvent("teamplay_round_start", 		teamplay_round_start);
	HookEvent("teamplay_setup_finished",	teamplay_setup_finished);
	HookEvent("post_inventory_application", post_inventory_application);
	
	//
	// Prepare SDK calls from Game Data
	//

	Handle hConf = LoadGameConfigFile("tf2.danepve");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();
	
	g_nOffset_CBaseEntity_m_iTeamNum = FindSendPropInfo("CBaseEntity", "m_iTeamNum");

	//
	// Setup DHook Detours
	//

	gHook_PointIsWithin = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	DHookSetFromConf(gHook_PointIsWithin, hConf, SDKConf_Signature, "PointIsWithin");
	DHookAddParam(gHook_PointIsWithin, HookParamType_VectorPtr);
	DHookEnableDetour(gHook_PointIsWithin, false, Detour_OnPointIsWithin);

	gHook_EstimateValidBuildPos = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	DHookSetFromConf(gHook_EstimateValidBuildPos, hConf, SDKConf_Signature, "EstimateValidBuildPos");
	DHookEnableDetour(gHook_EstimateValidBuildPos, false, Detour_EstimateValidBuildPos);
	DHookEnableDetour(gHook_EstimateValidBuildPos, true, Detour_EstimateValidBuildPos_Post);

	//
	// Load config and setup the game
	//

	Config_Load();
	PVE_ValidateGameForRound();
}

public OnPluginEnd()
{
	PVE_KickAllBots();

	// Restore all changed convars to default.
	tf_bot_force_class.RestoreDefault();
	tf_bot_difficulty.RestoreDefault();
	mp_humans_must_join_team.RestoreDefault();
	mp_forceautoteam.RestoreDefault();
	mp_disable_respawn_times.RestoreDefault();
	mp_teams_unbalance_limit.RestoreDefault();
	sv_visiblemaxplayers.RestoreDefault();
}

/** Reload the plugin config */
public Config_Load()
{
	// Build the path to the config file. 
	char szCfgPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szCfgPath, sizeof(szCfgPath), "configs/danepve.cfg");

	// Load the keyvalues.
	KeyValues kv = new KeyValues("UncleDanePVE");
	if(kv.ImportFromFile(szCfgPath) == false)
	{
		SetFailState("Failed to read configs/danepve.cfg");
		return;
	}

	// Try to load bot names.
	if(kv.JumpToKey("Names"))
	{
		Config_LoadNamesFromKV(kv);
		kv.GoBack();
	}

	// Try to load bot cosmetics.
	if(kv.JumpToKey("Cosmetics"))
	{
		Config_LoadCosmeticsFromKV(kv);
		kv.GoBack();
	}
}

/** Reload the bot names that will be on the bot team. */
public Config_LoadNamesFromKV(KeyValues kv)
{
	delete g_hBotNames;
	g_hBotNames = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	
	if(kv.GotoFirstSubKey(false))
	{
		do {
			char szName[PLATFORM_MAX_PATH];
			kv.GetString(NULL_STRING, szName, sizeof(szName));
			g_hBotNames.PushString(szName);
		} while (kv.GotoNextKey(false));

		kv.GoBack();
	}
}

/**
 * Load bot cosmetics definitions from config.
 */
public Config_LoadCosmeticsFromKV(KeyValues kv)
{
	if(g_hBotCosmetics != INVALID_HANDLE)
	{
		for(int i = 0; i < g_hBotCosmetics.Length; i++)
		{
			BotCosmetic cosmetic;
			g_hBotCosmetics.GetArray(i, cosmetic);
			delete cosmetic.m_Attributes;
		}
	}
	
	delete g_hBotCosmetics;

	g_hBotCosmetics = new ArrayList(sizeof(BotCosmetic));
	
	if(kv.GotoFirstSubKey(false))
	{
		do {
			// Create bot cosmetic definition.
			BotCosmetic cosmetic;
			cosmetic.m_DefinitionIndex = kv.GetNum("Index");
			
			// Check if cosmetic definition contains attributes.
			if(kv.JumpToKey("Attributes"))
			{
				// If so, create an array list.
				cosmetic.m_Attributes = new ArrayList(sizeof(BotCosmeticAttribute));

				// Try going to the first attribute scope.
				if(kv.GotoFirstSubKey(false))
				{
					do {
						// Read name and float value, add the pair to the attributes array.
						BotCosmeticAttribute attrib;
						kv.GetSectionName(attrib.m_szName, sizeof(attrib.m_szName));
						attrib.m_flValue = kv.GetFloat(NULL_STRING);
						cosmetic.m_Attributes.PushArray(attrib);

					} while (kv.GotoNextKey(false))

					kv.GoBack();
				}

				kv.GoBack();
			}

			g_hBotCosmetics.PushArray(cosmetic);

		} while (kv.GotoNextKey(false));

		kv.GoBack();
	}
}

//-------------------------------------------------------//
// GAMEMODE STOCKS
//-------------------------------------------------------//

public PVE_KickAllBots()
{
	ServerCommand("tf_bot_kick all");
}

public PVE_ValidateGameForRound()
{
	// Change the values of all the console variables.
	tf_bot_force_class.SetString(PVE_BOT_CLASS_NAME);
	tf_bot_difficulty.SetInt(3);
	mp_forceautoteam.SetBool(true);
	mp_humans_must_join_team.SetString(PVE_TEAM_HUMANS_NAME);
	mp_teams_unbalance_limit.SetInt(0);
	mp_disable_respawn_times.SetInt(1);

	int visPlayers = MaxClients - danepve_bot_limit.IntValue;
	sv_visiblemaxplayers.SetInt(visPlayers);

	PVE_ValidateClientTeams();
	PVE_ValidateBotCount();
}

/**
 * Verifies and fixes all issues with client team placement.
 */
public PVE_ValidateClientTeams()
{
	// Go through all clients and verify them.
	for(int i = 1; i <= MaxClients; i++)
	{
		// Client doesn't exist.
		if(!IsClientInGame(i))
			continue;

		TFTeam currentTeam = TF2_GetClientTeam(i);
		if(currentTeam == TFTeam_Spectator)
		{
			// Players don't leave spectator unless they specifically
			// choose to.
			continue;
		}

		// Figure out which team the client needs to be in.
		TFTeam requiredTeam = IsFakeClient(i) 
			? PVE_TEAM_BOTS
			: PVE_TEAM_HUMANS;

		// Assert that client is on that correct team.
		if(currentTeam != requiredTeam)
		{
			// Switch teams.
			PVE_SwitchClientTeamSilent(i, requiredTeam);
		}
	}
}

/**
 * Make sure we have enough bots on the server. 
 */
public PVE_ValidateBotCount()
{
	int targetBotCount = danepve_bot_limit.IntValue;

	// If there are no humans connected, dont summon any bots at all.
	if(TF2_GetConnectedHumans() == 0)
		targetBotCount = 0;

	int currentBotCount = TF2_GetClientCountInTeam(PVE_TEAM_BOTS);
	int countDiff = targetBotCount - currentBotCount;
	int diffDir = countDiff > 0 ? 1 : -1;
	
	int lastKickedBot = -1;
	for(int i = currentBotCount; i != targetBotCount; i += diffDir)
	{
		// Not enough bots.
		if(currentBotCount < targetBotCount)
		{
			// Create a new uncle dane bot.
			PVE_CreateNamedBot();
		}
		else
		{
			// Kick bot
			int client = PVE_FindNextBotToKick(lastKickedBot);
			if(client > 0) 
			{
				KickClient(client);
				lastKickedBot = client;
			}
		}
	}
}

public PVE_CreateNamedBot()
{
	// Figure out the name of the bot.
	// Make a static variable to store current local name index.
	static int currentName = -1;
	// Rotate the names
	int maxNames = g_hBotNames.Length;
	currentName++;
	currentName %= maxNames;

	char szName[PLATFORM_MAX_PATH];
	g_hBotNames.GetString(currentName, szName, sizeof(szName));

	// Format the command to summon a new bot.
	char szCommand[PLATFORM_MAX_PATH];
	Format(szCommand, sizeof(szCommand), "tf_bot_add %s %s \"%s\" noquota", 
		PVE_BOT_CLASS_NAME, 
		PVE_TEAM_BOTS_NAME, 
		szName);
	
	// Summon the bot.
	ServerCommand(szCommand);
}

/**
 * Returns the next bot to kick.
 */
public int PVE_FindNextBotToKick(int lastKicked)
{
	int toKick = -1;
	for(int i = MaxClients; i >= 1; i--)
	{
		if(!IsClientInGame(i))
			continue;

		if(!IsFakeClient(i))
			continue;

		if(TF2_GetClientTeam(i) != PVE_TEAM_BOTS)
			continue;

		if(lastKicked > 0 && lastKicked == i)
			break;

		toKick = i;
	}

	return toKick;
}

public PVE_EquipBotCosmetics(int client)
{
	for(int i = 0; i < g_hBotCosmetics.Length; i++)
	{
		BotCosmetic cosmetic;
		g_hBotCosmetics.GetArray(i, cosmetic);

		int hat = PVE_GiveWearableToClient(client, cosmetic.m_DefinitionIndex);
		if(hat <= 0)
			continue;
			
		for(int j = 0; j < cosmetic.m_Attributes.Length; j++)
		{
			BotCosmeticAttribute attrib;
			cosmetic.m_Attributes.GetArray(j, attrib);

			TF2Attrib_SetByName(hat, attrib.m_szName, attrib.m_flValue);
		}
	}
}

int PVE_GiveWearableToClient(int client, int itemDef)
{
	int hat = CreateEntityByName("tf_wearable");
	if(!IsValidEntity(hat))
		return -1;
	
	SetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex", itemDef);
	SetEntProp(hat, Prop_Send, "m_bInitialized", 1);
	SetEntProp(hat, Prop_Send, "m_iEntityLevel", 50);
	SetEntProp(hat, Prop_Send, "m_iEntityQuality", 6);
	SetEntProp(hat, Prop_Send, "m_bValidatedAttachedEntity", 1);
	SetEntProp(hat, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntPropEnt(hat, Prop_Send, "m_hOwnerEntity", client);

	DispatchSpawn(hat);
	SDKCall(g_hSdkEquipWearable, client, hat);
	return hat;
} 

void PVE_SwitchClientTeamSilent(int client, TFTeam team)
{
	SetEntProp(client, Prop_Send, "m_iTeamNum", view_as<int>(team));
	TF2_RespawnPlayer(client);
}

//-------------------------------------------------------//
// ConVars
//-------------------------------------------------------//

public Action cReload(int client, int args)
{
	Config_Load();
	ReplyToCommand(client, "[SM] Uncle Dane PVE config was reloaded!");
	return Plugin_Handled;
}

//-------------------------------------------------------//
// GAME EVENTS
//-------------------------------------------------------//

public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast)
{
	PVE_ValidateGameForRound();
	return Plugin_Continue;
}

public Action teamplay_setup_finished(Event event, const char[] name, bool dontBroadcast)
{
	// Destroy round timer
	int timer = FindEntityByClassname(-1, "team_round_timer");
	if(timer > 0)
	{
		AcceptEntityInput(timer, "Disable");
	}

	return Plugin_Continue;
}

public Action post_inventory_application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsFakeClient(client))
	{
		PVE_EquipBotCosmetics(client);

		// Infinite metal for bots!
		TF2Attrib_SetByName(client, "metal regen", 5000.0);
		TF2Attrib_SetByName(client, "maxammo metal increased", 25.0);
	}
	else 
	{
		// TEST!
		TF2Attrib_SetByName(client, "increase player capture value", 10.0);
	}

	return Plugin_Continue;
}

int TF2_GetClientCountInTeam(TFTeam team)
{
	int count = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		if(TF2_GetClientTeam(i) != team)
			continue;

		count++;
	}

	return count;
}

int TF2_GetConnectedHumans()
{
	int count = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		if(IsFakeClient(i))
			continue;

		count++;
	}

	return count;
}

//
// DHOOK Detours
//

int g_bAllowNextHumanTeamPointCheck = false;

MRESReturn Detour_EstimateValidBuildPos(Address pThis, Handle hReturn, Handle hParams)
{
	if(!danepve_allow_respawnroom_build.BoolValue)
		return MRES_Ignored;

	g_bAllowNextHumanTeamPointCheck = true;
	return MRES_Ignored;
}

MRESReturn Detour_EstimateValidBuildPos_Post(Address pThis, Handle hReturn, Handle hParams)
{
	g_bAllowNextHumanTeamPointCheck = false;
	return MRES_Ignored;
}

MRESReturn Detour_OnPointIsWithin(Address pThis, Handle hReturn, Handle hParams)
{
	if(g_bAllowNextHumanTeamPointCheck)
	{
		Address addrTeam = pThis + view_as<Address>(g_nOffset_CBaseEntity_m_iTeamNum);
		TFTeam iTeam = view_as<TFTeam>(LoadFromAddress(addrTeam, NumberType_Int8));
		
		if(iTeam == PVE_TEAM_HUMANS)
		{
			DHookSetReturn(hReturn, false);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}