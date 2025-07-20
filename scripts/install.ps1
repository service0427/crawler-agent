# Web Crawler Agent Installation Script (Windows)
# Run this script in PowerShell as Administrator

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "        Web Crawler Agent Installation Script (Windows)" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check Node.js installation
function Check-Node {
    Write-Host "Checking Node.js installation..." -ForegroundColor Yellow
    
    try {
        $nodeVersion = node -v
        $majorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
        
        if ($majorVersion -lt 18) {
            Write-Host "Node.js version is too old: $nodeVersion" -ForegroundColor Red
            Write-Host "Please upgrade to Node.js v18 or higher from https://nodejs.org/"
            exit 1
        }
        
        Write-Host "✓ Node.js $nodeVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "Node.js is not installed!" -ForegroundColor Red
        Write-Host "Please install Node.js (v18 or higher) from https://nodejs.org/"
        exit 1
    }
}

# Check Chrome installation
function Check-Browser {
    Write-Host "Checking browser installation..." -ForegroundColor Yellow
    
    $chromePath = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "${env:LocalAppData}\Google\Chrome\Application\chrome.exe"
    )
    
    $chromeFound = $false
    foreach ($path in $chromePath) {
        if (Test-Path $path) {
            $chromeFound = $true
            break
        }
    }
    
    if ($chromeFound) {
        Write-Host "✓ Google Chrome found" -ForegroundColor Green
    } else {
        Write-Host "Chrome not found. Please install Google Chrome from https://www.google.com/chrome/" -ForegroundColor Yellow
    }
}

# Create directories
function Create-Directories {
    Write-Host "Creating directories..." -ForegroundColor Yellow
    
    $dirs = @("logs", "data\users", "config")
    foreach ($dir in $dirs) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-Host "✓ Directories created" -ForegroundColor Green
}

# Setup environment file
function Setup-Environment {
    Write-Host "Setting up environment..." -ForegroundColor Yellow
    
    if (!(Test-Path ".env")) {
        if (Test-Path ".env.example") {
            Copy-Item ".env.example" ".env"
            Write-Host "Please edit .env file with your configuration" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✓ .env file already exists" -ForegroundColor Green
    }
}

# Install dependencies
function Install-Dependencies {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    
    try {
        npm install
        Write-Host "✓ Dependencies installed" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install dependencies" -ForegroundColor Red
        exit 1
    }
}

# Install Playwright browsers
function Install-PlaywrightBrowsers {
    Write-Host "Installing Playwright browsers..." -ForegroundColor Yellow
    
    try {
        npx playwright install chromium
        Write-Host "✓ Playwright browsers installed" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install Playwright browsers" -ForegroundColor Red
        exit 1
    }
}

# Create Windows batch files
function Create-BatchFiles {
    Write-Host "Creating batch files..." -ForegroundColor Yellow
    
    # Start single agent batch file
    $startBatch = @"
@echo off
echo Starting Crawler Agent...
npm start
pause
"@
    Set-Content -Path "start-agent.bat" -Value $startBatch
    
    # Start multiple agents batch file
    $multiStartBatch = @"
@echo off
echo Starting Multiple Crawler Agents...
powershell -ExecutionPolicy Bypass -File scripts\start-multi-agents.ps1
pause
"@
    Set-Content -Path "start-multi-agents.bat" -Value $multiStartBatch
    
    Write-Host "✓ Batch files created" -ForegroundColor Green
}

# Suggest Windows service setup
function Suggest-WindowsService {
    Write-Host ""
    Write-Host "To run agent as a Windows service:" -ForegroundColor Yellow
    Write-Host "1. Install node-windows: npm install -g node-windows"
    Write-Host "2. Run: node scripts\install-windows-service.js"
    Write-Host ""
    Write-Host "Or use PM2 for process management:"
    Write-Host "1. Install PM2: npm install -g pm2"
    Write-Host "2. Start agent: pm2 start src/index.js --name crawler-agent"
    Write-Host "3. Save PM2 list: pm2 save"
    Write-Host "4. Setup startup: pm2 startup"
}

# Main installation process
function Main {
    if (-not (Test-Administrator)) {
        Write-Host "This script should be run as Administrator for best results" -ForegroundColor Yellow
        Write-Host "Some features may not work properly without admin rights" -ForegroundColor Yellow
        Write-Host ""
    }
    
    Check-Node
    Check-Browser
    Create-Directories
    Setup-Environment
    Install-Dependencies
    Install-PlaywrightBrowsers
    Create-BatchFiles
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "        Installation completed successfully!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Edit .env file with your hub configuration"
    Write-Host "2. Run single agent: npm start (or double-click start-agent.bat)"
    Write-Host "3. Run multiple agents: .\scripts\start-multi-agents.ps1"
    Write-Host ""
    
    Suggest-WindowsService
}

# Run main function
Main