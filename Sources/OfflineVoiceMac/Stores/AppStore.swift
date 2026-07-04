import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppStore: ObservableObject {
    @Published var selection: AppSection? = .record
    @Published var currentText = ""
    @Published var status = "准备就绪"
    @Published var errorMessage = ""
    @Published var history: [TranscriptRecord] = []
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var isDownloadingLargeModel = false
    @Published var largeModelDownloadProgress: Double = 0
    @Published var currentAudioURL: URL?

    @Published var modelPath: String {
        didSet { UserDefaults.standard.set(modelPath, forKey: Keys.modelPath) }
    }

    @Published var whisperPath: String {
        didSet { UserDefaults.standard.set(whisperPath, forKey: Keys.whisperPath) }
    }

    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: Keys.language) }
    }

    @Published var autoCopy: Bool {
        didSet { UserDefaults.standard.set(autoCopy, forKey: Keys.autoCopy) }
    }

    @Published var keepAudio: Bool {
        didSet { UserDefaults.standard.set(keepAudio, forKey: Keys.keepAudio) }
    }

    let recorder = AudioRecorderService()

    private enum Keys {
        static let modelPath = "modelPath"
        static let whisperPath = "whisperPath"
        static let language = "language"
        static let autoCopy = "autoCopy"
        static let keepAudio = "keepAudio"
        static let history = "history"
    }

    init() {
        let defaultWhisper = [
            Self.bundledWhisperCLIPath(),
            Self.homebrewWhisperCLIPath(prefix: "/opt/homebrew"),
            Self.homebrewWhisperCLIPath(prefix: "/usr/local")
        ].compactMap { $0 }
            .first { FileManager.default.isExecutableFile(atPath: $0) } ?? "whisper-cli"
        let defaultModel = Self.defaultModelPath()
        let storedModel = UserDefaults.standard.string(forKey: Keys.modelPath)
        let storedWhisper = UserDefaults.standard.string(forKey: Keys.whisperPath)

        if let storedModel, !storedModel.isEmpty, URL(fileURLWithPath: storedModel).lastPathComponent != "ggml-base.bin" {
            modelPath = storedModel
        } else {
            modelPath = defaultModel
        }
        if let storedWhisper,
           !storedWhisper.isEmpty,
           !storedWhisper.hasPrefix("/opt/homebrew/"),
           !storedWhisper.hasPrefix("/usr/local/") {
            whisperPath = storedWhisper
        } else {
            whisperPath = defaultWhisper
        }
        language = UserDefaults.standard.string(forKey: Keys.language) ?? "auto"
        autoCopy = UserDefaults.standard.object(forKey: Keys.autoCopy) as? Bool ?? true
        keepAudio = UserDefaults.standard.object(forKey: Keys.keepAudio) as? Bool ?? false
        history = Self.loadHistory()
    }

    var activeModelName: String {
        if modelPath == Self.bundledBaseModelPath() {
            return "内置标准模型"
        }
        if modelPath == Self.largeModelPath {
            return "高精度大模型"
        }
        if modelPath.isEmpty {
            return "未选择模型"
        }
        return URL(fileURLWithPath: modelPath).lastPathComponent
    }

    var baseModelAvailable: Bool {
        guard let path = Self.bundledBaseModelPath() else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    var largeModelAvailable: Bool {
        Self.availableLargeModelPath() != nil
    }

    var isUsingBaseModel: Bool {
        modelPath == Self.bundledBaseModelPath()
    }

    var isUsingLargeModel: Bool {
        guard let largePath = Self.availableLargeModelPath() else { return false }
        return modelPath == largePath
    }

    static var largeModelPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("whisper.cpp/models/ggml-large-v3.bin")
            .path
    }

    static var largeModelDownloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!
    }

    static func userModelsDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("OfflineVoiceMac/models", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func downloadedLargeModelPath() -> String? {
        guard let directory = try? userModelsDirectory() else { return nil }
        return directory.appendingPathComponent("ggml-large-v3.bin").path
    }

    static func availableLargeModelPath() -> String? {
        if let downloaded = downloadedLargeModelPath(), FileManager.default.fileExists(atPath: downloaded) {
            return downloaded
        }
        if FileManager.default.fileExists(atPath: largeModelPath) {
            return largeModelPath
        }
        return nil
    }

    static func bundledBaseModelPath() -> String? {
        Bundle.main.url(forResource: "ggml-base", withExtension: "bin", subdirectory: "models")?.path
    }

    static func bundledWhisperCLIPath() -> String? {
        Bundle.main.url(forResource: "whisper-cli", withExtension: nil, subdirectory: "bin")?.path
    }

    static func defaultModelPath() -> String {
        if let bundled = bundledBaseModelPath(), FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        let developmentFallback = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("whisper.cpp/models/ggml-base.bin")
            .path
        if FileManager.default.fileExists(atPath: developmentFallback) {
            return developmentFallback
        }
        return ""
    }

    static func homebrewWhisperCLIPath(prefix: String) -> String {
        "\(prefix)/bin/whisper-cli"
    }

    func toggleRecording() async {
        if isRecording {
            await stopAndTranscribe()
        } else {
            await startRecording()
        }
    }

    func startRecording() async {
        errorMessage = ""
        currentText = ""
        do {
            currentAudioURL = try await recorder.start()
            isRecording = true
            status = "正在录音"
        } catch {
            status = "录音失败"
            errorMessage = error.localizedDescription
        }
    }

    func stopAndTranscribe() async {
        guard isRecording else { return }
        let duration = recorder.elapsed
        let audioURL = recorder.stop()
        isRecording = false

        guard let audioURL else {
            status = "录音失败"
            errorMessage = "没有生成音频文件。"
            return
        }

        await transcribe(audioURL: audioURL, duration: duration)
    }

    func transcribe(audioURL: URL, duration: TimeInterval) async {
        errorMessage = ""
        isTranscribing = true
        status = "正在转写"
        defer { isTranscribing = false }

        do {
            let service = WhisperCLIService(executablePath: whisperPath)
            let text = try await Task.detached(priority: .userInitiated) {
                try await service.transcribe(
                    audioURL: audioURL,
                    modelPath: self.modelPath,
                    language: self.language
                )
            }.value

            currentText = text
            status = "转写完成"
            let record = TranscriptRecord(
                text: text,
                modelPath: modelPath,
                audioPath: keepAudio ? audioURL.path : "",
                duration: duration
            )
            history.insert(record, at: 0)
            history = Array(history.prefix(100))
            saveHistory()
            if autoCopy {
                copyText(text)
            }
            if !keepAudio {
                try? FileManager.default.removeItem(at: audioURL)
            }
        } catch {
            status = "转写失败"
            errorMessage = error.localizedDescription
            currentText = error.localizedDescription
        }
    }

    func copyCurrentText() {
        copyText(currentText)
    }

    func copyText(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func chooseModel() {
        if let url = chooseFile(allowedTypes: ["bin", "gguf"]) {
            modelPath = url.path
        }
    }

    func useBuiltInBaseModel() {
        guard let path = Self.bundledBaseModelPath(), FileManager.default.fileExists(atPath: path) else {
            errorMessage = "内置标准模型未找到。请重新构建应用或选择外部模型。"
            return
        }
        modelPath = path
        errorMessage = ""
    }

    func useLargeModel() {
        guard let path = Self.availableLargeModelPath() else {
            errorMessage = "还没有高精度大模型。可以先下载，或在高级设置里选择本机已有的 ggml-large-v3.bin。"
            return
        }
        modelPath = path
        errorMessage = ""
    }

    func downloadLargeModel() {
        guard !isDownloadingLargeModel else { return }
        isDownloadingLargeModel = true
        largeModelDownloadProgress = 0
        errorMessage = ""

        Task {
            do {
                let targetDirectory = try Self.userModelsDirectory()
                let targetURL = targetDirectory.appendingPathComponent("ggml-large-v3.bin")
                let tempURL = targetDirectory.appendingPathComponent("ggml-large-v3.bin.download")
                try? FileManager.default.removeItem(at: tempURL)
                FileManager.default.createFile(atPath: tempURL.path, contents: nil)

                let (bytes, response) = try await URLSession.shared.bytes(from: Self.largeModelDownloadURL)
                let expectedLength = max(0, response.expectedContentLength)
                let handle = try FileHandle(forWritingTo: tempURL)
                var buffer = Data()
                buffer.reserveCapacity(1024 * 512)
                var downloaded: Int64 = 0

                for try await byte in bytes {
                    buffer.append(byte)
                    if buffer.count >= 1024 * 512 {
                        try handle.write(contentsOf: buffer)
                        downloaded += Int64(buffer.count)
                        buffer.removeAll(keepingCapacity: true)
                        updateLargeModelProgress(downloaded: downloaded, expected: expectedLength)
                    }
                }

                if !buffer.isEmpty {
                    try handle.write(contentsOf: buffer)
                    downloaded += Int64(buffer.count)
                    updateLargeModelProgress(downloaded: downloaded, expected: expectedLength)
                }

                try handle.close()
                try? FileManager.default.removeItem(at: targetURL)
                try FileManager.default.moveItem(at: tempURL, to: targetURL)
                modelPath = targetURL.path
                largeModelDownloadProgress = 1
                isDownloadingLargeModel = false
                errorMessage = ""
            } catch {
                isDownloadingLargeModel = false
                errorMessage = "大模型下载失败：\(error.localizedDescription)"
            }
        }
    }

    private func updateLargeModelProgress(downloaded: Int64, expected: Int64) {
        guard expected > 0 else { return }
        largeModelDownloadProgress = min(1, max(0, Double(downloaded) / Double(expected)))
    }

    func chooseWhisperCLI() {
        if let url = chooseFile(allowedTypes: nil) {
            whisperPath = url.path
        }
    }

    func transcribeFile() {
        guard let url = chooseFile(allowedTypes: ["wav"]) else { return }
        Task {
            await transcribe(audioURL: url, duration: 0)
        }
    }

    private func chooseFile(allowedTypes: [String]?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let allowedTypes {
            panel.allowedContentTypes = allowedTypes.compactMap { UTType(filenameExtension: $0) }
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Keys.history)
        }
    }

    private static func loadHistory() -> [TranscriptRecord] {
        guard let data = UserDefaults.standard.data(forKey: Keys.history),
              let records = try? JSONDecoder().decode([TranscriptRecord].self, from: data) else {
            return []
        }
        return records
    }
}
