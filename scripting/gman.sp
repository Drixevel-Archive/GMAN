//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//ConVars
ConVar convar_Status;
ConVar convar_Status_Spawns;
ConVar convar_Spawns_Amount;
ConVar convar_Spawns_Chance;
ConVar convar_Status_Sounds;
ConVar convar_Sounds_Volume;
ConVar convar_Sounds_Chance;

//Globals
bool g_bLate;
ArrayList g_GMANs;
ArrayList g_Sounds;

public Plugin myinfo =
{
	name = "Mr...Freeman",
	author = "Keith Warren (Shaders Allen)",
	description = "Wake up... Mr. Freeman... wake up... and smell the ashes.",
	version = "1.0.0",
	url = "http://www.marclaidlaw.com/epistle-3/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	convar_Status = CreateConVar("sm_gman_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Status_Spawns = CreateConVar("sm_gman_status_spawns", "1", "Status for random spawns to play.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Spawns_Amount = CreateConVar("sm_gman_spawns_amount", "1", "Amount of random spawns per new round.", FCVAR_NOTIFY, true, 0.0);
	convar_Spawns_Chance = CreateConVar("sm_gman_spawns_chance", "950.0", "Chance for the spawns to happen.", FCVAR_NOTIFY, true, 0.0, true, 1000.0);
	convar_Status_Sounds = CreateConVar("sm_gman_status_sounds", "1", "Status for random sounds to play.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Sounds_Volume = CreateConVar("sm_gman_sounds_volume", "0.08", "Volume level for sounds to play.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Sounds_Chance = CreateConVar("sm_gman_sounds_chance", "950.0", "Chance for the sounds to play.", FCVAR_NOTIFY, true, 0.0, true, 1000.0);
	AutoExecConfig();

	g_GMANs = new ArrayList();

	HookEvent("teamplay_round_start", Event_OnRoundStart);

	RegAdminCmd("sm_spawngman", Command_SpawnGMAN, ADMFLAG_SLAY, "Spawn a Gman permanently where you're standing.");
	RegAdminCmd("sm_deletegman", Command_DeleteGMAN, ADMFLAG_SLAY, "Delete a Gman on the current map you're looking at.");

	g_Sounds = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_Sounds.PushString("vo/citadel/gman_exit01.wav");
	g_Sounds.PushString("vo/citadel/gman_exit02.wav");
	g_Sounds.PushString("vo/citadel/gman_exit03.wav");
	g_Sounds.PushString("vo/citadel/gman_exit04.wav");
	g_Sounds.PushString("vo/citadel/gman_exit05.wav");
	g_Sounds.PushString("vo/citadel/gman_exit06.wav");
	g_Sounds.PushString("vo/citadel/gman_exit07.wav");
	g_Sounds.PushString("vo/citadel/gman_exit08.wav");
	g_Sounds.PushString("vo/citadel/gman_exit09.wav");
	g_Sounds.PushString("vo/citadel/gman_exit10.wav");
	g_Sounds.PushString("vo/gman_misc/gman_02.wav");
	g_Sounds.PushString("vo/gman_misc/gman_03.wav");
	g_Sounds.PushString("vo/gman_misc/gman_04.wav");
	g_Sounds.PushString("vo/gman_misc/gman_riseshine.wav");
}

public void OnPluginEnd()
{
	ClearGMANs();
}

public void OnMapStart()
{
	//Models
	g_GMANs.Clear();
	PrecacheModel("models/gman.mdl");

	//Sounds
	char sBuffer[PLATFORM_MAX_PATH];
	for (int i = 0; i < g_Sounds.Length; i++)
	{
		g_Sounds.GetString(i, sBuffer, sizeof(sBuffer));
		PrecacheSound(sBuffer);
	}
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue)
	{
		return;
	}

	if (g_bLate)
	{
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));
		GetMapDisplayName(sMap, sMap, sizeof(sMap));

		SpawnMapGMANs(sMap);

		PlayRandomSound();

		g_bLate = false;
	}
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
	{
		return;
	}

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));

	SpawnMapGMANs(sMap);

	PlayRandomSound();
}

void PlayRandomSound()
{
	if (!convar_Status.BoolValue || !convar_Status_Sounds.BoolValue)
	{
		return;
	}

	if (GetRandomFloat(0.0, 1000.0) > convar_Sounds_Chance.FloatValue)
	{
		CreateTimer(GetRandomFloat(0.5, 10.0), Timer_PlayRandomSound, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_PlayRandomSound(Handle timer)
{
	if (!convar_Status.BoolValue || !convar_Status_Sounds.BoolValue)
	{
		return Plugin_Stop;
	}

	char sBuffer[PLATFORM_MAX_PATH];
	g_Sounds.GetString(GetRandomInt(0, g_Sounds.Length - 1), sBuffer, sizeof(sBuffer));

	EmitSoundToAll(sBuffer, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, convar_Sounds_Volume.FloatValue);
	return Plugin_Stop;
}

void SpawnMapGMANs(const char[] map)
{
	if (!convar_Status.BoolValue || !convar_Status_Spawns.BoolValue)
	{
		return;
	}

	g_GMANs.Clear();

	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/gman.cfg");

	KeyValues kv = new KeyValues("gman");

	ArrayList g_Names = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
	StringMap g_Origin = new StringMap();
	StringMap g_Angles = new StringMap();

	char sName[MAX_NAME_LENGTH];
	float vecOrigin[3];
	float vecAngles[3];

	if (kv.ImportFromFile(sPath) && kv.JumpToKey(map, true) && kv.GotoFirstSubKey())
	{
		do
		{
			kv.GetSectionName(sName, sizeof(sName));

			if (strlen(sName) == 0)
			{
				continue;
			}

			g_Names.PushString(sName);

			kv.GetVector("origin", vecOrigin);
			g_Origin.SetArray(sName, vecOrigin, sizeof(vecOrigin));

			kv.GetVector("angles", vecAngles);
			g_Angles.SetArray(sName, vecAngles, sizeof(vecAngles));
		}
		while (kv.GotoNextKey());
	}

	delete kv;

	for (int i = 0; i < convar_Spawns_Amount.IntValue; i++)
	{
		if (GetRandomFloat(0.0, 1000.0) > convar_Spawns_Chance.FloatValue)
		{
			continue;
		}

		g_Names.GetString(GetRandomInt(0, g_Names.Length - 1), sName, sizeof(sName));
		g_Origin.GetArray(sName, vecOrigin, sizeof(vecOrigin));
		g_Angles.GetArray(sName, vecAngles, sizeof(vecAngles));

		if (strlen(sName) > 0)
		{
			SpawnGMAN(sName, vecOrigin, vecAngles);
		}
	}

	delete g_Names;
	delete g_Origin;
	delete g_Angles;
}

void SpawnGMAN(const char[] name, float origin[3], float angle[3])
{
	if (!convar_Status.BoolValue || !convar_Status_Spawns.BoolValue)
	{
		return;
	}

	int entity = CreateEntityByName("prop_dynamic");

	if (IsValidEntity(entity))
	{
		DispatchKeyValue(entity, "targetname", name);
		DispatchKeyValue(entity, "solid", "6");
		DispatchKeyValue(entity, "model", "models/gman.mdl");
		DispatchKeyValue(entity, "DefaultAnim", "idle");
		DispatchKeyValueVector(entity, "origin", origin);
		DispatchKeyValueVector(entity, "angles", angle);
		DispatchSpawn(entity);

		int reference = EntIndexToEntRef(entity);
		g_GMANs.Push(reference);
	}
}

void ClearGMANs()
{
	int entity;
	for (int i = 0; i < g_GMANs.Length; i++)
	{
		entity = EntRefToEntIndex(g_GMANs.Get(i));

		if (IsValidEntity(entity))
		{
			AcceptEntityInput(entity, "Kill");
		}
	}

	g_GMANs.Clear();
}

public Action Command_SpawnGMAN(int client, int args)
{
	if (!convar_Status.BoolValue)
	{
		return Plugin_Handled;
	}

	if (!convar_Status_Spawns.BoolValue)
	{
		return Plugin_Handled;
	}

	if (IsClientConsole(client))
	{
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}

	char sName[MAX_NAME_LENGTH];
	GetCmdArgString(sName, sizeof(sName));

	if (strlen(sName) == 0)
	{
		PrintToChat(client, "[GMAN] Specify a name.");
		return Plugin_Handled;
	}

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));

	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);

	float vecAngles[3];
	GetClientAbsAngles(client, vecAngles);

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/gman.cfg");

	KeyValues kv = new KeyValues("gman");

	if (kv.ImportFromFile(sPath) && kv.JumpToKey(sMap, true) && kv.JumpToKey(sName, true))
	{
		kv.SetVector("origin", vecOrigin);
		kv.SetVector("angles", vecAngles);

		kv.Rewind();
		kv.ExportToFile(sPath);

		SpawnGMAN(sName, vecOrigin, vecAngles);
		PrintToChat(client, "[GMAN] Position '%s' saved: %.2f/%.2f/%.2f", sName, vecOrigin[0], vecOrigin[1], vecOrigin[2]);
	}
	else
	{
		PrintToChat(client, "[GMAN] Error creating position '%s' inside of config.", sName);
	}

	delete kv;

	return Plugin_Handled;
}

public Action Command_DeleteGMAN(int client, int args)
{
	if (!convar_Status.BoolValue)
	{
		return Plugin_Handled;
	}

	if (!convar_Status_Spawns.BoolValue)
	{
		return Plugin_Handled;
	}

	int target = GetClientAimTarget(client, false);

	if (!IsValidEntity(target) || !IsEntityIndex(target))
	{
		PrintToChat(client, "GMAN not found, please look at him.");
		return Plugin_Handled;
	}

	int index = g_GMANs.FindValue(EntIndexToEntRef(target));

	if (index == -1)
	{
		PrintToChat(client, "Not a valid GMAN model.");
		return Plugin_Handled;
	}

	char sName[64];
	GetEntPropString(target, Prop_Data, "m_iName", sName, sizeof(sName));

	AcceptEntityInput(target, "Kill");
	g_GMANs.Erase(index);

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/gman.cfg");

	KeyValues kv = new KeyValues("gman");

	if (kv.ImportFromFile(sPath) && kv.JumpToKey(sMap, true) && kv.DeleteKey(sName))
	{
		kv.Rewind();
		kv.ExportToFile(sPath);

		PrintToChat(client, "[GMAN] Position '%s' has been deleted.", sName);
	}
	else
	{
		PrintToChat(client, "[GMAN] Error deleting position '%s' from config.", sName);
	}

	delete kv;

	return Plugin_Handled;
}
