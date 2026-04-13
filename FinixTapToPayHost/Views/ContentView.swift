//
//  ContentView.swift
//  FinixTapToPayHost
//
//  Created by Israrul Haque on 06/04/26.
//

import FinixTapToPaySDK
import SwiftUI

@available(iOS 16.4, *)
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel

    init() {
        _viewModel = StateObject(wrappedValue: ContentViewModel())
    }

    var body: some View {
        NavigationView {
            Form {
                statusSection
                transactionSection
                logsSection
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.showConfigurationSheet = true
                        } label: {
                            Label("Configuration", systemImage: "gearshape")
                        }
                        Button {
                            viewModel.onLinkAccountTapped()
                        } label: {
                            Label("Link Account", systemImage: "link.icloud")
                        }
                        Button {
                            viewModel.onClearCachesTapped()
                        } label: {
                            Label("Clear Caches", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .renderingMode(.template)
                            .foregroundColor(.blue)
                    }
                }
            }
            .alert(viewModel.alertObject.title, isPresented: $viewModel.showingAlert) {
                Button("OK") {}
            } message: {
                Text(viewModel.alertObject.message)
            }
            .sheet(isPresented: $viewModel.showConfigurationSheet) {
                NavigationView {
                    ConfigurationView(viewModel: viewModel)
                }
            }
            .navigationTitle("Finix Tap to Pay")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section(header: Text("STATUS")) {
            HStack {
                Text(viewModel.statusText)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    viewModel.onPrepareTapped()
                }) {
                    Text("Prepare")
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }

            Text("Selected environment: \(viewModel.selectedEnvironment.stringValue)")
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var transactionSection: some View {
        Section(header: transactionHeader) {
            HStack(spacing: 8) {
                Text("Amount")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 100, alignment: .leading)

                HStack(spacing: 4) {
                    Text("$")
                        .font(.body)
                        .foregroundColor(.gray)

                    TextField("0.00", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }

            transactionButtons
        }
    }

    private var transactionHeader: some View {
        HStack(spacing: 8) {
            Text("TRANSACTION")

            if viewModel.currentTransactionStatus == .processing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    @ViewBuilder
    private var transactionButtons: some View {
        switch viewModel.currentTransactionStatus {
            case .processing:
                FinixButton(
                    title: "Cancel \(viewModel.selectedTransactionType?.displayName ?? "Transaction")",
                    style: .cancel,
                    action: {
                        viewModel.onCancelTapped()
                    }
                )
            case .success:
                FinixButton(
                    title: "\(viewModel.selectedTransactionType?.displayName ?? "Transaction") Complete",
                    style: .success,
                    action: {}
                )
            case .failed:
                FinixButton(
                    title: "\(viewModel.selectedTransactionType?.displayName ?? "Transaction") Failed",
                    style: .failed,
                    action: {}
                )
            default:
                VStack(spacing: 8) {
                    // Transaction type selection
                    HStack(spacing: 8) {
                        TransactionTypeButton(
                            title: "Sale",
                            isSelected: viewModel.selectedTransactionType == .sale
                        ) {
                            viewModel.onSaleTapped()
                        }

                        TransactionTypeButton(
                            title: "Auth",
                            isSelected: viewModel.selectedTransactionType == .authorization
                        ) {
                            viewModel.onAuthTapped()
                        }

                        TransactionTypeButton(
                            title: "Refund",
                            isSelected: viewModel.selectedTransactionType == .refund
                        ) {
                            viewModel.onRefundTapped()
                        }
                    }

                    // Tap to Pay button - always visible, disabled until ready
                    TapToPayButton(
                        isEnabled: viewModel.isReaderReady && viewModel
                            .selectedTransactionType != nil
                    ) {
                        viewModel.onTapToPayTapped()
                    }
                }
        }
    }

    private var logsSection: some View {
        Section(header: logsHeader) {
            ScrollView {
                ScrollViewReader { proxy in
                    Text(viewModel.logOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                        .padding(12)
                        .background(Color(uiColor: .systemGroupedBackground))
                        .cornerRadius(8)
                        .id("bottom")
                        .onChange(of: viewModel.logOutput) { _ in
                            DispatchQueue.main.async {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                }
            }
            .frame(height: 280)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
        }
    }

    private var logsHeader: some View {
        HStack {
            Text("LOGS")

            Spacer()

            if !viewModel.logOutput.isEmpty, viewModel.logOutput != "No activity yet" {
                Button(action: {
                    viewModel.onClearLogsTapped()
                }) {
                    Text("Clear")
                        .font(Font.system(size: 15))
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Finix Button

struct FinixButton: View {
    enum Style {
        case primary
        case secondary
        case cancel
        case success
        case failed
    }

    let title: String
    var style: Style = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(backgroundColor)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        switch style {
            case .primary:
                Color.blue
            case .secondary:
                Color(uiColor: .systemGray5)
            case .cancel:
                Color.red
            case .success:
                Color.green
            case .failed:
                Color.red
        }
    }

    private var foregroundColor: Color {
        switch style {
            case .primary, .cancel, .success, .failed:
                .white
            case .secondary:
                .primary
        }
    }
}

// MARK: - Transaction Type Selection Button

struct TransactionTypeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(isSelected ? Color.blue : Color(uiColor: .systemGray5))
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tap to Pay Button (Apple Specifications)

struct TapToPayButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if isEnabled {
                action()
            }
        }) {
            Label("Tap to Pay on iPhone", systemImage: "wave.3.right.circle")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isEnabled ? .white : Color(uiColor: .systemGray))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(isEnabled ? Color.black : Color(uiColor: .systemGray5))
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
