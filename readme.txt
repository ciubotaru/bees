BEES MOD V3.0-dev
-------------

Bee colonies live in hives and gather honey from nearby flowers. A hive contains a bee colony and some space to store honey and wax (as combs or frames).

General mechanics
-----------------
Bee colonies are introduced into the game via random spawing of wild hives under "leaves" nodes.

The activity of a hive depends on the number of flowers within reach and the number of other hives around. The area where a hive collects honey and competes with other hives is measured by "bees_radius" (default value is 10). More flowers and less competitors means faster generation of honey (combs or frames) and eventually more swarms splitting off and creating new hives. Less flowers and more competition means depletion of honey and eventually death of the colony. Empty wild hives disappear after a while.

If a hive with a colony runs out of space to store honey (all combs/frames are filled), it splits: a swarm takes one comb of honey and flies away in search of a new location. Swarms settle between 1 and 2 radii from their mother hive. If conditions (flowers/competitors ratio) are good, a swarm will try to settle an abandoned hive, or create a new wild hive. If the swarm does not find any suitable location (not enough flowers, too many competitors, no amandoned hives, no leaves to hang a wild hive), it will die. Currently, only wild hives produce swarms.

Player can interact with bees by inspecting the contents of hives, placing and removing the colony, combs and frames. Specific tools are required to reduce aggressivity and move the colony.

Initially, the presence of bees had a positive effect on the number of flowers via "pollination". However, the pollination functionality was removed in order to avoid circular dependency (more bees -> more pollination -> more flowers -> more bees). Because of the built-in game mechanics, flowers propagate anyway.

Bee colony
----------
Bee colonies live in hives. To place a colony into a hive, or to remove the colony from the hive, the player needs to hold a special grafting tool. Bee colonies are normally aggressive and, if disturbed, will attack the player reducing his/her HP. A colony can be pacified by using a smoker.

Wild hive
---------
A wild hive contains a slot for the bee colony and 5 slots for honey combs. A new wild hive always appears (by swarming or by random spawing) with the colony and one comb of honey. Players can remove the colony and combs, and can place the colony. Users can not create wild hives. Digging an empty wild hive might yield a comb or a piece of wax (20% chance for each).

Artificial hive
---------------
An artifical hive contains a slot for the bee colony and 8 slots for frames (empty and/or full). An artificial hives are built from wood and sticks:

wood wood  wood
wood stick wood
wood stick wood

A living colony and empty frames are requred for the hive to produce honey (full frames). Users can place and remove the colony, empty and full frames. Currently, artificial hives are not diggable.

Honey Extractor
---------------
Extractors are used to extract honey and wax from full frames. The process requires full frames and empty bottles, and produces empty frames, wax and bottles with honey. To craft an extractor:

             steel_ingot
steel_ingot  stick       steel_ingot
mese_crystal steel_ingot mese_crystal

Smoker
------
Smokers are used to pacify the bees. To craft a bee smoker:

steel_ingot wool:red
            torch
            steel_ingot

Honey comb
----------
Description o be added.

Frame
-----
Description o be added.

Grafting tool
-------------
Description o be added.

Industrial hive
---------------
If 'pipeworks' mod is enabled, then an industrial hive is available. They function in the same manner as normal artificial hives, but have a different crafting recipe:

steel_ingot      homedecor:plastic_sheeting steel_ingot
pipeworks:tube_1 hive_artificial            pipeworks:tube_1
steel_ingot      homedecor:plastic_sheeting steel_ingot

AUTHORS
-------
See file AUTHORS

FORUM
-----
https://forum.minetest.net/viewtopic.php?pid=102905

LICENSE
-------
- code is GPLv3+
- textures are CC-BY-SA
