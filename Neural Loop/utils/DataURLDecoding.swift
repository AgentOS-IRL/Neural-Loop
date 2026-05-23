//
//  DataURLDecoding.swift
//  Neural Loop
//
//  Created by Codex on 23/05/2026.
//

import Foundation

extension String {
    /// Decodes a `data:...;base64,...` URL into raw data.
    func decodedDataURLPayload() -> Data? {
        guard let commaIndex = firstIndex(of: ",") else { return nil }
        let base64String = String(self[index(after: commaIndex)...])
        return Data(base64Encoded: base64String)
    }
}
