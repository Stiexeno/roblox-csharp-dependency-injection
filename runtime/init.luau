-- Entry point for the DI plugin. Just exports the public surface —
-- there's no global state to bootstrap (the container is created by
-- the user's GameInstaller boot tail), so this module has no side
-- effects.
--
-- IInitializable isn't exported as a Lua artifact — interfaces in
-- roblox-csharp lower to string names at every reference site, so
-- there's nothing to import.

return {
	Container = require(script.Container),
	Binder = require(script.Binder),
	Instantiator = require(script.Instantiator),
	Installer = require(script.Installer),
	ServerInstaller = require(script.ServerInstaller),
	ClientInstaller = require(script.ClientInstaller),
}
