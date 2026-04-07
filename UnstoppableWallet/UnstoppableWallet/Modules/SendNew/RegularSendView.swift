
import MarketKit
import SwiftUI

struct RegularSendView: View {
    @StateObject var sendViewModel: SendViewModel
    @State var showQR = false
    
    private let onSuccess: () -> Void
    public let isHardware: Bool
    
    init(sendData: SendData, address: String? = nil, isHardware: Bool = false, onSuccess: @escaping () -> Void) {
        self.isHardware = isHardware
        _sendViewModel = .init(wrappedValue: SendViewModel(sendData: sendData, address: address, isHardware: isHardware))
        self.onSuccess = onSuccess
    }
    
    private func launchQr() {
        self.showQR = true
    }
    
    private func onScanQr(text: String) {
//        self.showQR = false
        self.sendViewModel.onScanQr(text: text)
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
                    } else if sendViewModel.needsSigning {
                        Button(action: {
                            sendViewModel.startNfc()
                        }) {
                            Text("send.next_button".localized)
                        }
                        .buttonStyle(PrimaryButtonStyle(style: .gray))
                    } else if sendViewModel.needsScanning {
                        HStack {
                            Button(action: {
                                sendViewModel.startNfc()
                            }) {
                                Text("Retry")
                            }
                            .buttonStyle(PrimaryButtonStyle(style: .gray))
                            Button(action: {
                                self.launchQr()
                            }) {
                                HStack {
                                    Text("Scan")
                                    Image("qr_scan_20")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(style: .yellow))
                        }
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
        .sheet(isPresented: $showQR) {
            ScanQrViewControllerWrapper(didFetch: {
                self.onScanQr(text: $0)
            })
        }

    }
}

struct ScanQrViewControllerWrapper: UIViewControllerRepresentable {

    var didFetch: ((String) -> Void)?
    
    func makeUIViewController(context: Context) -> ScanQrViewController {
        let scanQrViewController = ScanQrViewController()
        
        scanQrViewController.didFetch = self.didFetch
        return scanQrViewController
    }

    func updateUIViewController(_ uiViewController: ScanQrViewController, context: Context) {

    }
}
