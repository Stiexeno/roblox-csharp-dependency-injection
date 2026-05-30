-- Entry point for the DI plugin. Just exports the public surface —
-- there's no global state to bootstrap (the container is created by
-- the user's GameServer / GameClient), so this module has no side
-- effects.

return {
	Container = require(script.Container),
	Binder = require(script.Binder),
	Installer = require(script.Installer),
	IInitializable = require(script.IInitializable),
	IDisposable = require(script.IDisposable),
}
