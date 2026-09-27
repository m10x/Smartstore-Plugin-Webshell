using System.Threading.Tasks;
using Smartstore.Engine.Modularity;

namespace M10x.Webshell;

/// <summary>
/// DEMO ONLY - do not use outside an isolated lab environment.
/// </summary>
internal class Module : ModuleBase
{
    public override async Task InstallAsync(ModuleInstallationContext context)
    {
        await ImportLanguageResourcesAsync();
        await base.InstallAsync(context);
    }

    public override async Task UninstallAsync()
    {
        await DeleteLanguageResourcesAsync();
        await base.UninstallAsync();
    }
}
