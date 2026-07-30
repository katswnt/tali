import SwiftUI
import UniformTypeIdentifiers

struct TaliExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText, .json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum TaliCompleteDataExport {
    static func archive(localData: Data, serverData: Data?) throws -> Data {
        let local = try JSONSerialization.jsonObject(with: localData)
        var archive: [String: Any] = [
            "schemaVersion": 1,
            "exportedAt": Date.now.formatted(
                Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            ),
            "local": local,
        ]
        if let serverData {
            archive["server"] = try JSONSerialization.jsonObject(with: serverData)
        }
        return try JSONSerialization.data(
            withJSONObject: archive,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }
}
