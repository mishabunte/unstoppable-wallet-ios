
import BigInt
import Combine
import Foundation
import RxSwift
import SolanaKit
import MarketKit

class SplTokenAdapter {
    private let solanaKit: SolanaKit.Kit
    private let tokenAddress: String  // The SPL token mint address
    private var cancellables = Set<AnyCancellable>()
    
    private let balanceStateSubject = PublishSubject<AdapterState>()
    private(set) var balanceState: AdapterState
    
    private let tokenBalanceSubject = PublishSubject<TokenAccountInfo?>()
    private(set) var tokenInfo: TokenAccountInfo?
    
    init(solanaKit: SolanaKit.Kit, tokenAddress: String) {
        self.solanaKit = solanaKit
        self.tokenAddress = tokenAddress
        
        // Find the token info from splTokens array
        tokenInfo = solanaKit.splTokens.first {
            $0.account.tokenData?.mint == tokenAddress
        }
        
        balanceState = Self.adapterState(kitSyncState: solanaKit.syncState)
        
        // Subscribe to balance updates
        solanaKit.$splTokens
            .sink { [weak self] in self?.handle(splTokens: $0) }
            .store(in: &cancellables)
        
        solanaKit.$syncState
            .sink { [weak self] in
                self?.balanceState = Self.adapterState(kitSyncState: $0)
            }
            .store(in: &cancellables)
    }
    
    private func handle(splTokens: [TokenAccountInfo]?) {
        tokenInfo = splTokens?.first {
            $0.account.tokenData?.mint == tokenAddress
        }
        tokenBalanceSubject.onNext(tokenInfo)
    }
    
    private static func adapterState(kitSyncState: SyncState) -> AdapterState {
        switch kitSyncState {
        case .syncing: return .syncing(progress: nil, lastBlockDate: nil)
        case .synced: return .synced
        case let .notSynced(error): return .notSynced(error: error)
        }
    }
    
    private static func amount(tokenInfo: TokenAccountInfo?) -> Decimal {
        guard let tokenInfo,
              let tokenData = tokenInfo.account.tokenData,
              let significand = Decimal(string: tokenData.tokenBalance) else {
            return 0
        }
        
        return Decimal(
            sign: .plus,
            exponent: -Int(tokenData.decimals),
            significand: significand
        )
    }
    
    private func sendAmount(
        amount: SendAmount,
        decimals: Int,
        balance: String
    ) throws -> UInt64 {
        switch amount {
        case .amount(let value):
            let rawAmount = value * pow(10, decimals)
            let result = UInt64(truncating: rawAmount as NSNumber)
            return result
            
        case .max:
            guard let result = UInt64(balance) else {
                throw SendError.invalidAmount
            }
            return result
        }
    }
}

extension SplTokenAdapter: IBaseAdapter {
    var isMainNet: Bool {
        true  // Can check network if needed
    }
}

extension SplTokenAdapter: IAdapter {
    func start() {
        // Started via SolanaKitManager
    }
    
    func stop() {
        // Stopped via SolanaKitManager
    }
    
    func refresh() {
        // Refreshed via SolanaKitManager
    }
    
    var statusInfo: [(String, Any)] {
        []
    }
    
    var debugInfo: String {
        ""
    }
}

extension SplTokenAdapter: IBalanceAdapter {
    var balanceStateUpdatedObservable: Observable<AdapterState> {
        balanceStateSubject.asObservable()
    }
    
    var balanceData: BalanceData {
        BalanceData(available: Self.amount(tokenInfo: tokenInfo))
    }
    
    var balanceDataUpdatedObservable: Observable<BalanceData> {
        tokenBalanceSubject.map {
            BalanceData(available: Self.amount(tokenInfo: $0))
        }
    }
}

extension SplTokenAdapter: IDepositAdapter {
    var receiveAddress: DepositAddress {
        // SPL tokens use the same address as native SOL
        DepositAddress(solanaKit.currentAccount ?? "")
    }
}

protocol ISendSplTokenAdapter {
    func transferData(
        recipient: String,
        amount: SplTokenAdapter.SendAmount
    ) async throws -> Data
}

extension SplTokenAdapter: ISendSplTokenAdapter {
    enum SendAmount {
        case amount(value: Decimal)
        case max
    }
    
    enum SendError: Error {
        case noTokenAccount
        case invalidAmount
    }
    
    func transferData(
        recipient: String,
        amount: SendAmount
    ) async throws -> Data {
        guard let tokenInfo = tokenInfo,
              let tokenData = tokenInfo.account.tokenData else {
            throw SendError.noTokenAccount
        }
        
        let rawAmount = try sendAmount(
            amount: amount,
            decimals: Int(tokenData.decimals),
            balance: tokenData.tokenBalance
        )
        
        // Build SPL token transfer transaction
        return try await solanaKit.getUnsignedSplTransaction(
            mintAddress: tokenAddress,
            from: solanaKit.currentAccount ?? "",
            destinationAddress: recipient,
            amount: rawAmount
        )
    }
}
