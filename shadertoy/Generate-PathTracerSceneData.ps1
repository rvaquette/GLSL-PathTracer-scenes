param(
    [string]$BaseDir = ".\shadertoy\examples\glsl-pathtracer"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-Number {
    param([string]$Text)

    $value = $Text.Trim()
    if ($value -match '^-?\d+$') {
        return [int]$value
    }

    if ($value -match '^-?\d+(?:\.\d+)?(?:[eE][+\-]?\d+)?$') {
        return [double]$value
    }

    return $value
}

function Parse-VectorLiteral {
    param([string]$Text)

    if ($Text -match 'vec[234]\s*\(([^\)]+)\)') {
        $components = $Matches[1].Split(',')
        $values = @()
        foreach ($component in $components) {
            $values += [double]($component.Trim())
        }
        return $values
    }

    return $null
}

function Parse-BooleanLiteral {
    param([string]$Text)

    $value = $Text.Trim().ToLowerInvariant()
    if ($value -eq 'true') {
        return $true
    }

    if ($value -eq 'false') {
        return $false
    }

    return $null
}

function Parse-GlslLiteral {
    param(
        [string]$Type,
        [string]$Text
    )

    if ($Type -match '^vec[234]$') {
        $vector = Parse-VectorLiteral -Text $Text
        if ($null -ne $vector) {
            return $vector
        }
        return $Text.Trim()
    }

    if ($Type -eq 'int' -or $Type -eq 'float') {
        return Parse-Number -Text $Text
    }

    if ($Type -eq 'bool') {
        $boolValue = Parse-BooleanLiteral -Text $Text
        if ($null -ne $boolValue) {
            return $boolValue
        }
        return $Text.Trim()
    }

    return $Text.Trim()
}

function Parse-BufferA {
    param([string]$FilePath)

    $result = [ordered]@{
        eye = $null
        lookat = $null
        fov = $null
    }

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $result
    }

    $content = Get-Content -LiteralPath $FilePath -Raw

    if ($content -match '(?m)^\s*vec3\s+eye\s*=\s*(vec3\s*\([^;]+\))\s*;') {
        $result.eye = Parse-VectorLiteral -Text $Matches[1]
    }

    if ($content -match '(?m)^\s*vec3\s+lookat\s*=\s*(vec3\s*\([^;]+\))\s*;') {
        $result.lookat = Parse-VectorLiteral -Text $Matches[1]
    }

    if ($content -match '(?m)^\s*float\s+fov\s*=\s*([^;]+);') {
        $result.fov = Parse-Number -Text $Matches[1]
    }

    return $result
}

function Parse-BufferD {
    param([string]$FilePath)

    $result = [ordered]@{}

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $result
    }

    $content = Get-Content -LiteralPath $FilePath -Raw
    $settingMatches = [regex]::Matches(
        $content,
        '(?m)^\s*(vec[234]|float|int|bool)\s+([A-Za-z_]\w*)\s*=\s*([^;]+);'
    )

    foreach ($m in $settingMatches) {
        $type = $m.Groups[1].Value
        $name = $m.Groups[2].Value
        $rawValue = $m.Groups[3].Value.Trim()
        $result[$name] = Parse-GlslLiteral -Type $type -Text $rawValue
    }

    return $result
}

function Parse-CommonCode {
    param([string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return @()
    }

    $content = Get-Content -LiteralPath $FilePath -Raw
    $defines = @()

    $defineMatches = [regex]::Matches(
        $content,
        '(?m)^\s*#define\s+(\S+(?:[^\S\r\n]+\S+)*)\s*$'
    )

    foreach ($m in $defineMatches) {
        # Ignore OPT_USE_MESHDATA_BLOB
        if ($m.Groups[1].Value.Trim() -eq 'OPT_USE_MESHDATA_BLOB') {
            continue
        }
        $defines += $m.Groups[1].Value.Trim()
    }

    return $defines
}

function Get-NormalizedSceneName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return ''
    }

    return (($Name -replace '[^A-Za-z0-9]', '').ToLowerInvariant())
}

function Parse-SceneRendererSettings {
    param([string]$FilePath)

    $result = [ordered]@{}

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $result
    }

    $content = Get-Content -LiteralPath $FilePath -Raw

    if ($content -match '(?m)^\s*resolution\s+([+\-]?\d+(?:\.\d+)?)\s+([+\-]?\d+(?:\.\d+)?)\s*$') {
        $result.resolution = @(
            $(Parse-Number -Text $Matches[1]),
            $(Parse-Number -Text $Matches[2])
        )
    }

    if ($content -match '(?m)^\s*tilewidth\s+([+\-]?\d+(?:\.\d+)?)\s*$') {
        $result.tileWidth = Parse-Number -Text $Matches[1]
    }

    if ($content -match '(?m)^\s*tileheight\s+([+\-]?\d+(?:\.\d+)?)\s*$') {
        $result.tileHeight = Parse-Number -Text $Matches[1]
    }

    return $result
}

function Parse-SceneAssets {
    param([string]$FilePath)

    $result = [ordered]@{
        materials = @()
        meshes = @()
    }

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $result
    }

    $content = Get-Content -LiteralPath $FilePath -Raw

    $materialMatches = [regex]::Matches(
        $content,
        '(?m)^\s*material\s+([^\s\{]+)\s*\{'
    )

    foreach ($materialMatch in $materialMatches) {
        $result.materials += $materialMatch.Groups[1].Value.Trim()
    }

    $meshMatches = [regex]::Matches(
        $content,
        '(?s)mesh\s*\{(.*?)\}'
    )

    foreach ($meshMatch in $meshMatches) {
        $meshBlock = $meshMatch.Groups[1].Value
        $meshFile = $null
        $meshMaterial = $null

        if ($meshBlock -match '(?m)^\s*file\s+(.+?)\s*$') {
            $meshFile = Split-Path -Leaf $Matches[1].Trim()
        }

        if ($meshBlock -match '(?m)^\s*material\s+([^\s#]+)') {
            $meshMaterial = $Matches[1].Trim()
        }

        $result.meshes += [ordered]@{
            name = $meshFile
            material = $meshMaterial
        }
    }

    return $result
}

function Test-SceneHasTextures {
    param([string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $true
    }

    $content = Get-Content -LiteralPath $FilePath -Raw
    return [bool]($content -match '(?m)^\s*\w*texture\s+\S+')
}

function Parse-BufferB {
    param([string]$FilePath)

    $result = [ordered]@{
        uniforms = [ordered]@{}
        texIndices = [ordered]@{}
        namedIndices = [ordered]@{}
    }

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $result
    }

    $content = Get-Content -LiteralPath $FilePath -Raw

    $defineMatches = [regex]::Matches(
        $content,
        '(?m)^\s*#define\s+([A-Za-z_]\w*)\s+\(\s*([+\-]?\d+)\s*\+\s*MESH_DATA_OFFSET\s*\)'
    )

    foreach ($m in $defineMatches) {
        $name = $m.Groups[1].Value
        $indexValue = [int]$m.Groups[2].Value
        $result.namedIndices[$name] = $indexValue

        # Keep texture indices and BVH-related define indices in the exported indices object.
        if ($name -like '*Tex' -or $name -match 'BVH') {
            $result.texIndices[$name] = $indexValue
        }
    }

    $uniformMatches = [regex]::Matches(
        $content,
        '(?m)^\s*(vec[234]|float|int|bool)\s+([A-Za-z_]\w*)\s*=\s*([^;]+);'
    )

    foreach ($m in $uniformMatches) {
        $uType = $m.Groups[1].Value
        $uName = $m.Groups[2].Value
        $uRawValue = $m.Groups[3].Value.Trim()
        $result.uniforms[$uName] = Parse-GlslLiteral -Type $uType -Text $uRawValue
    }

    # Compatibility key if user expects uniformsLightCol naming.
    if ($result.uniforms.Contains('uniformLightCol') -and -not $result.uniforms.Contains('uniformsLightCol')) {
        $result.uniforms['uniformsLightCol'] = $result.uniforms['uniformLightCol']
    }

    return $result
}

if (-not (Test-Path -LiteralPath $BaseDir)) {
    throw "BaseDir introuvable: $BaseDir"
}

$resolvedBaseDir = (Resolve-Path -LiteralPath $BaseDir).Path
$sceneDirs = Get-ChildItem -LiteralPath $resolvedBaseDir -Directory | Sort-Object Name

$pathtracerDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'pathtracer'
$sceneFileByNormalizedName = @{}
if (Test-Path -LiteralPath $pathtracerDir) {
    $sceneFiles = Get-ChildItem -LiteralPath $pathtracerDir -Filter '*.scene' -File
    foreach ($sceneFile in $sceneFiles) {
        $normalizedName = Get-NormalizedSceneName -Name $sceneFile.BaseName
        if (-not [string]::IsNullOrWhiteSpace($normalizedName) -and -not $sceneFileByNormalizedName.ContainsKey($normalizedName)) {
            $sceneFileByNormalizedName[$normalizedName] = $sceneFile.FullName
        }
    }
}

if ($sceneDirs.Count -eq 0) {
    Write-Warning "Aucun sous-repertoire trouve dans $resolvedBaseDir"
    exit 0
}

$summary = @()

foreach ($sceneDir in $sceneDirs) {
    Write-Host "Traitement de la scene: $($sceneDir.Name)" -ForegroundColor Cyan

    $bufferAPath = Join-Path $sceneDir.FullName 'bufferACode.glsl'
    $bufferBPath = Join-Path $sceneDir.FullName 'bufferBCode.glsl'
    $bufferDPath = Join-Path $sceneDir.FullName 'bufferDCode.glsl'
    $commonCodePath = Join-Path $sceneDir.FullName 'commonCode.glsl'

    $bufferAData = Parse-BufferA -FilePath $bufferAPath
    $bufferBData = Parse-BufferB -FilePath $bufferBPath
    $bufferDData = Parse-BufferD -FilePath $bufferDPath
    $commonDefines = Parse-CommonCode -FilePath $commonCodePath

    $sceneRendererSettings = [ordered]@{}
    $sceneAssets = [ordered]@{
        materials = @()
        meshes = @()
    }
    $normalizedSceneName = Get-NormalizedSceneName -Name $sceneDir.Name
    if ($sceneFileByNormalizedName.ContainsKey($normalizedSceneName)) {
        $sceneRendererSettings = Parse-SceneRendererSettings -FilePath $sceneFileByNormalizedName[$normalizedSceneName]
        $sceneAssets = Parse-SceneAssets -FilePath $sceneFileByNormalizedName[$normalizedSceneName]
    }

    $withTexture = $true
    if ($sceneFileByNormalizedName.ContainsKey($normalizedSceneName)) {
        $withTexture = Test-SceneHasTextures -FilePath $sceneFileByNormalizedName[$normalizedSceneName]
    }

    $data = [ordered]@{
        scene = $sceneDir.Name
        camera = [ordered]@{
            eye = $bufferAData.eye
            lookat = $bufferAData.lookat
            fov = $bufferAData.fov
        }
        uniforms = $bufferBData.uniforms
        indices = $bufferBData.texIndices
        display = $bufferDData
        defines = $commonDefines
        withTexture = $withTexture
        materials = $sceneAssets.materials
        meshes = $sceneAssets.meshes
    }

    if ($sceneRendererSettings.Contains('resolution')) {
        $data.resolution = $sceneRendererSettings.resolution
    }

    if ($sceneRendererSettings.Contains('tileWidth')) {
        $data.tileWidth = $sceneRendererSettings.tileWidth
    }

    if ($sceneRendererSettings.Contains('tileHeight')) {
        $data.tileHeight = $sceneRendererSettings.tileHeight
    }

    $jsonPath = Join-Path $sceneDir.FullName 'data.json'
    $jsonContent = $data | ConvertTo-Json -Depth 12
    Set-Content -LiteralPath $jsonPath -Value $jsonContent -Encoding UTF8

    $summary += [pscustomobject]@{
        Scene = $sceneDir.Name
        JsonPath = $jsonPath
    }
}

$summary | Format-Table -AutoSize
Write-Host "`nTermine. Scenes traitees: $($summary.Count)" -ForegroundColor Green

# Aggregate all per-scene data.json files into a single scenes.json
$allDataPath = Join-Path $BaseDir 'scenes.json'
$allItems = Get-ChildItem -LiteralPath $BaseDir -Directory | Sort-Object Name | ForEach-Object {
    $p = Join-Path $_.FullName 'data.json'
    if (Test-Path -LiteralPath $p) { Get-Content -LiteralPath $p -Raw | ConvertFrom-Json }
}
$allItems | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $allDataPath -Encoding UTF8
Write-Host "scenes.json written: $($allItems.Count) entries -> $allDataPath" -ForegroundColor Green

