# CommonsBase_Std

## Testing and Updating distribution scripts

On Windows only:

```sh
./dk0 -nosysinc --verbose distribute CommonsBase_Std-dist-win32 --library 'CommonsBase_Std@2.5.999911122233' --actual-in-place dist-win32.u
```

## Updating dk0 and dk0.cmd scripts

On Windows PowerShell (from the root of this repository):

```powershell
$ErrorActionPreference = "Stop"

$tmp = Join-Path $env:TEMP ("dk-" + [guid]::NewGuid().ToString())
git clone --depth 1 https://github.com/diskuv/dk.git $tmp

Copy-Item (Join-Path $tmp "dk0") -Destination ".\dk0" -Force
Copy-Item (Join-Path $tmp "dk0.cmd") -Destination ".\dk0.cmd" -Force

$dkVer = (Select-String -Path (Join-Path $tmp "dk0.cmd") -Pattern 'SET DK_VER=(.+)').Matches[0].Groups[1].Value.Trim()

Remove-Item $tmp -Recurse -Force

git commit -m "dk0 $dkVer" -- .\dk0 .\dk0.cmd
```
