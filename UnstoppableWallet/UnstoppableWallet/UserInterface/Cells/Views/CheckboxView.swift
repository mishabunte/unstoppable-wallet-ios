

import UIKit

class CheckboxView: UIView {
    private static let checkBoxLeadingMargin: CGFloat = .margin16
    private static let checkBoxSize: CGFloat = 24
    private static let textLeadingMargin: CGFloat = .margin16
    private static let textTrailingMargin: CGFloat = .margin16
    private static let textVerticalMargin: CGFloat = .margin16
    private static let textFont: UIFont = .subhead2

    private let checkBoxView = UIView()
    private let checkBoxImageView = UIImageView()
    private let descriptionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        addSubview(checkBoxView)
        checkBoxView.snp.makeConstraints { maker in
            maker.leading.equalToSuperview().inset(CheckboxView.checkBoxLeadingMargin)
            maker.centerY.equalToSuperview()
            maker.size.equalTo(CheckboxView.checkBoxSize)
        }

        checkBoxView.layer.cornerRadius = .cornerRadius12
        checkBoxView.layer.backgroundColor = UIColor.themeBlade.cgColor

        checkBoxView.addSubview(checkBoxImageView)
        checkBoxImageView.snp.makeConstraints { maker in
            maker.center.equalToSuperview()
        }

        checkBoxImageView.image = UIImage(named: "check_2_24")?.withRenderingMode(.alwaysTemplate)
        checkBoxImageView.isHidden = true
        checkBoxImageView.tintColor = .themeDark

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { maker in
            maker.leading.equalTo(checkBoxView.snp.trailing).offset(CheckboxView.textLeadingMargin)
            maker.top.equalToSuperview().inset(CheckboxView.textVerticalMargin)
            maker.trailing.equalToSuperview().inset(CheckboxView.textTrailingMargin)
        }

        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = CheckboxView.textFont
        descriptionLabel.textColor = .themeLeah
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var text: String? {
        get { descriptionLabel.text }
        set { descriptionLabel.text = newValue }
    }

    var textColor: UIColor? {
        get { descriptionLabel.textColor }
        set { descriptionLabel.textColor = newValue }
    }

    var checked: Bool {
        get { !checkBoxImageView.isHidden }
        set {
            checkBoxImageView.isHidden = !newValue
            checkBoxView.layer.backgroundColor = newValue ? UIColor.themeYellowD.cgColor : UIColor.themeBlade.cgColor
        }
    }
}

extension CheckboxView {
    static func height(containerWidth: CGFloat, text: String, insets: UIEdgeInsets = .zero) -> CGFloat {
        let textWidth = containerWidth - insets.width - checkBoxLeadingMargin - checkBoxSize - textLeadingMargin - textTrailingMargin
        let textHeight = text.height(forContainerWidth: textWidth, font: textFont)

        return textHeight + 2 * textVerticalMargin
    }
}
