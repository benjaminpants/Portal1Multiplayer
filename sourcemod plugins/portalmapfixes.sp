#include <sdktools>
#include <sourcemod>
#include <entitylump>

public Plugin myinfo =
{
	name = "Portal 1 Map Fixes",
	author = "MTM101",
	description = "Attempts to improve the playability of the campaign maps in multiplayer.",
	version = "1.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

public void OnMapInit()
{
	PrintToServer("Modifying entities...");
	bool doNeurotoxinFixes = false;//(GetCommandFlags("startserverneurotoxins") != INVALID_FCVAR_FLAGS);
	int entitiesChangedOrDeleted = 0;
	// add our point_servercommand since we will likely be needing it
	EntityLump.Append();
	EntityLumpEntry serverCommandEntity = EntityLump.Get(EntityLump.Length() - 1);
	serverCommandEntity.Append("classname", "point_servercommand");
	serverCommandEntity.Append("origin", "100 100 100");
	serverCommandEntity.Append("targetname","pmp_servercommand");
	delete serverCommandEntity;

	int entLumpLength = EntityLump.Length();
	// iterate through backwards so we can delete things from the lump without breaking things
	for (int i = entLumpLength - 1; i >= 0; i--)
	{
		bool modifiedEntry = false;
		EntityLumpEntry entry = EntityLump.Get(i);
		char classN[64];
		int classNameIndex = entry.GetNextKey("classname", classN, 64);
		if (classNameIndex == -1)
		{
			delete entry;
			continue;
		}

		char globalN[128];
		int globalNameIndex = entry.GetNextKey("globalname", globalN, 128);
		if (globalNameIndex != -1)
		{
			entry.Erase(globalNameIndex);
			classNameIndex = entry.GetNextKey("classname", classN, 64); // could've shifted when we erased globalname.
			entitiesChangedOrDeleted++;
			modifiedEntry = true;
		}

		// iterate through all keys and check for any startneurotoxin calls
		if (doNeurotoxinFixes)
		{
			int keyLength = entry.Length;
			for (int j = 0; j < keyLength; j++)
			{
				char keyBuffer[64];
				char valueBuffer[128];
				entry.Get(j, keyBuffer, 64, valueBuffer, 128);
				if (StrContains(valueBuffer, "startneurotoxins ", true) != -1)
				{
					// get the entityName and then replace it with pmp_servercommand

					// so explode string will only store the first one it finds
					char entityName[1][128];
					ExplodeString(valueBuffer, ",", entityName, 1, 128);
					ReplaceStringEx(valueBuffer, 128, entityName[0], "pmp_servercommand", -1, -1, true);
					ReplaceStringEx(valueBuffer, 128, "startneurotoxins ", "startserverneurotoxins ", -1, -1, true);
					entry.Update(j, NULL_STRING, valueBuffer);
				}
			}
		}

		if (strcmp(classN, "point_bonusmaps_accessor") == 0)
		{
			EntityLump.Erase(i);
			if (!modifiedEntry)
			{
				entitiesChangedOrDeleted++;
			}
			delete entry;
			continue;
		}
		
		// go through any logic relays and attempt to detect references to the elevator_body model.
		// since we switch out prop_portal_stats_display for prop_dynamics, the disable input disables the elevators visuals which is
		// not what we want.
		if (strcmp(classN, "logic_relay") == 0)
		{
			char outputString[256];
			int keyIndex = -1;
			while ((keyIndex = entry.GetNextKey("OnTrigger", outputString, 256, keyIndex)) != -1)
			{
				if (StrContains(outputString, "elevator_body", true) != -1)
				{
					entry.Erase(keyIndex);
					keyIndex = -1;
					if (!modifiedEntry)
					{
						entitiesChangedOrDeleted++;
						modifiedEntry = true;
					}
				}
			}

			delete entry;
			continue;
		}

		if (strcmp(classN, "path_track") == 0)
		{
			char outputString[256];
			int keyIndex = -1;
			while ((keyIndex = entry.GetNextKey("OnPass", outputString, 256, keyIndex)) != -1)
			{
				if (StrContains(outputString, "ChangeLevel", true) != -1)
				{
					entLumpLength = EntityLump.Length();
					char entName[64];
					char changeLevelName[64];
					SplitString(outputString, ",", entName, 64);
					for (int j = entLumpLength - 1; j >= 0; j--)
					{
						EntityLumpEntry subEntry = EntityLump.Get(j);
						char subTargetName[64];
						int targetNameIndex = subEntry.GetNextKey("targetname", subTargetName, 64);
						if (targetNameIndex == -1)
						{
							delete subEntry;
							continue;
						}
						if (strcmp(entName, subTargetName) == 0)
						{
							int levelNameIndex = subEntry.GetNextKey("map",changeLevelName, 64);
							if (levelNameIndex == -1)
							{
								subTargetName = "testchmb_a_00";
							}
							break;
						}
						delete subEntry;
						continue;
					}
					char targetCommmand[128] = "pmp_servercommand,Command,changelevel %s,0,-1";
					Format(targetCommmand, 128, targetCommmand, changeLevelName);
					entry.Update(keyIndex, NULL_STRING, targetCommmand);
					if (!modifiedEntry)
					{
						entitiesChangedOrDeleted++;
						modifiedEntry = true;
					}
				}
			}

			delete entry;
			continue;
		}

		// replace prop_portal_stats_display's with prop_dynamics, as when prop_portal_stats_displays are activated the server WILL crash
		// TODO: ignore prop_portal_stats_display's with no inputs going into them as those dont crash the game. (and for some reason certain prop_portal_stats_display's dont work when turned into prop_dynamics...)
		if (strcmp(classN, "prop_portal_stats_display") == 0)
		{
			entry.Update(classNameIndex, NULL_STRING, "prop_dynamic");
			entry.Append("model", "models/props/round_elevator_body.mdl");
			entry.Append("modelscale", "1.0");
			entry.Append("renderamt", "255");
			entry.Append("solid", "6");
			entry.Append("fademindist", "-1");
			entry.Append("fadescale", "1");
			entry.Append("rendercolor", "255 255 255");
			entry.Append("MaxAnimTime", "10");
			entry.Append("MinAnimTime", "5");
			entry.Append("DisableBoneFollowers", "0");
			entry.Append("disablereceiveshadows", "0");
			entry.Append("disableshadows", "0");
			entry.Append("ExplodeDamage", "0");
			entry.Append("StartDisabled", "0");
			entry.Append("ExplodeRadius", "0");
			entry.Append("spawnflags", "0");
			entry.Append("fademaxdist", "0");
			entry.Append("skin", "0");
			entry.Append("SetBodyGroup", "0");
			entry.Append("rendermode", "0");
			entry.Append("renderfx", "0");
			entry.Append("maxdxlevel", "0");
			entry.Append("mindxlevel", "0");
			entry.Append("RandomAnimation", "0");
			entry.Append("pressuredelay", "0");
			entry.Append("PerformanceMode", "0");
			if (!modifiedEntry)
			{
				entitiesChangedOrDeleted++;
			}
			delete entry;
			continue;
		}

		// trigger looks behave wonkily in multiplayer
		// TODO: add an option to turn this off incase someone REALLY wants trigger_look for some reason.
		if (strcmp(classN, "trigger_look") == 0)
		{
			entry.Update(classNameIndex, NULL_STRING, "trigger_once");
			delete entry;
			continue;
		}

		// delete any trigger_transitions, as these cause elevators to disappear if changelevel is used
		if (strcmp(classN, "trigger_transition") == 0)
		{
			EntityLump.Erase(i);
			if (!modifiedEntry)
			{
				entitiesChangedOrDeleted++;
			}
			delete entry;
			continue;
		}

		delete entry;
	}

	PrintToServer("Modified/Deleted %i entities!", entitiesChangedOrDeleted);
}