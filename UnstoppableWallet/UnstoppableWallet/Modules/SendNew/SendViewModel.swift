import Combine
import Foundation
import HsExtensions
import MarketKit

class SendViewModel: ObservableObject {
    private let currencyManager = App.shared.currencyManager
    private let marketKit = App.shared.marketKit
    private let recentAddressStorage = App.shared.recentAddressStorage

    private var syncTask: AnyTask?
    private var timer: AnyCancellable?
    private var ratesCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    let handler: ISendHandler?
    let transactionService: ITransactionService?
    let currency: Currency

    private let address: String?
    public let isHardware: Bool
    private var signedTransaction: String = ""
    private var NfcError: Error? = nil

    @Published var rates = [String: Decimal]()

    @Published var sending = false
    @Published var transactionSettingsModified = false
    @Published var timeLeft: Int = 0

    let errorSubject = PassthroughSubject<String, Never>()

    @Published var state: State = .syncing {
        didSet {
            timer?.cancel()

            if let handler, let expirationDuration = handler.expirationDuration, let data = state.data, data.canSend {
                timeLeft = expirationDuration

                timer = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        self?.handleTimerTick()
                    }
            }
        }
    }

    var cautions: [CautionNew] {
        var cautions = transactionService?.cautions ?? []

        if let data = state.data, let baseToken = handler?.baseToken {
            cautions.append(contentsOf: data.cautions(baseToken: baseToken))
        }

        return cautions
    }

    var canSend: Bool {
        guard let data = state.data, data.canSend else {
            return false
        }
        
        if self.needsSignature {
            return false
        }

        if let service = transactionService, service.cautions.contains(where: { $0.type == .error }) {
            return false
        }

        return true
    }
    
    var needsSignature: Bool {
        return self.isHardware ? signedTransaction.isEmpty : false
    }

    init(sendData: SendData, address: String? = nil, isHardware: Bool = false) {
        handler = SendHandlerFactory.handler(sendData: sendData)
        currency = currencyManager.baseCurrency
        self.address = address
        self.isHardware = isHardware
        print("is hardware: \(self.isHardware)")

        if let handler {
            transactionService = TransactionServiceFactory.transactionService(blockchainType: handler.baseToken.blockchainType, initialTransactionSettings: handler.initialTransactionSettings)
        } else {
            transactionService = nil
        }

        transactionService?.updatePublisher
            .sink { [weak self] in
                self?.syncTransactionSettingsModified()
                self?.sync()
            }
            .store(in: &cancellables)

        sync()
    }

    private func handleTimerTick() {
        timeLeft -= 1

        if timeLeft == 0 {
            timer?.cancel()
        }
    }

    private func syncTransactionSettingsModified() {
        transactionSettingsModified = transactionService?.modified ?? false
    }

    @MainActor private func syncRates(coins: [Coin]) {
        let coinUids = Array(Set(coins)).map(\.uid)

        rates = marketKit.coinPriceMap(coinUids: coinUids, currencyCode: currency.code).mapValues { $0.value }
        ratesCancellable = marketKit.coinPriceMapPublisher(coinUids: coinUids, currencyCode: currency.code)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rates in self?.rates = rates.mapValues { $0.value } }
    }

    @MainActor private func set(sending: Bool) {
        self.sending = sending
    }
}

extension SendViewModel {
    func sync() {
        guard let handler else {
            return
        }

        syncTask = nil

        if !state.isSyncing {
            state = .syncing
        }

        syncTask = Task { [weak self, handler, transactionService] in
            var state: State

            do {
                try await transactionService?.sync()

                let data = try await handler.sendData(transactionSettings: transactionService?.transactionSettings)

                await self?.syncRates(coins: [handler.baseToken.coin] + data.rateCoins)

                state = .success(data: data)
            } catch {
                state = .failed(error: error)
            }

            if !Task.isCancelled {
                await MainActor.run { [weak self, state] in
                    self?.state = state
                }
            }
        }
        .erased()
    }
    
    func startNfc() async throws {
        do {
            guard let handler else {
                throw SendError.noHandler
            }
            
            guard let data = state.data else {
                throw SendError.noData
            }
            
            let unsignedTx = try await handler.serialize(data: data)
            App.shared.nfcController.signStellarXDR(unsignedTransaction: unsignedTx) { txraw in
                guard let txraw = txraw else {
                    self.NfcError = SendError.noData
                    return
                }
                self.NfcError = nil
            }
        } catch {
            await set(sending: false)
            errorSubject.send(error.smartDescription)
            throw error
        }
    }

    func send() async throws {
        do {
            guard let handler else {
                throw SendError.noHandler
            }

            guard let data = state.data else {
                throw SendError.noData
            }

            await set(sending: true)
            
            if self.isHardware {
                _ = try await handler.sendSigned(data: data)
            } else {
                _ = try await handler.send(data: data)
            }

            if let address {
                try? recentAddressStorage.save(address: address, blockchainUid: handler.baseToken.blockchain.uid)
            }
        } catch {
            await set(sending: false)
            errorSubject.send(error.smartDescription)
            throw error
        }
    }
}

extension SendViewModel {
    enum State {
        case syncing
        case success(data: ISendData)
        case failed(error: Error)

        var data: ISendData? {
            switch self {
            case let .success(data): return data
            default: return nil
            }
        }

        var isSyncing: Bool {
            switch self {
            case .syncing: return true
            default: return false
            }
        }
    }

    enum SendError: Error {
        case noHandler
        case noData
    }
}
