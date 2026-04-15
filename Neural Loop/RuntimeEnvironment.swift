//
//  RuntimeEnvironment.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import Foundation

func isRunningUnderTests() -> Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
    NSClassFromString("XCTestCase") != nil ||
    NSClassFromString("XCTest") != nil
}
