# Wallet8:Wallet - Business Requirements & Functionality

> Audience: product owners, business analysts, and anyone evaluating what
> the **Wallet8 reference wallet app** does for the business. For
> architecture read `README.md`; for the vertical's standards baseline read
> the `wallet8` repository's `BUSINESS.md`.

## 1. Business Purpose

The reference wallet is the product a user actually touches, and the
artifact the certification suites actually drive. It exists for three
business reasons:

- **Prove the wallet role end to end.** A protocol library is a claim; a
  working app that scans an offer, receives a credential, and presents it
  is evidence.
- **Define the surface a vertical must ship.** A vertical's branded wallet
  is this app with different branding - so the surfaces here are the
  minimum product a wallet must offer, and the reference for what "done"
  looks like.
- **Make failures visible and honest.** Wallets fail in specific ways
  (expired offer, unsupported format, bad signature, unsatisfiable query).
  The app renders those as understandable states rather than a blank
  screen, which is both a product quality and a certification requirement.

## 2. Business Scope (What the App Provides)

| # | Capability | What the business gets |
|---|---|---|
| 1 | Vault surface | The user sees what credentials they hold, from whom, in which format |
| 2 | Scan intake | Accepts an issuer offer or a verifier request by QR code or deep link |
| 3 | Consent preview | Shows the exact claims a verifier requested before anything is disclosed |
| 4 | Presentation flow | Delivers the approved presentation, or records the decline |
| 5 | Error surface | States the failure in protocol terms the user can act on |
| 6 | Outcome landing | Confirms what was presented, to whom, and when |
| 7 | DC API shim | Implements the browser's Digital Credentials API bridge |
| 8 | Branding surface | Accent and logo are the app's; the protocol layer is not |

**What the app does NOT own (business boundary):**

| Out of scope | Owned by |
|---|---|
| Protocol drivers | `wallet8-flutter` (embedded) |
| Vault persistence and orchestration | `Wallet8:Holder` |
| Identity and tokens | Sentin8:Auth + Sentin8:BFF |
| The issuer and verifier roles | Sentin8:Auth |

## 3. Business Capabilities

| Capability | Business rule |
|---|---|
| Onboarding a credential | The user scans one code; the app handles the rest of the round |
| Presenting | The user sees the requested claims and approves or declines; nothing is presented implicitly |
| Failing well | Every protocol failure maps to a distinct, understandable screen |
| Staying thin | The app renders and routes; it holds no protocol judgment |
| Branding | A vertical changes accent, logo, and shell only |

## 4. Business Events (Outbound)

None directly. The app triggers holder operations, and the holder emits
the domain events (`wallet8:holder:credential:stored`,
`wallet8:holder:presentation:recorded`, and so on).

## 5. Business Rules & Invariants

1. **Nothing is presented without a consent screen.**
2. **The vault shows metadata, never credential material.**
3. **A failure is always a visible state**, never a silent no-op.
4. **No bearer token exists in the app**; all calls route through the
   BFF.
5. **The DC API path uses the same consent flow** as the QR path.

## 6. Target-User Roles & Use Cases

| Persona | Use case |
|---|---|
| Wallet end user | Receives a credential from an issuer and presents it to a verifier |
| Vertical product owner | Uses the app as the definition of the wallet surfaces to ship |
| Certification engineer | Drives the OIDF wallet plans against the app's rendered states |
| UX reviewer | Checks that consent and error states are honest and legible |

## 7. KPIs / Success Criteria

| KPI | Signal |
|---|---|
| Round completion | An issuance and a presentation each complete without leaving the app |
| Consent clarity | A user can state which claims they disclosed and to whom |
| Failure legibility | Every protocol failure reaches a distinct screen with an actionable message |
| Certification readiness | The rendered surfaces satisfy the wallet-role conformance plans |

## 8. Dependencies & Reliance on Other Services

| Dependency | Why |
|---|---|
| `wallet8-flutter` | The credential store and protocol drivers |
| `Wallet8:Holder` | The vault and orchestration backend |
| Sentin8:BFF | The only backend path for the app |
| Sentin8:Auth | The issuer and verifier the flows connect to |

## 9. Acceptance Criteria

1. The app boots to the vault and lists the user's credentials.
2. Scanning an offer URI lands the credential in the vault.
3. Scanning a verifier request reaches the consent screen with the
   requested claims.
4. A bad-signature request renders the error screen.
5. A missing nonce renders the error screen.
6. An unsatisfiable query renders the error screen.
7. Declining answers `access_denied`, never an empty presentation.

## 10. Open Business Questions

- Whether the reference app should remain a web-first reference or grow
  into a distributable store-listed wallet.
- Whether error screens should expose the underlying protocol error code
  to end users or only to developers.
