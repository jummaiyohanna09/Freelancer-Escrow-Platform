(define-constant ERR_DEADLINE_NOT_FOUND (err u300))
(define-constant ERR_DEADLINE_EXISTS (err u301))
(define-constant ERR_INVALID_DEADLINE (err u302))
(define-constant ERR_DEADLINE_PASSED (err u303))

(define-map milestone-deadlines
  uint
  {
    milestone-id: uint,
    deadline-block: uint,
    buffer-blocks: uint,
    penalty-rate: uint,
    created-at: uint
  }
)

(define-map deadline-status
  uint
  {
    is-overdue: bool,
    penalty-applied: bool,
    extension-count: uint,
    last-updated: uint
  }
)

(define-public (set-milestone-deadline 
  (milestone-id uint) 
  (deadline-blocks uint) 
  (buffer-blocks uint) 
  (penalty-rate uint))
  (let
    (
      (deadline-block (+ stacks-block-height deadline-blocks))
    )
    (asserts! (> deadline-blocks u0) ERR_INVALID_DEADLINE)
    (asserts! (<= penalty-rate u50) ERR_INVALID_DEADLINE)
    (asserts! (is-none (map-get? milestone-deadlines milestone-id)) ERR_DEADLINE_EXISTS)
    
    (map-set milestone-deadlines milestone-id
      {
        milestone-id: milestone-id,
        deadline-block: deadline-block,
        buffer-blocks: buffer-blocks,
        penalty-rate: penalty-rate,
        created-at: stacks-block-height
      }
    )
    
    (map-set deadline-status milestone-id
      {
        is-overdue: false,
        penalty-applied: false,
        extension-count: u0,
        last-updated: stacks-block-height
      }
    )
    (ok deadline-block)
  )
)

(define-public (extend-milestone-deadline (milestone-id uint) (additional-blocks uint))
  (let
    (
      (deadline (unwrap! (map-get? milestone-deadlines milestone-id) ERR_DEADLINE_NOT_FOUND))
      (status (unwrap! (map-get? deadline-status milestone-id) ERR_DEADLINE_NOT_FOUND))
      (new-deadline (+ (get deadline-block deadline) additional-blocks))
    )
    (asserts! (> additional-blocks u0) ERR_INVALID_DEADLINE)
    (asserts! (< (get extension-count status) u3) ERR_INVALID_DEADLINE)
    
    (map-set milestone-deadlines milestone-id
      (merge deadline { deadline-block: new-deadline })
    )
    
    (map-set deadline-status milestone-id
      (merge status 
        {
          extension-count: (+ (get extension-count status) u1),
          last-updated: stacks-block-height
        }
      )
    )
    (ok new-deadline)
  )
)

(define-public (check-deadline-status (milestone-id uint))
  (let
    (
      (deadline (unwrap! (map-get? milestone-deadlines milestone-id) ERR_DEADLINE_NOT_FOUND))
      (status (unwrap! (map-get? deadline-status milestone-id) ERR_DEADLINE_NOT_FOUND))
      (current-block stacks-block-height)
      (deadline-with-buffer (+ (get deadline-block deadline) (get buffer-blocks deadline)))
      (is-overdue (> current-block deadline-with-buffer))
    )
    (if (and is-overdue (not (get is-overdue status)))
      (map-set deadline-status milestone-id
        (merge status 
          {
            is-overdue: true,
            last-updated: current-block
          }
        )
      )
      true
    )
    (ok is-overdue)
  )
)

(define-read-only (get-milestone-deadline (milestone-id uint))
  (map-get? milestone-deadlines milestone-id)
)

(define-read-only (get-deadline-status (milestone-id uint))
  (map-get? deadline-status milestone-id)
)

(define-read-only (is-milestone-overdue (milestone-id uint))
  (match (map-get? milestone-deadlines milestone-id)
    some-deadline (let
      (
        (current-block stacks-block-height)
        (deadline-with-buffer (+ (get deadline-block some-deadline) (get buffer-blocks some-deadline)))
      )
      (> current-block deadline-with-buffer)
    )
    false
  )
)

(define-read-only (calculate-penalty-amount (milestone-id uint) (milestone-amount uint))
  (match (map-get? milestone-deadlines milestone-id)
    some-deadline (if (is-milestone-overdue milestone-id)
      (/ (* milestone-amount (get penalty-rate some-deadline)) u100)
      u0
    )
    u0
  )
)
