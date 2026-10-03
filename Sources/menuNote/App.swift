import SwiftUI

@main
struct MenuNoteApp: App {
    @StateObject private var store = NoteStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
                .frame(width: 480, height: 400)
        } label: {
            Image(systemName: "circle")
                .fontWeight(.black)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - File-backed store

/// Persists the note as plain Markdown in a user-chosen file, with debounced atomic writes.
/// The chosen path is remembered in UserDefaults under `notePath`.
final class NoteStore: ObservableObject {
    private static let pathKey = "notePath"

    @Published private(set) var fileURL: URL?
    @Published var text: String = "" {
        didSet { if !isLoading { scheduleSave() } }
    }

    private var isLoading = false
    private var saveWork: DispatchWorkItem?

    init() {
        if let p = UserDefaults.standard.string(forKey: Self.pathKey) {
            fileURL = URL(fileURLWithPath: p)
            reload()
        }
    }

    /// Show an open panel to pick a .md file (or a save panel to create one).
    func chooseFile() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Choose a Markdown file for menuNote"
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Use This File"
        panel.message = "Pick an existing .md file, or Cancel to create a new one."

        var url: URL?
        if panel.runModal() == .OK {
            url = panel.url
        } else {
            let save = NSSavePanel()
            save.title = "Create a new note file"
            save.nameFieldStringValue = "MenuNote.md"
            save.allowedContentTypes = [.init(filenameExtension: "md")!]
            if save.runModal() == .OK { url = save.url }
        }
        guard let url else { return }

        flushPendingSave()
        fileURL = url
        UserDefaults.standard.set(url.path, forKey: Self.pathKey)
        if FileManager.default.fileExists(atPath: url.path) {
            reload()
        } else {
            saveNow()   // keep current text in the new file
        }
    }

    /// Re-read the file from disk (called each time the popover opens).
    func reload() {
        flushPendingSave()
        guard let fileURL,
              let s = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        if s != text { setWithoutSaving(s) }
    }

    func saveNow() {
        saveWork = nil
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("menuNote: failed to save \(fileURL.path): \(error)")
        }
    }

    func flushPendingSave() {
        if saveWork != nil { saveWork?.cancel(); saveNow() }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func setWithoutSaving(_ s: String) {
        isLoading = true
        text = s
        isLoading = false
    }
}

// MARK: - UI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var editing = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if editing {
                TextEditor(text: $store.text)
                    .font(.andale(13))
                    .scrollContentBackground(.hidden)
                    .focused($focused)
            } else {
                ScrollView {
                    MarkdownView(text: store.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
                .scrollContentBackground(.hidden)
            }
            HStack(spacing: 6) {
                Button { store.chooseFile() } label: {
                    Image(systemName: "doc")
                }
                .buttonStyle(.borderless)
                .help(store.fileURL?.path ?? "Choose note file…")
                Toggle("Edit", isOn: $editing)
                    .toggleStyle(.switch)
                    .onChange(of: editing) { _, on in focused = on }
            }
            .controlSize(.mini)
            .font(.caption2)
            .padding(4)
            .background(.thinMaterial, in: Capsule())
        }
        .padding(8)
        .onAppear {
            store.reload()
            if store.fileURL == nil {
                DispatchQueue.main.async { store.chooseFile() }
            }
        }
        // MenuBarExtra keeps this view alive between openings, so onAppear
        // only fires once. Reload/save on the popover window gaining/losing key.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            store.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            store.flushPendingSave()
        }
        .onDisappear { store.flushPendingSave() }
    }
}

// MARK: - Lightweight Markdown renderer

struct MarkdownView: View {
    let text: String

    // Rendered as ONE Text so selection can span multiple lines.
    var body: some View {
        Text(render(text))
            .font(.andale(13))
            .lineSpacing(3)
            .textSelection(.enabled)
    }

    private func render(_ src: String) -> AttributedString {
        var out = AttributedString()
        let lines = src.components(separatedBy: "\n")
        for (i, raw) in lines.enumerated() {
            out += line(raw)
            if i < lines.count - 1 { out += AttributedString("\n") }
        }
        return out
    }

    private func line(_ raw: String) -> AttributedString {
        let t = raw.trimmingCharacters(in: .whitespaces)
        let headings: [(String, CGFloat)] = [("### ", 15), ("## ", 17), ("# ", 20)]
        for (prefix, size) in headings where t.hasPrefix(prefix) {
            var a = inline(String(t.dropFirst(prefix.count)))
            a.font = .custom("Arial", size: size).bold()
            return a
        }
        if t.hasPrefix("- ") || t.hasPrefix("* ") {
            let depth = raw.prefix { $0 == " " }.count / 2
            return AttributedString(String(repeating: "  ", count: depth) + " • ")
                + inline(String(t.dropFirst(2)))
        }
        return inline(raw)
    }

    /// Inline bold/italic/code/links via Foundation's Markdown parser.
    private func inline(_ s: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: opts)) ?? AttributedString(s)
    }
}

extension Font {
    static func andale(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Andale Mono", size: size).weight(weight)
    }
}
