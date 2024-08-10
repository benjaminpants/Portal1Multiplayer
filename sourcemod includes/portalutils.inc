#if defined _portalutils_included_
  #endinput
#endif
#define _portalutils_included_

// Get the portal gun that belongs to the specific client
stock int GetClientPortalGun(int client)
{
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "weapon_portalgun")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			if (GetOwnerOfWeapon(ent) == client)
			{
				return ent;
			}
		}
	}
	return -1;
}

stock int GetOwnerOfWeapon(int weapon)
{
	return GetEntPropEnt(weapon, Prop_Data, "m_hOwner");
}

// gets the extents of the specified portal.
stock bool GetPortalExtents(int portalEnt, float min[3], float max[3])
{
	if (IsValidEntity(portalEnt)) 
	{
		// if both portals are valid, exit the loop.
		float origin[3];
		GetEntPropVector(portalEnt, Prop_Send, "m_vecMins", min);
		GetEntPropVector(portalEnt, Prop_Send, "m_vecMaxs", max);
		GetEntPropVector(portalEnt, Prop_Send, "m_vecOrigin", origin);
		AddVectors(min,origin,min);
		AddVectors(max,origin,max);
		return true;
	}
	return false;
}

// find the first and second IDs of the portals corresponding to the linkageID.
// results are stored in portalIndexes
stock void FindAllPortalsOfLinkageID(int linkage, int[] portalIndexes, bool createIfNoneFound = false)
{
	int firstPortalEnt = -1;
	int secondPortalEnt = -1;
	
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "prop_portal")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			// if both portals are valid, exit the loop.
			if (IsValidEntity(firstPortalEnt) && IsValidEntity(secondPortalEnt))
			{
				break;
			}
			int entLinkage = GetEntProp(ent, Prop_Data, "m_iLinkageGroupID");
			if (entLinkage != linkage)
			{
				continue;
			}
			bool isSecond = (GetEntProp(ent, Prop_Data, "m_bIsPortal2") == 1);
			if (isSecond)
			{
				secondPortalEnt = ent;
			}
			else
			{
				firstPortalEnt = ent;
			}
		}
	}
	
	if (createIfNoneFound)
	{
		if (firstPortalEnt == -1)
		{
			int entityId = CreateEntityByName("prop_portal");
			SetEntProp(entityId, Prop_Data, "m_iLinkageGroupID", linkage);
			SetEntProp(entityId, Prop_Data, "m_bIsPortal2", false);
			DispatchSpawn(entityId);
		}
		if (secondPortalEnt == -1)
		{
			int entityId = CreateEntityByName("prop_portal");
			SetEntProp(entityId, Prop_Data, "m_iLinkageGroupID", linkage);
			SetEntProp(entityId, Prop_Data, "m_bIsPortal2", true);
			DispatchSpawn(entityId);
		}
	}

	portalIndexes[0] = firstPortalEnt;
	portalIndexes[1] = secondPortalEnt;
}

// count all the owned portal guns that fire a specific linkageID, use -1 to count all owned portal guns
stock int CountOwnedPortalGunsOfLink(int linkage)
{
	int count = 0;
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "weapon_portalgun")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			// if we aren't counting all owned guns and the linkageID of this gun does not match the target, skip.
			if ((linkage != -1) && (GetEntProp(ent, Prop_Data, "m_iPortalLinkageGroupID") != linkage))
			{
				continue;
			}
			int entOwner = GetEntPropEnt(ent, Prop_Data, "m_hOwner");
			if (entOwner != -1)
			{
				count++;
			}
		}
	}
	return count;
}

// fizzles the specified portal safely
stock void FizzlePortal(int portalId)
{
	if (!IsValidEntity(portalId)) return;
	if (GetEntProp(portalId, Prop_Data, "m_bActivated") == 0) return;
	AcceptEntityInput(portalId, "Fizzle");
}

stock void GetPortalsBelongingToClient(int client, int[] entIds)
{
	entIds[0] = -1;
	entIds[1] = -1;
	int portalGun = GetClientPortalGun(client);
	if (!IsValidEntity(portalGun))
	{
		return;
	}
	int linkId = GetEntProp(portalGun, Prop_Data, "m_iPortalLinkageGroupID");
	
	FindAllPortalsOfLinkageID(linkId, entIds);

	if (!(IsValidEntity(entIds[0]) && (GetEntProp(portalGun, Prop_Send, "m_bCanFirePortal1") == 1)))
	{
		entIds[0] = -1;
	}
	if (!(IsValidEntity(entIds[1]) && (GetEntProp(portalGun, Prop_Send, "m_bCanFirePortal2") == 1)))
	{
		entIds[1] = -1;
	}
}

// find the two portals that belong to the specified client's linkage id and if everyone who belongs to said linkageID is dead, fizzle the portals
stock void FizzlePortalsBelongingToClient(int client, bool[] fizzled)
{
	int portalGun = GetClientPortalGun(client);
	if (!IsValidEntity(portalGun))
	{
		return;
	}
	int linkId = GetEntProp(portalGun, Prop_Data, "m_iPortalLinkageGroupID");
	int count = CountOwnedPortalGunsOfLink(linkId);
	// when this function is called the player is likely not FULLY processed as dead by the game, so we check for 1 owned gun instead of zero
	if (count > 1)
	{
		return;
	}
	
	int linkage[2];
	FindAllPortalsOfLinkageID(linkId, linkage);
	
	fizzled[0] = false;
	fizzled[1] = false;
	
	if (IsValidEntity(linkage[0]) && (GetEntProp(portalGun, Prop_Send, "m_bCanFirePortal1") == 1))
	{
		FizzlePortal(linkage[0]);
		fizzled[0] = true;
	}
	if (IsValidEntity(linkage[1]) && (GetEntProp(portalGun, Prop_Send, "m_bCanFirePortal2") == 1))
	{
		FizzlePortal(linkage[1]);
		fizzled[1] = true;
	}
}