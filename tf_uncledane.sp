#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>

#define DANE_TEAM_HUMANS 		TFTeam_Blue
#define DANE_TEAM_HUMANS_NAME 	"blue"
#define DANE_TEAM_BOTS 			TFTeam_Red
#define DANE_TEAM_BOTS_NAME		"red"

#define DANE_BOT_CLASS_NAME		"engineer"
#define DANE_BOT_CLASS			TF2_GetClass(BOT_CLASS_NAME)

#define TF_PAINT_WHITE 			0xE6E6E6

char g_szBotNames[][] = {
	"Uncle Dane-O",
	"Uncle D-Man",
	"Unkie Dane",
	"Uncle Danno",
	"Uncle Danimal",
	"Unkie D",
	"Uncle D-Dawg",
	"Uncle Dizzle",
	"Unkie Doodle",
	"Uncle Danosaur",
	"Uncle D-Money",
	"Unkie D-Train",
	"Uncle D-Funk",
	"Uncle D-Cakes",
	"Unkie D-Swag",
	"Uncle D-Licious"
};

public Plugin myinfo = 
{
	name = "[TF2] Uncle Dane PVE",
	author = "Moonly Days",
	description = "Uncle Dane PVE",
	version = "1.0.0",
	url = "https://github.com/MoonlyDays"
};

ConVar dane_bot_limit;
ConVar tf_bot_force_class;
ConVar mp_humans_must_join_team;
ConVar mp_forceautoteam;
ConVar mp_teams_unbalance_limit;
ConVar sv_visiblemaxplayers;
ConVar maxplayers;

Handle g_hSdkEquipWearable;

public OnPluginStart()
{
	// Create plugin ConVars
	dane_bot_limit = CreateConVar("dane_bot_limit", "16");

	// Find Native ConVars
	tf_bot_force_class 			= FindConVar("tf_bot_force_class");
	mp_humans_must_join_team 	= FindConVar("mp_humans_must_join_team");
	mp_forceautoteam 			= FindConVar("mp_forceautoteam");
	mp_teams_unbalance_limit 	= FindConVar("mp_teams_unbalance_limit");
	sv_visiblemaxplayers 		= FindConVar("sv_visiblemaxplayers");
	maxplayers 					= FindConVar("maxplayers");

	// Hook Events
	HookEvent("teamplay_round_start", 		teamplay_round_start);
	HookEvent("post_inventory_application", post_inventory_application);
	
	// GameData
	Handle hConf = LoadGameConfigFile("tf2.danepve");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();

	LoadConfig();

}

public LoadConfig()
{

}

//-------------------------------------------------------//
// GAMEMODE STOCKS
//-------------------------------------------------------//

/**
 * Verifies and fixes all issues with client team placement.
 */
public ValidateClientTeams()
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
			? DANE_TEAM_BOTS
			: DANE_TEAM_HUMANS;

		// Assert that client is on that correct team.
		if(currentTeam != requiredTeam)
		{
			// Switch teams.
			TF2_ChangeClientTeam(i, requiredTeam);
		}
	}
}

/**
 * Make sure we have enough bots on the server.
 */
public ValidateBotCount()
{
	int targetBotCount = dane_bot_limit.IntValue;
	int currentBotCount = TF2_GetClientCountInTeam(DANE_TEAM_BOTS);
	int countDiff = targetBotCount - currentBotCount;
	int diffDir = countDiff > 0 ? 1 : -1;
	
	for(int i = currentBotCount; i != targetBotCount; i += diffDir)
	{
		// Not enough bots.
		if(currentBotCount < targetBotCount)
		{
			// Create a new uncle dane bot.
			CreateNamedBot();
		}
		else
		{
			// Kick bot
			int client = FindNextBotToKick();
			if(client > 0) KickClient(client);
		}
	}
}

public CreateNamedBot()
{
	// Figure out the name of the bot.
	// Make a static variable to store current local name index.
	static int currentName = -1;
	// Rotate the names
	int maxNames = sizeof(g_szBotNames);
	currentName++;
	currentName %= maxNames;

	char szName[PLATFORM_MAX_PATH];
	strcopy(szName, sizeof(szName), g_szBotNames[currentName]);

	// Allocate the bot itself.
	char szCommand[PLATFORM_MAX_PATH];
	Format(szCommand, sizeof(szCommand), "tf_bot_add %s %s \"%s\"", DANE_BOT_CLASS_NAME, DANE_TEAM_BOTS_NAME, szName);
	ServerCommand(szCommand);
}

public PrepareRound()
{
	// Change the values of all the console variables.
	tf_bot_force_class.SetString(DANE_BOT_CLASS_NAME);
	mp_forceautoteam.SetBool(true);
	mp_humans_must_join_team.SetString(DANE_TEAM_HUMANS_NAME);
	mp_teams_unbalance_limit.SetInt(0);

	int visPlayers = maxplayers.IntValue - dane_bot_limit.IntValue;
	sv_visiblemaxplayers.SetInt(visPlayers);

	ValidateClientTeams();
	ValidateBotCount();
}

public EquipEngineerBot()
{

}

//-------------------------------------------------------//
// GAME EVENTS
//-------------------------------------------------------//

public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast)
{
	PrepareRound();
	return Plugin_Continue;
}

public Action post_inventory_application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsFakeClient(client))
	{
		TF2_CreateWearable(client, 30539, TF_PAINT_WHITE);
		TF2_CreateWearable(client, 30420, TF_PAINT_WHITE);
		TF2_CreateWearable(client, 30172, TF_PAINT_WHITE);
	}

	return Plugin_Continue;
}

/**
 * Returns the next bot to kick.
 */
public int FindNextBotToKick()
{
	for(int i = MaxClients; i >= 1; i--)
	{
		if(!IsClientInGame(i))
			continue;

		if(!IsFakeClient(i))
			continue;

		if(TF2_GetClientTeam(i) != DANE_TEAM_BOTS)
			continue;

		return i;
	}

	return -1;
}

bool TF2_CreateWearable(int client, int itemDef, int color = -1)
{
	int hat = CreateEntityByName("tf_wearable");
	if (!IsValidEntity(hat))
		return false;
	
	SetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex", itemDef);
	SetEntProp(hat, Prop_Send, "m_bInitialized", 1);
	SetEntProp(hat, Prop_Send, "m_iEntityLevel", 50);
	SetEntProp(hat, Prop_Send, "m_iEntityQuality", 6);
	SetEntProp(hat, Prop_Send, "m_bValidatedAttachedEntity", 1);
	SetEntProp(hat, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntPropEnt(hat, Prop_Send, "m_hOwnerEntity", client);

	if(color >= 0)
	{
		TF2Attrib_SetByName(hat, "set item tint RGB", float(color));
		TF2Attrib_SetByName(hat, "set item tint RGB 2", float(color));
	}

	DispatchSpawn(hat);
	SDKCall(g_hSdkEquipWearable, client, hat);
	return true;
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