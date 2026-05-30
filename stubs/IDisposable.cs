namespace DependencyInjection
{
    // Marker for services that need cleanup. The container's Dispose()
    // (not yet implemented in v1) will call Dispose() on every
    // singleton instance whose type implements this.
    public interface IDisposable
    {
        void Dispose();
    }
}
