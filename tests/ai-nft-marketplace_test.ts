import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can mint AI NFT with metadata",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'create-collection', [
                types.ascii("AI Art Collection"),
                types.ascii("Collection of AI generated artwork")
            ], deployer.address),
            
            Tx.contractCall('ai-nft-marketplace', 'mint-ai-nft', [
                types.ascii("Cyberpunk City"),
                types.ascii("A futuristic cyberpunk cityscape at night"),
                types.ascii("https://example.com/image1.png"),
                types.ascii("cyberpunk city neon lights futuristic"),
                types.ascii("Stable Diffusion XL"),
                types.uint(1),
                types.uint(1000000), // 1 STX
                types.uint(500) // 5% royalty
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        assertEquals(block.receipts[1].result.expectOk(), types.uint(1));
    },
});

Clarinet.test({
    name: "Can buy NFT with royalty distribution",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Setup: Create collection and mint NFT
        let setupBlock = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'create-collection', [
                types.ascii("Test Collection"),
                types.ascii("Test collection")
            ], deployer.address),
            
            Tx.contractCall('ai-nft-marketplace', 'mint-ai-nft', [
                types.ascii("Test NFT"),
                types.ascii("Test description"),
                types.ascii("https://example.com/test.png"),
                types.ascii("test prompt"),
                types.ascii("Test Model"),
                types.uint(1),
                types.uint(1000000),
                types.uint(500)
            ], wallet1.address)
        ]);
        
        // Buy NFT
        let buyBlock = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'buy-nft', [
                types.uint(1)
            ], wallet2.address)
        ]);
        
        assertEquals(buyBlock.receipts[0].result.expectOk(), types.bool(true));
    },
});

Clarinet.test({
    name: "Can create and participate in auction",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Setup NFT
        let setupBlock = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'create-collection', [
                types.ascii("Auction Collection"),
                types.ascii("Collection for auction testing")
            ], deployer.address),
            
            Tx.contractCall('ai-nft-marketplace', 'mint-ai-nft', [
                types.ascii("Auction NFT"),
                types.ascii("NFT for auction"),
                types.ascii("https://example.com/auction.png"),
                types.ascii("auction test prompt"),
                types.ascii("Test Model"),
                types.uint(1),
                types.uint(2000000),
                types.uint(250)
            ], wallet1.address)
        ]);
        
        // Create auction
        let auctionBlock = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'create-auction', [
                types.uint(1),
                types.uint(1000000), // Starting price
                types.uint(100) // Duration in blocks
            ], wallet1.address)
        ]);
        
        assertEquals(auctionBlock.receipts[0].result.expectOk(), types.bool(true));
        
        // Place bid
        let bidBlock = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'place-bid', [
                types.uint(1),
                types.uint(1500000) // Bid amount
            ], wallet2.address)
        ]);
        
        assertEquals(bidBlock.receipts[0].result.expectOk(), types.bool(true));
    },
});

Clarinet.test({
    name: "Contract owner can pause/unpause contract",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Pause contract
        let pauseBlock = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'pause-contract', [], deployer.address)
        ]);
        
        assertEquals(pauseBlock.receipts[0].result.expectOk(), types.bool(true));
        
        // Try to mint while paused (should fail)
        let mintBlock = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'create-collection', [
                types.ascii("Paused Collection"),
                types.ascii("Should not work")
            ], wallet1.address)
        ]);
        
        mintBlock.receipts[0].result.expectErr(types.uint(401));
        
        // Unpause
        let unpauseBlock = chain.mineBlock([
            Tx.contractCall('ai-nft-marketplace', 'unpause-contract', [], deployer.address)
        ]);
        
        assertEquals(unpauseBlock.receipts[0].result.expectOk(), types.bool(true));
    },
});
