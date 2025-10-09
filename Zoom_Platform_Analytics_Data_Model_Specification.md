# Data Model Specification
**Source Document:** Zoom_Platform_Analytics_Systems_Reports-Requirements-Old.docx  
**Processed On:** 2024-06-09  
**Extraction Note:** All entities and attributes below were extracted directly from the provided document. Calculated metrics and KPIs are noted but not modeled as physical columns unless explicitly described.

## Table-Level Definitions

| Table Name      | Business Description                                                                                 |
|-----------------|-----------------------------------------------------------------------------------------------------|
| users           | Stores information about platform users, including plan type, company, and identifiers.             |
| meetings        | Represents scheduled meetings hosted on the Zoom platform, including duration and timestamps.        |
| attendees       | Tracks individual participants in meetings, linking users to meetings.                              |
| features_usage  | Records usage of specific platform features by users within meetings.                               |
| support_tickets | Captures customer support interactions, ticket types, status, and resolution details.               |
| billing_events  | Logs billing-related events for users, including revenue and event type.                            |
| licenses        | Manages license assignments, types, and validity periods for users.                                 |

## Column-Level Details

### users

| Column Name   | Business Description                       | Data Type      | Constraints                        | Domain Values           |
|---------------|-------------------------------------------|----------------|-------------------------------------|-------------------------|
| user_id       | Unique identifier for each user            | INT            | PRIMARY KEY, NOT NULL, UNIQUE       |                         |
| plan_type     | Type of user plan (e.g., Free, Paid)       | VARCHAR(20)    | NOT NULL                            | Free, Paid              |
| company       | Company or organization of the user        | VARCHAR(100)   |                                     |                         |
| user_name     | Name of the user                           | VARCHAR(100)   |                                     |                         |
| email         | Email address of the user                  | VARCHAR(100)   | UNIQUE                              |                         |
| sign_up_date  | Date the user registered                   | DATE           | NOT NULL                            |                         |

### meetings

| Column Name      | Business Description                              | Data Type      | Constraints                        | Domain Values           |
|------------------|--------------------------------------------------|----------------|-------------------------------------|-------------------------|
| meeting_id       | Unique identifier for each meeting                | INT            | PRIMARY KEY, NOT NULL, UNIQUE       |                         |
| host_id          | User who hosted the meeting                       | INT            | FOREIGN KEY (users.user_id), NOT NULL|                         |
| start_time       | Meeting start timestamp                           | DATETIME       | NOT NULL                            |                         |
| end_time         | Meeting end timestamp                             | DATETIME       |                                     |                         |
| duration_minutes | Duration of the meeting in minutes                | INT            | NOT NULL, CHECK >= 0                |                         |
| topic            | Meeting topic/title                               | VARCHAR(255)   |                                     |                         |
| created_at       | Timestamp when meeting was created                | DATETIME       |                                     |                         |

### attendees

| Column Name   | Business Description                       | Data Type      | Constraints                        | Domain Values           |
|---------------|-------------------------------------------|----------------|-------------------------------------|-------------------------|
| attendee_id   | Unique identifier for each attendee        | INT            | PRIMARY KEY, NOT NULL, UNIQUE       |                         |
| meeting_id    | Meeting attended                          | INT            | FOREIGN KEY (meetings.meeting_id), NOT NULL |                  |
| user_id       | User attending the meeting                 | INT            | FOREIGN KEY (users.user_id), NOT NULL|                         |
| join_time     | Timestamp when attendee joined             | DATETIME       |                                     |                         |
| leave_time    | Timestamp when attendee left               | DATETIME       |                                     |                         |

### features_usage

| Column Name   | Business Description                       | Data Type      | Constraints                        | Domain Values           |
|---------------|-------------------------------------------|----------------|-------------------------------------|-------------------------|
| usage_id      | Unique identifier for feature usage record | INT            | PRIMARY KEY, NOT NULL, UNIQUE       |                         |
| meeting_id    | Meeting in which feature was used          | INT            | FOREIGN KEY (meetings.meeting_id), NOT NULL |                  |
| user_id       | User who used the feature                  | INT            | FOREIGN KEY (users.user_id), NOT NULL|                         |
| feature_name  | Name of the feature used                   | VARCHAR(50)    | NOT NULL                            | [List from platform]    |
| usage_count   | Number of times feature was used           | INT            | NOT NULL, CHECK >= 0                |                         |

### support_tickets

| Column Name       | Business Description                          | Data Type      | Constraints                        | Domain Values           |
|-------------------|----------------------------------------------|----------------|-------------------------------------|-------------------------|
| ticket_id         | Unique identifier for each support ticket     | INT            | PRIMARY KEY, NOT NULL, UNIQUE       |                         |
| user_id           | User who opened the ticket                    | INT            | FOREIGN KEY (users.user_id), NOT NULL|                         |
| ticket_type       | Type/category of the support ticket           | VARCHAR(50)    | NOT NULL                            | audio, connectivity, ...|
| resolution_status | Current status of the ticket                  | VARCHAR(20)    | NOT NULL                            | open, closed, pending   |
| open_date         | Date ticket was opened                        | DATE           | NOT NULL                            |                         |
| close_time        | Timestamp when ticket was closed              | DATETIME       |                                     |                         |
| company           | Company of the user who opened the ticket     | VARCHAR(100)   |                                     |                         |

### billing_events

| Column Name   | Business Description                       | Data Type      | Constraints                        | Domain Values           |
|---------------|-------------------------------------------|----------------|-------------------------------------|-------------------------|
| billing_id    | Unique identifier for billing event        | INT            | PRIMARY KEY, NOT NULL, UNIQUE       |                         |
| user_id       | User associated with the billing event     | INT            | FOREIGN KEY (users.user_id), NOT NULL|                         |
| event_type    | Type of billing event                      | VARCHAR(50)    | NOT NULL                            | purchase, renewal, ...  |
| amount        | Amount involved in the billing event       | DECIMAL(10,2)  | NOT NULL, CHECK > 0                 |                         |
| event_date    | Date of the billing event                  | DATE           | NOT NULL                            |                         |

### licenses

| Column Name           | Business Description                          | Data Type      | Constraints                        | Domain Values           |
|-----------------------|----------------------------------------------|----------------|-------------------------------------|-------------------------|
| license_id            | Unique identifier for each license            | INT            | PRIMARY KEY, NOT NULL, UNIQUE       |                         |
| assigned_to_user_id   | User assigned to the license                  | INT            | FOREIGN KEY (users.user_id), NOT NULL|                         |
| license_type          | Type of license                               | VARCHAR(50)    | NOT NULL                            | [List from platform]    |
| start_date            | License start date                            | DATE           | NOT NULL                            |                         |
| end_date              | License end date                              | DATE           | NOT NULL, CHECK end_date > start_date|                         |

## Comments / Notes

- [ ] Feature names, license types, ticket types, and resolution statuses should be confirmed with business stakeholders for complete domain value lists.
- [ ] Calculated metrics (e.g., DAU/WAU/MAU, MRR, churn rate) are not modeled as physical columns but should be implemented in reporting logic.
- [ ] User anonymization/masking for sensitive fields (email, user_name) should be handled at the application/reporting layer as per security requirements.
- [ ] Meeting issues/ticket linkage is implied but not directly modeled; consider adding a meeting_issue_id or similar if required.
- [ ] Maximum lengths for VARCHAR fields are set based on standard practice; confirm with business if stricter limits are needed.
