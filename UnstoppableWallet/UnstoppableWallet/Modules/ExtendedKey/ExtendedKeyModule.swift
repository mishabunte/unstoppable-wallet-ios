
import UIKit

enum ExtendedKeyModule {
    static func viewController(mode: Mode, accountType: AccountType) -> UIViewController {
        let service = ExtendedKeyService(mode: mode, accountType: accountType)
        let viewModel = ExtendedKeyViewModel(service: service)
        return ExtendedKeyViewController(viewModel: viewModel)
    }
}

extension ExtendedKeyModule {
    enum Mode {
        case bip32RootKey
        case accountExtendedPrivateKey
        case accountExtendedPublicKey
    }
}
