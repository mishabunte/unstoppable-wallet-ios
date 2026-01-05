import Combine
import HsExtensions
import SectionsTableView
import SnapKit
import UIExtensions
import UIKit

class LinkHardwareWalletViewController: KeyboardAwareViewController {
    private let viewModel: LinkHardwareWalletViewModel
    private var cancellables = Set<AnyCancellable>()

    private let tableView = SectionsTableView(style: .grouped)
    private let gradientWrapperView = BottomGradientHolder()
    private let linkButton = PrimaryButton()

    private let nameCell = TextFieldCell()
    private let addressInputCell = TextInputCell(statPage: .linkHardwareWallet, statEntity: .key)
    private let addressCautionCell = FormCautionCell()

    private var isLoaded = false
    private weak var sourceViewController: UIViewController?

    init(viewModel: LinkHardwareWalletViewModel, sourceViewController: UIViewController?) {
        self.viewModel = viewModel
        self.sourceViewController = sourceViewController

        super.init(scrollViews: [tableView], accessoryView: gradientWrapperView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "link_hardware_wallet.title".localized

        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "button.cancel".localized, style: .plain, target: self, action: #selector(onTapClose))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "link_hardware_wallet.link".localized, style: .done, target: self, action: #selector(onTapLink))
        navigationItem.rightBarButtonItem?.tintColor = .themeJacob

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.sectionDataSource = self

        gradientWrapperView.add(to: self)
        gradientWrapperView.addSubview(linkButton)

        linkButton.set(style: .yellow)
        linkButton.setTitle("link_hardware_wallet.link".localized, for: .normal)
        linkButton.addTarget(self, action: #selector(onTapLink), for: .touchUpInside)

        let defaultName = viewModel.defaultName
        nameCell.inputText = defaultName
        nameCell.inputPlaceholder = defaultName
        nameCell.autocapitalizationType = .words
        nameCell.onChangeText = { [weak self] in self?.viewModel.onChange(name: $0 ?? "") }

        addressInputCell.set(placeholderText: "link_hardware_wallet.address_placeholder".localized)
        addressInputCell.onChangeHeight = { [weak self] in self?.reloadTable() }
        addressInputCell.onChangeText = { [weak self] in self?.viewModel.onChange(address: $0) }
        addressInputCell.onChangeTextViewCaret = { [weak self] in self?.syncContentOffsetIfRequired(textView: $0) }
        addressInputCell.onOpenViewController = { [weak self] in self?.present($0, animated: true) }

        addressCautionCell.onChangeHeight = { [weak self] in self?.reloadTable() }

        subscribe(&cancellables, viewModel.$name) { [weak self] name in
            self?.nameCell.inputText = name
            self?.nameCell.inputPlaceholder = name
        }
        subscribe(&cancellables, viewModel.$caution) { [weak self] caution in
            self?.addressInputCell.set(cautionType: caution?.type)
            self?.addressCautionCell.set(caution: caution)
        }
        subscribe(&cancellables, viewModel.$linkEnabled) { [weak self] enabled in
            self?.handleButtonState(enabled: enabled)
        }
        subscribe(&cancellables, viewModel.proceedPublisher) { [weak self] accountType, name in
            self?.proceedToLink(accountType: accountType, name: name)
        }

        tableView.buildSections()
        isLoaded = true
        handleButtonState(enabled: viewModel.linkEnabled)
    }

    @objc private func onTapLink() {
        viewModel.onTapLink()
    }

    @objc private func onTapClose() {
        dismiss(animated: true)
    }

    private func reloadTable() {
        guard isLoaded else {
            return
        }

        tableView.buildSections()
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    private func handleButtonState(enabled: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = enabled
        linkButton.isEnabled = enabled
    }

    private func proceedToLink(accountType: AccountType, name: String) {
        let viewController = LinkHardwareWalletModule.viewController(sourceViewController: sourceViewController, accountType: accountType, name: name)
//        LinkHardwareWalletModule.link(accountType: accountType, name: name)
//        HudHelper.instance.show(banner: .walletAdded)
//        (sourceViewController ?? self).dismiss(animated: true)
        
        navigationController?.pushViewController(viewController, animated: true)
    }
}

extension LinkHardwareWalletViewController: SectionsDataSource {
    func buildSections() -> [SectionProtocol] {
        [
            Section(
                id: "margin",
                headerState: .margin(height: .margin12)
            ),
            Section(
                id: "name",
                headerState: tableView.sectionHeader(text: "link_hardware_wallet.name".localized),
                footerState: .margin(height: .margin32),
                rows: [
                    StaticRow(
                        cell: nameCell,
                        id: "name",
                        height: .heightSingleLineCell
                    ),
                ]
            ),
            Section(
                id: "account-type",
                footerState: .margin(height: .margin32),
                rows: [
                    tableView.universalRow48(
                        id: "account_type",
                        title: .body("link_hardware_wallet.account_type".localized),
                        value: .subhead1(viewModel.accountType.title),
                        accessoryType: .dropdown,
                        autoDeselect: true,
                        isFirst: true,
                        isLast: true
                    ) { [weak self] in
                        self?.onTapAccountType()
                    },
                ]
            ),
            Section(
                id: "address-input",
                rows: [
                    StaticRow(
                        cell: addressInputCell,
                        id: "address-input",
                        dynamicHeight: { [weak self] width in
                            self?.addressInputCell.cellHeight(containerWidth: width) ?? 0
                        }
                    ),
                    StaticRow(
                        cell: addressCautionCell,
                        id: "address-caution",
                        dynamicHeight: { [weak self] width in
                            self?.addressCautionCell.height(containerWidth: width) ?? 0
                        }
                    ),
                ]
            ),
        ]
    }

    private func onTapAccountType() {
        let alertController = AlertRouter.module(
            title: "link_hardware_wallet.account_type".localized,
            viewItems: LinkHardwareWalletViewModel.HardwareAccountType.allCases.enumerated().map { _, accountType in
                AlertViewItem(
                    text: accountType.title,
                    description: accountType.subtitle,
                    selected: viewModel.accountType == accountType
                )
            }
        ) { [weak self] index in
            self?.viewModel.onSelectAccountType(accountType: LinkHardwareWalletViewModel.HardwareAccountType.allCases[index])
        }

        present(alertController, animated: true)
    }
}
