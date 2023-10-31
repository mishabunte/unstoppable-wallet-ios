import MarketKit
import ThemeKit
import UIKit

struct HardwareModule {
    static func viewController(sourceViewController: UIViewController? = nil) -> UIViewController {
        let ethereumToken = try? App.shared.marketKit.token(query: TokenQuery(blockchainType: .ethereum, tokenType: .native))

        let evmAddressParserItem = EvmAddressParser()
        let udnAddressParserItem = UdnAddressParserItem.item(rawAddressParserItem: evmAddressParserItem, coinCode: "ETH", token: ethereumToken)
        let addressParserChain = AddressParserChain()
            .append(handler: evmAddressParserItem)
            .append(handler: udnAddressParserItem)

        if let httpSyncSource = App.shared.evmSyncSourceManager.httpSyncSource(blockchainType: .ethereum),
           let ensAddressParserItem = EnsAddressParserItem(rpcSource: httpSyncSource.rpcSource, rawAddressParserItem: evmAddressParserItem) {
            addressParserChain.append(handler: ensAddressParserItem)
        }

        let addressUriParser = AddressParserFactory.parser(blockchainType: .ethereum)
        let addressService = AddressService(mode: .parsers(addressUriParser, addressParserChain), marketKit: App.shared.marketKit, contactBookManager: nil, blockchainType: .ethereum)

        let evmAddressService = HardwareEvmAddressService(addressService: addressService)
        let evmAddressViewModel = HardwareEvmAddressViewModel(service: evmAddressService)

        let tronAddressParserChain = AddressParserChain().append(handler: TronAddressParser())
        let tronAddressService = AddressService(
            mode: .parsers(AddressParserFactory.parser(blockchainType: .tron), tronAddressParserChain),
            marketKit: App.shared.marketKit, contactBookManager: nil, blockchainType: .tron
        )
        let hardwareTronAddressService = HardwareTronAddressService(addressService: tronAddressService)
        let tronAddressViewModel = HardwareTronAddressViewModel(service: hardwareTronAddressService)

        let publicKeyService = HardwarePublicKeyService()
        let publicKeyViewModel = HardwarePublicKeyViewModel(service: publicKeyService)

        let service = HardwareService(accountFactory: App.shared.accountFactory)
        let tronService = HardwareTronService(accountFactory: App.shared.accountFactory, accountManager: App.shared.accountManager,
                                           walletManager: App.shared.walletManager, marketKit: App.shared.marketKit)
        let viewModel = HardwareViewModel(
            service: service,
            tronService: tronService,
            evmAddressViewModel: evmAddressViewModel,
            tronAddressViewModel: tronAddressViewModel,
            publicKeyViewModel: publicKeyViewModel
        )

        let evmRecipientAddressViewModel = RecipientAddressViewModel(service: addressService, handlerDelegate: nil)
        let tronRecipientAddressViewModel = RecipientAddressViewModel(service: tronAddressService, handlerDelegate: nil)

        let viewController = HardwareViewController(
            viewModel: viewModel,
            evmAddressViewModel: evmRecipientAddressViewModel,
            tronAddressViewModel: tronRecipientAddressViewModel,
            publicKeyViewModel: publicKeyViewModel,
            sourceViewController: sourceViewController
        )

        return ThemeNavigationController(rootViewController: viewController)
    }

    static func viewController(sourceViewController: UIViewController? = nil, hardwareType: HardwareType, accountType: AccountType, name: String) -> UIViewController? {
        let service: IChooseHardwareService

        switch hardwareType {
        case .evmAddressHardware:
            service = ChooseHardwareBlockchainService(
                accountType: accountType,
                accountName: name,
                accountFactory: App.shared.accountFactory,
                accountManager: App.shared.accountManager,
                walletManager: App.shared.walletManager,
                evmBlockchainManager: App.shared.evmBlockchainManager,
                marketKit: App.shared.marketKit
            )

        case .tronAddressHardware:
            return nil

        case .publicKeyHardware:
            service = ChooseHardwareCoinService(
                accountType: accountType,
                accountName: name,
                accountFactory: App.shared.accountFactory,
                accountManager: App.shared.accountManager,
                walletManager: App.shared.walletManager,
                marketKit: App.shared.marketKit
            )
        }

        let viewModel = ChooseHardwareViewModel(service: service, hardwareType: hardwareType)

        return ChooseHardwareViewController(viewModel: viewModel, sourceViewController: sourceViewController)
    }
}

extension HardwareModule {
    enum HardwareType: CaseIterable {
        case evmAddressHardware
        case tronAddressHardware
        case publicKeyHardware

        var title: String {
            switch self {
            case .evmAddressHardware: return "hardware_address.evm_address".localized
            case .tronAddressHardware: return "hardware_address.tron_address".localized
            case .publicKeyHardware: return "hardware_address.public_key".localized
            }
        }

        var subtitle: String {
            switch self {
            case .evmAddressHardware: return "(Ethereum, Binance, …)"
            case .tronAddressHardware: return "(TRX, Tron tokens, …)"
            case .publicKeyHardware: return "(Bitcoin, Litecoin, …)"
            }
        }
    }

    enum Item {
        case coin(token: Token)
        case blockchain(blockchain: Blockchain)
    }
}
