namespace DependencyInjection
{
    // Convenience base for client-side bootstrap. Mirror of
    // ServerInstaller — see its comments for the emit shape. The only
    // difference is the file extension: a class deriving from
    // ClientInstaller compiles to `.client.luau`, which Rojo treats as
    // a LocalScript that auto-runs in the player.
    [Client]
    public abstract class ClientInstaller : Installer
    {
        public ClientInstaller(Container container) : base(container) { }
    }
}
