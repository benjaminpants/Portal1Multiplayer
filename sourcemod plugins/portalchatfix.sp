#include <sdktools>
#include <sourcemod>
 
public Plugin myinfo =
{
	name = "Portal 1 Chat Fix",
	author = "MTM101",
	description = "Fixes chat being broken in P1 Multiplayer.",
	version = "1.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	char playername[33];
	if (GetClientInfo(client, "name", playername, 32))
	{
		SetEntPropString(client, Prop_Data, "m_szNetname", playername);
	}
}