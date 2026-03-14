# Mess & Café Automation Platform - Live Project Command Board

_Last updated: 14-Mar-2026_

## 1) Completed Development
- Foundation: Flutter, Firebase, Firestore, device deployment, Git repository, cloud project
- Authentication: login, logout, Firebase email/password
- Menu retrieval: Firestore connectivity, menu item joining, breakfast menu display
- Project maintenance baseline: NAS backup scripts, Git push workflow, updated markdown state files

## 2) Ongoing Development
- Version 1 requirement refinement
- Admin and bulk upload design
- Production-grade Firestore schema and indexing strategy
- Monthly menu + estimated rate workflow design

## 3) Next Verified Steps
- [ ] Admin dashboard shell
- [ ] Employee master manual add/edit
- [ ] Employee bulk upload
- [ ] Menu item manual add/edit
- [ ] Menu item bulk upload
- [ ] Monthly menu creation and edit
- [ ] Monthly menu bulk upload
- [ ] Employee self-registration / profile creation with approval logic
- [ ] Attendance / booking flow for breakfast, lunch, dinner
- [ ] Kitchen dashboard
- [ ] Manager dashboard
- [ ] Monthly billing generation with uploaded estimated rates

## 4) Version 1 Locked Scope
### 4.1 Operational scope
- Mess system only
- Breakfast, lunch, dinner
- Monthly menu publishing, valid until revised
- Employee-wise attendance booking
- Monthly billing generation from uploaded estimated rates
- Manual and bulk upload for employees, menu items, monthly menus, rates
- Employee/customer phone number captured in profile
- Employee app, manager/admin interface, kitchen dashboard

### 4.2 Business rules
- Users can self-create an account if not yet in the database
- Menu is changed monthly or whenever management revises it, not random daily changes
- Rates remain estimated until recipe-costing and purchase-costing are introduced in later versions

## 5) Parking Lot / Future Ideas
### Versioned roadmap
- V2: Café management
- V3: Tuck shop management
- V4: Bakery management
- V5: Inventory / bulk store
- V6: Purchase management
- V7: Recipe and service costing
- V8: Event management
- V9: Automated billing
- V10: Email / WhatsApp push messaging
- V11: Asset management

## 6) Verification Log
| Date | Module | What was verified | By | Result | Notes |
|---|---|---|---|---|---|
| 14-Mar-2026 | Foundation | Flutter/Firebase/Menu display | Dr. Humayun | Pass | Stable baseline |
|  |  |  |  |  |  |

## 7) Change Notes
- Use this section to capture scope clarifications, architecture decisions, and deferred items.
