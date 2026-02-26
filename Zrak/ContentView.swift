import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var premiumManager: PremiumManager

    var body: some View {
        MapScreen()
            .sheet(isPresented: $premiumManager.isPaywallPresented) {
                PremiumPaywallView()
                    .environmentObject(premiumManager)
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(PremiumManager.preview(unlocked: false))
}
