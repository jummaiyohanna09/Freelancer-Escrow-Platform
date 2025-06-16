(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROJECT_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATUS (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_MILESTONE_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_EXISTS (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_DISPUTE_ACTIVE (err u107))

(define-constant STATUS_CREATED u0)
(define-constant STATUS_FUNDED u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)
(define-constant STATUS_DISPUTED u5)

(define-constant MILESTONE_PENDING u0)
(define-constant MILESTONE_SUBMITTED u1)
(define-constant MILESTONE_APPROVED u2)
(define-constant MILESTONE_REJECTED u3)

(define-data-var project-counter uint u0)
(define-data-var milestone-counter uint u0)

(define-map projects
  uint
  {
    client: principal,
    freelancer: principal,
    total-amount: uint,
    status: uint,
    created-at: uint,
    title: (string-ascii 100)
  }
)

(define-map milestones
  uint
  {
    project-id: uint,
    amount: uint,
    status: uint,
    description: (string-ascii 200),
    submitted-at: (optional uint),
    approved-at: (optional uint)
  }
)

(define-map project-milestones
  uint
  (list 20 uint)
)

(define-map project-funds
  uint
  uint
)

(define-map disputes
  uint
  {
    raised-by: principal,
    reason: (string-ascii 300),
    created-at: uint,
    resolved: bool
  }
)

(define-public (create-project (freelancer principal) (total-amount uint) (title (string-ascii 100)))
  (let
    (
      (project-id (+ (var-get project-counter) u1))
    )
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq tx-sender freelancer)) ERR_NOT_AUTHORIZED)
    
    (map-set projects project-id
      {
        client: tx-sender,
        freelancer: freelancer,
        total-amount: total-amount,
        status: STATUS_CREATED,
        created-at: stacks-block-height,
        title: title
      }
    )
    
    (map-set project-milestones project-id (list))
    (var-set project-counter project-id)
    (ok project-id)
  )
)

(define-public (fund-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get client project)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status project) STATUS_CREATED) ERR_INVALID_STATUS)
    
    (try! (stx-transfer? (get total-amount project) tx-sender (as-contract tx-sender)))
    
    (map-set projects project-id
      (merge project { status: STATUS_FUNDED })
    )
    
    (map-set project-funds project-id (get total-amount project))
    (ok true)
  )
)

(define-public (add-milestone (project-id uint) (amount uint) (description (string-ascii 200)))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (milestone-id (+ (var-get milestone-counter) u1))
      (current-milestones (default-to (list) (map-get? project-milestones project-id)))
    )
    (asserts! (is-eq tx-sender (get client project)) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (or (is-eq (get status project) STATUS_CREATED) (is-eq (get status project) STATUS_FUNDED)) ERR_INVALID_STATUS)
    
    (map-set milestones milestone-id
      {
        project-id: project-id,
        amount: amount,
        status: MILESTONE_PENDING,
        description: description,
        submitted-at: none,
        approved-at: none
      }
    )
    
    (map-set project-milestones project-id
      (unwrap! (as-max-len? (append current-milestones milestone-id) u20) ERR_ALREADY_EXISTS)
    )
    
    (var-set milestone-counter milestone-id)
    (ok milestone-id)
  )
)

(define-public (start-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get freelancer project)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status project) STATUS_FUNDED) ERR_INVALID_STATUS)
    
    (map-set projects project-id
      (merge project { status: STATUS_IN_PROGRESS })
    )
    (ok true)
  )
)

(define-public (submit-milestone (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
      (project (unwrap! (map-get? projects (get project-id milestone)) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get freelancer project)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status milestone) MILESTONE_PENDING) ERR_INVALID_STATUS)
    (asserts! (is-eq (get status project) STATUS_IN_PROGRESS) ERR_INVALID_STATUS)
    
    (map-set milestones milestone-id
      (merge milestone 
        { 
          status: MILESTONE_SUBMITTED,
          submitted-at: (some stacks-block-height)
        }
      )
    )
    (ok true)
  )
)

(define-public (approve-milestone (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
      (project (unwrap! (map-get? projects (get project-id milestone)) ERR_PROJECT_NOT_FOUND))
      (current-funds (default-to u0 (map-get? project-funds (get project-id milestone))))
    )
    (asserts! (is-eq tx-sender (get client project)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status milestone) MILESTONE_SUBMITTED) ERR_INVALID_STATUS)
    (asserts! (>= current-funds (get amount milestone)) ERR_INSUFFICIENT_FUNDS)
    
    (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get freelancer project))))
    
    (map-set milestones milestone-id
      (merge milestone 
        { 
          status: MILESTONE_APPROVED,
          approved-at: (some stacks-block-height)
        }
      )
    )
    
    (map-set project-funds (get project-id milestone) (- current-funds (get amount milestone)))
    (ok true)
  )
)

(define-public (reject-milestone (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
      (project (unwrap! (map-get? projects (get project-id milestone)) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get client project)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status milestone) MILESTONE_SUBMITTED) ERR_INVALID_STATUS)
    
    (map-set milestones milestone-id
      (merge milestone { status: MILESTONE_REJECTED })
    )
    (ok true)
  )
)

(define-public (raise-dispute (project-id uint) (reason (string-ascii 300)))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get client project)) (is-eq tx-sender (get freelancer project))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status project) STATUS_IN_PROGRESS) ERR_INVALID_STATUS)
    
    (map-set disputes project-id
      {
        raised-by: tx-sender,
        reason: reason,
        created-at: stacks-block-height,
        resolved: false
      }
    )
    
    (map-set projects project-id
      (merge project { status: STATUS_DISPUTED })
    )
    (ok true)
  )
)

(define-public (resolve-dispute (project-id uint) (favor-client bool))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (dispute (unwrap! (map-get? disputes project-id) ERR_PROJECT_NOT_FOUND))
      (remaining-funds (default-to u0 (map-get? project-funds project-id)))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status project) STATUS_DISPUTED) ERR_INVALID_STATUS)
    (asserts! (not (get resolved dispute)) ERR_INVALID_STATUS)
    
    (if favor-client
      (try! (as-contract (stx-transfer? remaining-funds tx-sender (get client project))))
      (try! (as-contract (stx-transfer? remaining-funds tx-sender (get freelancer project))))
    )
    
    (map-set disputes project-id
      (merge dispute { resolved: true })
    )
    
    (map-set projects project-id
      (merge project { status: STATUS_COMPLETED })
    )
    
    (map-set project-funds project-id u0)
    (ok true)
  )
)

(define-public (cancel-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
      (remaining-funds (default-to u0 (map-get? project-funds project-id)))
    )
    (asserts! (is-eq tx-sender (get client project)) ERR_NOT_AUTHORIZED)
    (asserts! (or (is-eq (get status project) STATUS_CREATED) (is-eq (get status project) STATUS_FUNDED)) ERR_INVALID_STATUS)
    
    (if (> remaining-funds u0)
      (try! (as-contract (stx-transfer? remaining-funds tx-sender (get client project))))
      true
    )
    
    (map-set projects project-id
      (merge project { status: STATUS_CANCELLED })
    )
    
    (map-set project-funds project-id u0)
    (ok true)
  )
)

(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones milestone-id)
)

(define-read-only (get-project-milestones (project-id uint))
  (map-get? project-milestones project-id)
)

(define-read-only (get-project-funds (project-id uint))
  (map-get? project-funds project-id)
)

(define-read-only (get-dispute (project-id uint))
  (map-get? disputes project-id)
)

(define-read-only (get-project-counter)
  (var-get project-counter)
)

(define-read-only (get-milestone-counter)
  (var-get milestone-counter)
)
