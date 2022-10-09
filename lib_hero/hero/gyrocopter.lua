local hero_data = {
	"gyrocopter",
	{1, 2, 1, 2, 1, 4, 1, 2, 2, 6, 3, 4, 3, 3, 7, 3, 10, 4, 12},
	{
		"item_magic_wand","item_quelling_blade","item_branches","item_boots_of_elves","item_boots","item_ring_of_basilius","item_power_treads","item_broadsword","item_blades_of_attack","item_lesser_crit","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_ogre_axe","item_blade_of_alacrity","item_point_booster","item_ultimate_scepter","item_lifesteal","item_skadi","item_claymore","item_satanic","item_invis_sword","item_silver_edge","item_bloodthorn","item_ultimate_scepter_2",
	},
	{ {1,1,1,1,3,}, {5,5,1,4,1,}, 0.1 },
	{
		"Rocket Barrage","Homing Missile","Flak Cannon","Call Down","+300 Flak Cannon Range","+200 Health","+0.4s Homing Missile Stun Duration","+2 Flak Cannon Attacks","+30 Movement Speed","+16 Rocket Barrage Damage","-6s Flak Cannon Cooldown","3x Call Down",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
		[0] = {"gyrocopter_rocket_barrage", ABILITY_TYPE.NUKE},
		{"gyrocopter_homing_missile", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE},
		{"gyrocopter_flak_cannon", ABILITY_TYPE.BUFF + ABILITY_TYPE.AOE + ABILITY_TYPE.ATTACK_MODIFIER},
		[5] = {"gyrocopter_call_down", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SLOW},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType

local fight_harass_handle = FightHarass_GetTaskHandle()

local t_player_abilities = {}

local d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, t_player_abilities) then
			return
		elseif false then -- TODO generic item use (probably can use same func for finished heroes)

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
