namespace DependencyInjection
{
    // Base for the user's binding-declaration classes. Inherit, override
    // InstallBindings, and have the bootstrap call Container.Install<T>()
    // to invoke. Mirrors Zenject's PlainAbstractInstaller — there's no
    // MonoInstaller-equivalent in Roblox since we have no scene contexts
    // to attach to.
    public abstract class Installer
    {
        protected Container Container { get; }

        public Installer(Container container)
        {
            Container = container;
        }

        public abstract void InstallBindings();
    }
}
