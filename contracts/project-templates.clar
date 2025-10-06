(define-constant ERR_TEMPLATE_NOT_FOUND (err u200))
(define-constant ERR_TEMPLATE_EXISTS (err u201))
(define-constant ERR_INVALID_TEMPLATE (err u202))

(define-data-var template-counter uint u0)

(define-map project-templates
  uint
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    milestone-count: uint,
    created-at: uint,
    active: bool
  }
)

(define-map template-milestones
  {template-id: uint, milestone-index: uint}
  {
    description: (string-ascii 200),
    percentage: uint
  }
)

(define-map user-templates
  principal
  (list 50 uint)
)

(define-public (create-template 
  (title (string-ascii 100)) 
  (description (string-ascii 300)) 
  (milestone-1-desc (string-ascii 200)) (milestone-1-pct uint)
  (milestone-2-desc (optional (string-ascii 200))) (milestone-2-pct (optional uint))
  (milestone-3-desc (optional (string-ascii 200))) (milestone-3-pct (optional uint)))
  (let
    (
      (template-id (+ (var-get template-counter) u1))
      (current-user-templates (default-to (list) (map-get? user-templates tx-sender)))
      (total-pct (+ milestone-1-pct 
                   (default-to u0 milestone-2-pct) 
                   (default-to u0 milestone-3-pct)))
    )
    (asserts! (is-eq total-pct u100) ERR_INVALID_TEMPLATE)
    (asserts! (> milestone-1-pct u0) ERR_INVALID_TEMPLATE)
    
    (map-set project-templates template-id
      {
        creator: tx-sender,
        title: title,
        description: description,
        milestone-count: (+ u1 
          (if (is-some milestone-2-desc) u1 u0)
          (if (is-some milestone-3-desc) u1 u0)),
        created-at: stacks-block-height,
        active: true
      }
    )
    
    (map-set template-milestones 
      {template-id: template-id, milestone-index: u0}
      {description: milestone-1-desc, percentage: milestone-1-pct}
    )
    
    (if (is-some milestone-2-desc)
      (map-set template-milestones 
        {template-id: template-id, milestone-index: u1}
        {description: (unwrap-panic milestone-2-desc), percentage: (unwrap-panic milestone-2-pct)}
      )
      true
    )
    
    (if (is-some milestone-3-desc)
      (map-set template-milestones 
        {template-id: template-id, milestone-index: u2}
        {description: (unwrap-panic milestone-3-desc), percentage: (unwrap-panic milestone-3-pct)}
      )
      true
    )
    
    (map-set user-templates tx-sender
      (unwrap! (as-max-len? (append current-user-templates template-id) u50) ERR_TEMPLATE_EXISTS)
    )
    
    (var-set template-counter template-id)
    (ok template-id)
  )
)

(define-public (toggle-template-status (template-id uint))
  (let
    (
      (template (unwrap! (map-get? project-templates template-id) ERR_TEMPLATE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator template)) ERR_INVALID_TEMPLATE)
    
    (map-set project-templates template-id
      (merge template {active: (not (get active template))})
    )
    (ok true)
  )
)

(define-read-only (get-template (template-id uint))
  (map-get? project-templates template-id)
)

(define-read-only (get-template-milestone (template-id uint) (milestone-index uint))
  (map-get? template-milestones {template-id: template-id, milestone-index: milestone-index})
)

(define-read-only (get-user-templates (user principal))
  (map-get? user-templates user)
)

(define-read-only (get-template-counter)
  (var-get template-counter)
)