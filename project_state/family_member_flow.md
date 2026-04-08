
## Project
Mess & Café Automation System

## Version Scope
Applies to Version 2 (Post V1 Launch Expansion)

## Status
LOCKED DESIGN DECISION

---

## 1. Background

Version 1 of the system is focused on core mess operations including:
- Breakfast
- Lunch
- Dinner
- BBQ (basic flow)
- Bakery (basic flow)

All flows are currently employee-centric, with:
- employee as booking entity
- employee as consumption entity
- billing aggregated at employee level

As system expands into **Café, Tuck Shop, and extended club services**, a need arises to:
- track consumption at **family member level**
- allow proxy booking for dependents
- provide better expense visibility for employees

---

## 2. Core Design Decision

### ❗ Family members will NOT be separate users

- No UID
- No login
- No authentication layer
- No independent identity

### ✔ Family members will exist ONLY as:
> A dependent list maintained under the employee profile

---

## 3. Conceptual Model

### Account vs Consumer Separation

| Concept | Definition |
|--------|-----------|
| Account Owner | Employee (billing entity) |
| Consumer | Self or selected family member |

---

## 4. Family Member Data Model

Family members will be stored under employee profile:

employee
├── employee_number
├── name
├── family_members[]


### Family Member Object


family_member
├── member_id
├── member_name
├── relationship
├── is_active
├── created_at
├── updated_at

employee
├── employee_number
├── name
├── family_members[]


---

## 5. Transaction Model (Future Flows)

All café/tuck shop/bakery transactions will include:


account_owner_employee_number
consumer_type → self | family_member
consumer_member_id (nullable)
consumer_member_name
consumer_relationship (optional)


---

## 6. Scope of Usage

### Family member flow will be enabled ONLY in:

| Module | Usage |
|--------|------|
| Café | YES |
| Tuck Shop | YES |
| Bakery | YES |
| BBQ | Optional future |
| Breakfast/Lunch/Dinner | NO |

---

## 7. Booking Flow (Future Design)

### Employee App

User selects:



---

## 6. Scope of Usage

### Family member flow will be enabled ONLY in:

| Module | Usage |
|--------|------|
| Café | YES |
| Tuck Shop | YES |
| Bakery | YES |
| BBQ | Optional future |
| Breakfast/Lunch/Dinner | NO |

---

## 7. Booking Flow (Future Design)

### Employee App

User selects:
Who is this for?
(•) Self
(•) Family Member → dropdown

---

### Club Staff / Proxy Booking

Flow:

1. Select Employee  
2. Select Consumer:
   - Self
   - Family Member (dropdown under employee)

---

## 8. Profile Management Flow

Employees will manage family members via:

### Employee Profile Screen

Capabilities:
- Add family member
- Edit family member
- Deactivate family member

### Governance Model

- Self-managed by employee
- No approval required initially
- Audit trail maintained (created_at / updated_at)

---

## 9. Notification Design Impact

### Current (V1)
- Notification only references employee

### Future (V2)

Notification must include consumer context:

#### Self
> "Your order has been issued."

#### Family Member
> "Your order for Ahmed has been issued."

or

> "Order issued for Ahmed under your account."

---

## 10. Reporting & Analytics Impact

### Employee Dashboard
- Total spend
- Breakdown by:
  - Self
  - Family members

### Admin Dashboard
- Consumption patterns
- Family vs employee usage
- Demand profiling

---

## 11. UI Design Principle

- Family member selection will appear ONLY in:
  - Café
  - Tuck Shop
  - Bakery

- No impact on:
  - Mess meal flows
  - Core reservation screens

---

## 12. Operational Time Models (V2 Extensions)

New service areas will reuse existing booking engine with time controls:

| Module | Timing |
|--------|--------|
| BBQ | Friday 19:00 – 22:00 |
| Café | Daily 19:00 – 23:00 |
| Bakery | Daily 17:00 – 22:00 |
| Tuck Shop | Daily 17:00 – 22:00 |

### Important
- No structural change required in booking engine
- Only:
  - new menu templates
  - adjusted time-window logic

---

## 13. Architectural Constraints

### Must NOT:
- introduce separate family user accounts
- modify existing mess reservation schema
- impact V1 stability

### Must:
- keep family members as lightweight dependent entities
- maintain clear separation between:
  - account owner
  - consumer

---

## 14. Implementation Strategy (Post V1)

### Phase 1
- Employee profile + family member CRUD

### Phase 2
- Consumer selection in café/tuck shop flows

### Phase 3
- Transaction tagging (consumer fields)

### Phase 4
- Notification enhancement

### Phase 5
- Reporting enhancement

---

## 15. Risks & Mitigation

| Risk | Mitigation |
|------|-----------|
| Fake dependents | Audit trail + optional future limits |
| UI clutter | Restrict usage to café/tuck shop |
| Scope creep | No change in mess flows |
| Complexity | No UID / no login for family members |

---

## 16. Final Decision Statement

> Family member functionality will be introduced in Version 2 as a dependent-based consumption model under employee profiles.  
> No separate user identities will be created.  
> This feature will be restricted to Café, Tuck Shop, and related club services, without impacting core mess operations.

---

## 17. Status

✔ Decision Locked  
✔ Ready for Version 2 Implementation Planning  
✔ No impact on Version 1 rollout

