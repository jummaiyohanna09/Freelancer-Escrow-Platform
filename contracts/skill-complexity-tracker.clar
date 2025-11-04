(define-constant ERR_COMPLEXITY_NOT_FOUND (err u500))
(define-constant ERR_INVALID_COMPLEXITY (err u501))
(define-constant ERR_SKILL_NOT_FOUND (err u502))
(define-constant ERR_UNAUTHORIZED_ACTION (err u503))
(define-constant ERR_ALREADY_ASSIGNED (err u504))

(define-constant COMPLEXITY_BEGINNER u1)
(define-constant COMPLEXITY_INTERMEDIATE u2)
(define-constant COMPLEXITY_ADVANCED u3)
(define-constant COMPLEXITY_EXPERT u4)

(define-map milestone-complexity
  uint
  {
    milestone-id: uint,
    complexity-level: uint,
    skill-category: (string-ascii 50),
    assigned-by: principal,
    assigned-at: uint,
    verified: bool
  }
)

(define-map freelancer-skills
  {freelancer: principal, skill-category: (string-ascii 50)}
  {
    beginner-count: uint,
    intermediate-count: uint,
    advanced-count: uint,
    expert-count: uint,
    total-completed: uint,
    last-updated: uint
  }
)

(define-map skill-categories
  principal
  (list 30 (string-ascii 50))
)

(define-public (assign-milestone-complexity
  (milestone-id uint)
  (complexity-level uint)
  (skill-category (string-ascii 50)))
  (begin
    (asserts! (and (>= complexity-level COMPLEXITY_BEGINNER) 
                   (<= complexity-level COMPLEXITY_EXPERT)) 
              ERR_INVALID_COMPLEXITY)
    (asserts! (is-none (map-get? milestone-complexity milestone-id)) 
              ERR_ALREADY_ASSIGNED)
    
    (map-set milestone-complexity milestone-id
      {
        milestone-id: milestone-id,
        complexity-level: complexity-level,
        skill-category: skill-category,
        assigned-by: tx-sender,
        assigned-at: stacks-block-height,
        verified: false
      }
    )
    (ok true)
  )
)

(define-public (verify-milestone-skill 
  (milestone-id uint) 
  (freelancer principal))
  (let
    (
      (complexity (unwrap! (map-get? milestone-complexity milestone-id) 
                          ERR_COMPLEXITY_NOT_FOUND))
      (current-skills (default-to 
        {beginner-count: u0, intermediate-count: u0, advanced-count: u0, 
         expert-count: u0, total-completed: u0, last-updated: u0}
        (map-get? freelancer-skills 
          {freelancer: freelancer, skill-category: (get skill-category complexity)})))
      (categories (default-to (list) (map-get? skill-categories freelancer)))
    )
    (asserts! (not (get verified complexity)) ERR_ALREADY_ASSIGNED)
    
    (map-set milestone-complexity milestone-id
      (merge complexity {verified: true})
    )
    
    (map-set freelancer-skills 
      {freelancer: freelancer, skill-category: (get skill-category complexity)}
      {
        beginner-count: (+ (get beginner-count current-skills) 
          (if (is-eq (get complexity-level complexity) COMPLEXITY_BEGINNER) u1 u0)),
        intermediate-count: (+ (get intermediate-count current-skills) 
          (if (is-eq (get complexity-level complexity) COMPLEXITY_INTERMEDIATE) u1 u0)),
        advanced-count: (+ (get advanced-count current-skills) 
          (if (is-eq (get complexity-level complexity) COMPLEXITY_ADVANCED) u1 u0)),
        expert-count: (+ (get expert-count current-skills) 
          (if (is-eq (get complexity-level complexity) COMPLEXITY_EXPERT) u1 u0)),
        total-completed: (+ (get total-completed current-skills) u1),
        last-updated: stacks-block-height
      }
    )
    
    (if (is-none (index-of categories (get skill-category complexity)))
      (map-set skill-categories freelancer
        (unwrap! (as-max-len? (append categories (get skill-category complexity)) u30) 
                ERR_SKILL_NOT_FOUND))
      true
    )
    (ok true)
  )
)

(define-read-only (get-milestone-complexity (milestone-id uint))
  (map-get? milestone-complexity milestone-id)
)

(define-read-only (get-freelancer-skill-stats 
  (freelancer principal) 
  (skill-category (string-ascii 50)))
  (map-get? freelancer-skills {freelancer: freelancer, skill-category: skill-category})
)

(define-read-only (get-freelancer-categories (freelancer principal))
  (map-get? skill-categories freelancer)
)

(define-read-only (calculate-skill-level 
  (freelancer principal) 
  (skill-category (string-ascii 50)))
  (match (map-get? freelancer-skills 
          {freelancer: freelancer, skill-category: skill-category})
    stats (if (>= (get expert-count stats) u3)
      (some u4)
      (if (>= (get advanced-count stats) u5)
        (some u3)
        (if (>= (get intermediate-count stats) u3)
          (some u2)
          (if (>= (get total-completed stats) u1)
            (some u1)
            none
          )
        )
      )
    )
    none
  )
)
