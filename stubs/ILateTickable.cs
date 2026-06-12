namespace DependencyInjection
{
    /// <summary>
    /// Late tick, driven by the container after <c>Bootstrap()</c> via
    /// <c>RunService.Heartbeat</c> (server + client). The Roblox frame runs
    /// RenderStepped → Stepped → physics → Heartbeat, so this fires after
    /// <see cref="ITickable.Tick"/> and after physics; on the server it
    /// shares the Heartbeat with Tick, dispatched second.
    /// </summary>
    public interface ILateTickable
    {
        void LateTick(double dt);
    }
}
