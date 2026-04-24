using System.ComponentModel;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using ModelContextProtocol.Server;

namespace SampleMcpServer.Tools;

/// <summary>
/// MCP tool that returns the authenticated user's identity from the JWT claims.
/// Proves end-to-end user delegation: client → APIM (OBO) → MCP backend.
/// </summary>
[McpServerToolType]
public sealed class WhoAmITool
{
    [McpServerTool(Name = "whoami"), Description("Returns the authenticated user's identity (oid, upn, name, roles) from the JWT token. Proves user delegation works end-to-end.")]
    public static object WhoAmI(IHttpContextAccessor httpContextAccessor)
    {
        var user = httpContextAccessor.HttpContext?.User;
        if (user?.Identity?.IsAuthenticated != true)
        {
            return new { Error = "Not authenticated" };
        }

        return new
        {
            ObjectId = user.FindFirstValue("http://schemas.microsoft.com/identity/claims/objectidentifier")
                       ?? user.FindFirstValue("oid"),
            UserPrincipalName = user.FindFirstValue("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn")
                                ?? user.FindFirstValue("preferred_username"),
            Name = user.Identity.Name
                   ?? user.FindFirstValue("name"),
            Email = user.FindFirstValue("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress")
                    ?? user.FindFirstValue("email"),
            TenantId = user.FindFirstValue("http://schemas.microsoft.com/identity/claims/tenantid")
                       ?? user.FindFirstValue("tid"),
            Scopes = user.FindFirstValue("http://schemas.microsoft.com/identity/claims/scope")
                     ?? user.FindFirstValue("scp"),
            Roles = user.FindAll("http://schemas.microsoft.com/ws/2008/06/identity/claims/role")
                        .Select(c => c.Value)
                        .Concat(user.FindAll("roles").Select(c => c.Value))
                        .Distinct()
                        .ToList(),
            Audience = user.FindFirstValue("aud"),
            Issuer = user.FindFirstValue("iss"),
            IsAuthenticated = true
        };
    }
}
