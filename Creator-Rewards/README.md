# CreatorTip

A decentralized content creator tipping platform built on Stacks blockchain.

## Overview

CreatorTip is a smart contract that enables a decentralized tipping system for content creators, allowing fans to financially support their favorite creators while maintaining transparent fund management, flexible fee structures, and secure withdrawals.

## Features

- **Decentralized Tipping**: Fans can directly send STX tips to content creators
- **Content Registry**: Creators can publish and manage content identifiers
- **Transparent Fee Structure**: Clear breakdown of platform fees and creator earnings
- **Secure Withdrawals**: Creators can withdraw their earnings at any time
- **Administrative Controls**: Emergency pause capability and fee adjustments

## Error Codes

| Code | Description |
|------|-------------|
| 100 | Unauthorized access attempt |
| 101 | Invalid tip amount |
| 102 | Content not found |
| 103 | Content already exists |
| 104 | Transfer failed |
| 105 | Insufficient balance |
| 106 | Invalid parameter value |
| 107 | Contract is paused |
| 108 | Zero amount transfer |
| 109 | Content inactive |

## Public Functions

### Administrative Functions

```clarity
(transfer-admin-rights (new-admin-address principal))
```
Transfers contract administration rights to a new address.

```clarity
(update-platform-fee (new-fee-percentage uint))
```
Updates the platform fee percentage (in basis points, max 10%).

```clarity
(toggle-emergency-pause (pause-status bool))
```
Enables or disables the emergency pause functionality.

```clarity
(withdraw-platform-revenue (recipient-address principal))
```
Withdraws accumulated platform fees to the specified address.

### Content Management Functions

```clarity
(publish-new-content 
  (content-identifier (string-ascii 64))
  (content-title (string-ascii 256))
  (content-details (string-utf8 1024))
)
```
Registers new content in the system.

```clarity
(update-content-details
  (content-identifier (string-ascii 64))
  (content-title (string-ascii 256))
  (content-details (string-utf8 1024))
  (content-status-active bool)
)
```
Updates existing content information.

### Tipping Functions

```clarity
(send-tip-to-creator
  (content-identifier (string-ascii 64))
  (tip-amount uint)
  (tip-message (optional (string-utf8 280)))
)
```
Sends a tip to content creator with an optional message.

### Fund Withdrawal Functions

```clarity
(withdraw-creator-earnings)
```
Allows a creator to withdraw their accumulated earnings.

### Read-only Functions

```clarity
(get-content-details (content-identifier (string-ascii 64)))
```
Returns content details by ID.

```clarity
(get-tip-details (content-identifier (string-ascii 64)) (tip-sender principal))
```
Returns tip information for a specific user and content.

```clarity
(get-creator-available-balance (creator-address principal))
```
Returns a creator's current available balance.

```clarity
(get-current-platform-fee)
```
Returns the current platform fee percentage.

```clarity
(get-platform-revenue)
```
Returns accumulated platform revenue.

```clarity
(is-contract-paused)
```
Checks if the contract is currently paused.

```clarity
(get-contract-admin)
```
Returns the current contract administrator address.

```clarity
(calculate-tip-breakdown (tip-amount uint))
```
Calculates fee breakdown for a potential tip.

## Data Structures

### Content Registry
Stores all creator content information:
- Content owner (principal)
- Content title (string-ascii 256)
- Content details (string-utf8 1024)
- Publication block (uint)
- Lifetime tip amount (uint)
- Tip transaction count (uint)
- Content status active (bool)

### Tip History
Records all tips made to specific content:
- Tip amount (uint)
- Tip block height (uint)
- Tip message (optional string-utf8 280)

### Creator Earnings
Tracks withdrawable funds for each creator:
- Available balance (uint)

## State Variables

- **contract-admin**: Principal address of the contract administrator
- **platform-fee-percentage**: Current platform fee in basis points (default: 250 = 2.5%)
- **emergency-pause-active**: Boolean flag for pausing contract operations
- **platform-revenue**: Accumulated platform fees

## Getting Started

1. Deploy the smart contract to the Stacks blockchain
2. Creators can publish content using `publish-new-content`
3. Fans can send tips using `send-tip-to-creator`
4. Creators can withdraw earnings using `withdraw-creator-earnings`

## Example Usage

### Publishing Content
```clarity
(publish-new-content 
  "content-123"
  "My Awesome Content"
  "This is a detailed description of my content that can receive tips."
)
```

### Sending a Tip
```clarity
(send-tip-to-creator
  "content-123"
  u1000000  ;; 1 STX
  (some "Thanks for the great content!")
)
```

### Withdrawing Earnings
```clarity
(withdraw-creator-earnings)
```