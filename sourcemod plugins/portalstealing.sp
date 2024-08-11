#include <sdktools>
#include <sdktools_hooks>
#include <sourcemod>
#include <entity_prop_stocks>
#include <mathutils>
#include <portalutils>
#include <portalutils_trace>
#include <halflife>

#define BLAST_SPEED 3000.0

public Plugin myinfo =
{
	name = "Portal 1 Portal Stealing",
	author = "MTM101",
	description = "Allows players to steal other player's portals.",
	version = "1.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

ConVar gcv_portalStealingEnabled;
ConVar gcv_portalStealingCrosshair;

#define MAX_PORTAL_IDS 256

// The time begins when the portal is shot and is set to how long it will take for it to place
float g_PortalStealFizzleTimes[MAX_PORTAL_IDS][2];
int g_PortalsToSteal[MAX_PORTAL_IDS][2];

public void OnPluginStart()
{
	HookEntityOutput("weapon_portalgun", "OnFiredPortal1", OnPortalGunFire);
	HookEntityOutput("weapon_portalgun", "OnFiredPortal2", OnPortalGunFire);
	HookEntityOutput("prop_portal", "OnPlacedSuccessfully", OnPlacedSuccessfully);
	gcv_portalStealingEnabled = CreateConVar("sv_portalstealing", "1", "If portal stealing should be enabled.");
	gcv_portalStealingCrosshair = CreateConVar("sv_portalstealingcrosshair", "1", "If the crosshair should attempt to display if the portal can be placed via stealing portals.");
	
	for ( int i = 0; i < MAX_PORTAL_IDS; ++i )
	{
		g_PortalStealFizzleTimes[i][0] = -1.0;
		g_PortalStealFizzleTimes[i][1] = -1.0;
	}
	
	for ( int i = 0; i < MAX_PORTAL_IDS; ++i )
	{
		g_PortalsToSteal[i][0] = -1;
		g_PortalsToSteal[i][1] = -1;
	}
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

	int portalTypeInd = 0;
	if ( !isPrimaryPortal )
	{
		portalTypeInd = 1;
	}
	
	// get the linkage id of the gun
	int linkageId = GetEntProp(portalGun, Prop_Data, "m_iPortalLinkageGroupID");
	
	int portalIndex = TR_GetPortalIndex();
	if (!IsValidEntity(portalIndex))
	{
		g_PortalStealFizzleTimes[linkageId][portalTypeInd] = -1.0;
		g_PortalsToSteal[linkageId][portalTypeInd] = -1;
		return;
	}
	
	int portalLinkageId = GetEntProp(portalIndex, Prop_Data, "m_iLinkageGroupID");
	
	if (linkageId == portalLinkageId)
	{
		g_PortalStealFizzleTimes[linkageId][portalTypeInd] = -1.0;
		g_PortalsToSteal[linkageId][portalTypeInd] = -1;
		return;
	}
		
	// get the portals position and angles and set our currently firing portal to its angles
	float portalPosition[3];
	float portalAngles[3];
	GetEntPropVector(portalIndex, Prop_Data, "m_vecOrigin", portalPosition);
	GetEntPropVector(portalIndex, Prop_Data, "m_angAbsRotation", portalAngles);
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
	
	float endPos[3];
	TR_GetEndPosition( endPos );
	
	float time = CalcPortalTravelTime( client, portalPosition );
	g_PortalStealFizzleTimes[linkageId][portalTypeInd] = time + GetEngineTime();
	g_PortalsToSteal[linkageId][portalTypeInd] = portalIndex;
}

float CalcPortalTravelTime( int client, float portalPosition[3] )
{	
	float eyeAngles[3];
	float eyePos[3];
	GetClientEyeAngles( client, eyeAngles );
	GetClientEyePosition( client, eyePos );
	
	float fwd[3];
	float right[3];
	float up[3];
	GetAngleVectors( eyeAngles, fwd, right, up );
	
	int playerPortal = GetEntPropEnt( client, Prop_Send, "m_hPortalEnvironment" );
		
	if ( IsValidEntity( playerPortal ) )
	{
		float portalCenter[3];
		GetEntPropVector( client, Prop_Data, "m_vecAbsOrigin", portalCenter );
			
		float portalAngles[3];
		GetEntPropVector( client, Prop_Data, "m_angAbsRotation", portalAngles );
		
		float portalForward[3];
		GetAngleVectors( portalAngles, portalForward, NULL_VECTOR, NULL_VECTOR );
		
		float eyeToPortalCenter[3];
		SubtractVectors( portalCenter, eyePos, eyeToPortalCenter );
		
		float portalDist = GetVectorDotProduct( portalForward, eyeToPortalCenter );
		if( portalDist > 0.0 )
		{		
			float matThisToLinked[4][4];	
			GetEntityMatrixFromProp( playerPortal, "m_matrixThisToLinked", matThisToLinked );
			
			MatrixMultiply3x3( matThisToLinked, fwd, fwd );
			MatrixMultiply3x3( matThisToLinked, right, right );
			MatrixMultiply3x3( matThisToLinked, up, up );
			MatrixPointMultiply3x3( matThisToLinked, eyePos, eyePos );
		}
	}
	
	float tracerOrigin[3];
	for ( int i = 0; i < 3; ++i )
		tracerOrigin[i] = eyePos[i] + (fwd[i] * 30.0) + (right[i] * 4.0) + (up[i] * -5.0);
	
	float delay = GetVectorDistance( tracerOrigin, portalPosition, false ) / BLAST_SPEED;
	return delay;
}

void DoCrosshairTest()
{
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

void TestForPortalReplacement()
{
	for ( int i = 0; i < MAX_PORTAL_IDS; ++i )
	{
		// Primary
		if ( g_PortalStealFizzleTimes[i][0] != -1.0 )
		{
			if ( g_PortalStealFizzleTimes[i][0] < GetEngineTime() )
			{
				// fizzle the original portal
				SetVariantBool( false );
				AcceptEntityInput(g_PortalsToSteal[i][0], "SetActivatedState");
				
				g_PortalStealFizzleTimes[i][0] = -1.0;
				g_PortalsToSteal[i][0] = -1;
			}
		}
		
		
		// Secondary
		if ( g_PortalStealFizzleTimes[i][1] != -1.0 )
		{
			if ( g_PortalStealFizzleTimes[i][1] < GetEngineTime() )
			{
				// fizzle the original portal
				SetVariantBool( false );
				AcceptEntityInput(g_PortalsToSteal[i][1], "SetActivatedState");
				
				g_PortalStealFizzleTimes[i][1] = -1.0;
				g_PortalsToSteal[i][1] = -1;
			}
		}
	}
}

// If player 1 shoots at a portal owned by player 2, player 2 moves that portal elsewhere before player 1's 
// portal reaches due to delayed placement, the portal WILL fizzle and we need to prevent that
void InvalidateStealTimesForPortal( int portal )
{
	for ( int i = 0; i < MAX_PORTAL_IDS; ++i )
	{
		// Primary
		if ( g_PortalsToSteal[i][0] == portal )
		{
			g_PortalStealFizzleTimes[i][0] = -1.0;
			g_PortalsToSteal[i][0] = -1;
		}
		// Secondary
		if ( g_PortalsToSteal[i][1] == portal )
		{
			g_PortalStealFizzleTimes[i][1] = -1.0;
			g_PortalsToSteal[i][1] = -1;
		}
	}
}

void OnPlacedSuccessfully(const char[] output, int portal, int portalGun, float delay)
{
	InvalidateStealTimesForPortal(portal);
}

public void OnGameFrame()
{
	if (!gcv_portalStealingEnabled.BoolValue) return;
	
	TestForPortalReplacement(); // Run this function before the crosshair checks
	DoCrosshairTest();
}