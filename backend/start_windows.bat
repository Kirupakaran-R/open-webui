:: This method is not recommended, and we recommend you use the `start.sh` file with WSL instead.
@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

:: Get the directory of the current script
SET "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%" || exit /b

:: Add conditional Playwright browser installation
IF /I "%WEB_LOADER_ENGINE%" == "playwright" (
    IF "%PLAYWRIGHT_WS_URL%" == "" (
        echo Installing Playwright browsers...
        playwright install chromium
        playwright install-deps chromium
    )

    python -c "import nltk; nltk.download('punkt_tab')"
)

SET "KEY_FILE=.webui_secret_key"
IF NOT "%WEBUI_SECRET_KEY_FILE%" == "" (
    SET "KEY_FILE=%WEBUI_SECRET_KEY_FILE%"
)

IF "%PORT%"=="" SET PORT=3002
IF "%HOST%"=="" SET HOST=0.0.0.0
IF "%AIOHTTP_CLIENT_TIMEOUT_TOOL_SERVER_DATA%"=="" SET AIOHTTP_CLIENT_TIMEOUT_TOOL_SERVER_DATA=30
SET "WEBUI_SECRET_KEY=%WEBUI_SECRET_KEY%"
SET "WEBUI_JWT_SECRET_KEY=%WEBUI_JWT_SECRET_KEY%"


:: Check if WEBUI_SECRET_KEY and WEBUI_JWT_SECRET_KEY are not set
IF "%WEBUI_SECRET_KEY% %WEBUI_JWT_SECRET_KEY%" == " " (
    echo Loading WEBUI_SECRET_KEY from file, not provided as an environment variable.

    IF NOT EXIST "%KEY_FILE%" (
        echo Generating WEBUI_SECRET_KEY
        :: Generate a random value to use as a WEBUI_SECRET_KEY in case the user didn't provide one
        SET /p WEBUI_SECRET_KEY=<nul
        FOR /L %%i IN (1,1,12) DO SET /p WEBUI_SECRET_KEY=<!random!>>%KEY_FILE%
        echo WEBUI_SECRET_KEY generated
    )

    echo Loading WEBUI_SECRET_KEY from %KEY_FILE%
    SET /p WEBUI_SECRET_KEY=<%KEY_FILE%
)

:: ============================================================================
:: ============================================================================
:: IMPORTANT: The URL should be just the base domain
:: Open WebUI will append /openai/deployments/{model}/chat/completions automatically for Azure
IF "%OPENAI_API_BASE_URLS%"=="" SET OPENAI_API_BASE_URLS=https://aoai-farm.bosch-temp.com/api

:: Set the API key (your genaiplatform-farm-subscription-key)
IF "%OPENAI_API_KEYS%"=="" SET OPENAI_API_KEYS=password

:: Configure proxy for LLM Farm access
IF "%HTTP_PROXY%"=="" SET HTTP_PROXY=http://127.0.0.1:3128
IF "%HTTPS_PROXY%"=="" SET HTTPS_PROXY=http://127.0.0.1:3128

:: Azure OpenAI specific settings
:: Set this to tell Open WebUI you're using Azure
SET OPENAI_API_TYPE=azure

:: Azure API version
SET AZURE_OPENAI_API_VERSION=2024-08-01-preview

:: Optional: Set custom headers for Azure authentication
:: Note: Open WebUI may require you to add this via the UI instead
:: SET OPENAI_API_HEADERS={"genaiplatform-farm-subscription-key":"password"}

:: ============================================================================
:: Configure MCP Tool Servers
:: ============================================================================
:: Format: JSON array with server configurations
:: Example for a local MCP server:
:: SET TOOL_SERVER_CONNECTIONS=[{"url":"http://localhost:3000","type":"mcp","auth_type":"none","path":"","config":{"enable":true},"info":{"id":"local-mcp","name":"Local MCP Server","description":"My local MCP server"}}]
::
:: For multiple servers, add more objects to the array
:: For bearer auth, add: "auth_type":"bearer","key":"your-api-key"

:: Disable follow-up generation to avoid errors
SET ENABLE_FOLLOW_UP_GENERATION=False

:: Enable user authentication (recommended for production)
IF "%ENABLE_SIGNUP%"=="" SET ENABLE_SIGNUP=true
IF "%WEBUI_AUTH%"=="" SET WEBUI_AUTH=true

:: Optional: Configure SSL certificate verification
:: If you have corporate SSL/TLS inspection, you may need to disable verification
:: SET SSL_VERIFY=false
:: SET REQUESTS_CA_BUNDLE=

:: ============================================================================
:: Display configuration
:: ============================================================================
echo.
echo ============================================================
echo Open WebUI Configuration
echo ============================================================
echo Host: %HOST%
echo Port: %PORT%
echo API Base URL: %OPENAI_API_BASE_URLS%
echo API Type: %OPENAI_API_TYPE%
echo Azure API Version: %AZURE_OPENAI_API_VERSION%
echo HTTP Proxy: %HTTP_PROXY%
echo HTTPS Proxy: %HTTPS_PROXY%
echo ============================================================
echo.
echo IMPORTANT: After starting, configure the connection in the UI:
echo 1. Go to Settings ^> Connections
echo 2. Add/Edit Azure OpenAI connection
echo 3. Add custom header: genaiplatform-farm-subscription-key
echo 4. Add deployment name: askbosch-prod-farm-openai-gpt-4o-mini-2024-07-18
echo ============================================================
echo.

:: Configure Azure OpenAI (Bosch LLM Farm)


:: Execute uvicorn
SET "WEBUI_SECRET_KEY=%WEBUI_SECRET_KEY%"
IF "%UVICORN_WORKERS%"=="" SET UVICORN_WORKERS=1
uvicorn open_webui.main:app --host "%HOST%" --port "%PORT%" --forwarded-allow-ips '*' --workers %UVICORN_WORKERS% --ws auto
:: For ssl user uvicorn open_webui.main:app --host "%HOST%" --port "%PORT%" --forwarded-allow-ips '*' --ssl-keyfile "key.pem" --ssl-certfile "cert.pem" --ws auto
