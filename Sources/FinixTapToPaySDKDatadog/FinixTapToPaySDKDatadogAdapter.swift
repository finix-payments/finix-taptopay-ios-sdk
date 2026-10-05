//
//  FinixTapToPaySDKDatadogAdapter.swift
//  FinixTapToPaySDKDatadog
//
//  Created by Tom Nguyen on 10/3/26.
//

import DatadogCore
import DatadogCrashReporting
import DatadogLogs
@_spi(FinixDatadog) import FinixTapToPaySDK
import Foundation

/// Links FinixTapToPaySDK to the app's copy of Datadog. The SDK finds it by its Objective-C name.
@objc(FinixTapToPaySDKDatadogAdapter)
final class FinixTapToPaySDKDatadogAdapter: NSObject, DatadogBootstrapping {
    func isInitialized(instanceName: String) -> Bool {
        Datadog.isInitialized(instanceName: instanceName)
    }

    func isDefaultInstanceInitialized() -> Bool {
        Datadog.isInitialized()
    }

    func initialize(instanceName: String, clientToken: String, env: String, service: String) {
        Datadog.initialize(
            with: Datadog.Configuration(clientToken: clientToken, env: env, service: service),
            trackingConsent: .granted,
            instanceName: instanceName
        )
    }

    func setUserInfo(instanceName: String, id: String, extraInfo: [String: String]) {
        Datadog.setUserInfo(
            id: id,
            extraInfo: extraInfo,
            in: Datadog.sdkInstance(named: instanceName)
        )
    }

    func enableLogs(instanceName: String) {
        Logs.enable(in: Datadog.sdkInstance(named: instanceName))
    }

    func enableCrashReporting(instanceName: String) {
        CrashReporting.enable(in: Datadog.sdkInstance(named: instanceName))
    }

    func makeLogger(
        instanceName: String,
        service: String,
        name: String,
        remoteLogThreshold: DatadogLogLevel,
        consoleLogPrefix: String?
    ) -> DatadogLogSinking {
        let logger = Logger.create(
            with: Logger.Configuration(
                service: service,
                name: name,
                networkInfoEnabled: true,
                remoteLogThreshold: remoteLogThreshold.logLevel,
                consoleLogFormat: consoleLogPrefix.map { .shortWith(prefix: $0) } ?? .short
            ),
            in: Datadog.sdkInstance(named: instanceName)
        )
        return LogSink(logger: logger)
    }
}

private struct LogSink: DatadogLogSinking {
    let logger: LoggerProtocol

    func log(level: DatadogLogLevel, message: String, attributes: [String: Encodable]?) {
        switch level {
            case .debug:
                logger.debug(message, attributes: attributes)
            case .info:
                logger.info(message, attributes: attributes)
            case .warn:
                logger.warn(message, attributes: attributes)
            case .error:
                logger.error(message, attributes: attributes)
        }
    }
}

private extension DatadogLogLevel {
    var logLevel: DatadogLogs.LogLevel {
        switch self {
            case .debug:
                .debug
            case .info:
                .info
            case .warn:
                .warn
            case .error:
                .error
        }
    }
}
