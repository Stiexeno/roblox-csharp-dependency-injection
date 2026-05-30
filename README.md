# roblox-csharp-dependency-injection

Zenject-style DI container packaged as a [roblox-csharp](https://github.com/Stiexeno/roblox-csharp) plugin. Fluent bindings, constructor injection, `IInitializable` lifecycle, `[Server]` / `[Client]` auto-bootstrap.

## Install

From your roblox-csharp project root (requires roblox-csharp `0.1.0-alpha.7` or newer):

```sh
roblox-csharp plugin add Stiexeno/roblox-csharp-dependency-injection
```

That drops the plugin into `plugins/DependencyInjection/`. Recompile (`roblox-csharp` or `roblox-csharp dev`) and the runtime mounts at `ReplicatedStorage.Plugins.DependencyInjection`.

## Quick start

```csharp
using DependencyInjection;

// Define a service. Constructor params get resolved by the container.
public interface IGameStateMachine { void EnterBootstrap(); }

public class GameStateMachine : IGameStateMachine
{
    public void EnterBootstrap() { /* ... */ }
}

// IInitializable services run once at boot.
public class EntryPoint : IInitializable
{
    private readonly IGameStateMachine _stateMachine;

    public EntryPoint(IGameStateMachine stateMachine)
    {
        _stateMachine = stateMachine;
    }

    public void Initialize()
    {
        _stateMachine.EnterBootstrap();
    }
}

// ServerInstaller is auto-bootstrapped: the file compiles to a
// .server.luau Script that Roblox runs on startup, and the compiler
// appends a boot tail (construct Container, instantiate this class
// with it, call InstallBindings, call Bootstrap). All you write is
// the bindings.
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

Use `ClientInstaller` for client-side bootstraps; same shape, compiles to `.client.luau`.

## API surface

### Container

| Method | Purpose |
|---|---|
| `Bind<T>()` | Start a binding for type `T`. Returns a `Binder`. |
| `BindInterfacesTo<T>()` | Bind `T` to every interface it implements. |
| `BindInterfacesAndSelfTo<T>()` | Bind `T` to its interfaces AND to itself. |
| `Resolve<T>()` | Get an instance for a registered type. Errors if unbound. |
| `Install<T>()` where `T : Installer` | Create the installer with the container and call `InstallBindings`. |
| `Bootstrap()` | Resolve every `IInitializable` binding and call `Initialize()`. |

### Binder (fluent)

| Method | Purpose |
|---|---|
| `To<T>()` | Specify the concrete implementation type. |
| `FromInstance(obj)` | Use a pre-built instance instead of constructing. |
| `AsSingle()` | Cache one instance; subsequent resolves return the same one. |
| `AsTransient()` | Construct a fresh instance per resolve. |

### Lifecycle interfaces

- **`IInitializable`** — `Initialize()` called by `Container.Bootstrap()` for every binding whose impl implements this.
- **`IDisposable`** — marker for cleanup. Container teardown is not wired in v1.

### Bootstrap base classes

- **`ServerInstaller`** — inherit, override `InstallBindings`. Compiles to `.server.luau`, auto-runs server-side.
- **`ClientInstaller`** — same, compiles to `.client.luau`, auto-runs in players.

## How it works

The compiler emits two pieces of metadata on every class:

```lua
EntryPoint.__ctorParams = {IGameStateMachine}    -- constructor parameter types
EntryPoint.__interfaces = {IInitializable}        -- declared interfaces
```

`__ctorParams` lets the container resolve constructor arguments recursively — no reflection at runtime, the metadata is baked in at transpile time. `__interfaces` lets `BindInterfacesTo<T>()` enumerate everything `T` implements (including inherited interfaces from base classes, walked via the metatable chain) and lets `Bootstrap()` find `IInitializable` implementers.

Generic method calls automatically surface their type arguments at runtime: `Container.Bind<IFoo>()` compiles to `Container:Bind(IFoo)`, with the type table arriving as a real parameter the container can key bindings off.

## What's not in v1

- **`IEnumerable<T>` injection** — Zenject lets you inject a collection of all bound implementers. Not wired yet; deferred until a real use case appears.
- **`[Inject]` on fields / methods** — currently only constructor injection. The marker attribute exists; the compiler doesn't honor it yet.
- **`Container.Dispose()`** — `IDisposable` marker exists; teardown not wired.
- **Sub-containers / scopes** — single container per app for v1.
- **Conditional bindings** (`.When(...)`) — not yet.

## License

[MIT](LICENSE).
