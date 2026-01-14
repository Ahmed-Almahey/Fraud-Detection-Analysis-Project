
--Data warehouse Exploration


--Explore all objects in the database
select * from INFORMATION_SCHEMA.TABLES


--Explore all columns in the database
select * from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'dim_customer'



--Dimensions Exploration


--Explore all merchants that the system deals with 

select distinct merchant_name from Dim_Merchant

select distinct merchant_category from Dim_Merchant
order by 1

--Explore Different Regions where customers come from 
select distinct zip_code from Dim_Customer



--Date Exploration



--Find the date of the first and last transaction 
--how many years on transactions are available
select min(date) as first_transaction_date, max(date) as last_transaction_date,
datediff(year,min(date),max(date)) as transactions_range_years
from Fact_Transactions t join DimDate d
on t.DateID_FK = d.DateSK

--Find the date of the first and last transaction in the OLTP 
select min(cast(transaction_datetime as date)) as first_date, max(cast(transaction_datetime as date)) as last_date 
from Transactions


--Find the youngest and oldest customers
select min(birthdate) as oldest_birthdate,
datediff(year,min(birthdate),getdate()) as oldest_age ,
 datediff(year,max(birthdate),getdate()) as youngest_age 
 ,max(birthdate) as youngest_birthdate
from Dim_Customer




--Measures Exploration

--Find the total transactions amount
select sum(amount) as total_amount 
from Fact_Transactions


--Find how many transactions detected fraud
select count(*) as number_of_detected_fraud_transactions
from Fact_Transactions
where Is_Flaged_Fraud = 1

--Find how many rows are fraud
select count(*) as number_of_fraud_transactions
from Fact_Transactions
where Is_Fraud = 1

--Find number of transactions that are fraud and were detected fraud
select count(*) as number_of_fraud_transactions_detected_fraud
from Fact_Transactions
where Is_Fraud = 1 and Is_Flaged_Fraud=1

--Find number of transactions that are fraud but weren't detected fraud
select count(*) as number_of_fraud_not_detected_fraud
from Fact_Transactions
where is_fraud = 1 and Is_Flaged_Fraud =0



--Generate a report that shows all key metrics of the business

select 'total_amount' as measure_name, sum(amount) as measure_value  
from Fact_Transactions
union all
select 'number_of_detected_fraud_transactions' ,count(*) 
from Fact_Transactions
where Is_Flaged_Fraud = 1
union all 
select 'number_of_fraud_transactions' ,count(*) 
from Fact_Transactions
where Is_Fraud = 1
union all 
select 'number_of_fraud_transactions_detected_fraud' ,count(*) 
from Fact_Transactions
where Is_Fraud = 1 and Is_Flaged_Fraud=1
union all 
select 'number_of_fraud_not_detected_fraud' ,count(*) 
from Fact_Transactions
where is_fraud = 1 and Is_Flaged_Fraud =0



--Magnitude Analysis

--Find Sending Customers Involved in Fraudulent Activity
select Customer_Name, count(*) as number_of_Fraud_by_Sender_Customer
from Fact_Transactions t left join Dim_Customer c
on t.Customer_Sender_id_FK = c.Customer_SK
where Is_Fraud = 1
group by Customer_Name
order by 2 desc

--Find Fraud Occurrence by Customer Risk Tier
select Risk_Segment, count(*) as number_of_Fraud_by_Customer_risk_segment
from Fact_Transactions t left join Dim_Customer c
on t.Customer_Sender_id_FK = c.Customer_SK
where Is_Fraud = 1
group by Risk_Segment
order by 2 desc

--Find total fraud amount by Merchant Category
select Merchant_Category, sum(Amount) as Total_Fraud_Amount_by_Merchant_Category
from Fact_Transactions t left join Dim_Merchant m
on t.Merchant_Sender_id_FK = m.Merchant_SK
where Is_Fraud = 1
group by Merchant_Category
order by 2 desc

--Find Fraud Activity Across Payment Channels
select Channel, count(*) as number_of_Fraud_by_channel
from Fact_Transactions 
where Is_Fraud = 1
group by Channel
order by 2 desc

--Find Number of fraud transactions by account_type
select Account_Type, sum(Amount) as Total_Fraud_Amount_by_Account_Type
from Fact_Transactions t left join Dim_Account a
on t.Account_Sender_id_FK = a.Account_SK
where Is_Fraud = 1
group by Account_Type
order by 2 desc


--Find Merchants by Fraud Losses (Monetary Impact of Fraud by Merchant)
select Merchant_Name, sum(Amount) as Total_Fraud_Amount_by_Merchant_Name
from Fact_Transactions t left join Dim_Merchant m
on t.Merchant_Sender_id_FK = m.Merchant_SK
where Is_Fraud = 1
group by Merchant_Name
order by 2 desc



--Ranking Analysis

--Identify the top 5 customers who have sent the highest total fraud transaction amount.
select top 5 Customer_id_bk, customer_name, sum(amount) as total_fraud_amount
from Dim_Customer c join Fact_Transactions t
on c.Customer_SK = t.Customer_Sender_id_FK
where Is_Fraud = 1
group by Customer_id_bk,Customer_Name
order by total_fraud_amount desc


--Find the 3 merchants with the highest number of detected fraud transactions, excluding merchants with fewer than 10 total transactions.
select top 3 merchant_name, count(*) as number_of_detected_fraud
from Dim_Merchant m join Fact_Transactions f
on f.Merchant_Sender_id_FK = m.Merchant_SK
where Is_Flaged_Fraud = 1 and Is_Flaged_Fraud = 1
group by Merchant_Name
having count(*) >= 10 
order by number_of_detected_fraud desc


--For each risk segment, rank customers by total fraud amount, and find the top 2 senders per risk segment.
select * from
(select risk_segment, customer_name, sum(amount) as Total_Fraud_Amount, 
ROW_NUMBER() over(partition by risk_segment order by sum(amount) desc) as rn
from Fact_Transactions t join Dim_Customer c
on t.Customer_Sender_id_FK = c.Customer_SK 
where Is_Fraud = 1
group by Risk_Segment, Customer_Name) as new_table
where rn <= 2
order by Risk_Segment

--Find the top 3 channels with the highest total fraud amount, then calculate their percentage of total fraud volume.
with t as (
select sum(amount) as total_fraud_accross_channels
from Fact_Transactions
where Is_Fraud =1
)

select top 3 channel, sum(amount) as total_fraud_amount, cast(sum(amount)*100.0/max(t.total_fraud_accross_channels) as decimal(5,2)) as total_fraud_percentage
from Fact_Transactions cross join t
where Is_Fraud = 1
group by channel 
order by total_fraud_amount desc


--alternative solution
with total_per_channel as(
select channel, sum(amount) as total_fraud_amount
from Fact_Transactions
where Is_Fraud =1
group by Channel
)

, absolute_total_fraud as (
select sum(total_fraud_amount) as  total_fraud_accross_channels
from total_per_channel
)

select top 3 channel, total_fraud_amount, cast(total_fraud_amount*100.0/ total_fraud_accross_channels as decimal(5,2)) as fraud_amount_percentage
from total_per_channel  cross join absolute_total_fraud 
order by total_fraud_amount desc



--Generate Confusion Matrix
SELECT
    SUM(CASE WHEN is_fraud = 1 AND is_flaged_fraud = 1 THEN 1 ELSE 0 END) AS True_Positive,
    SUM(CASE WHEN is_fraud = 0 AND is_flaged_fraud = 1 THEN 1 ELSE 0 END) AS False_Positive,
    SUM(CASE WHEN is_fraud = 1 AND is_flaged_fraud = 0 THEN 1 ELSE 0 END) AS False_Negative,
    SUM(CASE WHEN is_fraud = 0 AND is_flaged_fraud = 0 THEN 1 ELSE 0 END) AS True_Negative
FROM Fact_Transactions;







--Analyze the trend of fraud over time. For each month, calculate the 3-month rolling average of 
--fraud transactions to identify periods with increasing or decreasing fraud activity.