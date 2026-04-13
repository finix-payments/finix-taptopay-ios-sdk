//
//  ConfigurationView.swift
//  FinixTapToPayHost
//
//  Created by Israrul Haque on 06/04/26.
//

import FinixTapToPaySDK
import SwiftUI

struct ConfigurationView: View {
    @ObservedObject var viewModel: ContentViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var selectedEnvironment: TapToPayEnvironment = .qa
    @State private var deviceId: String = ""
    @State private var merchantId: String = ""
    @State private var merchantMid: String = ""
    @State private var merchantName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    @State private var showValidationAlert = false
    @State private var missingFields: [String] = []

    var body: some View {
        Form {
            Section(header: Text("ENVIRONMENT")) {
                Picker("Environment", selection: $selectedEnvironment) {
                    Text("Production").tag(TapToPayEnvironment.production)
                    Text("Sandbox").tag(TapToPayEnvironment.sandbox)
                    Text("QA").tag(TapToPayEnvironment.qa)
                }
                .pickerStyle(SegmentedPickerStyle())
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(UIColor.systemGroupedBackground))
                .onChange(of: selectedEnvironment) { newEnvironment in
                    loadDefaultsForEnvironment(newEnvironment)
                }
            }

            Section(header: Text("DEVICE")) {
                HStack {
                    Text("ID")
                        .font(.headline)
                        .frame(width: 100, alignment: .leading)
                    ClearableTextField(title: "Enter Device ID", text: $deviceId)
                }
            }

            Section(header: Text("MERCHANT")) {
                HStack {
                    Text("ID")
                        .font(.headline)
                        .frame(width: 100, alignment: .leading)
                    ClearableTextField(title: "Enter Merchant ID", text: $merchantId)
                }

                HStack {
                    Text("MID")
                        .font(.headline)
                        .frame(width: 100, alignment: .leading)
                    ClearableTextField(title: "Enter Merchant MID", text: $merchantMid)
                }

                HStack {
                    Text("Name")
                        .font(.headline)
                        .frame(width: 100, alignment: .leading)
                    ClearableTextField(title: "Enter Merchant Name", text: $merchantName)
                }
            }

            Section(header: Text("API KEY")) {
                HStack {
                    Text("Username")
                        .font(.headline)
                        .frame(width: 100, alignment: .leading)
                    ClearableTextField(title: "Enter Username", text: $username)
                }

                HStack {
                    Text("Password")
                        .font(.headline)
                        .frame(width: 100, alignment: .leading)
                    ClearableTextField(title: "Enter Password", text: $password)
                }
            }
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if validateConfiguration() {
                        saveConfiguration()
                        dismiss()
                    } else {
                        showValidationAlert = true
                    }
                }
                .font(.system(size: 17, weight: .medium))
            }
        }
        .alert("Missing Required Fields", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please fill in all required fields:\n\n\(missingFields.joined(separator: "\n"))")
        }
        .onAppear {
            loadCurrentConfiguration()
        }
    }

    private func loadCurrentConfiguration() {
        // Load from viewModel's current configuration
        if let config = viewModel.currentConfiguration {
            selectedEnvironment = config.environment
            deviceId = config.deviceId
            merchantId = config.merchant.merchantId
            merchantMid = config.merchant.merchantMid
            merchantName = config.merchant.merchantName
            username = config.credentials.username
            password = config.credentials.password
        } else {
            // Load QA defaults on first load
            loadDefaultsForEnvironment(.qa)
        }
    }

    private func loadDefaultsForEnvironment(_ environment: TapToPayEnvironment) {
        switch environment {
            case .qa:
                // QA test credentials (auto-filled but editable)
                deviceId = "DVvjrYhamHrwzkZKR2KgBmS5"
                merchantId = "MUsq3Cs2YxjjTpKHJFHb4ukK"
                merchantMid = "b02ef42b-e4e4-4131-800d-5e909c8a78c2"
                merchantName = "Alpheratz LLC"
                username = "US5jmtgVCr2x29u2GfwLVQKe"
                password = "e0e84764-f0ae-4bfd-84bd-38f6b72dd7f2"

            case .sandbox:
                // Clear for sandbox (user needs to provide their own)
                deviceId = ""
                merchantId = ""
                merchantMid = ""
                merchantName = ""
                username = ""
                password = ""

            case .production:
                // Clear for production (user needs to provide their own)
                deviceId = ""
                merchantId = ""
                merchantMid = ""
                merchantName = ""
                username = ""
                password = ""

            @unknown default:
                // Default to QA credentials for unknown environments
                deviceId = "DVvjrYhamHrwzkZKR2KgBmS5"
                merchantId = "MUsq3Cs2YxjjTpKHJFHb4ukK"
                merchantMid = "b02ef42b-e4e4-4131-800d-5e909c8a78c2"
                merchantName = "Alpheratz LLC"
                username = "US5jmtgVCr2x29u2GfwLVQKe"
                password = "e0e84764-f0ae-4bfd-84bd-38f6b72dd7f2"
        }
    }

    private func validateConfiguration() -> Bool {
        missingFields.removeAll()

        if deviceId.trimmingCharacters(in: .whitespaces).isEmpty {
            missingFields.append("• Device ID")
        }
        if merchantId.trimmingCharacters(in: .whitespaces).isEmpty {
            missingFields.append("• Merchant ID")
        }
        if merchantMid.trimmingCharacters(in: .whitespaces).isEmpty {
            missingFields.append("• Merchant MID")
        }
        if merchantName.trimmingCharacters(in: .whitespaces).isEmpty {
            missingFields.append("• Merchant Name")
        }
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            missingFields.append("• Username")
        }
        if password.trimmingCharacters(in: .whitespaces).isEmpty {
            missingFields.append("• Password")
        }

        return missingFields.isEmpty
    }

    private func saveConfiguration() {
        let credentials = TapToPayConfiguration.APICredentials(
            username: username.trimmingCharacters(in: .whitespaces),
            password: password.trimmingCharacters(in: .whitespaces)
        )

        let merchant = TapToPayConfiguration.MerchantInfo(
            merchantId: merchantId.trimmingCharacters(in: .whitespaces),
            merchantMid: merchantMid.trimmingCharacters(in: .whitespaces),
            merchantName: merchantName.trimmingCharacters(in: .whitespaces)
        )

        let configuration = TapToPayConfiguration(
            credentials: credentials,
            merchant: merchant,
            environment: selectedEnvironment,
            deviceId: deviceId.trimmingCharacters(in: .whitespaces),
            transactionOptions: TapToPayConfiguration.TransactionOptions(
                returnReadResultImmediately: true,
                autoPrepareOnForeground: true
            )
        )

        viewModel.updateConfiguration(configuration)
    }
}

struct ClearableTextField: View {
    let title: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            TextField(title, text: $text)
                .focused($isFocused)

            if !text.isEmpty, isFocused {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .padding(5)
                }
                .contentShape(Rectangle())
            }
        }
    }
}
