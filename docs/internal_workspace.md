OMC Internal Operations Hub — Final Plan

Internal Workspace customer app ka copy nahi hoga. Ye sirf Admin / Manager / Internal Staff ke liye operations control center hoga.

Customer side mein user apni service request, documents, payments dekhega.
Admin side mein staff customers ke records, unki services, un services ke documents/payments/status manage karega.

Current repo mein internal workspace abhi summary cards + shortcuts tak limited hai: Service Cases, Leads, Customers, Tasks, Payments. Isko proper hub banana hai.

1. Internal Hub ka main purpose

Admin yahan se ye sab kar sake:

Customer select karo
→ uski services dekho
→ service ke documents dekho
→ service ke payments dekho
→ status / review / notes / actions handle karo

Matlab data relation ye hogi:

Customer
  └── Service Requests
        ├── Required Documents
        ├── Uploaded Documents
        ├── Payments / Receipts
        ├── Support / Notes
        └── Status / Progress

Admin ke liye sab kuch customer + service request context mein hona chahiye.

2. Internal Workspace Home

Ye landing page hoga.

Top section

Small clean header:

OMC Operations Hub
Manage customers, services, documents and payments.

Below:

Search customer / phone / CNIC / NTN / service ID

Search ka kaam:

Customer search
Service request reference search
Phone/email/CNIC/NTN search
Direct open customer or service
Focus summary

Small cards/chips:

Needs document review
Pending payments
Active services
Waiting customer
Overdue / stuck requests
Open leads
Pending tasks

No huge hero. Compact, premium, operational.

3. Today / Priority Queue

Ye most important section hoga.

Admin ko pehle yahi dikhna chahiye:

Needs Attention

Items examples:

Ali Khan · Tax Filing 2026
2 documents need review
[Open]

Hassan Traders · Company Registration
Payment receipt uploaded
[Review]

Sara Ahmed · NTN Registration
Waiting for customer documents
[Open]

Each queue item mein:

Customer name
Service title
Service reference
Status badge
What needs action
Direct button

Priority queue mixed hogi:

Documents pending review
Payment receipts uploaded
Rejected documents needing follow-up
Waiting customer
Service in review too long
Pending internal tasks
4. Work Areas

Home page par clean work area grid hoga:

Service Requests

Admin all customers ki service requests dekhega.

Filters:

Active
Open
In Review
In Progress
Waiting Customer
Waiting Payment
Completed
Cancelled
All

Service card actions:

Open service
Open customer
View documents
View payments
Update status
Add internal note later

Important: yahan add service request optional rahega. Pehle admin view/manage karega.

Customers

Customer 360 center.

Customer list filters:

Approved
Pending approval
Active
Has pending docs
Has pending payment
All

Customer detail page tabs:

Overview | Services | Documents | Payments | Support | Activity

Overview shows:

Name
Email
Phone
CNIC
NTN
Company
Customer status
Active services count
Pending docs count
Pending payments amount

Main actions:

Open latest service
View documents
View payments
Contact customer
Approve/review customer if needed

This page is critical. Admin should not jump around blindly.

Documents

Admin document review center.

Default filter:

Needs Review

Filters:

Needs Review
Uploaded
Missing
Approved
Rejected
Archived
All

Document card:

CNIC Front
Ali Khan · Tax Filing 2026 · SR-00012

[Needs Review] [Required]

Uploaded 2h ago

[Preview] [Download] [Approve] [Reject]

Actions:

Preview file
Download file
Approve document
Reject with reason
Open related service
Open related customer

Admin yahan se customer ke uploaded docs ko properly review karega. Customer side se uploaded document status update hota rahega.

Payments

Yahan payment customer side payment tracker nahi hoga.
Ye admin review/check/payment control view hoga.

Payment relation:

Customer → Service Request → Payment

Filters:

Pending
Receipt Uploaded
Under Review
Received
Rejected
Overdue
All

Payment card:

PKR 25,000
Ali Khan · Tax Filing 2026 · SR-00012

[Receipt Uploaded] [Needs Review]

[View Receipt] [Approve] [Reject] [Open Service]

Functionality:

See who paid
See who did not pay
See payment receipt
Approve receipt
Reject receipt with reason
Open related customer/service
Later: create payment request from service

Important: payment add/create admin side ka flow service detail ke andar better hoga, not main payment queue. Main payment queue review/check ke liye hogi.

Leads

Lead management clean hoga.

Filters:

New
Contacted
Qualified
Converted
Lost
All

Lead card:

Lead name
Phone/email
Interested service
Source
Status
Next follow-up

Actions:

Open lead
Convert to customer later
Assign task later
Tasks

Internal work execution.

Filters:

My Tasks
Team Tasks
Pending
Overdue
Completed
All

Task card:

Title
Linked customer/service if any
Due date
Assigned user
Priority
Status

Actions:

Open
Mark done
Open related customer/service
5. Service Detail for Admin

This should become the strongest page.

When admin opens a service request, page should show complete case workspace.

Sections
Header
Tax Filing 2026
SR-00012 · Ali Khan

[In Review] [Payment Pending]

Actions:

Update status
Open customer
Contact customer
Customer block
Name
Phone
Email
CNIC
NTN
Company
Status / progress block
Current status
Progress
Next step
Internal notes later
Customer action required yes/no
Required Documents

Show all required documents:

Missing
Uploaded
Under Review
Approved
Rejected

Actions:

Preview
Download
Approve
Reject
Payments

Show all payments for this service:

Amount
Due date
Status
Receipt status
Uploaded receipt

Actions:

View receipt
Approve
Reject
Mark received if allowed
Create payment request later
Activity Timeline

Show:

Customer uploaded document
Admin approved document
Payment receipt uploaded
Status changed
Support message added

This makes the service request the real operational center.

6. Navigation logic

Internal staff should have two ways to work:

A. Queue-first flow
Internal Workspace
→ Needs Review item
→ Open document/service
→ Approve/reject
B. Customer-first flow
Internal Workspace
→ Search customer
→ Customer 360
→ Services
→ Service detail
→ Documents/payments/actions

Both are needed.

Queue-first is fast for daily operations.
Customer-first is best when admin is handling a specific client call.

7. Styling rules
Visual style

Use:

Clean white cards
Light grey background
OMC red only for brand/accent
Semantic status colors
Compact rows
Less big gradient
More readable admin-style layout

Admin UI should be denser than customer UI, but not crowded.

Card style

Internal cards should show more information in less height:

Customer Name
Service title · Reference
[Status] [Docs] [Payment]
Last update
Actions
Bottom nav spacing

Every shell page must have enough bottom padding.

Use standard:

EdgeInsets.fromLTRB(20, 18, 20, 164)

For current workspace, bottom padding is only 30, so floating nav can cover last blocks. Same fix should apply to loading/empty states too.

Best: create shared shell padding constants later and apply everywhere.

8. What exactly we will build

Final build list:

Redesigned Internal Workspace Home
Search
Focus summary
Priority queue
Work areas grid
Recent activity placeholder if backend supports later
Service Requests Admin Queue
Better filters
Better cards
Customer/service/payment/document quick actions
Customer 360
Overview
Services
Documents
Payments
Activity/support later
Document Review Center
Needs Review default
Preview/download/approve/reject
Open service/customer
Payment Review Center
Pending/receipt uploaded/received/rejected filters
View receipt
Approve/reject
Open service/customer
Service Detail Admin Mode
Customer info
Documents
Payments
Status/progress
Activity timeline
Global shell spacing fix
All pages get bottom padding so nav never hides last block
Final product feel

Admin opens app and sees:

What needs attention today?
Which customer is this?
Which service is this linked to?
Are documents complete?
Has payment been made?
What action should I take now?
