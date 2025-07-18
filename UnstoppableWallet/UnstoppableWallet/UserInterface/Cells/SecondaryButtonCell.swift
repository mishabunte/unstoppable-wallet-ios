

import UIKit

class SecondaryButtonCell: UITableViewCell {
    private static let verticalPadding: CGFloat = .margin16

    private let button = SecondaryButton()

    var onTap: (() -> Void)?

    override init(style: CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(button)
        button.snp.makeConstraints { maker in
            maker.center.equalToSuperview()
        }

        button.addTarget(self, action: #selector(onTapButton), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTapButton() {
        onTap?()
    }

    var title: String? {
        get { button.title(for: .normal) }
        set { button.setTitle(newValue, for: .normal) }
    }

    var isEnabled: Bool {
        get { button.isEnabled }
        set { button.isEnabled = newValue }
    }

    func set(style: SecondaryButton.Style) {
        button.set(style: style)
    }
}

extension SecondaryButtonCell {
    static func height(style: SecondaryButton.Style) -> CGFloat {
        SecondaryButton.height(style: style) + 2 * verticalPadding
    }
}
