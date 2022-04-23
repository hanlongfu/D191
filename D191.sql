 -- extract top 10% of paying customers and their respective revenue
create or replace view top_10_pct_customers as
with sub as(
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
)
select 
        customer_id
        , revenue
from ten_pct
where top_10_pct = 1;


-- match above with their corresponding film, film category, actor, and their address (city, country)
        -- 1. what are the favorite films including categories and actors of our top 10% paying customers?   
 
-- match above with their corresponding staff_id 
        -- 2. which staff are responsible for bringing in most money?


-- 1. what are the favorite films including categories and actors of our top 10% paying customers?

-- top 10% paying customers' payment and rental info
create or replace view top_10_pct_cust_payment as
select * 
from payment
where customer_id in (
        select customer_id 
        from top_10_pct_customers
); 

-- (payment) rental_id -> rental (inventory_id) -> inventory (film_id) 
--  -> film_actor(film_id) -> actor(actor_id)
--  -> film_category(film_id) -> category(category_id)

-- join table from above with rental table to get inventory_id
create or replace view top_10_pct_inventory as
select a.customer_id 
       , a.rental_id 
       , a.staff_id 
       , b.inventory_id 
from top_10_pct_cust_payment as a
inner join rental as b
        on a.customer_id = b.customer_id
              and a.staff_id = b.staff_id
              and a.rental_id = b.rental_id;
        

select * from top_10_pct_inventory;


-- join table from above with inventory table to get film_id
create or replace view top_10_pct_filmid as
select a.*,
       b.film_id,
       b.store_id
from top_10_pct_inventory as a
left join inventory as b
        on a.inventory_id = b.inventory_id;
     

-- join table from above with film_actor to get actor_id and film_category to get category_id
create or replace view top_10_pct_actor_catid as 
select a.*
       , b.actor_id
       , c.category_id
               , d.title
        , d.release_year
        , d.rental_rate
        , d.rental_duration
        , d.length
from top_10_pct_filmid as a
left join film_actor as b
        on a.film_id = b.film_id
left join film_category as c
        on a.film_id = c.film_id
left join film as d
        on a.film_id = d.film_id;


-- join actor table to get actor name and category table to get category name
create or replace view top_10_pct_final as
select a.*
        , b.first_name 
        , b.last_name
        , c.name as category_name
from top_10_pct_actor_catid as a
left join actor as b
        on a.actor_id = b.actor_id
left join category as c
        on a.category_id = c.category_id;

-- final actionable insights

-- calculate the distribution of film category
select a.category_name, count(*) as category_cnt
from top_10_pct_final as a
group by category_name 

-- calculate the distribution of actors
select 
        a.actor_id, 
        a.first_name ||' '|| a.last_name as actors, 
        count(*) as actor_count
from top_10_pct_final as a
group by a.actor_id,  a.first_name ||' '|| a.last_name 
order by actor_count desc;

-- calculate the distibution of films' rating, rental duration, length, and title etc.

-- length    
select a.length, count(*) as length_count
from top_10_pct_final as a
group by a.length
order by length_count desc


--film title
select a.title, count(*) as title_count
from top_10_pct_final as a
group by a.title
order by title_count desc


--rental duration
select a.rental_duration, count(*) as duration_count
from top_10_pct_final as a
group by a.rental_duration
order by duration_count desc