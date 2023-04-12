#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>
#include <dhooks>

#include <danepve/constants.sp>

#define PLUGIN_VERSION "1.1.0"

public Plugin myinfo = 
{
	name = "[TF2] Uncle Dane PVE",
	author = "Moonly Days",
	description = "Uncle Dane PVE",
	version = "1.0.0",
	url = "https://github.com/MoonlyDays"
};

// Plugin ConVars
ConVar danepve_allow_respawnroom_build;

// SDK Call Handles
Handle g_hSdkEquipWearable;
Handle gHook_PointIsWithin;
Handle gHook_EstimateValidBuildPos;
Handle gHook_HandleSwitchTeams;

ArrayList g_hBotCosmetics = null;
ArrayList g_hPlayerAttributes = null;
ArrayList g_hBotNames = null;

// Offset cache
int g_nOffset_CBaseEntity_m_iTeamNum;

public OnPluginStart()
{
	//
	// Create plugin ConVars
	//

	CreateConVar("danepve_version", PLUGIN_VERSION, "[TF2] Uncle Dane PVE Version", FCVAR_DONTRECORD);
	danepve_allow_respawnroom_build = CreateConVar("danepve_allow_respawnroom_build", "1", "Can humans build in respawn rooms?");
	RegAdminCmd("sm_danepve_reload", cReload, ADMFLAG_CHANGEMAP, "Reloads Uncle Dane PVE config.");

	//
	// Hook Events
	//

	HookEvent("post_inventory_application", post_inventory_application);
	
	//
	// Offsets Cache
	//

	g_nOffset_CBaseEntity_m_iTeamNum = FindSendPropInfo("CBaseEntity", "m_iTeamNum");

	//
	// Prepare SDK calls from Game Data
	//

	Handle hConf = LoadGameConfigFile("tf2.danepve");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();

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

	int offset = GameConfGetOffset(hConf, "CTFGameRules::HandleSwitchTeams");
	gHook_HandleSwitchTeams = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, CTFGameRules_HandleSwitchTeams);
	
	//
	// Load config and setup the game
	//

	Config_Load();
}

public OnMapStart()
{
	DHookGamerules(gHook_HandleSwitchTeams, false);
}

public bool OnClientConnect(int client, char[] rejectMsg, int maxlen)
{
	if(IsFakeClient(client))
	{
		CreateTimer(0.1, Timer_OnBotConnect, client);
	}

	return true;
}

public Action Timer_OnBotConnect(Handle timer, any client)
{
	PVE_RenameBotClient(client);
	TF2_ChangeClientTeam(client, PVE_TEAM_BOTS);

	return Plugin_Handled;
}

//-------------------------------------------------------//
// GAMEMODE STOCKS
//-------------------------------------------------------//

public PVE_RenameBotClient(int client)
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
	SetClientName(client, szName);
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
			TFAttribute attrib;
			cosmetic.m_Attributes.GetArray(j, attrib);
			TF2Attrib_SetByName(hat, attrib.m_szName, attrib.m_flValue);
		}
	}
}

public PVE_ApplyPlayerAttributes(int client)
{
	for(int i = 0; i < g_hPlayerAttributes.Length; i++)
	{
		TFAttribute attrib;
		g_hPlayerAttributes.GetArray(i, attrib);
		TF2Attrib_SetByName(client, attrib.m_szName, attrib.m_flValue);
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

public Action post_inventory_application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsFakeClient(client))
	{
		PVE_EquipBotCosmetics(client);
		PVE_ApplyPlayerAttributes(client);
	}

	return Plugin_Continue;
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

// void CTFGameRules::HandleSwitchTeams( void );
public MRESReturn CTFGameRules_HandleSwitchTeams( int pThis, Handle hParams ) 
{
	return MRES_Supercede;
}

//-------------------------------------------------------//
// CONFIG
//-------------------------------------------------------//

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

	// Try to load bot cosmetics.
	if(kv.JumpToKey("Attributes"))
	{
		Config_LoadAttributesFromKV(kv);
		kv.GoBack();
	}

	char szClassName[32];
	kv.GetString("Class", szClassName, sizeof(szClassName));
	FindConVar("tf_bot_force_class")		.SetString(szClassName);
	FindConVar("mp_forceautoteam")			.SetBool(true);
	FindConVar("mp_humans_must_join_team")	.SetString(PVE_TEAM_HUMANS_NAME);
	FindConVar("mp_disable_respawn_times")	.SetBool(true);
	FindConVar("mp_teams_unbalance_limit")	.SetInt(0);
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

/** Reload the bot names that will be on the bot team. */
public Config_LoadAttributesFromKV(KeyValues kv)
{
	delete g_hPlayerAttributes;
	g_hPlayerAttributes = new ArrayList(sizeof(TFAttribute));
	
	if(kv.GotoFirstSubKey(false))
	{
		do {
			// Read name and float value, add the pair to the attributes array.
			TFAttribute attrib;
			kv.GetSectionName(attrib.m_szName, sizeof(attrib.m_szName));
			attrib.m_flValue = kv.GetFloat(NULL_STRING);
			g_hPlayerAttributes.PushArray(attrib);

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
				cosmetic.m_Attributes = new ArrayList(sizeof(TFAttribute));

				// Try going to the first attribute scope.
				if(kv.GotoFirstSubKey(false))
				{
					do {
						// Read name and float value, add the pair to the attributes array.
						TFAttribute attrib;
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