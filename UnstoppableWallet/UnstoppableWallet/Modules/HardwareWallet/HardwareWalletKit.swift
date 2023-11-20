import CoreNFC
import SwiftUI
import EvmKit

class HardwareWalletKit: NSObject, NFCNDEFReaderSessionDelegate {
    
    static var shared = HardwareWalletKit()
    
    struct HitoNfcRequest {
        
        enum HitoNfcRequestType {
            case signEvmTransaction
            case signExpertMode
            case requestUtxoAddress
        }
        
        let type              : HitoNfcRequestType
        let payload           : String
        var isDataTransmitted : Bool               = false
    }
    
    var completion : ((String?) -> Void)?
    
    //var nfcMessage = "" // ?
    //var action: String? // ?
    var rawTransaction: RawTransaction?
    //var isDataTransmitted: Bool = false
    var lastError: String?
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        //
        //session.po
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        //print("readerSeesion didInvalidateWithError")
        lastError = self.hitoNfcRequest.isDataTransmitted ? nil : error.localizedDescription
        DispatchQueue.main.async {
            self.completion?(self.lastError)
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        //
        print("didDetectNDEFs")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        
        print(hitoNfcRequest.payload)
        
        let payload = NFCNDEFPayload(format: NFCTypeNameFormat.nfcWellKnown,
                                     type: Data(_: [0x54]), identifier: Data(),
                                     payload: hitoNfcRequest.payload.data(using: .utf8)!)

        guard tags.count == 1 else {
            session.invalidate(errorMessage: "Hito Device protocol is invalid.")
            return
        }
        let currentTag = tags.first!

        session.connect(to: currentTag) { error in

            guard error == nil else {
                session.invalidate(errorMessage: "Could not connect to Hito Wallet.")
                return
            }

            currentTag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Could not query status of Hito Wallet.")
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Protocol is not supported.")
                case .readOnly:
                    session.invalidate(errorMessage: "Protocol is only readable.")
                case .readWrite:
                    let message = NFCNDEFMessage.init(records: [payload])
                    currentTag.writeNDEF(message) { error in
                        if error != nil {
                            session.invalidate(errorMessage: "Failed to write message.")
                        } else {
                            session.alertMessage = "Scan to Transmit"
                            //self
                            self.hitoNfcRequest.isDataTransmitted = true
                            session.invalidate()
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown status of device.")
                }
            }
        }
    }
    
    var hitoNfcRequest: HitoNfcRequest = HitoNfcRequest(type: .signEvmTransaction, payload: "")

    func signEvmRequest(address: String, chainId: Int, rawTransaction: RawTransaction, completion: @escaping (String?) -> Void) {
        
        self.completion = completion
        self.rawTransaction = rawTransaction
        
        let emptySignature = Signature(v: 0, r: 0, s: 0)
        let data = TransactionBuilder.encode(rawTransaction: rawTransaction, signature: emptySignature, chainId: chainId)
        let transactionHex = "0x" + data.toHexString()
        
        print("sendtoDevice", address, transactionHex)
        let payload = "evm.sign:" + address + ":" + transactionHex
        print(payload)
        
        hitoNfcRequest = HitoNfcRequest(type: .signEvmTransaction, payload: payload)
        
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(nil)
            return
        }
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "Tap to Confirm"
        session.begin()

    }
    
}
