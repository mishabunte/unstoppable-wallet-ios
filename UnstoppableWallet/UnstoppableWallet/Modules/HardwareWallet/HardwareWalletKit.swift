import CoreNFC
import SwiftUI

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
    var txraw: String? // ?
    //var isDataTransmitted: Bool = false
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        //
        //session.po
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        //print("readerSeesion didInvalidateWithError")
        
        App.instance?.appManager.enableBlurManager()
        
        DispatchQueue.main.async {
            self.completion?(self.hitoNfcRequest.isDataTransmitted ? self.txraw : nil)
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

    func signEvmRequest(address: String, unsignedTransaction: String, completion: @escaping (String?) -> Void) {
        
        App.instance?.appManager.disableBlurManager()
        
        self.completion = completion
        
        print("sendtoDevice", address, unsignedTransaction)
        let payload = "evm.sign:" + address + ":" + unsignedTransaction
        print(payload)
        
        hitoNfcRequest = HitoNfcRequest(type: .signEvmTransaction, payload: payload)
        
        self.txraw = unsignedTransaction
        
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(nil)
            return
        }
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "Tap to Confirm"
        session.begin()

    }
    
}
