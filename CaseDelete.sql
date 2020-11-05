with be as (select entry_date, isbn, old_bin_id
            from binedit_entries
            where entry_date between trunc(sysdate-7) and trunc(sysdate)
            and operation = 'd'
            and old_bin_id like 'csX%'                                                                                                                                                                                --deleted items from case stickers
            and new_owner != 'unsellable'
            union
                select entry_date, isbn, substr(old_bin_id,3,12) old_bin_id
            from binedit_entries
            where entry_date between trunc(sysdate-7) and trunc(sysdate)
            and operation = 'd'
            and old_bin_id like 'vtcsX%'                                                                                                                                                                                                                            
            and new_owner != 'unsellable'),
           
cse as (select move_date, casesticker, bb.scannable_id as palletid
            from(
            select *
            from
            (select last_updated, container_id, scannable_id as casesticker, containing_container_id
            from containers
            where scannable_id like 'csX%') a                                                                                                                                                                                 --find pallet the case sticker was from
            join container_move_segments b
            on a.container_id = b.container_id
            ) aa
            join containers bb
            on aa.move_from_container_id = bb.container_id
            and aa.requested_by_client like 'FCPick%'),
       
stow as (select*
                from stow_metric_data
                where stow_mode = 'Pallet'                                                                                                                                                                                                                       --find VNA bin where the pallet was stowed to
                and success = 'Y'
                and stow_date_utc between trunc(sysdate-500) and trunc(sysdate)),
         
rsrv as (select *
            from(
            select distinct d.scannable_id bin, c.scannable_id pallet,a.fnsku asin
            from bin_items a
            join containers b
            on a.container_id=b.container_id
            join containers c
            on b.containing_container_id=c.container_id                                                                                                                                                         --filter only bins that have the current pallet/ASIN stowed
            join containers d
            on c.containing_container_id=d.container_id
            where d.scannable_id like 'R-1%'
            order by d.scannable_id asc
              )),
countd as            (select distinct count_end_date_utc as count_date, scannable_id
            from icqa_count_attempt_logs
            where attempt_number = 1                                                                                                                                                                                                                           --filter bins already counted
            and scannable_id like 'R-1%'
            and count_end_date_utc between trunc(sysdate-10) and trunc(sysdate))         
            
          
select distinct entry_date, isbn, asin, pallet, bin as reserve, count_date
from be
join cse
on be.old_bin_id = cse.casesticker
join stow
on cse.palletid = stow.source_scannable_id
join rsrv
on stow.bin_id = rsrv.bin
and cse.palletid = rsrv.pallet
left join countd
on rsrv.bin = countd.scannable_id
--and count_date is NULL
--or countd.count_date < be.entry_date -5