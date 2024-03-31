local robotLib = require("robotLib")
local sides = require("sides")
local component = require("component")
local event = require("event")
local thread = require("thread")
local rs = component.redstone
local keyboard = component.keyboard

-- 创建一个新的线程来监听键盘事件
local function listenForKeyboard()
    while true do
        local _, _, _, code = event.pull("key_down")
        if code == keyboard.keys.q then
            os.exit()
        end
    end
end

-- 启动键盘监听线程
thread.create(listenForKeyboard)

-- 检查是否有红石信号
while true do
    if rs.getInput(sides.right) > 0 then
        -- 移动到原材料存放容器
        robotLib.move(sides.top)
        robotLib.move(sides.right)
        robotLib.move(sides.front)
        robotLib.move(sides.front)

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

        -- 移动到工作区域的起始点
        robotLib.move(sides.left)
        for i = 1, 5 do
            robotLib.move(sides.front)
        end
        robotLib.move(sides.left)
        robotLib.move(sides.front)
        robotLib.move(sides.front)
        robotLib.move(sides.top)

        -- 工作逻辑
        for i = 1, minSlots do
            local item = robotLib.getStackInInternalSlot(i)
            if item ~= nil then
                if item.name == "minecraft:iron_block" then
                    robotLib.select(i)
                    robotLib.placeDown()
                    robotLib.move(sides.top)
                    -- 找到红石粉并放置
                    for j = 1, minSlots do
                        local redstone = robotLib.getStackInInternalSlot(j)
                        if redstone ~= nil and redstone.name == "minecraft:redstone" then
                            robotLib.select(j)
                            robotLib.placeDown()
                            break
                        end
                    end
                    for j = 1, 5 do
                        robotLib.move(sides.top)
                    end
                    robotLib.dropDown(1)
                end
            else
                break
            end
        end

        -- 回到原点
        robotLib.restPosition()

        -- 等待10秒钟
        os.sleep(10)
    end
    os.sleep(0.05)
end