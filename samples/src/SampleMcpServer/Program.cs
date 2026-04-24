using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using SampleMcpServer.Tools;

var builder = WebApplication.CreateBuilder(args);

// ---------- Entra ID JWT authentication ----------
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

builder.Services.AddAuthorization();

// ---------- HttpClient for downstream calls (Graph, etc.) ----------
builder.Services.AddHttpClient("graph", client =>
{
    client.BaseAddress = new Uri("https://graph.microsoft.com/v1.0/");
});

builder.Services.AddHttpContextAccessor();

// ---------- MCP Server ----------
builder.Services.AddMcpServer()
    .WithHttpTransport()
    .WithTools<WhoAmITool>()
    .WithTools<GetMyGraphProfileTool>()
    .WithTools<EchoTool>();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// MCP endpoint – requires authentication
app.MapMcp("/mcp").RequireAuthorization();

// Health check (no auth)
app.MapGet("/health", () => Results.Ok(new { Status = "healthy" }));

app.Run();
