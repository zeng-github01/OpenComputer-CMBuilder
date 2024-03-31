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
        local materialMatches = {} -- 用于跟踪每种材料是否匹配

        -- 初始化材料匹配跟踪表
        for i = 1, #materials do
            materialMatches[i] = false
        end

        -- 遍历机器人的所有物品槽
        for slot = 1, robotLib.getInternalInventorySize() do
            local stack = robotLib.getStackInInternalSlot(slot)
            if stack then -- 如果物品槽不为空
                for i, material in ipairs(materials) do
                    if stack.name == material.name and (material.damage == nil or stack.damage == material.damage) then
                        materialMatches[i] = true -- 标记找到匹配的材料
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
            return itemName .. "#" .. (product.damage or "") -- 返回匹配的合成表产物的ID和damage值
        end
    end
    return nil -- 没有匹配的合成表
end

return {
    matchRecipe = matchRecipe
}