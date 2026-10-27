# Brivio Production Build Script
param (
    [string]$SupabaseUrl = "",
    [string]$SupabaseAnonKey = "",
    [string]$Target = "appbundle" # 'appbundle' for Google Play or 'apk' for direct testing
)

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Brivio Production Release Build Pipeline   " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$defines = @()

if ($SupabaseUrl -ne "") {
    $defines += "--dart-define=SUPABASE_URL=$SupabaseUrl"
}

if ($SupabaseAnonKey -ne "") {
    $defines += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
}

$buildArgs = @("build", $Target, "--release") + $defines

Write-Host "Executing: flutter $($buildArgs -join ' ')" -ForegroundColor Yellow
& flutter @buildArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[SUCCESS] Production build completed successfully!" -ForegroundColor Green
    if ($Target -eq "appbundle") {
        Write-Host "AAB file output: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Green
    } else {
        Write-Host "APK file output: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
    }
} else {
    Write-Host "`n[ERROR] Production build failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
