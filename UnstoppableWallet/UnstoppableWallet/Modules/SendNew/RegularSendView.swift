
import MarketKit
import SwiftUI

struct RegularSendView: View {
    @StateObject var sendViewModel: SendViewModel

    private let onSuccess: () -> Void
    public let isHardware: Bool

    init(sendData: SendData, address: String? = nil, isHardware: Bool = false, onSuccess: @escaping () -> Void) {
        self.isHardware = isHardware
        _sendViewModel = .init(wrappedValue: SendViewModel(sendData: sendData, address: address, isHardware: isHardware))
        self.onSuccess = onSuccess
    }

    var body: some View {
        ThemeView {
            BottomGradientWrapper {
                SendView(viewModel: sendViewModel)
            } bottomContent: {
                switch sendViewModel.state {
                case .syncing:
                    EmptyView()
                case let .success(data):
                    if sendViewModel.canSend, sendViewModel.handler?.expirationDuration == nil || sendViewModel.timeLeft > 0 || sendViewModel.sending {
                        SlideButton(
                            styling: .text(start: data.customSendButtonTitle ?? "send.confirmation.slide_to_send".localized, end: "", success: ""),
                            action: {
                                try await sendViewModel.send()
                            }, completion: {
                                onSuccess()
                            }
                        )
                    } else if sendViewModel.needsSignature {
                        Button(action: {
                             
                        }) {
                            Text("send.next_button".localized)
                        }
                        .buttonStyle(PrimaryButtonStyle(style: .gray))
                    } else {
                        Button(action: {
                            sendViewModel.sync()
                        }) {
                            Text("send.confirmation.refresh".localized)
                        }
                        .buttonStyle(PrimaryButtonStyle(style: .gray))
                    }
                case .failed:
                    Button(action: {
                        sendViewModel.sync()
                    }) {
                        Text("send.confirmation.refresh".localized)
                    }
                    .buttonStyle(PrimaryButtonStyle(style: .gray))
                }
            }
        }
        .navigationTitle("send.confirmation.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
