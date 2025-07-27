import { Clarinet, Tx, Chain, Account, types } from "@hirosystems/clarinet-sdk";

Clarinet.test({
  name: "Create and complete a task successfully",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get("deployer")!;
    let creator = accounts.get("wallet_1")!;
    let claimant = accounts.get("wallet_2")!;

    // Create a task
    let block = chain.mineBlock([
      Tx.contractCall(
        "bounty-board",
        "create-task",
        [types.utf8("Build a website"), types.uint(1000000)], // 1 STX
        creator.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // Claim the task
    block = chain.mineBlock([
      Tx.contractCall(
        "bounty-board",
        "claim-task",
        [types.uint(1)],
        claimant.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Submit task result
    block = chain.mineBlock([
      Tx.contractCall(
        "bounty-board",
        "submit-task",
        [types.uint(1), types.utf8("Website completed")],
        claimant.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Confirm task completion
    block = chain.mineBlock([
      Tx.contractCall(
        "bounty-board",
        "confirm-task",
        [types.uint(1)],
        creator.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Check claimant's balance
    let balance = chain.getBalance(claimant.address);
    // Assuming claimant had 0 STX initially, should now have 1 STX
    assert(balance >= 1000000);
  },
});

Clarinet.test({
  name: "Cancel a task if not claimed",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let creator = accounts.get("wallet_1")!;

    // Create a task
    let block = chain.mineBlock([
      Tx.contractCall(
        "bounty-board",
        "create-task",
        [types.utf8("Write a blog post"), types.uint(500000)], // 0.5 STX
        creator.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // Cancel the task
    block = chain.mineBlock([
      Tx.contractCall(
        "bounty-board",
        "cancel-task",
        [types.uint(1)],
        creator.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Check task is deleted
    let task = chain.callReadOnlyFn(
      "bounty-board",
      "get-task",
      [types.uint(1)],
      creator.address
    );
    task.result.expectNone();
  },
});