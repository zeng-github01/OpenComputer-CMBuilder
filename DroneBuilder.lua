--[[
    This file is part of OpenComputer-CMBuilder

    Test File: DroneBuilder.lua
    This file is used to control the drone to automatically craft items based on recipes.]]

local sides = require("sides")
local component = require("component")
local event = require("event")
local thread = require("thread")
local term = require("term")
local rs = component.redstone
local keyboard = require("keyboard")
local recipe = require("drone.Recipe")
local droneLib = require("drone.DroneLib")
local term = require("term")

-- 创建一个新的线程来监听键盘事件
local function listenForKeyboard()
    term.write("press 'q' to exit")
    while true do
        local _, _, _, key, _ = term.pull('key_down')
        if (key == keyboard.keys.q) then
            break
        end
        os.sleep(0.1)
    end
end

local function runCrafting()
    local address, port = droneLib.autoConnect(5)
    assert(address, "No drone found or connection failed.")
    while true do
        term.clear()
        if rs.getInput(sides.east) > 0 then
            print("Crafting started...")
            local jsonName, catalyst, product = recipe.matchRecipe(sides.up)

            if not jsonName then
                error("No matching recipe found.\n")
            end

            print("Recipe found: " .. jsonName)
            print("Catalyst: " .. (catalyst and catalyst.name or "None"))
            print("Product: " .. (product and product.name or "None"))

            local blueprint = recipe.readJson(jsonName) -- 读取配方json
            assert(blueprint, "Failed to read recipe JSON: " .. jsonName)

            -- 移动到原材料存放容器上方
            -- Moved above the raw material storage container
            local ok, err = droneLib.move(address, -2, 1, 0, true)
            if ok then
                print("Moved to the raw material storage container.")
            else
                error("Failed to move to the raw material storage container: " .. err)
            end

            droneLib.suck(address, sides.bottom)

            -- 移动到工作区域的起始点 一层左下角上方
            -- Move to the starting point of the crafting area, above the lower left corner of the first layer
            droneLib.move(address, 1, 0, 2, true)
            recipe.setMirror(-1, 1, -1)
            local success = recipe.processRecipe(address, blueprint, sides.bottom) -- 批量放置蓝图

            if success then
                -- 回到原点
                droneLib.home(address)
            end

            -- 等待3.5秒钟
            os.sleep(3.5)
        end
        os.sleep(0.05)
    end
end

-- 启动键盘监听线程
local keybordThread = thread.create(listenForKeyboard)

local craftingThread = thread.create(runCrafting)

thread.waitForAny({ keybordThread })
