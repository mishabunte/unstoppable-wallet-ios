import Foundation
import MarketKit
import RxSwift
import RxRelay
import RxCocoa

protocol IChooseHardwareService {
    var items: [HardwareModule.Item] { get }
    func hardware(enabledUids: [String])
}

class ChooseHardwareViewModel {
    private var disposeBag = DisposeBag()
    private let service: IChooseHardwareService
    private let hardwareRelay = PublishRelay<Void>()
    private let hardwareEnabledRelay = BehaviorRelay<Bool>(value: false)

    private var enabledBlockchainUids = [String]()
    private let viewItems: [CoinToggleViewModel.ViewItem]
    private let hardwareType: HardwareModule.HardwareType

    init(service: IChooseHardwareService, hardwareType: HardwareModule.HardwareType) {
        self.service = service
        self.hardwareType = hardwareType

        viewItems = service.items.map { item in
            switch item {
            case let .coin(token):
                return CoinToggleViewModel.ViewItem(
                    uid: token.type.id,
                    imageUrl: token.coin.imageUrl,
                    placeholderImageName: "placeholder_circle_32",
                    title: token.coin.code,
                    subtitle: token.coin.name,
                    badge: token.badge,
                    state: .toggleVisible(enabled: false, hasSettings: false, hasInfo: false)
                )

            case let .blockchain(blockchain):
                return CoinToggleViewModel.ViewItem(
                    uid: blockchain.uid,
                    imageUrl: blockchain.type.imageUrl,
                    placeholderImageName: blockchain.type.placeholderImageName(tokenProtocol: .native),
                    title: blockchain.name,
                    subtitle: blockchain.type.description,
                    badge: nil,
                    state: .toggleVisible(enabled: blockchain.uid == "ethereum", hasSettings: false, hasInfo: false)
                )
            }
        }
    }

}

extension ChooseHardwareViewModel {

    var title: String {
        switch hardwareType {
        case .evmAddressHardware: return "hardware_address.choose_blockchain".localized
        case .publicKeyHardware: return "hardware_address.choose_coin".localized
        case .tronAddressHardware: return ""
        }
    }

    var hardwareSignal: Signal<Void> {
        hardwareRelay.asSignal()
    }

    var hardwareEnabledDriver: Driver<Bool> {
        hardwareEnabledRelay.asDriver()
    }

    func onTapHardware() {
        service.hardware(enabledUids: enabledBlockchainUids)
        hardwareRelay.accept(())
    }

}

extension ChooseHardwareViewModel: ICoinToggleViewModel {

    var viewItemsDriver: Driver<[CoinToggleViewModel.ViewItem]> {
        Driver.just(viewItems)
    }

    func onEnable(uid: String) {
        if enabledBlockchainUids.isEmpty {
            hardwareEnabledRelay.accept(true)
        }

        enabledBlockchainUids.append(uid)
    }

    func onDisable(uid: String) {
        if let index = enabledBlockchainUids.firstIndex(of: uid) {
            enabledBlockchainUids.remove(at: index)

            if enabledBlockchainUids.isEmpty {
                hardwareEnabledRelay.accept(false)
            }
        }
    }

    func onTapSettings(uid: String) { }
    func onTapInfo(uid: String) { }
    func onUpdate(filter: String) {}

}
