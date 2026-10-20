import Foundation

/// A word the user wants transcribed with a specific spelling, plus the ways
/// the engine tends to mishear it.
struct DictionaryEntry: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    /// The correct spelling, e.g. "Semeniuk".
    var word: String
    /// Comma-separated misrecognitions, e.g. "Semenyuk, Simeon UK". Kept as the
    /// raw text the user typed so editing it in a text field is lossless.
    var misheardAs: String = ""

    var misheardVariants: [String] {
        misheardAs
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum CustomDictionary {
    static func load(from defaults: UserDefaults = .standard) -> [DictionaryEntry] {
        guard let data = defaults.data(forKey: AppPreferences.customDictionaryKey),
              let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [DictionaryEntry], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: AppPreferences.customDictionaryKey)
    }

    /// Whisper is biased toward spellings that appear in its prompt, so the
    /// dictionary words are listed ahead of the user's own prompt. They come
    /// first because whisper.cpp drops the oldest prompt tokens when the
    /// prompt is too long, and the user's prompt carries the style.
    static func prompt(userPrompt: String, entries: [DictionaryEntry]) -> String {
        var seen = Set<String>()
        let words = entries
            .map { $0.word.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        let trimmedPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return trimmedPrompt }
        let vocabulary = words.joined(separator: ", ") + "."
        return trimmedPrompt.isEmpty ? vocabulary : vocabulary + " " + trimmedPrompt
    }

    /// Replaces every misheard variant with its entry's word. Matching ignores
    /// case, only hits whole words, and lets the words of a multi-word variant
    /// be separated by any spaces or hyphens ("open super-whisper").
    static func apply(_ entries: [DictionaryEntry], to text: String) -> String {
        let replacements = entries
            .flatMap { entry -> [(variant: String, word: String)] in
                let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !word.isEmpty else { return [] }
                return entry.misheardVariants.map { ($0, word) }
            }
            // Longest first, so "open super whisper" wins over "super whisper".
            .sorted { $0.variant.count > $1.variant.count }

        var result = text
        for (variant, word) in replacements {
            let parts = variant
                .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
                .map { NSRegularExpression.escapedPattern(for: String($0)) }
            guard !parts.isEmpty else { continue }
            let pattern = "(?<![\\p{L}\\p{N}])" + parts.joined(separator: "[\\s\\-]+") + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: NSRegularExpression.escapedTemplate(for: word)
            )
        }
        return result
    }
}
