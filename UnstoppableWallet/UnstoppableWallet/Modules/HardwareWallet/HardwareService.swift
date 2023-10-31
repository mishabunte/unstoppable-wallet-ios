import Foundation

class HardwareService {
    private let accountFactory: AccountFactory

    private(set) var name: String?

    init(accountFactory: AccountFactory) {
        self.accountFactory = accountFactory
    }

}

extension HardwareService {

    var defaultAccountName: String {
        accountFactory.nextHardwareAccountName
    }

    var resolvedName: String {
        let trimmedName = (name ?? defaultAccountName).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName
    }

    func set(name: String) {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.name = nil
        } else {
            self.name = name
        }
    }

}

