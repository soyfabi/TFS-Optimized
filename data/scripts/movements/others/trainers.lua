local trainersConfig = {
    first_room_pos = Position(29460, 32631, 4), -- posicao da primeira pos (linha 1 coluna 1)
    distX= 12, -- distancia em X entre cada sala (de uma mesma linha)
    distY= 21, -- distancia em Y entre cada sala (de uma mesma coluna)
    rX= 6, -- numero de colunas
    rY= 8 -- numero de linhas
}

local exhaust = {}
local exhaustTime = 10
local lastPositions = {}

local function isBusyable(position)
    local player = Tile(position):getTopCreature()
    if player then
        if player:isPlayer() then
            return false
        end
    end

    local tile = Tile(position)
    if not tile then
        return false
    end

    local ground = tile:getGround()
    if not ground or ground:hasProperty(CONST_PROP_BLOCKSOLID) then
        return false
    end

    local items = tile:getItems()
    for i = 1, tile:getItemCount() do
        local item = items[i]
        local itemType = item:getType()
        if itemType:getType() ~= ITEM_TYPE_MAGICFIELD and not itemType:isMovable() and item:hasProperty(CONST_PROP_BLOCKSOLID) then
            return false
        end
    end

    return true
end

local function addTrainers(position, arrayPos)
    if not isBusyable(position) then
        for places = 1, #arrayPos do
            local trainer = Tile(arrayPos[places]):getTopCreature()
            if not trainer then
                local monster = Game.createMonster("Training Fonticak", arrayPos[places])
                monster:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
            end
        end
    end
end

local function calculatingRoom(uid, position, coluna, linha)
    local player = Player(uid)
    if coluna >= trainersConfig.rX then
        coluna = 0
        linha = linha < (trainersConfig.rY -1) and linha + 1 or false
    end

    if linha then
        local room_pos = {x = position.x + (coluna * trainersConfig.distX), y = position.y + (linha * trainersConfig.distY), z = position.z}
        if isBusyable(room_pos) then
            player:teleportTo(room_pos)
            player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
            addTrainers(room_pos, {{x = room_pos.x - 1, y = room_pos.y - 1, z = room_pos.z}, {x = room_pos.x + 1 , y = room_pos.y - 1, z = room_pos.z}})
        else
            calculatingRoom(uid, position, coluna + 1, linha)
        end
    else
        player:sendCancelMessage("Right now the trainers are full, come back later.")
    end
end

local function onTrainerSay(player, words, param)
    local playerId = player:getId()
    local currentTime = os.time()
    if exhaust[playerId] and exhaust[playerId] > currentTime then
        player:sendCancelMessage("You are on cooldown, for getting out of trainer very quickly, now wait (0." .. exhaust[playerId] - currentTime .. "s).")
        return false
    end
	
	if not player:getTile():hasFlag(TILESTATE_PROTECTIONZONE) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to be in a protection zone to use this command.")
		return false
	end
    
	player:sendTextMessage(MESSAGE_EVENT_ORANGE, "You have been teleported to the trainer!")
    exhaust[playerId] = currentTime + exhaustTime
    lastPositions[playerId] = player:getPosition()
    player:setDirection(DIRECTION_NORTH)
    calculatingRoom(player.uid, trainersConfig.first_room_pos, 0, 0)
    return false
end

local function onExitTrainerSay(player, words, param)
    local playerId = player:getId()
	
	if not player:getTile():hasFlag(TILESTATE_PROTECTIONZONE) then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to be in a protection zone to use this command.")
		return false
	end
	
    if lastPositions[playerId] then
		player:sendTextMessage(MESSAGE_EVENT_ORANGE, "You have been teleported to the protection zone!")
        player:teleportTo(lastPositions[playerId])
        player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
        lastPositions[playerId] = nil
    else
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to have used !trainer to use this command.")
    end
    return false
end

local trainer_enter = MoveEvent()

function trainer_enter.onStepIn(creature, item, position, fromPosition)
    if not creature:isPlayer() then
        return false
    end
    
    local playerId = creature:getId()
    local currentTime = os.time()
    if exhaust[playerId] and exhaust[playerId] > currentTime then
        creature:sendCancelMessage("You are on cooldown, for getting out of trainer very quickly, now wait (0." .. exhaust[playerId] - currentTime .. "s).")
        creature:teleportTo(fromPosition, true)
        return true
    end
    
    exhaust[playerId] = currentTime + exhaustTime
    lastPositions[playerId] = creature:getPosition()
    creature:setDirection(DIRECTION_NORTH)
    calculatingRoom(creature.uid, trainersConfig.first_room_pos, 0, 0)
    return true
end

trainer_enter:aid(65000)
trainer_enter:register()

local trainer_leave = MoveEvent()

function trainer_leave.onStepIn(creature, item, position, fromPosition)
    if not creature:isPlayer() then
        return false
    end
    
    local function removeTrainers(position)
        local arrayPos = {{x = position.x - 1, y = position.y - 1, z = position.z}, {x = position.x + 1 , y = position.y - 1, z = position.z}}
        for places = 1, #arrayPos do
            local trainer = Tile(arrayPos[places]):getTopCreature()
            if trainer then
                if trainer:isMonster() then
                    trainer:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
                    trainer:remove()
                end
            end
        end
    end

    removeTrainers(fromPosition)
    creature:teleportTo(creature:getTown():getTemplePosition())
    creature:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
    return true
end

trainer_leave:aid(65001)
trainer_leave:register()

staminaEvents = {}
local config = {
    timeToAdd = 5,
    addTime = 1,
}

local function addStamina(cid)
    local player = Player(cid)
    if not player then
        stopEvent(staminaEvents[cid])
        staminaEvents[cid] = nil
        return true
    end
    player:setStamina(player:getStamina() + config.addTime)
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You received "..config.addTime.." minutes of stamina.")
    staminaEvents[cid] = addEvent(addStamina, config.timeToAdd * 60 * 1000, cid)
end

local staminatile = MoveEvent()

function staminatile.onStepIn(creature)
    if creature:isPlayer() then
        creature:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "You will receive "..config.addTime.." minute of stamina every "..config.timeToAdd.." minutes for being on the trainer, and you will also receive an extra minute for attacking the trainer.")
        staminaEvents[creature:getId()] = addEvent(addStamina, config.timeToAdd * 60 * 1000, creature:getId())
    end
    return true
end

staminatile:aid(65020)
staminatile:register()

local staminatile_out = MoveEvent()

function staminatile_out.onStepOut(creature)
    if creature:isPlayer() then
        stopEvent(staminaEvents[creature:getId()])
        staminaEvents[creature:getId()] = nil
    end
    return true
end

staminatile_out:aid(65020)
staminatile_out:register()

local staminatile_logout = CreatureEvent("Stamina_Logout")

function staminatile_logout.onLogout(player)
    local playerId = player:getId()
    if staminaEvents[playerId] then
        stopEvent(staminaEvents[player:getId()])
        staminaEvents[player:getId()] = nil     
        player:teleportTo(player:getTown():getTemplePosition())
    end
    return true
end

staminatile_logout:register()

-- Register the new commands
local trainerCommand = TalkAction("!trainer")
trainerCommand.onSay = onTrainerSay
trainerCommand:register()

local exitTrainerCommand = TalkAction("!exittrainer")
exitTrainerCommand.onSay = onExitTrainerSay
exitTrainerCommand:register()