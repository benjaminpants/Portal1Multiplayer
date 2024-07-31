#include <sdktools>
#include <sdktools_hooks>
#include <sourcemod>
#include <entity_prop_stocks>
#include <mathutils>
#include <portalutils>
#include <portalutils_trace>
#include <halflife>

public Plugin myinfo =
{
	name = "Portal 1 Portal Stealing",
	author = "MTM101",
	description = "Allows players to steal other player's portals.",
	version = "0.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

/*float g_targetPortalSteals[MAXPLAYERS][2][3];
bool g_hasValidSteal[MAXPLAYERS];

// TODO: add vehicle check
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	bool firingPrimary = (buttons & IN_ATTACK);
	bool firingSecondary = (buttons & IN_ATTACK2);
    bool pressingAttack = (firingPrimary || firingSecondary);
	if (pressingAttack)
	{
		int portalGun = GetClientPortalGun(client);
		if (!IsValidEntity(portalGun))
		{
			return Plugin_Continue;
		}
		float nextPrimaryAttack = GetEntPropFloat(portalGun, Prop_Data, "m_flNextPrimaryAttack");
		float nextSecondaryAttack = GetEntPropFloat(portalGun, Prop_Data, "m_flNextSecondaryAttack");
		float nextAttack = GetEntPropFloat(client, Prop_Data, "m_flNextAttack");
		bool hasPortalGunOut = (GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") == portalGun);
		if (!hasPortalGunOut) return Plugin_Continue;
		if (nextAttack > GetEngineTime()) return Plugin_Continue;
		if (firingPrimary && (nextPrimaryAttack > GetEngineTime())) return Plugin_Continue;
		if (firingSecondary && (nextSecondaryAttack > GetEngineTime())) return Plugin_Continue;
		if (GetEntProp(client, Prop_Data, "m_nWaterLevel") == 3) return Plugin_Continue;
		float position[3];
		GetClientEyePosition(client, position);
		float angles[3];
		GetClientEyeAngles(client, angles);

		TR_TraceRayFilter(position, angles, MASK_SHOT_PORTAL, RayType_Infinite, TracePortalFilter);

		int portalIndex = TR_GetPortalIndex();
		if (!IsValidEntity(portalIndex))
		{
			PrintToServer("No portal found, no need to do anything!");
			return;
		}
		// get the linkage id of the gun
		int linkageId = GetEntProp(portalGun, Prop_Data, "m_iPortalLinkageGroupID");
		int portalLinkageId = GetEntProp(portalIndex, Prop_Data, "m_iLinkageGroupID");
		if (linkageId == portalLinkageId)
		{
			PrintToServer("Linkage matches!");
			return;
		}
		// get the portals position and angles and set our currently firing portal to its angles
		float portalPosition[3];
		float portalAngles[3];
		GetEntPropVector(portalIndex, Prop_Data, "m_vecOrigin", portalPosition);
		GetEntPropVector(portalIndex, Prop_Data, "m_angAbsRotation", portalAngles);
		g_targetPortalSteals[client - 1][0] = portalPosition;
		g_targetPortalSteals[client - 1][1] = portalAngles;
		g_hasValidSteal[client - 1] = true; // queue a portal steal
		// fizzle the original portal
		AcceptEntityInput(portalIndex, "Fizzle");
	}
    return Plugin_Continue;
}*/

public void OnPluginStart()
{
	HookEntityOutput("weapon_portalgun", "OnFiredPortal1", OnPortalGunFire);
	HookEntityOutput("weapon_portalgun", "OnFiredPortal2", OnPortalGunFire);
}

void OnPortalGunFire(const char[] output, int portalGun, int activator, float delay)
{
	bool isPrimaryPortal = (strcmp(output, "OnFiredPortal1") == 0);
	// this shouldnt ever be the case but just incase
	if (!IsValidEntity(portalGun))
	{
		PrintToServer("Caller isn't valid? %i", portalGun);
		return;
	}

	int client = GetOwnerOfWeapon(portalGun);
	if (!IsValidEntity(client))
	{
		return;
	}
	float position[3];
	GetClientEyePosition(client, position);
	float angles[3];
	GetClientEyeAngles(client, angles);

	TR_TraceRayFilter(position, angles, MASK_SHOT_PORTAL, RayType_Infinite, TracePortalFilter);

	int portalIndex = TR_GetPortalIndex();
	if (!IsValidEntity(portalIndex))
	{
		PrintToServer("No portal found, no need to do anything!");
		return;
	}
	// get the linkage id of the gun
	int linkageId = GetEntProp(portalGun, Prop_Data, "m_iPortalLinkageGroupID");
	int portalLinkageId = GetEntProp(portalIndex, Prop_Data, "m_iLinkageGroupID");
	if (linkageId == portalLinkageId)
	{
		PrintToServer("Linkage matches!");
		return;
	}
	// get the portals position and angles and set our currently firing portal to its angles
	float portalPosition[3];
	float portalAngles[3];
	GetEntPropVector(portalIndex, Prop_Data, "m_vecOrigin", portalPosition);
	GetEntPropVector(portalIndex, Prop_Data, "m_angAbsRotation", portalAngles);
	// fizzle the original portal
	AcceptEntityInput(portalIndex, "Fizzle");
	int clientPortalIndexes[2];
	FindAllPortalsOfLinkageID(linkageId, clientPortalIndexes);
	int targetPortal = -1;
	if (isPrimaryPortal)
	{
		targetPortal = clientPortalIndexes[0];
	}
	else
	{
		targetPortal = clientPortalIndexes[1];
	}
	if (!IsValidEntity(targetPortal))
	{
		PrintToServer("targetPortal not valid? Help?");
		return;
	}
	SetEntProp(targetPortal, Prop_Data, "m_iDelayedFailure", 0);
	SetEntPropVector(targetPortal, Prop_Data, "m_vDelayedPosition", portalPosition);
	SetEntPropVector(targetPortal, Prop_Data, "m_qDelayedAngles", portalAngles);
}