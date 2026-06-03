namespace DependencyInjection
{
    /// <summary>
    /// Installer that runs only on the client. The <c>[Client]</c> marker tells
    /// the transpiler to emit this file as <c>*.client.luau</c>.
    /// </summary>
    [Client]
    public abstract class ClientInstaller : Installer
    {
        public ClientInstaller(Container container) : base(container) { }
    }
}
