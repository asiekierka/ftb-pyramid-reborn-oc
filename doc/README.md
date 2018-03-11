# FTB Pyramid Reborn OpenComputers documentation

The software documented here is available in the "Quest Provisioning Centre" room of the center pyramid.

## provisioning_server.lua

This is the most important tool - it is used to remotely update all other computers. It has to be running on the main server in the room in order for other computers 
to install the latest version of the software in ./software directories, as well as for them to be able to reboot (as they update on every reboot).

The tool accepts a single argument, "noreboot" - by default, it will send a reboot packet to all computers when it is first launched. This process does take a few 
minutes, and sometimes you might want to reboot only one affected computer manually (for example when debugging an issue).

## Software used on remote computers

* crc32.lua, inflate.lua, png.lua - library code from "octagon"
* qutil.lua - utility code shared across questing software packages

* software/ - code uploaded to the quest displays
* software/pngdraw.lua - PNG drawing library
* software/provisioning_client.lua - The client for managing remote updates. It is installed on *all* computers which accept updates from the provisioning server and 
updated on every reboot.
* software/quest.lua - The main file for quest display computers. It handles displaying quest progress, as well as emitting information (a packet if the quest is 
matched >=1x, a redstone signal if it is matched >=2x).

* software_leaderboard/quest.lua - The main file for leaderboard computers. It handles displaying overall quest progress. To rename or change the color of teams, this 
is the file you want to edit.

* software_xnet/quest.lua - The main file for XNet-controlling computers. It handles transferring items across the XNet network - in particular, accepting input items 
from the center chest and distributing rewards.

## Software for quest development

* chest_setup.lua - A tool for configuring the chest mapping for recipe input chests. Run it if you rearrange the recipe input chests.
* compile_quests.lua - This tool compiles the information from quests/*.txt and pushes it to out/*.txt (quest configuration) and out/*.files (file list) respectively. 
It handles importing requirements from mapped chests, as well as translating item names.
* slot_image.lua - A tool for uploading PNG icons for quest items. Utilizes information from out/*.txt to figure out which quest's slot an icon is being uploaded for.
