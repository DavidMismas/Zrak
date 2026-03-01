# Zrak Premium - App Purchase setup

## Product IDs (must match code)
- `com.david.Zrak.premium.lifetime`

IDs are used in `/Users/david/Documents/CODE/Zrak/Zrak/Services/PremiumManager.swift` (`PremiumStoreConfig.productIDs`).

## Features locked behind premium entitlement
- Station detail chart
- All widgets (small/medium/large)
- Experimental Slovenia interpolation view

## TestFlight behavior
- TestFlight and App Review use sandbox purchase flow.
- Premium is unlocked only after successful purchase or restore (same behavior as production).

## App Store Connect checklist
1. Add one non-consumable product:
   - `com.david.Zrak.premium.lifetime`
2. Fill localizations, screenshots, review notes.
3. Ensure product is in **Ready to Submit** or **Approved**.
4. Upload build and test purchases in Sandbox/TestFlight.

## Local testing in Xcode
- StoreKit test file: `/Users/david/Documents/CODE/Zrak/StoreKit/Zrak.storekit`
- Run scheme `Zrak` with StoreKit configuration enabled.
