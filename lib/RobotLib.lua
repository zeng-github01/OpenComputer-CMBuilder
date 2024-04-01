-- 导入必要的组件和API
local robot = require("robot")
local sides = require("sides")
local component = require("component")
local inventory_controller = component.inventory_controller
local navigation = component.navigation

-- 导入坐标定位脚本
local Pos = require("Pos")

-- 创建Pos对象
local pos = Pos:new(0, 0, 0)

-- 封装存储控制器的方法
local function getInventorySize(side)
    return inventory_controller.getInventorySize(side)
end

local function getStackInSlot(side, slot)
    return inventory_controller.getStackInSlot(side, slot)
end

local function getStackInInternalSlot(slot)
    return inventory_controller.getStackInInternalSlot(slot)
end

local function getInternalInventorySize()
   return robot.inventorySize()
end

local function equip()
    return robot.equip()
end

local function swing(side, sneaky)
    return robot.swing(side, sneaky)
end

local function suckFromSlot(side, slot)
    return inventory_controller.suckFromSlot(side, slot)
end

local function drop(count)
    return robot.drop(count)
end

local function dropUp(count)
    return robot.dropUp(count)
end

local function dropDown(count)
    return robot.dropDown(count)
end

local function select(slot)
    robot.select(slot)
end

local function place(side, sneaky)
    robot.place(side,sneaky)
end

local function placeUp()
    robot.placeUp()
end

local function placeDown()
    robot.placeDown()
end

local function suck(count)
    robot.suck(count)
end

local function suckUp(count)
    robot.suckUp(count)
end

local function suckDown(count)
    robot.suckDown(count)
end

local function getFacing()
    return navigation.getFacing()
end

-- 更新Pos对象
local function updatePos(direction, steps)
    if direction == sides.front then
        pos.x = pos.x + steps
    elseif direction == sides.back then
        pos.x = pos.x - steps
    elseif direction == sides.top then
        pos.y = pos.y + steps
    elseif direction == sides.bottom then
        pos.y = pos.y - steps
    elseif direction == sides.left then
        pos.z = pos.z - steps
    elseif direction == sides.right then
        pos.z = pos.z + steps
    end
end

-- 使用机器人接口移动
local function move(direction, steps)
    local steps = steps or 1
    if direction == sides.front then
        for i = 1, steps do
            robot.forward()
        end
    elseif direction == sides.back then
        for i = 1, steps do
            robot.back()
        end
    elseif direction == sides.top then
        for i = 1, steps do
            robot.up()
        end
    elseif direction == sides.bottom then
        for i = 1, steps do
            robot.down()
        end
    elseif direction == sides.left then
        robot.turnLeft()
        for i = 1, steps do
            robot.forward()
        end
        robot.turnRight()
    elseif direction == sides.right then
        robot.turnRight()
        for i = 1, steps do
            robot.forward()
        end
        robot.turnLeft()
    end
    updatePos(direction, steps)
end

local function restPosition()
    local origin = Pos:new(0, 0, 0)
    if pos.x > origin.x then
        move(sides.back, pos.x - origin.x)
    elseif pos.x < origin.x then
        move(sides.front, origin.x - pos.x)
    end
    if pos.z > origin.z then
        move(sides.left, pos.z - origin.z)
    elseif pos.z < origin.z then
        move(sides.right, origin.z - pos.z)
    end
    if pos.y > origin.y then
        move(sides.bottom, pos.y - origin.y)
    elseif pos.y < origin.y then
        move(sides.top, origin.y - pos.y)
    end
end

-- 返回库
return {
    move = move,
    getInventorySize = getInventorySize,
    getStackInSlot = getStackInSlot,
    getStackInInternalSlot = getStackInInternalSlot,
    getInternalInventorySize = getInternalInventorySize,
    equip = equip,
    swing = swing,
    suckFromSlot = suckFromSlot,
    drop = drop,
    dropUp = dropUp,
    dropDown = dropDown,
    pos = pos,
    select = select,
    place = place,
    placeUp = placeUp,
    placeDown = placeDown,
    suck = suck,
    suckDown = suckDown,
    suckUp = suckUp,
    restPosition = restPosition,
    getFacing = getFacing
}
