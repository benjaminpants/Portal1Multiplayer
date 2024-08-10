#include <sdktools>
#include <sourcemod>
#include <entitylump>
#include <portalutils>

public Plugin myinfo =
{
	name = "Portal 1 Player Fixes",
	author = "MTM101",
	description = "Fixes a variety of issues with the P1 Player in multiplayer and provides options for changing behavior.",
	version = "1.0",
	url = "https://github.com/benjaminpants/Portal1MultiplayerFixes"
};

// TODO: delete portal_ragdoll when created so we dont shit ourselves when the player commits suicide.


// due to the automatic setting being removed/not working, unsure if having these all as globals is still a good idea.
bool g_giveGun = true;
bool g_canFirePortal1 = true;
bool g_canFirePortal2 = true;
int g_portalGunLinkCount = 256;

ConVar gcv_portalGunType; // sv_portalgun_type
ConVar gcv_portalGunLinkageMethod; // sv_portalgun_maxlinks
ConVar gcv_enableSuit; // sv_suitenabled
ConVar gcv_portalFizzleOnDeath; // sv_portals_fizzle_on_death

// settings relating to automatic portal gunning
ConVar gcv_portalGunAutomatic; // sv_portalgun_auto
ConVar gcv_portalGunAutomaticAnnounce;// sv_announceportalgunpickup

public void OnPluginStart()
{
	RegServerCmd("refresh_player_portalguns", Command_RefreshPlayerPortalGuns, "Resets the portal guns of all players to match the current settings.");
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	gcv_portalGunType = CreateConVar("sv_portalgun_type", "3", 
	"The type of Portal gun to give to players upon spawning.\n0=No Gun\n1=Portal Gun(Blue Only)\n2=Portal Gun(Orange Only)\n3=Portal Gun(Both)\n4=Portal Gun(No Portal)", FCVAR_NOTIFY);
	gcv_portalGunType.AddChangeHook(OnPortalGunTypeChange);
	gcv_portalGunLinkageMethod = CreateConVar("sv_portalgun_maxlinks", "0", "The amount of possible portal sets that can exist, 0 meaning infinite. Values greater than zero will cause linkage ids to repeat after the specified number is reached. Use 1 to make all players have the same set of portals.",FCVAR_NOTIFY);
	gcv_portalGunLinkageMethod.AddChangeHook(OnPortalGunLinkageChange);
	gcv_enableSuit = CreateConVar("sv_suitenabled", "0", "Determines if players will get the HEV suit on spawn.", FCVAR_NOTIFY);
	gcv_portalFizzleOnDeath = CreateConVar("sv_portals_fizzle_on_death", "1", "Determines if portal sets will be fizzled when their owners die.", FCVAR_NOTIFY);
	
	// settings relating to automatic mode
	gcv_portalGunAutomatic = CreateConVar("sv_portalgun_auto", "1", "If 1, sv_portalgun_type will be ignored and the game will automatically determine the appropiate gun type.\n(If its determined to be a mono-portal chamber, sv_portalgun_maxlinks will also be ignored.)\n(Changes only apply on map reload.)");
	gcv_portalGunAutomatic.AddChangeHook(OnPortalGunAutoChange);
	
	gcv_portalGunAutomaticAnnounce = CreateConVar("sv_announceportalgunpickup", "1", "If sv_portalgun_auto is on, this makes it so that the person who picked up the ASHPD gets announced in chat..");
	HookEntityOutput("weapon_portalgun", "OnPlayerPickup", OnPortalGunPickup);
	HookEntityOutput("trigger_portal_cleanser", "OnFizzle", OnCleanserFizzle);
}

void OnCleanserFizzle(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidEntity(activator))
	{
		return;
	}

	int entities[2];
	GetPortalsBelongingToClient(activator, entities);
	if (IsValidEntity(entities[0]))
	{
		SetVariantBool(false);
		AcceptEntityInput(entities[0], "SetActivatedState");
	}
	if (IsValidEntity(entities[1]))
	{
		SetVariantBool(false);
		AcceptEntityInput(entities[1], "SetActivatedState");
	}
}

void OnPortalGunPickup(const char[] output, int caller, int activator, float delay)
{
	if (!gcv_portalGunAutomatic.BoolValue)
	{
		return;
	}
	if (!IsValidEntity(activator))
	{
		return;
	}
	if (!IsValidEntity(caller))
	{
		return;
	}
	// we only care about portal guns that have a target name. not ones spawned by us.
	// OR check the hammer ID if its blank as the player might be getting a gun upgrade
	char targetN[64];
	GetEntPropString(caller, Prop_Data, "m_iName", targetN, 64);
	if (strcmp(targetN, "") == 0)
	{
		int entHammerId = GetEntProp(caller, Prop_Data, "m_iHammerID");
		if (entHammerId <= 0)
		{
			return;
		}
	}
	if (IsValidEntity(activator))
	{
		g_giveGun = true;
		bool gunHasPrimary = (GetEntProp(caller, Prop_Send, "m_bCanFirePortal1") == 1);
		bool gunHasSecondary = (GetEntProp(caller, Prop_Send, "m_bCanFirePortal2") == 1);
		g_canFirePortal1 = g_canFirePortal1 || gunHasPrimary;
		g_canFirePortal2 = g_canFirePortal2 || gunHasSecondary;
		if (g_canFirePortal1 && g_canFirePortal2)
		{
			char dummyA[1];
			OnPortalGunLinkageChange(gcv_portalGunLinkageMethod,dummyA,dummyA);
		}
		else
		{
			g_portalGunLinkCount = 1;
		}
		// we kill the gun we just picked up because picked up guns dont pick up correctly in p1 multiplayer and cause buggy physics.
		AcceptEntityInput(caller, "Kill");
		char unlockedColorText[16];
		if (gunHasPrimary)
		{
			if (gunHasSecondary)
			{
				unlockedColorText = "Blue and orange";
			}
			else
			{
				unlockedColorText = "Blue";
			}
		}
		else
		{
			if (gunHasSecondary)
			{
				unlockedColorText = "Orange";
			}
			else
			{
				unlockedColorText = "No new";
			}
		}
		CreateTimer(0.2, RefreshPlayerGunsTimer);
		if (!gcv_portalGunAutomaticAnnounce.BoolValue)
		{
			return;
		}
		char playerName[33];
		GetClientName(activator, playerName, 33)
		PrintToChatAll("%s has acquired the ASHPD!", playerName);
		PrintToChatAll("(%s portals unlocked!)", unlockedColorText);
	}
}

Action RefreshPlayerGunsTimer(Handle timer)
{
	RefreshAllPlayerGuns();
}

Action Command_RefreshPlayerPortalGuns(int args)
{
	RefreshAllPlayerGuns();
	return Plugin_Handled;
}

void OnPortalGunTypeChange(ConVar convar, char[] oldValue, char[] newValue)
{
	if (convar.IntValue == 0)
	{
		g_giveGun = false;
		return;
	}
	g_giveGun = true;
	g_canFirePortal1 = ((convar.IntValue & 1) != 0);
	g_canFirePortal2 = ((convar.IntValue & 2) != 0);
}

void OnPortalGunAutoChange(ConVar convar, char[] oldValue, char[] newValue)
{
	if (!convar.BoolValue)
	{
		char dummyArray[1];
		OnPortalGunTypeChange(gcv_portalGunType, dummyArray, dummyArray);
		OnPortalGunLinkageChange(gcv_portalGunLinkageMethod, dummyArray, dummyArray);
		RefreshAllPlayerGuns();
	}
	else
	{
		PrintToServer("Please reload the map for changes to take effect.");
	}
}

void OnPortalGunLinkageChange(ConVar convar, char[] oldValue, char[] newValue)
{
	g_portalGunLinkCount = convar.IntValue;
	if (g_portalGunLinkCount == 0)
	{
		g_portalGunLinkCount = 256;
	}
}

// clears all bad guns and gives the player the appropiate gun
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!gcv_enableSuit.BoolValue)
	{
		SetEntProp(client, Prop_Data, "m_bWearingSuit", false);
	}
	SetVariantFloat(99999999999999.0);
	AcceptEntityInput(client, "IgnoreFallDamageWithoutReset");
	ClearAllBadPortalGuns();
	
	if (g_giveGun)
	{
		GivePlayerPortalGun(client);
	}
}

// clears all bad guns and fizzle portals, this event triggers before the player dies so we can do something incredibly stupid to prevent other players portals from disappearing
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	
	// we need to redudantly call FindAllPortalsOfLinkageID so we can get ent ids to ignore during our patch
	int linkage[2];
	FindAllPortalsOfLinkageID(CalculateLinkageIDForPlayer(client), linkage);
	
	// attempt to fizzle the portals belonging to this client and store the result
	bool fizzledPortals[2] = {false, false};
	if (gcv_portalFizzleOnDeath.BoolValue)
	{
		FizzlePortalsBelongingToClient(client, fizzledPortals);
	}
	
	
	// create a list of activated portals, de-activate them, then after 0.1 seconds re-activate them.
	// we do this so that the loop that fizzles players portals is essentially "skipped."
	DataPack pack = new DataPack();
	
	int ent = -1;
	int count = 0;
	pack.WriteCell(512); // write a placeholder value, we will be returning to this.
	while((ent = FindEntityByClassname(ent, "prop_portal")) != -1)
	{
		//skip by the persons portals we are actually trying to fizzle, unless we haven't fizzled any portals, than go right ahead
		if ((ent == linkage[0]) && (fizzledPortals[0]))
		{
			continue;
		}
		if ((ent == linkage[1]) && (fizzledPortals[1]))
		{
			continue;
		}
		// if it is enabled, disable it
		if ((GetEntProp(ent, Prop_Data, "m_bActivated") == 1))
		{
			SetEntProp(ent, Prop_Data, "m_bActivated", 0);
			pack.WriteCell(ent); // write the entity
			count++;
		}
	}

	//rewrite the count we wrote earlier
	pack.Reset(false);
	pack.WriteCell(count);
	CreateTimer(0.1, EnableAllPackedPortals, pack);
}

// enables all the portal entites in the pack
Action EnableAllPackedPortals(Handle timer, DataPack pack)
{
	pack.Reset(false); // reset for reading
	int count = pack.ReadCell();
	while (count > 0)
	{
		count--;
		int entIndex = pack.ReadCell();
		if (IsValidEntity(entIndex))
		{
			SetEntProp(entIndex, Prop_Data, "m_bActivated", 1);
		}
	}
	ClearAllBadPortalGuns();
	CloseHandle(pack);
}

// clears all bad guns and fizzle portals if no one else has them
public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// fizzle the portals belonging to this client
	bool fizzled[2];
	FizzlePortalsBelongingToClient(client, fizzled);
	
	ClearAllBadPortalGuns();
}

// refresh all player guns to account for the current settings/auto settings
void RefreshAllPlayerGuns()
{
	for (int i = 0; i < MaxClients; i++)
	{
		int client = (i + 1);
		if (IsValidEntity(client))
		{
			// weapon related functions crash(due to missing offsets) so this is the best we can do.
			int portalGun = GetClientPortalGun(client);
			bool clientHasGun = false;
			bool clientCanFirePrimary = false;
			bool clientCanFireSecondary = false;
			clientHasGun = IsValidEntity(portalGun);
			// dont bother trying to fizzle owned portals if this player doesn't have a portal gun
			if (clientHasGun)
			{
				clientCanFirePrimary = (GetEntProp(portalGun, Prop_Send, "m_bCanFirePortal1") == 1);
				clientCanFireSecondary = (GetEntProp(portalGun, Prop_Send, "m_bCanFirePortal2") == 1);
				int ownedPortals[2];
				FindAllPortalsOfLinkageID(CalculateLinkageIDForPlayer(client), ownedPortals);
				// dont fizzle orange/blue auto portals in the case this update is because someone picked up a new ASHPD with the auto setting on.
				if (clientCanFirePrimary && IsValidEntity(ownedPortals[0]))
				{
					FizzlePortal(ownedPortals[0]);
				}
				if (clientCanFireSecondary && IsValidEntity(ownedPortals[1]))
				{
					FizzlePortal(ownedPortals[1]);
				}
				// if the setting dictates we are giving a gun, then update the gun.
				// otherwise, destroy the gun the player is holding.
				if (g_giveGun)
				{
					SetEntProp(portalGun, Prop_Data, "m_iPortalLinkageGroupID", CalculateLinkageIDForPlayer(client));
					if (g_canFirePortal1)
					{
						DispatchKeyValue(portalGun, "CanFirePortal1", "1");
					}
					else
					{
						DispatchKeyValue(portalGun, "CanFirePortal1", "0");
					}
					if (g_canFirePortal2)
					{
						DispatchKeyValue(portalGun, "CanFirePortal2", "1");
					}
					else
					{
						DispatchKeyValue(portalGun, "CanFirePortal2", "0");
					}
				}
				else
				{
					AcceptEntityInput(portalGun, "Kill");
				}
			}
			else
			{
				if (g_giveGun)
				{
					GivePlayerPortalGun(client);
				}
			}
		}
	}
}

// Calculates the linkage ID for the specified client.
int CalculateLinkageIDForPlayer(int client)
{
	return (client - 1) % g_portalGunLinkCount;
}

// change the linkage and fireportal for the specified gun and client
Action ChangePortalGunLinkageAndFirePortal(Handle timer, DataPack pack)
{
	pack.Reset(false); // reset for reading
	int client = pack.ReadCell();
	int entId = pack.ReadCell();
	if (!IsValidEntity(entId))
	{
		return;
	}
	SetEntProp(entId, Prop_Data, "m_iPortalLinkageGroupID", CalculateLinkageIDForPlayer(client));
	if (g_canFirePortal1)
	{
		DispatchKeyValue(entId, "CanFirePortal1", "1");
	}
	else
	{
		DispatchKeyValue(entId, "CanFirePortal1", "0");
	}
	if (g_canFirePortal2)
	{
		DispatchKeyValue(entId, "CanFirePortal2", "1");
	}
	else
	{
		DispatchKeyValue(entId, "CanFirePortal2", "0");
	}
	CloseHandle(pack);
}

void GivePlayerPortalGun(int client)
{
	int entityId = GivePlayerItem(client, "weapon_portalgun");
	if (IsValidEntity(entityId))
	{
		// we remove these fields from the portal gun so that there isn't an inbetween time for the player to fire a portal before their linkageID gets set
		// (yes, this is something that has genuinely happened during testing)
		DispatchKeyValue(entityId, "CanFirePortal1", "0");
		DispatchKeyValue(entityId, "CanFirePortal2", "0");
		
		DataPack pack = new DataPack();
		pack.WriteCell(client);
		pack.WriteCell(entityId);
		CreateTimer(0.1, ChangePortalGunLinkageAndFirePortal, pack);
		
	}
	else
	{
		PrintToServer("GivePlayerItem failed... %i", client);
	}
}

// Clears portal guns that don't have any owners, and if automatic mode is on we also preserve named guns so pedestals dont break.
void ClearAllBadPortalGuns()
{
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "weapon_portalgun")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			int entOwner = GetEntPropEnt(ent, Prop_Data, "m_hOwner");
			if (!IsValidEntity(entOwner))
			{
				if (!gcv_portalGunAutomatic.BoolValue)
				{
					AcceptEntityInput(ent, "Kill");
					continue;
				}
				char targetN[64];
				GetEntPropString(ent, Prop_Data, "m_iName", targetN, 64);
				if (strcmp(targetN, "") == 0)
				{
					AcceptEntityInput(ent, "Kill");
				}
			}
		}
	}
}


// Does all the entity lump manip for automatic gun mode.
// we search through point templates instead of assuming what the portal gun is named to account for custom maps that might do who knows what.
public void OnMapInit()
{
	if (!gcv_portalGunAutomatic.BoolValue) return;
	PrintToServer("Doing automatic gun changes!");
	
	EntityLumpEntry portalGunLump;
	
	// search for point_templates and their respective guns
	int entLumpLength = EntityLump.Length();
	for (int i = 0; i < entLumpLength; i++)
	{
		if (portalGunLump != null)
		{
			break;
		}
		EntityLumpEntry entry = EntityLump.Get(i);
		char classN[64];
		int classNameIndex = entry.GetNextKey("classname", classN, 64);
		if (classNameIndex != -1)
		{
			if (strcmp(classN, "point_template") != 0)
			{
				delete entry;
				continue;
			}
			// we have found a point_template
			// get and check if it has a template(it should but. best to check.)
			char templateN[64];
			int targetIndex = entry.GetNextKey("Template01", templateN, 64);
			if (targetIndex == -1)
			{
				delete entry;
				continue;
			}
			// search for and find the first entity with that targetname
			for (int j = 0; j < entLumpLength; j++)
			{
				EntityLumpEntry subEntry = EntityLump.Get(j);
				char targetN[64];
				int targetNameIndex = subEntry.GetNextKey("targetname", targetN, 64);
				if (targetNameIndex == -1)
				{
					delete subEntry;
					continue;
				}
				// does it match our target entity from the template?
				if (strcmp(targetN, templateN) != 0)
				{
					delete subEntry;
					continue;
				}
				char subClass[64];
				int subClassIndex = subEntry.GetNextKey("classname", subClass, 64);
				if (subClassIndex == -1)
				{
					delete subEntry;
					continue;
				}
				if (strcmp(subClass, "weapon_portalgun") != 0)
				{
					delete subEntry;
					continue;
				}
				// change the original point_template target name so that IO breaks and it doesnt spawn and cause the player to get stuck
				int rootTargetNameIndex = entry.FindKey("targetname");
				entry.Update(rootTargetNameIndex, NULL_STRING, "vanillaportalguntemplate");
				portalGunLump = EntityLump.Get(j);
				delete subEntry;
				break; // break out of this loop
			}
		}
		delete entry;
	}

	// TODO: add backup search if the portal gun lump is null to scan for portal guns near info_player_starts.
	// so that maps like portal_playground_v4 dont need to have automatic portal guns turned off to behave properly
	
	if (portalGunLump != null)
	{
		g_giveGun = true;
		// should only need enough for a 1 or a 0 + NULL terminator
		char fireP1[2] = "0";
		char fireP2[2] = "0";
		portalGunLump.GetNextKey("CanFirePortal1", fireP1, 2);
		portalGunLump.GetNextKey("CanFirePortal2", fireP2, 2);
		g_canFirePortal1 = (strcmp(fireP1, "1") == 0);
		g_canFirePortal2 = (strcmp(fireP2, "1") == 0);
		if (g_canFirePortal1 && g_canFirePortal2)
		{
			char dummyA[1];
			OnPortalGunLinkageChange(gcv_portalGunLinkageMethod,dummyA,dummyA);
		}
		else
		{
			g_portalGunLinkCount = 1;
		}
		delete portalGunLump;
	}
	else
	{
		g_giveGun = false;
		g_canFirePortal1 = false;
		g_canFirePortal2 = false;
	}
	PrintToServer("Done!");
}