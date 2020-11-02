#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <steamtools>

#define STEAM_API_KEY "NAN"
#define IS_BUGGY(%1) (3014 <= %1 <= 3016 || %1 == 3021 || %1 == 3022 || 3037 <= %1 <= 3045)

#pragma dynamic 320789
#pragma newdecls required

ArrayList g_utaunts_id, g_utaunts_classname, g_utaunts_name;
int g_iTauntEffect[MAXPLAYERS + 1], g_iTauntParticle[MAXPLAYERS + 1], tryCount;
bool hadError;

public Plugin myinfo =
{
	name = "[TF2] Unusual Taunts",
	author = "StrikeR14",
	description = "Apply an unusual taunt effect!",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_utaunt", Command_TauntEffect);
	RegConsoleCmd("sm_unusualtaunt", Command_TauntEffect);
}

public void OnConfigsExecuted()
{
	tryCount = 0;
	CreateRequest();
}

public Action Command_TauntEffect(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[SM] This command is available in-game only!");
		return Plugin_Handled;
	}

	if(!strcmp(STEAM_API_KEY, "NAN"))
	{
		ReplyToCommand(client, "[SM] The owner did not define a valid STEAM API KEY.");
		return Plugin_Handled;
	}

	if(hadError)
	{
		ReplyToCommand(client, "[SM] There was an error with the server's HTTP Request, try again later.");
		return Plugin_Handled;
	}

	char name[32], index[8];

	Menu menu = new Menu(Handler);
	menu.SetTitle("[SM] Unusual Taunts:");
	menu.AddItem("0", "None");

	for(int i = 0; i < g_utaunts_id.Length; i++)
	{
		FormatEx(index, sizeof(index), "%i", g_utaunts_id.Get(i));
		g_utaunts_name.GetString(i, name, sizeof(name));
		menu.AddItem(index, name);
	}

	menu.Display(client, 30);
	return Plugin_Handled;
}

public int Handler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char index[8], name[32];
		menu.GetItem(param2, index, sizeof(index), _, name, sizeof(name));
		g_iTauntEffect[client] = StringToInt(index);

		if(g_iTauntEffect[client])
			PrintToChat(client, "[SM] Successfully applied %s for your taunts!", name);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (g_iTauntEffect[client] && condition == TFCond_Taunting)
	{
		float fPos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
		char strParticle[64];
		EffectToString(g_iTauntEffect[client], strParticle, sizeof(strParticle));
		g_iTauntParticle[client] = ClientParticle(client, strParticle, fPos);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (g_iTauntEffect[client] && condition == TFCond_Taunting)
	{
		RemoveParticle(client);
	}
}

//-----[ Functions ]-----//

void RemoveParticle(const int client)
{
	if (IsValidEdict(g_iTauntParticle[client]))
	{
		RemoveEdict(g_iTauntParticle[client]);
	}
}

int ClientParticle(const int client, const char[] effect, const float fPos[3])
{
	int iParticle = CreateEntityByName("info_particle_system");
	char sName[16];
	
	if (iParticle != -1)
	{
		TeleportEntity(iParticle, fPos, NULL_VECTOR, NULL_VECTOR);
		FormatEx(sName, sizeof(sName), "target%d", client);
		DispatchKeyValue(client, "targetname", sName);
		DispatchKeyValue(iParticle, "targetname", "tf2particle");
		DispatchKeyValue(iParticle, "parentname", sName);
		DispatchKeyValue(iParticle, "effect_name", effect);
		DispatchSpawn(iParticle);
		SetVariantString(sName);
		AcceptEntityInput(iParticle, "SetParent", iParticle, iParticle);
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "start");
		return iParticle;
	}
	
	return -1;
}

void EffectToString(const int effect, char[] particle, const int maxlen)
{
	g_utaunts_classname.GetString(g_utaunts_id.FindValue(effect), particle, maxlen);
}

void CreateRequest()
{
	HTTPRequestHandle request = Steam_CreateHTTPRequest(HTTPMethod_GET, "https://api.steampowered.com/IEconItems_440/GetSchemaOverview/v0001/?language=en");
	Steam_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
	Steam_SetHTTPRequestGetOrPostParameter(request, "key", STEAM_API_KEY);
	Steam_SendHTTPRequest(request, OnHTTPResponse);
}

public void OnHTTPResponse(HTTPRequestHandle request, bool successful, HTTPStatusCode eStatusCode) 
{
	if (!successful || eStatusCode >= HTTPStatusCode_BadRequest)
	{
		LogError("Could not fetch unusual taunts (HTTP status %d)", eStatusCode);
		Steam_ReleaseHTTPRequest(request);
		hadError = true;

		if (tryCount < 10)
		{
			CreateTimer(30.0, TryAgain, _, TIMER_FLAG_NO_MAPCHANGE); // too many requests in a small interval can generate HTTP errors too
		}

		return;
	}

	hadError = false;
	tryCount = 0;

	int len = Steam_GetHTTPResponseBodySize(request);
	char[] response = new char[len];
	Steam_GetHTTPResponseBodyData(request, response, len);

	char section[64], classname[64], name[32];

	KeyValues kv = new KeyValues("response");
	kv.ImportFromString(response, "response");
	kv.JumpToKey("attribute_controlled_attached_particles");
	kv.JumpToKey("0");

	g_utaunts_id = new ArrayList();
	g_utaunts_classname = new ArrayList(ByteCountToCells(64));
	g_utaunts_name = new ArrayList(ByteCountToCells(32));

	do
	{
		kv.GetSectionName(section, sizeof(section));

		if(!IsInt(section, strlen(section)))
		{
			break;
		}

		kv.GetString("system", classname, sizeof(classname));

		if(StrContains(classname, "utaunt", true) == -1)
		{
			continue;
		}

		int defIndex = kv.GetNum("id");

		if(IS_BUGGY(defIndex))
		{
			continue;
		}

		kv.GetString("name", name, sizeof(name));

		g_utaunts_id.Push(defIndex);
		g_utaunts_classname.PushString(classname);
		g_utaunts_name.PushString(name);
	}
	while (kv.GotoNextKey());

	kv.Rewind();
	delete kv;
	Steam_ReleaseHTTPRequest(request);
}

public Action TryAgain(Handle timer)
{
	if(hadError)
	{
		tryCount++;
		CreateRequest();
	}
}

bool IsInt(const char[] str, const int len)
{
	for (int i = 0; i < len; i++)
	{
		if (!IsCharNumeric(str[i]))
			return false;
	}

	return true;    
}
