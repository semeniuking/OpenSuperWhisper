import XCTest
@testable import OpenSuperWhisper

final class CustomDictionaryTests: XCTestCase {
    private func entry(_ word: String, _ misheardAs: String = "") -> DictionaryEntry {
        DictionaryEntry(word: word, misheardAs: misheardAs)
    }

    // MARK: - Replacements

    func testReplacesMisheardVariantIgnoringCase() {
        let entries = [entry("Semeniuk", "Semenyuk, Simeon UK")]
        XCTAssertEqual(
            CustomDictionary.apply(entries, to: "Hi, this is Misha semenyuk. And simeon uk again."),
            "Hi, this is Misha Semeniuk. And Semeniuk again."
        )
    }

    func testMatchesOnlyWholeWords() {
        let entries = [entry("Kubernetes", "cube")]
        XCTAssertEqual(
            CustomDictionary.apply(entries, to: "A cube, cubes and a Rubik's cube."),
            "A Kubernetes, cubes and a Rubik's Kubernetes."
        )
    }

    func testMultiWordVariantToleratesSpacesAndHyphens() {
        let entries = [entry("OpenSuperWhisper", "open super whisper")]
        XCTAssertEqual(
            CustomDictionary.apply(entries, to: "I use Open Super-Whisper and open  super whisper."),
            "I use OpenSuperWhisper and OpenSuperWhisper."
        )
    }

    func testLongerVariantWinsOverShorterOne() {
        let entries = [
            entry("Whisper", "whisker"),
            entry("OpenSuperWhisper", "open super whisker"),
        ]
        XCTAssertEqual(
            CustomDictionary.apply(entries, to: "open super whisker vs whisker"),
            "OpenSuperWhisper vs Whisper"
        )
    }

    func testSpecialCharactersAreLiteral() {
        let entries = [entry("$HOME\\bin", "c plus plus, c++")]
        XCTAssertEqual(
            CustomDictionary.apply(entries, to: "Write c++ or C plus plus."),
            "Write $HOME\\bin or $HOME\\bin."
        )
    }

    func testIgnoresEntriesWithoutWordOrVariants() {
        let entries = [entry("", "hello"), entry("World"), entry("Test", " , ,")]
        XCTAssertEqual(CustomDictionary.apply(entries, to: "hello world test"), "hello world test")
    }

    func testNonLatinText() {
        let entries = [entry("Михайло", "михаило")]
        XCTAssertEqual(CustomDictionary.apply(entries, to: "Привіт, михаило!"), "Привіт, Михайло!")
    }

    // MARK: - Prompt

    func testPromptListsWordsBeforeUserPrompt() {
        let entries = [entry("Semeniuk"), entry(" OpenSuperWhisper "), entry("semeniuk"), entry("")]
        XCTAssertEqual(
            CustomDictionary.prompt(userPrompt: "Use British spelling.", entries: entries),
            "Semeniuk, OpenSuperWhisper. Use British spelling."
        )
    }

    func testPromptWithoutWordsIsUserPrompt() {
        XCTAssertEqual(CustomDictionary.prompt(userPrompt: " Hello ", entries: []), "Hello")
        XCTAssertEqual(CustomDictionary.prompt(userPrompt: "", entries: [entry("Kyiv")]), "Kyiv.")
    }

    // MARK: - Persistence

    func testSaveAndLoadRoundTrip() throws {
        let suiteName = "CustomDictionaryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(CustomDictionary.load(from: defaults), [])
        let entries = [entry("Semeniuk", "Semenyuk"), entry("Kyiv", "Kiev")]
        CustomDictionary.save(entries, to: defaults)
        XCTAssertEqual(CustomDictionary.load(from: defaults), entries)
    }
}
