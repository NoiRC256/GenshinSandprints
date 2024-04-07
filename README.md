## Overview
This is an early attempt at recreating Genshin Impact’s interactive sand deformation. Genshin Impact’s implementation appears to use a depth capture + dynamic tessellation approach that creates 3D trails from any mesh that intersects with the desert terrain. My implementation builds on top of Batman: Arkham Origins's depth capture approach, adding support for complex terrains, indent rims, etc.

Blog post: https://noirccc.net/blog/posts/484

Note: This is just a proof of concept and won't be production ready any time soon

## Features
- :heavy_check_mark: Distance-based dynamic tessellation.
- :heavy_check_mark: Ground deforms by vertex displacement when in contact with meshes.
- :heavy_check_mark: Trail shape closely follows the contour of any interacting mesh.
- :heavy_check_mark: Have a ring of raised sand around an indent, simulating how sand is pushed away from the point of contact.
- :heavy_check_mark: Trails slowly regenerate over time.
- :heavy_check_mark: Does not intervene with the existing entity development workflow. e.g. for Genshin Impact, it has to be compatible with all existing characters as well as any new characters in the future, plus any mob/weapon/other meshes. Ideally developers don’t have to do per-object setups.
- :x: Automatic RT and camera setup.
- :x: Unrestricted area of effect (i.e. compatible with open world scenes. Trails can be created anywhere on the map where the ground material uses the corresponding shader).
- :x: Sand shader aesthetics: sparkles, smooth self shadows, etc.
- :x: Optimization: distance + region-based tessellation. Only tessellate where there will be indents and within a certain distance from camera.
- :x: Terrain system integration.

## Environment
- Unity 2022.3.20f1
- URP 14.0.10