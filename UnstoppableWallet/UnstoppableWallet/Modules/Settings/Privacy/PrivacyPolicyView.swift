import SwiftUI

struct PrivacyPolicyView: View {
    @StateObject var viewModel: PrivacyPolicyViewModel

    init(config: PrivacyPolicyViewModel.Config) {
        _viewModel = StateObject(wrappedValue: PrivacyPolicyViewModel(config: config))
    }

    var body: some View {
        ScrollableThemeView {
            VStack(spacing: .margin24) {
                HighlightedTextView(text: viewModel.config.description)

                VStack(spacing: 0) {
                    ListSection {
                        ListRow {
                            statsRow()
                        }
                    }
                    ListSectionFooter(text: "settings.privacy.allow.description".localized)
                }
            }
            .padding(EdgeInsets(top: .margin12, leading: .margin16, bottom: .margin32, trailing: .margin16))
        }
        .navigationTitle("settings.privacy".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func statsRow() -> some View {
        Toggle(isOn: Binding(get: { viewModel.statsEnabled }, set: { viewModel.set(allowed: $0) })) {
            HStack(spacing: .margin16) {
                Image("share_1_24").themeIcon(color: .themeGray)
                Text("settings.privacy.allow".localized).themeBody()
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .themeYellow))
    }
}
