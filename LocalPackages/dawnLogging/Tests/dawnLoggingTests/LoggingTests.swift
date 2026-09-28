import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(dawnLoggingMacros)
import dawnLoggingMacros

let testMacros: [String: Macro.Type] = [
    "log": LogMacro.self
]
#endif

final class dawnLoggingTests: XCTestCase {
    func testBasicLog() throws {
        assertMacroExpansion(
            """
            #log("Hello")
            """,
            expandedSource: #"""
            Loggers.general.debug("[\(#fileID, privacy: .public):\(#line, privacy: .public) \#
            \(#function, privacy: .public)] Hello")
            """#,
            macros: testMacros
        )
    }

    func testLogWithLevelAndCategory() throws {
        assertMacroExpansion(
            """
            #log("Connection established", level: .info, category: .transport)
            """,
            expandedSource: #"""
            Loggers.transport.info("[\(#fileID, privacy: .public):\(#line, privacy: .public) \#
            \(#function, privacy: .public)] Connection established")
            """#,
            macros: testMacros
        )
    }

    func testPreservesPrivacyInterpolation() throws {
        assertMacroExpansion(
            #"""
            #log("ID: \(id, privacy: .private)", level: .info, category: .settings)
            """#,
            expandedSource: #"""
            Loggers.settings.info("[\(#fileID, privacy: .public):\(#line, privacy: .public) \#
            \(#function, privacy: .public)] ID: \(id, privacy: .private)")
            """#,
            macros: testMacros
        )
    }

    func testRawStringInterpolation() throws {
        assertMacroExpansion(
          ##"""
          #log(#"ID: \#(id, privacy: .private)"#, category: .settings)
          """##,
          expandedSource: ##"""
          Loggers.settings.debug(#"[\#(#fileID, privacy: .public):\#(#line, privacy: .public) \##
          \#(#function, privacy: .public)] ID: \#(id, privacy: .private)"#)
          """##,
          macros: testMacros
        )
    }
}
