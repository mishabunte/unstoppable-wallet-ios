import MarketKit
import Foundation

protocol ISendHandler {
    var baseToken: Token { get }
    var syncingText: String? { get }
    var expirationDuration: Int? { get }
    var initialTransactionSettings: InitialTransactionSettings? { get }
    func sendData(transactionSettings: TransactionSettings?) async throws -> ISendData
    func send(data: ISendData) async throws
    func sendSigned(signedTx: String) async throws
    func serialize(data: ISendData) async throws -> String
}

extension ISendHandler {
    var syncingText: String? {
        nil
    }

    var expirationDuration: Int? {
        nil
    }

    var initialTransactionSettings: InitialTransactionSettings? {
        nil
    }
}
