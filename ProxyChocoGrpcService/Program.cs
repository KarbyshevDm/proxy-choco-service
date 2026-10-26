using ProxyChocoGrpcService.Services;
using Microsoft.Extensions.Hosting.WindowsServices;

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = WindowsServiceHelpers.IsWindowsService() ? AppContext.BaseDirectory : default,
});
builder.Host.UseWindowsService();
builder.WebHost.UseUrls("http://localhost:5000");

// Add services to the container.
builder.Services.AddGrpc(options => {
    options.MaxSendMessageSize = 50 * 1024 * 1024;
    
    options.MaxReceiveMessageSize = 50 * 1024 * 1024;
});

var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapGrpcService<ChocoService>();
app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");
app.Run();
