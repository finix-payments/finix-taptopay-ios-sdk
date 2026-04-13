//
//  ContentViewModel.swift
//  FinixTapToPayHost
//
//  Created by Israrul Haque on 06/04/26.
//

import Combine
import FinixTapToPaySDK
import Foundation
import SwiftUI

typealias TapToPayEnvironment = TapToPayConfiguration.Environment

@available(iOS 16.4, *)
class ContentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var statusText: String = "Not Ready"
    @Published var amountText: String = "54.13"
    @Published var logOutput: String = "No activity yet"
    @Published var currentTransactionStatus: TransactionStatus? = nil
    @Published var selectedTransactionType: TransactionType? = nil
    @Published var showingAlert: Bool = false
    @Published var alertObject: AlertObject = .init(title: "", message: "")
    @Published var showConfigurationSheet: Bool = false

    @Published var selectedEnvironment: TapToPayEnvironment = .qa

    var isReaderReady: Bool {
        statusText.lowercased().contains("ready")
    }

    // MARK: - Private Properties

    private var finixTapToPay: FinixTapToPay?
    var currentConfiguration: TapToPayConfiguration? // Made accessible for ConfigurationView
    private var currentTransactionTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupInitialConfiguration()
    }

    // MARK: - Setup

    private func setupInitialConfiguration() {
        // Auto-fill QA credentials
        let credentials = TapToPayConfiguration.APICredentials(
            username: "US5jmtgVCr2x29u2GfwLVQKe",
            password: "e0e84764-f0ae-4bfd-84bd-38f6b72dd7f2"
        )

        let merchant = TapToPayConfiguration.MerchantInfo(
            merchantId: "MUsq3Cs2YxjjTpKHJFHb4ukK",
            merchantMid: "b02ef42b-e4e4-4131-800d-5e909c8a78c2",
            merchantName: "Alpheratz LLC"
        )

        let deviceId = "DVvjrYhamHrwzkZKR2KgBmS5"

        let configuration = TapToPayConfiguration(
            credentials: credentials,
            merchant: merchant,
            environment: .qa,
            deviceId: deviceId,
            transactionOptions: TapToPayConfiguration.TransactionOptions(
                returnReadResultImmediately: true,
                autoPrepareOnForeground: true
            )
        )

        updateConfiguration(configuration)
    }

    func updateConfiguration(_ configuration: TapToPayConfiguration) {
        currentConfiguration = configuration
        selectedEnvironment = configuration.environment
        finixTapToPay = FinixTapToPay(configuration: configuration)

        addLog("Configuration updated for environment: \(configuration.environment.stringValue)")
        addLog("Merchant: \(configuration.merchant.merchantId)")
        addLog("Device: \(configuration.deviceId)")

        // Check link status
        Task {
            await checkLinkStatus()
        }
    }

    // MARK: - Actions

    func onLinkAccountTapped() {
        addLog("=== Link Account ===")

        guard let sdk = finixTapToPay else {
            statusText = "SDK not initialized"
            addLog("ERROR: SDK not initialized")
            return
        }

        statusText = "Linking..."

        Task {
            do {
                try await sdk.linkAccount()
                await MainActor.run {
                    statusText = "Account Linked - Ready to Prepare"
                    addLog("✅ Account linked successfully")
                }
            } catch {
                let errorString = error.localizedDescription
                let nsError = error as NSError

                // ProximityReader.PaymentCardReaderError code 20 = accountAlreadyLinked
                if nsError.domain == "ProximityReader.PaymentCardReaderError", nsError.code == 20 {
                    await MainActor.run {
                        statusText = "Account Already Linked - Ready to Prepare"
                        addLog("ℹ️ Account already linked")
                    }
                } else {
                    await MainActor.run {
                        statusText = "Link Failed"
                        addLog("❌ Link failed: \(errorString)")
                    }
                }
            }
        }
    }

    func onPrepareTapped() {
        addLog("=== Prepare Reader ===")

        guard let sdk = finixTapToPay else {
            statusText = "SDK not initialized"
            addLog("ERROR: SDK not initialized")
            return
        }

        statusText = "Preparing..."

        Task {
            do {
                try await sdk.prepareReader()
                await MainActor.run {
                    statusText = "Tap to Pay on iPhone is READY"
                    addLog("✅ Reader prepared successfully")
                }
            } catch {
                await MainActor.run {
                    statusText = "Prepare Failed"
                    addLog("❌ Prepare failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func onClearCachesTapped() {
        addLog("=== Clear Caches ===")

        guard let sdk = finixTapToPay else {
            addLog("ERROR: SDK not initialized")
            return
        }

        sdk.clearAllCaches()
        statusText = "Caches Cleared - Checking Status..."
        addLog("✅ All caches cleared")

        // Re-initialize
        if let config = currentConfiguration {
            finixTapToPay = FinixTapToPay(configuration: config)
        }

        Task {
            await checkLinkStatus()
        }
    }

    func onSaleTapped() {
        selectedTransactionType = .sale
    }

    func onAuthTapped() {
        selectedTransactionType = .authorization
    }

    func onRefundTapped() {
        selectedTransactionType = .refund
    }

    func onTapToPayTapped() {
        guard let transactionType = selectedTransactionType else {
            showAlert(
                title: "Select Transaction Type",
                message: "Please select Sale, Auth, or Refund first"
            )
            return
        }
        startTransaction(type: transactionType)
    }

    func onCancelTapped() {
        currentTransactionTask?.cancel()
        currentTransactionTask = nil
        currentTransactionStatus = nil
        addLog("Transaction cancelled by user")
    }

    private func onTransactionFinished() {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Wait for 2 seconds then reset to show transaction buttons again
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                currentTransactionStatus = nil
                selectedTransactionType = nil
            }
        }
    }

    func onClearLogsTapped() {
        logOutput = "No activity yet"
    }

    // MARK: - Private Methods

    private func checkLinkStatus() async {
        guard let sdk = finixTapToPay else { return }

        let isLinked = await sdk.isAccountLinked()
        await MainActor.run {
            if isLinked {
                statusText = "Account Linked - Ready to Prepare"
                addLog("ℹ️ Account is linked")
            } else {
                statusText = "Account Not Linked"
                addLog("⚠️ Account not linked - use menu to link")
            }
        }
    }

    private func startTransaction(type: TransactionType) {
        guard let sdk = finixTapToPay else {
            showAlert(title: "Error", message: "SDK not initialized")
            return
        }

        // Validate amount
        guard let amount = Double(amountText), amount > 0 else {
            showAlert(title: "Invalid Amount", message: "Please enter a valid amount")
            return
        }

        let amountInCents = Int(amount * 100)

        addLog("=== Start Transaction ===")
        addLog("Type: \(type.displayName)")
        addLog("Amount: $\(amountText) (\(amountInCents) cents)")

        currentTransactionStatus = .processing

        currentTransactionTask = Task {
            do {
                let result = try await sdk.startTransaction(
                    amount: amountInCents,
                    currency: "USD",
                    type: type
                )

                await MainActor.run {
                    currentTransactionStatus = .success
                    logTransactionResult(result)
                    onTransactionFinished()
                }
            } catch TapToPayError.transactionCancelled {
                await MainActor.run {
                    currentTransactionStatus = .failed
                    addLog("❌ Transaction cancelled")
                    onTransactionFinished()
                }
            } catch {
                await MainActor.run {
                    currentTransactionStatus = .failed
                    addLog("❌ Transaction failed: \(error.localizedDescription)")
                    onTransactionFinished()
                }
            }
        }
    }

    private func logTransactionResult(_ result: TapToPayTransactionResult) {
        addLog("✅ Transaction Successful")
        addLog("Amount: \(result.amount) \(result.currency)")
        addLog("Card: \(result.cardBrand ?? "Unknown") *\(result.last4 ?? "****")")
        addLog("Type: \(result.cardType ?? "Unknown")")
        addLog("Transaction ID: \(result.transactionIdentifier ?? "N/A")")
        addLog("Transfer ID: \(result.transferId ?? "N/A")")
        addLog("Transfer State: \(result.transferState ?? "N/A")")
        addLog("Time: \(result.timestamp)")
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )
        let logEntry = "[\(timestamp)] \(message)"

        DispatchQueue.main.async {
            if self.logOutput == "No activity yet" {
                self.logOutput = logEntry
            } else {
                self.logOutput += "\n" + logEntry
            }
        }
    }

    private func showAlert(title: String, message: String) {
        alertObject = AlertObject(title: title, message: message)
        showingAlert = true
    }
}

// MARK: - Supporting Types

enum TransactionStatus {
    case processing
    case success
    case failed
}

struct AlertObject {
    let title: String
    let message: String
}

extension TapToPayEnvironment {
    var stringValue: String {
        switch self {
            case .production:
                "Production"
            case .sandbox:
                "Sandbox"
            case .qa:
                "QA"
            @unknown default:
                "Unknown"
        }
    }
}
