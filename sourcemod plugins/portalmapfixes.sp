#include <sdktools>
#include <sourcemod>
#include <entitylump>
#include <keyvalues>
#include <halflife>

public Plugin myinfo =
{
	name = "Portal 1 Map Fixes",
	author = "MTM101",
	description = "Attempts to improve the playability of the campaign maps in multiplayer via modifying entity lumps and special logic.",
	version = "1.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

KeyValues LoadManualConfig()
{
	KeyValues keyValues = new KeyValues("MapCorrections");
	if (keyValues.ImportFromFile("portalmanualmapfix.txt"))
	{
		return keyValues;
	}
	PrintToServer("Failed to read config keyvalues!");
	delete keyValues;
	return null;
}

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

	PrintToServer("Performing manual changes...");
	KeyValues mt = LoadManualConfig();
	if (mt == null) return;
	entitiesChangedOrDeleted = 0;
	char mapName[65];
	GetCurrentMap(mapName,65);
	if (!mt.JumpToKey(mapName))
	{
		delete mt;
		PrintToServer("No manual changes for %s found.", mapName);
		return;
	}
	// get the info_player_start that should be moved when a checkpoint is reached.
	char startToNameBuffer[33];
	mt.GetString("PlayerStartToMove", startToNameBuffer, 33);
	EntityLumpEntry playerEntry = SearchForEntityInLump(startToNameBuffer, 33);
	if (playerEntry != null)
	{
		PrintToServer("Found player lump! Adding key...");
		playerEntry.Append("targetname", "portal_player_spawnpoint");
		entitiesChangedOrDeleted++;
		delete playerEntry;
	}
	// delete the specified outputs.
	if (mt.JumpToKey("DeleteOutputs"))
	{
		bool wentToNextKey = mt.GotoFirstSubKey(false);
		// todo: actually figure out what this code does to navigate the tree.
		// i genuinely spent hours on figuring this out this sucked.
		while (wentToNextKey)
		{
			char entTargetNameBuffer[255];
			mt.GetSectionName(entTargetNameBuffer, 255);
			EntityLumpEntry entLump = SearchForEntityInLump(entTargetNameBuffer, 255);
			if (entLump == null)
			{
				wentToNextKey = mt.GotoNextKey(false);
				PrintToServer("Couldn't find entity %s in DeleteOutputs. Skipping...", entTargetNameBuffer);
				continue;
			}
			PrintToServer("delete %s", entTargetNameBuffer);
			if (mt.GotoFirstSubKey(false))
			{
				bool browsedNextKey = true;
				while (browsedNextKey)
				{
					char outputKey[255]; // the output/key we will be scanning for
					char targetOutput[255]; // the output value we are looking for
					char outputValue[255]; // the value of the currently scanned output
					mt.GetSectionName(outputKey, 255);
					mt.GetString(NULL_STRING, targetOutput, sizeof(targetOutput));
					int keyIndex = -1;
					while ((keyIndex = entLump.GetNextKey(outputKey, outputValue, sizeof(outputValue), keyIndex)) != -1)
					{
						if (strcmp(outputValue, targetOutput) == 0)
						{
							//PrintToServer("Found target: %s! Deleting...", targetOutput);
							entLump.Erase(keyIndex); // we have found our target, deleting...
							keyIndex = -1;
							break;
						}
					}
					browsedNextKey = mt.GotoNextKey(false);
				}
				mt.GoBack();
			}
			entitiesChangedOrDeleted++;
			delete entLump; //we are done with it. carry on.
			wentToNextKey = mt.GotoNextKey(false);
		}
	}
	mt.Rewind();
	mt.JumpToKey(mapName);
	if (mt.JumpToKey("AddOutputs"))
	{
		bool wentToNextKey = mt.GotoFirstSubKey(false);
		while (wentToNextKey)
		{
			char entTargetNameBuffer[255];
			mt.GetSectionName(entTargetNameBuffer, 255);
			EntityLumpEntry entLump = SearchForEntityInLump(entTargetNameBuffer, 255);
			if (entLump == null)
			{
				wentToNextKey = mt.GotoNextKey(false);
				PrintToServer("Couldn't find entity %s in AddOutputs. Skipping...", entTargetNameBuffer);
				continue;
			}
			PrintToServer("add %s", entTargetNameBuffer);
			if (mt.GotoFirstSubKey(false))
			{
				bool browsedNextKey = true;
				while (browsedNextKey)
				{
					char outputKey[255]; // the key we will be adding
					char outputValue[255]; // the value we will be adding
					mt.GetSectionName(outputKey, 255);
					mt.GetString(NULL_STRING, outputValue, sizeof(outputValue));
					entLump.Append(outputKey, outputValue);
					browsedNextKey = mt.GotoNextKey(false);
				}
				mt.GoBack();
			}
			entitiesChangedOrDeleted++;
			delete entLump; //we are done with it. carry on.
			wentToNextKey = mt.GotoNextKey(false);
		}
	}
	mt.Rewind();
	mt.JumpToKey(mapName);
	if (mt.JumpToKey("CreateSpawns"))
	{
		bool wentToNextKey = mt.GotoFirstSubKey(false);
		while (wentToNextKey)
		{
			char entTargetNameBuffer[255];
			mt.GetSectionName(entTargetNameBuffer, 255);
			EntityLumpEntry entLump = SearchForEntityInLump(entTargetNameBuffer, 255);
			if (entLump == null)
			{
				wentToNextKey = mt.GotoNextKey(false);
				PrintToServer("Couldn't find entity %s in CreateSpawns. Skipping...", entTargetNameBuffer);
				continue;
			}
			PrintToServer("creates %s", entTargetNameBuffer);
			// is this correct?
			char originText[33];
			mt.GetString("origin", originText, sizeof(originText));
			char anglesText[33];
			mt.GetString("angles", anglesText, sizeof(anglesText));
			char targetOutput[33];
			mt.GetString("output", targetOutput, sizeof(targetOutput));
			char textBuffer[255];
			Format(textBuffer, sizeof(textBuffer), "portal_player_spawnpoint,AddOutput,origin %s,0,1", originText);
			entLump.Append(targetOutput, textBuffer);
			Format(textBuffer, sizeof(textBuffer), "portal_player_spawnpoint,AddOutput,angles %s,0,1", anglesText);
			entLump.Append(targetOutput, textBuffer);
			entitiesChangedOrDeleted++;
			delete entLump; //we are done with it. carry on.
			wentToNextKey = mt.GotoNextKey(false);
		}
	}
	mt.Rewind();
	mt.JumpToKey(mapName);
	delete mt;
	PrintToServer("Performed %i manual changes!", entitiesChangedOrDeleted);
}

// implemented for manual changes to avoid the code getting stupidly messy.
EntityLumpEntry SearchForEntityInLump(const char[] targetNameOrHammerId, int maxLength)
{
	int entLumpLength = EntityLump.Length();
	char[] toSearchFor = new char[maxLength];
	bool searchingForId = (targetNameOrHammerId[0] == '~');
	char searchKey[12]; // the key to search for.
	if (searchingForId)
	{
		// according to some weird thing i found on the wiki... this should cut off the first string
		strcopy(toSearchFor, maxLength, targetNameOrHammerId[1]);
		searchKey = "hammerid";
	}
	else
	{
		searchKey = "targetname";
		strcopy(toSearchFor, maxLength, targetNameOrHammerId);
	}
	for (int i = 0; i < entLumpLength; i++)
	{
		EntityLumpEntry entry = EntityLump.Get(i);
		char targetBuffer[128];
		int targetIndex = entry.GetNextKey(searchKey, targetBuffer, 128);
		if (targetIndex != -1)
		{
			if (strcmp(targetBuffer, toSearchFor) == 0)
			{
				return entry;
			}
		}
		delete entry;
	}
	return null;
}