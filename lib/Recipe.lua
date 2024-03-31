local component = require("component")
local database = component.database
local robotLib = require("robotLib")

-- 从数据库中获取合成表信息，跳过空的格子
local function getCraftingPattern(row)
    local materials = {}
    local catalyst
    local product
    for i = 1, 7 do -- 前7个格子是原材料
        local item = database.get(row * 9 - 9 + i)
        if item then -- 如果格子不为空，则添加到材料列表
            materials[i] = item
        end
    end
    catalyst = database.get(row * 9 - 9 + 8) -- 第8个格子是催化剂
    product = database.get(row * 9 - 9 + 9) -- 第9个格子是产物
    return materials, catalyst, product
end

-- 比对机器人内部物品堆栈与合成表
local function matchRecipe()
    for row = 1, 81 / 9 do -- 假设数据库每9个格子为一行
        local materials, catalyst, product = getCraftingPattern(row)
        local match = false
        for slot = 1, robotLib.getInternalInventorySize() do -- 遍历机器人的所有物品槽
            local stack = robotLib.getStackInInternalSlot(slot)
            if stack then -- 如果物品槽不为空
                local found = false
                for _, material in ipairs(materials) do
                    if stack.name == material.name then
                        found = true
                        break
                    end
                end
                if not found and catalyst and stack.name == catalyst.name then
                    found = true
                end
                if found then
                    match = true
                    break
                end
            end
        end
        if match then
            return product.label -- 返回匹配的合成表产物的标签
        end
    end
    return nil -- 没有匹配的合成表
end

return {
    matchRecipe = matchRecipe
}