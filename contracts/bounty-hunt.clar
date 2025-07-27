;; Decentralized Task Bounty Board
;; A smart contract for creating, claiming, submitting, and completing tasks with STX rewards
(define-constant STATUS-OPEN u1)
(define-constant STATUS-RECEIVED u2)
(define-constant STATUS-COMPLETED u3)

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-TASK-NOT-FOUND u101)
(define-constant ERR-TASK-ALREADY-CLAIMED u102)
(define-constant ERR-TASK-ALREADY-COMPLETED u103)
(define-constant ERR-INSUFFICIENT-BALANCE u104)
(define-constant ERR-INVALID-AMOUNT u105)
(define-constant ERR-TASK-NOT-CLAIMED u106)
(define-constant ERR-TITLE-EMPTY u107)
(define-constant ERR-TITLE-TOO-LONG u108)
(define-constant ERR-DESCRIPTION-EMPTY u107)
(define-constant ERR-DESCRIPTION-TOO-LONG u107)

;; Data structures
(define-map tasks
  { task-id: uint }
  {
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 256),
    reward: uint,
    status: uint,  ;; 1 = open, 2 = received, 3 = completed
    created-at: uint,
    deadline: (optional uint),
    claimant: (optional principal),
    submission: (optional (string-utf8 256))
  }
)

(define-data-var task-counter uint u0)

;; Create a new task
(define-public (create-task (title (string-utf8 100))
                            (description (string-utf8 256))
                            (reward uint)
                            (deadline (optional uint)))
  (let
    (
      (task-id (+ (var-get task-counter) u1))
      (sender tx-sender)
    )
    ;; Validate reward amount
    (asserts! (> reward u0) (err ERR-INVALID-AMOUNT))
    ;; Check if sender has enough balance
    (asserts! (>= (stx-get-balance sender) reward) (err ERR-INSUFFICIENT-BALANCE))
    
    ;; Check length of title
    (asserts! (> (len title) u0) (err ERR-TITLE-EMPTY))
    (asserts! (<= (len title) u100) (err ERR-TITLE-TOO-LONG))
    ;; Check length of description
    (asserts! (> (len description) u0) (err ERR-DESCRIPTION-EMPTY))
    (asserts! (<= (len description) u256) (err ERR-DESCRIPTION-TOO-LONG))
    
    ;; Transfer STX to contract
    (try! (stx-transfer? reward sender (as-contract tx-sender)))
    ;; Store task
    (map-insert tasks
      { task-id: task-id }
      {
        creator: sender,
        title: title,
        description: description,
        reward: reward,
        status: u1,
        created-at: u100,
        deadline: deadline,
        claimant: none,
        submission: none
      }
    )
    ;; Increment task counter
    (var-set task-counter task-id)
    (ok task-id)
  )
)

;; Claim a task
(define-public (claim-task (task-id uint))
  (let
    (
      (task (unwrap! (map-get? tasks { task-id: task-id }) (err ERR-TASK-NOT-FOUND)))
      (sender tx-sender)
    )
    ;; Check if task is not claimed
    (asserts! (is-none (get claimant task)) (err ERR-TASK-ALREADY-CLAIMED))
    ;; Check if task is not completed
    (asserts! (not (is-eq (get status task) STATUS-COMPLETED)) (err ERR-TASK-ALREADY-COMPLETED))
    ;; Update task with claimant
    (map-set tasks
      { task-id: task-id }
      (merge task { claimant: (some sender) })
    )
    (ok true)
  )
)

;; Submit task result
(define-public (submit-task (task-id uint) (submission (string-utf8 256)))
  (let
    (
      (task (unwrap! (map-get? tasks { task-id: task-id }) (err ERR-TASK-NOT-FOUND)))
      (sender tx-sender)
    )
    ;; Check if sender is the claimant
    (asserts! (is-eq (some sender) (get claimant task)) (err ERR-NOT-AUTHORIZED))
    ;; Check if task is not completed
    (asserts! (not (is-eq (get status task) STATUS-COMPLETED)) (err ERR-TASK-ALREADY-COMPLETED))
    ;; Update task with submission
    (map-set tasks
      { task-id: task-id }
      (merge task { submission: (some submission) })
    )
    (ok true)
  )
)

;; Confirm task completion
(define-public (confirm-task (task-id uint))
  (let
    (
      (task (unwrap! (map-get? tasks { task-id: task-id }) (err ERR-TASK-NOT-FOUND)))
      (sender tx-sender)
      (claimant (unwrap! (get claimant task) (err ERR-TASK-NOT-CLAIMED)))
    )
    ;; Check if sender is the creator
    (asserts! (is-eq sender (get creator task)) (err ERR-NOT-AUTHORIZED))
    ;; Check if task is not completed
    (asserts! (not (is-eq (get status task) STATUS-COMPLETED)) (err ERR-TASK-ALREADY-COMPLETED))
    ;; Transfer reward to claimant
    (try! (as-contract (stx-transfer? (get reward task) tx-sender claimant)))
    ;; Mark task as completed
    (map-set tasks
      { task-id: task-id }
      (merge task { status: u3 })
    )
    (ok true)
  )
)

;; Cancel task (only by creator, if not claimed)
(define-public (cancel-task (task-id uint))
  (let
    (
      (task (unwrap! (map-get? tasks { task-id: task-id }) (err ERR-TASK-NOT-FOUND)))
      (sender tx-sender)
    )
    ;; Check if sender is the creator
    (asserts! (is-eq sender (get creator task)) (err ERR-NOT-AUTHORIZED))
    ;; Check if task is not claimed
    (asserts! (is-none (get claimant task)) (err ERR-TASK-ALREADY-CLAIMED))
    ;; Check if task is not completed
    (asserts! (not (is-eq (get status task) STATUS-COMPLETED)) (err ERR-TASK-ALREADY-COMPLETED))
    ;; Refund reward to creator
    (try! (as-contract (stx-transfer? (get reward task) tx-sender sender)))
    ;; Delete task
    (map-delete tasks { task-id: task-id })
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-task (task-id uint))
  (map-get? tasks { task-id: task-id })
)

(define-read-only (get-task-counter)
  (var-get task-counter)
)