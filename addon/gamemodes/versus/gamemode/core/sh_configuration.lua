versus.config = versus.config or {}

-- The date format used when showing a date to a player
versus.config["Date Format"] = "%Y-%m-%d @ %X"

-- The symbol displayed before money
versus.config["Money Symbol"] = "$"

-- The money that each player starts with.
versus.config["Default Money"] = 500

-- The access that each player begins with.
versus.config["Default Flags"] = "bc"

-- The default inventory that each player starts with.
versus.config["Default Inventory"] = {
  health_vial = 5,
}

-- The minimum amount of money that can be dropped as a money entity.
versus.config["Minimum Drop Amount"] = 25

-- The prefix that is used for chat commands.
versus.config["Command Prefix"] = "/"

-- The default inventory size (can be expanded with negative size items).
versus.config["Inventory Size"] = 100

-- The default chest inventory size (can be expanded with negative size items).
versus.config["Chest Inventory Size"] = 500

-- Players can only hear a player's voice if they are near them.
versus.config["Local Voice"] = true

-- The radius of each player that other players have to be in to hear them talk (units).
versus.config["Talk Radius"] = 256

-- TODO: Unused atm
-- Whether or not to automatically cleanup decals every minute.
versus.config["Cleanup Decals"] = true

-- The speed that players walk at.
versus.config["Walk Speed"] = 250

-- The speed that players run at.
versus.config["Run Speed"] = 375

-- The time that a player has to wait before they can spawn again (seconds).
versus.config["Spawn Time"] = 30

-- The time that a player bleeds for when they get damaged, leaving a blood decal (seconds).
versus.config["Bleed Time"] = 5

-- The time that a player gets knocked out for (seconds).
versus.config["Knock Out Time"] = 30

-- Scale the hand damage. (1 = 10 hits to die)
versus.config["Hand Damage"] = 0.1

-- Scale the stunstick damage. (1 = 10 hits to die)
versus.config["Stunstick Damage"] = 1

-- How much to scale ragdolled player damage by.
versus.config["Scale Ragdoll Damage"] = 2

-- How much to scale head damage by.
versus.config["Scale Head Damage"] = 2

-- How much to scale chest damage by.
versus.config["Scale Chest Damage"] = 0.75

-- How much to scale limb damage by.
versus.config["Scale Limb Damage"] = 0.5

-- The website URL drawn at the bottom of the screen.
versus.config["Website URL"] = ""

-- Props that are not allowed to be spawned.
versus.config["Maximum Prop Bounds"] = Vector(400, 400, 400)
versus.config["Banned Props"] = {
  "models/props_combine/combinetrain02b.mdl",
  "models/props_combine/combinetrain02a.mdl",
  "models/props_combine/combinetrain01.mdl",
  "models/cranes/crane_frame.mdl",
  "models/props_wasteland/cargo_container01.mdl",
  "models/props_c17/oildrum001_explosive.mdl",
  "models/props_canal/canal_bridge02.mdl",
  "models/props_canal/canal_bridge01.mdl",
  "models/props_canal/canal_bridge03a.mdl",
  "models/props_canal/canal_bridge03b.mdl",
  "models/props_wasteland/cargo_container01.mdl",
  "models/props_wasteland/cargo_container01c.mdl",
  "models/props_wasteland/cargo_container01b.mdl",
  "models/props_c17/column02a.mdl",
  "models/cranes/crane_frame.mdl",
  "models/props_c17/fence04a.mdl",
  "models/props_c17/fence03a.mdl",
  "models/props_c17/oildrum001_explosive.mdl",
  "models/props_combine/weaponstripper.mdl",
  "models/props_combine/combinetrain01a.mdl",
  "models/props_combine/combine_train02a.mdl",
  "models/props_combine/combine_train02b.mdl",
  "models/props_trainstation/train005.mdl",
  "models/props_trainstation/train004.mdl",
  "models/props_trainstation/train003.mdl",
  "models/props_trainstation/train001.mdl",
  "models/props_trainstation/train001.mdl",
  "models/props_wasteland/buoy01.mdl",
  "models/props/cs_militia/coveredbridge01_top.mdl",
  "models/props/cs_militia/coveredbridge01_left.mdl",
  "models/props/cs_militia/coveredbridge01_bottom.mdl",
  "models/props/cs_militia/silo_01.mdl",
  "models/props/cs_assault/money.mdl",
  "models/props/cs_assault/dollar.mdl",
  "models/props/de_nuke/ibeams_bombsitea.mdl",
  "models/props/de_nuke/fuel_cask.mdl",
  "models/props/de_nuke/ibeams_bombsitec.mdl",
  "models/props/de_nuke/ibeams_bombsite_d.mdl",
  "models/props/de_nuke/ibeams_ctspawna.mdl",
  "models/props/de_nuke/ibeams_ctspawnb.mdl",
  "models/props/de_nuke/ibeams_ctspawnc.mdl",
  "models/props/de_nuke/ibeams_tspawna.mdl",
  "models/props/de_nuke/ibeams_tspawnb.mdl",
  "models/props/de_nuke/ibeams_tunnela.mdl",
  "models/props/de_nuke/ibeams_tunnelb.mdl",
  "models/props/de_nuke/storagetank.mdl",
  "models/props/de_nuke/truck_nuke.mdl",
  "models/props/de_nuke/powerplanttank.mdl",
  "models/combine_helicopter.mdl",
  "models/props_trainstation/train002.mdl",
  "models/props_junk/gascan001a.mdl",
  "models/props_phx/mk-82.mdl",
  "models/props_phx/torpedo.mdl",
  "models/props_phx/misc/flakshell_big.mdl",
  "models/props_phx/playfield.mdl",
  "models/props_phx/amraam.mdl",
  "models/props_mining/techgate01_outland03.mdl",
  "models/props_mining/techgate01.mdl",
}

-- The rules for the server.
-- TODO: Do without rules, limit what shouldn't be done through gameplay
-- Add player based moderation by voting, only for behaviour that can't be automatically prevented, mitigated or detected
versus.config["Rules"] = [[
To maintain an entertaining atmosphere for all players we implore you to follow these rules.

1. Show respect towards other players:
     ‣ Treat others as you would like to be treated .
     ‣ No name-calling or any form of insult.
2. Do not use hacks or cheats.
3. Please help us find bugs, do not exploit them.
4. No politics, no religion, while playing a game is not the time and place to discuss it.
5. Do not advertise products, services or other servers.
6. It is forbidden to share personal information belonging to another player.
7. We report illegal activities to relevant law enforcement agencies.
     This means you can't share things like:
     ‣ Copyrighted material that isn't yours to share
     ‣ Anything featuring child (sexual) exploitation
     ‣ Media depicting or inciting crime
     ‣ Anything referencing or showing abuse of animals
     ‣ Our servers are located in the European Union. EU-law is applicable.
8. You may not promote violent organizations.
9. Any other kind of abusive behaviour or subversion of the rules is forbidden.
10. Thanks for helping us by reporting, but please don't report players without a reason.

When you break one or more of these rules you will be punished.
Examples of punishments:
     ‣ Feature restrictions
     ‣ Chat ban
     ‣ Kick
     ‣ Playtime restrictions (e.g: max 2 hours playtime per week)
     ‣ Temporary ban (e.g: no access for a day)
     ‣ "Permaban": A ban lasting 5-years

Do you think someone broke one of these rules? Help us by reporting them!
Check out our Discord for more information :)
]]
