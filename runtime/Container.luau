-- DI container. Holds bindings (key -> Binder) and singleton cache,
-- resolves dependencies through the compiler-emitted __ctorParams
-- metadata that lives on every class table.
--
-- API matches Zenject as closely as the platform allows: Bind /
-- BindInterfacesTo / BindInterfacesAndSelfTo, fluent .To / .FromInstance
-- / .AsSingle / .AsTransient on the returned Binder, Resolve<T>(),
-- Install<T>(), Bootstrap() to fire IInitializable lifecycles and wire
-- ITickable / IFixedTickable / ILateTickable singletons to RunService
-- (the container owns the only tick connections in the process).

local Binder = require(script.Parent.Binder)
local Instantiator = require(script.Parent.Instantiator)

-- Interfaces have no runtime artifact in roblox-csharp — they're
-- identified by their simple name as a string at every reference
-- site. Hardcoding the literal here keeps Container's lifecycle
-- check (`if implements IInitializable then Initialize()`) aligned
-- with what user classes get for their `__interfaces` table.
local IInitializable = "IInitializable"
local ITickable = "ITickable"
local IFixedTickable = "IFixedTickable"
local ILateTickable = "ILateTickable"

-- Marker interfaces scanned by Bootstrap rather than resolved by key —
-- many services sharing one of these is the normal pattern, so the
-- re-binding warning and orphan drop don't apply to them.
local markerInterfaces = {
	[IInitializable] = true,
	[ITickable] = true,
	[IFixedTickable] = true,
	[ILateTickable] = true,
}

local Container = {}
Container.__index = Container

setmetatable(Container, {
	__tostring = function() return "Container" end,
})

Container.__ctorParams = {}
Container.__interfaces = {}

function Container.new()
	local self = setmetatable({}, Container)
	self._bindings = {}     -- [typeKey] = Binder (lookup for Resolve)
	-- Ordered list of every registered Binder, in bind order. Bootstrap
	-- iterates THIS, not the map: map keys collide (two IInitializable-only
	-- services share one key) and pairs() order is nondeterministic.
	self._bindingList = {}
	self._singletons = {}   -- [implType] = constructed singleton (lazy cache)
	-- Binders that started a chain but haven't hit AsSingle/AsTransient
	-- yet. Bootstrap errors if any remain — a `.To<T>()` chain with no
	-- lifetime would otherwise be silently dropped.
	self._openBinders = {}
	self._bootstrapped = false
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
	self:_warnIfBootstrapped("Bind")
	return Binder.new(self, { typeKey })
end

-- `BindInterfacesTo<T>()` walks T's interface set (including inherited)
-- and registers the binding under each. Matches Zenject's behavior of
-- spraying a single impl across every contract it satisfies.
function Container:BindInterfacesTo(implType)
	self:_warnIfBootstrapped("BindInterfacesTo")
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
	self:_warnIfBootstrapped("BindInterfacesAndSelfTo")
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

-- Walks every registered binding in bind order; for each unique impl
-- whose interface set includes IInitializable, resolves it (which seeds
-- the singleton cache if AsSingle was used) and calls Initialize().
--
-- Each construction and Initialize() is pcall-isolated: one throwing
-- service warns and the rest still come up.
--
-- Idempotent in the singleton case — re-running Bootstrap re-uses
-- cached instances rather than re-initializing them. Transient
-- bindings would re-initialize on every Bootstrap; users should
-- mark IInitializable services AsSingle.
function Container:Bootstrap()
	for binder in pairs(self._openBinders) do
		local names = {}
		for _, key in ipairs(binder._typeKeys) do
			table.insert(names, tostring(key))
		end
		error(string.format(
			"[DI] Binding for %s was never registered — finish the chain with :AsSingle() or :AsTransient()",
			table.concat(names, ", ")), 2)
	end
	self._bootstrapped = true

	local seen = {}
	for _, binding in ipairs(self._bindingList) do
		local impl = binding._implType
		if impl ~= nil and not seen[impl] then
			seen[impl] = true
			if self:_implementsInterface(impl, IInitializable) then
				local ok, instance = pcall(binding._provide, binding, self)
				if not ok then
					warn(string.format("[DI] Bootstrap: constructing %s failed: %s",
						tostring(impl), tostring(instance)))
				elseif instance.Initialize then
					local initOk, err = pcall(instance.Initialize, instance)
					if not initOk then
						warn(string.format("[DI] Bootstrap: %s.Initialize() failed: %s",
							tostring(impl), tostring(err)))
					end
				end
			end
		end
	end

	self:_wireTickables()
end

-- Collects every singleton implementing ITickable / IFixedTickable /
-- ILateTickable (in bind order) and drives them from RunService:
--   client: RenderStepped → Tick (pre-frame), Heartbeat → LateTick
--   server: Heartbeat → Tick then LateTick (one connection, in order;
--           RenderStepped doesn't exist there)
--   both:   Stepped → FixedTick (pre-physics)
-- Runs after every Initialize() so no tick fires on a half-built
-- service. Wired once — a second Bootstrap doesn't double-connect.
-- Ticks are not pcall-isolated: an error in one tickable skips the
-- rest for that frame (the connection itself survives).
function Container:_wireTickables()
	if self._tickConnections ~= nil then return end

	local tickables, fixedTickables, lateTickables = {}, {}, {}
	local seen = {}
	for _, binding in ipairs(self._bindingList) do
		local impl = binding._implType
		if impl ~= nil and not seen[impl] then
			seen[impl] = true
			local isTickable = self:_implementsInterface(impl, ITickable)
			local isFixed = self:_implementsInterface(impl, IFixedTickable)
			local isLate = self:_implementsInterface(impl, ILateTickable)
			if isTickable or isFixed or isLate then
				local ok, instance = pcall(binding._provide, binding, self)
				if not ok then
					warn(string.format("[DI] Bootstrap: constructing tickable %s failed: %s",
						tostring(impl), tostring(instance)))
				else
					if isTickable then table.insert(tickables, instance) end
					if isFixed then table.insert(fixedTickables, instance) end
					if isLate then table.insert(lateTickables, instance) end
				end
			end
		end
	end

	if #tickables == 0 and #fixedTickables == 0 and #lateTickables == 0 then
		return
	end

	local RunService = game:GetService("RunService")
	self._tickConnections = {}

	local function dispatch(list, methodName, dt)
		for _, instance in ipairs(list) do
			instance[methodName](instance, dt)
		end
	end

	if RunService:IsClient() then
		table.insert(self._tickConnections, RunService.RenderStepped:Connect(function(dt)
			dispatch(tickables, "Tick", dt)
		end))
		table.insert(self._tickConnections, RunService.Heartbeat:Connect(function(dt)
			dispatch(lateTickables, "LateTick", dt)
		end))
	else
		table.insert(self._tickConnections, RunService.Heartbeat:Connect(function(dt)
			dispatch(tickables, "Tick", dt)
			dispatch(lateTickables, "LateTick", dt)
		end))
	end

	if #fixedTickables > 0 then
		table.insert(self._tickConnections, RunService.Stepped:Connect(function(_time, dt)
			dispatch(fixedTickables, "FixedTick", dt)
		end))
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
--
-- IInitializable is suppressed from the re-binding warning (and from
-- the orphan drop below) because it isn't a Resolve target — it's a
-- marker Bootstrap scans for across the ordered binding list. Two
-- services both implementing IInitializable is the normal pattern;
-- their map entries collide but both survive in `_bindingList` and
-- both get Initialize() called. The warning would only mean something
-- if a user did `Resolve<IInitializable>()`, which never happens.
function Container:_addBinding(typeKey, binding)
	local previous = self._bindings[typeKey]
	self._bindings[typeKey] = binding

	if previous ~= nil and previous ~= binding and markerInterfaces[typeKey] ~= true then
		warn(string.format(
			"[DI] Re-binding %s — previous binding will be overwritten",
			tostring(typeKey)))
		self:_dropOrphanedBinding(previous)
	end

	if table.find(self._bindingList, binding) == nil then
		table.insert(self._bindingList, binding)
	end
end

-- A re-bound key may leave its previous Binder unreachable through the
-- map. Drop it from the ordered list so Bootstrap doesn't initialize a
-- binding the user explicitly replaced.
function Container:_dropOrphanedBinding(previous)
	for _, b in pairs(self._bindings) do
		if b == previous then return end
	end
	local index = table.find(self._bindingList, previous)
	if index ~= nil then
		table.remove(self._bindingList, index)
	end
end

-- Binder lifecycle hooks: a Binder is "open" from construction until
-- a lifetime call registers it. Bootstrap refuses to run while any
-- chain is still open.
function Container:_trackBinder(binder)
	self._openBinders[binder] = true
end

function Container:_untrackBinder(binder)
	self._openBinders[binder] = nil
end

function Container:_warnIfBootstrapped(method)
	if self._bootstrapped then
		warn(string.format(
			"[DI] %s called after Bootstrap — the binding will resolve but its Initialize() will never run",
			method))
	end
end

return Container
