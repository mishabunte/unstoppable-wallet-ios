import UIKit
import ThemeKit
import MarketKit
import StorageKit
import RxCocoa

protocol ITitledCautionViewModel {
    var cautionDriver: Driver<TitledCaution?> { get }
}

class SendXModule {

    static func viewController(platformCoin: PlatformCoin, adapter: ISendBitcoinAdapter) -> UIViewController? {
        guard let feeRateProvider = App.shared.feeRateProviderFactory.provider(coinType: platformCoin.coinType) else {
            return nil
        }

        let switchService = AmountTypeSwitchService(localStorage: StorageKit.LocalStorage.default)
        let coinService = CoinService(platformCoin: platformCoin, currencyKit: App.shared.currencyKit, marketKit: App.shared.marketKit)
        let fiatService = FiatService(switchService: switchService, currencyKit: App.shared.currencyKit, marketKit: App.shared.marketKit)

        // Amount
        let amountInputService = SendXBitcoinAmountInputService(platformCoin: platformCoin)
        let amountCautionService = AmountCautionService(amountInputService: amountInputService)

        // Address
        let bitcoinParserItem = BitcoinAddressParserItem(adapter: adapter)
        let udnAddressParserItem = UDNAddressParserItem.item(rawAddressParserItem: bitcoinParserItem, coinCode: platformCoin.code, coinType: platformCoin.coinType)
        let addressParserChain = AddressParserChain()
                .append(handler: bitcoinParserItem)
                .append(handler: udnAddressParserItem)

        let addressUriParser = AddressParserFactory.parser(coinType: platformCoin.coinType)
        let addressService = AddressService(addressUriParser: addressUriParser, addressParserChain: addressParserChain)

        // Fee
        let feePriorityService = SendXFeePriorityService(provider: feeRateProvider)
        let feeRateService = SendXFeeRateService(priorityService: feePriorityService, provider: feeRateProvider)
        let feeFiatService = FiatService(switchService: switchService, currencyKit: App.shared.currencyKit, marketKit: App.shared.marketKit)
        let feeService = SendBitcoinFeeService(fiatService: feeFiatService, feePriorityService: feePriorityService, feeCoin: platformCoin)

        // TimeLock
        var timeLockService: SendXTimeLockService?
        var timeLockErrorService: SendXTimeLockErrorService?
        var timeLockViewModel: SendXTimeLockViewModel?

        if App.shared.localStorage.lockTimeEnabled, adapter.blockchain == .bitcoin {
            let timeLockService = SendXTimeLockService()
            let timeLockErrorService = SendXTimeLockErrorService(timeLockService: timeLockService, addressService: addressService, adapter: adapter)

            let timeLockViewModel = SendXTimeLockViewModel(service: timeLockService)
        }

        let bitcoinAdapterService = SendBitcoinAdapterService(
                feeRateService: feeRateService,
                amountInputService: amountInputService,
                addressService: addressService,
                timeLockService: timeLockService,
                btcBlockchainManager: App.shared.btcBlockchainManager,
                adapter: adapter
        )
        let service = SendBitcoinService(
                amountService: amountInputService,
                amountCautionService: amountCautionService,
                addressService: addressService,
                adapterService: bitcoinAdapterService,
                feeService: feeRateService,
                timeLockErrorService: timeLockErrorService,
                reachabilityManager: App.shared.reachabilityManager,
                platformCoin: platformCoin
        )

        //Add dependencies
        switchService.add(toggleAllowedObservable: fiatService.toggleAvailableObservable)

        amountInputService.availableBalanceService = bitcoinAdapterService
        amountCautionService.availableBalanceService = bitcoinAdapterService
        amountCautionService.sendAmountBoundsService = bitcoinAdapterService

        addressService.customErrorService = timeLockErrorService

        feeService.feeValueService = bitcoinAdapterService
        feePriorityService.feeRateService = feeRateService

        // ViewModels
        let viewModel = SendXViewModel(service: service)
        let availableBalanceViewModel = SendAvailableBalanceViewModel(service: bitcoinAdapterService, coinService: coinService, switchService: switchService)
        let amountInputViewModel = AmountInputViewModel(
                service: amountInputService,
                fiatService: fiatService,
                switchService: switchService,
                decimalParser: AmountDecimalParser()
        )
        let amountCautionViewModel = AmountCautionViewModel(
                service: amountCautionService,
                switchService: switchService,
                coinService: coinService
        )
        let recipientViewModel = RecipientAddressViewModel(service: addressService, handlerDelegate: nil)

        // Fee
        let feeViewModel = SendXFeeViewModel(service: feeService)
        let feeWarningViewModel = SendXFeeWarningViewModel(service: feeRateService)

        // Confirmation and Settings
        let customRangedFeeRateProvider = feeRateProvider as? ICustomRangedFeeRateProvider

        let sendFactory = SendBitcoinFactory(
                fiatService: fiatService,
                amountCautionService: amountCautionService,
                addressService: addressService,
                feeFiatService: feeFiatService,
                feeService: feeService,
                feeRateService: feeRateService,
                feePriorityService: feePriorityService,
                timeLockService: timeLockService,
                adapterService: bitcoinAdapterService,
                customFeeRateProvider: customRangedFeeRateProvider,
                logger: App.shared.logger,
                platformCoin: platformCoin
        )

        let viewController = SendBitcoinViewController(
                confirmationFactory: sendFactory,
                feeSettingsFactory: sendFactory,
                viewModel: viewModel,
                availableBalanceViewModel: availableBalanceViewModel,
                amountInputViewModel: amountInputViewModel,
                amountCautionViewModel: amountCautionViewModel,
                recipientViewModel: recipientViewModel,
                feeViewModel: feeViewModel,
                feeWarningViewModel: feeWarningViewModel,
                timeLockViewModel: timeLockViewModel
        )

        return ThemeNavigationController(rootViewController: viewController)
    }

    static func viewController(platformCoin: PlatformCoin, adapter: ISendBinanceAdapter) -> UIViewController? {
        let feeCoin = App.shared.feeCoinProvider.feeCoin(coinType: platformCoin.coinType) ?? platformCoin
        let feeCoinProtocol = App.shared.feeCoinProvider.feeCoinProtocol(coinType: platformCoin.coinType)

        let switchService = AmountTypeSwitchService(localStorage: StorageKit.LocalStorage.default)
        let coinService = CoinService(platformCoin: platformCoin, currencyKit: App.shared.currencyKit, marketKit: App.shared.marketKit)
        let fiatService = FiatService(switchService: switchService, currencyKit: App.shared.currencyKit, marketKit: App.shared.marketKit)

        // Amount
        let amountInputService = SendXBitcoinAmountInputService(platformCoin: platformCoin)
        let amountCautionService = AmountCautionService(amountInputService: amountInputService)

        // Address
        let bitcoinParserItem = BinanceAddressParserItem(adapter: adapter)
        let addressParserChain = AddressParserChain()
                .append(handler: bitcoinParserItem)

        let addressUriParser = AddressParserFactory.parser(coinType: platformCoin.coinType)
        let addressService = AddressService(addressUriParser: addressUriParser, addressParserChain: addressParserChain)

        let memoService = MemoInputService(maxSymbols: 120)

        // Fee
        let feeFiatService = FiatService(switchService: switchService, currencyKit: App.shared.currencyKit, marketKit: App.shared.marketKit)
        let feeService = SendFeeService(fiatService: feeFiatService, feeCoin: feeCoin)

        let service = SendBinanceService(
                amountService: amountInputService,
                amountCautionService: amountCautionService,
                addressService: addressService,
                memoService: memoService,
                adapter: adapter,
                reachabilityManager: App.shared.reachabilityManager,
                platformCoin: platformCoin
        )

        //Add dependencies
        switchService.add(toggleAllowedObservable: fiatService.toggleAvailableObservable)

        amountInputService.availableBalanceService = service
        amountCautionService.availableBalanceService = service

        feeService.feeValueService = service

        // ViewModels
        let viewModel = SendXViewModel(service: service)
        let availableBalanceViewModel = SendAvailableBalanceViewModel(service: service, coinService: coinService, switchService: switchService)
        let amountInputViewModel = AmountInputViewModel(
                service: amountInputService,
                fiatService: fiatService,
                switchService: switchService,
                decimalParser: AmountDecimalParser()
        )
        let amountCautionViewModel = AmountCautionViewModel(
                service: amountCautionService,
                switchService: switchService,
                coinService: coinService
        )
        let recipientViewModel = RecipientAddressViewModel(service: addressService, handlerDelegate: nil)
        let memoViewModel = MemoInputViewModel(service: memoService)

        // Fee
        let feeViewModel = SendXFeeViewModel(service: feeService)
        let feeWarningViewModel = SendXBinanceFeeWarningViewModel(adapter: adapter, coinCode: platformCoin.code, coinProtocol: feeCoinProtocol, feeCoin: feeCoin)

        // Confirmation and Settings
        let sendFactory = SendBinanceFactory(
                service: service,
                fiatService: fiatService,
                addressService: addressService,
                memoService: memoService,
                feeFiatService: feeFiatService,
                logger: App.shared.logger,
                platformCoin: platformCoin
        )

        let viewController = SendBinanceViewController(
                confirmationFactory: sendFactory,
                viewModel: viewModel,
                availableBalanceViewModel: availableBalanceViewModel,
                amountInputViewModel: amountInputViewModel,
                amountCautionViewModel: amountCautionViewModel,
                recipientViewModel: recipientViewModel,
                memoViewModel: memoViewModel,
                feeViewModel: feeViewModel,
                feeWarningViewModel: feeWarningViewModel
        )

        return ThemeNavigationController(rootViewController: viewController)
    }

}