//
//  SolanaTransactionRecord.swift
//  UnstoppableWallet
//
//  Created by arsenal on 20.10.25.
//  Copyright © 2025 Horizontal Systems. All rights reserved.
//

import Foundation
import SolanaKit
import MarketKit

class SolanaTransactionRecord: TransactionRecord {
    let signature: String
    let slot: Int?
    let flow: String
    let activityType: SolanaKit.ActivityType
    let token: Token
    let from_address: String
    let to_address: String
    let amount: Decimal
    
    init(source: TransactionSource, transfer: AccountTransfer, token: Token) {
        signature = transfer.trans_id
        slot = transfer.block_id
        flow = transfer.flow
        activityType = transfer.activity_type
        self.token = token
        self.from_address = transfer.from_address
        self.to_address = transfer.to_address
        self.amount = Decimal(sign: flow == "in" ? .plus : .minus, exponent: -token.decimals, significand: Decimal(transfer.amount))
        
        super.init(
            source: source,
            uid: transfer.trans_id,
            transactionHash: transfer.trans_id,
            transactionIndex: 0,
            blockHeight: transfer.block_id,
            confirmationsThreshold: 1,
            date: Date(timeIntervalSince1970: TimeInterval(transfer.block_time)),
            failed: false
        )
    }
    
    override func status(lastBlockHeight: Int?) -> TransactionStatus {
        if failed {
            return .failed
        } else {
            return .completed
        }
    }
}
