namespace DependencyInjection
{
    /// <summary>
    /// Base class for binding registrations. Override <see cref="InstallBindings"/>
    /// and call <see cref="Container.Install{T}"/> to apply.
    /// </summary>
    public abstract class Installer
    {
        protected Container Container { get; }

        public Installer(Container container)
        {
            Container = container;
        }

        /// <summary>Registers bindings against <see cref="Container"/>. Called by <c>Install</c>.</summary>
        public abstract void InstallBindings();
    }
}
