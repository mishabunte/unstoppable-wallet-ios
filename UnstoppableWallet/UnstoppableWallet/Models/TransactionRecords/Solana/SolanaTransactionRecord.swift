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
    
    init(source: TransactionSource, transfer: AccountTransfer, token: Token) {
        signature = transfer.trans_id
        slot = transfer.block_id
        
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
}
