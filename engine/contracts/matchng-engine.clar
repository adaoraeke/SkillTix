;; SkillTix Matching Engine Contract - Simplified Version
;; Smart contract-based matching for skill offers and requests

;; =============================================================================
;; CONSTANTS & ERRORS
;; =============================================================================

(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u403))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant CONTRACT_OWNER tx-sender)

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

;; Skill offers
(define-map skill-offers
  uint
  {
    provider: principal,
    skill-category: uint,
    description: (string-ascii 128),
    location-lat: int,
    location-lng: int,
    status: (string-ascii 16)
  })

;; Skill requests
(define-map skill-requests
  uint
  {
    requester: principal,
    skill-category: uint,
    description: (string-ascii 128),
    location-lat: int,
    location-lng: int,
    status: (string-ascii 16)
  })

;; Matches
(define-map skill-matches
  uint
  {
    offer-id: uint,
    request-id: uint,
    compatibility-score: uint,
    status: (string-ascii 16)
  })

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

(define-data-var next-offer-id uint u1)
(define-data-var next-request-id uint u1)
(define-data-var next-match-id uint u1)

;; =============================================================================
;; PRIVATE FUNCTIONS
;; =============================================================================

(define-private (calculate-distance (lat1 int) (lng1 int) (lat2 int) (lng2 int))
  (let ((lat-diff (if (>= lat1 lat2) (- lat1 lat2) (- lat2 lat1)))
        (lng-diff (if (>= lng1 lng2) (- lng1 lng2) (- lng2 lng1))))
    (+ (* lat-diff lat-diff) (* lng-diff lng-diff))))

;; =============================================================================
;; PUBLIC FUNCTIONS
;; =============================================================================

;; Create skill offer
(define-public (create-skill-offer (skill-category uint) (description (string-ascii 128)) (location-lat int) (location-lng int))
  (let ((offer-id (var-get next-offer-id)))
    (map-set skill-offers offer-id {
      provider: tx-sender,
      skill-category: skill-category,
      description: description,
      location-lat: location-lat,
      location-lng: location-lng,
      status: "active"
    })
    (var-set next-offer-id (+ offer-id u1))
    (ok offer-id)))

;; Create skill request
(define-public (create-skill-request (skill-category uint) (description (string-ascii 128)) (location-lat int) (location-lng int))
  (let ((request-id (var-get next-request-id)))
    (map-set skill-requests request-id {
      requester: tx-sender,
      skill-category: skill-category,
      description: description,
      location-lat: location-lat,
      location-lng: location-lng,
      status: "active"
    })
    (var-set next-request-id (+ request-id u1))
    (ok request-id)))

;; Create match between offer and request
(define-public (create-match (offer-id uint) (request-id uint))
  (let ((offer (unwrap! (map-get? skill-offers offer-id) ERR_NOT_FOUND))
        (request (unwrap! (map-get? skill-requests request-id) ERR_NOT_FOUND))
        (match-id (var-get next-match-id)))
    
    (asserts! (is-eq (get skill-category offer) (get skill-category request)) ERR_INVALID_INPUT)
    
    (let ((distance (calculate-distance 
                      (get location-lat offer) (get location-lng offer)
                      (get location-lat request) (get location-lng request)))
          (compatibility-score (if (<= distance 100) (- u100 (to-uint (/ distance 10))) u0)))
      
      (map-set skill-matches match-id {
        offer-id: offer-id,
        request-id: request-id,
        compatibility-score: compatibility-score,
        status: "pending"
      })
      
      (var-set next-match-id (+ match-id u1))
      (ok match-id))))

;; Accept match
(define-public (accept-match (match-id uint))
  (let ((match (unwrap! (map-get? skill-matches match-id) ERR_NOT_FOUND)))
    (map-set skill-matches match-id (merge match {status: "accepted"}))
    (ok true)))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-skill-offer (offer-id uint))
  (map-get? skill-offers offer-id))

(define-read-only (get-skill-request (request-id uint))
  (map-get? skill-requests request-id))

(define-read-only (get-match (match-id uint))
  (map-get? skill-matches match-id))

(define-read-only (calculate-compatibility-score (offer-id uint) (request-id uint))
  (match (map-get? skill-offers offer-id)
    offer (match (map-get? skill-requests request-id)
      request 
        (let ((distance (calculate-distance 
                          (get location-lat offer) (get location-lng offer)
                          (get location-lat request) (get location-lng request))))
          (ok (if (<= distance 100) (- u100 (to-uint (/ distance 10))) u0)))
      ERR_NOT_FOUND)
    ERR_NOT_FOUND))