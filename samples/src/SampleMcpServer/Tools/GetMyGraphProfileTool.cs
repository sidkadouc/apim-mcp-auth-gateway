using System.ComponentModel;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using ModelContextProtocol.Server;

namespace SampleMcpServer.Tools;

/// <summary>
/// MCP tool that reads user profile data from the OBO JWT claims.
/// Optionally calls MS Graph /me if a Graph-scoped token is available (requires
/// the backend to perform its own OBO for https://graph.microsoft.com/.default).
///
/// In this PoC, we extract profile info directly from the claims propagated via
/// the APIM OBO chain — proving user identity flows end-to-end without an extra
/// token hop.
/// </summary>
[McpServerToolType]
public sealed class GetMyGraphProfileTool
{
    [McpServerTool(Name = "get-my-graph-profile"), Description("Returns the user's profile information (name, email, job title) from the OBO token claims. Demonstrates user identity propagation through the AI Gateway.")]
    public static async Task<object> GetMyGraphProfile(
        IHttpContextAccessor httpContextAccessor,
        IHttpClientFactory httpClientFactory)
    {
        var user = httpContextAccessor.HttpContext?.User;
        if (user?.Identity?.IsAuthenticated != true)
        {
            return new { Error = "Not authenticated" };
        }

        // Profile data available directly from the OBO JWT claims
        var profile = new
        {
            ObjectId = user.FindFirstValue("oid"),
            DisplayName = user.FindFirstValue("name"),
            UserPrincipalName = user.FindFirstValue("preferred_username")
                                ?? user.FindFirstValue("upn"),
            Email = user.FindFirstValue("email"),
            TenantId = user.FindFirstValue("tid"),
            Source = "jwt_claims"
        };

        // --- Extension point: if you chain another OBO to Graph, uncomment below ---
        // var accessToken = httpContextAccessor.HttpContext!
        //     .Request.Headers["Authorization"]
        //     .ToString().Replace("Bearer ", "");
        // var graphClient = httpClientFactory.CreateClient("graph");
        // graphClient.DefaultRequestHeaders.Authorization =
        //     new AuthenticationHeaderValue("Bearer", graphAccessToken);
        // var graphResponse = await graphClient.GetAsync("me");
        // var graphProfile = await graphResponse.Content.ReadFromJsonAsync<JsonElement>();
        // return graphProfile;

        await Task.CompletedTask; // async signature for future Graph call
        return profile;
    }
}
