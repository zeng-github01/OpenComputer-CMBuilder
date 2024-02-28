Pos = {x = 0, y = 0, z = 0}
PosLib = {}

Pos.__index = Pos

function Pos:new(...)
    local pos = {}
    local x , y , z
    setmetatable(pos, self)
    local arg = {...}
    if(#arg == 1 and type(arg[1]) == 'table') then
        x = arg[1].x
        y = arg[1].y
        z = arg[1].z
    elseif(#arg == 2 or #arg == 3) then
        if (type(arg[1]) == 'number' and type(arg[2]) == 'number') then
            x = arg[1]
            y = arg[2]
            if (type(arg[3]) == 'number' or type(arg[3]) == 'nil') then
                z = arg[3]
            else
                error('Invalid Input To New Pos')
            end
        end
    elseif(#arg ~= 0) then
        error('Invalid Input To New Pos')
    end
    pos.x = x or 0
    pos.y = y or 0
    pos.z = z or 0
    return pos
end

function Pos:set(...)
    local x , y , z
    local arg = {...}
    if(#arg == 1 and type(arg[1]) == 'table') then
        x = arg[1].x
        y = arg[1].y
        z = arg[1].z
    elseif(#arg == 2 or #arg == 3) then
        if (type(arg[1]) == 'number' and type(arg[2]) == 'number') then
            x = arg[1]
            y = arg[2]
            if (type(arg[3]) == 'number' or type(arg[3]) == 'nil') then
                z = arg[3]
            else
                error('Invalid Input To New Pos')
            end
        end
    elseif(#arg ~= 0) then
        error('Invalid Input To New Pos')
    end
    self.x = x or 0
    self.y = y or 0
    self.z = z or 0
    return self
end

function Pos:__call(...)
    return Pos:new(...)
end

function Pos:__tostring()
    return string.format('x: %d , y: %d , z: %d', self.x, self.y, self.z)
end

function Pos:__add(pos)
    local pos_out = Pos:new(self)
    pos_out.x = pos_out.x + pos.x
    pos_out.y = pos_out.y + pos.y
    pos_out.z = pos_out.z + pos.z
    return pos_out
end

function Pos:__sub(pos)
    local pos_out = Pos:new(self)
    pos_out.x = pos_out.x - pos.x
    pos_out.y = pos_out.y - pos.y
    pos_out.z = pos_out.z - pos.z
    return pos_out
end

function Pos:__eq(pos)
    local x_eq = self.x == pos.x
    local y_eq = self.y == pos.y
    local z_eq = self.z == pos.z
    return x_eq and y_eq and z_eq
end

function Pos:__le(pos)
    local x_le = self.x <= pos.x
    local y_le = self.y <= pos.y
    local z_le = self.z <= pos.z
    return x_le and y_le and z_le
end

function Pos:__lt(pos)
    return not (self >= pos)
end

function Pos:eqXY(x, y)
    return self.x == x and self.y == y
end

function Pos:large(pos)
    self.x = math.max(self.x , pos.x)
    self.y = math.max(self.y , pos.y)
    self.z = math.max(self.z , pos.z)
    return self
end

function Pos:larger(pos)
    local x = math.max(self.x , pos.x)
    local y = math.max(self.y , pos.y)
    local z = math.max(self.z , pos.z)
    return Pos:new(x,y,z)
end

function Pos:small(pos)
    self.x = math.min(self.x , pos.x)
    self.y = math.min(self.y , pos.y)
    self.z = math.min(self.z , pos.z)
    return self
end

function Pos:smaller(pos)
    local x = math.min(self.x , pos.x)
    local y = math.min(self.y , pos.y)
    local z = math.min(self.z , pos.z)
    return Pos:new(x,y,z)
end

function Pos:rotate(right)
    if right == nil then
        right = true
    end
    local angle
    if right then
        angle = math.rad(90)
    else
        angle = math.rad(-90)
    end
    local sin = math.sin(angle)
    local cos = math.cos(angle)
    local x = self.x * cos - self.y * sin
    local y = self.y * cos + self.x * sin
    if math.abs(x) < 1e-8 then
        x = 0
    end
    if math.abs(y) < 1e-8 then
        y = 0
    end
    return Pos:new(x, y, self.z)
end

local function sym(x)
    if (x == 0) then
        return 0
    else
        return x / math.abs(x)
    end
end

function Pos:mod()
    local x = sym(self.x)
    local y = sym(self.y)
    local z = sym(self.z)
    return Pos:new(x, y, z)
end

function Pos:inArea(posA , posB)
    local larger = self <= posA:larger(posB)
    local smaller = self >= posA:smaller(posB)
    return larger and smaller
end

setmetatable(PosLib , Pos)

return PosLib