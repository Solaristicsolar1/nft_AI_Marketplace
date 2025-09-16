;; AI NFT Marketplace Contract - Debugged Version
;; Features: Minting, Trading, Auctions, Royalties, AI Metadata, Collections

;; Define NFT token
(define-non-fungible-token ai-nft uint)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-PRICE (err u400))
(define-constant ERR-AUCTION-ENDED (err u410))
(define-constant ERR-AUCTION-ACTIVE (err u411))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-NOT-FOR-SALE (err u403))
(define-constant ERR-INVALID-INPUT (err u405))
(define-constant MARKETPLACE-FEE u250) ;; 2.5%
(define-constant MAX-ROYALTY u1000) ;; 10%
(define-constant MIN-AUCTION-DURATION u10) ;; Minimum 10 blocks
(define-constant MAX-AUCTION-DURATION u14400) ;; Maximum ~100 days

;; Data Variables
(define-data-var next-nft-id uint u1)
(define-data-var next-collection-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var total-volume uint u0)

;; NFT Metadata Storage
(define-map nft-metadata uint {
  creator: principal,
  owner: principal,
  title: (string-ascii 64),
  description: (string-ascii 256),
  image-uri: (string-ascii 256),
  ai-prompt: (string-ascii 256),
  ai-model: (string-ascii 32),
  collection-id: uint,
  price: uint,
  for-sale: bool,
  royalty-percent: uint,
  created-at: uint,
  rarity-score: uint
})

;; Collection Storage
(define-map collections uint {
  name: (string-ascii 64),
  description: (string-ascii 256),
  creator: principal,
  total-supply: uint,
  floor-price: uint,
  created-at: uint
})

;; Auction Storage
(define-map auctions uint {
  nft-id: uint,
  seller: principal,
  starting-price: uint,
  current-bid: uint,
  highest-bidder: (optional principal),
  end-block: uint,
  active: bool
})

;; Bid Storage
(define-map bids {auction-id: uint, bidder: principal} {
  amount: uint,
  block-height: uint
})

;; Sales History
(define-map sales-history uint {
  nft-id: uint,
  seller: principal,
  buyer: principal,
  price: uint,
  block-height: uint
})

;; User Statistics
(define-map user-stats principal {
  nfts-created: uint,
  nfts-owned: uint,
  total-sales: uint,
  total-purchases: uint,
  reputation-score: uint
})

;; Input Validation Functions
(define-private (validate-string-input (input (string-ascii 256)))
  (and (> (len input) u0) (<= (len input) u256)))

(define-private (validate-short-string (input (string-ascii 64)))
  (and (> (len input) u0) (<= (len input) u64)))

(define-private (validate-model-string (input (string-ascii 32)))
  (and (> (len input) u0) (<= (len input) u32)))

(define-private (validate-price (price uint))
  (and (> price u0) (<= price u1000000000000))) ;; Max 1M STX

(define-private (validate-royalty (royalty uint))
  (<= royalty MAX-ROYALTY))

(define-private (validate-auction-duration (duration uint))
  (and (>= duration MIN-AUCTION-DURATION) (<= duration MAX-AUCTION-DURATION)))

;; Collection Management Functions
(define-public (create-collection (name (string-ascii 64)) (description (string-ascii 256)))
  (let ((collection-id (var-get next-collection-id)))
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-short-string name) ERR-INVALID-INPUT)
    (asserts! (validate-string-input description) ERR-INVALID-INPUT)
    
    (map-set collections collection-id {
      name: name,
      description: description,
      creator: tx-sender,
      total-supply: u0,
      floor-price: u0,
      created-at: block-height
    })
    (var-set next-collection-id (+ collection-id u1))
    (ok collection-id)))

;; Enhanced NFT Minting with AI Metadata and Validation
(define-public (mint-ai-nft 
  (title (string-ascii 64)) 
  (description (string-ascii 256)) 
  (image-uri (string-ascii 256))
  (ai-prompt (string-ascii 256))
  (ai-model (string-ascii 32))
  (collection-id uint)
  (price uint)
  (royalty-percent uint))
  (let ((nft-id (var-get next-nft-id)))
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-short-string title) ERR-INVALID-INPUT)
    (asserts! (validate-string-input description) ERR-INVALID-INPUT)
    (asserts! (validate-string-input image-uri) ERR-INVALID-INPUT)
    (asserts! (validate-string-input ai-prompt) ERR-INVALID-INPUT)
    (asserts! (validate-model-string ai-model) ERR-INVALID-INPUT)
    (asserts! (validate-price price) ERR-INVALID-PRICE)
    (asserts! (validate-royalty royalty-percent) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? collections collection-id)) ERR-NOT-FOUND)
    
    ;; Mint NFT
    (try! (nft-mint? ai-nft nft-id tx-sender))
    
    ;; Store metadata
    (map-set nft-metadata nft-id {
      creator: tx-sender,
      owner: tx-sender,
      title: title,
      description: description,
      image-uri: image-uri,
      ai-prompt: ai-prompt,
      ai-model: ai-model,
      collection-id: collection-id,
      price: price,
      for-sale: true,
      royalty-percent: royalty-percent,
      created-at: block-height,
      rarity-score: (calculate-rarity-score ai-prompt)
    })
    
    ;; Update collection supply
    (update-collection-supply collection-id)
    
    ;; Update user stats
    (update-user-stats-mint tx-sender)
    
    (var-set next-nft-id (+ nft-id u1))
    (ok nft-id)))

;; Calculate rarity score based on AI prompt complexity
(define-private (calculate-rarity-score (prompt (string-ascii 256)))
  (let ((prompt-length (len prompt)))
    (if (> prompt-length u200) u95
    (if (> prompt-length u150) u85
    (if (> prompt-length u100) u75
    (if (> prompt-length u50) u65
    u50))))))

;; Update collection supply
(define-private (update-collection-supply (collection-id uint))
  (match (map-get? collections collection-id)
    collection (map-set collections collection-id 
      (merge collection {total-supply: (+ (get total-supply collection) u1)}))
    false))

;; Update user statistics for minting
(define-private (update-user-stats-mint (user principal))
  (let ((current-stats (default-to {nfts-created: u0, nfts-owned: u0, total-sales: u0, total-purchases: u0, reputation-score: u0}
                                  (map-get? user-stats user))))
    (map-set user-stats user (merge current-stats {
      nfts-created: (+ (get nfts-created current-stats) u1),
      nfts-owned: (+ (get nfts-owned current-stats) u1),
      reputation-score: (+ (get reputation-score current-stats) u10)
    }))))

;; Enhanced Buy Function with Royalties
(define-public (buy-nft (nft-id uint))
  (let ((metadata (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND))
        (owner (unwrap! (nft-get-owner? ai-nft nft-id) ERR-NOT-FOUND))
        (price (get price metadata))
        (creator (get creator metadata))
        (royalty-percent (get royalty-percent metadata)))
    
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (get for-sale metadata) ERR-NOT-FOR-SALE)
    (asserts! (not (is-eq tx-sender owner)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-price price) ERR-INVALID-PRICE)
    
    ;; Calculate fees
    (let ((marketplace-fee-amount (/ (* price MARKETPLACE-FEE) u10000))
          (royalty-amount (/ (* price royalty-percent) u10000))
          (seller-amount (- price (+ marketplace-fee-amount royalty-amount))))
      
      ;; Transfer payments
      (try! (stx-transfer? marketplace-fee-amount tx-sender CONTRACT-OWNER))
      (try! (stx-transfer? royalty-amount tx-sender creator))
      (try! (stx-transfer? seller-amount tx-sender owner))
      
      ;; Transfer NFT
      (try! (nft-transfer? ai-nft nft-id owner tx-sender))
      
      ;; Update metadata
      (map-set nft-metadata nft-id (merge metadata {
        owner: tx-sender,
        for-sale: false
      }))
      
      ;; Record sale
      (record-sale nft-id owner tx-sender price)
      
      ;; Update user stats
      (update-user-stats-sale owner tx-sender price)
      
      ;; Update total volume
      (var-set total-volume (+ (var-get total-volume) price))
      
      (ok true))))

;; Record sale in history
(define-private (record-sale (nft-id uint) (seller principal) (buyer principal) (price uint))
  (let ((sale-id (+ (* nft-id u1000000) block-height)))
    (map-set sales-history sale-id {
      nft-id: nft-id,
      seller: seller,
      buyer: buyer,
      price: price,
      block-height: block-height
    })))

;; Update user statistics for sales
(define-private (update-user-stats-sale (seller principal) (buyer principal) (price uint))
  (let ((seller-stats (default-to {nfts-created: u0, nfts-owned: u0, total-sales: u0, total-purchases: u0, reputation-score: u0}
                                 (map-get? user-stats seller)))
        (buyer-stats (default-to {nfts-created: u0, nfts-owned: u0, total-sales: u0, total-purchases: u0, reputation-score: u0}
                                (map-get? user-stats buyer))))
    ;; Update seller stats
    (map-set user-stats seller (merge seller-stats {
      nfts-owned: (- (get nfts-owned seller-stats) u1),
      total-sales: (+ (get total-sales seller-stats) price),
      reputation-score: (+ (get reputation-score seller-stats) u5)
    }))
    ;; Update buyer stats
    (map-set user-stats buyer (merge buyer-stats {
      nfts-owned: (+ (get nfts-owned buyer-stats) u1),
      total-purchases: (+ (get total-purchases buyer-stats) price),
      reputation-score: (+ (get reputation-score buyer-stats) u2)
    }))))

;; Auction Functions with Validation
(define-public (create-auction (nft-id uint) (starting-price uint) (duration-blocks uint))
  (let ((metadata (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND))
        (owner (unwrap! (nft-get-owner? ai-nft nft-id) ERR-NOT-FOUND)))
    
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-price starting-price) ERR-INVALID-PRICE)
    (asserts! (validate-auction-duration duration-blocks) ERR-INVALID-INPUT)
    
    ;; Create auction
    (map-set auctions nft-id {
      nft-id: nft-id,
      seller: tx-sender,
      starting-price: starting-price,
      current-bid: starting-price,
      highest-bidder: none,
      end-block: (+ block-height duration-blocks),
      active: true
    })
    
    ;; Remove from direct sale
    (map-set nft-metadata nft-id (merge metadata {for-sale: false}))
    
    (ok true)))

(define-public (place-bid (nft-id uint) (bid-amount uint))
  (let ((auction (unwrap! (map-get? auctions nft-id) ERR-NOT-FOUND)))
    
    (asserts! (get active auction) ERR-AUCTION-ENDED)
    (asserts! (< block-height (get end-block auction)) ERR-AUCTION-ENDED)
    (asserts! (> bid-amount (get current-bid auction)) ERR-INVALID-PRICE)
    (asserts! (not (is-eq tx-sender (get seller auction))) ERR-NOT-AUTHORIZED)
    (asserts! (validate-price bid-amount) ERR-INVALID-PRICE)
    
    ;; Return previous bid if exists
    (match (get highest-bidder auction)
      previous-bidder (try! (stx-transfer? (get current-bid auction) 
                                          (as-contract tx-sender) 
                                          previous-bidder))
      true)
    
    ;; Hold new bid in contract
    (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
    
    ;; Update auction
    (map-set auctions nft-id (merge auction {
      current-bid: bid-amount,
      highest-bidder: (some tx-sender)
    }))
    
    ;; Record bid
    (map-set bids {auction-id: nft-id, bidder: tx-sender} {
      amount: bid-amount,
      block-height: block-height
    })
    
    (ok true)))

(define-public (end-auction (nft-id uint))
  (let ((auction (unwrap! (map-get? auctions nft-id) ERR-NOT-FOUND))
        (metadata (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND)))
    
    (asserts! (get active auction) ERR-AUCTION-ENDED)
    (asserts! (>= block-height (get end-block auction)) ERR-AUCTION-ACTIVE)
    
    ;; Mark auction as ended
    (map-set auctions nft-id (merge auction {active: false}))
    
    ;; Process sale if there was a bidder
    (match (get highest-bidder auction)
      winner (begin
        (let ((price (get current-bid auction))
              (seller (get seller auction))
              (creator (get creator metadata))
              (royalty-percent (get royalty-percent metadata)))
          
          ;; Calculate payments
          (let ((marketplace-fee-amount (/ (* price MARKETPLACE-FEE) u10000))
                (royalty-amount (/ (* price royalty-percent) u10000))
                (seller-amount (- price (+ marketplace-fee-amount royalty-amount))))
            
            ;; Transfer payments from contract
            (try! (as-contract (stx-transfer? marketplace-fee-amount tx-sender CONTRACT-OWNER)))
            (try! (as-contract (stx-transfer? royalty-amount tx-sender creator)))
            (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
            
            ;; Transfer NFT
            (try! (nft-transfer? ai-nft nft-id seller winner))
            
            ;; Update metadata
            (map-set nft-metadata nft-id (merge metadata {owner: winner}))
            
            ;; Record sale
            (record-sale nft-id seller winner price)
            
            ;; Update stats
            (update-user-stats-sale seller winner price)
            (var-set total-volume (+ (var-get total-volume) price))
            
            (ok true))))
      ;; No bidders, return NFT to sale
      (begin
        (map-set nft-metadata nft-id (merge metadata {for-sale: true}))
        (ok false)))))

;; Administrative Functions
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused false)
    (ok true)))

;; Read-only Functions
(define-read-only (get-nft-metadata (nft-id uint))
  (map-get? nft-metadata nft-id))

(define-read-only (get-collection-info (collection-id uint))
  (map-get? collections collection-id))

(define-read-only (get-auction-info (nft-id uint))
  (map-get? auctions nft-id))

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats user))

(define-read-only (get-contract-stats)
  {
    total-nfts: (- (var-get next-nft-id) u1),
    total-collections: (- (var-get next-collection-id) u1),
    total-volume: (var-get total-volume),
    contract-paused: (var-get contract-paused)
  })

(define-read-only (get-nft-owner (nft-id uint))
  (nft-get-owner? ai-nft nft-id))

;; Set NFT for sale with validation
(define-public (set-for-sale (nft-id uint) (price uint))
  (let ((metadata (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND))
        (owner (unwrap! (nft-get-owner? ai-nft nft-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (validate-price price) ERR-INVALID-PRICE)
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    
    (map-set nft-metadata nft-id (merge metadata {
      price: price,
      for-sale: true
    }))
    (ok true)))

;; Remove from sale
(define-public (remove-from-sale (nft-id uint))
  (let ((metadata (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND))
        (owner (unwrap! (nft-get-owner? ai-nft nft-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    
    (map-set nft-metadata nft-id (merge metadata {for-sale: false}))
    (ok true)))
