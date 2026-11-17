# Serve this folder on http://localhost and open it in the default browser (Windows PowerShell).
# Listens on this computer only. Press Ctrl+C or close the window to stop.
# Options: -Port N (first port to try, default 8000), -NoBrowser.
param([int]$Port = 8000, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mime = @{
  '.html' = 'text/html; charset=utf-8'; '.htm' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'
  '.mjs' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json'
  '.md' = 'text/markdown; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8'; '.csv' = 'text/csv; charset=utf-8'
  '.wav' = 'audio/wav'; '.png' = 'image/png'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.pdf' = 'application/pdf'
}

$listener = $null; $chosen = 0
for ($p = $Port; $p -lt $Port + 50; $p++) {
  $l = New-Object System.Net.HttpListener
  $l.Prefixes.Add("http://localhost:$p/")
  try { $l.Start(); $listener = $l; $chosen = $p; break } catch { $l.Close() }
}
if (-not $listener) {
  Write-Host "Could not find a free port from $Port to $($Port + 49)."
  exit 1
}

$url = "http://localhost:$chosen/"
Write-Host "Serving $root"
Write-Host "Open $url  (this computer only)"
Write-Host "Press Ctrl+C or close this window to stop."
if (-not $NoBrowser) { Start-Process $url }

function Send-Text($res, [int]$code, [string]$text) {
  $b = [Text.Encoding]::UTF8.GetBytes($text)
  $res.StatusCode = $code; $res.ContentType = 'text/plain; charset=utf-8'; $res.ContentLength64 = $b.Length
  $res.OutputStream.Write($b, 0, $b.Length)
}

try {
  while ($listener.IsListening) {
    $ar = $listener.BeginGetContext($null, $null)
    while (-not $ar.AsyncWaitHandle.WaitOne(300)) { }        # short waits, so Ctrl+C can interrupt
    $ctx = $listener.EndGetContext($ar)
    $req = $ctx.Request; $res = $ctx.Response
    try {
      $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
      $seg = @($path.Split('/') | Where-Object { $_ -ne '' })
      $bad = ($req.HttpMethod -ne 'GET' -and $req.HttpMethod -ne 'HEAD') -or ($path.Contains([string][char]0)) -or
        (@($seg | Where-Object { $_.StartsWith('.') -or $_.Contains(':') -or $_.Contains('\') }).Count -gt 0)
      $file = $null
      if (-not $bad) {
        $file = $root
        if ($seg.Count -gt 0) { $file = Join-Path $root ($seg -join [IO.Path]::DirectorySeparatorChar) }
        if (Test-Path -LiteralPath $file -PathType Container) { $file = Join-Path $file 'index.html' }
      }
      if ($bad -or -not (Test-Path -LiteralPath $file -PathType Leaf)) {
        Send-Text $res 404 'Not found'
      } else {
        $bytes = [IO.File]::ReadAllBytes($file)
        $ext = [IO.Path]::GetExtension($file).ToLower()
        $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        $res.Headers.Add('Cache-Control', 'no-cache')
        $res.ContentLength64 = $bytes.Length
        if ($req.HttpMethod -eq 'GET') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
      }
    } catch {
      # a browser that cancelled a request, or a file that could not be read: carry on
    } finally {
      try { $res.Close() } catch { }
    }
  }
} finally {
  $listener.Stop(); $listener.Close()
}
