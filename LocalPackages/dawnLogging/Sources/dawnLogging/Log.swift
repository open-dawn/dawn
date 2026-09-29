import OSLog

@freestanding(expression)
public macro log(
    _ message: OSLogMessage,
    level: LogLevel = .debug,
    category: LogCategory = .general
) = #externalMacro(
    module: "dawnLoggingMacros",
    type: "LogMacro"
)
