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

int g_triggerIds[8]; //stores the ids of the triggers
char g_triggerNames[8][33]; //stores the names of each trigger
bool g_triggersActivated[8]; //stores whether or not each trigger has been activated
bool g_playersInTrigger[MAXPLAYERS];
int g_triggerTimes[8]; // stores the time of each trigger
int g_triggerTotal = 0; //how many total triggers are in this map

int g_currentTriggerIndex = -1;
int g_currentTriggerEnt = -1;
int g_currentTriggerCount = 0;
int g_previousTriggerCount = 0;
ConVar gcv_campaignCompleteConCommand;
Handle g_currentTriggerTimer = INVALID_HANDLE;

#define DEBUG_VERBOUS true
#define MAPFIX_DISABLED_SPAWNFLAG 16384

public void OnPluginStart()
{
	HookEntityOutput("game_zone_player", "OnPlayerInZone", OnPlayerInZone);
	RegConsoleCmd("spawn", Command_GoToSpawn);
	gcv_campaignCompleteConCommand = CreateConVar("sv_campaigncompletecommand", "changelevel testchmb_a_00", "The console command that gets ran when a campaign is 'completed'.");
	RegServerCmd("callcampaigncommand", Command_CallCampaignCommand, "Calls the command specified in sv_campaigncompletecommand.", 0);
}

Action Command_CallCampaignCommand(int args)
{
	char command[512];
	gcv_campaignCompleteConCommand.GetString(command, 512);
	ServerCommand(command);
}

public Action Command_GoToSpawn(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "spawn command must be called from client!");
		return Plugin_Handled;
	}
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "info_player_start")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			char targetN[128];
			GetEntPropString(ent, Prop_Data, "m_iName", targetN, 128)
			if (strcmp(targetN, "portal_player_spawnpoint") == 0)
			{
				float spawnPos[3];
				float zeroVelocity[3] = {0, ...};
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", spawnPos);
				TeleportEntity(client, spawnPos, NULL_VECTOR, zeroVelocity);
				return Plugin_Handled;
			}
		}
	}
	ReplyToCommand(client, "This map doesn't have a valid mapfixes spawn!");
	return Plugin_Handled;
}

void OnPlayerInZone(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidEntity(activator))
	{
		return;
	}
	if (!IsValidEntity(caller))
	{
		return;
	}
	// todo: put alive checks
	g_playersInTrigger[activator - 1] = true;
	int entHammerId = GetEntProp(caller, Prop_Data, "m_iHammerID");
	for (int i = 0; i < g_triggerTotal; i++)
	{
		if (g_triggerIds[i] == entHammerId)
		{
			if (g_triggersActivated[i]) return; //dont do anything if this trigger has already been activated
			g_currentTriggerIndex = i;
			g_currentTriggerEnt = caller;
			break;
		}
	}
	g_currentTriggerCount++;
}

void ResetAllPlayerTriggers()
{
	g_currentTriggerEnt = -1;
	g_currentTriggerIndex = -1;
	g_currentTriggerCount = 0;
	g_previousTriggerCount = 0;
	if (g_currentTriggerTimer != INVALID_HANDLE)
	{
		KillTimer(g_currentTriggerTimer, false);
	}
	g_currentTriggerTimer = INVALID_HANDLE;
}


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
	g_triggerTotal = 0;
	g_triggersActivated[0] = false;
	g_triggersActivated[1] = false;
	g_triggersActivated[2] = false;
	g_triggersActivated[3] = false;
	g_triggersActivated[4] = false;
	g_triggersActivated[5] = false;
	g_triggersActivated[6] = false;
	g_triggersActivated[7] = false;
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

	bool deleteTransitions = false;
	// load the config early so we can check it
	KeyValues mt = LoadManualConfig();
	char mapName[65];
	GetCurrentMap(mapName,65);
	if (mt != null)
	{
		if (mt.JumpToKey(mapName))
		{
			deleteTransitions = (mt.GetNum("PreserveTransitions") != 1);
			mt.Rewind();
			if (!deleteTransitions)
			{
				PrintToServer("Manual config says to preserve trigger_transition!");
			}
		}
	}

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

		// detect change levels via path tracks, as that is when the game does auto detection.
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
								PrintToServer("Error! Couldn't find map key for level transition!");
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
		if (deleteTransitions && (strcmp(classN, "trigger_transition") == 0))
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
	if (mt == null) return;
	entitiesChangedOrDeleted = 0;
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
					bool foundValue = false;
					while ((keyIndex = entLump.GetNextKey(outputKey, outputValue, sizeof(outputValue), keyIndex)) != -1)
					{
						if (strcmp(outputValue, targetOutput) == 0)
						{
							#if DEBUG_VERBOUS
								PrintToServer("Found target: \"%s\" \"%s\"! (%s) Deleting...", outputKey, targetOutput, entTargetNameBuffer);
							#endif
							entLump.Erase(keyIndex); // we have found our target, deleting...
							foundValue = true;
							break;
						}
					}
					if (!foundValue)
					{
						PrintToServer("Couldn't remove \"%s\", \"%s\" in %s! (Not found)", outputKey, targetOutput, entTargetNameBuffer);
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
					#if DEBUG_VERBOUS
						PrintToServer("Added \"%s\" \"%s\" to %s!", outputKey, outputValue, entTargetNameBuffer);
					#endif
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
			#if DEBUG_VERBOUS
				PrintToServer("Added spawn (%s, %s) to %s on %s.",originText,anglesText,entTargetNameBuffer, targetOutput);
			#endif
			delete entLump; //we are done with it. carry on.
			wentToNextKey = mt.GotoNextKey(false);
		}
	}
	mt.Rewind();
	mt.JumpToKey(mapName);
	if (mt.JumpToKey("RequirePlayerTriggers"))
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
				PrintToServer("Couldn't find entity %s in RequirePlayerTriggers. Skipping...", entTargetNameBuffer);
				continue;
			}
			char classN[64];
			int classNameIndex = entLump.GetNextKey("classname", classN, 64);
			if (classNameIndex == -1)
			{
				delete entLump;
				PrintToServer("Target for RequirePlayerTriggers has no classname? Skipping...", entTargetNameBuffer);
				continue;
			}
			entLump.Update(classNameIndex, NULL_STRING, "game_zone_player");
			char zoneName[33];
			mt.GetString("Name", zoneName, sizeof(zoneName));
			int timeDelay = mt.GetNum("WaitTime");
			int teleportAll = mt.GetNum("TeleportAll");

			// create the logic_relay
			int lumpIndex = EntityLump.Append();
			EntityLumpEntry logicLump = EntityLump.Get(lumpIndex);
			logicLump.Append("classname", "logic_relay");
			char hammerIdBuffer[128];
			char outputBuffer[256];
			char relayNameBuffer[256]
			int hammerIdIndex = entLump.GetNextKey("hammerid", hammerIdBuffer, 128);
			if (hammerIdIndex == -1)
			{
				delete entLump;
				PrintToServer("Target for RequirePlayerTriggers has no hammerid? Skipping...", entTargetNameBuffer);
				continue;
			}
			Format(relayNameBuffer, 256, "relay_%s", hammerIdBuffer);
			// relayNameBuffer should contain something like "relay_hammerid" where hammerid is the hammerid
			// we add a target name to our logic_relay so that we can easily track it down later
			logicLump.Append("targetname", relayNameBuffer);
			int outputIndex = -1;
			while ((outputIndex = entLump.GetNextKey("OnStartTouch", outputBuffer, 256, outputIndex)) != -1)
			{
				logicLump.Append("OnTrigger", outputBuffer);
			}
			outputIndex = -1;
			while ((outputIndex = entLump.GetNextKey("OnTrigger", outputBuffer, 256, outputIndex)) != -1)
			{
				logicLump.Append("OnTrigger", outputBuffer);
			}
			outputIndex = -1;
			while ((outputIndex = entLump.GetNextKey("OnStartTouchAll", outputBuffer, 256, outputIndex)) != -1)
			{
				logicLump.Append("OnTrigger", outputBuffer);
			}

			g_triggerTimes[g_triggerTotal] = timeDelay;
			g_triggerIds[g_triggerTotal] = StringToInt(hammerIdBuffer);
			g_triggerNames[g_triggerTotal] = zoneName;
			g_triggerTotal++;
			entitiesChangedOrDeleted++;
			delete entLump; //we are done with it. carry on.
			wentToNextKey = mt.GotoNextKey(false);
		}
	}
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
		// according to some weird thing i found on the wiki... this should cut off the first character
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

public void OnMapStart()
{
	CreateTimer(0.1, CheckTrigger, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	PrecacheSound("buttons/button14.wav");
}

public void OnMapEnd()
{
	ResetAllPlayerTriggers();
}

Action TimerExpire(Handle timer, int hammerId)
{
	g_currentTriggerCount = 0;
	g_previousTriggerCount = 0;
	// todo: timer expire logic...
	//PrintToServer("Timer done! %i, %i, %i", g_currentTriggerEnt, hammerId, g_currentTriggerIndex);
	//AcceptEntityInput(g_currentTriggerEnt, "Kill"); //get rid of it so it cant fire again.
	g_triggersActivated[g_currentTriggerIndex] = true;
	char targetName[128];
	Format(targetName, 128, "relay_%i", hammerId);
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "logic_relay")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			char relayName[128];
			GetEntPropString(ent, Prop_Data, "m_iName", relayName, 128);
			if (strcmp(relayName, targetName) == 0)
			{
				AcceptEntityInput(ent, "Trigger");
				//PrintToServer("Found relay!");
				break;
			}
		}
	}
	EmitSoundToAll("buttons/button14.wav");
	ResetAllPlayerTriggers();
}

void ShowCount()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(i))
		{
			SetHudTextParams(-1.0,0.1,0.2,91,222,255,255,0,3.0,0.0,2.0);
			ShowHudText(i, 10, "%i/%i", g_currentTriggerCount, GetClientCount(false));
		}
	}
}

void ResetPlayersInTrigger()
{
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		g_playersInTrigger[i] = false;
	}
}

Action CheckTrigger(Handle timer)
{
	// we are checking here because it will take at least a tick for the outputs to fire(i think) so doing it next time we check is the most convient way of doing it
	// there were players last time we checked
	if ((g_currentTriggerIndex != -1) && (!g_triggersActivated[g_currentTriggerIndex]))
	{
		if (g_currentTriggerCount > 0)
		{
			if ((g_currentTriggerTimer == INVALID_HANDLE))
			{
				PrintToChatAll("A player has reached the %s! Proceeding in %i seconds...", g_triggerNames[g_currentTriggerIndex], g_triggerTimes[g_currentTriggerIndex]);
				g_currentTriggerTimer = CreateTimer(float(g_triggerTimes[g_currentTriggerIndex]), TimerExpire, g_triggerIds[g_currentTriggerIndex], 0);
			}
			else
			{
				ShowCount();
				if (g_currentTriggerCount == GetClientCount(false))
				{
					PrintToChatAll("All players have reached the %s! Proceeding...", g_triggerNames[g_currentTriggerIndex]);
					TriggerTimer(g_currentTriggerTimer, false);
				}
			}
		}
		else
		{
			if ((g_currentTriggerTimer != INVALID_HANDLE))
			{
				PrintToChatAll("All players have left the %s! Cancelling...", g_triggerNames[g_currentTriggerIndex]);
				ResetAllPlayerTriggers();
			}
		}
	}
	g_previousTriggerCount = g_currentTriggerCount;
	g_currentTriggerCount = 0;
	int ent = -1;
	ResetPlayersInTrigger();
	while((ent = FindEntityByClassname(ent, "game_zone_player")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			if (GetEntProp(ent, Prop_Data, "m_spawnflags") != MAPFIX_DISABLED_SPAWNFLAG)
			{
				AcceptEntityInput(ent, "CountPlayersInZone");
			}
		}
	}
}