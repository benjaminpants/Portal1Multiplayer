#include <sdktools>
#include <sourcemod>

public Plugin myinfo =
{
	name = "Portal 1 GLaDOS Fix",
	author = "MTM101",
	description = "Fixes GLaDOS lines not being hearable in Portal 1 multiplayer. Sometimes. Still WIP.",
	version = "1.0",
	url = "https://github.com/benjaminpants"
};

int g_playerGLaDOSMap[MAXPLAYERS] = {-1, ...};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
}

public void OnMapStart()
{
	/*for (int i = 0; i < MAXPLAYERS; i++)
	{
		g_playerGLaDOSMap[i] = -1;
	}*/
	PrecacheModel("models/blackout.mdl");
	CreateTimer(0.1, UpdateDummyGLaDOS, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action UpdateDummyGLaDOS(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(i) && IsValidEntity(g_playerGLaDOSMap[i]))
		{
			new Float:position[3];
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", position);
			position[2] = position[2] + 32.0;
			TeleportEntity(g_playerGLaDOSMap[i - 1], position, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidEntity(g_playerGLaDOSMap[client - 1]))
	{
		return;
	}
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	CreateTimer(0.2, CreateDummyGLaDOS, pack);
	
}

public Action CreateDummyGLaDOS(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int entityId = CreateEntityByName("generic_actor");
	if (entityId != -1)
	{
		new Float:position[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
		position[2] = position[2] + 32.0;
		DispatchKeyValue(entityId, "model", "models/blackout.mdl");
		DispatchKeyValue(entityId, "targetname", "Aperture_AI");
		TeleportEntity(entityId, position, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(entityId);
		g_playerGLaDOSMap[client - 1] = EntIndexToEntRef(entityId);
		PrintToServer("Created GLaDOS dummy for %i! (%i)", client, g_playerGLaDOSMap[client - 1]);
	}
	else
	{
		PrintToServer("Creating GLaDOS dummy failed for %i!", client);
	}
	CloseHandle(pack);
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client == 0)
	{
		PrintToServer("Disconnect failure! Can't clear GLaDOS dummy!");
		return;
	}
	if (IsValidEntity(g_playerGLaDOSMap[client - 1]))
	{
		PrintToServer("Deleting GLaDOS dummy for %i!", client);
		AcceptEntityInput(g_playerGLaDOSMap[client - 1], "Kill");
		g_playerGLaDOSMap[client - 1] = -1;
	}
}