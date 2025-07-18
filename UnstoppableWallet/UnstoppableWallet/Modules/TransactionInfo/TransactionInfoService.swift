import EvmKit
import MarketKit
import RxSwift

class TransactionInfoService {
    private let disposeBag = DisposeBag()

    private let adapter: ITransactionsAdapter
    private let currencyManager: CurrencyManager
    private let rateService: HistoricalRateService
    private let nftMetadataService: NftMetadataService
    private let balanceHiddenManager: BalanceHiddenManager

    private var transactionRecord: TransactionRecord
    private var rates = [RateKey: CurrencyValue]()
    private var nftMetadata = [NftUid: NftAssetBriefMetadata]()

    private let transactionInfoItemSubject = PublishSubject<Item>()

    init(transactionRecord: TransactionRecord, adapter: ITransactionsAdapter, currencyManager: CurrencyManager, rateService: HistoricalRateService, nftMetadataService: NftMetadataService, balanceHiddenManager: BalanceHiddenManager) {
        self.transactionRecord = transactionRecord
        self.adapter = adapter
        self.currencyManager = currencyManager
        self.rateService = rateService
        self.nftMetadataService = nftMetadataService
        self.balanceHiddenManager = balanceHiddenManager

        subscribe(disposeBag, adapter.transactionsObservable(token: nil, filter: .all, address: nil)) { [weak self] in self?.sync(transactionRecords: $0) }
        subscribe(disposeBag, adapter.lastBlockUpdatedObservable) { [weak self] in self?.syncItem() }
        subscribe(disposeBag, rateService.rateUpdatedObservable) { [weak self] in self?.handle(rate: $0) }
        subscribe(disposeBag, nftMetadataService.assetsBriefMetadataObservable) { [weak self] in self?.handle(assetsBriefMetadata: $0) }

        fetchRates()
        fetchNftMetadata()
    }

    private var tokenForRates: [Token] {
        var tokens = [Token?]()

        switch transactionRecord {
        case let tx as EvmIncomingTransactionRecord: tokens.append(tx.value.token)
        case let tx as EvmOutgoingTransactionRecord: tokens.append(tx.value.token)
        case let tx as SwapTransactionRecord:
            tokens.append(tx.valueIn.token)
            tx.valueOut.flatMap { tokens.append($0.token) }
        case let tx as UnknownSwapTransactionRecord:
            tx.valueIn.flatMap { tokens.append($0.token) }
            tx.valueOut.flatMap { tokens.append($0.token) }
        case let tx as ApproveTransactionRecord: tokens.append(tx.value.token)
        case let tx as ContractCallTransactionRecord:
            tokens.append(contentsOf: tx.incomingEvents.map(\.value.token))
            tokens.append(contentsOf: tx.outgoingEvents.map(\.value.token))
        case let tx as ExternalContractCallTransactionRecord:
            tokens.append(contentsOf: tx.incomingEvents.map(\.value.token))
            tokens.append(contentsOf: tx.outgoingEvents.map(\.value.token))
        case let tx as TronIncomingTransactionRecord: tokens.append(tx.value.token)
        case let tx as TronOutgoingTransactionRecord: tokens.append(tx.value.token)
        case let tx as TronApproveTransactionRecord: tokens.append(tx.value.token)
        case let tx as TronContractCallTransactionRecord:
            tokens.append(contentsOf: tx.incomingEvents.map(\.value.token))
            tokens.append(contentsOf: tx.outgoingEvents.map(\.value.token))
        case let tx as TronExternalContractCallTransactionRecord:
            tokens.append(contentsOf: tx.incomingEvents.map(\.value.token))
            tokens.append(contentsOf: tx.outgoingEvents.map(\.value.token))
        case let tx as BitcoinIncomingTransactionRecord: tokens.append(tx.value.token)
        case let tx as BitcoinOutgoingTransactionRecord:
            tx.fee.flatMap { tokens.append($0.token) }
            tokens.append(tx.value.token)
        case let tx as TonTransactionRecord:
            for action in tx.actions {
                switch action.type {
                case let .send(value, _, _, _): tokens.append(value.token)
                case let .receive(value, _, _): tokens.append(value.token)
                default: ()
                }
            }
            tokens.append(tx.fee?.token)
        case let tx as StellarTransactionRecord:
            switch tx.type {
            case let .accountCreated(startingBalance, _): tokens.append(startingBalance.token)
            case let .accountFunded(startingBalance, _): tokens.append(startingBalance.token)
            case let .sendPayment(value, _, _): tokens.append(value.token)
            case let .receivePayment(value, _): tokens.append(value.token)
            case let .changeTrust(value, _, _, _): tokens.append(value.token)
            default: ()
            }
            tokens.append(tx.fee?.token)
        case let tx as ZcashShieldingTransactionRecord: tokens.append(tx.value.token)
        default: ()
        }

        if let evmTransaction = transactionRecord as? EvmTransactionRecord, evmTransaction.ownTransaction, let fee = evmTransaction.fee {
            tokens.append(fee.token)
        }

        if let tronTransaction = transactionRecord as? TronTransactionRecord, tronTransaction.ownTransaction, let fee = tronTransaction.fee {
            tokens.append(fee.token)
        }

        return Array(Set(tokens.compactMap { $0 }))
    }

    private func fetchRates() {
        for token in tokenForRates {
            let rateKey = RateKey(token: token, date: transactionRecord.date)
            if let currencyValue = rateService.rate(key: rateKey) {
                rates[rateKey] = currencyValue
            } else {
                rateService.fetchRate(key: rateKey)
            }
        }

        syncItem()
    }

    private func fetchNftMetadata() {
        let nftUids = transactionRecord.nftUids
        let assetsBriefMetadata = nftMetadataService.assetsBriefMetadata(nftUids: nftUids)

        nftMetadata = assetsBriefMetadata

        if !nftUids.subtracting(Set(assetsBriefMetadata.keys)).isEmpty {
            nftMetadataService.fetch(nftUids: nftUids)
        }
    }

    private func handle(rate: (RateKey, CurrencyValue)) {
        rates[rate.0] = rate.1
        syncItem()
    }

    private func handle(assetsBriefMetadata: [NftUid: NftAssetBriefMetadata]) {
        nftMetadata = assetsBriefMetadata
        syncItem()
    }

    private func sync(transactionRecords: [TransactionRecord]) {
        guard let transactionRecord = transactionRecords.first(where: { self.transactionRecord == $0 }) else {
            return
        }

        self.transactionRecord = transactionRecord
        transactionInfoItemSubject.onNext(item)
    }

    private func syncItem() {
        transactionInfoItemSubject.onNext(item)
    }
}

extension TransactionInfoService {
    var balanceHiddenObservable: Observable<Bool> {
        balanceHiddenManager.balanceHiddenObservable
    }

    var balanceHidden: Bool {
        balanceHiddenManager.balanceHidden
    }

    var item: Item {
        Item(
            record: transactionRecord,
            lastBlockInfo: adapter.lastBlockInfo,
            rates: Dictionary(uniqueKeysWithValues: rates.map { key, value in (key.token.coin, value) }),
            nftMetadata: nftMetadata,
            explorerTitle: adapter.explorerTitle,
            explorerUrl: adapter.explorerUrl(transactionHash: transactionRecord.transactionHash)
        )
    }

    var transactionItemUpdatedObserver: Observable<Item> {
        transactionInfoItemSubject.asObservable()
    }

    func rawTransaction() -> String? {
        adapter.rawTransaction(hash: transactionRecord.transactionHash)
    }
}

extension TransactionInfoService {
    struct Item {
        let record: TransactionRecord
        let lastBlockInfo: LastBlockInfo?
        let rates: [Coin: CurrencyValue]
        let nftMetadata: [NftUid: NftAssetBriefMetadata]
        let explorerTitle: String
        let explorerUrl: String?
    }
}
