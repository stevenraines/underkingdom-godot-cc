# Feature - FOV system
**Goal**: Light and obstacles should limit what is rendered to the player

---

The player currently can see everything on the map, even if it is not in the line of sight or illuminated. Modify the system as follows:

Two things impact whether the player can see a tile: Line of Sight to the tile and illumination.

Game map (overworld and dungeon):
1. The player cannot see what is currently in any tile that is not illuminated by a light source
2. If the player has previously seen a tile that is now not visible because line of sight is blocked, the player should see whatever was there previously.
3. Any areas they player cannot see but previously visited should be rendered in a very dark gray (including items, features, etc)
4. Light sources, carried by the player, enemies, or on the map (campfire) illuminate an area. Each light source should have a range of how many tiles it illuminates.

Overworld:
1. During the day, the player can see anything in their line of sight as the sun illuminates everything.
2. As it gets darker, the illuminated distance shrinks. At night, they player can only see their own tile unless there is a nearby light source.
3. Towns should have light sources present at night.

Dungeon:
1. Dungeons should be updated based on type to have SOME fixed light sources. These could be things like torches, glowing moss, braziers, magical light sources, etc. Determine the appropriate type based on the dungeon. If a given type would not reasonably have lights (sewer, barrows) do not implement fixed light sources.

Enemies:
1. Any humanoid enemy with an intelligence greater than 5 will carry a light source in their off-hand in the dark (candle, torch, etc)

Existing Work: There is currently some kind of FOV system in place, and the ranged combat system has some kind of line of sight implementation. leverage these (reuse code) where applicable

Implement a fast (low resource) but effective algorithm for FOV and lighting. Look at https://www.redblobgames.com/x/2128-thin-wall-fov/ and https://www.adammil.net/blog/v125_Roguelike_Vision_Algorithms.html 

Ask any clarifying questions you need to implement this feature.

