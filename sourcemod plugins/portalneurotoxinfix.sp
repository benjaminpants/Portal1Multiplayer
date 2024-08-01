#include <sdktools>
#include <sdkhooks>
#include <sourcemod>
#include <halflife>


public Plugin myinfo =
{
	name = "Portal 1 Neurotoxin Fix",
	author = "MTM101",
	description = "Creates a startserverneurotoxins command that can be used to all",
	version = "1.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

float g_neurotoxinTimestamp = -1.0;
bool g_killInitiated = false;

public void OnMapStart()
{
	g_neurotoxinTimestamp = -1.0;
	g_killInitiated = false;
	RegServerCmd("startserverneurotoxins", Command_StartNeurotoxin, "Starts the neurotoxin countdown serverside.");
	AddCommandListener(Listener_StartNeurotoxins, "startneurotoxins");
	CreateTimer(0.1, UpdateNeurotoxinHandler, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action UpdateNeurotoxinHandler(Handle timer)
{
	if (g_neurotoxinTimestamp == -1.0) return;
	int client = 1; //just to make the code easier to read, lol.
	if (!IsValidEntity(client))
	{
		int fakeClient = CreateFakeClient("Neurotoxin Helper");
		if (fakeClient != 1)
		{
			ThrowError("Fake client unable to join or got non-one index! %i", fakeClient);
		}
		/*float newPosition[3];
		// into out of bounds you go!
		newPosition[0] = 33000.0;
		newPosition[1] = 33000.0;
		newPosition[2] = 33000.0;
		TeleportEntity(client, newPosition, NULL_VECTOR, NULL_VECTOR);*/
	}
	float timeRemaining = g_neurotoxinTimestamp - GetEngineTime();
	if (timeRemaining < 0.0)
	{
		timeRemaining = 0.0;
		if (!g_killInitiated)
		{
			g_killInitiated = true;
			CreateTimer(3.5, ReloadMapDelay);
		}
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsValidEntity(i)) continue;
			SDKHooks_TakeDamage(i, 0, 0, GetTickInterval() * 50.0, DMG_NERVEGAS, -1, NULL_VECTOR, NULL_VECTOR, false);
		}
	}
	SetEntProp(client, Prop_Data, "m_iBonusProgress", RoundToFloor(timeRemaining));
	SetEntProp(client, Prop_Data, "m_bPauseBonusProgress", false);
}

Action Listener_StartNeurotoxins(int client, const char[] sCommand, any argc)
{
	return Plugin_Handled;
}

Action Command_StartNeurotoxin(int args)
{
	float time;
	if (args == 0)
	{
		time = 180.0;
	}
	else
	{
		time = GetCmdArgFloat(1);
	}
	g_neurotoxinTimestamp = GetEngineTime() + time;
	return Plugin_Handled;
}

void KickNeurotoxinHelper()
{
	if (IsFakeClient(1))
	{
		KickClientEx(1);
	}
}

Action ReloadMapDelay(Handle timer)
{
	KickNeurotoxinHelper();
	char mapName[129];
	GetCurrentMap(mapName, 129);
	ServerCommand("changelevel %s", mapName);
}