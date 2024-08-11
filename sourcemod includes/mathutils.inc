#if defined _mathutils_included_
  #endinput
#endif
#define _mathutils_included_

stock float FloatClamp(float val, float minVal, float maxVal)
{
    if ( maxVal < minVal )
        return maxVal;
    else if( val < minVal )
        return minVal;
    else if( val > maxVal )
        return maxVal;
    else
        return val;
}

stock bool IsPointInBox(float pt[3], float boxMin[3], float boxMax[3])
{
	if ( (pt[0] > boxMax[0]) || (pt[0] < boxMin[0]) )
		return false;
	if ( (pt[1] > boxMax[1]) || (pt[1] < boxMin[1]) )
		return false;
	if ( (pt[2] > boxMax[2]) || (pt[2] < boxMin[2]) )
		return false;
	return true;
}

// 1:1 port of MatrixMultiply3x3 from vmatrix.h
stock void MatrixMultiply3x3(float m[4][4], float vVec[3], float outputVec[3])
{
	outputVec[0] = m[0][0]*vVec[0] + m[0][1]*vVec[1] + m[0][2]*vVec[2];
	outputVec[1] = m[1][0]*vVec[0] + m[1][1]*vVec[1] + m[1][2]*vVec[2];
	outputVec[2] = m[2][0]*vVec[0] + m[2][1]*vVec[1] + m[2][2]*vVec[2];
}

// TODO: Give this a better name
stock void MatrixPointMultiply3x3(float m[4][4], float vVec[3], float outputVec[3])
{
	outputVec[0] = m[0][0]*vVec[0] + m[0][1]*vVec[1] + m[0][2]*vVec[2] + m[0][3];
	outputVec[1] = m[1][0]*vVec[0] + m[1][1]*vVec[1] + m[1][2]*vVec[2] + m[1][3];
	outputVec[2] = m[2][0]*vVec[0] + m[2][1]*vVec[1] + m[2][2]*vVec[2] + m[2][3];
}

stock void GetEntityMatrixFromProp(int entity, char[] prop, float outMatrix[4][4])
{
	int matrixOffset = FindDataMapInfo(entity, prop);

	float flatMatrix[16];

	for (int i = 0; i < 16; i++)
	{
		flatMatrix[i] = GetEntDataFloat(entity, matrixOffset + (i * 4));
	}

	outMatrix[0][0] = flatMatrix[0];
	outMatrix[0][1] = flatMatrix[1];
	outMatrix[0][2] = flatMatrix[2];
	outMatrix[0][3] = flatMatrix[3];

	outMatrix[1][0] = flatMatrix[4];
	outMatrix[1][1] = flatMatrix[5];
	outMatrix[1][2] = flatMatrix[6];
	outMatrix[1][3] = flatMatrix[7];

	outMatrix[2][0] = flatMatrix[8];
	outMatrix[2][1] = flatMatrix[9];
	outMatrix[2][2] = flatMatrix[10];
	outMatrix[2][3] = flatMatrix[11];

	outMatrix[3][0] = flatMatrix[12];
	outMatrix[3][1] = flatMatrix[13];
	outMatrix[3][2] = flatMatrix[14];
	outMatrix[3][3] = flatMatrix[15];
}
