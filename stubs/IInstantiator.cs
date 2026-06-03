namespace DependencyInjection
{
    /// <summary>
    /// Constructs new instances with their constructor dependencies resolved
    /// from the container, without first registering a binding for the target type.
    /// </summary>
    public interface IInstantiator
    {
        T Instantiate<T>();
    }
}
