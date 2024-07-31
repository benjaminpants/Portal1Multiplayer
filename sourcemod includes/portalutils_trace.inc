#if defined _portalutils_trace_included_
  #endinput
#endif
#define _portalutils_trace_included_


#define PORTAL_HALF_WIDTH 32.0
#define PORTAL_HALF_HEIGHT 54.0
#define PORTAL_HALF_DEPTH 2.0

stock int GetPortalIndexOnRay(float startPosition[3], float endPosition[3])
{
	int ent = -1;
	while((ent = FindEntityByClassname(ent, "prop_portal")) != -1) 
	{
		if (IsValidEntity(ent)) 
		{
			float rayIntersection = IntersectRayWithPortal(startPosition, endPosition, ent);
			if (rayIntersection == -1.0) continue;
			break;
		}
	}
	return ent;
}


char portalPassthroughEntities[][] = 
{
	"prop_physics",
	"func_physbox",
	"npc_portal_turret_floor",
	"prop_energy_ball",
	"npc_security_camera",
	"player",
	"simple_physics_prop",
	"simple_physics_brush",
	"prop_ragdoll",
	"prop_glados_core",
	"updateitem2"
}

stock bool TracePortalFilter(int entity, int contentsMask)
{
	char className[33];
	GetEntityClassname(entity, className, 33);
	// todo: fix
	for (int i = 0; i < 10; i++)
	{
		if (strcmp(className,portalPassthroughEntities[i]) == 0)
		{
			return false;
		}
	}
	return true;
}

stock int TR_GetPortalIndex(Handle hndl = INVALID_HANDLE)
{
	float rayStart[3];
	float rayEnd[3];
	TR_GetStartPosition(hndl, rayStart);
	TR_GetEndPosition(rayEnd, hndl);

	return GetPortalIndexOnRay(rayStart, rayEnd);
}

stock float IntersectRayWithPortal(float startPosition[3], float endPosition[3], int portalEnt)
{
	if ((!IsValidEntity(portalEnt)) || (GetEntProp(portalEnt, Prop_Data, "m_bActivated") != 1))
	{
		return -1.0;
	}
	float delta[3];
	SubtractVectors(endPosition,startPosition,delta);

	float portalAngles[3];
	GetEntPropVector(portalEnt, Prop_Data, "m_angAbsRotation", portalAngles);

	float portalPosition[3];
	GetEntPropVector(portalEnt, Prop_Data, "m_vecAbsOrigin", portalPosition);

	float portalForward[3];
	float portalRight[3];
	float portalUp[3];
	GetAngleVectors(portalAngles, portalForward, portalRight, portalUp);
	
	// Discount rays not coming from the front of the portal
	float fDot = GetVectorDotProduct(portalForward, delta);
	if (fDot > 0.0)
	{
		return -1.0;
	}

	float pvTri1[3][3];
	float pvTri2[3][3];

	CalculatePortalTriangles(portalPosition, portalRight, portalUp, pvTri1, pvTri2);

	// test triangle 1
	float fT = IntersectRayWithTriangles(startPosition, delta, pvTri1[0], pvTri1[1], pvTri1[2], false);

	if ( fT >= 0.0 )
		return fT;
	
	return IntersectRayWithTriangles(startPosition, delta, pvTri2[0], pvTri2[1], pvTri2[2], false);
}

stock float IntersectRayWithTriangles(float startPosition[3], float delta[3], float v1[3], float v2[3], float v3[3], bool oneSided)
{
	float edge1[3];
	float edge2[3];
	float org[3];

	SubtractVectors(v2, v1, edge1);
	SubtractVectors(v3, v1, edge2);

	float dirCrossEdge2[3];
	float orgCrossEdge1[3];
	GetVectorCrossProduct(delta, edge2, dirCrossEdge2);

	float denom = GetVectorDotProduct(dirCrossEdge2, edge1);
	if (FloatAbs(denom) < 0.000001)
	{
		return -1.0;
	}
	denom = 1.0 / denom;
	SubtractVectors(startPosition, v1, org);

	float u = GetVectorDotProduct(dirCrossEdge2, org) * denom;
	if ((u < 0.0) || (u > 1.0))
	{
		return -1.0;
	}

	GetVectorCrossProduct(org, edge1, orgCrossEdge1);
	float v = GetVectorDotProduct(orgCrossEdge1, delta) * denom;
	if ((v < 0.0) || (v + u > 1.0))
	{
		return -1.0;
	}

	float boxt = 0.001;

	float t = GetVectorDotProduct(orgCrossEdge1, edge2) * denom;
	if ((t < -boxt) || (t > 1.0 + boxt))
	{
		return -1.0;
	}

	return FloatClamp( t, 0.0, 1.0 );
}



stock void CalculatePortalTriangles(float portalCenter[3], float portalRight[3], float portalUp[3], float tri1[3][3], float tri2[3][3])
{
	float topEdge[3];
	
	topEdge[0] = portalUp[0];
	topEdge[1] = portalUp[1];
	topEdge[2] = portalUp[2];
	ScaleVector(topEdge, PORTAL_HALF_HEIGHT);
	
	float bottomEdge[3];
	bottomEdge[0] = topEdge[0];
	bottomEdge[1] = topEdge[1];
	bottomEdge[2] = topEdge[2];
	ScaleVector(bottomEdge, -1.0);

	float rightEdge[3];

	rightEdge[0] = portalRight[0];
	rightEdge[1] = portalRight[1];
	rightEdge[2] = portalRight[2];
	ScaleVector(rightEdge, PORTAL_HALF_WIDTH);

	float leftEdge[3];
	leftEdge[0] = rightEdge[0];
	leftEdge[1] = rightEdge[1];
	leftEdge[2] = rightEdge[2];
	ScaleVector(leftEdge, -1.0);

	float topLeft[3];
	float topRight[3];
	float bottomLeft[3];
	float bottomRight[3];

	// we need to add 3 so do this in two seperate phases
	AddVectors(leftEdge,topEdge,topLeft);
	AddVectors(rightEdge,topEdge,topRight);
	AddVectors(leftEdge,bottomEdge,bottomLeft);
	AddVectors(rightEdge,bottomEdge,bottomRight);

	AddVectors(topLeft,portalCenter,topLeft);
	AddVectors(topRight,portalCenter,topRight);
	AddVectors(bottomLeft,portalCenter,bottomLeft);
	AddVectors(bottomRight,portalCenter,bottomRight);

	// Make triangles
	tri1[0] = topRight;
	tri1[1] = topLeft;
	tri1[2] = bottomLeft;

	tri2[0] = topRight;
	tri2[1] = bottomLeft;
	tri2[2] = bottomRight;
}