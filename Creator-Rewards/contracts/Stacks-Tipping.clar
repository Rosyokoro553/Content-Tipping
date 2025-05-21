;; CreatorTip: A Decentralized Content Creator Tipping Platform

;; This smart contract enables a decentralized tipping system for content creators,
;; allowing fans to financially support their favorite creators while maintaining
;; transparent fund management, flexible fee structures, and secure withdrawals.

;; Error Constants

(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-TIP-AMOUNT (err u101))
(define-constant ERR-CONTENT-NOT-FOUND (err u102))
(define-constant ERR-CONTENT-ALREADY-EXISTS (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-INVALID-PARAMETER-VALUE (err u106))
(define-constant ERR-CONTRACT-IS-PAUSED (err u107))
(define-constant ERR-ZERO-AMOUNT-TRANSFER (err u108))
(define-constant ERR-CONTENT-INACTIVE (err u109))

;; Contract State Variables

;; Administrative controls
(define-data-var contract-admin principal tx-sender)
(define-data-var platform-fee-percentage uint u250) ;; In basis points (2.5%)
(define-data-var emergency-pause-active bool false)

;; Platform financials
(define-data-var platform-revenue uint u0)

;; Data Structures

;; Content registry - stores all creator content information
(define-map content-registry
  { content-identifier: (string-ascii 64) }
  {
    content-owner: principal,
    content-title: (string-ascii 256),
    content-details: (string-utf8 1024),
    publication-block: uint,
    lifetime-tip-amount: uint,
    tip-transaction-count: uint,
    content-status-active: bool
  }
)

;; Tip history - records all tips made to specific content
(define-map tip-history
  { content-identifier: (string-ascii 64), tip-sender: principal }
  {
    tip-amount: uint,
    tip-block-height: uint,
    tip-message: (optional (string-utf8 280))
  }
)

;; Creator earnings - tracks withdrawable funds for each creator
(define-map creator-earnings
  { creator-address: principal }
  { available-balance: uint }
)

;; Private Helper Functions

;; Check if caller is the contract administrator
(define-private (caller-is-admin)
  (is-eq tx-sender (var-get contract-admin))
)

;; Check if contract operations are currently allowed
(define-private (contract-operations-allowed)
  (not (var-get emergency-pause-active))
)

;; Verify administrative access and contract operational status
(define-private (validate-admin-access)
  (begin
    (asserts! (caller-is-admin) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (contract-operations-allowed) ERR-CONTRACT-IS-PAUSED)
    (ok true)
  )
)

;; Calculate platform fee from tip amount
(define-private (calculate-platform-fee (tip-amount uint))
  (/ (* tip-amount (var-get platform-fee-percentage)) u10000)
)

;; Calculate creator's share from tip amount
(define-private (calculate-creator-share (tip-amount uint))
  (- tip-amount (calculate-platform-fee tip-amount))
)

;; Update creator's available balance with new earnings
(define-private (add-to-creator-balance (creator-address principal) (amount-to-add uint))
  (let (
    (current-balance (default-to { available-balance: u0 } 
                      (map-get? creator-earnings { creator-address: creator-address })))
  )
    (map-set creator-earnings
      { creator-address: creator-address }
      { available-balance: (+ (get available-balance current-balance) amount-to-add) }
    )
  )
)

;; Update content tipping statistics
(define-private (update-content-tip-stats 
  (content-identifier (string-ascii 64)) 
  (tip-amount uint)
)
  (let (
    (content-data (unwrap! (map-get? content-registry { content-identifier: content-identifier }) 
                           ERR-CONTENT-NOT-FOUND))
  )
    (map-set content-registry
      { content-identifier: content-identifier }
      (merge content-data {
        lifetime-tip-amount: (+ (get lifetime-tip-amount content-data) tip-amount),
        tip-transaction-count: (+ (get tip-transaction-count content-data) u1)
      })
    )
  )
)

;; Administrative Functions

;; Transfer contract administration to a new address
(define-public (transfer-admin-rights (new-admin-address principal))
  (begin
    (asserts! (caller-is-admin) ERR-UNAUTHORIZED-ACCESS)
    (ok (var-set contract-admin new-admin-address))
  )
)

;; Update platform fee percentage (in basis points)
(define-public (update-platform-fee (new-fee-percentage uint))
  (begin
    (asserts! (caller-is-admin) ERR-UNAUTHORIZED-ACCESS)
    ;; Limit fee to maximum 10% (1000 basis points)
    (asserts! (<= new-fee-percentage u1000) ERR-INVALID-PARAMETER-VALUE)
    (ok (var-set platform-fee-percentage new-fee-percentage))
  )
)

;; Toggle emergency pause status
(define-public (toggle-emergency-pause (pause-status bool))
  (begin
    (asserts! (caller-is-admin) ERR-UNAUTHORIZED-ACCESS)
    (ok (var-set emergency-pause-active pause-status))
  )
)

;; Withdraw accumulated platform fees to specified address
(define-public (withdraw-platform-revenue (recipient-address principal))
  (let (
    (withdrawal-amount (var-get platform-revenue))
  )
    (begin
      ;; Check authorization
      (asserts! (caller-is-admin) ERR-UNAUTHORIZED-ACCESS)
      
      ;; Ensure non-zero withdrawal
      (asserts! (> withdrawal-amount u0) ERR-INSUFFICIENT-BALANCE)
      
      ;; Execute transfer
      (asserts! (is-ok (as-contract (stx-transfer? withdrawal-amount tx-sender recipient-address))) 
                ERR-TRANSFER-FAILED)
      
      ;; Reset platform revenue counter
      (var-set platform-revenue u0)
      
      (ok withdrawal-amount)
    )
  )
)

;; Content Management Functions

;; Register new content in the system
(define-public (publish-new-content 
  (content-identifier (string-ascii 64))
  (content-title (string-ascii 256))
  (content-details (string-utf8 1024))
)
  (begin
    ;; Verify contract is active
    (asserts! (contract-operations-allowed) ERR-CONTRACT-IS-PAUSED)
    
    ;; Check if content ID is unique
    (asserts! (is-none (map-get? content-registry { content-identifier: content-identifier })) 
              ERR-CONTENT-ALREADY-EXISTS)
    
    ;; Create new content entry
    (map-set content-registry
      { content-identifier: content-identifier }
      {
        content-owner: tx-sender,
        content-title: content-title,
        content-details: content-details,
        publication-block: block-height,
        lifetime-tip-amount: u0,
        tip-transaction-count: u0,
        content-status-active: true
      }
    )
    (ok true)
  )
)

;; Update existing content information
(define-public (update-content-details
  (content-identifier (string-ascii 64))
  (content-title (string-ascii 256))
  (content-details (string-utf8 1024))
  (content-status-active bool)
)
  (let (
    (content-data (unwrap! (map-get? content-registry { content-identifier: content-identifier }) 
                           ERR-CONTENT-NOT-FOUND))
  )
    (begin
      ;; Verify contract is active
      (asserts! (contract-operations-allowed) ERR-CONTRACT-IS-PAUSED)
      
      ;; Verify content ownership
      (asserts! (is-eq tx-sender (get content-owner content-data)) ERR-UNAUTHORIZED-ACCESS)
      
      ;; Update content details
      (map-set content-registry
        { content-identifier: content-identifier }
        (merge content-data {
          content-title: content-title,
          content-details: content-details,
          content-status-active: content-status-active
        })
      )
      (ok true)
    )
  )
)

;; Tipping Functions

;; Send a tip to content creator
(define-public (send-tip-to-creator
  (content-identifier (string-ascii 64))
  (tip-amount uint)
  (tip-message (optional (string-utf8 280)))
)
  (let (
    (content-data (unwrap! (map-get? content-registry { content-identifier: content-identifier }) 
                           ERR-CONTENT-NOT-FOUND))
    (content-owner (get content-owner content-data))
    (platform-fee (calculate-platform-fee tip-amount))
    (creator-share (calculate-creator-share tip-amount))
  )
    (begin
      ;; Check contract is active
      (asserts! (contract-operations-allowed) ERR-CONTRACT-IS-PAUSED)
      
      ;; Check content is active
      (asserts! (get content-status-active content-data) ERR-CONTENT-INACTIVE)
      
      ;; Validate tip amount
      (asserts! (> tip-amount u0) ERR-ZERO-AMOUNT-TRANSFER)
      (asserts! (> creator-share u0) ERR-INVALID-TIP-AMOUNT)
      
      ;; Transfer funds from sender to contract
      (asserts! (is-ok (stx-transfer? tip-amount tx-sender (as-contract tx-sender))) 
                ERR-TRANSFER-FAILED)
      
      ;; Update platform revenue
      (var-set platform-revenue (+ (var-get platform-revenue) platform-fee))
      
      ;; Update creator balance
      (add-to-creator-balance content-owner creator-share)
      
      ;; Record tip details
      (map-set tip-history
        { content-identifier: content-identifier, tip-sender: tx-sender }
        {
          tip-amount: tip-amount,
          tip-block-height: block-height,
          tip-message: tip-message
        }
      )
      
      ;; Update content statistics
      (update-content-tip-stats content-identifier tip-amount)
      
      (ok true)
    )
  )
)

;; Fund Withdrawal Functions

;; Creator withdraws accumulated earnings
(define-public (withdraw-creator-earnings)
  (let (
    (creator-data (default-to { available-balance: u0 } 
                  (map-get? creator-earnings { creator-address: tx-sender })))
    (withdrawal-amount (get available-balance creator-data))
  )
    (begin
      ;; Check contract is active
      (asserts! (contract-operations-allowed) ERR-CONTRACT-IS-PAUSED)
      
      ;; Ensure non-zero withdrawal
      (asserts! (> withdrawal-amount u0) ERR-INSUFFICIENT-BALANCE)
      
      ;; Execute transfer
      (asserts! (is-ok (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender))) 
                ERR-TRANSFER-FAILED)
      
      ;; Reset creator balance
      (map-set creator-earnings
        { creator-address: tx-sender }
        { available-balance: u0 }
      )
      
      (ok withdrawal-amount)
    )
  )
)

;; Read-only Functions

;; Get content details by ID
(define-read-only (get-content-details (content-identifier (string-ascii 64)))
  (map-get? content-registry { content-identifier: content-identifier })
)

;; Get tip information for a specific user and content
(define-read-only (get-tip-details (content-identifier (string-ascii 64)) (tip-sender principal))
  (map-get? tip-history { content-identifier: content-identifier, tip-sender: tip-sender })
)

;; Get creator's current balance
(define-read-only (get-creator-available-balance (creator-address principal))
  (default-to { available-balance: u0 } 
              (map-get? creator-earnings { creator-address: creator-address }))
)

;; Get current platform fee percentage
(define-read-only (get-current-platform-fee)
  (var-get platform-fee-percentage)
)

;; Get accumulated platform revenue
(define-read-only (get-platform-revenue)
  (var-get platform-revenue)
)

;; Check if contract is currently paused
(define-read-only (is-contract-paused)
  (var-get emergency-pause-active)
)

;; Check who is the current contract administrator
(define-read-only (get-contract-admin)
  (var-get contract-admin)
)

;; Calculate fee breakdown for a potential tip
(define-read-only (calculate-tip-breakdown (tip-amount uint))
  (let (
    (platform-fee (calculate-platform-fee tip-amount))
    (creator-share (calculate-creator-share tip-amount))
  )
    {
      proposed-tip-amount: tip-amount,
      platform-fee-amount: platform-fee,
      creator-share-amount: creator-share
    }
  )
)

;; Contract Initialization
(begin
  (var-set contract-admin tx-sender)
  (var-set platform-fee-percentage u250)  ;; 2.5% default fee
  (var-set emergency-pause-active false)
)