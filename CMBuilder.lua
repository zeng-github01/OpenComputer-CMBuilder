local robotLib = require("robotLib")
local recipe = require("Recipe")
local sides = require("sides")
local component = require("component")
local event = require("event")
local thread = require("thread")
local rs = component.redstone
local keyboard = component.keyboard
local enabled = true

-- 创建一个新的线程来监听键盘事件
local function listenForKeyboard()
    while true do
        local name, address, char, key, player = event.pull("key_down")
        if (key == keyboard.keys.q) then
            break
        end
        os.sleep(0.1)
    end
end

-- 启动键盘监听线程
local keybordThread = thread.create(listenForKeyboard)

-- 检查是否有红石信号
local craftingThread = thread.create(function()
    while enabled do
        if rs.getInput(sides.right) > 0 then
            -- 移动到原材料存放容器
            robotLib.move(sides.top)
            robotLib.move(sides.right, 2)

            -- 对容器和机器人背包的插槽数取最小值
            local minSlots = math.min(robotLib.getInventorySize(sides.bottom), robotLib.getInternalInventorySize())

            -- 取出容器内的物品到机器人背包
            for i = 1, minSlots do
                if robotLib.getStackInInternalSlot(i) == nil and robotLib.getStackInSlot(sides.bottom, i) ~= nil then
                    robotLib.select(i)
                    robotLib.suckFromSlot(sides.bottom, i)
                else
                    break
                end
            end

               local recipeName = recipe.matchRecipe()

            if recipeName ~= nil then
                -- 移动到工作区域的起始点
                robotLib.move(sides.left, 6)
                robotLib.move(sides.front, 5)
                robotLib.move(sides.top)
            else
                enabled = false
            end

            -- recipe.initCrafting(robotLib.pos)
            -- recipe.processRecipe()
            print(recipeName)
            if recipeName == "wallbreakable#0" then
                if robotLib.selectItem("minecraft:iron_block") then
                    robotLib.placeDown()
                    robotLib.move(sides.top)
                end

                if robotLib.selectItem("minecraft:redstone") then
                    robotLib.placeDown()
                end

                robotLib.move(sides.top, 5)
                robotLib.dropDown(1)
            end

            -------------------

            if recipeName == "tunneltool#0" then
                robotLib.move(sides.right, 2)
                robotLib.move(sides.front, 2)
                if robotLib.selectItem("compactmachines3:wallbreakable") then
                    robotLib.placeDown()
                end

                if robotLib.selectItem("minecraft:redstone") then
                    robotLib.move(sides.back, 1)
                    robotLib.placeDown()
                    robotLib.move(sides.left, 1)
                    robotLib.placeDown()
                    robotLib.move(sides.right, 2)
                    robotLib.placeDown()
                    for i = 1, 2 do
                        robotLib.move(sides.front)
                        robotLib.placeDown()
                    end
                    for i = 1, 2 do
                        robotLib.move(sides.left)
                        robotLib.placeDown()
                    end

                    robotLib.move(sides.back)
                    robotLib.placeDown()
                end

                robotLib.move(sides.top)
                robotLib.move(sides.right)

                if robotLib.selectItem("minecraft:hopper") then
                    rs.setOutput(sides.bottom,10)
                    robotLib.placeDown()
                end

                robotLib.move(sides.top, 5)
                rs.setOutput(sides.bottom,0)
                if robotLib.selectItem("minecraft:redstone") then
                    robotLib.dropDown(1)
                end
                -- if外层
            end

            if recipeName == "redstonetunneltool#0" then
                robotLib.move(sides.right, 2)
                robotLib.move(sides.front, 2)
                if robotLib.selectItem("compactmachines3:wallbreakable") then
                    robotLib.placeDown()
                end

                if robotLib.selectItem("minecraft:redstone") then
                    robotLib.move(sides.back, 1)
                    robotLib.placeDown()
                    robotLib.move(sides.left, 1)
                    robotLib.placeDown()
                    robotLib.move(sides.right, 2)
                    robotLib.placeDown()
                    for i = 1, 2 do
                        robotLib.move(sides.front)
                        robotLib.placeDown()
                    end
                    for i = 1, 2 do
                        robotLib.move(sides.left)
                        robotLib.placeDown()
                    end

                    robotLib.move(sides.back)
                    robotLib.placeDown()
                end

                robotLib.move(sides.top)
                robotLib.move(sides.right)

                if robotLib.selectItem("minecraft:redstone_block") then
                    robotLib.placeDown()
                end

                robotLib.move(sides.top, 5)
                if robotLib.selectItem("minecraft:redstone") then
                    robotLib.dropDown(1)
                end
                -- if外层
            end

            if recipeName == "machine#0" then
                --
            end

            if recipeName == "machine#5" then
                if robotLib.selectItem("compactmachines3:wallbreakable") then
                    robotLib.placeDown()
                    for i = 1, 4 do
                        robotLib.move(sides.right, 1)
                        robotLib.placeDown()
                    end

                    for i = 1, 4 do
                        robotLib.move(sides.front)
                        robotLib.placeDown()
                    end

                    for i = 1, 4 do
                        robotLib.move(sides.left)
                        robotLib.placeDown()
                    end

                    for i = 1, 3 do
                        robotLib.move(sides.back)
                        robotLib.placeDown()
                    end

                    for i = 1, 3 do
                        robotLib.move(sides.right)
                        robotLib.placeDown()
                    end

                    for i = 1, 2 do
                        robotLib.move(sides.front)
                        robotLib.placeDown()
                    end

                    for i = 1, 2 do
                        robotLib.move(sides.left)
                        robotLib.placeDown()
                    end

                    robotLib.move(sides.back)
                    robotLib.placeDown()
                    robotLib.move(sides.right)
                    robotLib.placeDown()
                end
                --if外层
            end

            -- 回到原点
            robotLib.restPosition()

            -- 等待3秒钟
            os.sleep(3)
        end
        os.sleep(0.05)
        ::continue::
    end
end)

thread.waitForAny({ keybordThread })
