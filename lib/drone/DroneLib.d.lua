---@meta

--- DroneLib – Remote drone command library (patched version)
---
--- Provides high-level functions to control drones via wireless modem messaging.
--- Handles command dispatching, sequence tracking, retries, and acknowledgment filtering.
--- All commands are sent via port `4711` and tagged for deduplication.
---@class DroneLib
local DroneLib = {}

--- Attempts to auto-connect to a nearby drone by broadcasting a ping.
--- Waits for an acknowledgment within the specified timeout.
---@param timeout number? Timeout in seconds (default = 5)
---@return string address Drone address
---@return number port Port used (always 4711)
function DroneLib.autoConnect(timeout) end

--- Sends a movement command to the drone.
---@param addr string Drone address
---@param x number X offset
---@param y number Y offset
---@param z number Z offset
---@param enableRetry boolean? Whether to retry on timeout
---@return boolean success
---@return string? errorMessage
function DroneLib.move(addr, x, y, z, enableRetry) end

--- Places an item by name from the drone's inventory.
---@param addr string Drone address
---@param itemName string Item ID (e.g. "minecraft:stone")
---@param damage number Metadata/damage value
---@param side number Placement side
---@param enableRetry boolean? Retry on failure
---@return boolean success
---@return string? errorMessage
function DroneLib.placeName(addr, itemName, damage, side, enableRetry) end

--- Places an item from a specific inventory slot.
---@param addr string Drone address
---@param slot number Inventory slot index
---@param side number Placement side
---@param enableRetry boolean? Retry on failure
---@return boolean success
---@return string? errorMessage
function DroneLib.placeSlot(addr, slot, side, enableRetry) end

--- Drops items from a specific slot.
---@param addr string Drone address
---@param slot number Inventory slot
---@param side number Drop direction
---@param n number? Quantity to drop (default = 1)
---@param enableRetry boolean? Retry on failure
---@return boolean success
---@return string? errorMessage
function DroneLib.dropSlot(addr, slot, side, n, enableRetry) end

--- Drops items by name from inventory.
---@param addr string Drone address
---@param itemName string Item ID
---@param damage number Metadata/damage
---@param side number Drop direction
---@param n number? Quantity to drop (default = 1)
---@param enableRetry boolean? Retry on failure
---@return boolean success
---@return string? errorMessage
function DroneLib.dropName(addr, itemName, damage, side, n, enableRetry) end

--- Commands the drone to suck items from the specified side.
---@param addr string Drone address
---@param side number Direction to suck from
---@param enableRetry boolean? Retry on failure
---@return boolean success
---@return string? errorMessage
function DroneLib.suck(addr, side, enableRetry) end

--- Sends the drone to its home position.
---@param addr string Drone address
---@param enableRetry boolean? Retry on failure
---@return boolean success
---@return string? errorMessage
function DroneLib.home(addr, enableRetry) end

--- Pings the drone to check connectivity.
---@param addr string Drone address
---@param enableRetry boolean? Retry on failure
---@return boolean success
---@return string? errorMessage
function DroneLib.ping(addr, enableRetry) end

--- Sends a shutdown command to the drone.
---@param addr string Drone address
---@param enableRetry boolean? Retry on failure
---@return boolean success
---@return string? message "Shutdown command sent" or error
function DroneLib.shutdown(addr, enableRetry) end

--- Resets the sequence map and notifies the drone to reset its sequence counter.
---@param addr string Drone address
---@param enableRetry boolean? Retry on failure
function DroneLib.resetSeq(addr, enableRetry) end

return DroneLib