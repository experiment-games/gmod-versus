@echo off

echo Starting local test server...

echo Starting SRCDS...

srcds.exe -console -game garrysmod +maxplayers 20 +gamemode versus +map versus_c18_v1 +host_workshop_collection 3674693854
