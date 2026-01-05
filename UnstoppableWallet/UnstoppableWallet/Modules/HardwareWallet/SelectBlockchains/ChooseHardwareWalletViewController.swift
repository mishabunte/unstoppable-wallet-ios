
import Foundation
import RxCocoa
import RxSwift
import SectionsTableView

import UIExtensions
import UIKit

class ChooseHardwareWalletViewController: CoinToggleViewController {
    private let viewModel: ChooseHardwareWalletViewModel
    private let gradientWrapperView = BottomGradientHolder()
    private let linkButton = PrimaryButton()

    private weak var sourceViewController: UIViewController?

    init(viewModel: ChooseHardwareWalletViewModel, sourceViewController: UIViewController?) {
        self.viewModel = viewModel
        self.sourceViewController = sourceViewController

        super.init(viewModel: viewModel)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.searchController = nil

        title = viewModel.title

        // remake to bind with bottom view
        tableView.snp.remakeConstraints { maker in
            maker.leading.top.trailing.equalToSuperview()
        }

        gradientWrapperView.add(to: self, under: tableView)
        gradientWrapperView.addSubview(linkButton)

        linkButton.set(style: .yellow)
        linkButton.setTitle("watch_address.watch".localized, for: .normal)
        linkButton.addTarget(self, action: #selector(onTapLink), for: .touchUpInside)

        subscribe(disposeBag, viewModel.linkEnabledDriver) { [weak self] enabled in
            self?.linkButton.isEnabled = enabled
        }
        subscribe(disposeBag, viewModel.linkSignal) { [weak self] in
            HudHelper.instance.show(banner: .walletAdded)
            (self?.sourceViewController ?? self)?.dismiss(animated: true)
        }
        subscribe(disposeBag, viewModel.linkEnabledDriver) { [weak self] enabled in
            self?.linkButton.isEnabled = enabled
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setInitialState(bottomPadding: gradientWrapperView.height)
    }

    @objc private func onTapLink() {
        viewModel.onTapLink()
    }
}
