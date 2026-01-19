//
//  NFCViewController.swift
//

import CoreNFC
import SwiftUI


class NFCController: NSObject, NFCNDEFReaderSessionDelegate {
    
    static var shared = NFCController()
    
    struct HitoNfcRequest {
        
        enum HitoNfcRequestType {
            case eth_send
            case authentication
            case solana_send
            case stellar_send
            
            func getPrefix() -> String {
                switch self {
                case .eth_send:
                    return "eth:"
                case .authentication:
                    return "hito.auth:"
                case .solana_send:
                    return "solana:"
                case .stellar_send:
                    return "stellar:"
                }
            }
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
        DispatchQueue.main.async {
            self.completion?(self.hitoNfcRequest.isDataTransmitted ? self.txraw : nil)
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        //
        print("didDetectNDEFs")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        
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
    
    var hitoNfcRequest: HitoNfcRequest = HitoNfcRequest(type: .eth_send, payload: "")

    func startNfcSession(type: HitoNfcRequest.HitoNfcRequestType, messageText: String, completion: @escaping (String?) -> Void) {
        
        self.completion = completion
        hitoNfcRequest = HitoNfcRequest(type: type, payload: type.getPrefix() + messageText)
        guard NFCNDEFReaderSession.readingAvailable else {
            //let alertController = UIAlertController(
            //   title: "Scanning Not Supported",
            //message: "This device doesn't support tag scanning.",
            //preferredStyle: .alert
            //)
            //alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            //self.present(alertController, animated: true, completion: nil)
            return
        }
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "Tap to Confirm"
        session.begin()
    }
    
    func signEvmRequest(address: String, unsignedTransaction: String, completion: @escaping (String?) -> Void) {
        
        let message = address + ":" + unsignedTransaction
        startNfcSession(type: .eth_send, messageText: message, completion: completion)
    }
    
    func signStellarXDR(unsignedTransaction: String, completion: @escaping (String?) -> Void) {
        startNfcSession(type: .stellar_send, messageText: unsignedTransaction, completion: completion)
    }
    
    func sendAuthToken(completion: @escaping (String?) -> Void) async {
        
        struct RequestToken: Codable {
            var token  : String
            var status : String
        }
        
        var requestToken : RequestToken? = nil
        
        guard let url = URL(string: "https://auth.hito.xyz/api/request_token") else { print("error reaching the server for authentification"); return }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        do {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            requestToken = try JSONDecoder().decode(RequestToken.self, from: data)
        } catch {
            print("error connecting to the server")
            return
        }
        
        if requestToken!.status != "ok" {
            print("error status")
            return
        }
        
        var timestamp = Int(Date().timeIntervalSince1970)
        
        timestamp = timestamp - timestamp % 600
        
        let payload = String(timestamp) + "." + requestToken!.token
        
        startNfcSession(type: .authentication, messageText: payload, completion: completion)
    }
}
