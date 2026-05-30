namespace DependencyInjection
{
    // Convenience base for server-side bootstrap. Inherit, override
    // InstallBindings, and the compiler emits a `.server.luau` Script
    // that auto-runs and performs the standard boot:
    //
    //     local _container = Container.new()
    //     local _installer = MyInstaller.new(_container)
    //     _installer:InstallBindings()
    //     _container:Bootstrap()
    //
    // No need to write GameServer.Start() or wire a manual bootstrap
    // Script in Studio. One file, one class, the runtime takes care of
    // the rest. Mirrors Zenject's SceneContext + Installer composition.
    [Server]
    public abstract class ServerInstaller : Installer
    {
        public ServerInstaller(Container container) : base(container) { }
    }
}
