import Foundation
import MarketKit

class EvmAccountManagerFactory {
    private let accountManager: IAccountManager
    private let walletManager: WalletManager
    private let marketKit: MarketKit.Kit
    private let provider: HsTokenBalanceProvider
    private let storage: IEvmAccountSyncStateStorage

    init(accountManager: IAccountManager, walletManager: WalletManager, marketKit: MarketKit.Kit, provider: HsTokenBalanceProvider, storage: IEvmAccountSyncStateStorage) {
        self.accountManager = accountManager
        self.walletManager = walletManager
        self.marketKit = marketKit
        self.provider = provider
        self.storage = storage
    }

}

extension EvmAccountManagerFactory {

    func evmAccountManager(blockchain: EvmBlockchain, evmKitManager: EvmKitManager) -> EvmAccountManager {
        EvmAccountManager(
                blockchain: blockchain,
                accountManager: accountManager,
                walletManager: walletManager,
                marketKit: marketKit,
                evmKitManager: evmKitManager,
                provider: provider,
                storage: storage
        )
    }

}