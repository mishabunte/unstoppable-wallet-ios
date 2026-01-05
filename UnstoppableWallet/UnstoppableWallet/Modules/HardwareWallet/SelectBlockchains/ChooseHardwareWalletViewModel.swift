import Foundation
import MarketKit
import RxCocoa
import RxRelay
import RxSwift

class ChooseHardwareWalletViewModel {
    private var disposeBag = DisposeBag()
    private let service: ChooseHardwareWalletService
    private let linkRelay = PublishRelay<Void>()
    private let linkEnabledRelay = BehaviorRelay<Bool>(value: false)

    private var enabledUids = [String]()
    private let viewItems: [CoinToggleViewModel.ViewItem]

    init(service: ChooseHardwareWalletService) {
        self.service = service

        switch service.items {
        case let .coins(tokens):
            viewItems = tokens.map { token in
                CoinToggleViewModel.ViewItem(
                    uid: token.tokenQuery.id,
                    imageUrl: token.coin.imageUrl,
                    placeholderImageName: "placeholder_circle_32",
                    title: token.coin.code,
                    subtitle: token.coin.name,
                    badge: token.badge,
                    state: .toggleVisible(enabled: false, hasSettings: false, hasInfo: false)
                )
            }
        case let .blockchains(blockchains):
            viewItems = blockchains.map { blockchain in
                CoinToggleViewModel.ViewItem(
                    uid: blockchain.uid,
                    imageUrl: blockchain.type.imageUrl,
                    placeholderImageName: blockchain.type.placeholderImageName(tokenProtocol: .native),
                    title: blockchain.name,
                    subtitle: blockchain.type.description,
                    badge: nil,
                    state: .toggleVisible(enabled: false, hasSettings: false, hasInfo: false)
                )
            }
        }
    }
}

extension ChooseHardwareWalletViewModel {
    var title: String {
        switch service.items {
        case .blockchains: return "watch_address.choose_blockchain".localized
        case .coins: return "watch_address.choose_coin".localized
        }
    }

    var linkSignal: Signal<Void> {
        linkRelay.asSignal()
    }

    var linkEnabledDriver: Driver<Bool> {
        linkEnabledRelay.asDriver()
    }

    func onTapLink() {
        service.link(enabledUids: enabledUids)
        linkRelay.accept(())
    }
}

extension ChooseHardwareWalletViewModel: ICoinToggleViewModel {
    var viewItemsDriver: Driver<[CoinToggleViewModel.ViewItem]> {
        Driver.just(viewItems)
    }

    func onEnable(uid: String) {
        if enabledUids.isEmpty {
            linkEnabledRelay.accept(true)
        }

        enabledUids.append(uid)
    }

    func onDisable(uid: String) {
        if let index = enabledUids.firstIndex(of: uid) {
            enabledUids.remove(at: index)

            if enabledUids.isEmpty {
                linkEnabledRelay.accept(false)
            }
        }
    }

    func onTapSettings(uid _: String) {}
    func onTapInfo(uid _: String) {}
    func onUpdate(filter _: String) {}
}
