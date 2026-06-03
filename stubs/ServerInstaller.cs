namespace DependencyInjection
{
    /// <summary>
    /// Installer that runs only on the server. The <c>[Server]</c> marker tells
    /// the transpiler to emit this file as <c>*.server.luau</c>.
    /// </summary>
    [Server]
    public abstract class ServerInstaller : Installer
    {
        public ServerInstaller(Container container) : base(container) { }
    }
}
