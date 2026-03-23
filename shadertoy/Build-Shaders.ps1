param (
    $shader = $null
)
    
function Get-BufferInputs {
    param (
        $buffer
    )

    # sort inputs by channel
    $inputs = $buffer.inputs | Sort-Object -Property channel | ForEach-Object {
        $inputObj = @{
            channel = $_.channel
            type = $_.type -eq "buffer" ? 
                $_.filepath -like "*/buffer00*" ? 
                    "bufferA" :
                    $_.filepath -like "*/buffer01*" ? 
                    "bufferB" :
                    $_.filepath -like "*/buffer02*" ? 
                        "bufferC" : 
                        $_.filepath -like "*/buffer03*" ? 
                        "bufferD" : 
                        "unknown" :
                $_.type
            sampler = $_.sampler
        }
        $filepath = $_.filepath -like "/media/a/*" ? $_.filepath : $null
        if ($null -ne $filepath) {
            $inputObj.filepath = $filepath
        }
        $inputObj
    }

    return $inputs
}

$shaders_all = Get-Content .\shaders_all.json | ConvertFrom-Json

if ($null -ne $shader) {
    $shaders_all.shaders = $shaders_all.shaders | Where-Object { $_.info.id -eq $shader } 
}

New-Item -Path "shaders" -ItemType Directory -Force | Out-Null

foreach ($shader in $shaders_all.shaders) {
    Write-Host "Parsing $($shader.info.id)"

    New-Item -Path "examples/$($shader.info.id)" -ItemType Directory -Force | Out-Null

    $common = $shader.renderpass | Where-Object { $_.type -eq "common" }
    $image = $shader.renderpass | Where-Object { $_.type -eq "image" }
    $bufferA = $shader.renderpass | Where-Object { $_.name -eq "Buffer A" }
    $bufferB = $shader.renderpass | Where-Object { $_.name -eq "Buffer B" }
    $bufferC = $shader.renderpass | Where-Object { $_.name -eq "Buffer C" }
    $bufferD = $shader.renderpass | Where-Object { $_.name -eq "Buffer D" }
    $cubeA = $shader.renderpass | Where-Object { $_.name -eq "Cube A" }
    $sound = $shader.renderpass | Where-Object { $_.name -eq "Sound" }

    $shaderInfo = [ordered]@{
        id = $shader.info.id
    }
    if ($null -ne $common) {
        $shaderInfo.common = $null -ne $common
    }
    if ($null -ne $bufferA) {
        $shaderInfo.bufferA = @{
            inputs = @(Get-BufferInputs $bufferA)
        }
    }
    if ($null -ne $bufferB) {
        $shaderInfo.bufferB = @{
            inputs = @(Get-BufferInputs $bufferB)
        }
    }
    if ($null -ne $bufferC) {
        $shaderInfo.bufferC = @{
            inputs = @(Get-BufferInputs $bufferC)
        }
    }
    if ($null -ne $bufferD) {
        $shaderInfo.bufferD = @{
            inputs = @(Get-BufferInputs $bufferD)
        }
    }
    if ($null -ne $cubeA) {
        $shaderInfo.cubeA = @{
            inputs = @(Get-BufferInputs $cubeA)
        }
    }
    if ($null -ne $sound) {
        $shaderInfo.sound = @{
            inputs = @(Get-BufferInputs $sound)
        }
    }

    $shaderInfo.image = @{
        inputs = @(Get-BufferInputs $image)
    }

    $shaderInfo | ConvertTo-Json -Depth 10 | Set-Content -Path "examples/$($shader.info.id)/shader.json" -Encoding UTF8

    if ($null -ne $common.code) {
        $common.code | Set-Content -Path "examples/$($shader.info.id)/common.glsl" -Encoding UTF8
    }
    if ($null -ne $image.code) {
        $image.code | Set-Content -Path "examples/$($shader.info.id)/image.glsl" -Encoding UTF8
    }
    if ($null -ne $bufferA.code) {
        $bufferA.code | Set-Content -Path "examples/$($shader.info.id)/bufferA.glsl" -Encoding UTF8
    }
    if ($null -ne $bufferB.code) {
        $bufferB.code | Set-Content -Path "examples/$($shader.info.id)/bufferB.glsl" -Encoding UTF8
    }
    if ($null -ne $bufferC.code) {
        $bufferC.code | Set-Content -Path "examples/$($shader.info.id)/bufferC.glsl" -Encoding UTF8
    }
    if ($null -ne $bufferD.code) {
        $bufferD.code | Set-Content -Path "examples/$($shader.info.id)/bufferD.glsl" -Encoding UTF8
    }
    if ($null -ne $cubeA.code) {
        $cubeA.code | Set-Content -Path "examples/$($shader.info.id)/cubeA.glsl" -Encoding UTF8
    }
    if ($null -ne $cubeA.code) {
        $cubeA.code | Set-Content -Path "examples/$($shader.info.id)/cubeA.glsl" -Encoding UTF8
    }
    if ($null -ne $sound.code) {
        $sound.code | Set-Content -Path "examples/$($shader.info.id)/sound.glsl" -Encoding UTF8
    }

    foreach ($renderpass in $shader.renderpass) {

        foreach ($shaderInput in $renderpass.inputs) {
            if ($shaderInput.filepath -notlike "*/previz/*" -and $shaderInput.type -ne "keyboard" -and $shaderInput.type -ne "webcam") {
                #Download the input file if it does not exist
                if ($shaderInput.filepath.StartsWith("/")) {
                    $input_path = ".$($shaderInput.filepath)"
                } else {
                    Write-Host "Skip $($shaderInput.filepath) for $($shader.info.id)/$($renderpass.name)"
                    continue
                }
                if (-not (Test-Path -Path $input_path)) {
                    Write-Host "Downloading $input_path"
                    $input_url = "https://www.shadertoy.com$($shaderInput.filepath)"
                    $input_dir = Split-Path -Path $input_path -Parent
                    New-Item -Path $input_dir -ItemType Directory -Force | Out-Null
                    Invoke-WebRequest -Uri $input_url -OutFile $input_path
                }
            }
        }

    }
}