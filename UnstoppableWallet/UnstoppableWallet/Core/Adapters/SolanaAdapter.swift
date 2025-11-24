
import BigInt
import Combine
import Foundation
import RxSwift
import SolanaKit
import MarketKit

class SolanaAdapter {
    private static let decimals = 9
    
    private let solanaKit: SolanaKit.Kit
    private var cancellables = Set<AnyCancellable>()
    
    private let balanceStateSubject = PublishSubject<AdapterState>()
    private let balanceDataSubject = PublishSubject<BalanceData>()
    private let transactionRecordsSubject = PublishSubject<[SolanaTransactionRecord]>()
    
    private let lastBlockUpdatedSubject = PublishSubject<Void>()
    
    let transactionSource: TransactionSource
    let token: Token
    
    private(set) var balanceState: AdapterState {
        didSet {
            balanceStateSubject.onNext(balanceState)
        }
    }
    
    private(set) var balanceData: BalanceData {
        didSet {
            balanceDataSubject.onNext(balanceData)
        }
    }
    
    private static func adapterState(kitSyncState: SolanaKit.SyncState) -> AdapterState {
        switch kitSyncState {
        case .syncing: return .syncing(progress: nil, lastBlockDate: nil)
        case .synced: return .synced
        case let .notSynced(error): return .notSynced(error: error)
        }
    }
    
    static func amount(lamports: UInt64?) -> Decimal {
        guard let lamports else { return 0 }
        return Decimal(sign: .plus, exponent: -self.decimals, significand: Decimal(lamports))
    }
    
    static func lamports(amount: Decimal) -> UInt64? {
        let lamportsDecimal = amount * pow(10, Self.decimals)
        return UInt64(truncating: lamportsDecimal as NSNumber)
    }
    
    init(solanaKit: SolanaKit.Kit, wallet: Wallet) {
        self.solanaKit = solanaKit
        
        balanceState = Self.adapterState(kitSyncState: solanaKit.syncState)
        balanceData = BalanceData(available: Self.amount(lamports: solanaKit.balance?.lamports))
        transactionSource = wallet.transactionSource
        token = wallet.token
        
        solanaKit.$balance
            .compactMap { $0 }
            .sink { [weak self] balance in
                self?.balanceData = BalanceData(
                    available: Self.amount(lamports: balance.lamports)
                )
            }
            .store(in: &cancellables)
        
        solanaKit.$syncState
            .sink { [weak self] status in
                self?.balanceState = Self.adapterState(kitSyncState: status)
            }
            .store(in: &cancellables)
        
        solanaKit.$transactions
            .sink { [weak self] transactions in
                self?.handleTransactionUpdates(transactions)
            }
            .store(in: &cancellables)
    }
}

extension SolanaAdapter: IBaseAdapter {
    var isMainNet: Bool {
        return true
    }
}

extension SolanaAdapter: IAdapter {
    func start() {
        // Started via SolanaKitManager
    }
    
    func stop() {
        // Stopped via SolanaKitManager
    }
    
    func refresh() {
        Task {
            print("refreshing data for solanakit")
            defer {print("new balance for solana: \(String(solanaKit.balance?.lamports ?? 180000))")}
            try? await solanaKit.loadData()
        }
        
        balanceState = Self.adapterState(kitSyncState: solanaKit.syncState)
        balanceData = BalanceData(available: Self.amount(lamports: solanaKit.balance?.lamports))
    }
    
    var statusInfo: [(String, Any)] {
        [
            ("Connection Status", "\(solanaKit.connectionStatus)"),
            ("Current Account", solanaKit.currentAccount ?? "N/A"),
            ("Last Sync", solanaKit.lastSyncTime.map { Date(timeIntervalSince1970: $0) } ?? "Never"),
        ]
    }
    
    var debugInfo: String {
        ""
    }
}

extension SolanaAdapter: IBalanceAdapter {
    var balanceStateUpdatedObservable: Observable<AdapterState> {
        balanceStateSubject.asObservable()
    }
    
    var balanceDataUpdatedObservable: Observable<BalanceData> {
        balanceDataSubject.asObservable()
    }
}

extension SolanaAdapter: IDepositAdapter {
    var receiveAddress: DepositAddress {
        DepositAddress(solanaKit.currentAccount ?? "")
    }
}

protocol ISendSolanaAdapter {
    func transferData(
        recipient: String,
        amount: SolanaAdapter.SendAmount
    ) async throws -> Data
}

extension SolanaAdapter: ISendSolanaAdapter {
    enum SendAmount {
        case amount(value: Decimal)
        case max
    }
    
    enum SendError: Error {
        case invalidAmount
        case noAccount
        case insufficientBalance
    }
    
    func transferData(
        recipient: String,
        amount: SendAmount
    ) async throws -> Data {
        let lamports = try sendAmount(amount: amount)
        
        guard let account = solanaKit.currentAccount else {
            throw SendError.noAccount
        }
        
        return try await solanaKit.getUnsignedSolTransaction(
            from: account,
            to: recipient,
            lamports: lamports
        )
    }
    
    private func sendAmount(amount: SendAmount) throws -> UInt64 {
        switch amount {
        case .amount(let value):
            guard let lamports = Self.lamports(amount: value) else {
                throw SendError.invalidAmount
            }
            return lamports
            
        case .max:
            // Calculate max sendable (balance - fee)
            guard let balance = solanaKit.balance?.lamports else {
                throw SendError.insufficientBalance
            }
            // Subtract estimated fee (5000 lamports is typical)
            return balance > 5000 ? balance - 5000 : 0
        }
    }
}

extension SolanaAdapter: ITransactionsAdapter {
    var syncing: Bool {
        balanceState.syncing
    }
    
    var syncingObservable: RxSwift.Observable<Void> {
        balanceStateSubject.map { _ in () }
    }
    
    var lastBlockInfo: LastBlockInfo? {
        nil
    }
    
    var lastBlockUpdatedObservable: RxSwift.Observable<Void> {
        Observable.empty()
    }
    
    var explorerTitle: String {
        "Solscan"
    }
    
    var additionalTokenQueries: [MarketKit.TokenQuery] {
        []
    }
    
    func explorerUrl(transactionHash: String) -> String? {
        "https://solscan.io/tx/\(transactionHash)"
    }
    
    func transactionsObservable(token: MarketKit.Token?, filter: TransactionTypeFilter, address: String?) -> RxSwift.Observable<[TransactionRecord]> {
        transactionRecordsSubject.asObservable()
            .map { transactions in
                transactions.compactMap { transaction -> TransactionRecord? in
                    switch filter {
                    case .all: return transaction
                    case .incoming: return transaction.flow == "in" ? transaction : nil
                    case .outgoing: return transaction.flow == "out" ? transaction : nil
                    default: return nil
                    }
                }
            }
            .filter { !$0.isEmpty }
    }
    
    func transactionsSingle(from: TransactionRecord?, token: MarketKit.Token?, filter: TransactionTypeFilter, address: String?, limit: Int) -> RxSwift.Single<[TransactionRecord]> {
//        Single.just([])
        
        let tokenType : TokenType
        if token?.type == nil {
            tokenType = .native
        } else {
            tokenType = token!.type
        }
        
        let transactions = self.solanaKit.transactions.filter({ transaction in
            switch tokenType {
            case .native:
                return transaction.token_address == "So11111111111111111111111111111111111111111"
            case .spl(address: let address):
                return transaction.token_address == address
            default:
                return false
            }
        }).filter({ transaction in
            switch filter {
            case .all: return true
            case .outgoing: return transaction.flow == "in"
            case .incoming: return transaction.flow == "out"
            default: return false
            }
        }).map { transaction in
            SolanaTransactionRecord(source: self.transactionSource, transfer: transaction, token: token!)
        }
        
        return Single.just(transactions)
    }
    
    func rawTransaction(hash: String) -> String? {
        return hash
    }
    
    private func handleTransactionUpdates(_ transactions: [AccountTransfer]) {
        let records = transactions.map { transactionRecord(from: $0) }
        transactionRecordsSubject.onNext(records)
    }
    
    private func transactionRecord(from transfer: AccountTransfer) -> SolanaTransactionRecord {
        return SolanaTransactionRecord(source: self.transactionSource, transfer: transfer, token: self.token)
    }
}
