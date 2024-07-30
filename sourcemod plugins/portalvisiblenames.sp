#include <sdktools>
#include <sourcemod>
#include <sdktools_trace>
#include <mathutils>
#include <portalutils>
#include <portalutils_trace>

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
			if (entIndex == 0)
			{
				float rayEnd[3];
				TR_GetEndPosition(rayEnd, INVALID_HANDLE);

				int portalIndex = GetPortalIndexOnRay(position, rayEnd);
				if (portalIndex == -1) continue;
				int portalGun = GetClientPortalGun(i);
				if (IsValidEntity(portalGun))
				{
					int linkageId = GetEntProp(portalGun, Prop_Data, "m_iPortalLinkageGroupID");
					if (GetEntProp(portalIndex, Prop_Data, "m_iLinkageGroupID") == linkageId)
					{
						continue;
					}
				}
				SetHudTextParams(-1.0,0.55,0.2,255,255,255,255,0,0.2,0.0,0.0);
				char playerName[33];
				if (!GetEntPropString(portalIndex, Prop_Data, "m_target", playerName, 33))
				{
					int gunPlacedBy = GetEntPropEnt(portalIndex,Prop_Data, "m_hPlacedBy");
					if (!IsValidEntity(gunPlacedBy))
					{
						continue;
					}
					int owner = GetOwnerOfWeapon(gunPlacedBy);
					if (IsValidEntity(owner))
					{
						GetClientName(owner, playerName, 33)
						SetEntPropString(portalIndex, Prop_Data, "m_target", playerName);
					}
				}
				ShowHudText(i, 1, "%s's Portal", playerName);
				continue;
			}
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