import UIKit
import ThemeKit
import SnapKit
import ComponentKit

class HardwareWalletScanSignatureCell: UITableViewCell {
    
    private let scanView: ScanQrView
    
    var didFetch: ((String) -> Void)?

    init() {
        
        scanView = ScanQrView(bottomInset: 0)
        
        super.init(style: .default, reuseIdentifier: nil)

        selectionStyle = .none
        backgroundColor = .clear
        clipsToBounds = true
        
        contentView.cornerRadius = .cornerRadius8
        contentView.layer.borderColor = UIColor.themeSteel20.cgColor
        contentView.layer.borderWidth = .heightOneDp
        contentView.snp.makeConstraints { maker in
            maker.top.bottom.equalToSuperview()
            maker.leading.trailing.equalToSuperview().inset(CGFloat.margin16)
        }
        contentView.addSubview(scanView)

        scanView.delegate = self
        
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            scanView.snp.makeConstraints { maker in
                maker.leading.trailing.equalToSuperview().inset(-CGFloat.margin24)
                maker.height.equalToSuperview()
                maker.centerX.equalToSuperview()
                maker.centerY.equalToSuperview()
            }
            scanView.start()
            scanView.startCaptureSession()
        }
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        scanView.stop()
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension HardwareWalletScanSignatureCell {
    
    var cellHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return screenWidth / 2.0
    }
    
}

extension HardwareWalletScanSignatureCell: IScanQrCodeDelegate {
    func didScan(string: String) {
        scanView.stop()
        self.didFetch?(string)
    }
}
