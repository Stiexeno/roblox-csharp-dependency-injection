-- Constructs arbitrary classes with DI-resolved ctor args. Mirrors
-- what Binder._construct does, but operates on UNBOUND types — the
-- caller owns the lifetime. Used by transient creation paths
-- (state-machine state factories, per-request worker pools, …)
-- where you don't want N separate Bind lines for N near-identical
-- classes.
--
-- The ctor params themselves DO go through the container's normal
-- Resolve, so any services those classes need still resolve through
-- their registered bindings — only the target class is transient.

local Instantiator = setmetatable({}, {
	__tostring = function() return "Instantiator" end,
})
Instantiator.__index = Instantiator

Instantiator.__ctorParams = {}
Instantiator.__interfaces = { "IInstantiator" }

function Instantiator.new(container)
	local self = setmetatable({}, Instantiator)
	self._container = container
	return self
end

-- `Instantiate<T>()` lowers to `Instantiate(targetClass)`. Walks the
-- target's compiler-emitted __ctorParams and resolves each through
-- the container, then calls the target's standard .new(...) factory.
function Instantiator:Instantiate(targetClass)
	local params = rawget(targetClass, "__ctorParams") or {}
	if #params == 0 then
		return targetClass.new()
	end
	local args = {}
	for i, paramType in ipairs(params) do
		args[i] = self._container:Resolve(paramType)
	end
	return targetClass.new(table.unpack(args))
end

return Instantiator
