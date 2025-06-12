#!/usr/bin/env pwsh
# Generate Application Secrets for RBarros Deployment
# This script generates secure random strings for application secrets

Write-Host "🔐 RBarros Application Secrets Generator" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Function to generate a secure random string
function Generate-SecureString {
    param(
        [int]$Length = 64,
        [string]$Description = "Secret"
    )
    
    # Use .NET RNGCryptoServiceProvider for cryptographically secure random generation
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    
    # Convert to base64 and clean up for use as secret
    $secret = [Convert]::ToBase64String($bytes) -replace '[/+=]', [char](Get-Random -Minimum 65 -Maximum 90)
    return $secret.Substring(0, $Length)
}

# Function to generate URL-safe string (for webhook secrets)
function Generate-URLSafeString {
    param([int]$Length = 32)
    
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    $secret = ""
    
    for ($i = 0; $i -lt $Length; $i++) {
        $secret += $chars[(Get-Random -Maximum $chars.Length)]
    }
    
    return $secret
}

Write-Host "Generating secure application secrets..." -ForegroundColor Yellow
Write-Host ""

# Generate secrets
$secretKey = Generate-SecureString -Length 64 -Description "JWT Secret Key"
$refreshTokenSecret = Generate-SecureString -Length 64 -Description "JWT Refresh Token Secret"
$webhookSecret = Generate-URLSafeString -Length 32

# Display generated secrets
Write-Host "📋 Generated Secrets:" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host ""

Write-Host "SECRET_KEY:" -ForegroundColor White
Write-Host $secretKey -ForegroundColor Yellow
Write-Host ""

Write-Host "SECRET_KEY_REFRESH_TOKEN:" -ForegroundColor White
Write-Host $refreshTokenSecret -ForegroundColor Yellow
Write-Host ""

Write-Host "WEBHOOK_SECRET:" -ForegroundColor White
Write-Host $webhookSecret -ForegroundColor Yellow
Write-Host ""

# Database password suggestion
$dbPassword = Generate-SecureString -Length 32
Write-Host "MYSQL_ROOT_PASSWORD (suggestion):" -ForegroundColor White
Write-Host $dbPassword -ForegroundColor Yellow
Write-Host ""

# Additional secrets that need manual setup
Write-Host "📋 Manual Setup Required:" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

Write-Host "SENDGRID_API_KEY:" -ForegroundColor White
Write-Host "  → Sign up at https://sendgrid.com" -ForegroundColor Gray
Write-Host "  → Go to Settings → API Keys → Create API Key" -ForegroundColor Gray
Write-Host "  → Copy the generated API key" -ForegroundColor Gray
Write-Host ""

# GitHub Secrets format
Write-Host "🔧 GitHub Secrets Setup:" -ForegroundColor Magenta
Write-Host "========================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Copy these values to your GitHub repository secrets:" -ForegroundColor Gray
Write-Host ""

$githubSecrets = @"
SECRET_KEY=$secretKey
SECRET_KEY_REFRESH_TOKEN=$refreshTokenSecret
WEBHOOK_SECRET=$webhookSecret
MYSQL_ROOT_PASSWORD=$dbPassword
"@

Write-Host $githubSecrets -ForegroundColor Yellow
Write-Host ""

# Save GitHub secrets to clipboard if possible
try {
    $githubSecrets | Set-Clipboard
    Write-Host "✅ GitHub secrets copied to clipboard!" -ForegroundColor Green
} catch {
    Write-Host "💡 Tip: Copy the secrets above to set them in GitHub" -ForegroundColor Blue
}
