//
//  ChooseHardwareWalletService.swift
//  UnstoppableWallet
//
//  Created by arsenal on 29.12.25.
//  Copyright © 2025 Horizontal Systems. All rights reserved.
//

import MarketKit

class ChooseHardwareWalletService {
    private let accountType: AccountType
    private let accountName: String
    private let accountFactory: AccountFactory
    private let accountManager: AccountManager
    private let walletManager: WalletManager
    private let marketKit: MarketKit.Kit
    private let evmBlockchainManager: EvmBlockchainManager

    private(set) var items: WatchModule.Items = .blockchains(blockchains: [])

    init(accountType: AccountType, accountName: String, accountFactory: AccountFactory, accountManager: AccountManager, walletManager: WalletManager, marketKit: MarketKit.Kit, evmBlockchainManager: EvmBlockchainManager) {
        self.accountType = accountType
        self.accountName = accountName
        self.accountFactory = accountFactory
        self.accountManager = accountManager
        self.walletManager = walletManager
        self.marketKit = marketKit
        self.evmBlockchainManager = evmBlockchainManager

        items = walletItems() ?? .coins(tokens: [])
    }

    private func walletItems() -> WatchModule.Items? {
        let tokenQueries: [TokenQuery]

        switch accountType {
        case .solanaAddress:
            tokenQueries = BlockchainType.solana.nativeTokenQueries
        case .mnemonic, .evmPrivateKey, .stellarSecretKey:
            return nil

        case .evmAddress:
            let blockchains = evmBlockchainManager.allBlockchains
                .sorted(by: { $0.type.order < $1.type.order })

            return .blockchains(blockchains: blockchains)

        case .tronAddress:
            tokenQueries = BlockchainType.tron.nativeTokenQueries

        case .tonAddress:
            tokenQueries = BlockchainType.ton.nativeTokenQueries

        case .stellarAccount:
            tokenQueries = BlockchainType.stellar.nativeTokenQueries
        case .stellarHardwareAccount:
            tokenQueries = BlockchainType.stellar.nativeTokenQueries

        case let .hdExtendedKey(key):
            guard case .public = key else {
                return nil
            }

            tokenQueries = BtcBlockchainManager.blockchainTypes.map(\.nativeTokenQueries).flatMap { $0 }

        case let .btcAddress(_, blockchainType, tokenType):
            tokenQueries = [TokenQuery(blockchainType: blockchainType, tokenType: tokenType)]
        }

        guard let tokens = try? marketKit.tokens(queries: tokenQueries) else {
            return nil
        }

        return .coins(tokens: tokens.filter { accountType.supports(token: $0) })
    }

    private func enableWallets(account: Account, enabledUids: [String]) {
        var wallets = [Wallet]()

        switch items {
        case let .coins(tokens):
            for token in tokens {
                if enabledUids.contains(token.tokenQuery.id) {
                    wallets.append(Wallet(token: token, account: account))
                }
            }

        case let .blockchains(blockchains):
            var tokenQueries = [TokenQuery]()
            for blockchain in blockchains {
                if enabledUids.contains(blockchain.uid) {
                    tokenQueries.append(blockchain.type.defaultTokenQuery)
                }
            }

            do {
                let blockchainNativeTokenWallets = try marketKit.tokens(queries: tokenQueries).map { token in
                    Wallet(token: token, account: account)
                }
                wallets.append(contentsOf: blockchainNativeTokenWallets)
            } catch {}
        }

        walletManager.save(wallets: wallets)
    }
}

extension ChooseHardwareWalletService {
    func link(enabledUids: [String]) {
        let account = accountFactory.hardwareWallet(type: accountType, name: accountName)

        accountManager.save(account: account)
//        accountManager.set(lastCreatedAccount: account)
        enableWallets(account: account, enabledUids: enabledUids)

        stat(page: .linkHardwareWallet, event: .linkWallet(walletType: accountType.statDescription))
    }
}
