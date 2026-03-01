import StoreKit
import SwiftUI

struct PremiumPaywallView: View {
    @EnvironmentObject private var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    featureList
                    purchaseSection
                    restoreSection
                }
                .padding()
            }
            .navigationTitle("Zrak Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zapri") {
                        dismiss()
                    }
                }
            }
            .task {
                await premiumManager.loadProductsIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(premiumManager.paywallFeature.title)
                .font(.headline)

            if premiumManager.hasPremiumAccess {
                Text("Premium je aktiven na tej napravi.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text("Odkleni graf postaje, vse widgete in eksperimentalni zemljevid Slovenije.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = premiumManager.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kaj odklene Premium")
                .font(.headline)

            featureRow("Graf v pogledu posamezne postaje")
            featureRow("Widgeti (small, medium, large)")
            featureRow("Eksperimentalni interpolirani pogled Slovenije")
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nakup")
                .font(.headline)

            if premiumManager.isLoadingProducts {
                ProgressView("Nalagam ponudbe ...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if premiumManager.products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ni aktivnih produktov. Dodaj produkte v App Store Connect in preveri ID-je v `PremiumStoreConfig`.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Poskusi znova") {
                        Task {
                            await premiumManager.loadProducts(forceReload: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ForEach(premiumManager.products, id: \.id) { product in
                    Button {
                        Task {
                            await premiumManager.purchase(product)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.displayName)
                                        .font(.headline.weight(.semibold))
                                    Text(product.description)
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 8)
                                Text(product.displayPrice)
                                    .font(.title3.weight(.bold))
                            }

                            HStack(spacing: 6) {
                                Text("Kupi zdaj")
                                    .font(.subheadline.weight(.semibold))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.subheadline)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.95), Color.green.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(premiumManager.isPurchasing)
                }
            }
        }
    }

    private var restoreSection: some View {
        HStack {
            Button("Obnovi nakupe") {
                Task {
                    await premiumManager.restorePurchases()
                }
            }
            .buttonStyle(.bordered)
            .disabled(premiumManager.isPurchasing)

            Spacer()

            if premiumManager.isPurchasing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func featureRow(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(title)
                .font(.subheadline)
        }
    }
}

#Preview {
    PremiumPaywallView()
        .environmentObject(PremiumManager.preview(unlocked: false))
}
