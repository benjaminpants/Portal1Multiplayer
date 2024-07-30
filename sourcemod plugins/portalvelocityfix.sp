#include <sdktools>
#include <sourcemod>
#include <entitylump>

public Plugin myinfo =
{
	name = "Portal 1 Portal Velocity Fix",
	author = "MTM101",
	description = "Massively improves the consistency of Portals in Portal 1 multiplayer.",
	version = "1.0",
	url = "https://github.com/benjaminpants"
};

float g_playerVelocities[MAXPLAYERS][3];

const float cnst_floorPortalZAngle = 0.7071;

ConVar gcv_portalVelocityCap;
ConVar gcv_portalMinExit;

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("EntityPortalled"), Event_PlayerPortalled, false);
	gcv_portalVelocityCap = CreateConVar("sv_portal_velocitycap", "1000.0", "The maximum exit velocity of portals.");
	gcv_portalMinExit = CreateConVar("sv_portal_floorportalexit", "300.0", "The minimum Z velocity when exiting through floor portals.");
}

public Action Event_PlayerPortalled(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int portal = msg.ReadNum();
	int entity = msg.ReadNum();

	// why the fuck.
	entity = (entity & ((1 << 11)) - 1);
	portal = (portal & ((1 << 11)) - 1);

	int linkedPortal = GetEntPropEnt(portal, Prop_Data, "m_hLinkedPortal");
	
	// this entity is not a player so ignore it.
	if (entity > MaxClients)
	{
		return;
	}

	int matrixOffset = FindDataMapInfo(portal, "m_matrixThisToLinked");
	float matrix[4][4];

	float flatMatrix[16];

	for (int i = 0; i < 16; i++)
	{
		flatMatrix[i] = GetEntDataFloat(portal, matrixOffset + (i * 4));
	}

	matrix[0][0] = flatMatrix[0];
	matrix[0][1] = flatMatrix[1];
	matrix[0][2] = flatMatrix[2];
	matrix[0][3] = flatMatrix[3];

	matrix[1][0] = flatMatrix[4];
	matrix[1][1] = flatMatrix[5];
	matrix[1][2] = flatMatrix[6];
	matrix[1][3] = flatMatrix[7];

	matrix[2][0] = flatMatrix[8];
	matrix[2][1] = flatMatrix[9];
	matrix[2][2] = flatMatrix[10];
	matrix[2][3] = flatMatrix[11];

	matrix[3][0] = flatMatrix[12];
	matrix[3][1] = flatMatrix[13];
	matrix[3][2] = flatMatrix[14];
	matrix[3][3] = flatMatrix[15];

	float portalAngles[3];
	GetEntPropVector(linkedPortal, Prop_Data, "m_angAbsRotation", portalAngles);

	float portalForward[3];
	GetAngleVectors(portalAngles, portalForward, NULL_VECTOR, NULL_VECTOR);
	
	float output[3];
	MatrixMultiply3x3(matrix, g_playerVelocities[entity - 1], output);

	float floorMinExit = gcv_portalMinExit.FloatValue;
	if (portalForward[2] > cnst_floorPortalZAngle)
	{
		if (output[2] < floorMinExit)
		{
			output[2] = floorMinExit;
		}
	}

	float velocityCap = gcv_portalVelocityCap.FloatValue;

	if (GetVectorLength(output, true) > (velocityCap * velocityCap))
	{
		float multiplier = (velocityCap / GetVectorLength(output, false));
		output[0] *= multiplier;
		output[1] *= multiplier;
		output[2] *= multiplier;
	}

	SetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", output);
	//PrintToServer("Last recorded velocity before velocity set, %f, %f, %f", g_playerVelocities[entity - 1][0], g_playerVelocities[entity - 1][1], g_playerVelocities[entity - 1][2]);
	//PrintToServer("Set velocity, %f, %f, %f", output[0], output[1], output[2]);
}


// 1:1 port of MatrixMultiply3x3 from vmatrix.h
void MatrixMultiply3x3(float m[4][4], float vVec[3], float outputVec[3])
{
	outputVec[0] = m[0][0]*vVec[0] + m[0][1]*vVec[1] + m[0][2]*vVec[2];
	outputVec[1] = m[1][0]*vVec[0] + m[1][1]*vVec[1] + m[1][2]*vVec[2];
	outputVec[2] = m[2][0]*vVec[0] + m[2][1]*vVec[1] + m[2][2]*vVec[2];
}

public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(i))
		{
			GetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", g_playerVelocities[i - 1]);
		}
	}
}