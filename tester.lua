local robotLib = require("robotLib")
local recipe = require("Recipe")
local sides = require("sides")
local component = require("component")
local event = require("event")
local thread = require("thread")
local rs = component.redstone
local keyboard = component.keyboard
local recipe = require("Recipe")

-- 创建一个新的线程来监听键盘事件
local function listenForKeyboard()
    while true do
        local name,address,char,key,player= event.pull("key_down")
        if (key == keyboard.keys.q) then
           break
        end
        os.sleep(0.1)
    end
end

-- 启动键盘监听线程
local keybordThread = thread.create(listenForKeyboard)

-- 检查是否有红石信号
local craftingThread = thread.create(function ()
    while true do
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
    
            -- print(recipe.matchRecipe())
    
            -- 移动到工作区域的起始点
            robotLib.move(sides.left, 6)
            robotLib.move(sides.front, 5)
            robotLib.move(sides.top)
    
            recipe.initCrafting(robotLib.pos)
            recipe.processRecipe()
    
            -- 回到原点
            robotLib.restPosition()
    
            -- 等待3秒钟
            os.sleep(3)
        end
        os.sleep(0.05)
    end
end)

thread.waitForAny({keybordThread})