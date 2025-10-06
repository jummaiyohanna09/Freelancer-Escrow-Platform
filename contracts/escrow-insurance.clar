(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u401))
(define-constant ERR_CLAIM_EXISTS (err u402))
(define-constant ERR_INVALID_AMOUNT (err u403))
(define-constant ERR_CLAIM_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_RESOLVED (err u405))

(define-constant COVERAGE_RATIO u200)
(define-constant MIN_CONTRIBUTION u1000000)

(define-data-var total-pool uint u0)
(define-data-var claim-counter uint u0)

(define-map participant-coverage
  principal
  {
    contributed: uint,
    max-coverage: uint,
    active-claims: uint,
    last-contribution: uint
  }
)

(define-map insurance-claims
  uint
  {
    claimant: principal,
    project-id: uint,
    amount-requested: uint,
    amount-approved: uint,
    reason: (string-ascii 300),
    status: uint,
    filed-at: uint,
    resolved-at: (optional uint)
  }
)

(define-public (contribute-to-pool (amount uint))
  (let
    (
      (current-coverage (default-to 
        {contributed: u0, max-coverage: u0, active-claims: u0, last-contribution: u0}
        (map-get? participant-coverage tx-sender)))
      (new-max-coverage (* amount COVERAGE_RATIO))
    )
    (asserts! (>= amount MIN_CONTRIBUTION) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set participant-coverage tx-sender
      {
        contributed: (+ (get contributed current-coverage) amount),
        max-coverage: (+ (get max-coverage current-coverage) new-max-coverage),
        active-claims: (get active-claims current-coverage),
        last-contribution: stacks-block-height
      }
    )
    
    (var-set total-pool (+ (var-get total-pool) amount))
    (ok new-max-coverage)
  )
)

(define-public (file-insurance-claim (project-id uint) (amount uint) (reason (string-ascii 300)))
  (let
    (
      (coverage (unwrap! (map-get? participant-coverage tx-sender) ERR_NOT_AUTHORIZED))
      (claim-id (+ (var-get claim-counter) u1))
      (available-coverage (- (get max-coverage coverage) (* (get active-claims coverage) amount)))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount available-coverage) ERR_INSUFFICIENT_COVERAGE)
    
    (map-set insurance-claims claim-id
      {
        claimant: tx-sender,
        project-id: project-id,
        amount-requested: amount,
        amount-approved: u0,
        reason: reason,
        status: u0,
        filed-at: stacks-block-height,
        resolved-at: none
      }
    )
    
    (map-set participant-coverage tx-sender
      (merge coverage {active-claims: (+ (get active-claims coverage) u1)})
    )
    
    (var-set claim-counter claim-id)
    (ok claim-id)
  )
)

(define-public (resolve-claim (claim-id uint) (approved-amount uint))
  (let
    (
      (claim (unwrap! (map-get? insurance-claims claim-id) ERR_CLAIM_NOT_FOUND))
      (coverage (unwrap! (map-get? participant-coverage (get claimant claim)) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get status claim) u0) ERR_ALREADY_RESOLVED)
    (asserts! (<= approved-amount (get amount-requested claim)) ERR_INVALID_AMOUNT)
    
    (if (> approved-amount u0)
      (try! (as-contract (stx-transfer? approved-amount tx-sender (get claimant claim))))
      true
    )
    
    (map-set insurance-claims claim-id
      (merge claim
        {
          amount-approved: approved-amount,
          status: (if (> approved-amount u0) u1 u2),
          resolved-at: (some stacks-block-height)
        }
      )
    )
    
    (map-set participant-coverage (get claimant claim)
      (merge coverage {active-claims: (- (get active-claims coverage) u1)})
    )
    
    (ok approved-amount)
  )
)

(define-read-only (get-participant-coverage (participant principal))
  (map-get? participant-coverage participant)
)

(define-read-only (get-insurance-claim (claim-id uint))
  (map-get? insurance-claims claim-id)
)

(define-read-only (get-total-pool)
  (ok (var-get total-pool))
)

(define-read-only (get-available-coverage (participant principal))
  (match (map-get? participant-coverage participant)
    coverage (ok (- (get max-coverage coverage) 
                   (* (get active-claims coverage) u1000000)))
    (ok u0)
  )
)