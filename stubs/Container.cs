namespace DependencyInjection
{
    // C# stubs for the DI plugin. Bodies are never executed — the
    // compiler routes references to these types onto the Lua runtime
    // under ReplicatedStorage.Plugins.DependencyInjection.
    //
    // Generic methods get their type arguments surfaced as runtime
    // arguments automatically — no opt-in attribute. `Container.Bind<IFoo>()`
    // becomes `Container:Bind(IFoo)` so the container can key bindings
    // by table identity.
    public class Container
    {
        public Binder Bind<T>() => null;

        public Binder BindInterfacesTo<T>() => null;

        public Binder BindInterfacesAndSelfTo<T>() => null;

        public T Resolve<T>() => default;

        public void Install<T>() where T : Installer { }

        // Resolves every registered binding whose implementation
        // implements IInitializable and calls Initialize() on each.
        // Idempotent — safe to call again after adding more bindings,
        // but services already initialized won't fire a second time.
        public void Bootstrap() { }
    }
}
