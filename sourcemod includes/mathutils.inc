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