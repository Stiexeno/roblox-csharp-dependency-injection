-- Thin wrapper over Installer that exists so the compiler-emitted
-- script (a class inheriting `ServerInstaller`) has something concrete
-- to require. The boot mechanics live on the compiler side — this
-- class doesn't add any behavior of its own, it just inherits.
--
-- Why a separate class at all: the [Server] attribute on the C# stub
-- is what tells the compiler to output the user's derived class as a
-- `.server.luau`. Inheriting from this base is how the marker
-- propagates.

local Installer = require(script.Parent.Installer)

local ServerInstaller = setmetatable({}, {
	__tostring = function() return "ServerInstaller" end,
	__index = Installer,
})
ServerInstaller.__index = ServerInstaller

function ServerInstaller.new(...)
	local self = setmetatable({}, ServerInstaller)
	return self:constructor(...) or self
end

ServerInstaller.__ctorParams = {}
ServerInstaller.__interfaces = {}

function ServerInstaller:constructor(container)
	Installer.constructor(self, container)
end

return ServerInstaller
