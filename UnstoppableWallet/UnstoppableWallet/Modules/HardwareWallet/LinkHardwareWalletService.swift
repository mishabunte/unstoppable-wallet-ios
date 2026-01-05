import Combine
import RxSwift
import Foundation
import HsExtensions

class LinkHardwareWalletService {
    private var disposeBag = DisposeBag()
    private let accountFactory: AccountFactory

    private(set) var name: String?
    @PostPublished private(set) var state = State.notReady

    private var address: String = ""
    private var accountType: AccountType.Abstract = .stellarHardwareAccount
    private var addressParserChain: AddressParserChain

    init(accountFactory: AccountFactory, addressParserChain: AddressParserChain) {
        self.accountFactory = accountFactory
        self.addressParserChain = addressParserChain
    }
    
    private func parseAddress() {
        disposeBag = DisposeBag()
        
        guard !address.isEmpty else {
            state = .notReady
            return
        }
        
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines).deletingPrefix(self.accountType.prefix())

        addressParserChain
            .handle(address: trimmedAddress)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .subscribe(
                onSuccess: { [weak self] in
                    guard let address = $0 else {
                        self?.state = .error(error: LinkError.nonPublicKey)
                        return
                    }
                    self?.validate(parsed: trimmedAddress)
                },
                onError: { [weak self] error in
                    self?.state = .error(error: error)
                    return
                }
            )
            .disposed(by: disposeBag)
    }

    private func validate(parsed: String) {
        do {
            let accountType: AccountType
            switch self.accountType {
            case .stellarHardwareAccount:
                accountType = .stellarHardwareAccount(accountId: parsed)
            default:
                state = .error(error: LinkError.unsupportedAccountType)
                return
            }
            state = .ready(accountType: accountType)
        }
    }
}

extension LinkHardwareWalletService {
    var defaultAccountName: String {
        accountFactory.nextAccountName
    }

    var resolvedName: String {
        let trimmedName = (name ?? defaultAccountName).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName
    }

    func set(name: String) {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.name = nil
        } else {
            self.name = name
        }
    }

    func set(address: String) {
        self.address = address
        parseAddress()
    }

    func set(accountType: AccountType.Abstract) {
        self.accountType = accountType
        parseAddress()
    }

    func resolve() -> AccountType? {
        switch state {
        case let .ready(accountType): return accountType
        default: return nil
        }
    }
}

extension LinkHardwareWalletService {
    enum State {
        case ready(accountType: AccountType)
        case notReady
        case error(error: Error)

        var linkEnabled: Bool {
            switch self {
            case .ready: return true
            case .notReady, .error: return false
            }
        }
    }

    enum LinkError: Error, LocalizedError {
        case emptyAddress
        case unsupportedAccountType
        case nonPublicKey

        var errorDescription: String? {
            switch self {
            case .emptyAddress: return "link_hardware_wallet.error.empty_address".localized
            case .unsupportedAccountType: return "link_hardware_wallet.error.unsupported_account_type".localized
            case .nonPublicKey: return "watch_address.error.non_public_key".localized
            }
        }
    }
}
