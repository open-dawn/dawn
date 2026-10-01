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

final class DawnLoggingTests: XCTestCase {
    func testBasicLog() {
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

    func testLogWithLevelAndCategory() {
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

    func testPreservesPrivacyInterpolation() {
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

    func testRawStringInterpolation() {
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

    func testMultilineLog() {
        assertMacroExpansion(
            #"""
            #log(
            """
            Connection failed; \
            retrying
            """,
            level: .error,
            category: .transport
            )
            """#,
            expandedSource: #"""
                Loggers.transport.error(
                    """
                    [\(#fileID, privacy: .public):\(#line, privacy: .public) \#
                \(#function, privacy: .public)] Connection failed; \
                    retrying
                    """)
                """#,
            macros: testMacros
        )
    }

    func testMultilineLogPreservesPrivacyInterpolation() {
        assertMacroExpansion(
            #"""
            #log(
                """
                ID: \(id, privacy: .private); \
                retrying
                """,
                level: .info,
                category: .settings
            )
            """#,
            expandedSource: #"""
                Loggers.settings.info(
                    """
                    [\(#fileID, privacy: .public):\(#line, privacy: .public) \#
                \(#function, privacy: .public)] ID: \(id, privacy: .private); \
                    retrying
                    """)
                """#,
            macros: testMacros
        )
    }
}
