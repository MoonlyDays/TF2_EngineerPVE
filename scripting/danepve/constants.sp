/** Internal game index of the humans team */
#define PVE_TEAM_HUMANS			TFTeam_Blue
/** Display name of the humans team */
#define PVE_TEAM_HUMANS_NAME 	"blue"
/** Internal game index of the bots team */
#define PVE_TEAM_BOTS			TFTeam_Red
/** Display name of the bot team */
#define PVE_TEAM_BOTS_NAME 		"red"
/** Maximum amount of players that can be on the server in TF2 */
#define TF_MAXPLAYERS 			32

/** Name of the class that bots play as. */
#define PVE_BOT_CLASS_NAME 		"engineer"
/** Internal game index of the bot class. */
#define PVE_BOT_CLASS 			TF2_GetClass(PVE_BOT_CLASS_NAME)

/** Maximum amount of attributes on a bot cosmetic */
#define PVE_MAX_COSMETIC_ATTRS 8

enum struct BotCosmeticAttribute
{
	char m_szName[PLATFORM_MAX_PATH];
	float m_flValue;
}

enum struct BotCosmetic
{
	int m_DefinitionIndex;
	ArrayList m_Attributes;
} 