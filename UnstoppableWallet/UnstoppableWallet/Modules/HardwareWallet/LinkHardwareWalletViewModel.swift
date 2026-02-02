import Combine
import Foundation
import HsExtensions

class LinkHardwareWalletViewModel {
    private let service: LinkHardwareWalletService
    private var cancellables = Set<AnyCancellable>()

    @PostPublished private(set) var linkEnabled: Bool = false
    @PostPublished private(set) var name: String
    @PostPublished private(set) var caution: Caution?
    @PostPublished private(set) var accountType: HardwareAccountType = .stellarAccount

    private let proceedSubject = PassthroughSubject<(AccountType, String), Never>()

    init(service: LinkHardwareWalletService) {
        self.service = service
        name = service.defaultAccountName

        service.$state
            .sink(receiveValue: { [weak self] in self?.sync(state: $0) })
            .store(in: &cancellables)

        sync(state: service.state)
    }

    private func sync(state: LinkHardwareWalletService.State) {
        switch state {
        case .ready:
            linkEnabled = true
            caution = nil
        case .notReady:
            linkEnabled = false
            caution = nil
        case let .error(error):
            linkEnabled = false
            caution = Caution(
                text: (error as? LocalizedError)?.errorDescription ?? "link_hardware_wallet.error.invalid_address".localized,
                type: .error
            )
        }
    }
}

extension LinkHardwareWalletViewModel {
    var defaultName: String {
        service.defaultAccountName
    }

    var proceedPublisher: AnyPublisher<(AccountType, String), Never> {
        proceedSubject.eraseToAnyPublisher()
    }

    func onChange(address: String) {
        service.set(address: address)
    }

    func onChange(name: String) {
        service.set(name: name)
    }

    func onSelectAccountType(accountType: HardwareAccountType) {
        self.accountType = accountType
        service.set(accountType: accountType.getAccountType())
    }

    func onTapLink() {
        if let accountType = service.resolve() {
            proceedSubject.send((accountType, service.resolvedName))
        }
    }
}

extension LinkHardwareWalletViewModel {
    enum HardwareAccountType: CaseIterable {
        case stellarAccount
        case solanaAccount

        var title: String {
            switch self {
            case .stellarAccount: return "Stellar Address"
            case .solanaAccount: return "Solana Address"
            }
        }

        var subtitle: String {
            switch self {
            case .stellarAccount: return "(XLM, Stellar tokens, ...)"
            case .solanaAccount: return "(SOL, Solana Tokens, ...)"
            }
        }

        func getAccountType() -> AccountType.Abstract {
            switch self {
            case .stellarAccount: return .stellarHardwareAccount
            case .solanaAccount: return .solanaHardware
            }
        }
    }
}
