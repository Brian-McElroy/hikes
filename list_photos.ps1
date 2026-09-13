$dirs = Get-ChildItem -Directory | ForEach-Object {
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
    $lines += "  {"
    $lines += "    title: `"$($d.Name)`","
    $lines += "    photos: ["
    Get-ChildItem $d.Name -Filter *.jpg | ForEach-Object {
        $lines += "      `"$($d.Name)/$($_.Name)`","
    }
    $lines += "    ]"
    $lines += "  },"
}
$lines += "];"

$lines | Set-Content -Path photos_list.js
Write-Host "Done. photos_list.js updated, newest hike first."
