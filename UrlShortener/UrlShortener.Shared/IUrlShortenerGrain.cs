using Orleans;

namespace UrlShortener.Shared
{
    public interface IUrlShortenerGrain : IGrainWithStringKey
    {
        Task SetUrl(string shortenedRouteSegment, string fullUrl);
        Task<string> GetUrl();
    }
}
