import Combine
import Foundation
import StoreKit

@MainActor
final class PremiumManager: ObservableObject {
    enum LockedFeature {
        case all
        case stationChart
        case widgets
        case experimentalMap

        var title: String {
            switch self {
            case .all:
                return "Premium funkcije"
            case .stationChart:
                return "Graf postaje"
            case .widgets:
                return "Widget"
            case .experimentalMap:
                return "Eksperimentalni pogled"
            }
        }
    }

    enum PurchaseError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "Nakup ni bil uspešno preverjen."
            }
        }
    }

    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isTestFlightBuild = false
    @Published var paywallFeature: LockedFeature = .all
    @Published var isPaywallPresented = false
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init(startLiveTasks: Bool = true) {
        hasPremiumAccess = PremiumAccessSharedStore.readIsPremiumUnlocked()

        guard startLiveTasks else { return }

        transactionUpdatesTask = Task { [weak self] in
            guard let self else { return }
            await self.bootstrap()
            await self.observeTransactionUpdates()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func presentPaywall(for feature: LockedFeature = .all) {
        paywallFeature = feature
        isPaywallPresented = true
    }

    func loadProductsIfNeeded() async {
        guard products.isEmpty else { return }
        await loadProducts(forceReload: false)
    }

    func loadProducts(forceReload: Bool) async {
        if isLoadingProducts { return }
        if !forceReload, !products.isEmpty { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: PremiumStoreConfig.productIDs)
            products = fetched.sorted(by: Self.sortProducts)
        } catch {
            errorMessage = "Produktov trenutno ni mogoče naložiti. Poskusi znova."
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlementStatus()
                if hasPremiumAccess {
                    isPaywallPresented = false
                }

            case .pending:
                errorMessage = "Nakup je v obdelavi."

            case .userCancelled:
                break

            @unknown default:
                errorMessage = "Nakup ni uspel."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlementStatus()
        } catch {
            errorMessage = "Obnova nakupov ni uspela."
        }
    }

    func refreshEntitlementStatus() async {
        let isTestFlight = await DistributionChannel.currentIsTestFlight()
        if isTestFlightBuild != isTestFlight {
            isTestFlightBuild = isTestFlight
        }

        if isTestFlight {
            applyPremiumState(true)
            return
        }

        var unlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard PremiumStoreConfig.productIDs.contains(transaction.productID) else {
                continue
            }

            if transaction.revocationDate != nil {
                continue
            }

            if let expirationDate = transaction.expirationDate,
               expirationDate < Date() {
                continue
            }

            unlocked = true
            break
        }

        applyPremiumState(unlocked)
    }

    static func preview(unlocked: Bool) -> PremiumManager {
        let manager = PremiumManager(startLiveTasks: false)
        manager.applyPremiumState(unlocked, persist: false)
        return manager
    }

    private func bootstrap() async {
        await loadProducts(forceReload: false)
        await refreshEntitlementStatus()
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
            await refreshEntitlementStatus()
        }
    }

    private func applyPremiumState(_ unlocked: Bool, persist: Bool = true) {
        hasPremiumAccess = unlocked

        guard persist else { return }
        PremiumAccessSharedStore.write(isPremiumUnlocked: unlocked)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private static func sortProducts(_ lhs: Product, _ rhs: Product) -> Bool {
        if lhs.price != rhs.price {
            return lhs.price < rhs.price
        }

        return lhs.id < rhs.id
    }
}

enum PremiumStoreConfig {
    // Uskladi ID-je z App Store Connect produkti.
    static let productIDs: [String] = [
        "com.david.Zrak.premium.lifetime"
    ]
}

enum DistributionChannel {
    static func currentIsTestFlight() async -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        do {
            let verification = try await AppTransaction.shared

            switch verification {
            case .verified(let appTransaction):
                return appTransaction.environment == .sandbox

            case .unverified(let appTransaction, _):
                // Fallback inferenca okolja, tudi če preverjanje ni uspelo.
                return appTransaction.environment == .sandbox
            }
        } catch {
            return false
        }
        #endif
    }
}
