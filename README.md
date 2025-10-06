# 🤝 Freelancer Escrow Platform

A secure smart contract platform for freelance project payments with milestone-based releases on the Stacks blockchain.

## 🚀 Features

- 💰 **Secure Escrow**: Client funds are held in smart contract until milestones are completed
- 🎯 **Milestone Management**: Break projects into manageable milestones with individual payments
- ⚖️ **Dispute Resolution**: Built-in dispute mechanism with contract owner arbitration
- 🔒 **Trust & Security**: Blockchain-based transparency and automated payments
- 📊 **Project Tracking**: Complete project lifecycle management

## 🛠️ How It Works

### For Clients 👨‍💼

1. **Create Project**: Define project details, freelancer, and total budget
2. **Add Milestones**: Break down project into milestones with specific amounts
3. **Fund Project**: Deposit total amount into escrow
4. **Review Work**: Approve or reject milestone submissions
5. **Automatic Payments**: Funds released automatically upon milestone approval

### For Freelancers 👩‍💻

1. **Start Project**: Accept funded project and begin work
2. **Submit Milestones**: Submit completed work for client review
3. **Get Paid**: Receive payments automatically when milestones are approved
4. **Dispute Protection**: Raise disputes if issues arise

## 📋 Contract Functions

### Project Management
- `create-project` - Create new freelance project
- `fund-project` - Client deposits funds into escrow
- `start-project` - Freelancer accepts and starts project
- `cancel-project` - Cancel project and refund client

### Milestone Management
- `add-milestone` - Add milestone to project
- `submit-milestone` - Freelancer submits completed milestone
- `approve-milestone` - Client approves and releases payment
- `reject-milestone` - Client rejects milestone submission

### Dispute Resolution
- `raise-dispute` - Either party can raise dispute
- `resolve-dispute` - Contract owner resolves disputes

### Read Functions
- `get-project` - Get project details
- `get-milestone` - Get milestone information
- `get-project-milestones` - List all project milestones
- `get-project-funds` - Check remaining escrow funds
- `get-dispute` - Get dispute details

## 🎮 Usage Example

````clarity
;; Client creates a project
(contract-call? .freelancer-escrow create-project 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1000000 "Website Development")

;; Client adds milestones
(contract-call? .freelancer-escrow add-milestone u1 u300000 "Design mockups")
(contract-call? .freelancer-escrow add-milestone u1 u400000 "Frontend development")
(contract-call? .freelancer-escrow add-milestone u1 u300000 "Backend integration")

;; Client funds the project
(contract-call? .freelancer-escrow fund-
