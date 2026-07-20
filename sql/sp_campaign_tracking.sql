-- =============================================================================
-- SP_CAMPAIGN_TRACKING  |  Credit Campaign Analytics Dashboard
-- =============================================================================
-- Purpose : Builds the campaign performance tracking table (FCC_SEG_CAMP_REPORTE)
--           consumed by the Seguimiento tab in the Power BI dashboard.
--
-- Key logic:
--   - Joins disbursement data (iacg_Cosechas_Final_Variables) with lead data
--     (IC_Prospectos_Campañas_Totales_2) by period and campaign
--   - Calculates cosechas at 3M and 6M (CC3, CC6) per campaign cohort
--   - Tracks approved amount, pre-approved amount, and disbursed amount
--     over a rolling 12-month window
--   - Handles special cases: "Nuevos No Bancarizados" pilot remapping
--
-- Usage : EXEC dbo.SP_CAMPAIGN_TRACKING '202601'
-- =============================================================================

/****** Object:  StoredProcedure [dbo].[SP_SEGUIMIENTO_CAMPAÑAS]    Script Date: 12/02/2026 17:18:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[SP_SEGUIMIENTO_CAMPAÑAS] '202601'
ALTER PROC [dbo].[SP_SEGUIMIENTO_CAMPAÑAS] (@periodo varchar(6)) AS 

BEGIN
	
	declare 
		@periodoMax VARCHAR(6) = '',
		@FechaBase DATE,
		@Mes0   CHAR(6),
		@Mes1   CHAR(6),
		@Mes2   CHAR(6),
		@Mes3   CHAR(6),
		@Mes4   CHAR(6),
		@Mes5   CHAR(6),
		@Mes6   CHAR(6),
		@Mes7   CHAR(6),
		@Mes8   CHAR(6),
		@Mes9   CHAR(6),
		@Mes10  CHAR(6),
		@Mes11  CHAR(6),
		@Mes12  CHAR(6),
		@Ano0   CHAR(4),
		@Ano1   CHAR(4);
	
	set @FechaBase = CAST(@periodo + '01' AS DATE)

	if object_id('dbo.FCC_SEG_CAMP_REPORTE') IS NOT NULL DROP TABLE dbo.FCC_SEG_CAMP_REPORTE
	if object_id('tempdb..#SEGUIMIENTO_CAMPAÑAS') IS NOT NULL DROP TABLE #SEGUIMIENTO_CAMPAÑAS

	SELECT 
	'DESEMBOLSO' TIPO,
	CodMes,
	CASE WHEN B.CDOCUMENTOID IS NOT NULL THEN 'RIE_NUE_NOBANC' ELSE Base_Campaña END Base_Campaña,
	CASE WHEN B.CDOCUMENTOID IS NOT NULL THEN 'Piloto_NoBancarizado' ELSE Base_Campaña_Desc END Base_Campaña_Desc,
	MOD_DES2,
	SUM(0.0) MontoAprobado,
	SUM(0.0) MontoPreAprobado,
	SUM(MontoDesembolsadoSoles) MontoDesembolsado,
	SUM(ISNULL(CC6,0)) CC6,
	SUM(ISNULL(CC3,0)) CC3,
	COUNT(*) Cant,
	SUM(0) CantPre
	INTO #SEGUIMIENTO_CAMPAÑAS
	FROM dbo.iacg_Cosechas_Final_Variables A
	LEFT JOIN 
			(SELECT * FROM dbo.OfertaCamp A
			WHERE cNombreCampCarga = 'Nuevos No Bancarizados') B
		ON A.dni = B.CDOCUMENTOID AND CAST(CODMES AS VARCHAR(6)) = CONVERT(VARCHAR(6),dFechaOferta,112)
	WHERE CodMes >= 202401 and CodMes<=@periodo
	AND MOD_DES2 IN (1,2)
	GROUP BY CodMes,
	CASE WHEN B.CDOCUMENTOID IS NOT NULL THEN 'RIE_NUE_NOBANC' ELSE Base_Campaña END,
	CASE WHEN B.CDOCUMENTOID IS NOT NULL THEN 'Piloto_NoBancarizado' ELSE Base_Campaña_Desc END,
	MOD_DES2
	UNION
	SELECT 
	'LEAD' TIPO,
	YEAR(P_Periodo)*100+MONTH(P_Periodo) CodMes, 
	P_Nombre_Simple Base_Campaña_1,
	B.Nombre_Cod Base_Campaña_Desc_1,
	0 MOD_DES2,
	SUM(ISNULL(P_dMontoAprobado,0)) MontoAprobado, 
	SUM(ISNULL(P_dMontoPreAprobado,0)) MontoPreAprobado, 
	SUM(0.0) MontoDesembolsado,
	SUM(0.0) CC6,
	SUM(0.0) CC3,
	SUM(CASE WHEN ISNULL(P_dMontoAprobado,0)>0 THEN 1 ELSE 0 END) Cant,
	SUM(CASE WHEN P_Envio = 'Comerciales' AND P_Base IN ('Ataque','Blindaje','EfectivoAlInstante') THEN 1 ELSE 0 END) CantPre
	FROM dbo.IC_Prospectos_Campañas_Totales_2 A LEFT JOIN dbo.Nombre_Campañas B ON
	A.P_Nombre_Simple = B.Nombre_Simple
	WHERE ((P_Nombre_Simple <> 'RIE_CAM_REC' AND P_Periodo >= '2024-01-01') OR (P_Nombre_Simple = 'RIE_CAM_REC' AND P_Periodo >= '2024-09-30'))
			and P_Periodo<=eomonth(@FechaBase,0)
	GROUP BY YEAR(P_Periodo)*100+MONTH(P_Periodo), P_Nombre_Simple, B.Nombre_Cod

	SELECT TIPO,CodMes,Base_Campaña,Base_Campaña_Desc,MOD_DES2,
	SUM(MontoAprobado)MontoAprobado, SUM(MontoPreAprobado)MontoPreAprobado, 
	SUM(MontoDesembolsado)MontoDesembolsado, SUM(CC6)CC6, SUM(CC3)CC3, SUM(Cant)Cant, SUM(CantPre)CantPre
	INTO dbo.FCC_SEG_CAMP_REPORTE
	FROM #SEGUIMIENTO_CAMPAÑAS
	GROUP BY TIPO,CodMes,Base_Campaña,Base_Campaña_Desc,MOD_DES2

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Desembolso <= oferta, cambio de tipo de operación por > UC con ayuda de TI (manual)'
	WHERE Base_Campaña IN ('Desembolso < oferta, cambio de tipo de operación por > UC con ayuda de TI (manual)',
	'Desembolso = oferta, cambio de tipo de operación por > UC con ayuda de TI (manual)')

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Desembolso <= oferta, cambio de tipo de operación, en BD por UC'
	WHERE Base_Campaña IN ('Desembolso < oferta, cambio de tipo de operación, en BD por UC',
	'Desembolso = oferta, cambio de tipo de operación, en BD por UC')

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Desembolso <= oferta, cambio de tipo de operación, Incidencia TI: Corebank (crédito automático)'
	WHERE Base_Campaña IN ('Desembolso < oferta, cambio de tipo de operación, Incidencia TI: Corebank (crédito automático)',
	'Desembolso = oferta, cambio de tipo de operación, Incidencia TI: Corebank (crédito automático)')

	--NOMBRES DE CAMPAÑAS SEGUN LAS VIGENTES
	if object_id('tempdb..#NOMBRES_CAMP') IS NOT NULL DROP TABLE #NOMBRES_CAMP
	SELECT TipoCliente, P_Tipo_Operacion, P_Nombre_Simple, ROW_NUMBER() OVER (ORDER BY TipoCliente DESC, P_Tipo_Operacion DESC, P_Nombre_Simple) ORDEN
	INTO #NOMBRES_CAMP
	FROM dbo.IC_Prospectos_Campañas_Totales_2 A LEFT JOIN dbo.OfertaCamp B
	ON A.P_cDocumentoID = B.cDocumentoID
	WHERE YEAR(P_Periodo)*100+MONTH(P_Periodo) = @periodo AND YEAR(dFechaOferta)*100+MONTH(dFechaOferta) = @periodo AND P_Nombre_Simple LIKE 'RIE%'
	GROUP BY TipoCliente, P_Tipo_Operacion, P_Nombre_Simple
	ORDER BY TipoCliente DESC, P_Tipo_Operacion DESC, P_Nombre_Simple


	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña =
	CASE 
		WHEN B.P_Nombre_Simple IS NOT NULL 
		THEN CONCAT(CASE WHEN B.ORDEN<10 THEN '0' ELSE '' END,B.ORDEN,'. ',B.P_Nombre_Simple)
		ELSE CONCAT('99. ',Base_Campaña) 
	END
	FROM dbo.FCC_SEG_CAMP_REPORTE A JOIN #NOMBRES_CAMP B
	ON A.Base_Campaña = B.P_Nombre_Simple

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 
	(SELECT distinct Base_Campaña
	FROM dbo.FCC_SEG_CAMP_REPORTE
	WHERE Base_Campaña LIKE '%RIE_REC_PIL03%' AND CodMes = (SELECT MAX(CODMES) FROM dbo.FCC_SEG_CAMP_REPORTE))
	WHERE Base_Campaña = 'RIE_REC_PIL14'

	--CAMBIO MANUAL PARA PILOTO 4 EN JUNIO
	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 
	(SELECT distinct Base_Campaña
	FROM dbo.FCC_SEG_CAMP_REPORTE
	WHERE Base_Campaña LIKE '%RIE_REC_PIL04%' AND CodMes = (SELECT MAX(CODMES) FROM dbo.FCC_SEG_CAMP_REPORTE))
	WHERE Base_Campaña IN ('RIE_REC_PIL13','RIE_NUE_PIL13') AND CodMes IN (202506, 202507)

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña_Desc = CASE 
	WHEN Base_Campaña LIKE '%RIE_CAM_EAI%' THEN REPLACE(Base_Campaña,'RIE_CAM_EAI','Efectivo Al Instante')
	WHEN Base_Campaña LIKE '%RIE_CAM_REC%' THEN REPLACE(Base_Campaña,'RIE_CAM_REC','Recurrente')
	WHEN Base_Campaña LIKE '%RIE_REC_PIL01%' THEN REPLACE(Base_Campaña,'RIE_REC_PIL01','Piloto 1 Cap. Pago - Ago25')
	WHEN Base_Campaña LIKE '%RIE_REC_PIL02%' THEN REPLACE(Base_Campaña,'RIE_REC_PIL02','Piloto 2 Antig. Desembolso - Ago25')
	WHEN Base_Campaña LIKE '%RIE_REC_PIL03%' THEN REPLACE(Base_Campaña,'RIE_REC_PIL03','Piloto 3 Recurrente Flex - Jun25')
	WHEN Base_Campaña LIKE '%RIE_REC_PIL04%' THEN REPLACE(Base_Campaña,'RIE_REC_PIL04','Piloto 4 Atraso - Jun25')
	WHEN Base_Campaña LIKE '%RIE_CAM_REE%' THEN REPLACE(Base_Campaña,'RIE_CAM_REE','Reenganche Principal')
	WHEN Base_Campaña LIKE '%RIE_REC_PIL08%' THEN REPLACE(Base_Campaña,'RIE_REC_PIL08','Piloto 8 Cap. Pago - Ago25')
	WHEN Base_Campaña LIKE '%RIE_REC_PIL09%' THEN REPLACE(Base_Campaña,'RIE_REC_PIL09','Piloto 9 Tope 20M - Dic24')
	WHEN Base_Campaña LIKE '%RIE_CAM_NUE%' THEN REPLACE(Base_Campaña,'RIE_CAM_NUE','Nuevos')
	WHEN Base_Campaña LIKE '%RIE_CAM_NUE%' THEN REPLACE(Base_Campaña,'RIE_CAM_NUE','Nuevos')
	WHEN Base_Campaña LIKE '%RIE_NUE_%' THEN REPLACE(Base_Campaña,'RIE_NUE_','Antigua: Nuevos ')
	WHEN Base_Campaña LIKE '%RIE_REC_%' THEN REPLACE(Base_Campaña,'RIE_REC_','Antigua: Recurrentes ')
	ELSE CONCAT('Casuística: ',Base_Campaña)
	END 


	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña_Desc = 
	CASE 
		WHEN Base_Campaña = 'COM_CAM_EAI' THEN REPLACE(Base_Campaña,'COM_CAM_EAI','1. EfectivoAlInstante')
		WHEN Base_Campaña = 'COM_CAM_BLI' THEN REPLACE(Base_Campaña,'COM_CAM_BLI','2. Blindaje')
		WHEN Base_Campaña = 'COM_CAM_ATQ' THEN REPLACE(Base_Campaña,'COM_CAM_ATQ','3. Ataque')
	END
	WHERE Base_Campaña IN ('COM_CAM_EAI','COM_CAM_BLI','COM_CAM_ATQ')


	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña_Desc = REPLACE(Base_Campaña_Desc,'Casuística: ','')
	WHERE Base_Campaña IN ('COM_CAM_EAI','COM_CAM_BLI','COM_CAM_ATQ')

	ALTER TABLE dbo.FCC_SEG_CAMP_REPORTE ADD UltimoMes INT, PenultimoMes INT, AntepenultimoMes INT, Preantepenultimo INT, 
	UltimoTrimestre INT, UltimoAño INT, Ultimo3MCos6M INT, UltimoAñoCos6M INT, UltimoMesCos6M INT, PenultimoMesCos6M INT, AntepenultimoMesCos6M INT,
	Ultimo3MCos3M INT, UltimoAñoCos3M INT, UltimoMesCos3M INT, PenultimoMesCos3M INT, AntepenultimoMesCos3M INT
	
	----set @FechaBase = CAST(@periodo + '01' AS DATE)
	--DECLARE 
		SET @Mes0   = FORMAT(@FechaBase, 'yyyyMM')
		SET @Mes1   = FORMAT(DATEADD(MONTH, -1, @FechaBase), 'yyyyMM')
		SET @Mes2   = FORMAT(DATEADD(MONTH, -2, @FechaBase), 'yyyyMM')
		SET @Mes3   = FORMAT(DATEADD(MONTH, -3, @FechaBase), 'yyyyMM')
		SET @Mes4   = FORMAT(DATEADD(MONTH, -4, @FechaBase), 'yyyyMM')
		SET @Mes5   = FORMAT(DATEADD(MONTH, -5, @FechaBase), 'yyyyMM')
		SET @Mes6   = FORMAT(DATEADD(MONTH, -6, @FechaBase), 'yyyyMM')
		SET @Mes7   = FORMAT(DATEADD(MONTH, -7, @FechaBase), 'yyyyMM')
		SET @Mes8   = FORMAT(DATEADD(MONTH, -8, @FechaBase), 'yyyyMM')
		SET @Mes9   = FORMAT(DATEADD(MONTH, -9, @FechaBase), 'yyyyMM')
		SET @Mes10  = FORMAT(DATEADD(MONTH, -10, @FechaBase), 'yyyyMM')
		SET @Mes11  = FORMAT(DATEADD(MONTH, -11, @FechaBase), 'yyyyMM')
		SET @Mes12  = FORMAT(DATEADD(MONTH, -12, @FechaBase), 'yyyyMM')
		SET @Ano0   = FORMAT(@FechaBase, 'yyyy')
		SET @Ano1   = FORMAT(DATEADD(YEAR, -1, @FechaBase), 'yyyy');

	-------------------------------------------------
	----------------------LEADS----------------------
	-------------------------------------------------
	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET UltimoMes        = CASE WHEN CodMes = @Mes0 THEN 1 ELSE 0 END,
		PenultimoMes     = CASE WHEN CodMes = @Mes1 THEN 1 ELSE 0 END,
		AntepenultimoMes = CASE WHEN CodMes = @Mes2 THEN 1 ELSE 0 END,
		Preantepenultimo = CASE WHEN CodMes = @Mes3 THEN 1 ELSE 0 END,
		UltimoTrimestre  = CASE WHEN CodMes IN (@Mes0, @Mes1, @Mes2) THEN 1 ELSE 0 END,
		UltimoAño        = CASE WHEN CodMes IN (@Mes0, @Mes1, @Mes2, @Mes3, @Mes4, @Mes5, @Mes6, @Mes7, @Mes8, @Mes9, @Mes10, @Mes11) THEN 1 ELSE 0 END
	WHERE TIPO = 'LEAD';

	-------------------------------------------------
	-------------------DESEMBOLSOS-------------------
	-------------------------------------------------
	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET UltimoMes        = CASE WHEN CodMes = @Mes1 THEN 1 ELSE 0 END,
		PenultimoMes     = CASE WHEN CodMes = @Mes2 THEN 1 ELSE 0 END,
		AntepenultimoMes = CASE WHEN CodMes = @Mes3 THEN 1 ELSE 0 END,
		UltimoTrimestre  = CASE WHEN CodMes IN (@Mes1, @Mes2, @Mes3) THEN 1 ELSE 0 END,
		UltimoAño        = CASE WHEN CodMes IN (@Mes1, @Mes2, @Mes3, @Mes4, @Mes5, @Mes6, @Mes7, @Mes8, @Mes9, @Mes10, @Mes11, @Mes12) THEN 1 ELSE 0 END
	WHERE TIPO = 'DESEMBOLSO';

	-------------------------------------------------
	-------------------COSECHAS 6M-------------------
	-------------------------------------------------
	DECLARE 
		@C6_0   CHAR(6) = FORMAT(DATEADD(MONTH, -7, @FechaBase), 'yyyyMM'),
		@C6_1   CHAR(6) = FORMAT(DATEADD(MONTH, -8, @FechaBase), 'yyyyMM'),
		@C6_2   CHAR(6) = FORMAT(DATEADD(MONTH, -9, @FechaBase), 'yyyyMM'),
		@C6_Ini CHAR(6) = FORMAT(DATEADD(MONTH, -18, @FechaBase), 'yyyyMM');
	
	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Ultimo3MCos6M        = CASE WHEN CodMes IN (@C6_2, @C6_1, @C6_0) THEN 1 ELSE 0 END,
		UltimoAñoCos6M       = CASE WHEN CodMes BETWEEN @C6_Ini AND @C6_0 THEN 1 ELSE 0 END,
		UltimoMesCos6M       = CASE WHEN CodMes = @C6_0 THEN 1 ELSE 0 END,
		PenultimoMesCos6M    = CASE WHEN CodMes = @C6_1 THEN 1 ELSE 0 END,
		AntepenultimoMesCos6M = CASE WHEN CodMes = @C6_2 THEN 1 ELSE 0 END;

	-------------------------------------------------
	-------------------COSECHAS 3M-------------------
	-------------------------------------------------
	DECLARE 
		@C3_0   CHAR(6) = FORMAT(DATEADD(MONTH, -4, @FechaBase), 'yyyyMM'),
		@C3_1   CHAR(6) = FORMAT(DATEADD(MONTH, -5, @FechaBase), 'yyyyMM'),
		@C3_2   CHAR(6) = FORMAT(DATEADD(MONTH, -6, @FechaBase), 'yyyyMM'),
		@C3_Ini CHAR(6) = FORMAT(DATEADD(MONTH, -15, @FechaBase), 'yyyyMM');
	
	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Ultimo3MCos3M        = CASE WHEN CodMes IN (@C3_2, @C3_1, @C3_0) THEN 1 ELSE 0 END,
		UltimoAñoCos3M       = CASE WHEN CodMes BETWEEN @C3_Ini AND @C3_0 THEN 1 ELSE 0 END,
		UltimoMesCos3M       = CASE WHEN CodMes = @C3_0 THEN 1 ELSE 0 END,
		PenultimoMesCos3M    = CASE WHEN CodMes = @C3_1 THEN 1 ELSE 0 END,
		AntepenultimoMesCos3M = CASE WHEN CodMes = @C3_2 THEN 1 ELSE 0 END;

	-------------------------------------------
	-------AJUSTES MANUALES PARA REPORTE-------
	-------------------------------------------

	UPDATE dbo.FCC_SEG_CAMP_REPORTE 
	SET Base_Campaña = '1. EfectivoAlInstante'
	WHERE Base_Campaña LIKE '%RIE_CAM_EAI%' AND MOD_DES2 = 2

	UPDATE dbo.FCC_SEG_CAMP_REPORTE 
	SET MOD_DES2 = 1
	WHERE Base_Campaña LIKE '%RIE_REC_PIL12%' 
	OR Base_Campaña LIKE '%RIE_REC_PIL02%'

	UPDATE dbo.FCC_SEG_CAMP_REPORTE 
	SET MOD_DES2 = 1
	WHERE Base_Campaña = '11. RIE_NUE_NOBANC'

	UPDATE dbo.FCC_SEG_CAMP_REPORTE 
	SET MOD_DES2 = 2
	WHERE (Base_Campaña LIKE '%RIE_REC_PIL03%' 
	OR Base_Campaña LIKE '%RIE_REC_PIL04%')
	and CodMes>=202506


	UPDATE dbo.FCC_SEG_CAMP_REPORTE 
	SET Base_Campaña_Desc = 'Antigua: Piloto 4 Atraso'
	WHERE  Base_Campaña LIKE '%RIE_REC_PIL04%'
	and CodMes<202506

	UPDATE dbo.FCC_SEG_CAMP_REPORTE 
	SET Base_Campaña_Desc = 'Antigua: Piloto 4 Atraso'
	WHERE  Base_Campaña LIKE '%RIE_REC_PIL03%'
	and CodMes<202506 


	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Piloto No Bancarizado'
	where Base_Campaña = 'RIE_NUE_NOBANC'

	--- QUITANDO INFORMACION DE PILOTOS ANTIGUOS
	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Piloto 3 - Anterior'
	where Base_Campaña in ('05. RIE_REC_PIL03') and CodMes < 202506

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Piloto 4 - Anterior'
	where Base_Campaña in ('06. RIE_REC_PIL04') and CodMes < 202506

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Piloto 1 - Anterior'
	where Base_Campaña in ('03. RIE_REC_PIL01') and CodMes < 202508

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Piloto 2 - Anterior'
	where Base_Campaña in ('04. RIE_REC_PIL02') and CodMes < 202508

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Piloto 8 - Anterior'
	where Base_Campaña in ('08. RIE_REC_PIL08') and CodMes < 202508

	UPDATE dbo.FCC_SEG_CAMP_REPORTE
	SET Base_Campaña = 'Piloto 9 - Anterior'
	where Base_Campaña in ('09. RIE_REC_PIL09') and CodMes < 202412


	--- TABLA PARA REPORTE
	---declare @periodoMax varchar(6)

	set	@periodoMax = CAST((select max(codmes) from dbo.FCC_SEG_CAMP_REPORTE where TIPO = 'DESEMBOLSO') AS VARCHAR(6))

	drop table dbo.HAR_SEGUIMIENTO_RESUMEN

	select 
		TIPO,
		CodMes,
		Base_Campaña,
		Base_Campaña_Desc,
		MOD_DES2,
		MontoAprobado,
		MontoPreAprobado,
		MontoDesembolsado,
		CASE WHEN CODMES > CONVERT(VARCHAR(6),DATEADD(MONTH,-6,CAST(@periodoMax + '01' AS DATE)),112) OR TIPO = 'LEAD' THEN NULL ELSE CC6 END AS CC6,
		CASE WHEN CODMES > CONVERT(VARCHAR(6),DATEADD(MONTH,-3,CAST(@periodoMax + '01' AS DATE)),112) OR TIPO = 'LEAD' THEN NULL ELSE CC3 END AS CC3,
		Cant,
		CantPre,
		CAST(cast(CodMes as varchar(6)) + '01' AS DATE) periodo_fecha,
		DATEADD(MONTH,-1,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U1M,
		DATEADD(MONTH,-2,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U2M,
		DATEADD(MONTH,-3,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U3M,
		DATEADD(MONTH,-4,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U4M,
		DATEADD(MONTH,-5,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U5M,
		DATEADD(MONTH,-6,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U6M,
		DATEADD(MONTH,-7,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U7M,
		DATEADD(MONTH,-8,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U8M,
		DATEADD(MONTH,-9,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U9M,
		DATEADD(MONTH,-10,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U10M,
		DATEADD(MONTH,-11,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U11M,
		DATEADD(MONTH,-12,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U12M,
		DATEADD(MONTH,-13,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U13M,
		DATEADD(MONTH,-14,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U14M,
		DATEADD(MONTH,-15,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U15M,
		DATEADD(MONTH,-18,CAST(cast(CodMes as varchar(6)) + '01' AS DATE)) periodo_fecha_U18M,
		CASE WHEN CODMES <= @periodoMax THEN 1 ELSE 0 END Mostrar_Desembolso,
		CASE WHEN CODMES >= convert(varchar(6),DATEADD(MONTH,-12,CAST(cast(@periodoMax as varchar(6)) + '01' AS DATE)),112) THEN 1 ELSE 0 END Mostrar_Grafico,
		datediff(month,cast(cast(codmes as varchar) + '01' as date),cast('20251201' as date)) orden_diferencia
		into dbo.HAR_SEGUIMIENTO_RESUMEN
	from dbo.FCC_SEG_CAMP_REPORTE 
	where CodMes>= CONVERT(VARCHAR(6),DATEADD(MONTH,-18,CAST(@periodoMax + '01' AS DATE)),112)

END


/*
select orden_diferencia,codmes from (
select *, datediff(month,cast(cast(codmes as varchar) + '01' as date),cast('20251201' as date)) orden_diferencia
from dbo.HAR_SEGUIMIENTO_RESUMEN) a
group by orden_diferencia,codmes
order by 1
*/
