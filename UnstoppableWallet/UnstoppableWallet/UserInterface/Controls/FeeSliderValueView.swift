import SnapKit
import UIKit

class FeeSliderValueView: UIView {
    private let feeRateLabel = UILabel()
    private let unitNameLabel = UILabel()

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public required init() {
        super.init(frame: CGRect.zero)

        backgroundColor = .themeClaude
        addSubview(feeRateLabel)
        feeRateLabel.snp.makeConstraints { maker in
            maker.top.equalToSuperview().offset(CGFloat.margin2x)
            maker.centerX.equalToSuperview()
            maker.leading.trailing.equalToSuperview().inset(CGFloat.margin4)
        }
        feeRateLabel.textAlignment = .center
        feeRateLabel.textColor = .themeLeah
        feeRateLabel.font = .body

        addSubview(unitNameLabel)
        unitNameLabel.snp.makeConstraints { maker in
            maker.centerX.equalToSuperview()
            maker.top.equalTo(feeRateLabel.snp.bottom)
        }
        unitNameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        unitNameLabel.font = .micro
        unitNameLabel.textAlignment = .center
        unitNameLabel.textColor = .themeGray
    }

    func set(descriptionText: String?) {
        unitNameLabel.text = descriptionText
    }

    func set(value: String?) {
        feeRateLabel.text = value
    }
}

extension FeeSliderValueView: HUDContentViewInterface {
    public func updateConstraints(forSize _: CGSize) {
        // do nothing
    }

    public var actions: [HUDTimeAction] {
        get { [] }
        set {}
    } // ignore all actions on view
}
