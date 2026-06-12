namespace DependencyInjection
{
    /// <summary>
    /// Per-frame tick, driven by the container after <c>Bootstrap()</c> for
    /// every singleton bound under this interface (in bind order). Client:
    /// <c>RunService.RenderStepped</c> (pre-frame). Server:
    /// <c>RunService.Heartbeat</c> (RenderStepped doesn't exist there).
    /// </summary>
    public interface ITickable
    {
        void Tick(double dt);
    }
}
