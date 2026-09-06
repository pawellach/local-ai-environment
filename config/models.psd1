@{
    # LLM model recommendations by hardware tier.
    # OllamaTag is passed directly to `ollama pull`.
    # ApproximateSizeGB is the compressed download size.
    # MinRAMGB / MinVRAMGB are soft requirements; below them the model
    # will run but may be slow.

    Low = @(
        @{
            Name              = "Qwen2.5 0.5B"
            OllamaTag         = "qwen2.5:0.5b"
            ApproximateSizeGB = 0.4
            MinRAMGB          = 4
            MinVRAMGB         = 0
            Description       = "Ultra-lightweight, CPU-friendly, good for testing"
        }
        @{
            Name              = "Qwen2.5 1.5B"
            OllamaTag         = "qwen2.5:1.5b"
            ApproximateSizeGB = 1.0
            MinRAMGB          = 4
            MinVRAMGB         = 0
            Description       = "Good quality/size ratio for CPU-only machines"
        }
        @{
            Name              = "Phi4 Mini"
            OllamaTag         = "phi4-mini:latest"
            ApproximateSizeGB = 2.5
            MinRAMGB          = 8
            MinVRAMGB         = 0
            Description       = "Microsoft Phi4 Mini — strong reasoning on CPU"
        }
    )

    Medium = @(
        @{
            Name              = "Llama3.2 3B"
            OllamaTag         = "llama3.2:3b"
            ApproximateSizeGB = 2.0
            MinRAMGB          = 8
            MinVRAMGB         = 4
            Description       = "Meta Llama 3.2 — balanced performance, small footprint"
        }
        @{
            Name              = "Gemma3 4B"
            OllamaTag         = "gemma3:4b"
            ApproximateSizeGB = 2.5
            MinRAMGB          = 8
            MinVRAMGB         = 4
            Description       = "Google Gemma 3 — strong instruction following"
        }
        @{
            Name              = "Qwen2.5 7B"
            OllamaTag         = "qwen2.5:7b"
            ApproximateSizeGB = 4.7
            MinRAMGB          = 16
            MinVRAMGB         = 8
            Description       = "Excellent quality, multilingual, best Medium choice"
        }
    )

    High = @(
        @{
            Name              = "Llama3.1 8B"
            OllamaTag         = "llama3.1:8b"
            ApproximateSizeGB = 4.9
            MinRAMGB          = 16
            MinVRAMGB         = 8
            Description       = "Meta Llama 3.1 — strong general-purpose model"
        }
        @{
            Name              = "Qwen2.5 14B"
            OllamaTag         = "qwen2.5:14b"
            ApproximateSizeGB = 9.0
            MinRAMGB          = 32
            MinVRAMGB         = 16
            Description       = "High quality reasoning, excellent multilingual support"
        }
        @{
            Name              = "Phi4 14B"
            OllamaTag         = "phi4:latest"
            ApproximateSizeGB = 9.1
            MinRAMGB          = 32
            MinVRAMGB         = 16
            Description       = "Microsoft Phi4 — exceptional at reasoning and coding tasks"
        }
    )

    # Fallback model used when the user skips the interactive selection
    Default = "qwen2.5:1.5b"
}
