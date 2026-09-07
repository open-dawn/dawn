import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(PaLoggingMacros)
import PaLoggingMacros

let testMacros: [String: Macro.Type] = [
    "log": LogMacro.self,
]
#endif

final class PaLoggingTests: XCTestCase {
    func testBasicLog() throws {
        assertMacroExpansion(
            """
            #log("Hello")
            """,
            expandedSource: #"""
            PaLoggers.general.debug("[\(#fileID, privacy: .public):\(#line, privacy: .public) \(#function, privacy: .public)] Hello")
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
            PaLoggers.transport.info("[\(#fileID, privacy: .public):\(#line, privacy: .public) \(#function, privacy: .public)] Connection established")
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
            PaLoggers.settings.info("[\(#fileID, privacy: .public):\(#line, privacy: .public) \(#function, privacy: .public)] ID: \(id, privacy: .private)")
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
          PaLoggers.settings.debug(#"[\#(#fileID, privacy: .public):\#(#line, privacy: .public)
          \#(#function, privacy: .public)] ID: \#(id, privacy: .private)"#)
          """##,
          macros: testMacros
        )
    }
}
