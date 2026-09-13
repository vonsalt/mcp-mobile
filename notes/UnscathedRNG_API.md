# Unscathed RNG — API map (place 122951224417794)

Paused mid-mapping (user switched games). Everything below is verified live.

## Networking
All actions are plain RemoteEvents parented under `ReplicatedStorage.Libraries.Network`.
`require(ReplicatedStorage.Libraries.Network)` returns `{ _events, create, on, send, sendTo, sendToAll, setRateLimitedHandler }`.

- `Network.send(name, ...)` -> `_events[name]:FireServer(...)`
- `Network.on(name, fn)` -> connects `OnClientEvent`
- Non-RemoteEvent children: `RateLimiter` (ModuleScript), `TokenRateLimiter` (ModuleScript), `player_respawn` (BindableEvent)

### Full action list (103)
```
add_cash, add_exp, add_gems, add_rolls, admin_command, admin_mount_toggle, admin_panel,
afk_teleport_request, battlepass_skip_request, broadcast_aura_rolled, cannon_action,
claim_achievement, claim_all_achievements, claim_all_battlepass, claim_battlepass_reward,
claim_reward, combat_choose_aura, combat_cover_up, combat_event, combat_ready,
combat_set_speed, combat_turn_done, combat_vote, craft_add_ingredient, craft_claim,
craft_skip_request, craft_start, craft_toggle_auto, cutscene_request, drop_held, equip_item,
expedition_cancel, expedition_claim, expedition_start, get_player_inventory_auras, gift_claim,
gift_claim_all, gift_decline, gift_received, gift_request, gift_sent, give_aura, give_cash,
give_item, glider_shop_buy, gliding_action, grant_aura, grant_gamepass, grant_item, hold_item,
mark_community_joined, notification, notify_aura_selection, npc_interaction_ended,
npc_interaction_started, player_respawn, purchase_inventory_slot, pvp_pad_set_barrier,
quest_action, redeem_code, resolve_unresolved_aura, roll_aura, roll_trait, rotating_shop_buy,
select_starter_aura, sell_items, send_global_chat_message, set_admin, set_cash,
set_combat_action, set_combat_auto, set_combat_auto_action, set_level, set_luck,
set_placement_hidden, set_setting, set_walkspeed, skill_unlock_upgrade, skip_tutorial,
spawn_item, story_pivot_done, story_pivot_request, teleport_player, teleport_to_dojo,
toggle_auto_roll, toggle_favorite_aura, toggle_quick_roll, trade_offer, trade_respond,
trade_status, try_cancel_selection, try_create_room, try_join_party, try_leave_party,
try_set_ready, unequip_item, unlock_all, updates_seen, upgrade_gem, use_ability, use_item
```
(`add_*`, `give_*`, `grant_*`, `set_admin`, `set_cash`, `set_level`, `set_luck`, `unlock_all`,
`spawn_item`, `admin_*` are admin-gated server side.)

### Observed call signatures (from decompiled client)
```
send("roll_aura", requestId)                       -> reply on("roll_aura", requestId, result)
send("redeem_code", code)
send("get_player_inventory_auras", userId, true)
send("sell_items", itemList)
send("equip_item", itemId) / send("unequip_item", itemId)
send("hold_item", itemId) / send("drop_held")
send("use_item", itemId, arg)
send("toggle_favorite_aura", auraId)
send("select_starter_aura", auraName)
send("skill_unlock_upgrade", nodeId, arg)
send("upgrade_gem", gemId)
send("purchase_inventory_slot")
send("claim_achievement", id) / send("claim_all_achievements")
send("claim_battlepass_reward", a, b) / send("claim_all_battlepass")
send("battlepass_skip_request", n)
send("quest_action", {table})
send("roll_trait", itemId)
send("rotating_shop_buy", a, b, c, d)
send("glider_shop_buy", gliderId)
send("expedition_start", a, b, ctx) / expedition_claim(id, ctx) / expedition_cancel(id, ctx)
send("craft_start", recipe, ctx) / craft_add_ingredient(a, b, qty, ctx)
send("craft_claim", recipe, ctx) / craft_skip_request(recipe, ctx) / craft_toggle_auto(on, ctx)
send("set_setting", key, value)
send("combat_choose_aura", auraName) / combat_ready(id) / combat_cover_up(id)
send("combat_turn_done", id) / set_combat_action(a, b) / set_combat_auto(bool)
send("combat_set_speed", n) / send("combat_vote", {table})
send("gift_request", a, b, c) / gift_claim(id) / gift_claim_all() / gift_decline(id)
send("trade_offer", tonumber(x)) / trade_respond(bool)
send("try_create_room", id, 1, {..}) / try_join_party / try_leave_party / try_set_ready(a,b)
send("teleport_to_dojo") / send("afk_teleport_request") / send("player_respawn")
send("npc_interaction_started", npcName) / send("npc_interaction_ended")
send("story_pivot_request", padName) / send("cutscene_request", "Replicate"|"Destroy", id, type)
send("gliding_action", Enums.GlidingAction.End, {})
send("cannon_action", Enums.CannonAction.Enter|Land, {})
send("set_placement_hidden", a, b) / send("updates_seen") / send("mark_community_joined")
send("skip_tutorial") / send("notify_aura_selection", x)
```

`ReplicatedStorage.Client.UI.Screens.HUDUI.Spin.RollRequest.Send(name, janitor, callback, ...)`
wraps a request id + 10s timeout around `Network.send`.

## State replication — ReplicaService (Madwork)
`require(ReplicatedStorage.Libraries.ReplicaController)` -> `_replicas`, `GetReplicaById`,
`ReplicaOfClassCreated`, `RequestData`, `NewReplicaSignal`, `InitialDataReceivedSignal`.

Replicas present:
| Class | Tags | Data keys |
|---|---|---|
| `Global` | — | biomeChangeAt, currentBiome, glideRingsCFrames, pendingRooms, quests, rotatingShop, spawnCFrame, stats |
| `Player_<uid>` | Player=<name> | 77 keys (below) |
| `Item_<uid>` | Player | items |
| `Achievement_<uid>` | Player | claimable, claimed, trackedValues |
| `Quest_<uid>` | Player | poolClaims, quests |

### Player replica data keys (77)
```
accuracyIncrease, activeBattlepassQuests, auraCollection, auraStorageLevel, autoRoll,
baseCritChance, battlepassExp, battlepassLevel, battlepassQuestRerolls, biomeLuck,
biomeRollSpeed, bonusRollLuck, cash, cashMultiplier, cashOnBonusRoll,
claimedBattlepassRewards, completedQuests, craftedPotionDuplicateChance, crafting,
crateDuplicateChance, damageMultiplier, dodgeChance, elementDamageReduction,
elementalDamageMultiplier, elementalLuck, elementalLuckOnBonusRoll, expeditions,
finishedTutorial, firstJoinedAt, friendsOnline, gearCraftTimeReduction,
gearMaterialCostReduction, giftedGamepasses, glideCooldownEndsAt, inAuraAbility,
inventorySlots, isBonusRoll, isInStoryZone, joinedCommunity, lastSeenUpdate, level,
lowHealthDamageMultiplier, lowHpDamageReduction, luck, luckOnBonusRoll, obbyCooldownEndsAt,
ownedGamepasses, paidRandomItemsRestricted, pendingGifts, pickedItemDuplicateChance,
potionCraftTimeReduction, potionDurationBonus, potionPower, quickRoll, rollBonusLuckTracker,
rollCount, rollsTillBonus, rotatingShop, selectedStarterAura, settings, shieldMultiplier,
skillTreePoints, skillTreeUpgrades, specialBuff, spinCooldown, spinTime, spinTimeBuff,
starterPackEndsAt, starterPackPurchased, statusEffects, storyProgression, unresolvedAura,
walkSpeedBonus, worldItemSpawns, xp, xpMultiplier, xpMultiplierOnBonusRoll
```

## Roll loop
`ReplicatedStorage.Configs.RollConfig`:
```
BaseSpinTime = 3, BaseSpinCooldown = 2, MinSpinCooldown = 0.05
AutoRollNextRollDelay = 0.05, QuickRollSpinTimeRatio = 0.4
```
Client state machine: `Client.UI.Screens.HUDUI.Spin.SpinStateMachine`
states = Idle -> AwaitingRollResult -> Spinning -> AwaitingResolution -> Cooldown -> Idle.
`AutoRollRunner` drives it off the server stat `autoRoll` (set via `toggle_auto_roll`).
Server-side gates: `Validators.RollEligibilityValidator`, `Validators.AutoRollEligibilityValidator`.

## Other folders
- `ReplicatedStorage.Configs` (47): AchievementConfig, AdminPanelConfig, AnimationConfig,
  AuraCombatConfig, AuraIconConfig, BattlepassConfig, BiomeConfig, CombatConfig, CraftingConfig,
  CrateConfig, DevPlaceConfig, DevProductConfig, EffectConfig, ErrorConfig, ExpConfig,
  ExpeditionConfig, FriendLuckBoostConfig, GamepassConfig, GiftConfig, GlidingConfig,
  ImpactFramesConfig, InteractionAnchorConfig, InventoryConfig, ItemConfig, MilestoneConfig,
  NpcConfig, PVPConfig, ProductHelpers, QuestConfig, RandomItemConfig, RewardTypeConfig,
  RollConfig, RollbackDiffConfig, RotatingShopConfig, SettingsConfig, SkillTreeConfig,
  StoryConfig, TagConfig, TipsConfig, TitleConfig, TowerConfig, TradeConfig, TraitConfig,
  TutorialConfig, UpdatesConfig, UpgradeGemConfig, WorldItemSpawnConfig
- `ReplicatedStorage.Validators` (29): AutoRollEligibilityValidator, CanClaimAchievement,
  CanEnterAct, CanSelectAuras, CanSetPlacementHidden, CanUsePivotPad, CombatValidator, Crafting,
  CutsceneSpeedValidator, DoesActExist, DoesStageExist, EnsureIdle, EnsureNotInCombat,
  EnsureNotInParty, ExpeditionStartValidator, GemUpgradeValidator, GiftRequestValidator,
  GliderPurchaseValidator, HasMinimumAuras, InventoryRoomValidator, IsActUnlocked,
  IsStageUnlocked, QuestEligibilityValidator, RollEligibilityValidator,
  RotatingShopPurchaseValidator, SettingsValidator, SlotPurchaseValidator, TradeOfferValidator,
  TraitRollValidator
- `ReplicatedStorage.Libraries` (21): ActionLock, DummyFactory, GroupRanks, HumanoidStateHandler,
  Janitor, LightingManager, MadworkMaid, MadworkScriptSignal, Net, Network, Pool,
  QuestItemSpawnMap, RNG, RateLimiter, ReplicaController, SoundPlayer, TerrainGenerator,
  TypeChecker, ZoneService, refx, spr
- `ReplicatedStorage.Client` (16): Animations, BindableEvents, Combat, Configs, Controllers,
  Entities, Equipment, Library, Lifecycle, Managers, Prefabs, PullCutscene, Services,
  SoundGroupManager, UI, UseItemFlow
- `Client.Controllers` (19): AFK, Achievement, AdminMount, Battlepass, Biome, ChatTag,
  FollowSocialEvent, Gliding, GemUpgrade, Gift, ObbyVFX, Quest, Settings, Shop, Tower, Trade,
  Trait, Tutorial, WorldItemSpawn
- `Client.Services` (10): AchievementService, AuraCutsceneAssetService, GlobalPoolManager,
  GlobalService, ItemService, LocalCharacterAnimatorService, PlayerService, ProductService,
  QuestService, ReplicatorInitializer

## Notes
- The connector serialises each returned string at ~500 chars; chunk to <=470 to read sources.
- `decompile(module)` is available on this executor; `script-grep` needs sources uploaded first.
