import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "Foreground sync",
            title: "Your notes,",
            emphasis: "in motion.",
            body: "Vault Sync runs a focused Syncthing session while the app is open. It is a manual, verified sync - not invisible background magic. Start it, watch it finish, then return to Obsidian.",
            symbol: "arrow.triangle.2.circlepath",
            tint: VaultPalette.teal
        ),
        OnboardingPage(
            eyebrow: "Step one",
            title: "Choose the",
            emphasis: "real vault.",
            body: "Use the Files picker to grant access to your actual vault - usually On My iPad, then Obsidian, then your vault folder. The permission is saved securely and reused next time.",
            symbol: "folder.fill.badge.questionmark",
            tint: VaultPalette.orange
        ),
        OnboardingPage(
            eyebrow: "Step two",
            title: "Pair",
            emphasis: "directly.",
            body: "Add this iPad's device ID to Syncthing on your computer and share the existing vault folder with it. Then enter or scan the computer's device ID and the exact Syncthing folder ID here.",
            symbol: "qrcode.viewfinder",
            tint: VaultPalette.lilac
        ),
        OnboardingPage(
            eyebrow: "Step three",
            title: "Sync and",
            emphasis: "verify.",
            body: "Keep the app open until it reports a verified, up-to-date result on both sides. If competing edits exist, Syncthing keeps conflict copies for you to review in Recovery.",
            symbol: "checkmark.seal.fill",
            tint: VaultPalette.teal
        ),
    ]

    var body: some View {
        ZStack {
            VaultPalette.parchment.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index]).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                controls
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? VaultPalette.ink : VaultPalette.ink.opacity(0.16))
                    .frame(height: 5)
                    .animation(.easeOut(duration: 0.25), value: page)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .accessibilityHidden(true)
    }

    private func pageView(_ p: OnboardingPage) -> some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(p.tint.opacity(0.22)).frame(width: 150, height: 150)
                Image(systemName: p.symbol)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(VaultPalette.ink)
            }
            .accessibilityHidden(true)
            VStack(spacing: 10) {
                Text(p.eyebrow)
                    .font(VaultType.body(.caption, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(VaultPalette.muted)
                HStack(spacing: 7) {
                    Text(p.title).font(VaultType.display(size: 38, weight: .regular))
                    Text(p.emphasis).font(VaultType.display(size: 38, weight: .black))
                        .foregroundStyle(p.tint == VaultPalette.lilac ? VaultPalette.ink : p.tint)
                }
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                Text(p.body)
                    .font(VaultType.body(.body))
                    .foregroundStyle(VaultPalette.ink.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if page > 0 {
                    VaultPillButton(title: "Back", systemImage: "chevron.left",
                                    style: .outline) {
                        withAnimation { page -= 1 }
                    }
                    .frame(maxWidth: .infinity)
                }
                VaultPillButton(
                    title: page == pages.count - 1 ? "Get started" : "Next",
                    systemImage: page == pages.count - 1 ? "checkmark" : "chevron.right",
                    style: page == pages.count - 1 ? .teal : .primary
                ) {
                    if page == pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation { page += 1 }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Button("Skip for now") { onFinish() }
                .font(.footnote.weight(.medium))
                .foregroundStyle(VaultPalette.muted)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 26)
    }
}

private struct OnboardingPage {
    let eyebrow: String
    let title: String
    let emphasis: String
    let body: String
    let symbol: String
    let tint: Color
}
