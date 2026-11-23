# Compresses a video with PowerPoint's own encoder (MediaFormat.Resample = File > Info > Compress Media)
# and writes the result as a standalone MP4 (H.264). Used for the digital-twin video of the deck.
# Usage: powershell -File compress_video.ps1 -Video in.mp4 -OutMp4 out.mp4 [-Width 1920 -Height 1080]
# PowerPoint treats VideoBitRate as a cap only: a 77 s 1080p screen recording comes out at ~3 MB.
param(
    [Parameter(Mandatory = $true)][string]$Video,
    [Parameter(Mandatory = $true)][string]$OutMp4,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [int]$FrameRate = 30,
    [int]$BitRate = 20000000
)
$Video = (Resolve-Path $Video).Path
$work = Join-Path $env:TEMP ("resample_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$tmpPptx = Join-Path $work "original.pptx"
$outPptx = Join-Path $work "resampled.pptx"
$app = New-Object -ComObject PowerPoint.Application
try {
    $pres = $app.Presentations.Add(0)
    $pres.PageSetup.SlideWidth = 960
    $pres.PageSetup.SlideHeight = 540
    $slide = $pres.Slides.Add(1, 12)
    $shp = $slide.Shapes.AddMediaObject2($Video, 0, -1, 0, 0, 960, 540)
    $pres.SaveAs($tmpPptx)
    $shp.MediaFormat.Resample(0, $Height, $Width, $FrameRate, 48000, $BitRate)
    $t0 = Get-Date
    do {
        Start-Sleep -Seconds 2
        $st = $shp.MediaFormat.ResamplingStatus
    } while (($st -eq 1 -or $st -eq 2) -and ((Get-Date) - $t0).TotalMinutes -lt 20)
    Write-Output ("Resampling status {0} after {1:N0} s" -f $st, ((Get-Date) - $t0).TotalSeconds)
    if ($st -ne 3) { throw "Resampling did not finish (status $st)" }
    $pres.SaveAs($outPptx)   # Save() keeps the original media in the file, SaveAs writes the resampled one
    $pres.Close()
}
finally {
    if ($app.Presentations.Count -eq 0) { $app.Quit() }
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($outPptx)
try {
    $entry = $zip.Entries | Where-Object { $_.FullName -like "ppt/media/*.mp4" } | Sort-Object Length -Descending | Select-Object -First 1
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $OutMp4, $true)
}
finally { $zip.Dispose() }
Remove-Item -Recurse -Force $work
Write-Output ("{0}: {1:N1} MB" -f $OutMp4, ((Get-Item $OutMp4).Length / 1MB))
