local component = require("component")
local navigation = component.navigation
local str = "robot facing: %s"
print(string.format(str,navigation.getFacing()))