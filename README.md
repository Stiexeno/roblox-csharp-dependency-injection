# roblox-csharp-dependency-injection

Zenject-style DI container for [roblox-csharp](https://github.com/Stiexeno/roblox-csharp): fluent bindings, constructor injection via compiler-emitted `__ctorParams`, `IInitializable` bootstrap lifecycle, `ServerInstaller` / `ClientInstaller` auto-boot.

## Install

```sh
roblox-csharp plugin add Stiexeno/roblox-csharp-dependency-injection
```

Requires roblox-csharp `0.1.0-alpha.52+`. No other dependencies. Runtime mounts at `ReplicatedStorage.Plugins.DependencyInjection`.

## Quick start

```csharp
using DependencyInjection;

public interface IGameStateMachine { void EnterBootstrap(); }

public class GameStateMachine : IGameStateMachine
{
    public void EnterBootstrap() { /* ... */ }
}

public class EntryPoint : IInitializable
{
    private readonly IGameStateMachine _stateMachine;

    public EntryPoint(IGameStateMachine stateMachine) => _stateMachine = stateMachine;

    public void Initialize() => _stateMachine.EnterBootstrap();
}

// Compiles to a .server.luau Script. The compiler appends the boot
// tail: new Container() -> new GameInstaller(container) ->
// InstallBindings() -> Bootstrap(). You only write the bindings.
public class GameInstaller : ServerInstaller
{
    public GameInstaller(Container container) : base(container) { }

    public override void InstallBindings()
    {
        Container.BindInterfacesTo<EntryPoint>().AsSingle();
        Container.BindInterfacesTo<GameStateMachine>().AsSingle();
    }
}
```

`ClientInstaller` is the same shape, emitted as `.client.luau`. Server and client each get their own container.

## API

### Container

| Method | Behavior |
|---|---|
| `Bind<T>()` | Start a binding keyed by `T`. With no `.To()`, the key binds to itself. |
| `BindInterfacesTo<T>()` | Bind `T` under every interface it (or a base class) declares. Warns and self-binds if `T` has none. |
| `BindInterfacesAndSelfTo<T>()` | Same, plus a binding under `T` itself. |
| `Resolve<T>()` | Return the bound instance. Errors with the full resolve chain when unbound or circular. |
| `Install<T>()` | `new T(container)` + `InstallBindings()`. Installers bypass DI resolution. |
| `Bootstrap()` | Construct every binding whose impl declares `IInitializable` and call `Initialize()`, in bind order. Each construction/`Initialize()` is error-isolated: a throwing service warns, the rest still run. Errors if any binding chain was left without a lifetime. |

Binding after `Bootstrap()` warns — the late binding resolves, but its `Initialize()` never runs.

### Binder (fluent)

`To<T>()` · `FromInstance(obj)` · `AsSingle()` · `AsTransient()`

**A binding only registers when `AsSingle()` or `AsTransient()` runs.** A chain that stops at `.To<T>()` makes `Bootstrap()` error, naming the unterminated type.

Singletons are cached per concrete impl type, so a type bound under several keys yields one shared instance. Re-binding an existing key overwrites it with a warning.

### Built-in bindings

The container auto-binds itself (inject `Container`) and an `IInstantiator` — `Instantiate<T>()` constructs an unbound `T` with its ctor params resolved from the container; caller owns the lifetime.

### Lifecycle

- `IInitializable.Initialize()` — called by `Bootstrap()`, in the order services were bound.
- `ITickable.Tick(dt)` — per frame, container-driven after `Bootstrap()`: `RenderStepped` on the client (pre-frame), `Heartbeat` on the server. Singletons only, bind order.
- `IFixedTickable.FixedTick(dt)` — `RunService.Stepped` (pre-physics, both sides).
- `ILateTickable.LateTick(dt)` — `RunService.Heartbeat` (both sides; after `Tick` on the server, where they share one connection). The Roblox frame runs RenderStepped → Stepped → physics → Heartbeat.
- The container owns the only RunService connections in the process — services implement the tick interfaces instead of connecting themselves.
- No teardown lifecycle — there is no `IDisposable` equivalent.

## How resolution works

The compiler emits on every class:

```lua
EntryPoint.__ctorParams = {IGameStateMachine}  -- ctor parameter type identities
EntryPoint.__interfaces = {"IInitializable"}   -- declared interface names
```

`Resolve` walks `__ctorParams` recursively. `BindInterfacesTo` walks `__interfaces` up the metatable chain (inherited interfaces included). No runtime reflection.

## Caveats

- **Interfaces are string identities (simple name).** Two interfaces with the same name in different namespaces are the same binding key. A user interface literally named `IInitializable` opts into the bootstrap lifecycle.
- **Circular dependencies are detected, not supported** — `Resolve` errors with the cycle path (`A -> B -> A`); there is no lazy/proxy resolution.
- Transient `IInitializable` bindings are re-constructed and re-initialized on every `Bootstrap()`; mark them `AsSingle()`.
- Constructor injection only — no `[Inject]` fields/methods, no `IEnumerable<T>` multi-injection, no sub-containers, no conditional bindings.

## License

[MIT](LICENSE).
