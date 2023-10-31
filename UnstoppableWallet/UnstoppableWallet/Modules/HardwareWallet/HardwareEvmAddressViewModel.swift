import Foundation
import RxSwift
import RxRelay
import RxCocoa

class HardwareEvmAddressViewModel {
    private let service: HardwareEvmAddressService

    init(service: HardwareEvmAddressService) {
        self.service = service
    }

}

extension HardwareEvmAddressViewModel: IHardwareSubViewModel {

    var hardwareEnabled: Bool {
        service.state.hardwareEnabled
    }
    
    var hardwareEnabledObservable: Observable<Bool> {
        service.stateObservable.map { $0.hardwareEnabled }
    }

    var domainObservable: Observable<String?> {
        service.stateObservable.map { $0.domain }
    }

    func resolve() -> AccountType? {
        service.resolve()
    }

}
