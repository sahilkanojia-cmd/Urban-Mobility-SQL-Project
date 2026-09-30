# 🚕 Urban Mobility IQ — Ride-Sharing Data Analysis Using SQL

## 📌 Project Overview

**Urban Mobility IQ** is a SQL-based data analytics project focused on analyzing an urban ride-sharing platform.

The project uses a relational database containing information about rides, customers, drivers, vehicles, cities, payments, promotions, and ratings.

The objective is to transform transactional ride data into meaningful business insights using **MySQL and advanced SQL techniques**.

---

## 🎯 Business Objectives

This project answers key business questions around:

- Ride demand across cities
- Revenue-driving markets
- Vehicle-type preferences
- Driver performance
- Customer spending behavior
- Cancellation behavior
- Payment performance
- Promotion effectiveness
- Ratings and operational performance

---

## 🗄️ Database Overview

The database contains **8 relational tables** and **126,284 total records**.

| Table | Records |
|---|---:|
| Users | 3,000 |
| Drivers | 800 |
| Vehicles | 800 |
| Cities | 10 |
| Rides | 45,000 |
| Payments | 40,184 |
| Promotions | 6,802 |
| Ratings_Feedback | 29,688 |

---

## 🔗 Entity Relationship Diagram

The project uses an 8-table relational database with `Rides` acting as the central transactional table.

![Urban Mobility ERD](ERD/urban_mobility.png)

---

## 🔍 Key Business Questions

The analysis answers questions such as:

1. How many rides were completed?
2. Which cities have the highest ride volume?
3. Which cities generate the most revenue?
4. Which vehicle types are most popular?
5. Which vehicle types generate higher fares?
6. What are the major cancellation reasons?
7. Which drivers generate the highest revenue?
8. Which customers spend the most?
9. What payment methods are most used?
10. How effective are promotions?
11. What is the payment success/failure pattern?
12. How do ratings vary across the platform?

---

## 📊 Key Findings

### 🚕 Ride Demand

- Total rides analyzed: **45,000**
- Completed rides: **38,101**
- Cancelled rides: **4,604**
- No-show rides: **2,295**

### 🏙️ City Performance

Top cities by ride volume:

| City | Rides |
|---|---:|
| Hyderabad | 5,723 |
| Mumbai | 5,284 |
| Kolkata | 4,950 |
| Pune | 4,706 |
| Lucknow | 4,331 |

Hyderabad leads the platform in ride demand and completed-ride revenue.

### 🚗 Vehicle Analysis

| Vehicle Type | Rides |
|---|---:|
| Mini | 16,661 |
| Bike | 10,835 |
| Auto | 8,793 |
| Prime | 6,106 |
| XL | 2,605 |

Average fares:

| Vehicle Type | Average Fare |
|---|---:|
| XL | ₹192.34 |
| Prime | ₹151.54 |
| Mini | ₹108.68 |
| Auto | ₹79.36 |
| Bike | ₹54.90 |

Mini vehicles dominate ride volume, while XL and Prime have higher average fares.

### 👨‍💼 Driver & Customer Analysis

Top driver by revenue:

**Dipta Kannan — ₹13,547.66**

Top customer by spending:

**USR002542 — ₹3,224.01**

### 💳 Payment Analysis

| Payment Status | Transactions |
|---|---:|
| Success | 26,363 |
| Failed | 7,397 |
| Refunded | 6,424 |

### 🎁 Promotion Analysis

The **Festive Season Offer** generated the highest total discount:

**₹52,045.23**

---

## 🧠 SQL Skills Demonstrated

This project demonstrates practical use of:

- `SELECT`
- `WHERE`
- `GROUP BY`
- `ORDER BY`
- `JOIN`
- `CASE WHEN`
- Aggregate Functions
- Subqueries
- Common Table Expressions (CTEs)
- Window Functions
- `RANK()`
- `DENSE_RANK()`
- `PARTITION BY`

---

## 🚀 Advanced SQL Analysis

### CTE

Used CTEs to break complex analytical problems into reusable query layers.

### Window Functions

Used:

```sql
RANK()
DENSE_RANK()
PARTITION BY
ORDER BY
