using Microsoft.AspNetCore.Http.Extensions;
using Orleans;
using Orleans.Configuration;
using Orleans.Hosting;
using UrlShortener.Shared;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseOrleans(siloBuilder =>
{
    siloBuilder.UseLocalhostClustering()
    .Configure<ClusterOptions>(options =>
    {
        options.ClusterId = "prod";
        options.ServiceId = "UrlShortener";
    })
    .ConfigureApplicationParts(parts =>
        parts.AddApplicationPart(typeof(UrlShortenerGrain).Assembly).WithReferences())
    .ConfigureLogging(logging =>
        logging.AddConsole());
});

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

var grainFactory = app.Services.GetRequiredService<IGrainFactory>();

app.MapGet("/shorten/{*path}", async (HttpContext context, string path) =>
{
    var shortenedRouteSegment = Guid.NewGuid().GetHashCode().ToString("X");
    var shortenerGrain = grainFactory.GetGrain<IUrlShortenerGrain>(shortenedRouteSegment);
    await shortenerGrain.SetUrl(shortenedRouteSegment, path);
    var resultBuilder = new UriBuilder(context.Request.GetEncodedUrl())
    {
        Path = $"/go/{shortenedRouteSegment}"
    };

    return Results.Ok(resultBuilder.Uri);
});

app.MapGet("/go/{shortenedRouteSegment}", async (string shortenedRouteSegment) =>
{
    var shortenerGrain = grainFactory.GetGrain<IUrlShortenerGrain>(shortenedRouteSegment);
    var url = await shortenerGrain.GetUrl();

    return url is not null ? Results.Redirect(url) : Results.NotFound();
});

app.Run();

public class UrlShortenerGrain : Grain, IUrlShortenerGrain
{
    private KeyValuePair<string, string> _cache;

    public Task SetUrl(string shortenedRouteSegment, string fullUrl)
    {
        _cache = new KeyValuePair<string, string>(shortenedRouteSegment, fullUrl);
        return Task.CompletedTask;
    }

    public Task<string?> GetUrl()
    {
        return Task.FromResult(_cache.Value);
    }
}