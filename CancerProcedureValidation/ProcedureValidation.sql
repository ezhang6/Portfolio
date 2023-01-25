
DECLARE @Month int
	   ,@Year int

SET @Month = 1
SET @Year = 2021
;

-- Declare memory table to store all required data from abnormal follow up table
declare @main TABLE (
	sbc_phn varchar (20)
	, contactid uniqueidentifier
	, sbc_mammo_exam_date date
	, sbc_diag_imaging uniqueidentifier
	,sbc_diag_imagingname varchar (100)
	,sbc_diag_biopsy uniqueidentifier
	,sbc_diag_biopsyname varchar (100)
	,sbc_breast_pathology uniqueidentifier
	,sbc_breast_pathologyname varchar (100)
	,sbc_breast_path_final_gradename varchar (100)
)

-- Declare memory table to store all the diagnostic imaging procedures
declare @img_main TABLE (
	sbc_phn varchar (20)
	, contactid uniqueidentifier
	, sbc_mammo_exam_date date
	, sbc_diagnostic_procedureid uniqueidentifier
	, sbc_name varchar (100)
	, sbc_exam_dateutc date
	, duplicate_count int
	)
	
-- Declare memory table to store all the correct diagnostic biopsy procedures
declare @bio TABLE (
	sbc_phn varchar (20)
	, contactid uniqueidentifier
	, sbc_mammo_exam_date date
	, sbc_name varchar (100)
	)

-- Declare memory table to store all the correct breast pathologies
declare @path TABLE (
	sbc_phn varchar (20)
	, contactid uniqueidentifier
	, sbc_mammo_exam_date date
	, sbc_breast_pathologyname varchar (100)
	, sbc_breast_path_final_gradename varchar (100)
	)

-- Declare memory table to store all the correct diagnostic imaging procedures
declare @img_expected1 TABLE (
	sbc_phn varchar (20)
	, contactid uniqueidentifier
	, sbc_mammo_exam_date date
	, sbc_name varchar (100)
	, sbc_exam_dateutc date
	)

-- Declare memory table to store all the second correct diagnostic imaging procedures
declare @img_expected2 TABLE (
	sbc_phn varchar (20)
	, contactid uniqueidentifier
	, sbc_mammo_exam_date date
	, sbc_name varchar (100)
	, sbc_exan_dateutc date
	, duplicate_count int
	)

-- Declare memory table to store all the correct diagnostic imaging procedures with the correct second dianostic imaging procedure
declare @img_final TABLE (
	sbc_phn varchar (20)
	, sbc_mammo_exam_date date
	, sbc_name1 varchar (100)
	, sbc_name2 varchar (100)
	)

-- Declare memory table to store all the correct imaging and biopsy procedures
declare @img_bio TABLE (
	sbc_phn varchar (20)
	, sbc_mammo_exam_date date
	, current_imaging varchar (100)
	, expected_imaging varchar (100)
	, current_biopsy varchar (100)
	, expected_biopsy varchar (100)
	)
;

-- Creating a main CTE to store all the abnormal follow up records
WITH v_main AS(
SELECT 
  c.sbc_phn
  ,c.contactid
  ,ufu.[sbc_mammo_exam_date] 
  ,[sbc_diag_imaging]	    --sbc_diagnostic_procedureid
  ,RIGHT(sbc_diag_imagingname, 12) AS sbc_diag_imagingname 
  ,[sbc_diag_biopsy]		--sbc_diagnostic_procedureid
  ,RIGHT(sbc_diag_biopsyname, 12) AS sbc_diag_biopsyname
  ,[sbc_breast_pathology]	
  ,RIGHT(sbc_breast_pathologyname, 12) AS sbc_breast_pathologyname
  ,sbc_breast_path_final_gradename
  ,ROW_NUMBER() OVER (PARTITION BY contactid ORDER BY ufu.sbc_mammo_exam_date desc) AS duplicate_count 
FROM [dbo].[Filteredsbc_abnormal_follow_up] ufu
	left join [dbo].[Filteredsbc_event] e on ufu.[sbc_eventid] = e.sbc_eventid
	left join [dbo].[Filteredcontact] c on ufu.sbc_contact = c.contactid
where e.sbc_program = 12345678
	and sbc_current_test_type in ('BBBBBBBBB-CCCC-1111-AAAA-0050569B5FEC')  --Mammogram Screening
	and sbc_next_recommendation_group in (
	  12345, 23456, 34567, 45678, 567889) --Abnormal, Abnormal - High Risk, Abnormal - Naturopath, Abnormal - Naturopath - High Risk, Abnormal - Higher Risk Surveillance
	and month(sbc_reference_dateutc) = @Month
	and year(sbc_reference_dateutc) = @Year
) --select * from v_main --order by sbc_phn

, v_main_dis as (
	select sbc_phn
			,contactid
			,sbc_mammo_exam_date
			,sbc_diag_imaging	    --sbc_diagnostic_procedureid
			,sbc_diag_imagingname
			,sbc_diag_biopsy		--sbc_diagnostic_procedureid
			,sbc_diag_biopsyname
			,sbc_breast_pathology
			,sbc_breast_pathologyname
			,sbc_breast_path_final_gradename
	from v_main
	where duplicate_count = 1
)--select * from v_main_dis -- where contactid = 'AAAAAA-BBBBB-1111-ACCC-0050569B05F7' order by sbc_phn
insert into @main
select * from v_main_dis
; --select * from @main order by sbc_phn


-- displays the correct imaging procedure
WITH v_diag_img as (
	select m.sbc_phn
		,m.contactid
		,m.sbc_mammo_exam_date
		,dp.sbc_diagnostic_procedureid
		,RIGHT(dp.sbc_name, 12) AS sbc_name
		,dp.sbc_exam_dateutc
		,ROW_NUMBER() OVER (PARTITION BY contactid ORDER BY dp.sbc_exam_dateutc desc) AS duplicate_count 
	FROM @main m
		INNER JOIN Filteredsbc_diagnostic_procedure dp ON m.contactid = dp.sbc_contact
		INNER JOIN Filteredsbc_procedure_code pc on pc.sbc_procedure_codeid = dp.sbc_procedure
		where 
			 (dp.sbc_exam_date <= DATEADD(m, 6, m.[sbc_mammo_exam_date])  and
			 dp.sbc_exam_date >= m.[sbc_mammo_exam_date]     --within 6 month of mammo (if 6 months after mammo)
			and [sbc_test_statusname] != 'Unresolvable'
			and sbc_procedure_codeid in ('AAAAAAAAAAAAA'							--Ultrasound - Breast
										,'BBBBBBBBBB'							--Mammogram - Unilateral
										,'CCCCCCCCCC'							--Mammogram - Bilateral
										,'DDDDDDDDD'							--CT - Breast
										,'EEEEEEEEE'							--MRI - Breast
										,'FFFFFFFFF'))						--Nuclear Med (PET) Scan - Breast	
)--select * from v_diag_img order by sbc_phn
insert into @img_main
select * from v_diag_img
; --select * from @img

with v_diag_img_first as (
	select sbc_phn
		, contactid
		, sbc_mammo_exam_date
		, sbc_name
		, sbc_exam_dateutc
	from @img_main
	where duplicate_count = 1
)--select * from v_diag_img_first order by sbc_phn
insert into @img_expected1
select * from v_diag_img_first
; --select * from @img1

with v_diag_img_next as (
	select distinct
		i.sbc_phn
		,i.contactid
		,i.sbc_mammo_exam_date
		,i.sbc_name
		,i.sbc_exam_dateutc
		,ROW_NUMBER() OVER (PARTITION BY i.sbc_phn ORDER BY i.sbc_exam_dateutc desc) AS duplicate_count 
	from @img_main i
	left join @img_expected1 f on i.sbc_phn=f.sbc_phn 
	where i.duplicate_count != 1
	and i.sbc_exam_dateutc < f.sbc_exam_dateutc
) --select * from v_diag_img_next order by sbc_phn

,v_diag_img_next_filter as (
	select *
	from v_diag_img_next
	where duplicate_count = 1
)--select * from v_diag_img_next_filter order by sbc_phn
insert into @img_expected2
select * from v_diag_img_next_filter
;

with v_diag_img_comb as (
	select a.sbc_phn
		, a.sbc_mammo_exam_date
		, a.sbc_name as orig_proc
		, CASE 
			WHEN a.sbc_name = b.sbc_name THEN a.sbc_name
			WHEN a.sbc_name != b.sbc_name THEN b.sbc_name
			ELSE a.sbc_name
		END as next_proc 
	from @img_expected1 a
	left join @img_expected2 b on a.sbc_phn=b.sbc_phn
) --select * from v_diag_img_comb order by sbc_phn

insert into @img_final
select * from v_diag_img_comb
; --select * from @img_expect order by sbc_phn

-- displays the correct biopsy procedure
WITH v_diag_biopsy as (
select m.sbc_phn
		,m.contactid
		,m.sbc_mammo_exam_date
		,dp.sbc_diagnostic_procedureid
		,RIGHT(dp.sbc_name, 12) AS sbc_name
		,dp.sbc_exam_dateutc
		,ROW_NUMBER() OVER (PARTITION BY contactid ORDER BY dp.sbc_exam_dateutc) AS duplicate_count 
		FROM @main m 
		inner join Filteredsbc_diagnostic_procedure dp ON m.contactid = dp.sbc_contact
		inner join Filteredsbc_procedure_code pc on pc.sbc_procedure_codeid = dp.sbc_procedure
		where 
			 (dp.sbc_exam_date <= DATEADD(m, 6, m.[sbc_mammo_exam_date])  and
			 dp.sbc_exam_date >= m.[sbc_mammo_exam_date]     --within 6 month of mammo (if 6 months after mammo)
			and [sbc_test_statusname] != 'Unresolvable'
			and sbc_procedure_codeid in ('AAAAAAAAAAAAAAAAA'						--Partial Mastectomy
									,'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'							--Bilateral Total Mastectomy
									,'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'							--Breast lesion, non-palpable localizing
									,'111111111111111DAFSFDSAFDSAFDSA'							--Fine Needle Aspirate
									,'DFASKDJFASDHFKDASHFIUDSHFAIDSFDA'							--Open Biopsy
									,'DFASKDFNAODSIFDSAFODSAHFDSIOAFS'							--Core Biopsy
									,'FDA;HIORHEAOIHDSOIFAHDOIFHASODFH'							--Lymph Node Biopsy
									,'CDSFASDFASDFASFASDFASDFASDFDSFA'							--Axillary Dissection
									,'FDASFSDAFASDFSADFASDFDSAFSADFSDA'							--Sentinel Lymph Node Biopsy
									,'CFDSAFDASFSADFSAFASDFASDFASDFDSC'							--Total Mastectomy
									,'FDSAFDSFSADFSADFSDAFSADFSDAFSDAF'))						--Mastotomy
) --select * from v_diag_biopsy

, v_diag_biopsy_filter as (
	select *
	from v_diag_biopsy
	where duplicate_count = 1
) 

, v_diag_biopsy_correct as (
	select  sbc_phn
			, contactid
			,sbc_mammo_exam_date
			,sbc_name
	FROM v_diag_biopsy_filter
)--select * from v_diag_biopsy_correct 

insert into @bio
select * from v_diag_biopsy_correct
; --select * from @bio

-- Join the correct imaging and biopsy together
WITH v_img_bio as (
	select m.sbc_phn, m.contactid,m.sbc_mammo_exam_date
	, m.sbc_diag_imagingname as current_imaging
	, i.sbc_name1			as expected_imaging1
	, i.sbc_name2			as expected_imaging2
	, m.sbc_diag_biopsyname as current_biopsy
	, b.sbc_name			as expected_biopsy
	from @main m
	left join @img_final i on m.sbc_phn=i.sbc_phn 
	left join @bio b on m.sbc_phn=b.sbc_phn 
) --select * from v_img_bio order by sbc_phn

-- Choose the next correct imaging proceudre if the original expected imaging procedure = current biopsy and expected biopsy
, v_img_bio_filter AS (
	SELECT sbc_phn
		, sbc_mammo_exam_date
		, current_imaging
		, case 
			when current_biopsy = expected_biopsy and expected_imaging1 = current_biopsy THEN expected_imaging2
			else expected_imaging1
			end as expected_imaging
		, current_biopsy
		, expected_biopsy
	FROM v_img_bio
) --select * from v_img_bio_filter order by sbc_phn

insert into @img_bio
select * from v_img_bio_filter
; --select * from @img_bio

-- display the correct pathology
WITH v_pathology_correct as (
select  sbc_phn
		, contactid
		,[sbc_mammo_exam_date]
		--when it has cancer fact then (select order by collected on asc) else (select order by collected on desc)
		,( select top 1 [sbc_breast_pathologyid] = CASE WHEN (select top 1 [sbc_final_gradename] 
																from [dbo].[Filteredsbc_breast_pathology] 
																where sbc_contact = m.contactid 					   
																and [sbc_collected_on_date] <= DATEADD(m, 6, m.[sbc_mammo_exam_date])
																and [sbc_collected_on_date] >= m.[sbc_mammo_exam_date] 
																and [sbc_final_grade] IN ('Cfasfds050569B5FEC'				-- Pleomorphic LCIS_2020
																		,'C4FDFSADFASDFASDFASDFSDAFSADFDSAFDSFA'					-- Insitu_2020
																		,'C5FA6FDSAFDSAFDSFASDFASDFDSAFSDAFSADFS'					-- Invasive_2020
																		,'DLASDFHJAOSIDFHOASDFHSIDOAFHDISOAFDSA'					-- L2020_Insitu
																		,'DFAOISDHFOIASHDFIOHASDIFHASDOIFHOSADFF')				-- L2020_Invasive
															) is not null
				THEN
							(select top 1 right(sbc_name, 12)  --has cancer fact 
							FROM [dbo].[Filteredsbc_breast_pathology]
							where [sbc_final_grade] IN ('Cfasfds050569B5FEC'				-- Pleomorphic LCIS_2020
																		,'C4FDFSADFASDFASDFASDFSDAFSADFDSAFDSFA'					-- Insitu_2020
																		,'C5FA6FDSAFDSAFDSFASDFASDFDSAFSDAFSADFS'					-- Invasive_2020
																		,'DLASDFHJAOSIDFHOASDFHSIDOAFHDISOAFDSA'					-- L2020_Insitu
																		,'DFAOISDHFOIASHDFIOHASDIFHASDOIFHOSADFF')				-- L2020_Invasive
								and sbc_contact = m.contactid 
								and	[sbc_collected_on_date] <= DATEADD(m, 6, m.[sbc_mammo_exam_date])
								and [sbc_collected_on_date] >= m.[sbc_mammo_exam_date] 
								and [sbc_test_statusname] != 'Unresolvable'					
								order by sbc_collected_on_date)
				ELSE
						(select top 1 right(sbc_name, 12)  --no cancer fact 
						FROM [dbo].[Filteredsbc_breast_pathology]	
						where [sbc_final_grade] not IN ('Cfasfds050569B5FEC'				-- Pleomorphic LCIS_2020
																		,'C4FDFSADFASDFASDFASDFSDAFSADFDSAFDSFA'					-- Insitu_2020
																		,'C5FA6FDSAFDSAFDSFASDFASDFDSAFSDAFSADFS'					-- Invasive_2020
																		,'DLASDFHJAOSIDFHOASDFHSIDOAFHDISOAFDSA'					-- L2020_Insitu
																		,'DFAOISDHFOIASHDFIOHASDIFHASDOIFHOSADFF')				-- L2020_Invasive
							and sbc_contact = m.contactid
							and	[sbc_collected_on_date] <= DATEADD(m, 6, m.[sbc_mammo_exam_date])
							and [sbc_collected_on_date] >= m.[sbc_mammo_exam_date] 
							and [sbc_test_statusname] != 'Unresolvable'				
							order by sbc_collected_on_date desc)
				END			
			FROM [dbo].[Filteredsbc_breast_pathology]
			where sbc_contact = m.contactid 
				and	[sbc_collected_on_date] <= DATEADD(m, 6, m.[sbc_mammo_exam_date])
				and [sbc_collected_on_date] >= m.[sbc_mammo_exam_date] 
				and [sbc_test_statusname] != 'Unresolvable' ) as sbc_breast_pathologyname
		, sbc_breast_path_final_gradename
FROM @main m
)--select * from v_pathology_correct

insert into @path
select * from v_pathology_correct
; --select * from @path order by sbc_phn

-- Adding the correct pathology together with the correct imaging and biopsy procedures
WITH v_final as (
	select i.sbc_phn, i.sbc_mammo_exam_date
	, i.current_imaging
	, i.expected_imaging
	, i.current_biopsy
	, i.expected_biopsy
	, m.sbc_breast_pathologyname as current_breast_pathology
	, m.sbc_breast_path_final_gradename as current_bp_final_grande_name
	, p.sbc_breast_pathologyname as expected_breast_pathology
	, p.sbc_breast_path_final_gradename as expected_bp_final_grande_name
	from @main m
	left join @img_bio i on m.sbc_phn=i.sbc_phn
	left join @path p on m.sbc_phn=p.sbc_phn 
) --select * from v_final order by sbc_phn

-- Produces a final table and only shows the procedures that are showing different "dates" (using the sbc_name in Filteredsbc_Diagnostic_Procedure)
, v_final_filter as(
select 
	sbc_phn
	, sbc_mammo_exam_date
	, current_imaging
	, expected_imaging
	, current_biopsy
	, expected_biopsy
	, current_breast_pathology
	, current_bp_final_grande_name
	, expected_breast_pathology
	, expected_bp_final_grande_name
from v_final 
where (current_imaging != expected_imaging) OR (current_biopsy!=expected_biopsy) OR (current_breast_pathology!=expected_breast_pathology) 
)

--Final Querry, dont need the record with same imaging procedure and the same current_biopsy, current_breast_pathology and expect_breast_pathology "date"
select 
	sbc_phn
	, sbc_mammo_exam_date
	, current_imaging
	, expected_imaging
	, current_biopsy
	, expected_biopsy
	, current_breast_pathology
	, current_bp_final_grande_name
	, expected_breast_pathology
	, expected_bp_final_grande_name
from v_final_filter
where 
	(current_imaging != expected_imaging)
	or (current_biopsy not in (current_breast_pathology, expected_breast_pathology))
	or (current_biopsy is null or expected_biopsy is null or current_breast_pathology is null or expected_breast_pathology is null)
order by sbc_phn

