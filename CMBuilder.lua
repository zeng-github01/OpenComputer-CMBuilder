local robotLib = require("robotLib")
local sides = require("sides")
local component = require("component")
local event = require("event")
local thread = require("thread")
local term = require("term")
local rs = component.redstone
local keyboard = require("keyboard")
local recipe = require("Recipe")
local sides = require("sides")

-- 创建一个新的线程来监听键盘事件
local function listenForKeyboard()
    while true do
        local name, address, char, key, player = term.pull('key_down')
        if (key == keyboard.keys.q) then
            break
        end
        os.sleep(0.1)
    end
end

local function runCrafting()
    while true do
        if rs.getInput(sides.right) > 0 then
            -- 移动到原材料存放容器上方
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

            -- 移动到工作区域的起始点 一层左下角
            robotLib.move(sides.left, 6)
            robotLib.move(sides.front, 5)
            robotLib.move(sides.top)

            recipe.processRecipe()

            -- 回到原点
            robotLib.resetPosition()

            -- 等待3.5秒钟
            os.sleep(3.5)
        end
        os.sleep(0.05)
    end
end



--启动合成线程
local craftingThread = thread.create(runCrafting)

-- 启动键盘监听线程
local keybordThread = thread.create(listenForKeyboard)

thread.waitForAny({keybordThread})
os.exit(0)