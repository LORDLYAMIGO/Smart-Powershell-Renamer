$ApiKey = "---"

# ====== API KEY VALIDATION ======
if ($ApiKey -eq "YOUR_API_KEY_HERE" -or [string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "Please set your Gemini API key in the script before running." -ForegroundColor Red
    Write-Host "Get your API key from: https://aistudio.google.com/app/apikey" -ForegroundColor Yellow
    exit
}

# ====== CHECK CURL AVAILABILITY ======
$curlCommand = Get-Command curl -ErrorAction SilentlyContinue
if (-not $curlCommand) {
    Write-Host "curl is not available. Please install curl or use a system that has it." -ForegroundColor Red
    exit
}

# ====== USER INPUT ======
$FolderPath = Read-Host "Enter folder path"
$UserPrompt = Read-Host "Enter your rename prompt (e.g., 'Make filenames descriptive and professional')"

# ====== VALIDATION ======
if (-not (Test-Path $FolderPath)) {
    Write-Host "Folder not found: $FolderPath" -ForegroundColor Red
    exit
}

$files = Get-ChildItem -Path $FolderPath -File
if ($files.Count -eq 0) {
    Write-Host "No files found in folder." -ForegroundColor Yellow
    exit
}

Write-Host "`nFound $($files.Count) file(s) to rename." -ForegroundColor Cyan

# ====== PREPARE PROMPT ======
$fileNames = $files.Name -join "`n"
$promptText = @"
You are an AI that helps rename files.
User instruction: $UserPrompt

Here are the current filenames (one per line):
$fileNames

IMPORTANT: Respond ONLY with a valid JSON array of new filenames WITHOUT file extensions.
The array must have exactly $($files.Count) names in the same order as the input.
Ensure names are valid for Windows/Unix filesystems (no special characters like / \ : * ? " < > |).

Example format:
["NewName1", "NewName2", "NewName3"]
"@

# Escape the prompt text for JSON
$promptTextEscaped = $promptText -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", ''

# ====== BUILD REQUEST ======
$jsonPayload = @"
{
  "contents": [
    {
      "parts": [
        {
          "text": "$promptTextEscaped"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7,
    "maxOutputTokens": 2048
  }
}
"@

# Save payload to temp file to avoid command line length issues
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonPayload | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

$apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"

# ====== API REQUEST ======
Write-Host "Sending request to Gemini 2.0 Flash..." -ForegroundColor Cyan

try {
    $curlOutput = & curl -s -X POST "$apiUrl" `
        -H "Content-Type: application/json" `
        -H "X-goog-api-key: $ApiKey" `
        --data-binary "@$tempFile" 2>&1
    
    # Check if curl command failed
    if ($LASTEXITCODE -ne 0) {
        Write-Host "curl command failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Output: $curlOutput" -ForegroundColor Red
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        exit
    }
    
    # Parse JSON response
    $response = $curlOutput | ConvertFrom-Json
    
} catch {
    Write-Host "API request failed: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    exit
} finally {
    # Clean up temp file
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

# ====== PARSE RESPONSE ======
if (-not $response.candidates -or $response.candidates.Count -eq 0) {
    Write-Host "No response from API. The request may have been blocked." -ForegroundColor Red
    if ($response.error) {
        Write-Host "Error: $($response.error.message)" -ForegroundColor Red
    }
    exit
}

$newNamesRaw = $response.candidates[0].content.parts[0].text

# Remove markdown code fences if present
$newNamesRaw = $newNamesRaw -replace '```json\s*', '' -replace '```\s*$', ''
$newNamesRaw = $newNamesRaw.Trim()

Write-Host "`nRaw API response:" -ForegroundColor Cyan
Write-Host $newNamesRaw -ForegroundColor Gray

try {
    $newNames = $newNamesRaw | ConvertFrom-Json
} catch {
    Write-Host "Could not parse Gemini response as JSON." -ForegroundColor Red
    Write-Host "Raw response:" -ForegroundColor Yellow
    Write-Host $newNamesRaw
    exit
}

# ====== VALIDATION ======
if ($newNames.Count -ne $files.Count) {
    Write-Host "Count mismatch: got $($newNames.Count) names for $($files.Count) files." -ForegroundColor Red
    exit
}

# ====== PREVIEW CHANGES ======
Write-Host "`nPreview of changes:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Gray
for ($i = 0; $i -lt $files.Count; $i++) {
    $oldName = $files[$i].Name
    $newBase = $newNames[$i]
    $ext = $files[$i].Extension
    $newName = $newBase + $ext
    Write-Host "$($i+1). " -NoNewline -ForegroundColor Yellow
    Write-Host "$oldName " -NoNewline -ForegroundColor White
    Write-Host "→ " -NoNewline -ForegroundColor Gray
    Write-Host "$newName" -ForegroundColor Green
}
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Gray

# ====== CONFIRMATION ======
$confirmation = Read-Host "`nProceed with renaming? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

# ====== RENAME FILES ======
Write-Host "`nRenaming files..." -ForegroundColor Cyan
$successCount = 0
$skippedCount = 0

for ($i = 0; $i -lt $files.Count; $i++) {
    $oldFile = $files[$i]
    $newBase = $newNames[$i]
    
    # Sanitize filename (remove invalid characters)
    $newBase = $newBase -replace '[\\/:*?"<>|]', '_'
    $newBase = $newBase.Trim()
    
    # Handle empty names
    if ([string]::IsNullOrWhiteSpace($newBase)) {
        Write-Host "Skipped '$($oldFile.Name)' - empty name suggested" -ForegroundColor Yellow
        $skippedCount++
        continue
    }
    
    $ext = $oldFile.Extension
    if ([string]::IsNullOrEmpty($ext)) {
        $ext = ""
    }
    
    $newPath = Join-Path $FolderPath ($newBase + $ext)
    
    # Check if target file already exists
    if (Test-Path $newPath) {
        Write-Host "Skipped '$($oldFile.Name)' - target file already exists: '$newBase$ext'" -ForegroundColor Yellow
        $skippedCount++
    } else {
        try {
            Rename-Item -Path $oldFile.FullName -NewName ($newBase + $ext) -ErrorAction Stop
            Write-Host "'$($oldFile.Name)' → '$newBase$ext'" -ForegroundColor Green
            $successCount++
        } catch {
            Write-Host "Failed to rename '$($oldFile.Name)': $($_.Exception.Message)" -ForegroundColor Red
            $skippedCount++
        }
    }
}

# ====== SUMMARY ======
Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host "Renaming complete!" -ForegroundColor Cyan
Write-Host "   Successfully renamed: $successCount file(s)" -ForegroundColor Green
if ($skippedCount -gt 0) {
    Write-Host "   Skipped: $skippedCount file(s)" -ForegroundColor Yellow
}

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Gray
