--- vector3.lua
--- 3D 向量/坐标工具库
---@class Vector3
local Vector3 = {}
Vector3.__index = Vector3

--- 构造一个新的三维向量
---@param x number
---@param y number
---@param z number
---@return Vector3
function Vector3.new(x, y, z)
  return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, Vector3)
end

--- 克隆当前向量
---@return Vector3
function Vector3:copy()
  return Vector3.new(self.x, self.y, self.z)
end

--- 向量加法
---@param other Vector3
---@return Vector3
function Vector3:__add(other)
  return Vector3.new(self.x + other.x, self.y + other.y, self.z + other.z)
end

--- 向量减法
---@param other Vector3
---@return Vector3
function Vector3:__sub(other)
  return Vector3.new(self.x - other.x, self.y - other.y, self.z - other.z)
end

--- 向量与标量或向量点乘／缩放
---@param other number|Vector3
---@return Vector3|number
function Vector3:__mul(other)
  if type(other) == "number" then
    return Vector3.new(self.x * other, self.y * other, self.z * other)
  else
    -- 向量点乘
    return self.x * other.x + self.y * other.y + self.z * other.z
  end
end

--- 向量除以标量
---@param s number
---@return Vector3
function Vector3:__div(s)
  return Vector3.new(self.x / s, self.y / s, self.z / s)
end

--- 判断向量相等（分量相等）
---@param other Vector3
---@return boolean
function Vector3:__eq(other)
  return self.x == other.x and self.y == other.y and self.z == other.z
end

--- 向量转为字符串
---@return string
function Vector3:__tostring()
  return string.format("(%g, %g, %g)", self.x, self.y, self.z)
end

--- 计算向量长度（模）
---@return number
function Vector3:length()
  return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

--- 计算向量长度的平方（避免开方）
---@return number
function Vector3:lengthSquared()
  return self.x * self.x + self.y * self.y + self.z * self.z
end

--- 归一化向量（长度为 1）
---@return Vector3
function Vector3:normalize()
  local len = self:length()
  if len == 0 then return Vector3.new(0, 0, 0) end
  return self / len
end

--- 点乘
---@param other Vector3
---@return number
function Vector3:dot(other)
  return self.x * other.x + self.y * other.y + self.z * other.z
end

--- 叉乘
---@param other Vector3
---@return Vector3
function Vector3:cross(other)
  return Vector3.new(
    self.y * other.z - self.z * other.y,
    self.z * other.x - self.x * other.z,
    self.x * other.y - self.y * other.x
  )
end

--- 线性插值
---@param other Vector3
---@param t number [0,1]
---@return Vector3
function Vector3:lerp(other, t)
  return Vector3.new(
    self.x + (other.x - self.x) * t,
    self.y + (other.y - self.y) * t,
    self.z + (other.z - self.z) * t
  )
end

--- 两点距离
---@param other Vector3
---@return number
function Vector3:distanceTo(other)
  return (self - other):length()
end

--- 返回一个包含元方法的向量库
return setmetatable(
  { new = Vector3.new },
  { __call = function(_, ...) return Vector3.new(...) end }
)