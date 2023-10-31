import TronKit
import MarketKit

class HardwareTronService {
    private let accountFactory: AccountFactory
    private let accountManager: AccountManager
    private let walletManager: WalletManager
    private let marketKit: MarketKit.Kit

    init(accountFactory: AccountFactory, accountManager: AccountManager, walletManager: WalletManager, marketKit: MarketKit.Kit) {
        self.accountFactory = accountFactory
        self.accountManager = accountManager
        self.walletManager = walletManager
        self.marketKit = marketKit
    }

}

extension HardwareTronService {

    func enableHardware(accountType: AccountType, accountName: String) {
        let account = accountFactory.hardwareAccount(type: accountType, name: accountName)
        accountManager.save(account: account)

        let tokenQuery = TokenQuery(blockchainType: .tron, tokenType: .native)

        guard let token = try? marketKit.tokens(queries: [tokenQuery]).first else {
            return
        }

        walletManager.save(wallets: [Wallet(token: token, account: account)])
    }

}
