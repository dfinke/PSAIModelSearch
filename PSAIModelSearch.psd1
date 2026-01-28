@{
    RootModule        = 'PSAIModelSearch.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '8f7b6a2f-8e9d-45f0-9f6c-4b8b3d2f7e1a'
    Author            = 'dfinke'
    CompanyName       = ''
    Copyright         = '(c) 2026 dfinke. All rights reserved.'
    Description       = 'Search and inspect models.dev API catalog data.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Search-AIModel', 'Get-AIModelsByReleaseDate')
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('models.dev', 'models', 'ai', 'catalog', 'search')
            ProjectUri   = 'https://models.dev'
            LicenseUri   = 'https://models.dev'
            ReleaseNotes = 'Added Get-AIModelsByReleaseDate function for date-based filtering.'
        }
    }
}
