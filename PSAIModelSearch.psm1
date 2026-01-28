# PSAIModelSearch PowerShell module

function Convert-ToDateTimeIfPossible {
    param($Value)
    if ($Value -is [string]) {
        try {
            $parsed = [DateTime]::Parse($Value)
            return $parsed
        }
        catch {
            return $Value
        }
    }
    return $Value
}

function Format-Modalities {
    param(
        $Modalities,
        [string]$Key
    )

    if ($null -eq $Modalities) { return '' }

    $value = $Modalities.$Key
    if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
        return ($value | ForEach-Object { $_.ToString() }) -join ', '
    }

    if ($null -ne $value) { return $value.ToString() }
    return ''
}

function Format-ModelsTable {
    param(
        $Models
    )

    $Models |
    Sort-Object provider_name, id |
    ForEach-Object {
        [pscustomobject]@{
            Provider   = $_.provider_name
            Model      = $_.name
            Family     = $_.family
            ProviderId = $_.provider_id
            ModelId    = $_.id
            ToolCall   = if ($null -ne $_.tool_call) { $_.tool_call } else { '' }
            Reasoning  = if ($null -ne $_.reasoning) { $_.reasoning } else { '' }
            Input      = Format-Modalities -Modalities $_.modalities -Key 'input'
            Output     = Format-Modalities -Modalities $_.modalities -Key 'output'
            InputCost  = if ($null -ne $_.cost -and $null -ne $_.cost.input) { $_.cost.input } else { '' }
        }
    } |
    Format-Table -AutoSize
}

function Search-AIModel {
    <#
    .SYNOPSIS
    Downloads models.dev API data and searches for matching models, or returns all models if no query is specified.

    .DESCRIPTION
    Fetches https://models.dev/api.json (cached locally) and searches for matches
    by substring across string properties. Returns full model objects for matches.
    If no Query is provided, returns all available models.

    .PARAMETER Query
    Search string (case-insensitive substring match). If omitted, returns all models.

    .PARAMETER Refresh
    Force refresh from remote endpoint even if cache exists.

    .PARAMETER PassThru
    Return full model objects instead of the summary table.

    .PARAMETER Table
    Output a formatted table similar to the models.dev UI.

    .PARAMETER Deep
    Perform deep recursive search across all nested fields (slower).

    .PARAMETER Fields
    Top-level fields to search when not using -Deep (faster).

    .PARAMETER FlatCachePath
    Path to flattened cache (CLIXML). Defaults to model-flat.clixml next to this module.

    .PARAMETER NoFlatCache
    Disable flattened cache usage.

    .PARAMETER CachePath
    Path to cache file. Defaults to model.json alongside this module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Query = "",

        [switch]$Refresh,

        [switch]$PassThru,

        [switch]$Table,

        [switch]$Deep,

        [string[]]$Fields = @('id', 'name', 'provider_name', 'provider_id', 'family'),

        [string]$FlatCachePath = (Join-Path $PSScriptRoot 'model-flat.clixml'),

        [switch]$NoFlatCache,

        [string]$CachePath = (Join-Path $PSScriptRoot 'model.json')
    )

    function Get-ModelsData {
        param(
            [string]$Path,
            [switch]$ForceRefresh
        )

        $needsFetch = $ForceRefresh -or -not (Test-Path $Path)

        if (-not $needsFetch) {
            $content = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
            if (-not $content) {
                $needsFetch = $true
            }
        }

        if ($needsFetch) {
            Write-Host "Fetching data from https://models.dev/api.json..." -ForegroundColor Cyan
            $data = Invoke-RestMethod -Uri 'https://models.dev/api.json' -Method Get
            $json = $data | ConvertTo-Json -Depth 100
            $json | Set-Content -Path $Path -Encoding UTF8
            return $data
        }

        return Get-Content -Path $Path -Raw | ConvertFrom-Json
    }

    function Get-ModelsFromProvider {
        param(
            $Provider,
            [string]$ProviderId
        )

        if ($null -eq $Provider -or -not ($Provider.PSObject.Properties.Name -contains 'models')) {
            return @()
        }

        $providerName = $Provider.name
        $providerApi = $Provider.api
        $providerNpm = $Provider.npm
        $providerDoc = $Provider.doc
        $providerEnv = $Provider.env

        $models = $Provider.models
        $items = @()

        foreach ($prop in $models.PSObject.Properties) {
            $model = $prop.Value
            if ($null -eq $model) { continue }

            $model | Add-Member -NotePropertyName provider_id -NotePropertyValue $ProviderId -Force
            $model | Add-Member -NotePropertyName provider_name -NotePropertyValue $providerName -Force
            $model | Add-Member -NotePropertyName provider_api -NotePropertyValue $providerApi -Force
            $model | Add-Member -NotePropertyName provider_npm -NotePropertyValue $providerNpm -Force
            $model | Add-Member -NotePropertyName provider_doc -NotePropertyValue $providerDoc -Force
            $model | Add-Member -NotePropertyName provider_env -NotePropertyValue $providerEnv -Force

            # Convert date-like strings to DateTime
            foreach ($prop in $model.PSObject.Properties) {
                $model.($prop.Name) = Convert-ToDateTimeIfPossible $prop.Value
            }

            $items += $model
        }

        return $items
    }

    function Get-ModelCollection {
        param(
            $Data
        )

        if ($null -eq $Data) { return @() }

        if ($Data.PSObject.Properties.Name -contains 'models') {
            return Get-ModelsFromProvider -Provider $Data -ProviderId $Data.id
        }

        if ($Data -is [psobject]) {
            $all = @()
            foreach ($prop in $Data.PSObject.Properties) {
                $provider = $prop.Value
                $all += Get-ModelsFromProvider -Provider $provider -ProviderId $prop.Name
            }
            if ($all.Count -gt 0) { return $all }
        }

        if ($Data -is [System.Collections.IDictionary]) {
            $all = @()
            foreach ($key in $Data.Keys) {
                $provider = $Data[$key]
                $all += Get-ModelsFromProvider -Provider $provider -ProviderId $key
            }
            return $all
        }

        if ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string])) {
            return @($Data)
        }

        return @($Data)
    }

    function Test-ValueMatch {
        param(
            $Value,
            [string]$Search
        )

        if ($null -eq $Value) { return $false }

        if ($Value -is [string]) {
            return $Value.IndexOf($Search, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        }

        if ($Value -is [System.Collections.IDictionary]) {
            foreach ($key in $Value.Keys) {
                if (Test-ValueMatch -Value $key -Search $Search) { return $true }
                if (Test-ValueMatch -Value $Value[$key] -Search $Search) { return $true }
            }
            return $false
        }

        if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
            foreach ($v in $Value) {
                if (Test-ValueMatch -Value $v -Search $Search) { return $true }
            }
            return $false
        }

        foreach ($prop in $Value.PSObject.Properties) {
            if (Test-ValueMatch -Value $prop.Value -Search $Search) { return $true }
        }

        return $false
    }

    function Test-ModelMatch {
        param(
            $Item,
            [string]$Search
        )

        return (Test-ValueMatch -Value $Item -Search $Search)
    }

    function Test-ModelMatchShallow {
        param(
            $Item,
            [string]$Search,
            [string[]]$FieldList
        )

        foreach ($field in $FieldList) {
            if ($null -eq $Item) { continue }
            if (-not ($Item.PSObject.Properties.Name -contains $field)) { continue }
            $value = $Item.$field
            if ($null -ne $value -and $value.ToString().IndexOf($Search, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                return $true
            }
        }

        return $false
    }

    function Format-Modalities {
        param(
            $Modalities,
            [string]$Key
        )

        if ($null -eq $Modalities) { return '' }

        $value = $Modalities.$Key
        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            return ($value | ForEach-Object { $_.ToString() }) -join ', '
        }

        if ($null -ne $value) { return $value.ToString() }
        return ''
    }

    function Format-ModelsTable {
        param(
            $Models
        )

        $Models |
        Sort-Object provider_name, id |
        ForEach-Object {
            [pscustomobject]@{
                Provider   = $_.provider_name
                Model      = $_.name
                Family     = $_.family
                ProviderId = $_.provider_id
                ModelId    = $_.id
                ToolCall   = if ($null -ne $_.tool_call) { $_.tool_call } else { '' }
                Reasoning  = if ($null -ne $_.reasoning) { $_.reasoning } else { '' }
                Input      = Format-Modalities -Modalities $_.modalities -Key 'input'
                Output     = Format-Modalities -Modalities $_.modalities -Key 'output'
                InputCost  = if ($null -ne $_.cost -and $null -ne $_.cost.input) { $_.cost.input } else { '' }
            }
        } |
        Format-Table -AutoSize
    }

    function Get-ModelsList {
        param(
            [string]$Path,
            [string]$FlatPath,
            [switch]$ForceRefresh,
            [switch]$DisableFlat
        )

        if (-not $DisableFlat -and -not $ForceRefresh -and (Test-Path $FlatPath)) {
            if (Test-Path $Path) {
                $flatTime = (Get-Item $FlatPath).LastWriteTimeUtc
                $srcTime = (Get-Item $Path).LastWriteTimeUtc
                if ($flatTime -ge $srcTime) {
                    return Import-Clixml -Path $FlatPath
                }
            }
            else {
                return Import-Clixml -Path $FlatPath
            }
        }

        $data = Get-ModelsData -Path $Path -ForceRefresh:$ForceRefresh
        Write-Host "Processing models..." -ForegroundColor Cyan
        $models = Get-ModelCollection -Data $data

        if (-not $DisableFlat) {
            Write-Host "Saving cache..." -ForegroundColor Cyan
            $models | Export-Clixml -Path $FlatPath
        }

        return $models
    }

    $models = Get-ModelsList -Path $CachePath -FlatPath $FlatCachePath -ForceRefresh:$Refresh -DisableFlat:$NoFlatCache

    $matches = if ([string]::IsNullOrEmpty($Query)) {
        $models
    }
    else {
        if ($Deep) {
            $models | Where-Object { Test-ModelMatch -Item $_ -Search $Query }
        }
        else {
            $models | Where-Object { Test-ModelMatchShallow -Item $_ -Search $Query -FieldList $Fields }
        }
    }

    if (-not $matches -and -not [string]::IsNullOrEmpty($Query)) {
        Write-Host "No matches found for '$Query'." -ForegroundColor Yellow
        return
    }

    if ($Table -and -not $PassThru) {
        Format-ModelsTable -Models $matches
        return
    }

    $matches
}

function Get-AIModelsByReleaseDate {
    <#
    .SYNOPSIS
    Retrieves AI models filtered by release date.

    .DESCRIPTION
    Fetches models from the models.dev API and filters them based on release date criteria.
    Supports filtering by last N days, date range, or specific dates.

    .PARAMETER LastDays
    Return models released in the last N days.

    .PARAMETER FromDate
    Return models released on or after this date.

    .PARAMETER ToDate
    Return models released on or before this date.

    .PARAMETER Refresh
    Force refresh from remote endpoint even if cache exists.

    .PARAMETER PassThru
    Return full model objects instead of the summary table.

    .PARAMETER Table
    Output a formatted table similar to the models.dev UI.

    .PARAMETER Deep
    Perform deep recursive search across all nested fields (slower).

    .PARAMETER Fields
    Top-level fields to search when not using -Deep (faster).

    .PARAMETER FlatCachePath
    Path to flattened cache (CLIXML). Defaults to model-flat.clixml next to this module.

    .PARAMETER NoFlatCache
    Disable flattened cache usage.

    .PARAMETER CachePath
    Path to cache file. Defaults to model.json alongside this module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$LastDays,

        [Parameter(Mandatory = $false)]
        [DateTime]$FromDate,

        [Parameter(Mandatory = $false)]
        [DateTime]$ToDate,

        [switch]$Refresh,

        [switch]$PassThru,

        [switch]$Table,

        [switch]$Deep,

        [string[]]$Fields = @('id', 'name', 'provider_name', 'provider_id', 'family'),

        [string]$FlatCachePath = (Join-Path $PSScriptRoot 'model-flat.clixml'),

        [switch]$NoFlatCache,

        [string]$CachePath = (Join-Path $PSScriptRoot 'model.json')
    )

    # Get all models
    $allModels = Search-AIModel -Refresh:$Refresh -PassThru -Deep:$Deep -Fields $Fields -FlatCachePath $FlatCachePath -NoFlatCache:$NoFlatCache -CachePath $CachePath

    # Filter by date
    $filteredModels = $allModels | Where-Object {
        $model = $_
        $releaseDate = $model.release_date

        # Skip if no release date
        if ($null -eq $releaseDate -or -not ($releaseDate -is [DateTime])) {
            return $false
        }

        $include = $true

        if ($LastDays -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$LastDays)
            $include = $include -and ($releaseDate -ge $cutoffDate)
        }

        if ($PSBoundParameters.ContainsKey('FromDate')) {
            $include = $include -and ($releaseDate -ge $FromDate)
        }

        if ($PSBoundParameters.ContainsKey('ToDate')) {
            $include = $include -and ($releaseDate -le $ToDate)
        }

        return $include
    }

    if ($Table -and -not $PassThru) {
        Format-ModelsTable -Models $filteredModels
        return
    }

    $filteredModels
}

Export-ModuleMember -Function Search-AIModel, Get-AIModelsByReleaseDate
