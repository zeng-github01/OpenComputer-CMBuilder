local robot = require("robot")
local sides = require("sides")

-- 三维坐标对象
local Pos3D = {}
Pos3D.__index = Pos3D

function Pos3D:new(x, y, z)
    local obj = setmetatable({}, self)
    obj.x = x or 0
    obj.y = y or 0
    obj.z = z or 0
    return obj
end

function Pos3D:__eq(other)
    return self.x == other.x and self.y == other.y and self.z == other.z
end

function Pos3D:copy()
    return Pos3D:new(self.x, self.y, self.z)
end

function Pos3D:neighbors()
    -- 返回六个方向的相邻坐标
    return {
        Pos3D:new(self.x + 1, self.y, self.z),
        Pos3D:new(self.x - 1, self.y, self.z),
        Pos3D:new(self.x, self.y + 1, self.z),
        Pos3D:new(self.x, self.y - 1, self.z),
        Pos3D:new(self.x, self.y, self.z + 1),
        Pos3D:new(self.x, self.y, self.z - 1)
    }
end

function Pos3D:distance(other)
    -- 曼哈顿距离
    return math.abs(self.x - other.x) + math.abs(self.y - other.y) + math.abs(self.z - other.z)
end

-- 检查当前位置到目标位置的方向和障碍
local function detectObstacle(from, to)
    if to.x > from.x then
        return robot.detect(sides.front)
    elseif to.x < from.x then
        return robot.detect(sides.back)
    elseif to.y > from.y then
        return robot.detectUp()
    elseif to.y < from.y then
        return robot.detectDown()
    elseif to.z > from.z then
        return robot.detect(sides.right)
    elseif to.z < from.z then
        return robot.detect(sides.left)
    end
    return false
end

-- A*寻路算法
local function astar(startPos, endPos, isBlocked)
    local openSet = {[startPos.x .. "," .. startPos.y .. "," .. startPos.z] = startPos}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end

    gScore[key(startPos)] = 0
    fScore[key(startPos)] = startPos:distance(endPos)

    while next(openSet) do
        -- 取fScore最小的节点
        local current, currentKey
        for k, pos in pairs(openSet) do
            if not current or fScore[k] < fScore[currentKey] then
                current = pos
                currentKey = k
            end
        end

        if current == endPos then
            -- 回溯路径
            local path = {current}
            while cameFrom[key(current)] do
                current = cameFrom[key(current)]
                table.insert(path, 1, current)
            end
            return path
        end

        openSet[currentKey] = nil
        for _, neighbor in ipairs(current:neighbors()) do
            if not isBlocked(current, neighbor) then
                local neighborKey = key(neighbor)
                local tentative_gScore = gScore[currentKey] + 1
                if not gScore[neighborKey] or tentative_gScore < gScore[neighborKey] then
                    cameFrom[neighborKey] = current
                    gScore[neighborKey] = tentative_gScore
                    fScore[neighborKey] = tentative_gScore + neighbor:distance(endPos)
                    if not openSet[neighborKey] then
                        openSet[neighborKey] = neighbor
                    end
                end
            end
        end
    end
    return nil -- 无法到达
end

-- 用于OpenComputer的障碍检测
local function isBlocked(from, to)
    return detectObstacle(from, to)
end

return {
    Pos3D = Pos3D,
    astar = function(startPos, endPos)
        return astar(startPos, endPos, isBlocked)
    end
}