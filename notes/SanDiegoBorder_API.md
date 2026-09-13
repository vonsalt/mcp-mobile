# San Diego Border Roleplay — API map (place 136020512003847)

Framework: **Pronghorn**. Remotes live at `ReplicatedStorage.__remotes.<Service>.<Remote>`
(85 service folders). The client accessor is:

```lua
local Remotes = require(ReplicatedStorage.SharedModules.Pronghorn.Remotes).Client
Remotes.<Service>:<Remote>(args...)
```

Each remote object is a table with `Fire`, `Connect`, `ConnectDeferred` and a `__call`
metamethod, so the colon-call form above is the correct idiom (matches the game's own code).

## Verified call signatures

| Call | Args | Notes |
|---|---|---|
| `WorldBuyableItemService:PurchaseWorldBuyableItem(model)` | the buyable **Model** | model is tagged `WorldBuyableItem` |
| `SmuggleService:SellSmuggledGoods(seller)` | instance tagged `SmuggledGoodsSeller` | |
| `SmuggleService:LaunderBriefcase(part)` | instance tagged `LaunderPromptPart` | |
| `BoxJobService:FetchBox(part)` | instance tagged `BoxFetchPrompt` | |
| `BoxJobService:DeliverBox(part)` | instance tagged `BoxDeliverPrompt` | |
| `TruckService:StartMission(missionId, contrabandPercent)` | RemoteFunction -> bool | |
| `TruckService:CancelCurrentMission()` | RemoteFunction | |
| `TruckService:SpeakToTrucker()` | opens shop server-side | |
| `BoatMissionService:StartMission(missionId)` | RemoteFunction -> bool | |
| `BoatMissionService:CancelCurrentMission()` | RemoteFunction | |
| `VehicleSpawnerService:SpawnVehicleFromSpawner(spawner, vehicleName)` | RemoteFunction -> bool | |
| `VehicleSpawnerService:SpawnBoatFromSpawner(spawner, boatName)` | RemoteFunction -> bool | |
| `VehicleSpawnerService:PurchaseVehicle(spawner, vehicleName)` | RemoteFunction -> bool | |

## Tagged instances (CollectionService)

| Tag | Count | Positions |
|---|---|---|
| `WorldBuyableItem` | 49 | Mexico civilian shop ~(6810,17,15), El Capo ~(6600,64,-440), US gun shop ~(205,16,490), printer shop (2980,-67,-1265) |
| `SmuggledGoodsSeller` | 2 | `Seller` @ (155,17,261), `Seller2` @ (-83,49,429) |
| `LaunderPromptPart` | 2 | (6805,18,-35) city, (6557,91,-440) El Capo |
| `BoxFetchPrompt` | 1 | (-30,18,-72) |
| `BoxDeliverPrompt` | 1 | (5,16,-62) |

## Smuggling economy (`SharedModules.ToolInfo`)

| Item | Price | Sell value | Profit | Margin | Detection |
|---|---|---|---|---|---|
| Crate Of Avacados | 150 | 375 | 225 | 150% | 10 |
| Wagyu Beef | 350 | 750 | 400 | 114% | 20 |
| Witches Brew | 500 | 1050 | 550 | 110% | 60 |
| Fake Designer Sneakers | 700 | 1388 | 688 | 98% | 35 |
| Fake Diamond Ring | 1000 | 1875 | 875 | 87% | 45 |
| Mona Lisa Painting | 3750 | 5520 | 1770 | 47% | 60 |
| El Diablo Box | 5250 | 7138 | 1888 | 36% | 75 |

Weapons/tools in the same table carry `Price` and `Detection` but no `Value` (not sellable).
`Money Printer` 20000, `Super Money Printer` 50000 (DevProduct), `Money Printer Booster` 20000.

## Truck missions (`Configs.TruckMissions:GetMissions()`)

| Id | Title | Base pay | Max contraband | Cooldown | Required completions | Vehicle |
|---|---|---|---|---|---|---|
| CarParts | CAR PARTS | 2000 | 500 | 300s | 0 | Chevy Express |
| FoodSupplies | FOOD SUPPLIES | 4000 | 1000 | 300s | 2 | International4700Fridge |
| GymEquipment | GYM EQUIPMENT | 6000 | 2000 | 300s | 8 | International4700 |
| Cement | CEMENT | 8000 | 3000 | 300s | 50 | International4700Cement |
| Petrol | PETROL | 10000 | 4000 | 300s | 100 | International4700Tanker |
| LumberSupplies | LUMBER SUPPLIES | 15000 | 6000 | 360s | 275 | LogTruck |
| SupermarketGoods | SUPERMARKET GOODS | 20000 | 10000 | 360s | 350 | SemiTruck |

Delivery point names: Autoshop, TacoHell, Gym, Scrapyard, PetrolStation, LumberYard, Supermarket.
Contraband percent slider bounds come from `TruckMissions:GetMinimumContrabandPercent()` /
`GetMaximumContrabandPercent()` / `GetContrabandPercentIncrement()`.

## Boat missions (`Configs.BoatMissions:GetMissions()`)

| Id | Title | Base pay | Cooldown | Required completions | Boat |
|---|---|---|---|---|---|
| DinghyRun | DINGHY RUN | 18375 | 450s | 0 | Dinghy |
| FishingBoatRun | FISHING BOAT RUN | 26775 | 525s | 25 | Aluminium_Fishing_Boat |
| GoFastRun | GO-FAST RUN | 33750 | 600s | 100 | Go_Fast_Boat |

## Vehicles

`Configs.VehicleInfo` — 95 entries, each `{Name, Price, Icon, SpawnerGroups}`.
`Configs.BoatInfo` — 7 entries: Aluminium_Fishing_Boat, Dinghy, Go_Fast_Boat, Police_Boat,
Response_Boat_Medium, TestBoat, Weaponized_dinghy.
`Workspace.VehicleSpawners` — 18 spawners. Attributes: `ParkingSpots`, `Authority=true` for
police-only, `Boats=true` + `Team` for boat spawners.

## Player state

- Money: `PlayerDataController:GetPlayerData().Currency.Money` (integer).
  `Players.<name>.ReplicatedStats.Money` is only the formatted HUD string ("10.6K").
- Player attributes: `WantedLevel`, `CurrentRankName`, `Sprinting`, `Crouching`,
  `LegallyCrossedBorder`, `FromMexico`, `VehicleDrivePermission`, `IsDeveloper`,
  `ShowModeratorTag`, `HasModeratorGui`, `InCivTutorial`, `CivTutorialState`, `DataLoaded`
- Teams: Civilian, plus authority teams (Coast Guard etc.)

## Anti-exploit surface (do not disable — for awareness only)

The game ships a real, server-backed anti-exploit stack:

- `__remotes.AntiTp` — `ApplyRollbackCFrame`, `ApplyVehicleRollback`, `AckVehicleRollback`
  (server rolls the player/vehicle back on illegal position deltas)
- `__remotes.AntiFly` — `DebugState`
- `__remotes.ExploitWatchService` — 17 remotes including `PushSellSpeedEvaluation`,
  `SellSpeedSimulation*`, `GetHoneypotLogPage`, `GetExploitLogPage`, `BanTalliedPlayers`,
  `TeleportToExploitTarget`
- `__remotes.ExploitTransferService` — `GetFlaggedReceiverPage`, `BanFlaggedReceivers`
- `__remotes.ExploitPurgeService` — `AcknowledgeResetNotice`
- Client modules: `AntiCheatController`, `AntiWalkSpeed`, `SharedModules.AntiCheatGeometry`,
  `SharedModules.ExploitWatchUtil`, `Workspace.NoClipTracker`

Consequences that matter for feature design: raw CFrame teleports get reverted, so travel has to
go through the game's own movement (see the measured table below); walkspeed is watched
client-side and reported; sell rate is profiled server-side. None of this is bypassed by the
script.

## Other useful modules

- `SharedModules.Configs`: Badges, BoatInfo, BoatMissions, Constants, CustomServerUtil,
  DailyRewards, DevProducts, EmoteConfig, GamepassDevProductMap, Gamepasses, GiftUtil, GunConfig,
  JailConfig, LightingUtil, LoadoutUtil, MarkerConfig, MeleeToolConfig, MoneyPrinterConfig,
  ReferralConfig, RegionSpeedLimits, TeamUtil, TruckMissions, VehicleCollisionConfig,
  VehicleCustomisation, VehicleInfo
- `SharedModules`: CivilianEconomyUtil (income multipliers), WantedLevelUtil, VehicleUtil,
  PlayerUtil, ToolInfo, TruckDeliveryUtil, RegionUtil, SightUtil, DuffelUtil
- `ClientModules` (90) incl. GunController, VehicleController, SmuggleController,
  BoxJobController, TruckController, BoatMissionController, WantedLevelController,
  MoneyPrinterController, CollectiblesController
- `ReplicatedStorage.Assets.TruckDeliveryPoints` — delivery point models

## Gotchas found while probing

- The MCP connector serialises each returned string at ~500 chars; chunk to <=470.
- `decompile()` on large controllers (GunController, VehicleShopGui) hangs/disconnects the
  Delta client. Decompile small modules only, or slice with `get-script-content`.

## Movement — what the anti-cheat actually allows (measured)

| Method | Result |
|---|---|
| Anchored root + CFrame tween | reverted by `AntiTp.ApplyRollbackCFrame` past ~400 studs, at any speed |
| Unanchored per-Heartbeat root CFrame | held 1500 studs once, then rolled back; character sits in Freefall |
| Repeated short hops (300 studs, 2-4s settle) | roughly one hop in two is accepted, then a lockout - does not accumulate |
| `MovementController:MoveTo(CFrame)` | **accepted**. Blocking. Walks up to ~600-750 studs per call, returns false past its range but still moves. Chain legs for distance. |
| `car:PivotTo()` per Heartbeat, seated | **accepted**. 6400 studs in 26s at 250 studs/s, player rides along, no rollback. 500 studs/s gets fought; 250 is the sweet spot. |

So: drive for distance, `MoveTo` legs on foot, and never raw-teleport the character more than a few studs.

## Other client APIs worth knowing

`require(ReplicatedStorage.ClientModules.MovementController)`:
`SetWalkSpeedModifier(name, delta)` (the controller overwrites direct `Humanoid.WalkSpeed`
every frame, so this is the only way that sticks), `GetWalkSpeed()`, `GetStamina()`,
`GetMaxStamina()` = 200, `ConsumeStamina`, `DrainStamina`, `StartSprinting`, `StopSprinting`,
`ToggleMobileSprint`, `MoveTo`, `LockMovementFor`, `SetMovementLock`, `GetIsSprinting`,
`GetIsCrouching`, `StartCrouching`, `StopCrouching`, `IsInAir`.

`require(ReplicatedStorage.ClientModules.PlayerDataController):GetPlayerData()` — full save
data. `Currency.Money` is the integer balance; `Players.<name>.ReplicatedStats.Money` is only
the formatted HUD string ("10.2K").

`Configs.GunConfig[<gun>].Stats` — real keys are `FirstPersonCameraRecoilFactor`,
`ThirdPersonCameraRecoilFactor`, `BulletSpreadDegrees`, `ShotgunSpreadDegrees`,
`EquipShootDelay`, `RPM`, `Damage`, `MagSize`, `Range`. There is no reload-time key; reload is
animation driven.

`Configs.RegionSpeedLimits` — `Regions.BorderSpeedLimitRegion = {MaxMPH = 21,
BrakeTorqueMultiplier = 1.75}` plus `MinimumBrakeInput`, `FullBrakeOverSpeedMPH`. There are no
`SpeedLimit` attributes anywhere in Workspace.

Vehicles carry `OwnerUserId` / `OwnerName` / `VehicleType` / `VehicleId` attributes.
`PurchaseVehicle` and `SpawnVehicleFromSpawner` both require the player within ~20 studs of the
spawner.

## The smuggling loop, as actually implemented by the game

1. Buy the good in Mexico (CivilianArea ~6810,17,15 or El Capo ~6600,64,-440).
2. Drive it to a `SmuggledGoodsSeller` in the US and fire `SellSmuggledGoods` — this does **not**
   pay cash, it hands you a `Briefcase` tool carrying a `SmuggleValue` attribute and
   `SmuggleCashContainer = true`.
3. Drive the briefcase back to a `LaunderPromptPart` in Mexico and fire `LaunderBriefcase` —
   that is when `Currency.Money` goes up.

Measured with Mona Lisa Painting: buy -$3,750, launder +$5,537, about 110s per round trip.
Crate Of Avacados: buy -$150, launder +$501.

Job NPCs `Workspace.NPC.TruckerNPC` and `Workspace.NPC.BoatNPC` gate `StartMission` at 18 studs.
Neither was present in the server tested, so both mission runners refuse until you are at the
depot/marina.

Box job: `BoxFetchPrompt` (-30,18,-72) and `BoxDeliverPrompt` (5,16,-62) are 36 studs apart, so
it needs no driving at all - measured 6 deliveries in 13 seconds.
