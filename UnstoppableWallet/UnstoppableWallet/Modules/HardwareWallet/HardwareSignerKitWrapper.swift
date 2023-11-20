import Foundation
import RxSwift
import EvmKit
import UIKit

enum HardwareError : Error {
    case notImplemented
}

class HalfScreenModalTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        HalfScreenPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

class HalfScreenPresentationController: UIPresentationController {
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        let containerHeight = containerView.bounds.height * 5 / 8
        return CGRect(x: 0, y: containerView.bounds.height - containerHeight, width: containerView.bounds.width, height: containerHeight)
    }
    
    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        containerView.layer.cornerRadius = 15
        containerView.layer.masksToBounds = true
    }
}


class HardwareSignerKitWrapper {
    
    private var address: EvmKit.Address
    
    init(address: EvmKit.Address) {
        self.address = address
    }
    
    func onFetchText(_ : String?) {
        print("onFetchText")
    }
    
    func signAndTransmit(rawTransaction: RawTransaction, evmKit: EvmKit.Kit) -> Single<FullTransaction> {
        
        let emptySignature = Signature(v: 0, r: 0, s: 0)
        let data = TransactionBuilder.encode(rawTransaction: rawTransaction, signature: emptySignature, chainId: evmKit.chain.id)
        
        return Single<FullTransaction>.create { [weak self] single in
            
            guard let strongSelf = self else {
                single(.error(AppError.weakReference))
                return Disposables.create()
            }
            
            let task = Task {
                //HardwareWalletKit.shared.signEvmRequest(address: evmKit.address.eip55, unsignedTransaction: "0x" + data.toHexString()) { result in
                    //if result == nil {
                        //single(.error(HardwareError.notImplemented))
                    //} else {
                        //strongSelf.showScanToTransmit()
                    //}
                //}
                //try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                //single(.error(HardwareError.notImplemented))
            }
            
            return Disposables.create {
                task.cancel()
            }
        }
            
    }
        
    func showScanToTransmit() -> Single<FullTransaction> {
        
#if targetEnvironment(simulator)
        let pasteEnabled = true
#else
        let pasteEnabled = false
#endif
        let scanQrViewController = ScanQrViewController(reportAfterDismiss: true, pasteEnabled: pasteEnabled)
        scanQrViewController.didFetch = { [weak self] in self?.onFetchText($0) }
        
        if let currentViewController = UIApplication.topViewController() {
            //let viewControllerToPresent = YourCustomViewController()
            //scanQrViewController.modalPresentationStyle = .pageSheet
            let transitioningDelegate = HalfScreenModalTransitioningDelegate()
            //scanQrViewController.transitioningDelegate = transitioningDelegate
            DispatchQueue.main.sync {
                //scanQrViewController.view.backgroundColor = .themeGray50
                currentViewController.present(scanQrViewController, animated: true, completion: nil)
            }
        }
        //onOpenViewController?(scanQrViewController)
        
        return Single<FullTransaction>.create { [weak self] single in
            
            guard let strongSelf = self else {
                single(.error(AppError.weakReference))
                return Disposables.create()
            }
            
            let task = Task {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                single(.error(HardwareError.notImplemented))
            }
            
            return Disposables.create {
                task.cancel()
            }
        }
        
    }
}

extension UIApplication {
    static func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        
        return base
    }
}

