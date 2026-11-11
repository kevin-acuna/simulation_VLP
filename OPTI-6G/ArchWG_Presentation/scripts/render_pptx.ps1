param(
    [Parameter(Mandatory = $true)][string]$PptxPath,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [int]$Width = 1600
)
$PptxPath = (Resolve-Path $PptxPath).Path
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
Get-ChildItem -Path $OutDir -Filter "slide_*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
$app = New-Object -ComObject PowerPoint.Application
try {
    $pres = $app.Presentations.Open($PptxPath, $true, $false, $false)
    $h = [int]($Width * $pres.PageSetup.SlideHeight / $pres.PageSetup.SlideWidth)
    $i = 1
    foreach ($s in $pres.Slides) {
        $fn = Join-Path $OutDir ("slide_{0:D2}.png" -f $i)
        $s.Export($fn, "PNG", $Width, $h)
        $i++
    }
    $pres.Close()
    Write-Output "Exported $($i-1) slides to $OutDir"
}
finally {
    if ($app.Presentations.Count -eq 0) { $app.Quit() }
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
}
