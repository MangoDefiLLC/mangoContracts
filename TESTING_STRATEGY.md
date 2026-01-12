# Comprehensive Testing Strategy for Mango Contracts

**Status:** Implementation in Progress  
**Date:** 2025-01-XX

---

## Overview

This document outlines the comprehensive testing strategy for the Mango DeFi smart contracts, including unit tests, integration tests, gas benchmarks, fuzz tests, and fork tests.

---

## 1. Testing Goals

### Primary Objectives

1. **Unit Test Coverage:** 100% for all public/external functions
2. **Integration Test Coverage:** All contract interactions tested
3. **Gas Benchmarks:** Document gas costs for optimized functions
4. **Fuzz Tests:** Edge cases and boundary conditions
5. **Fork Tests:** Mainnet integration testing
6. **Test Coverage Reports:** Track and report coverage metrics

---

## 2. Test File Structure

### 2.1 Unit Tests (One per Contract)

| Test File | Contract Under Test | Status |
|-----------|-------------------|--------|
| `AirdropTest.t.sol` | `Airdrop.sol` | ✅ Created |
| `ManagerTest.t.sol` | `Mango_Manager.sol` | ⏳ TODO |
| `MangoTokenTest.t.sol` | `MANGO_DEFI_TOKEN.sol` | ⏳ TODO |
| `MangoReferralTest.t.sol` | `MangoReferral.sol` | ⏳ TODO |
| `MangoRouterTest.t.sol` | `MangoRouter002.sol` | ⏳ TODO |
| `PresaleTest.t.sol` | `Presale.sol` | ⏳ TODO |

### 2.2 Integration Tests

| Test File | Purpose | Status |
|-----------|---------|--------|
| `IntegrationTest.t.sol` | Full system integration | ⏳ TODO |
| `RouterReferralIntegrationTest.t.sol` | Router + Referral | ⏳ TODO |
| `ManagerRouterIntegrationTest.t.sol` | Manager + Router | ⏳ TODO |

### 2.3 Gas Benchmarks

| Test File | Purpose | Status |
|-----------|---------|--------|
| `GasBenchmarks.t.sol` | All gas benchmarks | ⏳ TODO |

### 2.4 Fuzz Tests

| Test File | Purpose | Status |
|-----------|---------|--------|
| `FuzzTests.t.sol` | Comprehensive fuzz tests | ⏳ TODO |

### 2.5 Fork Tests

| Test File | Purpose | Status |
|-----------|---------|--------|
| `ForkTests.t.sol` | Mainnet fork testing | ⏳ TODO |

---

## 3. Test Coverage Requirements

### 3.1 Unit Test Coverage

#### Airdrop Contract ✅
- [x] Constructor whitelists deployer
- [x] `airDrop()` success cases
- [x] `airDrop()` reverts when not whitelisted
- [x] `airDrop()` reverts when insufficient balance
- [x] `airDrop()` empty list
- [x] `airDrop()` single holder
- [x] `addToWhitelist()` success
- [x] `addToWhitelist()` reverts when not whitelisted
- [x] `addToWhitelist()` reverts when zero address
- [x] `removeFromWhitelist()` success
- [x] `removeFromWhitelist()` reverts when not whitelisted
- [x] `withdrawToken()` success
- [x] `withdrawToken()` reverts when not whitelisted
- [x] Fuzz tests (2 tests)
- [x] Gas benchmarks (2 tests)
- [x] Edge cases (3 tests)

#### Manager Contract ⏳
- [ ] Constructor validation
- [ ] `receive()` fee distribution
- [ ] `burn()` success
- [ ] `burn()` reverts when not owner
- [ ] `burn()` reverts when amount exceeds fee
- [ ] `fundReferral()` success
- [ ] `fundReferral()` reverts
- [ ] `withdrawTeamFee()` success
- [ ] `withdrawTeamFee()` reverts
- [ ] Fee splitting logic
- [ ] Gas benchmarks
- [ ] Fuzz tests

#### MangoToken Contract ⏳
- [ ] Constructor initialization
- [ ] `_transfer()` with taxes
- [ ] `addPair()` success
- [ ] `addV3Pool()` success
- [ ] `excludeAddress()` success
- [ ] `setTaxWallet()` success
- [ ] `autoDetectV3Pools()` success
- [ ] Tax calculations (buy/sell)
- [ ] Gas benchmarks for `_transfer()`
- [ ] Fuzz tests

#### MangoReferral Contract ⏳
- [ ] Constructor validation
- [ ] `distributeReferralRewards()` success
- [ ] `distributeReferralRewards()` reverts when not whitelisted
- [ ] `getReferralChain()` success
- [ ] `addReferralChain()` success
- [ ] `addRouter()` success
- [ ] `depositTokens()` success
- [ ] Referral chain building (5 levels)
- [ ] Lifetime earnings tracking
- [ ] Gas benchmarks
- [ ] Fuzz tests

#### MangoRouter Contract ⏳
- [ ] Constructor validation
- [ ] `swap()` ETH → Token
- [ ] `swap()` Token → ETH
- [ ] `swap()` Token → Token
- [ ] Fee calculation
- [ ] Referral integration
- [ ] Pool discovery (V2/V3)
- [ ] `changeTaxMan()` success
- [ ] `setReferralContract()` success
- [ ] Gas benchmarks
- [ ] Fuzz tests

#### Presale Contract ⏳
- [ ] Constructor validation
- [ ] `buyTokens()` success
- [ ] `buyTokens()` reverts when presale ended
- [ ] `buyTokens()` reverts when amount exceeds max
- [ ] `getAmountOutETH()` calculation
- [ ] `setPrice()` success
- [ ] `endPresale()` success
- [ ] `withdrawETH()` success
- [ ] `withdrawTokens()` success
- [ ] Referral integration
- [ ] Gas benchmarks
- [ ] Fuzz tests

---

## 4. Test Implementation Guide

### 4.1 Running Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/AirdropTest.t.sol

# Run with gas report
forge test --gas-report

# Run with verbosity
forge test -vvv

# Run fuzz tests
forge test --fuzz-runs 1000

# Run fork tests (requires RPC endpoints)
forge test --fork-url $BASE_RPC
```

### 4.2 Gas Benchmarking

```bash
# Generate gas report
forge test --gas-report > gas-report.txt

# Compare gas costs
forge snapshot
forge test --gas-report
forge snapshot --diff
```

### 4.3 Coverage Reports

```bash
# Generate coverage report (requires forge coverage)
forge coverage
forge coverage --report lcov
```

---

## 5. Test Helper Contracts

### 5.1 Mock Contracts

Create mock contracts for testing:

- `MockERC20.sol` - ERC20 token for testing
- `MockRouter.sol` - Mock router for testing
- `MockReferral.sol` - Mock referral contract
- `MockUniswapFactory.sol` - Mock Uniswap factory

### 5.2 Test Utilities

- `TestHelpers.sol` - Common test utilities
- `GasBenchmarkHelpers.sol` - Gas measurement utilities

---

## 6. Test Implementation Status

### Phase 1: Unit Tests ✅ In Progress
- [x] AirdropTest.t.sol (Created)
- [ ] ManagerTest.t.sol
- [ ] MangoTokenTest.t.sol
- [ ] MangoReferralTest.t.sol
- [ ] MangoRouterTest.t.sol
- [ ] PresaleTest.t.sol

### Phase 2: Integration Tests ⏳ Pending
- [ ] IntegrationTest.t.sol
- [ ] RouterReferralIntegrationTest.t.sol
- [ ] ManagerRouterIntegrationTest.t.sol

### Phase 3: Gas Benchmarks ⏳ Pending
- [ ] GasBenchmarks.t.sol

### Phase 4: Fuzz Tests ⏳ Pending
- [ ] FuzzTests.t.sol

### Phase 5: Fork Tests ⏳ Pending
- [ ] ForkTests.t.sol

### Phase 6: Coverage Reports ⏳ Pending
- [ ] Setup coverage reporting
- [ ] Generate initial coverage report
- [ ] Set coverage targets

---

## 7. Next Steps

1. **Complete AirdropTest.t.sol** - Verify compilation and fix any issues
2. **Create ManagerTest.t.sol** - Comprehensive manager tests
3. **Create MangoTokenTest.t.sol** - Token and tax tests
4. **Create MangoReferralTest.t.sol** - Referral system tests
5. **Create MangoRouterTest.t.sol** - Router swap tests
6. **Create PresaleTest.t.sol** - Presale tests
7. **Create IntegrationTest.t.sol** - Full system tests
8. **Create GasBenchmarks.t.sol** - Gas measurement tests
9. **Create FuzzTests.t.sol** - Property-based tests
10. **Setup Coverage Reporting** - Track test coverage

---

**Last Updated:** 2025-01-XX  
**Status:** Implementation in Progress

