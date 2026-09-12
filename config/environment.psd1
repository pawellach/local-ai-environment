@{
    ProjectName     = "Local-AI-Environment"
    ProjectVersion  = "1.0.0"

    # Paths (relative to project root; scripts resolve these at runtime)
    LogDir          = ".\logs"
    ReportDir       = ".\reports"

    # Open-WebUI configuration
    # Installed via: pip install open-webui
    # Started via:   open-webui serve --port <OpenWebUIPort>
    OpenWebUIPort   = 3000
    OpenWebUIHost   = "localhost"
    OpenWebUIStartCmd = "open-webui serve"

    # Ollama configuration
    OllamaPort          = 11434
    OllamaHost          = "localhost"
    OllamaApiUrl        = "http://localhost:11434"
    # Check https://ollama.com/download before each release — URL may change
    OllamaInstallerUrl  = "https://ollama.com/download/OllamaSetup.exe"
    OllamaWinGetId      = "Ollama.Ollama"

    # Python runtime requirements
    MinPythonVersion = "3.11"

    # Node.js runtime requirements (for optional tooling)
    MinNodeVersion  = "18"

    # Docker / future n8n phase
    N8nPort         = 5678
    N8nDataDir      = "C:\n8n-data"
}
