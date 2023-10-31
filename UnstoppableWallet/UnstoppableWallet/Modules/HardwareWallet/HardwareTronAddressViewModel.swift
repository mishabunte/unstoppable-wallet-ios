import Foundation
import RxSwift
import RxRelay
import RxCocoa

class HardwareTronAddressViewModel {
    private let service: HardwareTronAddressService

    init(service: HardwareTronAddressService) {
        self.service = service
    }

}

extension HardwareTronAddressViewModel: IHardwareSubViewModel {

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
