import Combine
import Foundation

protocol IReceiveAddressService {
    var title: String { get }
    var coinName: String { get }
    var state: DataStatus<ReceiveAddress> { get }
    var statusUpdatedPublisher: AnyPublisher<DataStatus<ReceiveAddress>, Never> { get }
}

protocol IReceiveAddressViewItemFactory {
    func viewItem(item: ReceiveAddress, amount: String?) -> ReceiveAddressModule.ViewItem
    func popup(item: ReceiveAddress) -> ReceiveAddressModule.PopupWarningItem?
    func actions(item: ReceiveAddress) -> [ReceiveAddressModule.ActionType]
}

class ReceiveAddressViewModel: ObservableObject {
    private let service: IReceiveAddressService
    private let viewItemFactory: IReceiveAddressViewItemFactory
    private let decimalParser: AmountDecimalParser
    private var cancellables = Set<AnyCancellable>()
    private var hasAppeared = false

    @Published private(set) var state: DataStatus<ReceiveAddressModule.ViewItem> = .loading
    @Published var popup: ReceiveAddressModule.PopupWarningItem?
    @Published private(set) var actions: [ReceiveAddressModule.ActionType] = []
    @Published private(set) var amount: Decimal = 0

    private var amountFieldChangedSuccessSubject = PassthroughSubject<Bool, Never>()
    var amountFieldChangedSuccessPublisher: AnyPublisher<Bool, Never> {
        amountFieldChangedSuccessSubject.eraseToAnyPublisher()
    }

    init(service: IReceiveAddressService, viewItemFactory: IReceiveAddressViewItemFactory, decimalParser: AmountDecimalParser) {
        self.service = service
        self.viewItemFactory = viewItemFactory
        self.decimalParser = decimalParser

        service.statusUpdatedPublisher
            .sink { [weak self] in self?.sync(state: $0) }
            .store(in: &cancellables)

        sync(state: service.state)
    }

    private func sync(state: DataStatus<ReceiveAddress>) {
        self.state = state.map { viewItemFactory.viewItem(item: $0, amount: amount == 0 ? nil : amount.description) }
        syncPopup(state: state)
        syncActions(state: state)
    }

    private func syncPopup(state: DataStatus<ReceiveAddress>) {
        if hasAppeared, let item = state.data {
            let popup = viewItemFactory.popup(item: item)
            self.popup = popup
        }
    }

    private func syncActions(state: DataStatus<ReceiveAddress>) {
        if let item = state.data {
            actions = viewItemFactory.actions(item: item)
        }
    }
}

extension ReceiveAddressViewModel {
    var title: String {
        service.title
    }

    var coinName: String {
        service.coinName
    }

    func set(amount: String) {
        let value = decimalParser.parseAnyDecimal(from: amount) ?? 0
        self.amount = value
        sync(state: service.state)
    }

    func onFirstAppear() {
        hasAppeared = true
        syncPopup(state: service.state)
    }

    func showPopup() {
        syncPopup(state: service.state)
    }

    func onAmountChanged(_ text: String) {
        set(amount: text)
        stat(page: .receive, event: .setAmount)
    }

    var initialText: String {
        amount == 0 ? "" : amount.description
    }

    var stellarSendData: SendData? {
        guard let service = service as? ReceiveAddressService, let adapter = service.adapter as? StellarAdapter else {
            return nil
        }

        return .stellar(data: .changeTrust(asset: adapter.asset, limit: StellarAdapter.maxValue), token: service.wallet.token, memo: nil)
    }
}

extension ReceiveAddressViewModel {
    static func instance(wallet: Wallet) -> ReceiveAddressViewModel {
        let service = ReceiveAddressService(wallet: wallet, adapterManager: App.shared.adapterManager)
        let depositViewItemFactory = ReceiveAddressViewItemFactory()

        return ReceiveAddressViewModel(service: service, viewItemFactory: depositViewItemFactory, decimalParser: AmountDecimalParser())
    }
}
