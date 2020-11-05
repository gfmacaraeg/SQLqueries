ALTER SESSION SET TIME_ZONE = '-6:00';
with count as (select old_bin_id as bin_stowed_to, isbn, sum(quantity) as quantity_added
        from binedit_entries
        where entry_date between trunc(sysdate -7) and trunc(sysdate)           -- Look up quantity adds from SRC counts
        and distributor_order_id = 'AFTWatsonService'
        and operation = 'a'
        group by  old_bin_id, isbn),
 
stow as ( select entry_date, old_bin_id as stow_container, new_bin_id, isbn, person
        from binedit_entries
        where distributor_order_id like 'FCStow%'                               --Find the stower and the receive container
        and entry_date between trunc(sysdate -7) and trunc(sysdate)
        and operation = 'm'),
       
stowadd as(select entry_date, old_bin_id as added_stow_container, isbn, person
        from binedit_entries
        where distributor_order_id like 'FCStow%'                               --Confirms the item was added by the stower
        and entry_date between trunc(sysdate -7) and trunc(sysdate)
        and operation = 'a'),       
 
rec as  (select entry_date, new_bin_id as receive_container, isbn, person
        from binedit_entries
        where distributor_order_id like 'FCRec%'                                --Find the receiver
        and entry_date between (TO_DATE('{RUN_DATE_YYYYMMDD} 06:00:00', 'YYYYMMDD HH24:MI:SS')-{FREE_FORM}) AND TO_DATE('{RUN_DATE_YYYYMMDD} 06:00:00', 'YYYYMMDD HH24:MI:SS')),
       
event as (select distinct isbn, distributor_order_id, receiver, receive_date
        from RECEIVED_ITEMS                                                     --Find the PO the receiver received from
        where receive_date between trunc(sysdate-7) and trunc(sysdate)),
 
doi as (select doi.isbn, doi.order_id, (quantity_submitted - sum(quantity_unpacked)) qty_under_received, quantity_submitted, sum(quantity_unpacked) as Total_quantity_received
        from DC_DISTRIBUTOR_SHIPMENT_ITEMS dsi
        join distributor_order_items doi                                        --Get the PO details
        on dsi.order_id = doi.order_id
        and dsi.isbn = doi.isbn
        group by doi.isbn, doi.order_id, quantity_submitted, quantity_submitted),
total_receive as (
select distinct person , sum(quantity) as receiver_total_units_received
        from binedit_entries
        where distributor_order_id like 'FCRec%'                                --Find the receiver
        and entry_date between (TO_DATE('{RUN_DATE_YYYYMMDD} 06:00:00', 'YYYYMMDD HH24:MI:SS')-{FREE_FORM}) AND TO_DATE('{RUN_DATE_YYYYMMDD} 06:00:00', 'YYYYMMDD HH24:MI:SS')
                                group by person
)
   
    
select distinct to_date(receive_date, 'MM-DD-YYYY') receive_date, receiver, isbn, tr.receiver_total_units_received,  sum(quantity_added) quantity_added , distributor_order_id, quantity_submitted, Total_quantity_received, qty_under_received
from(
select distinct TO_CHAR(rec.entry_date, 'MM-DD-YYYY') as receive_date, count.isbn, quantity_added, rec.person as receiver, event.distributor_order_id, doi.quantity_submitted, Total_quantity_received, doi.qty_under_received
--fc.employee_start_date as hire_date,
from count
join stow
on count.bin_stowed_to = stow.new_bin_id
and count.isbn = stow.isbn
join stowadd
on stowadd.added_stow_container = stow.stow_container
and stowadd.isbn = stow.isbn
and stow.entry_date between stowadd.entry_date and stowadd.entry_date + 1
join rec
on stow.stow_container = rec.receive_container
and stow.isbn = rec.isbn
and stow.entry_date between rec.entry_date and rec.entry_date + 2
join event
on rec.person = event.receiver
and rec.isbn = event.isbn
and to_date(rec.entry_date, 'DD-MON-YY') = to_date(event.receive_date, 'DD-MON-YY')
join doi
on event.distributor_order_id = doi.order_id
and  event.isbn = doi.isbn) gi
left join total_receive tr on tr.person = gi.receiver
group by to_date(receive_date, 'MM-DD-YYYY'), isbn, receiver, distributor_order_id, quantity_submitted, qty_under_received,  Total_quantity_received, tr.receiver_total_units_received
having sum(quantity_added) <= qty_under_received
--and quantity_added <= doi.qty_under_received
--left join FC_EMPLOYEES fc
--on rec.person = fc.user_id
order by receive_date, receiver, isbn
