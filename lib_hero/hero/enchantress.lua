local hero_data = {
	"enchantress",
	{1, 2, 1, 2, 1, 5, 1, 3, 3, 6, 3, 2, 3, 12, 8, 2, 5, 10},
	{
		"item_tango","item_magic_stick","item_enchanted_mango","item_enchanted_mango","item_enchanted_mango","item_branches","item_branches","item_boots","item_magic_wand","item_staff_of_wizardry","item_point_booster","item_ogre_axe","item_ultimate_scepter","item_cloak","item_headdress","item_hood_of_defiance","item_pipe","item_belt_of_strength","item_dragon_lance","item_force_staff","item_hurricane_pike","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_hyperstone","item_moon_shard",
	},
	{ {3,3,3,4,2,}, {3,3,4,5,2,}, 0.1 },
	{
		"Impetus","Enchant","Nature's Attendants","Little Friends","Untouchable","+10% Magic Resistance","+30 Movespeed during Nature's Attendants","+45 Damage","+5 Nature's Attendants Wisps","-65 Untouchable Slow","Enchant Affects Ancients","+6.5% Impetus Damage","+20 Nature's Attendants Heal",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
	[0] = {"enchantress_impetus", ABILITY_TYPE.ATTACK_MODIFIER + ABILITY_TYPE.UNIT_TARGET + ABILITY_TYPE.SINGLE_TARGET + ABILITY_TYPE.NUKE},
	{"enchantress_enchant", ABILITY_TYPE.SLOW + ABILITY_TYPE.SUMMON + ABILITY_TYPE.UNIT_TARGET},
	{"enchantress_natures_attendants", ABILITY_TYPE.HEAL + ABILITY_TYPE.AOE},
	{"enchantress_bunny_hop", ABILITY_TYPE.NUKE + ABILITY_TYPE.MOBILITY},
	[5] = {"enchantress_untouchable", ABILITY_TYPE.PASSIVE + ABILITY_TYPE.BUFF},
}

local N_A_DUR = 11
local HIGH_USE_N_A_REMAINING_MANA = 65 + 70
local HIGH_USE_IMP_REMAINING_MANA = 70 + 170
local HIGH_USE_ENC_REMAINING_MANA = 65 + 170
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric

-- TODO clean up redudant global search
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local INCENTIVISE_TASK = Task_IncentiviseTask
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_ENEMY_HERO = SET_ENEMY_HERO
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed

local fight_harass_task_handle = FightHarass_GetTaskHandle()

local min = math.min
local max = math.max
local rad = math.rad
local cos = math.cos
local asin = math.asin

local ACCEPTABLE_FACING = cos(MATH_PI/6)

local t_player_abilities = {}

local d
d = {
	["SproinkDominateFunc"] = function(gsiPlayer)
		local sproink = t_player_abilities[gsiPlayer.nOnTeam][4]
		if sproink:GetCooldownTimeRemaining() > 0 or gsiPlayer.sproinkTryExpiry < RealTime() then
			gsiPlayer.sproinkDesiredFacing = nil
			gsiPlayer.sproinkMovementVector = nil
			-- keep the expiry to avoid repeated locking
			return;
		end
		local unitFacingTarget = gsiPlayer.sproinkDesiredFacing - rad(gsiPlayer.hUnit:GetFacing())
		if cos(unitFacingTarget) > ACCEPTABLE_FACING then
			gsiPlayer.hUnit:Action_UseAbility(sproink)
			return;
		end
		gsiPlayer.hUnit:Action_MoveToLocation(
				Vector_Addition(
						gsiPlayer.lastSeen.location,
						gsiPlayer.sproinkMovementVector
					)
			)
		end,
	["StartCastSproink"] = function(gsiPlayer, awayFromLoc)
		local unitDirectional = Vector_UnitDirectionalPointToPoint(gsiPlayer.lastSeen.location, awayFromLoc)
		gsiPlayer.sproinkDesiredFacing = asin(unitDirectional.y)
		gsiPlayer.sproinkMovementVector = Vector_ScalarMultiply(unitDirectional, 50)
		gsiPlayer.sproinkTryExpiry = RealTime() + 0.75
		DOMINATE_SetDominateFunc(gsiPlayer, "LibHero_EnchantressCastSproink", d.SproinkDominateFunc, true)
	end,
	["untouchable_at_lvl"] = {0,-1,-1.4,-1.8},
	["UntouchableAtLevel"] = function(lvl) return d.untouchable_at_lvl[min(4, math.floor(lvl/6)+1)] end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["AbilityThink"] = function(gsiPlayer)
		if not UseAbility_IsPlayerLocked(gsiPlayer) then
			local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
			local naturesAttendants = thisPlayerAbilities[3]
			local sproink = thisPlayerAbilities[4]
			local currHealthPercent = (gsiPlayer.lastSeenHealth-Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit)/2)/gsiPlayer.maxHealth
			local currManaPercent = gsiPlayer.lastSeenMana / gsiPlayer.maxMana
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, naturesAttendants) and currHealthPercent < 0.8 then
				-- Nature's Attendants Self
				local potentialHeal = naturesAttendants:GetSpecialValueInt("wisp_count") * naturesAttendants:GetSpecialValueInt("heal") * N_A_DUR
				local potentialHealPercent = potentialHeal / gsiPlayer.maxHealth
				local resultantHealthPercent = currHealthPercent + potentialHeal / gsiPlayer.maxHealth
				local healUtilization = potentialHealPercent - (resultantHealthPercent - 1)/potentialHealPercent
				local remainingMana = gsiPlayer.lastSeenMana - naturesAttendants:GetManaCost()
				if remainingMana > 0 and 
						( 	( 1 - min(0.25, 
								gsiPlayer.vibe.safetyRating) 
							) * healUtilization
						) + max(0, min(1, remainingMana/HIGH_USE_N_A_REMAINING_MANA)) * 0.33
							> ((gsiPlayer.lastSeenHealth - Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit))/gsiPlayer.maxHealth - 0.33) -- or 0.67 - (1-HP%)
				then
					UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, naturesAttendants, nil, VALUE_OF_ONE_HEALTH*potentialHeal - VALUE_OF_ONE_MANA*naturesAttendants:GetManaCost()+100, nil)
				end
			end
			local impetus = thisPlayerAbilities[1]
			HANDLE_AUTOCAST_GENERIC(gsiPlayer, impetus)
			local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_task_handle)
			local currentTask = CURRENT_TASK(gsiPlayer)
			local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)

			if fightHarassTarget and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then 
				local fightHarassPercentHealth = fightHarassTarget.lastSeenHealth / fightHarassTarget.maxHealth
				-- enchant player
				local enchant = thisPlayerAbilities[2]
				local currTask = CURRENT_TASK(gsiPlayer)
				if AbilityLogic_AbilityCanBeCast(gsiPlayer, enchant)
						and fightHarassTarget.currentMovementSpeed > gsiPlayer.currentMovementSpeed * 0.85
						and AbilityLogic_HighUseAllowOffensive(gsiPlayer, enchant, HIGH_USE_ENC_REMAINING_MANA, fightHarassPercentHealth) then
					UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, enchant, fightHarassTarget, 400, nil)
					Task_IncentiviseTask(gsiPlayer, fight_harass_task_handle, 15, 3)
				end
			end
			if not sproink:IsHidden() and currentActivityType > ACTIVITY_TYPE.CAREFUL then
				d.StartCastSproink(gsiPlayer, ENEMY_FOUNTAIN)
			end
		end
	end
}
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
