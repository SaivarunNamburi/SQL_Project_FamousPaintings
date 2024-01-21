-- 1. Fetch all the paintings which are not displayed on any museums?
select *
from public.work
where museum_id IS NULL;

-- 2. Are there museuems without any paintings?
select *
from public.museum
where not exists(select 1
                 from public.work
                 where work.museum_id = museum.museum_id);

-- 3. How many paintings have an asking price of more than their regular price?
select count(*) as total
from public.product_size
where product_size.sale_price > product_size.regular_price;

-- 4. Identify the paintings whose asking price is less than 50% of its regular price
select *
from public.product_size
where product_size.sale_price < (product_size.regular_price / 2);

-- 5. Which canva size costs the most?
select cs.label, ps.sale_price
from (select *, rank() over (order by product_size.sale_price desc ) as price_rnk
      from public.product_size) as ps
         join public.canvas_size cs
              on ps.size_id = cs.size_id::text
where price_rnk = 1;

-- 6. Delete duplicate records from work, product_size, subject and image_link tables
    -- work
delete
from public.work
where work_id not in
      (select min(work_id) from public.work group by work_id having count(*) > 1);

    -- product_size
delete
from public.product_size
where (work_id, size_id) not in
      (select work_id, size_id from public.product_size group by work_id, size_id having count(*) > 1);

    -- subject
delete
from public.subject
where (work_id, subject) not in
      (select work_id, subject from public.subject group by work_id, subject having count(*) > 1);

    -- image_link
delete
from public.image_link
where work_id not in
      (select min(work_id) from public.image_link group by work_id having count(*) > 1);

-- 7. Identify the museums with invalid city information in the given dataset
select *
from public.museum
where city ~ '[^0-9]';

-- 8. Museum_Hours table has 1 invalid entry. Identify it and remove it.
delete
from public.museum_hours
where museum_hours.museum_id not in
      (select min(museum_id)
       from public.museum_hours
       group by museum_id, day);

-- 9. Fetch the top 10 most famous painting subject
with cte as
         (select s.subject,
                 count(*)                             as no_of_paintings,
                 rank() over (order by count(1) desc) as ranking
          from public.subject s
                   join public.work w on s.work_id = w.work_id
          group by s.subject)

select *
from cte
where ranking <= 10;

-- 10. Identify the museums which are open on both Sunday and Monday. Display museum name, city.
select distinct m.name, m.city, m.state, m.country
from public.museum m
         join public.museum_hours mh
              on m.museum_id = mh.museum_id
where mh.day = 'Sunday'
  and exists(select 1
             from public.museum_hours mh2
             where mh2.museum_id = mh.museum_id
               and mh2.day = 'Monday');

-- 11. How many museums are open every single day?
select count(1)
from (select m.museum_id, count(1)
      from public.museum m
      group by m.museum_id
      having count(1) = 7) as tmp;

-- 12. Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
with cte as
         (select w.museum_id,
                 count(1)                             as no_of_paintings,
                 rank() over (order by count(1) desc) as ranking
          from public.work w
                   join public.museum m
                        on w.museum_id = m.museum_id
          group by w.museum_id)
select *
from cte
where ranking <= 5;

-- 13. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
with cte as
         (select w.artist_id,
                 a.first_name,
                 count(1)                             as no_of_paintings,
                 rank() over (order by count(1) desc) as ranking
          from public.work w
                   join public.artist a
                        on w.artist_id = a.artist_id
          group by w.artist_id, a.first_name)
select *
from cte
where ranking <= 5;

-- 14. Display the 3 least popular canva sizes
with cte as
         (select cs.size_id, cs.label, count(1) as no_of_sizes, dense_rank() over (order by count(1)) as rnk
          from public.product_size ps
                   join public.canvas_size cs on ps.size_id = cs.size_id::text
                   join public.work w on ps.work_id = w.work_id
          group by cs.label, cs.size_id)
select *
from cte
where rnk <= 3;

-- 15. Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
with cte as
         (select m.museum_id,
                 m.name,
                 m.state,
                 mh.open,
                 mh.close,
                 to_timestamp(mh.close, 'HH:MI AM') - to_timestamp(mh.open, 'HH:MI PM')                             as duration,
                 rank() over (order by to_timestamp(mh.close, 'HH:MI AM') -
                                       to_timestamp(mh.open, 'HH:MI PM') desc)                                      as rnk
          from public.museum_hours mh
                   join public.museum m on mh.museum_id = m.museum_id)

select museum_id, name, open, close, duration
from cte
where rnk = 1;

-- 16. Which museum has the most no of most popular painting style?
with cte as
         (select m.name, w.style, count(1) as no_of_paintings, rank() over (order by count(w.style) desc) as rnk
          from public.work w
                   join public.museum m
                        on w.museum_id = m.museum_id
          group by w.style, m.name)
select *
from cte
where rnk = 1;

-- 17. Identify the artists whose paintings are displayed in multiple countries
with cte as
         (select distinct a.first_name as artist, m.country
          from public.work w
                   join public.artist a on w.artist_id = a.artist_id
                   join public.museum m on w.museum_id = m.museum_id)
select artist, count(1) as no_of_countries
from cte
group by artist
having count(1) > 1
order by 2 desc;

-- 18. Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.
with cte_city as
         (select city,
                 count(1)                             as no_of_museum,
                 rank() over (order by count(1) desc) as rnk
          from public.museum
          group by city
          order by no_of_museum desc),

     cte_country as
         (select country,
                 count(1)                             as no_of_museum,
                 rank() over (order by count(1) desc) as rnk
          from public.museum
          group by country
          order by no_of_museum desc)
select string_agg(distinct cntry.country, ', '), string_agg(city.city, ', ')
from cte_country cntry
         cross join cte_city city
where cntry.rnk = 1
  and city.rnk = 1;

-- 19. Identify the artist and the museum where the most expensive and least expensive painting is placed. Display the artist name, sale_price, painting name, museum name, museum city and canvas label
with cte as
         (select *,
                 rank() over (order by sale_price desc) as rnk_dsc,
                 rank() over (order by sale_price)      as rnk_asc
          from product_size)
select distinct w.name as painting, cte.sale_price, a.full_name, m.name as museum_name, m.city, cs.label as canvas
from cte
         join public.work w on w.work_id = cte.work_id
         join public.museum m on w.museum_id = m.museum_id
         join public.artist a on a.artist_id = w.artist_id
         join public.canvas_size cs on cs.size_id::text = cte.size_id
where cte.rnk_dsc = 1
   or cte.rnk_asc = 1;

-- 20. Which country has the 5th highest no of paintings?
with cte as
         (select m.country, count(1) as no_of_paintings, rank() over (order by count(1) desc) as rnk
          from public.work w
                   join public.museum m on w.museum_id = m.museum_id
          group by m.country)
select country
from cte
where rnk = 5;

-- 21. Which are the 3 most popular and 3 least popular painting styles?
with cte as
         (select style,
                 count(1)                             as pop_style,
                 rank() over (order by count(1) desc) as rnk_desc,
                 count(1) over ()                     as no_of_records
          from public.work
          where style is not null
          group by style)
select style,
       case when rnk_desc <= 3 then 'Most Popular' else 'Least Popular' end as popularity
from cte
where rnk_desc <= 3
   or rnk_desc > no_of_records - 3;

-- 22. Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.
with cte as
(select a.full_name, a.nationality, count(1) as no_of_paintings,
       rank() over (order by count(1) desc) as rnk
from public.work w join public.museum m on w.museum_id = m.museum_id
join public.artist a on w.artist_id = a.artist_id
where m.country != 'USA'
group by a.nationality, a.full_name)
select * from cte
where rnk = 1;