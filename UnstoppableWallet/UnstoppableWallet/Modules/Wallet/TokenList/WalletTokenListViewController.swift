import Combine
import DeepDiff
import MarketKit
import RxCocoa
import RxSwift
import SectionsTableView
import UIKit

class WalletTokenListViewController: ThemeSearchViewController {
    private let viewModel: WalletTokenListViewModel

    var hideSearchBar: Bool = false

    let tableView = UITableView(frame: .zero, style: .plain)
    private let dataSource: ISectionDataSource

    init(viewModel: WalletTokenListViewModel, dataSource: ISectionDataSource) {
        self.viewModel = viewModel
        self.dataSource = dataSource

        super.init(scrollViews: [tableView])

        navigationItem.largeTitleDisplayMode = .never
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = viewModel.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "button.cancel".localized, style: .plain, target: self, action: #selector(onTapClose))
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.searchController?.searchBar.placeholder = "add_token.coin_name".localized
        if hideSearchBar {
            navigationItem.searchController = nil
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        tableView.backgroundColor = .clear
        tableView.sectionHeaderTopPadding = 0
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.delaysContentTouches = false
        tableView.alwaysBounceVertical = false

        tableView.dataSource = dataSource
        tableView.delegate = dataSource

        dataSource.prepare(tableView: tableView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.deselectCell(withCoordinator: transitionCoordinator, animated: animated)
    }

    @objc func onTapClose() {
        dismiss(animated: true)
    }
}
