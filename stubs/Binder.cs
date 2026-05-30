namespace DependencyInjection
{
    // Fluent binder returned by Container.Bind* methods. The chain
    // terminates with .AsSingle() / .AsTransient(), which registers the
    // binding with the container.
    public class Binder
    {
        public Binder To<T>() => this;

        // Bind to an externally-constructed instance. Common shape for
        // Roblox services (game:GetService(...)) or pre-built Contexts.
        public Binder FromInstance(object instance) => this;

        public Binder AsSingle() => this;
        public Binder AsTransient() => this;
    }
}
