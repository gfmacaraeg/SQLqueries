-This is a bad query example. This is to show my progress from where I started. 


-Multiple scannable barcode query 

alter session enable parallel query;
select distinct /*+ USE_HASH(zz, yy) full (zz) full (yy)*/
zz.bin_id add_bin,
yy.bin_id delete_bin,
zz.fnsku add_fnsku,
yy.fnsku delete_fnsku,
zz.GL_PRODUCT_GROUP_DESC add_product_group,
yy.GL_PRODUCT_GROUP_DESC delete_product_group,
zz.ITEM_NAME add_ITEM_NAME,
yy.ITEM_NAME delete_ITEM_NAME
--zz.quantity+yy.quantity as sumAdjustments
from
   (Select distinct /*+ USE_HASH(temp1, temp2) full (temp1) full (temp2)*/
                                --temp1.reason_code     
         temp1.fnsku
       , temp1.quantity
        , temp1.bin_id
        , temp2.PARENT_ASIN_NAME as ITEM_NAME
                , temp2.GL_PRODUCT_GROUP_DESC
                                , temp1.asin fcsku
        from
                                                (SELECT /*+ USE_HASH (iai, b)*/
                iai.fnsku
        , iai.quantity
        , b.bin_id
                                , iai.asin
      FROM
        na_acs_met_ddl.binedit_entries iai
      , na_acs_met_ddl.bins b
   
      WHERE
        iai.old_bin_id = b.bin_id
        and b.region_id = 1
        and iai.region_id = 1
        and b.warehouse_id = '{WAREHOUSE_ID}'
        and b.bin_usage = 1024
        and b.bin_type_name not in ('PALLET-SINGLE')
        and iai.tool in ('AMNESTY_ADD_BACK', 'FCICQACountService', 'WatsonCycleCount')
        and iai.entry_date between trunc(sysdate-4) and trunc(sysdate)
        and iai.operation = 'a'
        --and iai.asin not like 'ZZZ'
       and iai.warehouse_id = '{WAREHOUSE_ID}'
            ) temp1
        join D_MP_ASINS temp2
        on temp1.fnsku = temp2.ASIN
                                and temp2.region_id = 1
                                and temp2.marketplace_id = 1
   ) zz
  
   join
        
    (Select distinct /*+ USE_HASH(temp1, temp2) full (temp1) full (temp2)*/
 
                                --temp1.reason_code     
         temp1.fnsku
       , temp1.quantity
        , temp1.bin_id
        , temp2.PARENT_ASIN_NAME as ITEM_NAME,
     temp2.GL_PRODUCT_GROUP_DESC
     , temp1.asin fcsku
        from
                                                (SELECT distinct /*+ USE_HASH (iai, b)*/
               iai.fnsku
        , iai.quantity
        , b.bin_id
                                , iai.asin
      FROM
        na_acs_met_ddl.binedit_entries iai
      , na_acs_met_ddl.bins b
   
      WHERE
        iai.old_bin_id = b.bin_id
        and b.region_id = 1
        and iai.region_id = 1
        and b.warehouse_id = '{WAREHOUSE_ID}'
        and b.bin_usage = 1024
        and b.bin_type_name not in ('PALLET-SINGLE')
        and iai.tool not in ('reconvert-date-lot')
        and iai.entry_date between trunc(sysdate-4) and trunc(sysdate)
        and iai.operation = 'd'
        --and iai.asin not like 'ZZZ'  
                    and iai.warehouse_id = '{WAREHOUSE_ID}'
            ) temp1
        join D_MP_ASINS temp2
        on temp1.fnsku = temp2.ASIN
                                and temp2.region_id = 1
                                and temp2.marketplace_id = 1
    ) yy
   
    on zz.bin_id = yy.bin_id    
      where zz.GL_PRODUCT_GROUP_DESC = yy.GL_PRODUCT_GROUP_DESC
      AND ZZ.bin_id like 'P%'
      and UTL_MATCH.EDIT_DISTANCE_SIMILARITY(zz.ITEM_NAME,yy.ITEM_NAME) > 50
     
      /*and zz.ITEM_NAME != yy.ITEM_NAME
           and (substr(zz.ITEM_NAME,7,8)=substr(yy.ITEM_NAME,7,8)
           or substr(zz.ITEM_NAME,0,9)=substr(yy.ITEM_NAME,0,9)
          or substr(zz.ITEM_NAME,-18)=substr(yy.ITEM_NAME,-18))*/
   --and zz.fnsku = yy.fnsku   
     --and zz.quantity+yy.quantity =0
