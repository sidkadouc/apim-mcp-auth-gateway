using System.ComponentModel;
using ModelContextProtocol.Server;

namespace SampleMcpServer.Tools;

/// <summary>
/// Simple echo tool for testing MCP connectivity (no auth claims needed).
/// </summary>
[McpServerToolType]
public sealed class EchoTool
{
    [McpServerTool(Name = "echo"), Description("Echoes back the provided message. Useful for testing MCP server connectivity through the AI Gateway.")]
    public static object Echo(
        [Description("The message to echo back")] string message)
    {
        return new
        {
            Echo = message,
            Timestamp = DateTimeOffset.UtcNow,
            Server = "SampleMcpServer"
        };
    }
}
