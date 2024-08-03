#include <sdktools>
#include <sourcemod>
#include <entitylump>
 
public Plugin myinfo =
{
	name = "Portal 1 Turret Fixes",
	author = "MTM101",
	description = "Fixes problems with turrets and rocket turrets in P1 multiplayer",
	version = "1.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

ConVar gcv_rocketTurretUpdateRate;

public void OnPluginStart()
{
	gcv_rocketTurretUpdateRate = CreateConVar("sv_rocketturret_updaterate", "1.0", "The update rate(in seconds) of rocket turret targets. Set to zero to disable the rocket turret fixes. Changes only take effect on map reload.");
}


// start the timer that updates rocket turret targets
public void OnMapStart()
{
	if (gcv_rocketTurretUpdateRate.FloatValue != 0.0)
	{
		CreateTimer(gcv_rocketTurretUpdateRate.FloatValue, UpdateRocketTurretTargets, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}


// inject the appropiate logic_timer and ai_relationship entities into the entity lump
// as spawning them in OnMapStart appears to not really work.
// TODO: figure out a better solution.
public void OnMapInit()
{
	EntityLump.Append();
	EntityLumpEntry aiRelationshipEntry = EntityLump.Get(EntityLump.Length() - 1);
	aiRelationshipEntry.Append("classname", "ai_relationship");
	aiRelationshipEntry.Append("origin", "100 100 100");
	aiRelationshipEntry.Append("StartActive", "0");
	aiRelationshipEntry.Append("Reciprocal", "1");
	aiRelationshipEntry.Append("rank", "100");
	aiRelationshipEntry.Append("disposition", "1");
	aiRelationshipEntry.Append("target", "player");
	aiRelationshipEntry.Append("subject", "npc_portal_turret_floor");
	aiRelationshipEntry.Append("targetname","p1fixes_turretrel");
	
	EntityLump.Append();
	EntityLumpEntry logicAutoEntry = EntityLump.Get(EntityLump.Length() - 1);
	logicAutoEntry.Append("classname", "logic_timer");
	logicAutoEntry.Append("origin", "100 100 100");
	logicAutoEntry.Append("RefireTime", "0.5");
	logicAutoEntry.Append("UseRandomTime", "0");
	logicAutoEntry.Append("StartDisabled", "0");
	logicAutoEntry.Append("OnTimer", "p1fixes_turretrel,ApplyRelationship,,0,-1");
	
	delete aiRelationshipEntry;
	delete logicAutoEntry;
}

// go through all rocket turrets and recalculate their tagets.
public Action UpdateRocketTurretTargets(Handle timer)
{
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "npc_rocket_turret")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			RecalculateRocketTurretTarget(ent);
		}
	}
}


// recalculates the rocket turret's current target(the nearest player) and sets it.
public void RecalculateRocketTurretTarget(int entityId)
{
	float smallestDist = 1000000.0;
	int foundClient = -1;
	
	float turretPos[3];
	GetEntPropVector(entityId, Prop_Send, "m_vecAbsOrigin", turretPos);
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(i))
		{
			float clientPos[3];
			GetClientAbsOrigin(i, clientPos);

			// unsure if this can be squared or not, investigate in the future.
			float dist = GetVectorDistance(clientPos, turretPos, false);
			if (dist <= smallestDist)
			{
				smallestDist = dist;
				foundClient = i;
			}
		}
	}
	// couldn't find a client, simply return early and do nothing.
	if (foundClient == -1)
	{
		return;
	}
	SetEntPropEnt(entityId, Prop_Data, "m_hEnemy", foundClient);
}