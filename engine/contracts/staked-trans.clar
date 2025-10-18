;; SkillTix Staked Transaction Contract
;; Holds staked funds from both parties until mutual approval


;; CONSTANTS & ERRORS

(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u403))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_ALREADY_STAKED (err u401))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))



;; DATA STRUCTURES
;; Staked transactions
(define-map staked-txns
  uint
  {
    match-id: uint,
    provider: principal,
    requester: principal,
    stake-amount: uint,
    provider-approved: bool,
    requester-approved: bool,
    status: (string-ascii 16)
  })

;; Track stakes per user
(define-map user-stakes
  principal
  uint)


;; DATA VARIABLES

(define-data-var next-stake-id uint u1)
(define-data-var minimum-stake uint u1000000)


;; PUBLIC FUNCTIONS

;; Create staked transaction with both parties staking
(define-public (create-staked-txn (match-id uint) (provider principal) (requester principal) (stake-amount uint))
  (let ((stake-id (var-get next-stake-id)))
    (asserts! (> stake-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= stake-amount (var-get minimum-stake)) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set staked-txns stake-id {
      match-id: match-id,
      provider: provider,
      requester: requester,
      stake-amount: stake-amount,
      provider-approved: false,
      requester-approved: false,
      status: "pending"
    })
    
    (var-set next-stake-id (+ stake-id u1))
    (ok stake-id)))

;; Provider approves transaction
(define-public (provider-approve (stake-id uint))
  (let ((stake-txn (unwrap! (map-get? staked-txns stake-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get provider stake-txn)) ERR_UNAUTHORIZED)
    (map-set staked-txns stake-id (merge stake-txn {provider-approved: true}))
    (ok true)))

;; Requester approves transaction
(define-public (requester-approve (stake-id uint))
  (let ((stake-txn (unwrap! (map-get? staked-txns stake-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get requester stake-txn)) ERR_UNAUTHORIZED)
    (map-set staked-txns stake-id (merge stake-txn {requester-approved: true}))
    (ok true)))

;; Release funds after mutual approval
(define-public (release-funds (stake-id uint))
  (let ((stake-txn (unwrap! (map-get? staked-txns stake-id) ERR_NOT_FOUND)))
    (asserts! (and (get provider-approved stake-txn) (get requester-approved stake-txn)) ERR_UNAUTHORIZED)
    
    (try! (stx-transfer? (get stake-amount stake-txn) (as-contract tx-sender) (get provider stake-txn)))
    (try! (stx-transfer? (get stake-amount stake-txn) (as-contract tx-sender) (get requester stake-txn)))
    
    (map-set staked-txns stake-id (merge stake-txn {status: "completed"}))
    (ok true)))

;; Cancel and refund stakes
(define-public (cancel-stake (stake-id uint))
  (let ((stake-txn (unwrap! (map-get? staked-txns stake-id) ERR_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get provider stake-txn)) (is-eq tx-sender (get requester stake-txn))) ERR_UNAUTHORIZED)
    
    (try! (stx-transfer? (get stake-amount stake-txn) (as-contract tx-sender) (get provider stake-txn)))
    (try! (stx-transfer? (get stake-amount stake-txn) (as-contract tx-sender) (get requester stake-txn)))
    
    (map-set staked-txns stake-id (merge stake-txn {status: "cancelled"}))
    (ok true)))


;; READ-ONLY FUNCTIONS

(define-read-only (get-staked-txn (stake-id uint))
  (map-get? staked-txns stake-id))

(define-read-only (get-minimum-stake)
  (var-get minimum-stake))