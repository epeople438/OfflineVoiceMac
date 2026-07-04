import Foundation

struct WhisperCLIService {
    var executablePath: String

    func transcribe(audioURL: URL, modelPath: String, language: String) async throws -> String {
        let executable = URL(fileURLWithPath: executablePath)
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw WhisperError.missingExecutable(executablePath)
        }

        guard !modelPath.isEmpty, FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperError.missingModel(modelPath)
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "-m", modelPath,
            "-f", audioURL.path,
            "-nt",
            "-l", language
        ]
        let resourcesURL = executable.deletingLastPathComponent().deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        environment["GGML_BACKEND_PATH"] = resourcesURL
            .appendingPathComponent("libexec", isDirectory: true)
            .appendingPathComponent("libggml-metal.so")
            .path
        environment["DYLD_LIBRARY_PATH"] = resourcesURL.appendingPathComponent("lib", isDirectory: true).path
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let diagnostics = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw WhisperError.processFailed(diagnostics.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let text = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("whisper_") && !$0.hasPrefix("main:") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw WhisperError.emptyOutput(diagnostics.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return text
    }
}

enum WhisperError: LocalizedError {
    case missingExecutable(String)
    case missingModel(String)
    case processFailed(String)
    case emptyOutput(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let path):
            "找不到 whisper-cli：\(path)。请安装 whisper-cpp，或在设置里选择正确路径。"
        case .missingModel(let path):
            path.isEmpty ? "还没有选择模型文件。请在“模型”页选择真实 ggml-*.bin 模型。" : "找不到模型文件：\(path)。请选择真实 ggml-*.bin 模型。"
        case .processFailed(let message):
            message.isEmpty ? "whisper-cli 执行失败。" : "whisper-cli 执行失败：\(message)"
        case .emptyOutput(let diagnostics):
            diagnostics.isEmpty ? "模型没有输出文本。请确认模型不是测试空模型。" : "模型没有输出文本：\(diagnostics)"
        }
    }
}
