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