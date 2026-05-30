-- Base class for user-written installers. Subclasses override
-- InstallBindings; the container's Install<T>() constructs them with
-- the container passed in and invokes that override.
--
-- Shape matches our compiler-emitted class scaffold so derived classes
-- (compiled from user C#) can `Installer.constructor(self, container)`
-- from their base-call chain without any special-casing.

local Installer = {}
Installer.__index = Installer

setmetatable(Installer, {
	__tostring = function() return "Installer" end,
})

function Installer.new(...)
	local self = setmetatable({}, Installer)
	return self:constructor(...) or self
end

-- __ctorParams stays empty: Installer is constructed by
-- Container.Install with the container handed in directly, not
-- resolved through DI. (DI resolving the container would be a
-- self-reference loop.)
Installer.__ctorParams = {}
Installer.__interfaces = {}

function Installer:constructor(container)
	self.Container = container
end

function Installer:InstallBindings()
	error("[DI] Installer subclasses must override InstallBindings", 2)
end

return Installer
