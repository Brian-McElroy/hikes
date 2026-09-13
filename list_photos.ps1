Add-Type -AssemblyName System.Drawing

$thumbWidth = 400

function New-Thumbnail {
    param($SourcePath, $DestPath)
    $img = [System.Drawing.Image]::FromFile($SourcePath)
    try {
        $ratio = $thumbWidth / $img.Width
        if ($ratio -gt 1) { $ratio = 1 }
        $newWidth = [int]($img.Width * $ratio)
        $newHeight = [int]($img.Height * $ratio)
        $thumb = New-Object System.Drawing.Bitmap $newWidth, $newHeight
        $graphics = [System.Drawing.Graphics]::FromImage($thumb)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 75L)
        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $thumb.Save($DestPath, $jpegCodec, $encoderParams)
        $graphics.Dispose()
        $thumb.Dispose()
    } finally {
        $img.Dispose()
    }
}

$dirs = Get-ChildItem -Directory | Where-Object { $_.Name -ne "thumbs" } | ForEach-Object {
    $folder = $_
    $latest = Get-ChildItem $folder.FullName -Filter *.jpg | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    [PSCustomObject]@{
        Name = $folder.Name
        Date = if ($latest) { $latest.LastWriteTime } else { [datetime]::MinValue }
    }
} | Sort-Object Date -Descending

$lines = @()
$lines += "const hikes = ["
foreach ($d in $dirs) {
    $thumbsDir = Join-Path $d.Name "thumbs"
    if (-not (Test-Path $thumbsDir)) {
        New-Item -ItemType Directory -Path $thumbsDir | Out-Null
    }

    $lines += "  {"
    $lines += "    title: `"$($d.Name)`","
    $lines += "    photos: ["
    Get-ChildItem $d.Name -Filter *.jpg | Sort-Object LastWriteTime | ForEach-Object {
        $sourceFile = $_
        $thumbPath = Join-Path $thumbsDir $sourceFile.Name

        if ((-not (Test-Path $thumbPath)) -or ((Get-Item $thumbPath).LastWriteTime -lt $sourceFile.LastWriteTime)) {
            New-Thumbnail -SourcePath $sourceFile.FullName -DestPath $thumbPath
        }

        $lines += "      { full: `"$($d.Name)/$($sourceFile.Name)`", thumb: `"$($d.Name)/thumbs/$($sourceFile.Name)`" },"
    }
    $lines += "    ]"
    $lines += "  },"
}
$lines += "];"

$lines | Set-Content -Path photos_list.js
Write-Host "Done. Thumbnails generated and photos_list.js updated, newest hike first."
