# PSAIModelSearch

A PowerShell module for searching and exploring AI models from the [models.dev](https://models.dev) API catalog.

## Features

- **Substring Search**: Find models by partial matches across multiple fields (ID, name, provider, family, etc.)
- **Flexible Output**: Return full model objects for scripting or formatted tables for quick viewing
- **Performance Optimized**: Uses local caching with CLIXML for fast repeated queries
- **Date Handling**: Automatically converts date strings to DateTime objects for proper filtering
- **Deep Search**: Option for recursive search across all nested fields

## Installation

### From Local Files

1. Download `PSAIModelSearch.psd1` and `PSAIModelSearch.psm1`
2. Place them in the same directory
3. Import the module:

```powershell
Import-Module .\PSAIModelSearch.psd1
```

### From PowerShell Gallery

```powershell
Install-Module PSAIModelSearch
```

## Usage

### Basic Search

```powershell
# Import the module
Import-Module .\PSAIModelSearch.psd1

# Search for models containing "gpt-4"
Search-AIModel -Query "gpt-4"
```

### Return All Models

```powershell
# Get all available models
Search-AIModel
```

### Table Output

```powershell
Search-AIModel -Query "gpt" -Table
```

### Advanced Filtering

```powershell
# Get models as objects and filter by date
Search-AIModel -Query "gpt-4o" | Where-Object { $_.release_date -gt [DateTime]::Parse("1/1/2025") } | Format-Table
```

### Deep Search

```powershell
# Search across all fields (slower but more thorough)
Search-AIModel -Query "openai" -Deep
```

### Refresh Cache

```powershell
# Force refresh from remote API
Search-AIModel -Query "claude" -Refresh
```

## Parameters

- **Query** (optional): Search string for substring matching. If not specified, returns all models.
- **Refresh**: Force download fresh data from API
- **PassThru**: Return raw objects (default when not using -Table)
- **Table**: Output formatted table instead of objects
- **Deep**: Perform deep recursive search across all fields
- **Fields**: Specify fields to search (default: id, name, provider_name, provider_id, family)
- **FlatCachePath**: Path to CLIXML cache file (default: model-flat.clixml)
- **NoFlatCache**: Disable CLIXML caching
- **CachePath**: Path to JSON cache file (default: model.json)

## Output

Returns PSCustomObject instances with model details including:
- Model metadata (id, name, family, etc.)
- Provider information (name, API, docs, etc.)
- Capabilities (modalities, tool calling, reasoning)
- Cost information
- Dates (automatically converted to DateTime)

## Caching

- **JSON Cache**: Raw API data in `model.json`
- **CLIXML Cache**: Processed models in `model-flat.clixml` for faster loading
- Caches are updated automatically when source data changes

## Examples

```powershell
# Find all GPT models
Search-AIModel gpt

# Get Claude models with table output
Search-AIModel claude -Table

# Find models supporting tool calling
Search-AIModel -Query "" -PassThru | Where-Object { $_.tool_call } | Select-Object name, provider_name

# Search specific fields only
Search-AIModel -Query "openai" -Fields name, provider_name
```

## Requirements

- PowerShell 5.1 or later
- Internet access for initial data fetch

## License

See [models.dev](https://models.dev) for API terms.

## Contributing

Issues and PRs welcome at the [GitHub repository](https://github.com/dfinke/PowerShellAIAssistant-ScratchPad).</content>
<parameter name="filePath">d:\mygit\PowerShellAIAssistant-ScratchPad\Anomalyco-models.dev\README.md