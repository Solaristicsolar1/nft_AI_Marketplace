;; AI NFT Marketplace Contract
(define-non-fungible-token ai-nft uint)

;; Storage
(define-map nft-metadata uint {
  creator: principal,
  title: (string-ascii 64),
  description: (string-ascii 256),
  image-uri: (string-ascii 256),
  price: uint,
  for-sale: bool
})

(define-data-var next-nft-id uint u1)

;; Mint NFT with AI-generated metadata
(define-public (mint-ai-nft (title (string-ascii 64)) (description (string-ascii 256)) (image-uri (string-ascii 256)) (price uint))
  (let ((nft-id (var-get next-nft-id)))
    (try! (nft-mint? ai-nft nft-id tx-sender))
    (map-set nft-metadata nft-id {
      creator: tx-sender,
      title: title,
      description: description,
      image-uri: image-uri,
      price: price,
      for-sale: true
    })
    (var-set next-nft-id (+ nft-id u1))
    (ok nft-id)))

;; Buy NFT
(define-public (buy-nft (nft-id uint))
  (let ((metadata (unwrap! (map-get? nft-metadata nft-id) (err u404)))
        (owner (unwrap! (nft-get-owner? ai-nft nft-id) (err u404))))
    (asserts! (get for-sale metadata) (err u400))
    (try! (stx-transfer? (get price metadata) tx-sender owner))
    (try! (nft-transfer? ai-nft nft-id owner tx-sender))
    (map-set nft-metadata nft-id (merge metadata {for-sale: false}))
    (ok true)))

;; Get NFT metadata
(define-read-only (get-nft-metadata (nft-id uint))
  (map-get? nft-metadata nft-id))

;; Set NFT for sale
(define-public (set-for-sale (nft-id uint) (price uint))
  (let ((owner (unwrap! (nft-get-owner? ai-nft nft-id) (err u404))))
    (asserts! (is-eq tx-sender owner) (err u403))
    (map-set nft-metadata nft-id 
      (merge (unwrap! (map-get? nft-metadata nft-id) (err u404)) 
             {price: price, for-sale: true}))
    (ok true)))
