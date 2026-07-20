-- =============================================================================
-- SP_LEADS_REPORT  |  Credit Campaign Analytics Dashboard
-- =============================================================================
-- Purpose : Normalises raw campaign offer data into a structured leads summary
--           table (HAR_LEADS_RESUMEN) consumed by the Power BI dashboard.
--
-- Key logic:
--   1. Maps 20+ raw campaign name variants to standardised codes
--      (EAI, RECURRENTE, REENGANCHE, PILOTO 1-15, etc.)
--   2. Classifies approved amounts into 6 ranges (≤1K … >200K)
--   3. Separates APROBADOS vs EVALUABLES campaign types
--   4. Populates both summary (HAR_LEADS_RESUMEN) and detail
--      (HAR_LEADS_REPORTE) tables for different dashboard views
--
-- Usage : EXEC dbo.SP_LEADS_REPORT '202601'
-- =============================================================================

/****** Object:  StoredProcedure [dbo].[SP_LEADS_REPORTE]    Script Date: 12/02/2026 17:43:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--exec [dbo].[SP_LEADS_REPORTE] '202508'
ALTER PROC [dbo].[SP_LEADS_REPORTE] (@PERIODO VARCHAR(6)) AS

BEGIN

/*
SELECT MIN(PERIODO) FROM HAR_LEADS_REPORTE
SELECT CNOMBRECAMPCARGA,SUM(Q) Q FROM HAR_LEADS_REPORTE
WHERE TIPO_CAMPAÑA = 'EVALUABLES'
GROUP BY CNOMBRECAMPCARGA
ORDER BY 1

SELECT CNOMBRECAMPCARGA,SUM(Q) Q FROM HAR_LEADS_RESUMEN
WHERE TIPO_CAMPAÑA = 'EVALUABLES'
GROUP BY CNOMBRECAMPCARGA
ORDER BY 1
*/

-- PARA CASCADA
DELETE FROM HAR_LEADS_RESUMEN WHERE PERIODO = @PERIODO

INSERT INTO HAR_LEADS_RESUMEN
SELECT 
	CAST(dFechaOferta AS DATE) dFechaOferta,
	CONVERT(CHAR(6),dFechaOferta,112) PERIODO,
	CAST(cNombreCampCarga AS VARCHAR)cNombreCampCarga,
	CASE 
		WHEN cNombreCampCarga IN( 'Efectivo al Instante','Base de Efectivo al Instante') THEN 'EAI'
		WHEN cNombreCampCarga = 'Base Nuevos' THEN 'NUEVOS'
		WHEN cNombreCampCarga = 'Nuevos' THEN 'NUEVOS'
		WHEN cNombreCampCarga IN ('Piloto 1','Piloto 1 – Capacidad de Pago') THEN 'PILOTO 1: Capacidad de pago'
		WHEN cNombreCampCarga = 'Piloto 12 Ultima Cuota' THEN 'PILOTO 12'
		WHEN cNombreCampCarga = 'Piloto 13' THEN 'PILOTO 13'
		WHEN cNombreCampCarga IN ('Piloto 14', 'Piloto 14 Reenganche') THEN 'PILOTO 14'
		WHEN cNombreCampCarga = 'Piloto 15 Reenganche' THEN 'PILOTO 15'
		WHEN cNombreCampCarga IN ('Piloto 2','Piloto 2 – Avance de cuota') THEN 'PILOTO 2: Avance de cuota'
		WHEN cNombreCampCarga = 'Piloto 2 Disponible RCC' THEN 'PILOTO 2: Avance de cuota'
		WHEN cNombreCampCarga LIKE 'Piloto 3 – Rapicrédito -%' THEN 'Piloto 3 – Rapicrédito - Recurrente Flexible'
		WHEN cNombreCampCarga = 'Piloto 3' THEN 'PILOTO 3: Recurente flexible'
		WHEN cNombreCampCarga LIKE 'Piloto 4 – Rapicrédito -%' THEN 'Piloto 4 – Rapicrédito - Atraso'
		WHEN cNombreCampCarga = 'Piloto 4' THEN 'PILOTO 4: Atraso'
		WHEN cNombreCampCarga = 'Piloto 6' THEN 'PILOTO 6'
		WHEN cNombreCampCarga = 'Piloto 7' THEN 'PILOTO 7'
		WHEN cNombreCampCarga IN ('Piloto 8','Piloto 8  – Capacidad de Pago','Piloto 8 Reenganche') THEN 'PILOTO 8: Capacidad de pago'
		WHEN cNombreCampCarga IN( 'Piloto 9  – Tope de Oferta 20M','Piloto 9 Reenganche') THEN 'PILOTO 9: Tope Oferta 20M'
		WHEN cNombreCampCarga = 'Nuevos No Bancarizados' THEN 'PILOTO NO BANCARIZADO'
		WHEN cNombreCampCarga IN ('Base de Recurrente','Recurrente') THEN 'RECURRENTE'
		WHEN cNombreCampCarga IN ( 'Base de Reenganche','Campaña Reenganche Principal') THEN 'REENGANCHE'
	ELSE cNombreCampCarga END TIPO_NOMBRE_CARGA,
	'APROBADOS' TIPO_CAMPAÑA,
	CASE 
		WHEN dMontoAprobado<=1000 THEN '1. <=1000'
		WHEN dMontoAprobado<=3000 THEN '2. <=3000'
		WHEN dMontoAprobado<=5000 THEN '3. <=5000'
		WHEN dMontoAprobado<=10000 THEN '4. <=10000'
		WHEN dMontoAprobado<=20000 THEN '5. <=20000'
		else '6. >20000'
	END RANGO_MONTO, 
	REGION,RangoScore,CAST(TipoCliente AS VARCHAR)TipoCliente,Observacion,clasificacion_plus,Plazo,
	COUNT(1) Q, SUM(dMontoAprobado) MONTO
FROM OFERTACAMP
WHERE CONVERT(CHAR(6),dFechaOferta,112) = @PERIODO
GROUP BY 
	CAST(dFechaOferta AS DATE) ,
	CONVERT(CHAR(6),dFechaOferta,112) ,
	CAST(cNombreCampCarga AS VARCHAR),
	CASE 
		WHEN cNombreCampCarga IN( 'Efectivo al Instante','Base de Efectivo al Instante') THEN 'EAI'
		WHEN cNombreCampCarga = 'Base Nuevos' THEN 'NUEVOS'
		WHEN cNombreCampCarga = 'Nuevos' THEN 'NUEVOS'
		WHEN cNombreCampCarga IN ('Piloto 1','Piloto 1 – Capacidad de Pago') THEN 'PILOTO 1: Capacidad de pago'
		WHEN cNombreCampCarga = 'Piloto 12 Ultima Cuota' THEN 'PILOTO 12'
		WHEN cNombreCampCarga = 'Piloto 13' THEN 'PILOTO 13'
		WHEN cNombreCampCarga IN ('Piloto 14', 'Piloto 14 Reenganche') THEN 'PILOTO 14'
		WHEN cNombreCampCarga = 'Piloto 15 Reenganche' THEN 'PILOTO 15'
		WHEN cNombreCampCarga IN ('Piloto 2','Piloto 2 – Avance de cuota') THEN 'PILOTO 2: Avance de cuota'
		WHEN cNombreCampCarga = 'Piloto 2 Disponible RCC' THEN 'PILOTO 2: Avance de cuota'
		WHEN cNombreCampCarga LIKE 'Piloto 3 – Rapicrédito -%' THEN 'Piloto 3 – Rapicrédito - Recurrente Flexible'
		WHEN cNombreCampCarga = 'Piloto 3' THEN 'PILOTO 3: Recurente flexible'
		WHEN cNombreCampCarga LIKE 'Piloto 4 – Rapicrédito -%' THEN 'Piloto 4 – Rapicrédito - Atraso'
		WHEN cNombreCampCarga = 'Piloto 4' THEN 'PILOTO 4: Atraso'
		WHEN cNombreCampCarga = 'Piloto 6' THEN 'PILOTO 6'
		WHEN cNombreCampCarga = 'Piloto 7' THEN 'PILOTO 7'
		WHEN cNombreCampCarga IN ('Piloto 8','Piloto 8  – Capacidad de Pago','Piloto 8 Reenganche') THEN 'PILOTO 8: Capacidad de pago'
		WHEN cNombreCampCarga IN( 'Piloto 9  – Tope de Oferta 20M','Piloto 9 Reenganche') THEN 'PILOTO 9: Tope Oferta 20M'
		WHEN cNombreCampCarga = 'Nuevos No Bancarizados' THEN 'PILOTO NO BANCARIZADO'
		WHEN cNombreCampCarga IN ('Base de Recurrente','Recurrente') THEN 'RECURRENTE'
		WHEN cNombreCampCarga IN ( 'Base de Reenganche','Campaña Reenganche Principal') THEN 'REENGANCHE'
	ELSE cNombreCampCarga END ,
	CASE 
		WHEN dMontoAprobado<=1000 THEN '1. <=1000'
		WHEN dMontoAprobado<=3000 THEN '2. <=3000'
		WHEN dMontoAprobado<=5000 THEN '3. <=5000'
		WHEN dMontoAprobado<=10000 THEN '4. <=10000'
		WHEN dMontoAprobado<=20000 THEN '5. <=20000'
		else '6. >20000'
	END , 
	REGION,RangoScore,CAST(TipoCliente AS VARCHAR),Observacion,clasificacion_plus,Plazo

union all

SELECT CAST(CAST(a.PERIODO AS VARCHAR(6))+'01' AS DATE),CAST(PERIODO AS VARCHAR(6)),CAST(a.cNombreCampCarga AS VARCHAR),
CASE	WHEN A.cNombreCampCarga = 'Producto Ataque' THEN 'ATAQUE'
		WHEN A.cNombreCampCarga = 'Producto Blindaje' THEN 'BLINDAJE'
		WHEN A.cNombreCampCarga = 'Efectivo Al Instante' THEN 'EAI' END,
'EVALUABLES' TIPO_CAMPAÑA,
null RANGO_MONTO, null REGION,null RangoScore,
CASE WHEN a.cNombreCampCarga LIKE '%ATAQUE%' THEN 'Nuevo' ELSE 'Recurrente' end tipo_cliente
,a.Observacion,null clasificacion_plus,null Plazo,
COUNT(1) Q, 0 MONTO
FROM OfertaCamp_Preapro a
left join (select * from OfertaCamp where cNombreCampCarga not in ('Levantamiento de flujo')) b
on a.cDocumentoID=b.cDocumentoID and a.periodo=convert(varchar(6),b.dFechaOferta,112)
WHERE a.periodo =@PERIODO and b.cDocumentoID is null
GROUP BY CAST(CAST(a.PERIODO AS VARCHAR(6))+'01' AS DATE),CAST(a.PERIODO AS VARCHAR(6)),CAST(a.cNombreCampCarga AS VARCHAR),
CASE	WHEN A.cNombreCampCarga = 'Producto Ataque' THEN 'ATAQUE'
		WHEN A.cNombreCampCarga = 'Producto Blindaje' THEN 'BLINDAJE'
		WHEN A.cNombreCampCarga = 'Efectivo Al Instante' THEN 'EAI' END,
CASE WHEN a.cNombreCampCarga LIKE '%ATAQUE%' THEN 'Nuevo' ELSE 'Recurrente' end,a.Observacion

---PARA REPORTE
DELETE FROM HAR_LEADS_REPORTE WHERE PERIODO = @PERIODO

--DROP TABLE HAR_LEADS_REPORTE

INSERT INTO HAR_LEADS_REPORTE
SELECT 
	CAST(dFechaOferta AS DATE) dFechaOferta,
	CONVERT(CHAR(6),dFechaOferta,112) PERIODO,
	CAST(cNombreCampCarga AS VARCHAR)cNombreCampCarga,
	CASE 
		WHEN cNombreCampCarga IN( 'Efectivo al Instante','Base de Efectivo al Instante') THEN 'EAI'
		WHEN cNombreCampCarga = 'Base Nuevos' THEN 'NUEVOS'
		WHEN cNombreCampCarga = 'Nuevos' THEN 'NUEVOS'
		WHEN cNombreCampCarga IN ('Piloto 1','Piloto 1 – Capacidad de Pago') THEN 'PILOTO 1: Capacidad de pago'
		WHEN cNombreCampCarga = 'Piloto 12 Ultima Cuota' THEN 'PILOTO 12'
		--WHEN cNombreCampCarga = 'Piloto 13' THEN 'PILOTO 13'
		WHEN cNombreCampCarga IN ('Piloto 14 Reenganche') THEN 'PILOTO 14: Reenganche'
		WHEN cNombreCampCarga = 'Piloto 15 Reenganche' THEN 'PILOTO 15: Reenganche'
		WHEN cNombreCampCarga IN ('Piloto 2','Piloto 2 – Avance de cuota','Piloto 2 Disponible RCC') THEN 'PILOTO 2: Avance de cuota'
		--WHEN cNombreCampCarga = 'Piloto 2 Disponible RCC' THEN 'PILOTO 2: Avance de cuota'
		WHEN cNombreCampCarga LIKE 'Piloto 3 – Rapicrédito -%' or cNombreCampCarga in ('Piloto 3','Piloto 14') THEN 'Piloto 3 – Rapicrédito - Recurrente Flexible'
		--WHEN cNombreCampCarga = 'Piloto 3' THEN 'Piloto 3 – Rapicrédito - Recurrente Flexible'
		WHEN cNombreCampCarga LIKE 'Piloto 4 – Rapicrédito -%' or cNombreCampCarga in ('Piloto 4','Piloto 13') THEN 'Piloto 4 – Rapicrédito - Atraso'
		--WHEN cNombreCampCarga = 'Piloto 4' THEN 'PILOTO 4: Atraso'
		WHEN cNombreCampCarga = 'Piloto 6' THEN 'PILOTO 6'
		WHEN cNombreCampCarga = 'Piloto 7' THEN 'PILOTO 7'
		WHEN cNombreCampCarga IN ('Piloto 8','Piloto 8  – Capacidad de Pago','Piloto 8 Reenganche') THEN 'PILOTO 8: Capacidad de pago'
		WHEN cNombreCampCarga IN( 'Piloto 9  – Tope de Oferta 20M','Piloto 9 Reenganche') THEN 'PILOTO 9: Tope Oferta 20M'
		WHEN cNombreCampCarga = 'Nuevos No Bancarizados' THEN 'Piloto 5 – Rapicrédito - No Bancarizado'
		WHEN cNombreCampCarga IN ('Base de Recurrente','Recurrente') THEN 'RECURRENTE'
		WHEN cNombreCampCarga IN ( 'Base de Reenganche','Campaña Reenganche Principal') THEN 'REENGANCHE'
	ELSE cNombreCampCarga END TIPO_NOMBRE_CARGA,
	'APROBADOS' TIPO_CAMPAÑA,
	CASE 
		WHEN dMontoAprobado<=1000 THEN '1. <=1000'
		WHEN dMontoAprobado<=3000 THEN '2. <=3000'
		WHEN dMontoAprobado<=5000 THEN '3. <=5000'
		WHEN dMontoAprobado<=10000 THEN '4. <=10000'
		WHEN dMontoAprobado<=20000 THEN '5. <=20000'
		else '6. >20000'
	END RANGO_MONTO, 
	REGION,RangoScore,CAST(TipoCliente AS VARCHAR)TipoCliente,Observacion,clasificacion_plus,Plazo,
	COUNT(1) Q, SUM(dMontoAprobado) MONTO, CAST(0 AS bigint) AS ORDEN_CAMPAÑA, 0 AS flag_campaña_antigua
	--INTO HAR_LEADS_REPORTE
FROM OFERTACAMP
WHERE CONVERT(CHAR(6),dFechaOferta,112) = @PERIODO
GROUP BY 
	CAST(dFechaOferta AS DATE) ,
	CONVERT(CHAR(6),dFechaOferta,112) ,
	CAST(cNombreCampCarga AS VARCHAR),
	CASE 
		WHEN cNombreCampCarga IN( 'Efectivo al Instante','Base de Efectivo al Instante') THEN 'EAI'
		WHEN cNombreCampCarga = 'Base Nuevos' THEN 'NUEVOS'
		WHEN cNombreCampCarga = 'Nuevos' THEN 'NUEVOS'
		WHEN cNombreCampCarga IN ('Piloto 1','Piloto 1 – Capacidad de Pago') THEN 'PILOTO 1: Capacidad de pago'
		WHEN cNombreCampCarga = 'Piloto 12 Ultima Cuota' THEN 'PILOTO 12'
		--WHEN cNombreCampCarga = 'Piloto 13' THEN 'PILOTO 13'
		WHEN cNombreCampCarga IN ('Piloto 14 Reenganche') THEN 'PILOTO 14: Reenganche'
		WHEN cNombreCampCarga = 'Piloto 15 Reenganche' THEN 'PILOTO 15: Reenganche'
		WHEN cNombreCampCarga IN ('Piloto 2','Piloto 2 – Avance de cuota','Piloto 2 Disponible RCC') THEN 'PILOTO 2: Avance de cuota'
		--WHEN cNombreCampCarga = 'Piloto 2 Disponible RCC' THEN 'PILOTO 2: Avance de cuota'
		WHEN cNombreCampCarga LIKE 'Piloto 3 – Rapicrédito -%' or cNombreCampCarga in ('Piloto 3','Piloto 14') THEN 'Piloto 3 – Rapicrédito - Recurrente Flexible'
		--WHEN cNombreCampCarga = 'Piloto 3' THEN 'Piloto 3 – Rapicrédito - Recurrente Flexible'
		WHEN cNombreCampCarga LIKE 'Piloto 4 – Rapicrédito -%' or cNombreCampCarga in ('Piloto 4','Piloto 13') THEN 'Piloto 4 – Rapicrédito - Atraso'
		--WHEN cNombreCampCarga = 'Piloto 4' THEN 'PILOTO 4: Atraso'
		WHEN cNombreCampCarga = 'Piloto 6' THEN 'PILOTO 6'
		WHEN cNombreCampCarga = 'Piloto 7' THEN 'PILOTO 7'
		WHEN cNombreCampCarga IN ('Piloto 8','Piloto 8  – Capacidad de Pago','Piloto 8 Reenganche') THEN 'PILOTO 8: Capacidad de pago'
		WHEN cNombreCampCarga IN( 'Piloto 9  – Tope de Oferta 20M','Piloto 9 Reenganche') THEN 'PILOTO 9: Tope Oferta 20M'
		WHEN cNombreCampCarga = 'Nuevos No Bancarizados' THEN 'Piloto 5 – Rapicrédito - No Bancarizado'
		WHEN cNombreCampCarga IN ('Base de Recurrente','Recurrente') THEN 'RECURRENTE'
		WHEN cNombreCampCarga IN ( 'Base de Reenganche','Campaña Reenganche Principal') THEN 'REENGANCHE'
	ELSE cNombreCampCarga END,
	CASE 
		WHEN dMontoAprobado<=1000 THEN '1. <=1000'
		WHEN dMontoAprobado<=3000 THEN '2. <=3000'
		WHEN dMontoAprobado<=5000 THEN '3. <=5000'
		WHEN dMontoAprobado<=10000 THEN '4. <=10000'
		WHEN dMontoAprobado<=20000 THEN '5. <=20000'
		else '6. >20000'
	END , 
	REGION,RangoScore,CAST(TipoCliente AS VARCHAR),Observacion,clasificacion_plus,Plazo

union all

SELECT CAST(CAST(a.PERIODO AS VARCHAR(6))+'01' AS DATE),CAST(PERIODO AS VARCHAR(6)),CAST(a.cNombreCampCarga AS VARCHAR),
CASE	WHEN A.cNombreCampCarga = 'Producto Ataque' THEN 'ATAQUE'
		WHEN A.cNombreCampCarga = 'Producto Blindaje' THEN 'BLINDAJE'
		WHEN A.cNombreCampCarga = 'Efectivo Al Instante' THEN 'EAI' END,
'EVALUABLES' TIPO_CAMPAÑA,
null RANGO_MONTO, null REGION,null RangoScore,
CASE WHEN a.cNombreCampCarga LIKE '%ATAQUE%' THEN 'Nuevo' ELSE 'Recurrente' end tipo_cliente
,a.Observacion,null clasificacion_plus,null Plazo,
COUNT(1) Q, 0 MONTO, CAST(0 AS bigint) AS ORDEN_CAMPAÑA, 0 AS flag_campaña_antigua
FROM OfertaCamp_Preapro a
WHERE a.periodo = @PERIODO
GROUP BY CAST(CAST(a.PERIODO AS VARCHAR(6))+'01' AS DATE),CAST(a.PERIODO AS VARCHAR(6)),CAST(a.cNombreCampCarga AS VARCHAR),
CASE	WHEN A.cNombreCampCarga = 'Producto Ataque' THEN 'ATAQUE'
		WHEN A.cNombreCampCarga = 'Producto Blindaje' THEN 'BLINDAJE'
		WHEN A.cNombreCampCarga = 'Efectivo Al Instante' THEN 'EAI' END,
CASE WHEN a.cNombreCampCarga LIKE '%ATAQUE%' THEN 'Nuevo' ELSE 'Recurrente' end,a.Observacion

-- AJUSTE NUEVOS EVALUABLES
update a
set TIPO_CAMPAÑA = 'EVALUABLES'
from HAR_LEADS_REPORTE a
WHERE TIPO_NOMBRE_CARGA = 'Piloto 3 – Rapicrédito - Recurrente Flexible' AND PERIODO>=202506

update a
set TIPO_CAMPAÑA = 'EVALUABLES'
from HAR_LEADS_REPORTE a
WHERE TIPO_NOMBRE_CARGA = 'Piloto 4 – Rapicrédito - Atraso' AND PERIODO>=202506

update a
set TIPO_CAMPAÑA = 'EVALUABLES'
from HAR_LEADS_REPORTE a
WHERE cNombreCampCarga = 'Nuevos No Bancarizados'

/*
select TIPO_NOMBRE_CARGA,count(*) q from HAR_LEADS_REPORTE
where PERIODO >=202501
group by TIPO_NOMBRE_CARGA

select PERIODO,count(*) q from HAR_LEADS_REPORTE
where TIPO_NOMBRE_CARGA = 'PILOTO 13'
group by PERIODO

select TIPO_NOMBRE_CARGA,count(*) q from HAR_LEADS_REPORTE
where PERIODO >=202501 AND TIPO_NOMBRE_CARGA like '%PILOTO%' and TIPO_NOMBRE_CARGA NOT IN (
'PILOTO 1: Capacidad de pago','PILOTO 2: Avance de cuota','Piloto 3 – Rapicrédito - Recurrente Flexible',
'Piloto 4 – Rapicrédito - Atraso','Piloto 5 – Rapicrédito - No Bancarizado','PILOTO 8: Capacidad de pago',
'PILOTO 9: Tope Oferta 20M'
)
group by TIPO_NOMBRE_CARGA


select PERIODO,count(*) q from HAR_LEADS_REPORTE
where TIPO_NOMBRE_CARGA = 'PILOTO 14'
group by PERIODO
*/


-- AJUSTES CAMPAÑAS ANTIGUAS
/*
update a
set flag_campaña_antigua = 0
from HAR_LEADS_REPORTE a
WHERE PERIODO = @PERIODO
*/

update a
set flag_campaña_antigua = 1
from HAR_LEADS_REPORTE a
where TIPO_NOMBRE_CARGA = 'PILOTO 1: Capacidad de pago' and PERIODO<202508 AND PERIODO = @PERIODO

update a
set flag_campaña_antigua = 1
from HAR_LEADS_REPORTE a
where TIPO_NOMBRE_CARGA = 'PILOTO 2: Avance de cuota' and PERIODO<202508 AND PERIODO = @PERIODO

update a
set flag_campaña_antigua = 1
from HAR_LEADS_REPORTE a
where TIPO_NOMBRE_CARGA = 'Piloto 3 – Rapicrédito - Recurrente Flexible' and PERIODO<202506 AND PERIODO = @PERIODO

update a
set flag_campaña_antigua = 1
from HAR_LEADS_REPORTE a
where TIPO_NOMBRE_CARGA = 'Piloto 4 – Rapicrédito - Atraso' and PERIODO<202506 AND PERIODO = @PERIODO

update a
set flag_campaña_antigua = 1
from HAR_LEADS_REPORTE a
where TIPO_NOMBRE_CARGA = 'PILOTO 8: Capacidad de pago' and PERIODO<202508 AND PERIODO = @PERIODO

update a
set flag_campaña_antigua = 1
from HAR_LEADS_REPORTE a
where TIPO_NOMBRE_CARGA = 'PILOTO 9: Tope Oferta 20M' and PERIODO<202412 AND PERIODO = @PERIODO


update a
set flag_campaña_antigua = 1
from HAR_LEADS_REPORTE a
where TIPO_NOMBRE_CARGA like '%PILOTO%' and TIPO_NOMBRE_CARGA NOT IN (
'PILOTO 1: Capacidad de pago','PILOTO 2: Avance de cuota','Piloto 3 – Rapicrédito - Recurrente Flexible',
'Piloto 4 – Rapicrédito - Atraso','Piloto 5 – Rapicrédito - No Bancarizado','PILOTO 8: Capacidad de pago',
'PILOTO 9: Tope Oferta 20M'
) AND flag_campaña_antigua = 0 AND PERIODO = @PERIODO




--alter table HAR_LEADS_REPORTE add flag_campaña_antigua int

--SELECT TIPO_NOMBRE_CARGA FROM HAR_LEADS_REPORTE WHERE PERIODO = 202506 GROUP BY TIPO_NOMBRE_CARGA


UPDATE HAR_LEADS_REPORTE
SET ORDEN_CAMPAÑA =
		CASE 
			WHEN TIPO_NOMBRE_CARGA = 'EAI' THEN 1
			WHEN TIPO_NOMBRE_CARGA = 'RECURRENTE' THEN 2
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 1: Capacidad de pago' THEN 3
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 2: Avance de cuota' THEN 4
			WHEN TIPO_NOMBRE_CARGA = 'Piloto 3 – Rapicrédito - Recurrente Flexible' THEN 904
			WHEN TIPO_NOMBRE_CARGA = 'Piloto 4 – Rapicrédito - Atraso' THEN 905
			WHEN TIPO_NOMBRE_CARGA = 'REENGANCHE' THEN 7
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 8: Capacidad de pago' THEN 8
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 9: Tope Oferta 20M' THEN 9
			--WHEN TIPO_NOMBRE_CARGA = 'PILOTO 3: Recurente flexible' THEN 104
			--WHEN TIPO_NOMBRE_CARGA = 'PILOTO 4: Atraso' THEN 105
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 6' THEN 12
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 7' THEN 13
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 12' THEN 14
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 13' THEN 15
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 14: Reenganche' THEN 16
			WHEN TIPO_NOMBRE_CARGA = 'PILOTO 15: Reenganche' THEN 17
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Mora 4 mejores grupos scrore Empresarial' THEN 18
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Liberación Grupo Cliente' THEN 19
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Disponible RCC' THEN 20
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Clientes Inactivos con Reporte sin Deuda' THEN 21
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Reenganche 1' THEN 22
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Reporte SBS 4 M 3 mejores grupo score Empresarial' THEN 23
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Reporte SBS 4 M mejor grupo score Empresarial' THEN 24
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Reporte SBS 5 M 2 mejores grupo score Empresarial' THEN 25
			WHEN TIPO_NOMBRE_CARGA = 'Piloto RI RCC' THEN 26
			WHEN TIPO_NOMBRE_CARGA = 'Piloto SE' THEN 27
			WHEN TIPO_NOMBRE_CARGA = 'Piloto_Mora_Max_10_Prom_8_3_Mejores_Grupos_Score_Empresarial' THEN 28
			WHEN TIPO_NOMBRE_CARGA = 'NUEVOS' THEN 29
			WHEN TIPO_NOMBRE_CARGA = 'Piloto Nuevos con Reporte sin Deuda' THEN 30
			WHEN TIPO_NOMBRE_CARGA = 'Piloto 5 – Rapicrédito - No Bancarizado' THEN 906
			WHEN TIPO_NOMBRE_CARGA = 'Levantamiento de Flujo' THEN 32
			WHEN TIPO_NOMBRE_CARGA = 'BLINDAJE' THEN 102
			WHEN TIPO_NOMBRE_CARGA = 'ATAQUE' THEN 103
			END
	WHERE PERIODO = @PERIODO

END

/*
SELECT TIPO_NOMBRE_CARGA FROM HAR_LEADS_REPORTE
GROUP BY TIPO_NOMBRE_CARGA
ORDER BY 1

SELECT TIPO_NOMBRE_CARGA,ORDEN_CAMPAÑA FROM HAR_LEADS_REPORTE
GROUP BY TIPO_NOMBRE_CARGA,ORDEN_CAMPAÑA
ORDER BY 2,1

SELECT COUNT(1) FROM HAR_LEADS_REPORTE

SELECT * FROM HAR_LEADS_REPORTE WHERE TIPO_NOMBRE_CARGA = 'Efectivo Al Instante'

UPDATE HAR_LEADS_REPORTE
SET TIPO_NOMBRE_CARGA = 'EAI'
WHERE TIPO_NOMBRE_CARGA ='Efectivo Al Instante' AND TIPO_CAMPAÑA = 'EVALUABLES'
*/

/*

SELECT CAST(dFechaOferta AS DATE) dFechaOferta,CONVERT(CHAR(6),dFechaOferta,112) PERIODO,
CAST(cNombreCampCarga AS VARCHAR)cNombreCampCarga,
'APROBADOS' TIPO_CAMPAÑA,
CASE 
	WHEN dMontoAprobado<=1000 THEN '1. <=1000'
	WHEN dMontoAprobado<=3000 THEN '2. <=3000'
	WHEN dMontoAprobado<=5000 THEN '3. <=5000'
	WHEN dMontoAprobado<=10000 THEN '4. <=10000'
	WHEN dMontoAprobado<=20000 THEN '5. <=20000'
	else '6. >20000'
END RANGO_MONTO, REGION,RangoScore,CAST(TipoCliente AS VARCHAR)TipoCliente,Observacion,clasificacion_plus,Plazo,
COUNT(1) Q, SUM(dMontoAprobado) MONTO
FROM OFERTACAMP
WHERE dFechaOferta >= '2025-01-01'
GROUP BY CAST(dFechaOferta AS DATE),CONVERT(CHAR(6),dFechaOferta,112) ,CAST(cNombreCampCarga AS VARCHAR),dMontoAprobado,
CASE 
	WHEN dMontoAprobado<=1000 THEN '1. <=1000'
	WHEN dMontoAprobado<=3000 THEN '2. <=3000'
	WHEN dMontoAprobado<=5000 THEN '3. <=5000'
	WHEN dMontoAprobado<=10000 THEN '4. <=10000'
	WHEN dMontoAprobado<=20000 THEN '5. <=20000'
	else '6. >20000'
END , REGION,RangoScore,TipoCliente,Observacion,clasificacion_plus,Plazo

union all

SELECT CAST(CAST(a.PERIODO AS VARCHAR(6))+'01' AS DATE),CAST(PERIODO AS VARCHAR(6)),CAST(a.cNombreCampCarga AS VARCHAR),'EVALUABLES' TIPO_CAMPAÑA,
null RANGO_MONTO, null REGION,null RangoScore,
CASE WHEN a.cNombreCampCarga LIKE '%ATAQUE%' THEN 'Nuevo' ELSE 'Recurrente' end tipo_cliente
,a.Observacion,null clasificacion_plus,null Plazo,
COUNT(1) Q, 0 MONTO
FROM OfertaCamp_Preapro a
left join (select * from OfertaCamp where cNombreCampCarga not in ('Levantamiento de flujo')) b
on a.cDocumentoID=b.cDocumentoID and a.periodo=convert(varchar(6),b.dFechaOferta,112)
WHERE a.periodo >= '202501' and b.cDocumentoID is null
GROUP BY CAST(CAST(a.PERIODO AS VARCHAR(6))+'01' AS DATE),CAST(a.PERIODO AS VARCHAR(6)),CAST(a.cNombreCampCarga AS VARCHAR),
CASE WHEN a.cNombreCampCarga LIKE '%ATAQUE%' THEN 'Nuevo' ELSE 'Recurrente' end,a.Observacion
*/

/*
select * from OfertaCamp 
where dFechaOferta = '2025-12-01' and Observacion is not null


SELECT *
	FROM HAR_LEADS_RESUMEN
	where periodo = 202512


	SELECT 
		A.dFechaOferta,A.PERIODO,b.ORDEN_TIPO_CAMPAÑA,b.TIPO_CAMPAÑA,b.ORDEN_CAMPAÑA,A.CAMPAÑA_FINAL,b.orden_filtro+1,'F000' FILTRO,'Otros (CEM, Score, etc.)' NOMBRE_FILTRO,
		sum(q) PASAN,NULL,NULL,sum(q) UNIVERSO,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
	FROM (SELECT *, CASE 
	WHEN TIPO_NOMBRE_CARGA = 'EAI' THEN 'EAI'
	WHEN TIPO_NOMBRE_CARGA = 'RECURRENTE' THEN 'RECURRENTE'
	WHEN TIPO_NOMBRE_CARGA = 'PILOTO 1: Capacidad de pago' THEN 'PILOTO1'
	WHEN TIPO_NOMBRE_CARGA = 'PILOTO 2: Avance de cuota' THEN 'PILOTO2'
	WHEN TIPO_NOMBRE_CARGA IN ('Piloto 3 – Rapicrédito - Recurrente Flexible','PILOTO 3: Recurente flexible') THEN 'PILOTO3'
	WHEN TIPO_NOMBRE_CARGA IN ('Piloto 4 – Rapicrédito - Atraso', 'PILOTO 4: Atraso') THEN 'PILOTO4'
	WHEN TIPO_NOMBRE_CARGA = 'REENGANCHE' THEN 'REENGANCHE'
	WHEN TIPO_NOMBRE_CARGA = 'NUEVOS' THEN 'NUEVOS'
	WHEN TIPO_NOMBRE_CARGA = 'BLINDAJE' THEN 'BLINDAJE'
	WHEN TIPO_NOMBRE_CARGA = 'ATAQUE' THEN 'ATAQUE'
	WHEN TIPO_NOMBRE_CARGA = 'PILOTO 8: Capacidad de pago' THEN 'PILOTO8'
	WHEN TIPO_NOMBRE_CARGA = 'PILOTO 9: Tope Oferta 20M' THEN 'PILOTO9'
	ELSE TIPO_NOMBRE_CARGA END CAMPAÑA_FINAL 
	--SELECT *
	FROM HAR_LEADS_RESUMEN ) A 
	left join (select periodo,ORDEN_TIPO_CAMPAÑA,TIPO_CAMPAÑA,ORDEN_CAMPAÑA,CAMPAÑA, MAX(ORDEN_FILTRO) ORDEN_FILTRO from MAESTRO_FILTROS
				WHERE TIPO_CAMPAÑA IN ('APROBADOS','EVALUABLES')
				GROUP BY periodo,ORDEN_TIPO_CAMPAÑA,TIPO_CAMPAÑA,ORDEN_CAMPAÑA,CAMPAÑA) b
	on a.PERIODO= b.PERIODO and a.TIPO_CAMPAÑA=b.TIPO_CAMPAÑA  AND A.CAMPAÑA_FINAL=B.CAMPAÑA
	WHERE A.PERIODO = 202512 and isnull(a.Observacion,'Pasa')  = 'Pasa'
	GROUP BY 
		A.dFechaOferta,A.PERIODO,B.ORDEN_TIPO_CAMPAÑA,b.TIPO_CAMPAÑA,B.ORDEN_CAMPAÑA,CAMPAÑA_FINAL,b.orden_filtro



	SELECT tipo_nombre_carga,Observacion,sum(q)
	FROM HAR_LEADS_RESUMEN
	where periodo = 202512
	group by tipo_nombre_carga,Observacion
	order by 1
	*/
