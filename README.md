# Grow Hair!

Roblox hair-farming simulator. Players start bald with Patchy hair, collect hair tufts in
progressively unlocked farms, sell their hair at the Barbershop, and buy better hair types.

## Code (synced with Rojo)
- `src/ReplicatedStorage/HairConfig.luau`: all tuning (hair types, farm zones, prices, sounds)
- `src/ReplicatedStorage/HairRemotes/`: RemoteEvents `Notify`, `FX`, `Shop`
- `src/ServerScriptService/HairServer.server.luau`: data saving, tuft collection, selling, gates, shop
- `src/StarterPlayer/StarterPlayerScripts/HairClient.client.luau`: hair rendering, HUD, shop UI, effects

## The map lives in the place file
The world (`Workspace.HairCity`, `Workspace.HairFarms`, tagged `Tuft` / `ZoneGate` / `ZoneKiosk`
parts) is built in Studio and saved with the place, not in this repo. The scripts expect it to exist.
