Add-Type -AssemblyName System.Drawing

$thumbWidth = 400

function Get-DateTaken {
    param($Path)
    try {
        $img = [System.Drawing.Image]::FromFile($Path)
        try {
            if ($img.PropertyIdList -contains 0x9003) {
                $bytes = $img.GetPropertyItem(0x9003).Value
                $str = [System.Text.Encoding]::ASCII.GetString($bytes).TrimEnd([char]0)
                return [datetime]::ParseExact($str, "yyyy:MM:dd HH:mm:ss", $null)
            }
        } finally {
            $img.Dispose()
        }
    } catch {}
    return (Get-Item $Path).LastWriteTime
}

function New-Thumbnail {
    param($SourcePath, $DestPath)
    $img = [System.Drawing.Image]::FromFile($SourcePath)
    try {
        if ($img.PropertyIdList -contains 0x0112) {
            $orientation = $img.GetPropertyItem(0x0112).Value[0]
            switch ($orientation) {
                2 { $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
                3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
                4 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipX) }
                5 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipX) }
                6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
                7 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipX) }
                8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
            }
        }

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

# Build each hike's photo list (with date taken) once, reuse for both
# photo ordering within the hike and hike ordering on the page.
$hikeData = Get-ChildItem -Directory | Where-Object { $_.Name -ne "thumbs" } | ForEach-Object {
    $folder = $_
    $photos = Get-ChildItem $folder.FullName -Filter *.jpg | ForEach-Object {
        [PSCustomObject]@{ File = $_; Date = Get-DateTaken $_.FullName }
    } | Sort-Object Date

    $latestDate = if ($photos) { ($photos.Date | Sort-Object -Descending | Select-Object -First 1) } else { [datetime]::MinValue }

    [PSCustomObject]@{
        Name = $folder.Name
        Photos = $photos
        Date = $latestDate
    }
} | Sort-Object Date -Descending

$lines = @()
$lines += "const hikes = ["
foreach ($hike in $hikeData) {
    $thumbsDir = Join-Path $hike.Name "thumbs"
    if (-not (Test-Path $thumbsDir)) {
        New-Item -ItemType Directory -Path $thumbsDir | Out-Null
    }

    $lines += "  {"
    $lines += "    title: `"$($hike.Name)`","
    $lines += "    photos: ["
    foreach ($p in $hike.Photos) {
        $sourceFile = $p.File
        $thumbPath = Join-Path $thumbsDir $sourceFile.Name

        if ((-not (Test-Path $thumbPath)) -or ((Get-Item $thumbPath).LastWriteTime -lt $sourceFile.LastWriteTime)) {
            New-Thumbnail -SourcePath $sourceFile.FullName -DestPath $thumbPath
        }

        $lines += "      { full: `"$($hike.Name)/$($sourceFile.Name)`", thumb: `"$($hike.Name)/thumbs/$($sourceFile.Name)`" },"
    }
    $lines += "    ]"
    $lines += "  },"
}
$lines += "];"

$lines | Set-Content -Path photos_list.js
Write-Host "Done. Sorted by date taken, thumbnails generated, photos_list.js updated."
