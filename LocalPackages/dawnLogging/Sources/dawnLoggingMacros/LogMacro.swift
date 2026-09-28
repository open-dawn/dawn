import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LogMacro: ExpressionMacro {

    private static let supportedLevels = [
        "trace",
        "debug",
        "info",
        "notice",
        "warning",
        "error",
        "critical",
    ]

    private static let supportedCategories = [
        "general",
        "appLifecycle",
        "settings",
        "userInterface",
        "eventBus",
        "transport",
    ]

    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        let message = try messageLiteral(from: node)

        let level = try argumentCase(
            named: "level",
            default: "debug",
            from: node
        )

        let category = try argumentCase(
            named: "category",
            default: "general",
            from: node
        )

        try validate(level: level, category: category)

        var messageWithCallSite = message
        let pounds = message.openingPounds

        messageWithCallSite.segments = StringLiteralSegmentListSyntax {
            StringSegmentSyntax(content: .stringSegment("["))

            publicInterpolation(
                ExprSyntax("#fileID"),
                pounds: pounds
            )

            StringSegmentSyntax(content: .stringSegment(":"))

            publicInterpolation(
                ExprSyntax("#line"),
                pounds: pounds
            )

            StringSegmentSyntax(content: .stringSegment(" "))

            publicInterpolation(
                "#function",
                pounds: pounds
            )

            StringSegmentSyntax(content: .stringSegment("] "))

            for segment in message.segments {
                segment
            }
        }

        return """
            Loggers.\(raw: category).\(raw: level)(\(messageWithCallSite))
            """
    }

    private static func messageLiteral(
        from node: some FreestandingMacroExpansionSyntax
    ) throws -> StringLiteralExprSyntax {
        guard
            let message = node.arguments.first?
                .expression.as(StringLiteralExprSyntax.self)
        else {
            throw MacroExpansionErrorMessage(
                "#log requires a string literal."
            )
        }

        let isMultiline = message.openingQuote.tokenKind == .multilineStringQuote

        guard !isMultiline else {
            throw MacroExpansionErrorMessage(
                "#log does nto currently support multiline string literals"
            )
        }

        return message
    }

    private static func validate(
        level: String,
        category: String
    ) throws {
        guard supportedLevels.contains(level) else {
            throw MacroExpansionErrorMessage(
                "Unsupported log level: \(level)"
            )
        }

        guard supportedCategories.contains(category) else {
            throw MacroExpansionErrorMessage(
                "Unsupported log category: \(category)"
            )
        }
    }

    private static func argumentCase(
        named label: String,
        default defaultValue: String,
        from node: some FreestandingMacroExpansionSyntax
    ) throws -> String {
        guard
            let argument = node.arguments.first(
                where: { $0.label?.text == label }
            )
        else {
            return defaultValue
        }

        guard
            let memberAccess = argument.expression.as(
                MemberAccessExprSyntax.self
            )
        else {
            throw MacroExpansionErrorMessage(
                "\(label) must be an enum case"
            )
        }

        return memberAccess.declName.baseName.text
    }

    private static func publicInterpolation(
        _ expression: ExprSyntax,
        pounds: TokenSyntax?
    ) -> ExpressionSegmentSyntax {
        ExpressionSegmentSyntax(
            pounds: pounds,
            expressions: LabeledExprListSyntax {
                LabeledExprSyntax(expression: expression)

                LabeledExprSyntax(
                    label: "privacy",
                    colon: .colonToken(trailingTrivia: .space),
                    expression: ExprSyntax(".public")
                )
            }
        )
    }
}

@main
struct dawnLoggingPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LogMacro.self
    ]
}
