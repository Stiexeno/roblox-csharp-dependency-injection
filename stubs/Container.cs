namespace DependencyInjection
{
    /// <summary>
    /// DI container. Collect bindings via <see cref="Install{T}"/> then call
    /// <see cref="Bootstrap"/> to instantiate singletons and wire dependencies.
    /// </summary>
    public class Container
    {
        /// <summary>Starts a new binding for <typeparamref name="T"/>.</summary>
        public Binder Bind<T>() => null;

        /// <summary>Binds every interface implemented by <typeparamref name="T"/> to the same instance.</summary>
        public Binder BindInterfacesTo<T>() => null;

        /// <summary>Binds <typeparamref name="T"/> and all its interfaces to the same instance.</summary>
        public Binder BindInterfacesAndSelfTo<T>() => null;

        /// <summary>Resolves the registered binding for <typeparamref name="T"/>.</summary>
        public T Resolve<T>() => default;

        /// <summary>Runs the installer's <c>InstallBindings</c> against this container.</summary>
        public void Install<T>() where T : Installer { }

        /// <summary>
        /// Materializes singletons, invokes <see cref="IInitializable.Initialize"/>
        /// hooks, then wires <see cref="ITickable"/> / <see cref="IFixedTickable"/> /
        /// <see cref="ILateTickable"/> singletons to RunService (bind order).
        /// </summary>
        public void Bootstrap() { }
    }
}
