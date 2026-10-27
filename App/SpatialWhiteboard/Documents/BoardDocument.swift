import SwiftUI
import UniformTypeIdentifiers
import BoardCore

extension UTType {
    static let spatialBoard = UTType(
        exportedAs: "com.alvarovillalbaa.spatial-whiteboard.board",
        conformingTo: .json
    )
}

struct BoardDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.spatialBoard, .json] }
    static var writableContentTypes: [UTType] { [.spatialBoard, .json] }

    var board: Board

    init(board: Board = Board()) {
        self.board = board
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BoardError.invalid("This document is not a regular board file.")
        }
        // A failed read propagates to the document browser; it never becomes an empty board.
        board = try BoardCodec.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try BoardCodec.encode(board))
    }
}
