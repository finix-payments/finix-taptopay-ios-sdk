# FinixTapToPaySDK

Accept in-person contactless payments on iPhone with Apple's Tap to Pay — no card reader or extra hardware. The SDK wraps Apple's `ProximityReader` framework, manages payment tokens, and submits the transfer to Finix for you.

Buyers can pay with contactless credit and debit cards, Apple Pay, Google Pay, and other NFC wallets.

## Features

- Sale, authorization and refund transactions
- `async`/`await` API with a Combine publisher for transaction progress
- Apple ID account linking, including status caching and force-refresh
- Automatic reader warm-up on app foreground
- Localized buyer-facing UI via a BCP-47 language tag
- Submits the Finix transfer itself — the result carries `transferId` and `transferState`
- Diagnostics reported to Finix to support troubleshooting (opt-out available)

API traffic uses HTTPS with the system's certificate validation, enforced by App Transport Security.

## Requirements

| | |
|---|---|
| iOS | 18.1 or later |
| Device | iPhone XS or newer |
| Xcode | 16.0 or later |
| Swift | 5.9 or later |
| Account | Finix merchant account provisioned for in-person payments |
| Entitlement | `com.apple.developer.proximity-reader.payment.acceptance` |

Tap to Pay on iPhone is not available on iPad, on Android, or in the iOS Simulator — `FinixTapToPay.isSupported()` returns `false` there.

## Apple entitlement and Info.plist

Tap to Pay requires an Apple entitlement that you must request for **your own** app; it cannot be inherited from Finix.

1. Request the entitlement at [Apple's Tap to Pay on iPhone page](https://developer.apple.com/contact/request/tap-to-pay-on-iphone/). Apple grants a development entitlement first, then a distribution entitlement once you're ready to ship.
2. Add it to your target's `.entitlements` file:

```xml
<key>com.apple.developer.proximity-reader.payment.acceptance</key>
<true/>
```

3. Regenerate your provisioning profiles so they carry the entitlement.
4. Add an NFC usage description to your `Info.plist`:

```xml
<key>NFCReaderUsageDescription</key>
<string>This app uses NFC to accept contactless card payments.</string>
```

Apple also expects your app to show merchant education before the first tap, and requires that your use of Tap to Pay branding follows their [marketing guidelines](https://developer.apple.com/tap-to-pay/marketing-guidelines/).

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/finix-payments/finix-taptopay-ios-sdk.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies**, then enter
`https://github.com/finix-payments/finix-taptopay-ios-sdk.git`.

### Manual

Download the `FinixTapToPaySDK.xcframework` from the [releases page](https://github.com/finix-payments/finix-taptopay-ios-sdk/releases) and embed it in your target.

The SDK is distributed as a binary framework with its dependencies already linked in — you don't need to declare anything else.

## Quick start

### 1. Check device support

```swift
import FinixTapToPaySDK

guard FinixTapToPay.isSupported() else {
    // Hide all Tap to Pay UI on this device
    return
}
```

Gate every entry point on this. It is `false` on unsupported hardware, on iPad, and in the Simulator.

### 2. Provision a Finix device

Every iPhone that takes payments needs an activated Finix `Device`. Create it once per `(merchant, iPhone)` pair — see [Device provisioning](#device-provisioning) for the API calls — and persist the resulting `DV…` id.

### 3. Configure and initialize

```swift
let configuration = TapToPayConfiguration(
    credentials: .init(username: apiKey, password: apiSecret),
    merchant: .init(
        merchantId: "MU…",       // Finix Merchant id
        merchantMid: "…",        // Merchant's processor MID
        merchantName: "Coffee Bar"
    ),
    environment: .sandbox,       // .sandbox or .production
    deviceId: "DV…"              // from step 2
)

let tapToPay = FinixTapToPay(configuration: configuration)
```

Cache the instance and rebuild it only when `merchantId`, `merchantMid` **or** `environment` changes. Keying the cache on `merchantId` alone will reuse a configuration with a stale MID.

### 4. Link the merchant's Apple ID

```swift
if await tapToPay.isAccountLinked() == false {
    do {
        try await tapToPay.linkAccount()   // presents Apple's terms
    } catch TapToPayError.accountAlreadyLinked {
        // Already linked — treat as success
    }
}
```

`accountAlreadyLinked` is a success case, not a failure. See [Account linking](#account-linking).

### 5. Warm up the reader

```swift
try await tapToPay.prepareReader()
```

Call this at launch or on foreground once the account is linked. Preparation can take a few seconds on a cold start, so warming early keeps the tap itself responsive.

### 6. Take a payment

```swift
let events = tapToPay.transactionEvents.sink { event in
    switch event {
        case .preparingTransaction: showPreparing()
        case .readingCard:          showTapPrompt()
        case .cardRead:             showReadComplete()
        case .processing:           showProcessing()
        case .success(let result):  showReceipt(result)
        case .failure(let error):   showError(error)
    }
}

let result = try await tapToPay.startTransaction(
    amount: 1500,          // minor units — $15.00
    currency: "USD",
    type: .sale
)

print(result.transferId ?? "", result.transferState ?? "")
```

Navigate to your processing screen within about a second of the tap; Apple's UI appears immediately and a lagging app looks broken.

## Device provisioning

The SDK does not create devices — your backend does, so it can hold your API credentials. Do this once per `(merchant, iPhone)`.

**Step 1 — read Apple's reader identifier on the device:**

```swift
import ProximityReader

let readerIdentifier = try await PaymentCardReader().readerIdentifier
```

**Step 2 — your backend creates the Finix Device.** `app_bundle_id` is a top-level field:

```shell
curl -i -X POST \
  -u {api_key}:{api_secret} \
  https://finix.sandbox-payments-api.com/merchants/{merchant_id}/devices \
  -H 'Content-Type: application/json' \
  -H 'Finix-Version: 2022-02-01' \
  -d '{
    "model": "IOS_TAP_TO_PAY",
    "name": "iPhone Tap to Pay — Front Counter",
    "description": "iOS Tap to Pay device",
    "serial_number": "{readerIdentifier from step 1}",
    "app_bundle_id": "com.example.yourapp"
  }'
```

Use `https://finix.live-payments-api.com` for production. Copy `id` from the response — that's your `deviceId`.

**Step 3 — activate it.** Devices are created disabled:

```shell
curl -i -X PUT \
  -u {api_key}:{api_secret} \
  https://finix.sandbox-payments-api.com/devices/{device_id} \
  -H 'Content-Type: application/json' \
  -d '{ "action": "ACTIVATE" }'
```

**Step 4 — persist the `deviceId`** against the `(merchant, readerIdentifier)` pair. Apple's `readerIdentifier` is stable per install, so reuse the device rather than creating a new one each launch.

**Recovery:** if a transaction fails because the device isn't activated, discard the stored id and repeat steps 2-4. Devices don't transfer between merchants — a new merchant needs a new device.

## Account linking

Linking associates the merchant's Apple ID with Tap to Pay on that iPhone. Apple owns this binding:

- `linkAccount()` presents Apple's terms and conditions.
- The link survives app updates. It is removed only by deleting and reinstalling the app, or via the merchant's Apple ID settings — there is no programmatic unlink.
- The device is registered to the **signed-in Apple ID**. Testing several merchants or environments on one phone means switching Apple IDs, so plan for one Apple ID per test configuration.
- `isAccountLinked()` reads a cached answer (`linkStatusCacheDuration`, default 300s). Use `forceRefreshLinkStatus()` to bypass the cache, and `clearLinkStatus()` to drop it entirely.

Treat `accountAlreadyLinked` as success: Apple reports it when the account was linked previously.

## Transactions and events

| Type | `TransactionType` | Notes |
|---|---|---|
| Sale | `.sale` | Default — authorize and capture together |
| Authorization | `.authorization` | Capture later via the Finix API |
| Refund | `.refund` | Unreferenced refund to the tapped card |

`transactionEvents` publishes, in order:

`preparingTransaction → readingCard → cardRead → processing → success | failure`

`cancelTransaction()` ends an in-flight transaction; subscribers receive `.failure(.transactionCancelled)`.

`startTransaction` also accepts `identityId` to associate the payment with an existing Finix Identity (buyer).

The SDK re-prepares the reader after every transaction, as Apple requires — you don't need to call `prepareReader()` again between sales.

### Result

`TapToPayTransactionResult` carries `amount`, `currency`, `cardBrand`, `last4`, `maskedCardNumber`, `cardType`, `emvData`, `timestamp`, `approvalCode`, `traceId`, Finix's `transferId` and `transferState` (`SUCCEEDED`, `FAILED`, `PENDING`), plus Apple's `readerIdentifier` and `transactionIdentifier`.

Keep `readerIdentifier` and `transactionIdentifier` on your receipts or logs — Apple requires them when raising a support case.

## Localization

```swift
tapToPay.setUserInterfaceLanguage(Locale.Language(identifier: "fr-CA"))
```

Use a BCP-47 tag (`fr-CA`, not `fr_CA`). Pass `nil` to follow the device language.

## Errors

Every SDK call throws `TapToPayError`, which conforms to `LocalizedError`.

| Case | When | Handling |
|---|---|---|
| `notSupported` | Device or OS can't do Tap to Pay | Hide Tap to Pay UI |
| `notConfigured` | SDK used before configuration | Fix initialization order |
| `accountNotLinked` | No Apple ID linked yet | Call `linkAccount()` |
| `accountAlreadyLinked` | Account was already linked | Treat as success |
| `accountLinkingCancelled` | Merchant dismissed Apple's terms | Re-prompt later |
| `accountLinkingFailed(String?)` | Apple rejected linking | Show detail, offer retry |
| `accountLinkingCheckFailed` | Link status couldn't be read | Retry; check connectivity |
| `accountLinkingRequiresiCloudSignIn` | No iCloud account signed in | Ask merchant to sign in to iCloud |
| `accountDeactivated` | Apple deactivated the account | Merchant must contact Apple |
| `readerPreparationFailed(String?)` | Warm-up failed | Retry; verify entitlement |
| `transactionCancelled` | Cancelled by merchant or buyer | Return to the amount screen |
| `transactionFailed(String)` | Processing declined or errored | Show the message; allow retry |
| `tokenFetchFailed(String)` | Couldn't obtain a payment token | Check credentials and connectivity |
| `emptyReaderToken` / `invalidReaderToken(String?)` | Token rejected by Apple | Retry; then contact Finix support |
| `invalidMerchant` | Merchant not provisioned for Tap to Pay | Contact Finix |
| `merchantBlocked` | Merchant blocked from processing | Contact Finix |
| `deviceBanned(Date?)` | Apple banned this device, possibly until a date | Surface the date; contact Apple |
| `modelNotSupported` | iPhone model too old | Hide Tap to Pay UI |
| `networkAuthenticationError` | Network rejected authentication | Check credentials |
| `backgroundRequestNotAllowed` | Called while backgrounded | Retry in the foreground |
| `unknown(String)` | Unclassified failure | Log and report to Finix |

## Testing

Set `environment: .sandbox` with sandbox credentials to integrate without moving money. Because Tap to Pay registers the device to the signed-in Apple ID, keep a dedicated Apple ID for sandbox testing.

Tap to Pay cannot run in the Simulator, so end-to-end tests need a physical iPhone XS or newer with the development entitlement installed.

`TapToPayTransactionResult.mock(...)` builds a result for your own unit tests without touching the network.

## Privacy

The SDK ships a privacy manifest (`PrivacyInfo.xcprivacy`) declaring what it collects. It reports crash, performance and diagnostic data to Finix to support troubleshooting, linked to the merchant identifier and username you configure. It does **not** track users and declares no tracking domains. It reads and writes `UserDefaults` to cache account-link status (Apple reason `CA92.1`).

Opt out of crash reporting:

```swift
TapToPayConfiguration(/* … */, crashReportingEnabled: false)
```

Card data never passes through Finix in the clear — Apple encrypts it in the secure element before the SDK sees it.

The framework statically links Datadog's `dd-sdk-ios` (3.6.1) for diagnostics.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `isSupported()` is `false` on a real iPhone | Model older than XS, or iOS below 18.1 |
| `readerPreparationFailed` right after install | Entitlement missing from the build, or profile not regenerated |
| Transaction fails mentioning activation | Device created but never activated — repeat the `ACTIVATE` call |
| `tokenFetchFailed` | Wrong environment for the credentials, or MID not provisioned |
| Apple's sheet never appears | Not linked; call `linkAccount()` first |

## Demo app

A runnable integration lives in [finix-taptopay-ios-sdk-demo-app](https://github.com/finix-payments/finix-taptopay-ios-sdk-demo-app).

## Support

Contact your Finix point of contact, or open an issue on [the SDK repository](https://github.com/finix-payments/finix-taptopay-ios-sdk/issues).

## License

Proprietary — see [LICENSE](LICENSE). Use of the SDK is governed by your Finix services agreement. Release history is in [CHANGELOG.md](CHANGELOG.md).
