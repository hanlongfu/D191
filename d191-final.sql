-- create the detailed table
drop table if exists detailed;
create table detailed (
        customer_id integer,
        rental_id integer,
        inventory_id integer,
        film_id integer,
        category_id integer,
        category_name varchar(50)
);

-- create the summary table
drop table if exists summary;
create table summary(
        category_id_name varchar(100),
        category_cnt integer
);

-- Insert data into detailed table
truncate detailed;
insert into detailed(customer_id,rental_id,inventory_id,film_id, category_id,category_name
) with sub as(
	select 
			customer_id
			, sum(amount) as revenue
	from payment
	group by customer_id
	order by revenue desc
), ten_pct as (
	select
		customer_id
		, revenue
		, ntile(10) over(order by revenue desc) as top_10_pct
	from sub
), top_10_pct_customers as(
	select
        customer_id
        , revenue
	from ten_pct
	where top_10_pct = 1
), top_10_pct_cust as (
	select 
		customer_id
		, rental_id
	from payment
	where customer_id in (
			select customer_id 
			from top_10_pct_customers)
), rental as (
	select b.*
		   , inventory_id 
	from rental a
	right join top_10_pct_cust b
		on a.rental_id = b.rental_id
		and a.customer_id = b.customer_id
), inventory as (
	select a.*
		, b.film_id
	from rental a
	left join inventory b
		on a.inventory_id = b.inventory_id
), cat_id as (
	select a.*
		, b.category_id
	from inventory a
	left join film_category b
		on a.film_id = b.film_id
) select a.*,
	 	b.name category_name
	from cat_id a
	left join category b
		on a.category_id = b.category_id;
		
select * from detailed;

-- create the function that performs the transformation
create or replace function combo(cat_id integer, cat_name varchar(50))
	returns varchar(100)
	language plpgsql
as
$$
declare cat_id_name varchar(100);
begin
	select cat_id||'-'||cat_name into cat_id_name;
	return cat_id_name;
end
$$

------------------------------------------------------------
-- update the summary table
-- this function updates the summary table with fresh data from the detailed table
------------------------------------------------------------
create function refresh_summary()
returns trigger
language plpgsql
as $$
begin
-- this will empty the summary table
truncate summary;
-- insert data into the summary table
insert into summary (
	category_id_name,
	category_cnt
) select 
	combo(category_id, category_name) as category_id_name,
	count(*) as category_cnt
   from detailed
   group by combo(category_id, category_name)
   order by category_cnt desc;
return new;
end $$

------------------------------------------------------------
-- create the trigger
-- this trigger execute the function from above whenenver new data is added to the detailed table
------------------------------------------------------------
create or replace trigger refresh_summary_trigger
after insert on detailed
for each statement
execute procedure refresh_summary();


------------------------------------------------------------
-- create the stored procedure
-- 
------------------------------------------------------------
create procedure refresh_tbls()
language plpgsql
as $$
begin

-- clear the tables
truncate detailed;
--
insert into detailed(customer_id,rental_id,inventory_id,film_id, category_id,category_name
) with sub as(
	select 
		customer_id
		, sum(amount) as revenue
	from payment
	group by customer_id
	order by revenue desc
), ten_pct as (
	select
		customer_id
		, revenue
		, ntile(10) over(order by revenue desc) as top_10_pct
	from sub
), top_10_pct_customers as(
	select
        customer_id
        , revenue
	from ten_pct
	where top_10_pct = 1
), top_10_pct_cust as (
	select 
		customer_id
		, rental_id
	from payment
	where customer_id in (
			select customer_id 
			from top_10_pct_customers)
), rental as (
	select b.*
	   	, inventory_id 
	from rental a
	right join top_10_pct_cust b
		on a.rental_id = b.rental_id
		and a.customer_id = b.customer_id
), inventory as (
	select a.*
		, b.film_id
	from rental a
	left join inventory b
		on a.inventory_id = b.inventory_id
), cat_id as (
	select a.*
		, b.category_id
	from inventory a
	left join film_category b
		on a.film_id = b.film_id
) select a.*,
	 	b.name category_name
	from cat_id a
	left join category b
		on a.category_id = b.category_id;
		
end; 
$$


call refresh_tbls();

select * from detailed;
select * from summary;
















