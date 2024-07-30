#include <sdktools>
#include <sourcemod>
#include <sdktools_trace>

public Plugin myinfo =
{
	name = "Portal 1 Visible Names",
	author = "MTM101",
	description = "Makes names visible in Portal 1.",
	version = "1.0",
	url = "https://github.com/benjaminpants"
};

public void OnPluginStart()
{
	RegServerCmd("check_portal_bounds", CheckPortalBounds, "Resets the portal guns of all players to match the current settings.");
}

Action CheckPortalBounds(int args)
{
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "prop_portal")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			// if both portals are valid, exit the loop.
			float min[3];
			float max[3];
			float origin[3];
			GetEntPropVector(ent, Prop_Send, "m_vecMins", min);
			GetEntPropVector(ent, Prop_Send, "m_vecMaxs", max);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
			AddVectors(min,origin,min);
			AddVectors(max,origin,max);
			PrintToServer("%f,%f,%f | %f,%f,%f", min[0], min[1], min[2], max[0], max[1], max[2]);
		}
	}
	return Plugin_Handled;
}

bool PlayerFilter(int entity, int contentsMask, int client)
{
	if (entity == client) return false;
	return true;
}

public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(i))
		{
			float position[3];
			GetClientEyePosition(i, position);
			float angles[3];
			GetClientEyeAngles(i, angles);
			TR_TraceRayFilter(position, angles, MASK_PLAYERSOLID, RayType_Infinite, PlayerFilter, i);

			int entIndex = TR_GetEntityIndex(INVALID_HANDLE);
			if (entIndex == 0) continue;
			if (IsValidEntity(entIndex) && (entIndex <= MaxClients))
			{
				char clientName[33];
				if (GetClientName(entIndex, clientName, 33))
				{
					SetHudTextParams(-1.0,0.55,0.2,255,255,255,255,0,0.2,0.0,0.0);
					ShowHudText(i, 1, clientName);
				}
			}
		}
	}
}