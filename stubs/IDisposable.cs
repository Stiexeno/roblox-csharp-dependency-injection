namespace DependencyInjection
{
    /// <summary>
    /// Lifecycle hook invoked when the owning <see cref="Container"/> tears down.
    /// </summary>
    public interface IDisposable
    {
        void Dispose();
    }
}
