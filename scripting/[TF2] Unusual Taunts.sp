#pragma semicolon 1

#include <sourcemod>
#include <tf_econ_data>
#include <tf2_stocks>
#include <tf2items>

#define IS_BUGGY(%1) (3014 <= %1 <= 3016 || %1 == 3021 || %1 == 3022 || 3037 <= %1 <= 3045)

#pragma newdecls required

int				 g_iClientParticleIndex[MAXPLAYERS + 1], g_iClientParticleEntity[MAXPLAYERS + 1];
StringMap		 g_hTokensMap;

public Plugin myinfo =
{
	name		= "[TF2] Unusual Taunts",
	author		= "StrikeR14",
	description = "Apply an unusual taunt effect!",
	version		= "2.0",
	url			= ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_taunt", Command_Taunt);
	RegConsoleCmd("sm_taunts", Command_Taunt);
	RegConsoleCmd("sm_utaunt", Command_UTaunt);

	g_hTokensMap = ParseLanguage("english");
}

public void OnClientConnected(int client)
{
	g_iClientParticleIndex[client] = 0;
	g_iClientParticleEntity[client] = 0;
}

public Action Command_Taunt(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[SM] This command is available in-game only!");
		return Plugin_Handled;
	}

	MainMenu(client);
	return Plugin_Handled;
}

public Action Command_UTaunt(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[SM] This command is available in-game only!");
		return Plugin_Handled;
	}

	UnusualTauntMenu(client);
	return Plugin_Handled;
}

public int Handler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char index[8];
		menu.GetItem(param2, index, sizeof(index));

		if (StrEqual(index, "unu"))
		{
			UnusualTauntMenu(client);
		}
		else
		{
			char strTauntIndex[16];
			menu.GetItem(param2, strTauntIndex, sizeof(strTauntIndex));
			int iTauntIndex = StringToInt(strTauntIndex);
			ServerCommand("sm_tauntem #%i %i", GetClientUserId(client), iTauntIndex);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int Handler_Unusual(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		MainMenu(client);
	}
	else if (action == MenuAction_Select)
	{
		char strUnusualIndex[16];
		char strLocalizedName[64];
		menu.GetItem(param2, strUnusualIndex, sizeof(strUnusualIndex), _, strLocalizedName, sizeof(strLocalizedName));

		int iUnusualIndex			   = StringToInt(strUnusualIndex);
		g_iClientParticleIndex[client] = iUnusualIndex;

		if (iUnusualIndex != 0)
		{
			ReplyToCommand(client, "[SM] Successfully applied \"%s\" on your taunts.", strLocalizedName);
		}
		else
		{
			ReplyToCommand(client, "[SM] Successfully removed the current effect from your taunts.");
		}
	}

	return 0;
}

public void MainMenu(int client)
{
	Menu menu = new Menu(Handler);
	menu.SetTitle("*----------- Taunt Menu -----------*\n \n");
	menu.AddItem("unu", "Unusual Effects!\n \n");

	ArrayList hTauntsList	 = TF2Econ_GetItemList(FilterTaunts, TF2_GetPlayerClass(client));
	int		  iTauntListSize = hTauntsList.Length;
	char	  strTauntName[64];
	char	  strTauntIndex[16];

	for (int iEntry = 0; iEntry < iTauntListSize; iEntry++)
	{
		int iTauntIndex = hTauntsList.Get(iEntry);
		IntToString(iTauntIndex, strTauntIndex, sizeof(strTauntIndex));
		TF2Econ_GetItemName(iTauntIndex, strTauntName, sizeof(strTauntName));
		Format(strTauntName, sizeof(strTauntName), "[%i] %s", iEntry + 1, strTauntName);
		menu.AddItem(strTauntIndex, strTauntName, ITEMDRAW_DEFAULT);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	delete hTauntsList;
}

public void UnusualTauntMenu(int client)
{
	Menu menu2			 = new Menu(Handler_Unusual);
	menu2.SetTitle("* Taunt Menu - Unusual Effects *");
	menu2.AddItem("0", "No effect", ITEMDRAW_DEFAULT);

	ArrayList hUnusualsList = TF2Econ_GetParticleAttributeList(ParticleSet_TauntUnusualEffects);

	int	 iUnusualsListSize = hUnusualsList.Length;
	char strUnusualIndex[16];
	char strUnusualName[64];
	char strLocalizedName[64];

	for (int iEntry = 0; iEntry < iUnusualsListSize; iEntry++)
	{
		int iUnusualIndex = hUnusualsList.Get(iEntry);
		IntToString(iUnusualIndex, strUnusualIndex, sizeof(strUnusualIndex));
		FormatEx(strUnusualName, sizeof(strUnusualName), "Attrib_Particle%i", iUnusualIndex);
		LocalizeToken(strUnusualName, strLocalizedName, sizeof(strLocalizedName));

		menu2.AddItem(strUnusualIndex, strLocalizedName, IS_BUGGY(iUnusualIndex) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu2.ExitBackButton = true;
	menu2.Display(client, MENU_TIME_FOREVER);
	delete hUnusualsList;
}

public void TF2_OnConditionAdded(int iClient, TFCond condition)
{
	if (condition != TFCond_Taunting)
		return;

	if (GetEntProp(iClient, Prop_Send, "m_iTauntItemDefIndex") == -1) // disable unusual effect for default taunts
		return;

	int iParticleIndex = g_iClientParticleIndex[iClient];
	if (iParticleIndex <= 0)
		return;

	int iParticleEntity = CreateAttachedParticle(iClient, iParticleIndex);
	if (!IsValidEdict(iParticleEntity))
		return;

	g_iClientParticleEntity[iClient] = EntIndexToEntRef(iParticleEntity);
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition != TFCond_Taunting)
		return;

	int iParticleEntity = EntRefToEntIndex(g_iClientParticleEntity[client]);
	if (iParticleEntity <= 0)
		return;

	char strEntityClassname[64];
	GetEntityClassname(iParticleEntity, strEntityClassname, sizeof(strEntityClassname));

	if (IsValidEdict(iParticleEntity))
	{
		RemoveEdict(iParticleEntity);
		g_iClientParticleEntity[client] = -1;
	}
}

//-----[ Functions ]-----//
public bool FilterTaunts(int iItemDefIndex, TFClassType iClass)
{
	return TF2Econ_GetItemLoadoutSlot(iItemDefIndex, iClass) == TF2Econ_TranslateLoadoutSlotNameToIndex("taunt");
}

stock int CreateAttachedParticle(int iClient, int iParticleIndex)
{
	int iEntity = CreateEntityByName("info_particle_system");

	if (!IsValidEdict(iEntity))
		return iEntity;

	char strEffectName[PLATFORM_MAX_PATH];

	if (!TF2Econ_GetParticleAttributeSystemName(iParticleIndex, strEffectName, sizeof(strEffectName)))
	{
		LogError("Failed to get the system name of the particle attribute index. Removing entity.");
		RemoveEdict(iEntity);
		return -1;
	}

	char sName[16];
	float fPosition[3];
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", fPosition);
	TeleportEntity(iEntity, fPosition, NULL_VECTOR, NULL_VECTOR);
	FormatEx(sName, 16, "target%d", iClient);
	DispatchKeyValue(iClient, "targetname", sName);
	DispatchKeyValue(iEntity, "targetname", "tf2particle");
	DispatchKeyValue(iEntity, "parentname", sName);
	DispatchKeyValue(iEntity, "effect_name", strEffectName);
	DispatchSpawn(iEntity);
	SetVariantString(sName);
	AcceptEntityInput(iEntity, "SetParent", iEntity, iEntity);
	ActivateEntity(iEntity);
	AcceptEntityInput(iEntity, "start", -1, -1);
	return iEntity;
}

bool LocalizeToken(const char[] strToken, char[] strOutput, int strMaxLen)
{
	if (g_hTokensMap == null)
	{
		LogError("Unable to localize token for server language!");

		return false;
	}
	else
	{
		return g_hTokensMap.GetString(strToken, strOutput, strMaxLen);
	}
}

StringMap ParseLanguage(const char[] strLanguage)
{
	char strFilename[64];
	Format(strFilename, sizeof(strFilename), "resource/tf_%s.txt", strLanguage);
	File hFile = OpenFile(strFilename, "r");

	if (hFile == null)
	{
		return null;
	}

	// The localization files are encoded in UCS-2, breaking all of our available parsing options
	// We have to go byte-by-byte then line-by-line :(

	// This parser isn't perfect since some values span multiple lines, but since we're only interested in single-line values, this is sufficient

	StringMap hLang = new StringMap();
	hLang.SetString("__name__", strLanguage);

	int	 iData, i = 0;
	char strLine[2048];

	while (ReadFileCell(hFile, iData, 2) == 1)
	{
		if (iData < 0x80)
		{
			// It's a single-byte character
			strLine[i++] = iData;

			if (iData == '\n')
			{
				strLine[i] = '\0';
				HandleLangLine(strLine, hLang);
				i = 0;
			}
		}
		else if (iData < 0x800)
		{
			// It's a two-byte character
			strLine[i++] = (iData >> 6) | 0xC0;
			strLine[i++] = (iData & 0x3F) | 0x80;
		}
		else if (iData < 0xFFFF && iData >= 0xD800 && iData <= 0xDFFF)
		{
			strLine[i++] = (iData >> 12) | 0xE0;
			strLine[i++] = ((iData >> 6) & 0x3F) | 0x80;
			strLine[i++] = (iData & 0x3F) | 0x80;
		}
		else if (iData >= 0x10000 && iData < 0x10FFFF)
		{
			strLine[i++] = (iData >> 18) | 0xF0;
			strLine[i++] = ((iData >> 12) & 0x3F) | 0x80;
			strLine[i++] = ((iData >> 6) & 0x3F) | 0x80;
			strLine[i++] = (iData & 0x3F) | 0x80;
		}
	}

	delete hFile;

	return hLang;
}

void HandleLangLine(char[] strLine, StringMap hLang)
{
	TrimString(strLine);

	if (strLine[0] != '"')
	{
		// Not a line containing at least one quoted string
		return;
	}

	char strToken[128], strValue[1024];
	int	 iPos = BreakString(strLine, strToken, sizeof(strToken));

	if (iPos == -1)
	{
		// This line doesn't have two quoted strings
		return;
	}

	BreakString(strLine[iPos], strValue, sizeof(strValue));

	if (StrContains(strToken, "Attrib_Particle") != -1)	   // Only particles should be added
	{
		hLang.SetString(strToken, strValue);
	}
}
