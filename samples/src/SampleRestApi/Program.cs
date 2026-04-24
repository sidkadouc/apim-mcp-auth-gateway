using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;

var builder = WebApplication.CreateBuilder(args);

// ---------- Entra ID JWT authentication ----------
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

// ---------- Sample endpoints ----------

// GET /api/weather – returns dummy weather data, requires valid JWT
app.MapGet("/api/weather", (HttpContext ctx) =>
{
    var forecasts = Enumerable.Range(1, 5).Select(i => new
    {
        Date = DateOnly.FromDateTime(DateTime.Now.AddDays(i)),
        TemperatureC = Random.Shared.Next(-20, 55),
        Summary = new[] { "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Hot" }[Random.Shared.Next(7)]
    });
    return Results.Ok(forecasts);
})
.RequireAuthorization();

// GET /api/me – returns the authenticated user's claims
app.MapGet("/api/me", (HttpContext ctx) =>
{
    var claims = ctx.User.Claims.Select(c => new { c.Type, c.Value });
    return Results.Ok(new
    {
        IsAuthenticated = ctx.User.Identity?.IsAuthenticated,
        Name = ctx.User.Identity?.Name,
        Claims = claims
    });
})
.RequireAuthorization();

// Health check (no auth)
app.MapGet("/health", () => Results.Ok(new { Status = "healthy" }));

app.Run();
