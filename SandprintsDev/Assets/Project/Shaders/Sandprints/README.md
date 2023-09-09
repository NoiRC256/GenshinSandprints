## How to determine indent depth

Parameters
- `extraHeight`: Additional height in meters, terrain surface will be raised by this height.
- `indentDepthLimit`: Depth limit for indents, the unit is number of meters below the terrain surface. Takes `extraHeight` into consideration.

Need to know
- `indentPixel`: Pixel color value that represents how deep below center point, sampled from `SandprintsIndentMap`, higher value is deeper.
- `proposedIndentDepth = indentPixel * _indentPixelValue_ToMeter`: Proposed indent depth in worldpsace meters.
- `worldPos.y`: Original terrain height at the world position corresponding to the indent map pixel
- `terrainPoint.y = worldPos.y + normalCoef * saturate(extraHeight)`: Original terrain height plus `extraHeight`.

Calculating actual indent depth
- `indentDepth = terrainPoint.y - proposedIndentDepth`: Actual indent depth in number of meters below terrain at the world poisiton corresponding to the indent map pixel.
- `min(indentDepth, indentDepthLimit)`: Limit the actual indent depth by the `indentDepthLimit` material parameter.

## Setup

`ObjectCam` distance from center point is 5, view distance is 10. So object exactly on the ground will be 5 meters away, with r value of 0.5.
