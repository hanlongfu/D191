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
		

-- create the functions that performs the transformation
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

--  creates a trigger on the detailed table of the report that will continually update the summary table as data is added to the detailed table. 
truncate summary;
insert into summary (
	category_id_name,
	category_cnt
) select 
	combo(category_id, category_name) as category_id_name,
	count(*) as category_cnt
   from detailed
   group by combo(category_id, category_name)
   order by category_cnt desc;


-- stored procedure to be called using trigger function
create or replace procedure refresh_summary()
language plpgsql
as $$
begin
	-- clear both tables
	truncate detailed;
	truncate summary;

	-- insert into the detailed table
	insert into detailed( customer_id,rental_id,inventory_id,film_id, category_id,category_name
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
		
	-- insert into the summary table
	insert into summary (
	category_id_name,
	category_cnt
	) select 
	combo(category_id, category_name) as category_id_name,
	count(*) as category_cnt
	from detailed
	group by combo(category_id, category_name)
	order by category_cnt desc;
	
end; $$

-- trigger must be paired with a trigger function
create or replace trigger refresh_summary_trigger
	after insert 
on payment -- one of the base tables
	for each statement
	execute procedure insert_trigger_function();

-- trigger function
-- trigger function calles the stored procedure
create or replace function insert_trigger_function()
returns trigger
language plpgsql
as $$
begin
	-- call the stored procedure to refresh summary table
	call refresh_summary();
	return NEW;
end; $$


--- check whether trigger and stored procedure is working

-- check customer 341 
select count(*) from detailed where customer_id=341 group by customer_id;   -- n=24

-- insert some data base tables to verify trigger and stored procedure 

insert into category (name, last_update) values ('Gothic', '2021-10-05 14:01:10');  
insert into film(title, language_id) values ('Totally made up film', 1);   

select * from film order by film_id desc;
select * from category;

insert into film_category(film_id, category_id, last_update) values (1008, 24, '2006-02-15 10:07:09');
insert into inventory(film_id, store_id, last_update)   
	values (1008, 2, '2020-10-05 14:01:10');	
	
select * from inventory order by inventory_id desc;

insert into rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
     values ('2020-10-05 14:01:10', 4589, 341, '2020-10-05 14:01:10', 2, '2020-10-05 14:01:10');

insert into payment(customer_id, staff_id, rental_id, amount, payment_date) 
	values(341, 2, 4589, 200.50, '2020-10-05 14:01:10')

delete from rental where inventory_id = 4588;
delete from inventory where film_id = 1007;
delete from film_category where category_id = 23;
delete from film where title = 'Totally made up film';
delete from category where name = 'Gothic';



select * from detailed where customer_id=341;
