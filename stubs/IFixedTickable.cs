namespace DependencyInjection
{
    /// <summary>
    /// Fixed-timestep tick, driven by the container after <c>Bootstrap()</c>
    /// via <c>RunService.Stepped</c> (pre-physics, server + client).
    /// </summary>
    public interface IFixedTickable
    {
        void FixedTick(double dt);
    }
}
