#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "Portal 1 Stats",
	author = "MTM101",
	description = "Allows players to use the portalstats command to view their stats as they would appear in challenge mode.",
	version = "1.0",
	url = "https://github.com/benjaminpants"
};

public void OnPluginStart()
{
	RegConsoleCmd("portalstats", Command_PortalStats);
}

public Action Command_PortalStats(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "portalstats command must be called from client.");
		return Plugin_Handled;
	}
	int stepsTaken = GetEntProp(client, Prop_Data, "m_StatsThisLevel.iNumStepsTaken");
	int portalsFired = GetEntProp(client, Prop_Data, "m_StatsThisLevel.iNumPortalsPlaced");
	float timePassed = GetEntPropFloat(client, Prop_Data, "m_StatsThisLevel.fNumSecondsTaken");
	char playername[33];
	GetClientName(client, playername, 33);
	ReplyToCommand(client, "Stats for %s:\nTime Passed: %is\nPortals Fired: %i\nSteps Taken: %i", playername, RoundToFloor(timePassed), portalsFired, stepsTaken);
	return Plugin_Handled;
}