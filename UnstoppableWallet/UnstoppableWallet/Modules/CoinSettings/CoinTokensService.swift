import RxSwift
import RxRelay
import MarketKit

class CoinTokensService {
    private let approveTokensRelay = PublishRelay<CoinWithTokens>()
    private let rejectApproveTokensRelay = PublishRelay<FullCoin>()

    private let requestRelay = PublishRelay<Request>()
}

extension CoinTokensService {

    var approveTokensObservable: Observable<CoinWithTokens> {
        approveTokensRelay.asObservable()
    }

    var rejectApproveTokensObservable: Observable<FullCoin> {
        rejectApproveTokensRelay.asObservable()
    }

    var requestObservable: Observable<Request> {
        requestRelay.asObservable()
    }

    func approveTokens(fullCoin: FullCoin, currentTokens: [Token] = []) {
        let supportedTokens = fullCoin.supportedTokens

        guard supportedTokens.count > 1 else {
            approveTokensRelay.accept(CoinWithTokens(coin: fullCoin.coin, tokens: supportedTokens))
            return
        }

        let request = Request(fullCoin: fullCoin, currentTokens: currentTokens)
        requestRelay.accept(request)
    }

    func select(tokens: [Token], coin: Coin) {
        let coinWithTokens = CoinWithTokens(coin: coin, tokens: tokens)
        approveTokensRelay.accept(coinWithTokens)
    }

    func cancel(fullCoin: FullCoin) {
        rejectApproveTokensRelay.accept(fullCoin)
    }

}

extension CoinTokensService {

    struct CoinWithTokens {
        let coin: Coin
        let tokens: [Token]

        init(coin: Coin, tokens: [Token] = []) {
            self.coin = coin
            self.tokens = tokens
        }
    }

    struct Request {
        let fullCoin: FullCoin
        let currentTokens: [Token]
    }

}
