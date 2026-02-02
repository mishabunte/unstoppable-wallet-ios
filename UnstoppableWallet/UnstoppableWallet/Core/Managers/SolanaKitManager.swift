//
//  SolanaKitManager.swift
//  UnstoppableWallet
//
//  Created by arsenal on 06.10.25.
//  Copyright © 2025 Horizontal Systems. All rights reserved.
//
import Combine
import Foundation
import HdWalletKit
import MarketKit
import Base58Swift
import SolanaKit
import Solana
import TweetNacl

struct SplTokenInfo {
    let mint: String
    let account: String
    let name: String?
    let symbol: String?
    let decimals: UInt64
    let logoURI: String?
    let balance: String
    
    var tokenType: TokenType {
        .spl(address: mint)
    }
}

class SolanaKitManager {
    // MARK: - Dependencies
    private let restoreStateManager: RestoreStateManager
    private let marketKit: MarketKit.Kit
    private let walletManager: WalletManager
    
    // MARK: - Kit Instance Management
    private weak var _solanaKit: SolanaKit.Kit?
    private var currentAccount: Account?
    
    // MARK: - Concurrency
    private let queue = DispatchQueue(label: "\(AppConfig.label).solana-kit-manager", qos: .userInitiated)
    
    // MARK: - Subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var balanceCancellable: AnyCancellable?
    private var transactionsCancellable: AnyCancellable?
    
    init(restoreStateManager: RestoreStateManager, marketKit: MarketKit.Kit, walletManager: WalletManager) {
        self.restoreStateManager = restoreStateManager
        self.walletManager = walletManager
        self.marketKit = marketKit
    }
    
    private func _solanaKit(account: Account) throws -> SolanaKit.Kit {
        // Return existing kit if same account
        if let _solanaKit, let currentAccount, currentAccount == account {
            return _solanaKit
        }
        
        // Extract Solana address from account type
        let address: String
        
        switch account.type {
        case .mnemonic:
            // Derive Solana keypair from mnemonic
            let keypair = try Self.keypair(accountType: account.type)
            address = keypair.publicKey // base58 encoded
            
        case let .solanaAddress(_address):
            address = _address
            
        default:
            throw AdapterError.unsupportedAccount
        }
        
        guard let solscanKey = AppConfig.solscanApiKeys.first else { throw AdapterError.wrongParameters }
        
        // Create SolanaKit instance
        let solanaKit = try SolanaKit.Kit(
            network: .mainnet,
            account: address,
            solscanAPIKey: solscanKey
        )

        // Load balance and transaction data in background
        Task {
            try? await solanaKit.loadData()
        }

        _solanaKit = solanaKit
        currentAccount = account

        subscribe(solanaKit: solanaKit, account: account)

        return solanaKit
    }
    
    static func keypair(accountType: AccountType) throws -> (publicKey: String, privateKey: Data) {
        guard case let .mnemonic(words, _, _) = accountType else {
            throw AdapterError.unsupportedAccount
        }
        
        let hotAccount = HotAccount(phrase: words)
        guard let publicKey = hotAccount?.publicKey.base58EncodedString else { throw AdapterError.wrongParameters }
        guard let privateKey = hotAccount?.secretKey else { throw AdapterError.wrongParameters }
        
//        let hdWallet = HDWallet(seed: seed, coinType: 501, xPrivKey: 0, curve: .ed25519)
//        let privateKey = try hdWallet.privateKey(account: 0)
//        let privateRaw = Data(privateKey.raw.bytes)
//        
//        let keyPair = try TweetNacl.NaclSign.KeyPair.keyPair(fromSeed: privateRaw)
//        let publicKeyBase58 = Base58.base58Encode([UInt8](keyPair.publicKey))
        
        return (publicKey: publicKey, privateKey: privateKey)
    }
    
    private func getSplTokens(solanaKit: SolanaKit.Kit) -> [SplTokenInfo] {
        let tokens = solanaKit.splTokens
        let splTokens: [SplTokenInfo] = tokens.compactMap { token -> SplTokenInfo? in
            guard let tokenData = token.account.tokenData else { return nil }
            return SplTokenInfo(
                mint: tokenData.mint,
                account: token.pubkey,
                name: nil,
                symbol: nil,
                decimals: tokenData.decimals,
                logoURI: nil,
                balance: tokenData.tokenBalance
            )
        }

        return splTokens
    }
    
    private func subscribe(solanaKit: SolanaKit.Kit, account: Account) {
        let restoreState = restoreStateManager.restoreState(account: account, blockchainType: .solana)
        
        // Auto-enable SPL tokens on first restore or for watch accounts
        if restoreState.shouldRestore || account.watchAccount, !restoreState.initialRestored {
            balanceCancellable = solanaKit.$balance
                .compactMap { $0 }
                .sink { [weak self, restoreStateManager] balance in
                    // Fetch SPL token accounts from your SolanaKit
                    Task {
                        if let splTokens = self?.getSplTokens(solanaKit: solanaKit) {
                            self?.handle(splTokens: splTokens, account: account)
                        }
                        
                        restoreStateManager.setInitialRestored(account: account, blockchainType: .solana)
                        
                        self?.balanceCancellable?.cancel()
                        self?.balanceCancellable = nil
                    }
                }
        }
        
        // Subscribe to transaction updates for new token discovery
        transactionsCancellable = solanaKit.$transactions
            .sink { [weak self] transactions in
                self?.handleNewTransactions(transactions, account: account)
            }
    }
    
    private func handle(splTokens: [SplTokenInfo], account: Account) {
        guard !splTokens.isEmpty else { return }
        
        let existingWallets = walletManager.activeWallets
        let existingTokenTypeIds = existingWallets.map(\.token.type.id)
        let newTokens = splTokens.filter { !existingTokenTypeIds.contains($0.tokenType.id) }
        
        guard !newTokens.isEmpty else { return }
        
        let enabledWallets : [EnabledWallet] = newTokens.compactMap { token in
            EnabledWallet(
                tokenQueryId: TokenQuery(blockchainType: .solana, tokenType: .spl(address: token.mint)).id,
                accountId: account.id,
//                coinName: token.name ?? token.symbol,
//                coinCode: token.symbol,
//                coinImage: token.logoURI,
                tokenDecimals: Int(token.decimals)
            )
        }
        
        walletManager.save(enabledWallets: enabledWallets)
    }
    
    private func handleNewTransactions(_ transactions: [AccountTransfer], account: Account) {
        // Parse transactions for new SPL token addresses
        let newTokenAddresses = Set(transactions.map { $0.token_address })
            .filter { $0 != "So11111111111111111111111111111111111111112" } // Filter out native SOL
        
        // Fetch metadata and enable new tokens
        Task {
            // Implement similar to handle(splTokens:account:)
        }
    }
}

extension SolanaKitManager {
    func solanaKit(account: Account) throws -> SolanaKit.Kit {
        try queue.sync {
            try _solanaKit(account: account)
        }
    }
}

extension SolanaKitManager {
    enum KitWrapperError: Error {
        case mnemonicNoSeed
    }
}
