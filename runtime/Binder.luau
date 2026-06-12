-- Fluent binder. Container.Bind*() returns one of these; the chain
-- terminates with AsSingle/AsTransient which calls back into the
-- container to register. Until that terminator runs, the binding is
-- in a draft state and not yet resolvable — the container tracks it
-- as "open" and Bootstrap errors if any chain was left unterminated.

local Binder = {}
Binder.__index = Binder

setmetatable(Binder, {
	__tostring = function() return "Binder" end,
})

Binder.__ctorParams = {}
Binder.__interfaces = {}

function Binder.new(container, typeKeys)
	local self = setmetatable({}, Binder)
	self._container = container
	self._typeKeys = typeKeys     -- list of keys this binding covers
	self._implType = nil          -- the concrete class table to instantiate
	self._instance = nil          -- explicit instance (FromInstance path)
	self._isSingle = false
	container:_trackBinder(self)
	return self
end

-- `To<U>()` lowers via [Reified] to `To(U)` — U arrives as the class table.
function Binder:To(implType)
	self._implType = implType
	return self
end

function Binder:FromInstance(instance)
	self._instance = instance
	-- Recover implType from the instance's metatable so Bootstrap can
	-- still walk this binding when checking IInitializable.
	if self._implType == nil then
		self._implType = getmetatable(instance)
	end
	return self
end

function Binder:AsSingle()
	self._isSingle = true
	self:_register()
	return self
end

function Binder:AsTransient()
	self._isSingle = false
	self:_register()
	return self
end

-- Locks the binding in. If neither .To() nor .FromInstance() was
-- called and we have exactly one type key, default to binding the key
-- to itself (`Container.Bind<MyClass>().AsSingle()` resolves `MyClass`
-- to itself).
function Binder:_register()
	if self._implType == nil and self._instance == nil then
		if #self._typeKeys == 1 then
			self._implType = self._typeKeys[1]
		else
			error("[DI] Binding chain has no .To() or .FromInstance()", 3)
		end
	end

	for _, key in ipairs(self._typeKeys) do
		self._container:_addBinding(key, self)
	end
	self._container:_untrackBinder(self)
end

-- Container calls this when resolving a key bound by this binder.
-- Honors AsSingle caching and recurses into the container to fill in
-- the constructor's parameter list from __ctorParams.
function Binder:_provide(container)
	if self._instance ~= nil then
		return self._instance
	end

	if self._isSingle then
		local cached = container._singletons[self._implType]
		if cached ~= nil then return cached end
		local instance = self:_construct(container)
		container._singletons[self._implType] = instance
		return instance
	end

	return self:_construct(container)
end

-- Walks __ctorParams (compiler-emitted on every class) and recursively
-- resolves each one. Mirrors what Zenject's reflection-based ctor
-- selection does in Unity — only here the metadata is baked in at
-- transpile time so there's no runtime reflection cost.
function Binder:_construct(container)
	local impl = self._implType
	local params = rawget(impl, "__ctorParams") or {}

	if #params == 0 then
		return impl.new()
	end

	local args = {}
	for i, paramType in ipairs(params) do
		args[i] = container:Resolve(paramType)
	end
	return impl.new(table.unpack(args))
end

return Binder
