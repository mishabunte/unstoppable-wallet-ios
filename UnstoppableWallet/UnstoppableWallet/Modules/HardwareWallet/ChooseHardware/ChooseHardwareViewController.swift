import Foundation
import UIKit
import ThemeKit
import SectionsTableView
import RxSwift
import RxCocoa
import ComponentKit
import UIExtensions

class ChooseHardwareViewController: CoinToggleViewController {
    private let viewModel: ChooseHardwareViewModel
    private let gradientWrapperView = BottomGradientHolder()
    private let hardwareButton = PrimaryButton()

    private weak var sourceViewController: UIViewController?

    init(viewModel: ChooseHardwareViewModel, sourceViewController: UIViewController?) {
        self.viewModel = viewModel
        self.sourceViewController = sourceViewController

        super.init(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
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
        gradientWrapperView.addSubview(hardwareButton)

        hardwareButton.set(style: .yellow)
        hardwareButton.setTitle("hardware_address.hardware".localized, for: .normal)
        hardwareButton.addTarget(self, action: #selector(onTapHardware), for: .touchUpInside)

        subscribe(disposeBag, viewModel.hardwareEnabledDriver) { [weak self] enabled in
            self?.hardwareButton.isEnabled = enabled
        }
        subscribe(disposeBag, viewModel.hardwareSignal) { [weak self] in
            HudHelper.instance.show(banner: .walletAdded)
            (self?.sourceViewController ?? self)?.dismiss(animated: true)
        }
        subscribe(disposeBag, viewModel.hardwareEnabledDriver) { [weak self] enabled in
            self?.hardwareButton.isEnabled = enabled
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setInitialState(bottomPadding: gradientWrapperView.height)
        hardwareButton.isEnabled = true
        viewModel.onEnable(uid: "ethereum")
    }

    @objc private func onTapHardware() {
        viewModel.onTapHardware()
    }

}
