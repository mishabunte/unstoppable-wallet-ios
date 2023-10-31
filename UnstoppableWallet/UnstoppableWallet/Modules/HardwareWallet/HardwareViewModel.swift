import Foundation
import RxSwift
import RxRelay
import RxCocoa

protocol IHardwareSubViewModel: AnyObject {
    var hardwareEnabled: Bool { get }
    var hardwareEnabledObservable: Observable<Bool> { get }
    var domainObservable: Observable<String?> { get }
    func resolve() -> AccountType?
}

class HardwareViewModel {
    private let service: HardwareService
    private let tronService: HardwareTronService
    private let evmAddressViewModel: IHardwareSubViewModel
    private let tronAddressViewModel: IHardwareSubViewModel
    private let publicKeyViewModel: IHardwareSubViewModel
    private var disposeBag = DisposeBag()

    private let hardwareTypeRelay = BehaviorRelay<HardwareModule.HardwareType>(value: .evmAddressHardware)
    private let hardwareEnabledRelay = BehaviorRelay<Bool>(value: false)
    private let nameRelay = PublishRelay<String>()
    private let proceedRelay = PublishRelay<(HardwareModule.HardwareType, AccountType, String)>()

    init(service: HardwareService, tronService: HardwareTronService, evmAddressViewModel: IHardwareSubViewModel, tronAddressViewModel: IHardwareSubViewModel, publicKeyViewModel: IHardwareSubViewModel) {
        self.service = service
        self.tronService = tronService
        self.evmAddressViewModel = evmAddressViewModel
        self.tronAddressViewModel = tronAddressViewModel
        self.publicKeyViewModel = publicKeyViewModel
        
        syncSubViewModel()
    }

    private var subViewModel: IHardwareSubViewModel {
        switch hardwareTypeRelay.value {
        case .evmAddressHardware: return evmAddressViewModel
        case .tronAddressHardware: return tronAddressViewModel
        case .publicKeyHardware: return publicKeyViewModel
        }
    }

    private func syncSubViewModel() {
        disposeBag = DisposeBag()
        sync(hardwareEnabled: subViewModel.hardwareEnabled)
        subscribe(disposeBag, subViewModel.hardwareEnabledObservable) { [weak self] in self?.sync(hardwareEnabled: $0) }
        subscribe(disposeBag, subViewModel.domainObservable) { [weak self] in self?.sync(domain: $0) }
    }

    private func sync(hardwareEnabled: Bool) {
        hardwareEnabledRelay.accept(hardwareEnabled)
    }

    private func sync(domain: String?) {
        if let domain = domain, service.name == nil {
            service.set(name: domain)
            nameRelay.accept(domain)
        }
    }

}

extension HardwareViewModel {

    var hardwareTypeDriver: Driver<HardwareModule.HardwareType> {
        hardwareTypeRelay.asDriver()
    }

    var hardwareEnabledDriver: Driver<Bool> {
        hardwareEnabledRelay.asDriver()
    }

    var proceedSignal: Signal<(HardwareModule.HardwareType, AccountType, String)> {
        proceedRelay.asSignal()
    }

    var defaultName: String {
        service.defaultAccountName
    }

    var nameSignal: Signal<String> {
        nameRelay.asSignal()
    }

    var hasNextPage: Bool {
        hardwareTypeRelay.value == .tronAddressHardware
        //hardwareTypeRelay.value == hardwareType
    }

    func onChange(name: String) {
        service.set(name: name)
    }

    func onSelect(hardwareType: HardwareModule.HardwareType) {
        guard hardwareTypeRelay.value != hardwareType else {
            return
        }

        hardwareTypeRelay.accept(hardwareType)
        syncSubViewModel()
    }

    func onTapNext() {
        if let accountType = subViewModel.resolve() {
            let hardwareType = hardwareTypeRelay.value
            if hardwareType == .tronAddressHardware {
                tronService.enableHardware(accountType: accountType, accountName: service.resolvedName)
            }

            proceedRelay.accept((hardwareType, accountType, service.resolvedName))
        }
    }

}
