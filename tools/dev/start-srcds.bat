@echo off

echo Starting local test server...

echo Starting SRCDS...

srcds.exe -console -game garrysmod +maxplayers 20 +gamemode versus +map exp_c18_v1_alpha034 +host_workshop_collection 3674693854
