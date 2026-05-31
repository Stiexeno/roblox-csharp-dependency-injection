-- DI container. Holds bindings (key -> Binder) and singleton cache,
-- resolves dependencies through the compiler-emitted __ctorParams
-- metadata that lives on every class table.
--
-- API matches Zenject as closely as the platform allows: Bind /
-- BindInterfacesTo / BindInterfacesAndSelfTo, fluent .To / .FromInstance
-- / .AsSingle / .AsTransient on the returned Binder, Resolve<T>(),
-- Install<T>(), Bootstrap() to fire IInitializable lifecycles.

local Binder = require(script.Parent.Binder)
local Instantiator = require(script.Parent.Instantiator)

-- Interfaces have no runtime artifact in roblox-csharp — they're
-- identified by their simple name as a string at every reference
-- site. Hardcoding the literal here keeps Container's lifecycle
-- check (`if implements IInitializable then Initialize()`) aligned
-- with what user classes get for their `__interfaces` table.
local IInitializable = "IInitializable"

local Container = {}
Container.__index = Container

function Container.new()
	local self = setmetatable({}, Container)
	self._bindings = {}     -- [typeKey] = Binder
	self._singletons = {}   -- [implType] = constructed singleton (lazy cache)
	-- Stack of keys currently mid-resolve. Pushed on Resolve entry,
	-- popped on exit. Used for two diagnostics:
	--   - cycle detection (same key appears twice while resolving)
	--   - unbound errors (show the chain that led to the failure)
	self._resolveStack = {}
	-- Self-bind so any service that takes Container as a ctor param
	-- (StateFactory, ComponentsService, plugin-provided service
	-- factories) resolves cleanly instead of hitting "no binding
	-- registered". FromInstance bypasses ctor resolution so this is
	-- safe even before the user's bindings land.
	Binder.new(self, { Container }):FromInstance(self):AsSingle()
	-- Auto-bind the Instantiator under its interface so user code
	-- can `IInstantiator instantiator` ctor-inject without an
	-- explicit Bind in their installer. Same Zenject convention —
	-- the container ships an instantiator as a built-in service.
	Binder.new(self, { "IInstantiator" }):FromInstance(Instantiator.new(self)):AsSingle()
	return self
end

-- `Bind<T>()` lowers via [Reified] to `Bind(T)`. T arrives as the
-- class / interface table the user wants to register against.
function Container:Bind(typeKey)
	return Binder.new(self, { typeKey })
end

-- `BindInterfacesTo<T>()` walks T's interface set (including inherited)
-- and registers the binding under each. Matches Zenject's behavior of
-- spraying a single impl across every contract it satisfies.
function Container:BindInterfacesTo(implType)
	local interfaces = self:_collectInterfaces(implType)
	if #interfaces == 0 then
		warn(string.format(
			"[DI] BindInterfacesTo: %s declares no interfaces; binding to self",
			tostring(implType)))
		return Binder.new(self, { implType }):To(implType)
	end
	return Binder.new(self, interfaces):To(implType)
end

-- `BindInterfacesAndSelfTo<T>()` — also registers the binding under
-- T itself, on top of every declared interface. Useful for concrete
-- types you also want to Resolve directly.
function Container:BindInterfacesAndSelfTo(implType)
	local keys = { implType }
	for _, iface in ipairs(self:_collectInterfaces(implType)) do
		table.insert(keys, iface)
	end
	return Binder.new(self, keys):To(implType)
end

-- `Install<T>()` constructs the installer with the container itself
-- as the argument and invokes InstallBindings. This deliberately
-- bypasses normal DI resolution — installers are part of the
-- bootstrap, not application services, so they don't go through Bind.
function Container:Install(installerType)
	local installer = installerType.new(self)
	installer:InstallBindings()
end

-- `Resolve<T>()` returns an instance for the bound key. Errors when
-- nothing is bound, when a binding's construction throws, or when
-- the request would close a circular-dependency loop. The error
-- messages include the active resolve chain so debugging deep DI
-- graphs doesn't require staring at line-numbered traces.
function Container:Resolve(typeKey)
	-- Cycle check first — has to fire before we even look at the
	-- binding, otherwise a binding that hasn't yet cached its
	-- singleton would just recurse and stack-overflow.
	for i, inProgress in ipairs(self._resolveStack) do
		if inProgress == typeKey then
			error(string.format("[DI] Circular dependency: %s",
				self:_formatCycle(i, typeKey)), 2)
		end
	end

	local binding = self._bindings[typeKey]
	if binding == nil then
		error(string.format("[DI] No binding registered for %s%s",
			tostring(typeKey), self:_formatChain()), 2)
	end

	table.insert(self._resolveStack, typeKey)
	local ok, result = pcall(binding._provide, binding, self)
	table.remove(self._resolveStack)

	if not ok then
		-- Re-raise the inner error verbatim. Level 0 keeps Luau from
		-- prepending another file:line to a message that already has
		-- one (or that we built deliberately above).
		error(result, 0)
	end
	return result
end

-- Renders the chain that led to the current Resolve call as an
-- arrow-joined string. Returns an empty string when the stack is
-- empty (i.e., this is the user's top-level Resolve), so callers
-- can blindly concatenate without conditionals.
function Container:_formatChain()
	if #self._resolveStack == 0 then return "" end
	local parts = {}
	for _, t in ipairs(self._resolveStack) do
		table.insert(parts, tostring(t))
	end
	return " (resolving: " .. table.concat(parts, " -> ") .. ")"
end

-- Builds the cycle path from the position where the duplicate was
-- found to the end of the stack, then back to the duplicate to
-- close the loop visually: `A -> B -> C -> A`.
function Container:_formatCycle(firstIndex, repeatedKey)
	local parts = {}
	for i = firstIndex, #self._resolveStack do
		table.insert(parts, tostring(self._resolveStack[i]))
	end
	table.insert(parts, tostring(repeatedKey))
	return table.concat(parts, " -> ")
end

-- Walks every registered binding once; for each unique impl whose
-- interface set includes IInitializable, resolves it (which seeds the
-- singleton cache if AsSingle was used) and calls Initialize().
--
-- Idempotent in the singleton case — re-running Bootstrap re-uses
-- cached instances rather than re-initializing them. Transient
-- bindings would re-initialize on every Bootstrap; users should
-- mark IInitializable services AsSingle.
function Container:Bootstrap()
	local seen = {}
	for _, binding in pairs(self._bindings) do
		local impl = binding._implType
		if impl ~= nil and not seen[impl] then
			seen[impl] = true
			if self:_implementsInterface(impl, IInitializable) then
				local instance = binding:_provide(self)
				if instance.Initialize then
					instance:Initialize()
				end
			end
		end
	end
end

-- Collects every interface declared on `implType` and on its base
-- classes. Walks the metatable chain — same shape the class scaffold
-- uses for method inheritance, so a derived class picks up its
-- parents' interfaces automatically.
function Container:_collectInterfaces(implType)
	local result = {}
	local seen = {}
	local current = implType
	while current ~= nil do
		local interfaces = rawget(current, "__interfaces")
		if interfaces then
			for _, iface in ipairs(interfaces) do
				if not seen[iface] then
					seen[iface] = true
					table.insert(result, iface)
				end
			end
		end
		local mt = getmetatable(current)
		current = mt and mt.__index or nil
	end
	return result
end

function Container:_implementsInterface(implType, interfaceType)
	for _, iface in ipairs(self:_collectInterfaces(implType)) do
		if iface == interfaceType then return true end
	end
	return false
end

-- Internal hook the Binder calls during .AsSingle/.AsTransient. Kept
-- separate so the Binder doesn't poke at `_bindings` directly.
function Container:_addBinding(typeKey, binding)
	if self._bindings[typeKey] ~= nil then
		warn(string.format(
			"[DI] Re-binding %s — previous binding will be overwritten",
			tostring(typeKey)))
	end
	self._bindings[typeKey] = binding
end

return Container
