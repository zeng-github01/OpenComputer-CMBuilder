local sides = require("sides")
local component = require("component")
local event = require("event")
local thread = require("thread")
local term = require("term")
local rs = component.redstone
local keyboard = require("keyboard")
local recipe = require("drone.DroneRecipe")
local droneLib = require("drone.DroneLib")
local term = require("term")

local function listenForKeyboard()
    while true do
        local _, _, _, key, _ = term.pull('key_down')
        if (key == keyboard.keys.q) then
            break
        end
        os.sleep(0.1)
    end
end

local function runCrafting(address)
    local function drawFrame()
        term.clear()
        term.setCursor(1, 1)
        print("+--------------------------------------+")
        print("| CMBuilder: Drone Edition             |")
        print("| Press 'q' to exit                    |")
        print("+--------------------------------------+")
    end

    local function drawStatus(line, msg)
        term.setCursor(2, line)
        term.write(msg)
    end

    while true do
        drawFrame()

        if rs.getInput(sides.east) > 0 then
            drawStatus(5, "Crafting triggered...")

            local jsonName, catalyst, product = recipe.matchRecipe(sides.up)
            if not jsonName then
                drawStatus(7, "No matching recipe found.")
                os.sleep(0.1)
                goto continue
            end

            drawStatus(6, "Recipe: " .. jsonName)
            drawStatus(7, "Catalyst: " .. (catalyst and catalyst.name or "None"))
            drawStatus(8, "Product:  " .. (product and product.name or "None"))

            local blueprint = recipe.readJson(jsonName)
            if not blueprint then
                drawStatus(10, "Failed to read recipe JSON.")
                os.sleep(0.1)
                goto continue
            end

            local ok, err = droneLib.move(address, -2, 1, 0, true)
            if ok then
                drawStatus(10, "Moved to raw material container.")
            else
                drawStatus(10, "Move failed: " .. err)
                os.sleep(0.1)
                goto continue
            end

            ok, err = droneLib.suck(address, sides.bottom)
            if not ok then
                drawStatus(11, "Suck failed: " .. err)
                os.sleep(0.1)
                goto continue
            end

            ok, err = droneLib.move(address, 1, 0, 2)
            if ok then
                drawStatus(12, "Moved to crafting area.")
            else
                drawStatus(12, "Move failed: " .. err)
                os.sleep(0.1)
                goto continue
            end

            recipe.setMirror(-1, 1, -1)
            local success = recipe.processRecipe(address, blueprint, sides.bottom)
            if success then
                drawStatus(13, "Recipe processed successfully.")
                ok, err = droneLib.home(address)
                if ok then
                    -- drop catalyst
                    -- find nearest Dropper or Dispenser by yourself
                    -- drone can't drop items directly
                    ok, err = droneLib.move(address, 1, 1, 2)
                    if ok then
                        drawStatus(14, "Moved to dropper/dispenser.")
                    else
                        drawStatus(14, "Move to dropper/dispenser failed: " .. err)
                        os.sleep(0.1)
                        goto continue
                    end

                    ok, err = droneLib.dropName(address, catalyst.name, catalyst.damage, sides.bottom, 1, true)
                    if ok then
                        drawStatus(15, "Catalyst dropped.")
                        drawStatus(16, "Returning home...")
                        droneLib.home(address)
                    else
                        drawStatus(15, "Drop failed: " .. err)
                        os.sleep(1)
                        goto continue
                    end
                end
            else
                drawStatus(13, "Recipe processing failed.")
                os.sleep(1)
            end
        end

        ::continue::
        droneLib.home(address)
        os.sleep(0.05)
    end
end

local address, port = droneLib.autoConnect(5)
assert(address, "No drone found or connection failed.")

local keybordThread = thread.create(listenForKeyboard)

local craftingThread = thread.create(runCrafting, address)

thread.waitForAny({ keybordThread, craftingThread })

droneLib.home(address)
print("Exiting DroneBuilder...")

os.exit(0)
