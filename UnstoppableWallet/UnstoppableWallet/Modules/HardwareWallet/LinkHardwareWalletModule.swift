import UIKit

enum LinkHardwareWalletModule {
    static func viewController(sourceViewController: UIViewController? = nil) -> UIViewController {
        let service = LinkHardwareWalletService(
            accountFactory: App.shared.accountFactory
        )
        let viewModel = LinkHardwareWalletViewModel(service: service)
        let viewController = LinkHardwareWalletViewController(viewModel: viewModel, sourceViewController: sourceViewController)

        return ThemeNavigationController(rootViewController: viewController)
    }
    
    static func viewController(sourceViewController: UIViewController? = nil, accountType: AccountType, name: String) -> UIViewController {
        let service = ChooseHardwareWalletService(
            accountType: accountType,
            accountName: name,
            accountFactory: App.shared.accountFactory,
            accountManager: App.shared.accountManager,
            walletManager: App.shared.walletManager,
            marketKit: App.shared.marketKit,
            evmBlockchainManager: App.shared.evmBlockchainManager
        )
        
        let viewModel = ChooseHardwareWalletViewModel(service: service)
        
        return ChooseHardwareWalletViewController(viewModel: viewModel, sourceViewController: sourceViewController)
    }

    static func link(accountType: AccountType, name: String) {
        let service = ChooseHardwareWalletService(
            accountType: accountType,
            accountName: name,
            accountFactory: App.shared.accountFactory,
            accountManager: App.shared.accountManager,
            walletManager: App.shared.walletManager,
            marketKit: App.shared.marketKit,
            evmBlockchainManager: App.shared.evmBlockchainManager
        )
        
        if case let .coins(tokens) = service.items, tokens.count <= 1 {
            service.link(enabledUids: tokens.map(\.tokenQuery.id))
        }
    }
}
