# move current folder to where contains this .ps1 script file.
$scriptDir = Split-Path $MyInvocation.MyCommand.Path
pushd $scriptDir
[System.Reflection.Assembly]::LoadFile((Convert-Path "Ionic.Zip.dll")) > $null

# Compress project template contents into .zip file.
$projectTemplateDir = Join-Path $scriptDir "ItemTemplates\CSharp\Test"
if ((Test-Path $projectTemplateDir) -eq $false){
    mkdir $projectTemplateDir > $null
}
$zip = new-object Ionic.Zip.ZipFile
$zip.AddDirectory((Convert-Path 'Item Template Source'), "") > $null
$zip.Save((Join-Path $projectTemplateDir "xUnitTest.zip"))
$zip.Dispose()

# Get version infomation from reading manifest file.
$manifest = [xml](cat .\extension.vsixmanifest -Raw)
$ver = $manifest.PackageManifest.Metadata.Identity.Version
$packageId = $manifest.PackageManifest.Metadata.Identity.id
$displayName = $manifest.PackageManifest.Metadata.DisplayName
$description = $manifest.PackageManifest.Metadata.Description
$extensionDir = "[installdir]\Common7\IDE\Extensions\cxo3p5vn.yj3"
$vsixFileName = "xUnitTestItemTemplate"

# Create "manifest.json".
$baseDir = (pwd).Path
$srcFiles = @(ls (Join-Path $baseDir "ItemTemplates") -Recurse -File | % { $_.FullName })
$srcFiles += @("icon.png", "extension.vsixmanifest") | % { ls (Join-Path $baseDir $_) } | % { $_.FullName }
$files = $srcFiles | % {
  @{
    sha256 = (Get-FileHash $_ -Algorithm SHA256).Hash;
    fileName = $_.Substring($baseDir.Length).Replace("\","/");
  }
}

$manifestJson = @{
    id = $packageId;
    version = $ver;
    type =  "Vsix";
    language = "en-us";
    vsixId = $packageId;
    extensionDir = $extensionDir;
    files = $files;
    dependencies = @{
        "Microsoft.VisualStudio.Component.CoreEditor" = "[11.0,16.0)";
    }
}
$manifestJson | ConvertTo-Json -Compress | Out-File "manifest.json" -Encoding utf8


# Create "catalog.json"
$catalogJson = [PSCustomObject]@{
    manifestVersion = "1.1";
    info = @{
        id = "$packageId,version=$ver,language=en-us";
    };
    packages= @(
        @{
            id = "Component.$packageId";
            version = $ver;
            type =  "Component";
            language = "en-us";
            extension =  $true;
            dependencies = @{
                "$packageId" = @{
                    version =  "[$ver]";
                    language = "en-us";
                };
                "Microsoft.VisualStudio.Component.CoreEditor" = "[11.0,16.0)";
            };
            localizedResources = @(
                @{
                    language = "en-US";
                    title = $displayName;
                    description = $description;
                }
            );
        },
        @{
            id = $packageId;
            version = $ver;
            type = "Vsix";
            language = "en-us";
            payloads = @(
                @{
                    fileName = "$vsixFileName.vsix";
                    #size = ?;
                }
            );
            vsixId = $packageId;
            extensionDir = $extensionDir;
        }
    );
}
$catalogJson | ConvertTo-Json -Depth 100 -Compress | Out-File "catalog.json" -Encoding utf8


# Create .vsix a package with embedding version information.
$zip = new-object Ionic.Zip.ZipFile
$zip.AddFile((Convert-Path '.\`[Content_Types`].xml'), "") > $null
$zip.AddFile((Convert-Path .\extension.vsixmanifest), "") > $null
$zip.AddFile((Convert-Path .\manifest.json), "") > $null
$zip.AddFile((Convert-Path .\catalog.json), "") > $null
$zip.AddFile((Convert-Path .\icon.png), "") > $null
#$zip.AddFile((Convert-Path .\release-notes.txt), "") > $null
$zip.AddDirectory((Convert-Path .\ItemTemplates), "ItemTemplates") > $null
$zip.Save((Join-Path $scriptDir "$vsixFileName.$ver.vsix"))
#DEBUG: $zip.Save((Join-Path $scriptDir "xUnitTestItemTemplate.zip"))
$zip.Dispose()

# Clean up working files.
del .\ItemTemplates -Recurse -Force
