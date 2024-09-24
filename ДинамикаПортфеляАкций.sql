USE [UBS]
GO
/****** Object:  StoredProcedure [capital].[DLG_DYNAM_PORTF]    Script Date: 01.04.2021 10:57:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROC [capital].[DLG_DYNAM_PORTF]
    @DateRep DATETIME
AS
BEGIN

DECLARE @DateStartYear DATETIME = DATEADD(YEAR, DATEDIFF(YEAR, 0, @DateRep), 0),
	@DatePrevYear datetime = CAST(CAST(YEAR(DATEADD(YEAR, -1, @DateRep)) AS nvarchar) + '12' + '01' AS datetime), @CurDay datetime


if (not OBJECT_ID('tempdb.dbo.#main') is null)
    drop table tempdb.dbo.#main

Select capital.first_last_day(@DatePrevYear, 1) CurDay
Into #main

Declare @IMonth int = 1

While MONTH(@DateRep) > @IMonth
Begin
	Set @DatePrevYear = CAST(CAST(YEAR(@DateRep) AS nvarchar) + RIGHT('0' + CAST(@IMonth AS nvarchar), 2) + '01' AS datetime)
	Insert Into #main (CurDay)	-- Values (@DatePrevYear)
	Select capital.first_last_day(@DatePrevYear, 1)

	Set @IMonth += 1
End

Insert Into #main (CurDay)
Select DATE_TRN
From capital.MARKET_DATA
Where YEAR(DATE_TRN) = YEAR(@DateRep)
	And MONTH(DATE_TRN) = MONTH(@DateRep)
	And DAY(DATE_TRN) <= DAY(@DateRep)
Group By DATE_TRN


if (not OBJECT_ID('tempdb.dbo.#main2') is null)
    drop table tempdb.dbo.#main2

CREATE TABLE #main2(
	Prizn smallint Null,
	ID_PAPER int Null,
	PAPER_NAME varchar(500) Null,
	CurDay datetime Null,
	PAPER_COUNT numeric (24,12) Null,
	SUMMA_BUY numeric (24,12) Null,
	CURR_COST_BUY numeric (24,12) Null,
	REVALUATION numeric (24,12) Null,
	REV_INC numeric (24,12) Null,
	PAPER_CODE varchar(40) NULL,
	REVALUATION_YEAR numeric (24,12) Null,
	TCC_START_YEAR decimal (18, 9) Null,
	REV_BAL numeric (24,12) Null
)


DECLARE PAPER CURSOR FOR
Select CurDay From #main

OPEN PAPER;
    
FETCH NEXT FROM PAPER INTO @CurDay;
    
WHILE @@FETCH_STATUS = 0
BEGIN

  ;WITH REST_PAPER
    AS
    (
	SELECT DRF.TRADE_ID
          ,DT.ID_PAPER
          ,DT.DATE_REGISTR_REAL
          ,DRS.REST
          ,DT.COST
          ,DRF.COUPON
          ,DT.HOLDING_ID
	--INTO   #REST
    FROM   dbo.DLG_REST_FR AS DRF
           INNER JOIN dbo.DLG_REST_SALDO AS DRS
                   ON DRS.ID_REST = DRF.ID_REST
           INNER JOIN dbo.DLG_TRADE AS DT
                   ON DT.TRADE_ID = DRF.TRADE_ID
           INNER JOIN dbo.DLG_TRADE_OWN AS DTO
                   ON DTO.TRADE_ID = DT.TRADE_ID
    WHERE  DRS.DATE_FR <= @CurDay
           AND DRS.DATE_NEXT > @CurDay
           AND DRF.HOLDING_ID IN (1, 2, 5)
           --AND DRS.REST <> 0
           AND DT.TRADE_TYPE IN (1, 2, 8, 9)
           AND DTO.CLIENT_IDENT = 0	--@ClientID
		   And Exists (Select * From dbo.DEPO_EMISSION_ADDFL_INT Where [ID_FIELD] = 69 And [ID_OBJECT] = DT.ID_PAPER And ISNULL([FIELD], 0) <> 0)
	)

	Insert Into #main2 (Prizn, ID_PAPER, PAPER_NAME, CurDay, PAPER_COUNT, SUMMA_BUY, CURR_COST_BUY, REVALUATION, REV_INC, PAPER_CODE, REVALUATION_YEAR, TCC_START_YEAR, REV_BAL)
	Select AL.Sect, AL.ID_PAPER, AL.PAPER_NAME, AL.CurDay, AL.PAPER_COUNT, AL.SUMMA_BUY, AL.CURR_COST_BUY, AL.REVALUATION, AL.REV_INC, AL.PAPER_CODE,
		ISNULL(R2.REVALUATION_YEAR, 0), AL.TCC_START_YEAR, ISNULL(RB.RevBal, 0)
	From (
		SELECT 20 Sect, DE.ID_PAPER
              , DE.PAPER_NAME
              ,@CurDay CurDay
              , Case When SUM(R.REST) <> 0.0 Then SUM(R.REST * R.COST) / SUM(R.REST) Else 0.0 End AS PAPER_COUNT,
			   SUM(R.REST * R.COST) AS SUMMA_BUY
			  ,CASE WHEN ISNULL(AVG(DM.PR_CLOSE), 0) <> 0 THEN AVG(DM.PR_CLOSE) ELSE AVG(DM.CLOSE_PRICE) END AS CURR_COST_BUY	-- snur 060918
              --,CASE																																-- закомм. 010421
       --        WHEN ID_CLASS = 2 THEN 
				   --(((CASE WHEN ISNULL(AVG(DM.PR_CLOSE), 0) <> 0 THEN AVG(DM.PR_CLOSE) ELSE AVG(DM.CLOSE_PRICE) END / 100) * AVG(DE.NOMINAL))		-- snur 060918
				   --- (((SUM(R.REST * R.COST * DE.NOMINAL / 100) / SUM(R.REST) / (AVG(DE.NOMINAL) / 100)) / 100) * AVG(DE.NOMINAL))) * SUM(R.REST)
       --        ELSE 
			  , SUM(R.REST * DM.TCC - R.REST * R.COST) AS REVALUATION																				-- SSV 010421
			  , 0 REV_INC, DE.PAPER_CODE,
			   --ISNULL(AVG(R2.REVALUATION_YEAR), 0) REVALUATION_YEAR, 
			   ISNULL(AVG(DM2.TCC), 1) TCC_START_YEAR,
			   --ISNULL(AVG(RB.RevBal), 0)
			   DE.ID_EMITENT
        FROM   REST_PAPER AS R
               INNER JOIN dbo.DEPO_EMISSION AS DE
                       ON DE.ID_PAPER = R.ID_PAPER
               LEFT  JOIN dbo.DLG_MARKET AS DM
                       ON DM.ID_PAPER = R.ID_PAPER
                          AND DM.DATE_TRN <= @CurDay
                          AND DM.DATE_NEXT > @CurDay

			   LEFT  JOIN dbo.DLG_MARKET AS DM2
                       ON DM2.ID_PAPER = R.ID_PAPER
                          AND DM2.DATE_TRN < @DateStartYear
                          AND DM2.DATE_NEXT >= @DateStartYear

		Where DE.ID_CLASS = 1
        GROUP  BY	DE.ID_CLASS, DE.ID_PAPER, DE.PAPER_CODE,
			DE.PAPER_NAME, DE.ID_EMITENT
		--Order By DE.PAPER_CODE
	) AL

		OUTER APPLY (SELECT SUM(REVALUATION_YEAR) AS REVALUATION_YEAR		
								FROM
								(SELECT
								--CASE																											-- Закомм. 010421
								-- WHEN DE2.ID_CLASS = 2 THEN	-- 0
								--	AVG(DE2.NOMINAL) * (ROUND(SUM(DLF.COUNT_PAPER * DT_SALE.COST) / SUM(DLF.COUNT_PAPER), 3) / 100) * SUM(DLF.COUNT_PAPER) - SUM(DLF.SUM_BUY_BAL)	-- Закомм. 120918, раскомм. 240920
								-- ELSE 
								 SUM(DLF.SUM_SALE) - SUM(DLF.COUNT_PAPER * DT_BUY.COST) AS REVALUATION_YEAR										-- SSV 010421

                        FROM   dbo.DLG_TRADE AS DT_SALE
                               INNER JOIN dbo.DLG_TRADE_OWN AS DTO
                                       ON DTO.TRADE_ID = DT_SALE.TRADE_ID
                               INNER JOIN dbo.DLG_LINKS_FR AS DLF
                                       ON DLF.ID_TRADE_SALE = DT_SALE.TRADE_ID
                               INNER JOIN dbo.DLG_REST_FR AS DRF
                                       ON DRF.ID_REST = DLF.ID_REST
                               INNER JOIN dbo.DLG_TRADE AS DT_BUY
                                       ON DT_BUY.TRADE_ID = DRF.TRADE_ID
                               INNER JOIN dbo.DEPO_EMISSION AS DE2
                                       ON DE2.ID_PAPER = DT_SALE.ID_PAPER
                               INNER JOIN dbo.DEPO_EMITENT AS DI
                                       ON DI.ID_EMITENT = AL.ID_EMITENT
						WHERE YEAR(DT_SALE.DATE_REGISTR_REAL) = YEAR(@CurDay)
						  AND CAST(DT_SALE.DATE_REGISTR_REAL AS DATE) <= @CurDay
						  AND DT_SALE.TRADE_TYPE = 2
						  AND DT_SALE.HOLDING_ID = 1
						  AND DTO.CLIENT_IDENT = 0
						  AND DTO.OWN_TYPE = 1
						  AND DE2.PAPER_CODE = AL.PAPER_CODE
						GROUP BY DE2.ID_CLASS, DE2.ID_PAPER, DI.EMITENT_NAME, DE2.PAPER_NAME

						UNION ALL
        
						SELECT SUM(OBOROT_CR) AS REVALUATION_YEAR
						FROM dbo.DLG_SUB_HOLDING AS DSH
						INNER JOIN dbo.DEPO_EMISSION AS DE3
							ON DE3.ID_PAPER = DSH.ID_PAPER
						INNER JOIN dbo.DEPO_EMITENT AS DI
							ON DI.ID_EMITENT = AL.ID_EMITENT
						WHERE YEAR(DSH.DATE_TRN) = YEAR(@CurDay)
						  AND CAST(DSH.DATE_TRN AS DATE) <= @CurDay
						  AND DSH.TYPE_SUBACCOUNT = 1
						  --AND @ClientID = 0
						  AND DE3.PAPER_CODE = AL.PAPER_CODE
						GROUP BY DE3.ID_CLASS, DI.EMITENT_NAME, DE3.PAPER_NAME
						
						) AS F
						  --WHERE F.REVALUATION_YEAR <> 0
				) AS R2

		OUTER APPLY (SELECT 
			SUM(Case When DATE_REGISTR_0 < '20200301' Then (paper_cc_s * WAPRICE_1) - (cost_b * paper_cc_s) Else (paper_cc_s * WAPRICE_2) - (cost_b * paper_cc_s) End) RevBal
			FROM capital.get_fifo_paper_repo_fix_0103 ('20200301', @CurDay, AL.ID_PAPER)
			Where IDB is Not null
		) AS RB

	Order By AL.PAPER_CODE		

FETCH NEXT FROM PAPER INTO @CurDay;
END;
    
CLOSE PAPER;
DEALLOCATE PAPER;


if (not OBJECT_ID('tempdb.dbo.#main3') is null)
drop table tempdb.dbo.#main3

Select m2.*	
Into #main3
From #main2 m2
--Where ISNULL(m2.REVALUATION_YEAR, 0) <> 0

Order By m2.CurDay, m2.PAPER_NAME


Select *
From #main3

Union All

Select 25, ID_PAPER, PAPER_NAME, NULL, NULL, NULL, (CURR_COST_BUY - TCC_START_YEAR) / TCC_START_YEAR * 100.0, NULL, NULL, NULL, NULL, NULL, NULL
From #main3
Where CurDay = @DateRep

Union All

Select 5, m3.ID_PAPER, m3.PAPER_NAME, NULL, NULL, NULL, ISNULL(Avg(DE_Max.FIELD_DECIMAL), 0), NULL, NULL, NULL, NULL, NULL, NULL
From #main3 m3
Left Join dbo.DEPO_EMISSION_ADDFL_ARRAY DE_Max
On DE_Max.ID_OBJECT = m3.ID_PAPER
	And DE_Max.ID_FIELD = 97
	And DE_Max.INDEX_COLUMN = 0
Group By m3.ID_PAPER, m3.PAPER_NAME

Union All

Select 10, m3.ID_PAPER, m3.PAPER_NAME, NULL, NULL, NULL, ISNULL(Avg(DE_Min.FIELD_DECIMAL), 0), NULL, NULL, NULL, NULL, NULL, NULL
From #main3 m3
Left Join dbo.DEPO_EMISSION_ADDFL_ARRAY DE_Min
On DE_Min.ID_OBJECT = m3.ID_PAPER
	And DE_Min.ID_FIELD = 97
	And DE_Min.INDEX_COLUMN = 1
Group By m3.ID_PAPER, m3.PAPER_NAME

Union All

Select 15, m3.ID_PAPER, m3.PAPER_NAME, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ISNULL(Avg(ST0.SALDO), 0), NULL, NULL
From #main3 m3
Left Join dbo.DEPO_EMISSION_ADDFL_STRING DE_Acc
On DE_Acc.ID_OBJECT = m3.ID_PAPER
	And DE_Acc.ID_FIELD = 98
Left Join dbo.OD_ACCOUNTS0 OA
On OA.STRACCOUNT = DE_Acc.FIELD
Left Join dbo.OD_SALTRN0 ST0
On ST0.ID_ACCOUNT = OA.ID_ACCOUNT
	And ST0.DATE_TRN <= @DateRep
    AND ST0.DATE_NEXT > @DateRep
Group By m3.ID_PAPER, m3.PAPER_NAME


END;




