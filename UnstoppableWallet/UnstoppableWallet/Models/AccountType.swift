import BitcoinCore
import Crypto
import EvmKit
import Foundation
import HdWalletKit
import MarketKit
import TronKit

enum AccountType {
    case mnemonic(words: [String], salt: String, bip39Compliant: Bool)
    case evmPrivateKey(data: Data)
    case evmAddress(address: EvmKit.Address)
    case evmAddressHardware(address: EvmKit.Address)
    case tronAddress(address: TronKit.Address)
    case tronAddressHardware(address: TronKit.Address)
    case hdExtendedKey(key: HDExtendedKey)
    case hdExtendedKeyHardware(key: HDExtendedKey)
    case cex(cexAccount: CexAccount)

    var mnemonicSeed: Data? {
        switch self {
        case let .mnemonic(words, salt, bip39Compliant):
            return bip39Compliant
                ? Mnemonic.seed(mnemonic: words, passphrase: salt)
                : Mnemonic.seedNonStandard(mnemonic: words, passphrase: salt)

        default: return nil
        }
    }

    func uniqueId(hashed: Bool = true) -> Data {
        let privateData: Data
        switch self {
        case let .mnemonic(words, salt, bip39Compliant):
            var description = words.joined(separator: " ")
            if !bip39Compliant {
                description += "&nonBip39Compliant"
            }
            if !salt.isEmpty {
                description += "@" + salt
            }

            privateData = description.data(using: .utf8) ?? Data() // always non-null
        case let .evmPrivateKey(data):
            privateData = data
        case let .evmAddress(address):
            privateData = address.hex.hs.data
        case let .evmAddressHardware(address):
            privateData = address.hex.hs.data
        case let .tronAddress(address):
            privateData = address.hex.hs.data
        case let .tronAddressHardware(address):
            privateData = address.hex.hs.data
        case let .hdExtendedKey(key):
            privateData = key.serialized
        case let .hdExtendedKeyHardware(key):
            privateData = key.serialized
        case let .cex(cexAccount):
            privateData = cexAccount.uniqueId.data(using: .utf8) ?? Data() // always non-null
        }

        if hashed {
            return Data(SHA512.hash(data: privateData))
        } else {
            return privateData
        }
    }

    func supports(token: Token) -> Bool {
        switch self {
        case .mnemonic:
            switch (token.blockchainType, token.type) {
            case (.bitcoin, .derived): return true
            case (.bitcoinCash, .addressType): return true
            case (.ecash, .native): return true
            case (.litecoin, .derived): return true
            case (.dash, .native): return true
            case (.zcash, .native): return true
            case (.binanceChain, .native), (.binanceChain, .bep2): return true
            case (.ethereum, .native), (.ethereum, .eip20): return true
            case (.binanceSmartChain, .native), (.binanceSmartChain, .eip20): return true
            case (.polygon, .native), (.polygon, .eip20): return true
            case (.avalanche, .native), (.avalanche, .eip20): return true
            case (.gnosis, .native), (.gnosis, .eip20): return true
            case (.fantom, .native), (.fantom, .eip20): return true
            case (.arbitrumOne, .native), (.arbitrumOne, .eip20): return true
            case (.optimism, .native), (.optimism, .eip20): return true
            case (.tron, .native), (.tron, .eip20): return true
            default: return false
            }
        case .hdExtendedKey(let key), .hdExtendedKeyHardware(let key):
            switch token.blockchainType {
            case .bitcoin, .litecoin:
                guard let derivation = token.type.derivation, key.purposes.contains(where: { $0.mnemonicDerivation == derivation }) else {
                    return false
                }

                if token.blockchainType == .bitcoin {
                    return key.coinTypes.contains(where: { $0 == .bitcoin })
                }

                return key.coinTypes.contains(where: { $0 == .litecoin })
            case .bitcoinCash, .ecash, .dash:
                return key.purposes.contains(where: { $0 == .bip44 })
            default:
                return false
            }
        case .evmPrivateKey, .evmAddress, .evmAddressHardware:
            switch (token.blockchainType, token.type) {
            case (.ethereum, .native), (.ethereum, .eip20): return true
            case (.binanceSmartChain, .native), (.binanceSmartChain, .eip20): return true
            case (.polygon, .native), (.polygon, .eip20): return true
            case (.avalanche, .native), (.avalanche, .eip20): return true
            case (.gnosis, .native), (.gnosis, .eip20): return true
            case (.fantom, .native), (.fantom, .eip20): return true
            case (.arbitrumOne, .native), (.arbitrumOne, .eip20): return true
            case (.optimism, .native), (.optimism, .eip20): return true
            default: return false
            }
        case .tronAddress, .tronAddressHardware:
            switch (token.blockchainType, token.type) {
            case (.tron, .native), (.tron, .eip20): return true
            default: return false
            }
        default:
            return false
        }
    }

    var canAddTokens: Bool {
        switch self {
        case .mnemonic, .evmPrivateKey, .evmAddressHardware: return true
        default: return false
        }
    }

    var supportsWalletConnect: Bool {
        switch self {
        case .mnemonic, .evmPrivateKey, .evmAddressHardware: return true
        default: return false
        }
    }

    var supportsNft: Bool {
        switch self {
        case .cex: return false
        default: return true
        }
    }

    var withdrawalAllowed: Bool {
        switch self {
        case let .cex(cexAccount: account): return account.cex.withdrawalAllowed
        default: return true
        }
    }

    var description: String {
        switch self {
        case let .mnemonic(words, salt, _):
            let count = "\(words.count)"
            return salt.isEmpty ? "manage_accounts.n_words".localized(count) : "manage_accounts.n_words_with_passphrase".localized(count)
        case .evmPrivateKey:
            return "EVM Private Key"
        case .evmAddress:
            return "EVM Address"
        case .evmAddressHardware:
            return "EVM Address Hardware"
        case .tronAddress:
            return "TRON Address"
        case .tronAddressHardware:
            return "TRON Address Hardware"
        case let .hdExtendedKey(key):
            switch key {
            case .private:
                switch key.derivedType {
                case .master: return "BIP32 Root Key"
                case .account: return "Account xPrivKey"
                default: return ""
                }
            case .public:
                switch key.derivedType {
                case .account: return "Account xPubKey"
                default: return ""
                }
            }
        case let .hdExtendedKeyHardware(key):
            switch key {
            case .public:
                switch key.derivedType {
                case .account: return "Account xPubKey Hardware"
                default: return ""
                }
            default:
                return ""
            }
        case let .cex(cexAccount):
            return cexAccount.cex.title
        }
    }

    var detailedDescription: String {
        switch self {
        case .evmAddress(let address), .evmAddressHardware(let address):
            return address.eip55.shortened
        case .tronAddress(let address), .tronAddressHardware(let address):
            return address.base58.shortened
        default: return description
        }
    }

    func evmAddress(chain: Chain) -> EvmKit.Address? {
        switch self {
        case .mnemonic:
            guard let mnemonicSeed else {
                return nil
            }

            return try? Signer.address(seed: mnemonicSeed, chain: chain)
        case let .evmPrivateKey(data):
            return Signer.address(privateKey: data)
        case let .evmAddressHardware(address):
            return address
        default:
            return nil
        }
    }

    func sign(message: Data, isLegacy: Bool = false) -> Data? {
        switch self {
        case .mnemonic:
            guard let mnemonicSeed else {
                return nil
            }

            guard let privateKey = try? Signer.privateKey(seed: mnemonicSeed, chain: App.shared.evmBlockchainManager.chain(blockchainType: .ethereum)) else {
                return nil
            }

            return try? EvmKit.Kit.sign(message: message, privateKey: privateKey, isLegacy: isLegacy)
        case let .evmPrivateKey(data):
            return try? EvmKit.Kit.sign(message: message, privateKey: data, isLegacy: isLegacy)
        default:
            return nil
        }
    }
}

extension AccountType {
    private static func split(_ string: String, separator: String) -> (String, String) {
        if let index = string.firstIndex(of: Character(separator)) {
            let left = String(string.prefix(upTo: index))
            let right = String(string.suffix(from: string.index(after: index)))
            return (left, right)
        }

        return (string, "")
    }

    static func decode(uniqueId: Data, type: Abstract) -> AccountType? {
        let string = String(decoding: uniqueId, as: UTF8.self)

        switch type {
        case .mnemonic:
            let (wordsWithCompliant, salt) = split(string, separator: "@")
            let (wordList, bip39CompliantString) = split(wordsWithCompliant, separator: "&")
            let words = wordList.split(separator: " ").map(String.init)

            let bip39Compliant = bip39CompliantString.isEmpty
            return AccountType.mnemonic(words: words, salt: salt, bip39Compliant: bip39Compliant)
        case .evmPrivateKey:
            return AccountType.evmPrivateKey(data: uniqueId)
        case .hdExtendedKey:
            do {
                return try AccountType.hdExtendedKey(key: HDExtendedKey(data: uniqueId))
            } catch {
                return nil
            }
        case .hdExtendedKeyHardware:
            do {
                return try AccountType.hdExtendedKeyHardware(key: HDExtendedKey(data: uniqueId))
            } catch {
                return nil
            }
        case .evmAddress:
            return (try? EvmKit.Address(hex: string)).map { AccountType.evmAddress(address: $0) }
        case .evmAddressHardware:
            return (try? EvmKit.Address(hex: string)).map { AccountType.evmAddressHardware(address: $0) }
        case .tronAddress:
            return (try? TronKit.Address(address: string)).map { AccountType.tronAddress(address: $0) }
        case .tronAddressHardware:
            return (try? TronKit.Address(address: string)).map { AccountType.tronAddressHardware(address: $0) }
        case .cex:
            guard let cexAccount = CexAccount.decode(uniqueId: string) else {
                return nil
            }

            return .cex(cexAccount: cexAccount)
        }
    }

    enum Abstract: String, Codable {
        case mnemonic
        case evmPrivateKey = "private_key"
        case evmAddress = "evm_address"
        case evmAddressHardware = "evm_address_hardware"
        case tronAddress = "tron_address"
        case tronAddressHardware = "tron_address_hardware"
        case hdExtendedKey = "hd_extended_key"
        case hdExtendedKeyHardware = "hd_extended_key_hardware"
        case cex

        init(_ type: AccountType) {
            switch type {
            case .mnemonic: self = .mnemonic
            case .evmPrivateKey: self = .evmPrivateKey
            case .evmAddress: self = .evmAddress
            case .evmAddressHardware: self = .evmAddressHardware
            case .tronAddress: self = .tronAddress
            case .tronAddressHardware: self = .tronAddressHardware
            case .hdExtendedKey: self = .hdExtendedKey
            case .hdExtendedKeyHardware: self = .hdExtendedKeyHardware
            case .cex: self = .cex
            }
        }

        var isWatch: Bool {
            switch self {
            case .evmAddress, .tronAddress: return true
            default: return false
            }
        }
    }
}

extension AccountType: Hashable {
    public static func == (lhs: AccountType, rhs: AccountType) -> Bool {
        switch (lhs, rhs) {
        case (let .mnemonic(lhsWords, lhsSalt, lhsBip39Compliant), let .mnemonic(rhsWords, rhsSalt, rhsBip39Compliant)):
            return lhsWords == rhsWords && lhsSalt == rhsSalt && lhsBip39Compliant == rhsBip39Compliant
        case let (.evmPrivateKey(lhsData), .evmPrivateKey(rhsData)):
            return lhsData == rhsData
        case let (.evmAddress(lhsAddress), .evmAddress(rhsAddress)):
            return lhsAddress == rhsAddress
        case let (.evmAddressHardware(lhsAddress), .evmAddressHardware(rhsAddress)):
            return lhsAddress == rhsAddress
        case let (.tronAddress(lhsAddress), .tronAddress(rhsAddress)):
            return lhsAddress == rhsAddress
        case let (.tronAddressHardware(lhsAddress), .tronAddressHardware(rhsAddress)):
            return lhsAddress == rhsAddress
        case let (.hdExtendedKey(lhsKey), .hdExtendedKey(rhsKey)):
            return lhsKey == rhsKey
        case let (.hdExtendedKeyHardware(lhsKey), .hdExtendedKeyHardware(rhsKey)):
            return lhsKey == rhsKey
        case let (.cex(lhsCexAccount), .cex(rhsCexAccount)):
            return lhsCexAccount == rhsCexAccount
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .mnemonic(words, salt, bip39Compliant):
            hasher.combine("mnemonic")
            hasher.combine(words)
            hasher.combine(salt)
            hasher.combine(bip39Compliant)
        case let .evmPrivateKey(data):
            hasher.combine("evmPrivateKey")
            hasher.combine(data)
        case let .evmAddress(address):
            hasher.combine("evmAddress")
            hasher.combine(address.raw)
        case let .evmAddressHardware(address):
            hasher.combine("evmAddressHardware")
            hasher.combine(address.raw)
        case let .tronAddress(address):
            hasher.combine("tronAddress")
            hasher.combine(address.raw)
        case let .tronAddressHardware(address):
            hasher.combine("tronAddressHardware")
            hasher.combine(address.raw)
        case let .hdExtendedKey(key):
            hasher.combine("hdExtendedKey")
            hasher.combine(key)
        case let .hdExtendedKeyHardware(key):
            hasher.combine("hdExtendedKeyHardware")
            hasher.combine(key)
        case let .cex(cexAccount):
            hasher.combine("cex")
            hasher.combine(cexAccount)
        }
    }
}

extension AccountType {
    static func decrypt(crypto: BackupCrypto, type: AccountType.Abstract, passphrase: String) throws -> AccountType {
        let data = try crypto.decrypt(passphrase: passphrase)

        guard let accountType = AccountType.decode(uniqueId: data, type: type) else {
            throw RestoreCloudModule.RestoreError.invalidBackup
        }

        return accountType
    }
}
