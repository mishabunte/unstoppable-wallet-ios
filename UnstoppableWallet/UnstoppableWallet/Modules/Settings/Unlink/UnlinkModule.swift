import UIKit

struct UnlinkModule {

    static func viewController(account: Account) -> UIViewController {
        let service = UnlinkService(account: account, accountManager: App.shared.accountManager)
        let viewModel = UnlinkViewModel(service: service)
        let viewController : UIViewController = {
            if account.watchAccount {
                return UnlinkWatchViewController(viewModel: viewModel)
            } else if account.hardwareAccount {
                return UnlinkHardwareViewController(viewModel: viewModel)
            } else {
                return UnlinkViewController(viewModel: viewModel)
            }
        }()

        return viewController.toBottomSheet
    }

}
