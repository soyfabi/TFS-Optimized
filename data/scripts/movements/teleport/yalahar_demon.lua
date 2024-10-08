local setting = {
	-- west entrance
	[4244] = {
		sacrificePosition = Position(32859, 31056, 9),
		pushPosition = Position(32856, 31054, 9),
		destination = Position(32860, 31061, 9)
	},
	--east entrance
	[4245] = {
		sacrificePosition = Position(32894, 31044, 9),
		pushPosition = Position(32895, 31046, 9),
		destination = Position(32888, 31044, 9)
	}
}

local yalaharDemon = MoveEvent()

local exhaust = {}
local exhaustTime = 10

function yalaharDemon.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	
	local playerId = creature:getId()
    local currentTime = os.time()
    if exhaust[playerId] and exhaust[playerId] > currentTime then
		creature:sendCancelMessage("You are on cooldown, now wait (0." .. exhaust[playerId] - currentTime .. "s).")
		creature:teleportTo(fromPosition, true)
		return true
	end

	local flame = setting[item.actionid]
	if not flame then
		return true
	end

	local sacrificeId, sacrifice = Tile(flame.sacrificePosition):getThing(1).itemid, true
	if not isInArray({940, 941, 944, 945}, sacrificeId) then
		sacrifice = false
	end

	if not sacrifice then
		player:teleportTo(flame.pushPosition)
		position:sendMagicEffect(CONST_ME_ENERGYHIT)
		flame.pushPosition:sendMagicEffect(CONST_ME_ENERGYHIT)
		exhaust[playerId] = currentTime + exhaustTime
		return true
	end

	local soilItem = Tile(flame.sacrificePosition):getItemById(sacrificeId)
	if soilItem then
		soilItem:remove()
	end

	player:teleportTo(flame.destination)
	position:sendMagicEffect(CONST_ME_HITBYFIRE)
	flame.sacrificePosition:sendMagicEffect(CONST_ME_HITBYFIRE)
	flame.destination:sendMagicEffect(CONST_ME_HITBYFIRE)
	return true
end

yalaharDemon:type("stepin")

for index, value in pairs(setting) do
	yalaharDemon:aid(index)
end

yalaharDemon:register()
