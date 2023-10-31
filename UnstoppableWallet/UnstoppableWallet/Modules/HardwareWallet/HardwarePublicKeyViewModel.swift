import Foundation
import RxSwift
import RxRelay
import RxCocoa

class HardwarePublicKeyViewModel {
    private let service: HardwarePublicKeyService

    private let cautionRelay = BehaviorRelay<Caution?>(value: nil)

    init(service: HardwarePublicKeyService) {
        self.service = service
    }

}

extension HardwarePublicKeyViewModel {

    var cautionDriver: Driver<Caution?> {
        cautionRelay.asDriver()
    }

    func onChange(text: String) {
        service.set(text: text)
        cautionRelay.accept(nil)
    }

}

extension HardwarePublicKeyViewModel: IHardwareSubViewModel {

    var hardwareEnabled: Bool {
        service.state.hardwareEnabled
    }

    var hardwareEnabledObservable: Observable<Bool> {
        service.stateObservable.map { $0.hardwareEnabled }
    }

    var domainObservable: Observable<String?> {
        Observable.just(nil)
    }

    func resolve() -> AccountType? {
        cautionRelay.accept(nil)

        do {
            let accountType = try service.resolve()
            return accountType
        } catch {
            cautionRelay.accept(Caution(text: "hardware_address.public_key.invalid_key".localized, type: .error))
            return nil
        }
    }

}
