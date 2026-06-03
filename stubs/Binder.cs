namespace DependencyInjection
{
    /// <summary>
    /// Fluent builder returned by <see cref="Container.Bind{T}"/>. Configures
    /// which concrete type resolves the binding and the binding's lifetime.
    /// </summary>
    public class Binder
    {
        /// <summary>Routes the binding to the concrete type <typeparamref name="T"/>.</summary>
        public Binder To<T>() => this;

        /// <summary>Resolves the binding to a specific pre-built instance.</summary>
        public Binder FromInstance(object instance) => this;

        /// <summary>One shared instance lives for the container's lifetime.</summary>
        public Binder AsSingle() => this;

        /// <summary>A fresh instance is constructed on every <c>Resolve</c>.</summary>
        public Binder AsTransient() => this;
    }
}
