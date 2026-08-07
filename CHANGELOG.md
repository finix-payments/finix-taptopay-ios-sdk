# Changelog

All notable changes to FinixTapToPaySDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-08-07

Initial public release.

### Added

- Tap to Pay on iPhone payments via Apple's `ProximityReader`, for iOS 18.1+ on iPhone XS and newer
- Sale, authorization and refund transaction types
- `async`/`await` API with a Combine `transactionEvents` publisher reporting transaction progress
- Apple ID account linking with cached status, force-refresh and cache clearing
- Automatic reader preparation on app foreground, and automatic re-preparation after each transaction
- Finix transfer submission built in — results carry `transferId` and `transferState`
- Optional `identityId` on `startTransaction` to associate a payment with a Finix Identity
- Buyer-facing UI localization through a BCP-47 language tag
- Privacy manifest (`PrivacyInfo.xcprivacy`) declaring collected diagnostics and required-reason API use
- `crashReportingEnabled` configuration flag to opt out of crash reporting
- `Sendable` and `Equatable` conformances across the public models
- Swift Package Manager distribution as a binary xcframework

### Security

- Payment tokens are never written to logs at any level
- Remote log threshold raised so on-device debug logging is not transmitted
- Merchant diagnostics attached per log entry, leaving a host app's own Datadog user info untouched
