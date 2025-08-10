local component = require("component")
local database = component.database
local robotLib = require("robot.RobotLib")
local json = require("json")
local Pos = require("robot.Pos")
local filesystem = require("filesystem")
local sides = require("sides")
local rs = component.redstone

local recipePath = "/usr/bin/recipe/"

local craftingPos = Pos:new(1, 1, 1)

local function updatePos(direction, steps)
    if direction == sides.front then
        craftingPos.x = craftingPos.x + steps
    elseif direction == sides.back then
        craftingPos.x = craftingPos.x - steps
    elseif direction == sides.top then
        craftingPos.y = craftingPos.y + steps
    elseif direction == sides.bottom then
        craftingPos.y = craftingPos.y - steps
    elseif direction == sides.left then
        craftingPos.z = craftingPos.z - steps
    elseif direction == sides.right then
        craftingPos.z = craftingPos.z + steps
    end
end

-- 从数据库中获取合成表信息，跳过空的格子
local function getCraftingPattern(row)
    local materials = {}
    local catalyst
    local product
    for i = 1, 7 do  -- 前7个格子是原材料
        local item = database.get(row * 9 - 9 + i)
        if item then -- 如果格子不为空，则添加到材料列表
            table.insert(materials, item)
        end
    end
    catalyst = database.get(row * 9 - 9 + 8) -- 第8个格子是催化剂
    product = database.get(row * 9 - 9 + 9)  -- 第9个格子是产物
    return materials, catalyst, product
end

-- 比对机器人内部物品堆栈与合成表
local function matchRecipe()
    for row = 1, 9 do              -- 假设数据库每9个格子为一行
        local materials, catalyst, product = getCraftingPattern(row)
        local materialMatches = {} -- 用于跟踪每种材料是否匹配

        -- 初始化材料匹配跟踪表
        for i = 1, #materials do
            materialMatches[i] = false
        end

        -- 遍历机器人的所有物品槽
        for slot = 1, robotLib.getInternalInventorySize() do
            local stack = robotLib.getStackInInternalSlot(slot)
            for i, material in ipairs(materials) do
                if stack and not materialMatches[i] then
                    if stack.name == material.name and stack.damage == material.damage then
                        materialMatches[i] = true -- 标记找到匹配的材料
                        break
                    end
                end
            end
        end


        -- 检查是否所有材料都找到了匹配项
        local allMatched = true
        for _, matched in ipairs(materialMatches) do
            if not matched then
                allMatched = false
                break
            end
        end

        -- 如果所有材料都匹配，则返回产物的ID和damage值
        if allMatched then
            local itemName = product.name:match(":(.+)$")
            return itemName .. "_" .. product.damage, catalyst  -- 返回匹配的合成表产物的ID和damage值
        end
    end
    return nil -- 没有匹配的合成表
end

local function readJson(filename)
    local fullPath = recipePath .. filename .. ".json"
    -- 检查文件是否存在
    if filesystem.exists(fullPath) and not filesystem.isDirectory(fullPath) then
        local file = io.open(fullPath, "r")
        if file then
            local content = file:read("*a")
            file:close()
            -- 将文件内容解析为 Lua 表
            return json.decode(content)
        else
            error("无法打开文件: " .. fullPath)
        end
    else
        error("文件不存在或路径错误: " .. fullPath)
    end
end

local function makePaste()
    -- local equipSlot
    local recipeName, catalyst = matchRecipe()
    -- for slot = 1, robotLib.getInternalInventorySize() do
    --     local pasteStack = robotLib.getStackInInternalSlot(slot)
    --     if pasteStack then
    --         print("lable".. pasteStack.lable)
    --         print("name" .. pasteStack.name)
    --         if pasteStack.name == "buildinggadgets:copypastetool" and pasteStack.lable == recipeName then
    --             robotLib.select(slot)
    --             equipSlot = slot
    --             robotLib.equip()
    --             break            
    --         end
    --     end
    -- end
    robotLib.use()
    if catalyst then
        local upSteps = 7 - craftingPos.y
        -- 向上移动指定格数
        robotLib.move(sides.top, upSteps)
        -- 丢下催化剂
        for catalystSlot = 1, robotLib.getInternalInventorySize() do
            local catalystStack = robotLib.getStackInInternalSlot(catalystSlot)
            if catalystStack and catalystStack.name == catalyst.name and catalystStack.damage == catalyst.damage then
                robotLib.select(catalystSlot)
                robotLib.drop()
                break
            end
        end
    end
    -- robotLib.select(equipSlot)
    -- robotLib.equip()
end

-- 自定义处理每个格子的内容
local function process_cell_content(relativeX, relativeY, relativeZ, cell_content)
    if cell_content == "air" then
        return
    end


    -- 计算从当前位置到目标位置的移动距离
    local moveX = relativeX - craftingPos.x
    local moveY = relativeY - craftingPos.y
    local moveZ = relativeZ - craftingPos.z

    -- 移动到正确的位置
    if moveY > 0 then
        robotLib.move(sides.top, moveY)
        updatePos(sides.top, moveY)
    elseif moveY < 0 then
        robotLib.move(sides.bottom, -moveY)
        updatePos(sides.bottom, -moveY)
    end

    if moveX > 0 then
        robotLib.move(sides.front, moveX)
        updatePos(sides.front, moveX)
    elseif moveX < 0 then
        robotLib.move(sides.back, -moveX)
        updatePos(sides.back, -moveX)
    end

    if moveZ > 0 then
        robotLib.move(sides.right, moveZ)
        updatePos(sides.right, moveZ)
    elseif moveZ < 0 then
        robotLib.move(sides.left, -moveZ)
        updatePos(sides.left, -moveZ)
    end

    if cell_content == "minecraft:hopper" then
        rs.setOutput(sides.bottom, 10)
    end

    if robotLib.selectItem(cell_content) then
        robotLib.placeDown()
    end
end

local function processRecipe()
    local recipeName, catalyst = matchRecipe()
    craftingPos = Pos:new(1, 1, 1)
    local recipe = readJson(recipeName)
    for y, xLayer in ipairs(recipe) do
        -- 遍历x层
        for x, zLayer in ipairs(xLayer) do
            -- 遍历z层
            for z, block in ipairs(zLayer) do
                process_cell_content(x, y, z, block)
            end
        end
    end

    if catalyst then
        local upSteps = 7 - craftingPos.y
        -- 向上移动指定格数
        robotLib.move(sides.top, upSteps)
        -- 丢下催化剂
        for catalystSlot = 1, robotLib.getInternalInventorySize() do
            local catalystStack = robotLib.getStackInInternalSlot(catalystSlot)
            if catalystStack and catalystStack.name == catalyst.name and catalystStack.damage == catalyst.damage then
                robotLib.select(catalystSlot)
                robotLib.dropDown()
                break
            end
        end
    end
    rs.setOutput(sides.bottom, 0)
end



return {
    processRecipe = processRecipe,
    makePaste = makePaste
}
