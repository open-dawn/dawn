import OSLog

@freestanding(expression)
public macro log(
    _ message: OSLogMessage,
    level: PaLogLevel = .debug,
    category: PaLogCategory = .general
) = #externalMacro(
    module: "dawnLoggingMacros",
    type: "LogMacro"
)
