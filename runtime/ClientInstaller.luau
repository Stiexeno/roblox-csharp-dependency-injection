-- Mirror of ServerInstaller for client-side bootstrap. See its
-- comments for the full rationale. Only difference: the [Client]
-- attribute on the C# stub triggers a `.client.luau` output instead
-- of `.server.luau`.

local Installer = require(script.Parent.Installer)

local ClientInstaller = setmetatable({}, {
	__tostring = function() return "ClientInstaller" end,
	__index = Installer,
})
ClientInstaller.__index = ClientInstaller

function ClientInstaller.new(...)
	local self = setmetatable({}, ClientInstaller)
	return self:constructor(...) or self
end

ClientInstaller.__ctorParams = {}
ClientInstaller.__interfaces = {}

function ClientInstaller:constructor(container)
	Installer.constructor(self, container)
end

return ClientInstaller
