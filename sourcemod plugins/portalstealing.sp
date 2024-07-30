#include <sdktools>
#include <sdktools_hooks>
#include <sourcemod>
#include <entity_prop_stocks>

public Plugin myinfo =
{
	name = "Portal 1 Portal Stealing",
	author = "MTM101",
	description = "Allows players to steal other player's portals.",
	version = "0.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

// currently does nothing.
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    //buttons &= ~IN_ATTACK;
    return Plugin_Continue;
}