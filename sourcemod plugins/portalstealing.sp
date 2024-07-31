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

ConVar gcv_portalStealingEnabled;
ConVar gcv_portalStealingCrosshair;

public void OnPluginStart()
{
	HookEntityOutput("weapon_portalgun", "OnFiredPortal1", OnPortalGunFire);
	HookEntityOutput("weapon_portalgun", "OnFiredPortal2", OnPortalGunFire);
	gcv_portalStealingEnabled = CreateConVar("sv_portalstealing", "1", "If portal stealing should be enabled.");
	gcv_portalStealingCrosshair = CreateConVar("sv_portalstealingcrosshair", "1", "If the crosshair should attempt to display if the portal can be placed via stealing portals.");
}

void OnPortalGunFire(const char[] output, int portalGun, int activator, float delay)
{
	if (!gcv_portalStealingEnabled.BoolValue) return;
	bool isPrimaryPortal = (strcmp(output, "OnFiredPortal1") == 0);
	// this shouldnt ever be the case but just incase
	if (!IsValidEntity(portalGun))
	{
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
		return;
	}
	// get the linkage id of the gun
	int linkageId = GetEntProp(portalGun, Prop_Data, "m_iPortalLinkageGroupID");
	int portalLinkageId = GetEntProp(portalIndex, Prop_Data, "m_iLinkageGroupID");
	if (linkageId == portalLinkageId)
	{
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
		return;
	}
	SetEntProp(targetPortal, Prop_Data, "m_iDelayedFailure", 0);
	SetEntPropVector(targetPortal, Prop_Data, "m_vDelayedPosition", portalPosition);
	SetEntPropVector(targetPortal, Prop_Data, "m_qDelayedAngles", portalAngles);
}



public void OnGameFrame()
{
	if (!gcv_portalStealingEnabled.BoolValue) return;
	if (!gcv_portalStealingCrosshair.BoolValue) return;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidEntity(client))
		{
			int activeWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if (!IsValidEntity(activeWeapon)) continue;
			char className[33];
			GetEntityClassname(activeWeapon, className, 33);
			if (strcmp(className, "weapon_portalgun") != 0) continue;

			float position[3];
			GetClientEyePosition(client, position);
			float angles[3];
			GetClientEyeAngles(client, angles);

			TR_TraceRayFilter(position, angles, MASK_SHOT_PORTAL, RayType_Infinite, TracePortalFilter);

			int portalIndex = TR_GetPortalIndex();
			if (!IsValidEntity(portalIndex)) continue;
			int linkageId = GetEntProp(activeWeapon, Prop_Data, "m_iPortalLinkageGroupID");
			int portalLinkageId = GetEntProp(portalIndex, Prop_Data, "m_iLinkageGroupID");
			if (linkageId == portalLinkageId) continue;
			if ((GetEntProp(activeWeapon, Prop_Send, "m_bCanFirePortal1") == 1))
			{
				SetEntPropFloat(activeWeapon, Prop_Send, "m_fCanPlacePortal1OnThisSurface", 1.0);
			}
			if ((GetEntProp(activeWeapon, Prop_Send, "m_bCanFirePortal2") == 1))
			{
				SetEntPropFloat(activeWeapon, Prop_Send, "m_fCanPlacePortal2OnThisSurface", 1.0);
			}
		}
	}
}